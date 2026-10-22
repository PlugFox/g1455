// The proxy pass: our own paint over the live render tree, recorded into a
// picture the glass surfaces read as their backdrop.
//
// A custom `PaintingContext` does not propagate by itself inside the normal
// pipeline — the wall is exactly `isRepaintBoundary` — and a walk that simply
// calls `paint` through that wall silently drops transparency. This pass handles
// both: drawing *everything*, it reproduces `toImageSync` byte for byte on 16
// constructs of 18 tested, and it leaves the live render tree exactly as it
// found it.
//
// One sampling case is not byte for byte, on Skia only: an image filter that
// resamples, such as `ImageFilter.matrix` with a scale at `FilterQuality.low`.
// The pass flattens it into a `saveLayer` carrying the filter, which samples
// differently from the layer the engine composites — 599 px apart, at most 45
// a channel, on the composited route and the `pushLayer` one alike, even at
// the origin (#31). Impeller is exact, and so is `FilterQuality.none` on both.
// It is left as it is: the difference is the backdrop's own pixels resampled
// once, under the glass's blur, and the tests pin scaling filters at
// `FilterQuality.none` so they measure the offset rather than the sampler.
//
// Everything built on top of it — the atlas, stopping the descent on an
// opaque cover, substituting platform views, the roles the app declares through
// `GlassProxy` — is a *subtraction* from that pass, so the pass itself must not
// lose content silently.
//
// Deliberately observable: every subtraction and every construct this pass
// cannot reproduce is counted in [WalkLog] rather than assumed away.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'proxy_role.dart';
import 'shadow_filter.dart';

/// What a node is allowed to become in the pass.
///
/// There is no "simplify" step: simplifying content saves 24…28% and costs
/// 0.95…9.6 ΔE, while lowering the proxy resolution saves 47…73% and costs
/// 0.47, so it loses to a knob that already exists, on both axes. What remains
/// is binary, plus the substitution the engine forces for content that cannot
/// be read.
enum WalkAction {
  /// Run the node's own `paint`.
  paint,

  /// Draw nothing and do not descend. Our own glass surfaces (self-capture) and
  /// shadows (0.00 ΔE behind the blur) are the two mandatory members.
  skip,

  /// Draw a placeholder rectangle and do not descend. Platform views and
  /// `Texture` are unreadable by construction — `PlatformViewLayer::Paint`
  /// without an embedder draws nothing and logs an error
  /// (`platform_view_layer.cc:36-41`), so the stock capture leaves a hole there
  /// too.
  substitute,
}

/// Decides, per child, whether the walk paints it, skips it or substitutes a
/// placeholder.
typedef WalkPolicy = WalkAction Function(RenderObject child);

/// The control policy: draw everything, subtract nothing.
///
/// This is the variant the pixel comparison is run against. Any policy that
/// skips or substitutes is only meaningful once this one is known to be exact.
WalkAction paintEverything(RenderObject child) => WalkAction.paint;

/// Everything one pass observed. A fresh instance per pass on purpose: two
/// passes over the same tree are two measurements, not one accumulated.
class WalkLog {
  /// Render objects the pass reached.
  int visited = 0;

  /// Repaint boundaries the pass walked through instead of compositing.
  int boundariesCrossed = 0;

  /// Opacities and image filters the pass applied — the two effects a repaint
  /// boundary carries in `updateCompositedLayer`, where a direct `paint()`
  /// call cannot see them. Zero here on a tree containing an `Opacity` means
  /// the pass dropped its transparency.
  ///
  /// One rule on every route, so the number means the same whichever one a
  /// tree happens to use: an effect is counted when the pass actually applies
  /// it, whether it came off a composited boundary, through `pushOpacity` or
  /// through `pushLayer`. An alpha of 255 and a missing filter apply nothing
  /// and are not counted; an alpha of 0 hides its content and is.
  int compositedEffectsApplied = 0;

  /// Layers this pass had to create because a `push*` return type is
  /// non-nullable and the caller had none to reuse. Each one is parked in
  /// somebody else's field, which is a mutation of the live tree even though
  /// nothing is lost. The invariant is that this stays at zero.
  int layersMinted = 0;

  /// Layer types with no canvas equivalent, so their effect is missing from the
  /// recording. Named rather than counted: which type it is *is* the finding.
  final List<String> unhandledLayers = <String>[];

  /// Reached through `addLayer`, i.e. content that never goes through a canvas.
  final List<String> addedLayers = <String>[];

  /// Nodes the policy replaced with a placeholder, by type.
  final List<String> substituted = <String>[];

  /// Nodes the policy skipped, by type.
  final List<String> skipped = <String>[];

  /// [GlassProxy] markers the pass actually reached, by role.
  ///
  /// Half a counter on its own: compare it against
  /// `RenderGlassProxy.countIn(root)` to tell a marker that fired from one an
  /// ancestor cut off before the pass ever saw it.
  final Map<GlassProxyRole, int> proxyRoles = <GlassProxyRole, int>{};

  /// Colour and image filters flattened while an alpha layer was open above
  /// them.
  ///
  /// The engine folds the alpha into the filter's own `saveLayer`, and the fold
  /// changes that layer's bounds from the cull rect to the content — so a
  /// filter that paints transparent black stops covering the empty area.
  /// Measured: at opacity 1.0 the region is opaque cyan and at 254/255 it is
  /// gone, in the engine's own rendering. This pass keeps it, so a subtree with
  /// a non-zero count here belongs on the `toImageSync` fallback — which does
  /// not exist yet: the pipeline records through this pass whatever the count
  /// says, and the count reaches diagnostics only (#32).
  ///
  /// An image filter is counted for the same reason: `ImageFilterLayer`
  /// accepts its parent's opacity as `ColorFilterLayer` does, and a colour
  /// filter can be handed over as an image filter, alone or composed. Measured
  /// with `Opacity(0.5)` over `ImageFiltered(compose(colour filter, blur))`:
  /// 2116 px differ on Impeller and every pixel by a code value on Skia.
  int opacityFoldedIntoFilter = 0;

  /// Nodes whose `paint` threw. We run foreign code; this is the budget for it.
  final List<String> errors = <String>[];

  /// `createChildContext` calls, which should be none: every branch that would
  /// have asked for one is overridden to stay on this context's canvas.
  final List<String> childContextsRequested = <String>[];

  /// Every counter, keyed for a report.
  Map<String, Object> summary() => <String, Object>{
    'visited': visited,
    'boundaries_crossed': boundariesCrossed,
    'composited_effects_applied': compositedEffectsApplied,
    'layers_minted': layersMinted,
    'opacity_folded_into_filter': opacityFoldedIntoFilter,
    'unhandled_layers': unhandledLayers,
    'added_layers': addedLayers,
    'substituted': substituted,
    'skipped': skipped,
    'proxy_roles': <String, int>{
      for (final MapEntry<GlassProxyRole, int> e in proxyRoles.entries) e.key.name: e.value,
    },
    'errors': errors,
    'child_contexts_requested': childContextsRequested,
  };
}

/// A `PaintingContext` that walks *through* repaint boundaries instead of
/// compositing them, and flattens every layer effect onto its own canvas.
///
/// Three hazards, all handled here rather than hoped about:
///
/// - **`push*` with `oldLayer` writes back into somebody else's field.**
///   `RenderClipRect.paint` does `layer = context.pushClipRect(..., oldLayer:
///   layer as ClipRectLayer?)`, and `LayerHandle`'s setter disposes whatever it
///   held when a *different* layer arrives (`layer.dart:800-812`). Returning a
///   fresh layer from any of these would dispose a layer that is still in the
///   live layer tree. So every override returns the `oldLayer` it was given,
///   and assigning the identical object back is a no-op in the handle.
/// - **`addLayer` bypasses the canvas entirely** — platform views, `Texture`.
///   The method is public and overridden here.
/// - **A direct `paint()` call misses `_paintWithContext`** (`object.dart:3484`):
///   `_needsPaint` is left set, which is correct — the pipeline must not be
///   lied to — and the reentrancy assert is skipped, which is why this belongs
///   in a post-frame callback rather than inside our own `paint`.
class ProxyWalkContext extends PaintingContext {
  /// A context that records into [containerLayer] under [policy], logging to
  /// [log] (a fresh one when null).
  ProxyWalkContext(
    super.containerLayer,
    super.estimatedBounds, {
    WalkLog? log,
    this.policy = paintEverything,
    this.placeholderColor = const ui.Color(0xFF808080),
    this.shadowFilter,
  }) : log = log ?? WalkLog();

  /// What this pass observed.
  final WalkLog log;

  /// What to do with each child the walk reaches.
  final WalkPolicy policy;

  /// The fill of a [WalkAction.substitute] placeholder.
  final ui.Color placeholderColor;

  /// The shadow policy, which does not fit [WalkPolicy].
  ///
  /// A shadow is not a node: it is a `drawShadow` inside a physical model's
  /// `paint`, or a blurred `drawRRect` inside a `BoxDecoration`'s. Skipping the
  /// node that owns it would take the card with it. So the filter sits on the
  /// canvas instead — which is possible because `PaintingContext.canvas` is a
  /// plain getter and `ClipContext` reads the same one.
  final ShadowFilter? shadowFilter;

  FilteringCanvas? _filtered;

  @override
  Canvas get canvas {
    final Canvas inner = super.canvas;
    final ShadowFilter? filter = shadowFilter;
    // `GlassProxy.verbatim` is a subtree-sized hole in the canvas policy, so it
    // has to be applied here rather than at the node: the draws it protects are
    // several frames down somebody else's `paint`, which is the same reason the
    // filter itself does not live on a node.
    if (filter == null || _verbatimDepth > 0) {
      return inner;
    }
    // `PaintingContext` starts a new recording after every layer it pushes, so
    // the wrapper is rebuilt whenever the canvas underneath changes rather than
    // cached once.
    final FilteringCanvas? wrapper = _filtered;
    if (wrapper == null || !identical(wrapper.inner, inner)) {
      return _filtered = FilteringCanvas(inner, filter);
    }
    return wrapper;
  }

  /// Alpha-carrying `saveLayer`s currently open above the cursor.
  ///
  /// The one construct this pass does not reproduce needs both halves: an
  /// opacity below 1.0 *and* a colour or image filter under it. The engine
  /// folds the first into the second (`ColorFilterLayer::Preroll` and
  /// `ImageFilterLayer::Preroll` both advertise `kCallerCanApplyOpacity`) and
  /// the fold changes the filter's bounds from the
  /// cull rect to the content, which deletes everything the filter painted
  /// outside the content. A flattened pass keeps two layers and keeps that
  /// region. Counted rather than fixed: reproducing the fold means knowing
  /// bottom-up what the child will do, and this pass is top-down.
  int _opacityDepth = 0;

  /// Open [GlassProxyRole.verbatim] subtrees above the cursor.
  int _verbatimDepth = 0;

  /// `stopRecordingIfNeeded` is `@protected`, and whoever seeded this context
  /// has to close the recording before the container layer holds a picture.
  void finish() => stopRecordingIfNeeded();

  // ---------------------------------------------------------------------
  // Descent.
  // ---------------------------------------------------------------------

  @override
  void paintChild(RenderObject child, Offset offset) {
    log.visited++;
    if (child.isRepaintBoundary) {
      log.boundariesCrossed++;
    }

    // The policy is consulted for *every* child, before the marker and whatever
    // the marker says, because `OcclusionPolicy` reads paint order out of this
    // call sequence: a short circuit here would make its order check blind
    // exactly where a `GlassProxy` sits.
    WalkAction action = policy(child);

    final RenderGlassProxy? marker = child is RenderGlassProxy ? child : null;
    if (marker != null) {
      log.proxyRoles.update(marker.role, (int n) => n + 1, ifAbsent: () => 1);
    }
    // A node the policy already cut needs no stub: it is invisible either way,
    // and drawing one would cost area for nothing.
    if (marker != null && action == WalkAction.paint) {
      switch (marker.role) {
        case GlassProxyRole.hidden:
          action = WalkAction.skip;
        case GlassProxyRole.replace:
          log.substituted.add('GlassProxy.replace');
          marker.paintProxy(canvas, offset);
          return;
        case GlassProxyRole.opaque:
        case GlassProxyRole.verbatim:
          break;
      }
    }

    switch (action) {
      case WalkAction.skip:
        log.skipped.add(child.runtimeType.toString());
        return;
      case WalkAction.substitute:
        log.substituted.add(child.runtimeType.toString());
        canvas.drawRect(child.paintBounds.shift(offset), ui.Paint()..color = placeholderColor);
        return;
      case WalkAction.paint:
        break;
    }

    final _CanvasEffect? composited = child.isRepaintBoundary ? _compositedEffect(child, offset) : null;

    // A throwing `paint` leaves the save stack unbalanced, and the next node
    // would then draw under somebody else's clip. Recorded, not hidden.
    final int savesBefore = canvas.getSaveCount();
    if (composited != null && composited.carriesAlpha) {
      _opacityDepth++;
    }
    final bool verbatim = marker != null && marker.role == GlassProxyRole.verbatim;
    final _LiveOffsets? live = _LiveOffsets.of(child);
    composited?.begin(canvas);
    // After `begin` and before `end`, so the effect's own save/restore pair is
    // issued through the same canvas at both ends.
    if (verbatim) {
      _verbatimDepth++;
    }
    try {
      // The whole mechanism: `PaintingContext.paintChild`'s `isRepaintBoundary`
      // branch (`object.dart:255`) is never reached, so nothing is composited
      // and nothing is recorded into the child's own layer. `paint` is
      // `@protected`, which is a lint and not a runtime guard.
      // ignore: invalid_use_of_protected_member
      child.paint(this, composited?.childOffset(offset) ?? offset);
    } catch (error) {
      log.errors.add('${child.runtimeType}: $error');
    } finally {
      live?.restore();
      if (verbatim) {
        _verbatimDepth--;
      }
      composited?.end(canvas);
      if (composited != null && composited.carriesAlpha) {
        _opacityDepth--;
      }
      while (canvas.getSaveCount() > savesBefore) {
        canvas.restore();
      }
    }
  }

  /// The effect a repaint boundary carries in `updateCompositedLayer`, which is
  /// invisible to a direct `paint()` call.
  ///
  /// `RenderOpacity.paint` is literally `super.paint` (`proxy_box.dart:947-953`);
  /// all of the alpha lives in `updateCompositedLayer` (`:941`), and that method
  /// is only ever called by `repaintCompositedChild`. A walk that calls `paint`
  /// directly walks past it and the transparency simply disappears.
  ///
  /// The method is public API, so asking the child for a *throwaway* layer and
  /// reading the effect off it needs nothing private, and it covers all three
  /// framework implementations (`RenderOpacity`, `RenderAnimatedOpacityMixin`,
  /// `_RenderImageFiltered`) plus any future one, which a `case RenderOpacity`
  /// would not. The price is one layer allocated and disposed per boundary per
  /// pass, a real share of the pass's CPU cost.
  ///
  /// [offset] is where the boundary is painted, which on screen is the offset
  /// of its layer: `_compositeChild` writes it there and the child paints at
  /// zero inside. The walk paints the child at [offset] instead, so an effect
  /// that is not translation-invariant has to be applied about it.
  _CanvasEffect? _compositedEffect(RenderObject child, Offset offset) {
    final handle = LayerHandle<OffsetLayer>();
    try {
      handle.layer = child.updateCompositedLayer(oldLayer: null);
      final OffsetLayer probe = handle.layer!;
      if (probe is OpacityLayer) {
        final int? alpha = probe.alpha;
        if (alpha == null || alpha == 255) {
          return null;
        }
        log.compositedEffectsApplied++;
        return _SaveLayer(ui.Paint()..color = ui.Color.fromARGB(alpha, 0, 0, 0), carriesAlpha: _live(alpha));
      }
      if (probe is ImageFilterLayer) {
        final ui.ImageFilter? filter = probe.imageFilter;
        if (filter == null) {
          return null;
        }
        _noteFilter();
        log.compositedEffectsApplied++;
        return _FilterAt(offset, ui.Paint()..imageFilter = filter);
      }
      return null;
    } finally {
      // The public way to dispose a layer: `Layer.dispose` is @protected and
      // @visibleForTesting, `LayerHandle` is neither.
      handle.layer = null;
    }
  }

  // ---------------------------------------------------------------------
  // Layer effects, flattened.
  //
  // The clip and transform families already have a non-compositing branch in
  // the framework that does exactly what we want, so these delegate to it with
  // `needsCompositing: false` rather than re-deriving the canvas calls. That is
  // not laziness: `Clip.antiAliasWithSaveLayer` is a `clipRRect` *plus* a
  // `saveLayer` (`painting/clip.dart:29-33`), and a reimplementation that
  // missed it would differ from `toImageSync` only on antialiased edges.
  // ---------------------------------------------------------------------

  @override
  ClipRectLayer? pushClipRect(
    bool needsCompositing,
    Offset offset,
    Rect clipRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.hardEdge,
    ClipRectLayer? oldLayer,
  }) {
    super.pushClipRect(false, offset, clipRect, painter, clipBehavior: clipBehavior);
    return oldLayer;
  }

  @override
  ClipRRectLayer? pushClipRRect(
    bool needsCompositing,
    Offset offset,
    Rect bounds,
    RRect clipRRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipRRectLayer? oldLayer,
  }) {
    super.pushClipRRect(false, offset, bounds, clipRRect, painter, clipBehavior: clipBehavior);
    return oldLayer;
  }

  @override
  ClipRSuperellipseLayer? pushClipRSuperellipse(
    bool needsCompositing,
    Offset offset,
    Rect bounds,
    RSuperellipse clipRSuperellipse,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipRSuperellipseLayer? oldLayer,
  }) {
    super.pushClipRSuperellipse(
      false,
      offset,
      bounds,
      clipRSuperellipse,
      painter,
      clipBehavior: clipBehavior,
    );
    return oldLayer;
  }

  @override
  ClipPathLayer? pushClipPath(
    bool needsCompositing,
    Offset offset,
    Rect bounds,
    Path clipPath,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipPathLayer? oldLayer,
  }) {
    super.pushClipPath(false, offset, bounds, clipPath, painter, clipBehavior: clipBehavior);
    return oldLayer;
  }

  @override
  TransformLayer? pushTransform(
    bool needsCompositing,
    Offset offset,
    Matrix4 transform,
    PaintingContextCallback painter, {
    TransformLayer? oldLayer,
  }) {
    super.pushTransform(false, offset, transform, painter);
    return oldLayer;
  }

  // Opacity and colour filter have no non-compositing branch to borrow: the
  // framework always builds a layer for them. Both are a `saveLayer` at the
  // engine level anyway (`OpacityLayer.addToScene` → `builder.pushOpacity`),
  // so the flattening is exact rather than approximate.

  @override
  OpacityLayer pushOpacity(
    Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    // `PaintingContext.pushOpacity` puts `offset` on the layer and paints the
    // children at zero, so the translate has to happen here.
    final int savesBefore = canvas.getSaveCount();
    // Full alpha folds nothing into a filter below it and a zero alpha leaves
    // nothing to fold into, as through `pushLayer` and a composited boundary:
    // only a live alpha is counted open.
    final bool live = _live(alpha);
    if (live) {
      _opacityDepth++;
    }
    if (alpha < 255) {
      log.compositedEffectsApplied++;
    }
    try {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      // No layer at full alpha, as the engine adds none: an offscreen layer
      // would give a child that blends with what is under it (`clear`,
      // `dstOut`) a transparent backdrop instead of the content it punches
      // through on screen.
      if (alpha < 255) {
        canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromARGB(alpha, 0, 0, 0));
      }
      painter(this, Offset.zero);
    } finally {
      // As in `pushLayer`: a painter that throws must not leave every later
      // filter in the pass counted as folded.
      if (live) {
        _opacityDepth--;
      }
      while (canvas.getSaveCount() > savesBefore) {
        canvas.restore();
      }
    }
    return oldLayer ?? _mint(OpacityLayer());
  }

  @override
  ColorFilterLayer pushColorFilter(
    Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    _noteFilter();
    final int savesBefore = canvas.getSaveCount();
    try {
      canvas.saveLayer(null, ui.Paint()..colorFilter = colorFilter);
      painter(this, offset);
    } finally {
      while (canvas.getSaveCount() > savesBefore) {
        canvas.restore();
      }
    }
    return oldLayer ?? _mint(ColorFilterLayer());
  }

  /// Non-nullable return types force a layer into existence when the caller had
  /// none to reuse. Returning `oldLayer` unchanged is what keeps the live tree
  /// intact; this is the one case where that is not an option, so it is counted
  /// and the count is an invariant rather than a detail.
  T _mint<T extends ContainerLayer>(T layer) {
    log.layersMinted++;
    return layer;
  }

  // ---------------------------------------------------------------------
  // The general routes. Anything that did not come through a typed `push*`
  // arrives here carrying its effect in the layer object itself.
  // ---------------------------------------------------------------------

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    // Deliberately not `super`: `PaintingContext.pushLayer` starts by calling
    // `childLayer.removeAllChildren()` (`object.dart:554-556`), and this layer
    // belongs to a live render object that is *not* repainting. Stripping its
    // children would gut a retained subtree, and the next real frame — which
    // has no reason to repaint it — would composite nothing.
    final _CanvasEffect? effect = _effectOf(childLayer);
    // Live alpha under this layer as under a composited boundary's, or a colour
    // filter below it would not be counted as folded.
    final bool alpha = effect?.carriesAlpha ?? false;
    final int savesBefore = canvas.getSaveCount();
    if (alpha) {
      _opacityDepth++;
    }
    try {
      effect?.begin(canvas);
      painter(this, offset);
      effect?.end(canvas);
    } finally {
      // A painter that throws is caught by the boundary walk above, which
      // would otherwise go on counting every later filter as folded.
      if (alpha) {
        _opacityDepth--;
      }
      while (canvas.getSaveCount() > savesBefore) {
        canvas.restore();
      }
    }
  }

  @override
  void addLayer(Layer layer) {
    // Content that never reaches a canvas: `TextureLayer`, `PlatformViewLayer`.
    // There is nothing to read, so the choice is a placeholder or a hole — and
    // it is a hole, because the stock capture gives a hole and the base level
    // is recorded that way: a level above it that drew a stub would show
    // something the level below did not. On the web every `SelectionArea`
    // stands on one — the browser's context menu, a transparent
    // `HtmlElementView` under the whole selectable region — and a stub there
    // would paint a selectable page grey into the backdrop of every bar over
    // it.
    log.addedLayers.add(layer.runtimeType.toString());
    if (layer is! TextureLayer && layer is! PlatformViewLayer) {
      log.unhandledLayers.add(layer.runtimeType.toString());
    }
  }

  @override
  void appendLayer(Layer layer) {
    // Only reachable from `addLayer`/`pushLayer`, both overridden. If this
    // fires, a route was missed.
    log.unhandledLayers.add('appendLayer:${layer.runtimeType}');
  }

  @override
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    // Same: every caller is overridden. Recorded rather than asserted, because
    // the pass has to survive profile mode where an assert is not there.
    log.childContextsRequested.add(childLayer.runtimeType.toString());
    return this;
  }

  /// The one place this pass is known to diverge from `toImageSync`.
  ///
  /// Conservative on purpose: the engine only folds when the opacity's sole
  /// child advertises that it can absorb one, and this counts every colour or
  /// image filter under any live alpha — a blur that would have survived the
  /// fold included, because Dart cannot ask a filter whether it holds a colour
  /// filter. Over-reporting would send a subtree back to a plain
  /// `toImageSync`, which is the direction a fallback should err in, once
  /// there is one (#32).
  void _noteFilter() {
    if (_opacityDepth > 0) {
      log.opacityFoldedIntoFilter++;
    }
  }

  /// Whether [alpha] is one the engine could fold into a filter below it.
  ///
  /// Neither end is. At 255 there is no alpha to fold; at 0 nothing under it
  /// is drawn at all, in the engine's rendering or in this pass's, so whatever
  /// the fold would have done to a filter's bounds it does to nothing. Counting
  /// either would report a divergence no pixel can show — the rule `Opacity` and `FadeTransition` already obey by
  /// not painting their child at 0.
  ///
  /// The pass still paints the subtree at 0 rather than skipping it as those
  /// two widgets do: its markers are counted and the occlusion policy reads
  /// paint order off the descent, and a subtree that vanished from the walk
  /// would read as one an ancestor cut off.
  static bool _live(int alpha) => alpha > 0 && alpha < 255;

  /// Reads a layer's effect and returns the canvas operation that reproduces
  /// it, or null when there is none to reproduce.
  _CanvasEffect? _effectOf(ContainerLayer layer) {
    switch (layer) {
      case ClipRectLayer():
        final Rect? clip = layer.clipRect;
        return clip == null ? null : _ClipRect(clip, layer.clipBehavior);
      case ClipRRectLayer():
        final RRect? clip = layer.clipRRect;
        return clip == null ? null : _ClipRRect(clip, layer.clipBehavior);
      case ClipRSuperellipseLayer():
        final RSuperellipse? clip = layer.clipRSuperellipse;
        return clip == null ? null : _ClipRSuperellipse(clip, layer.clipBehavior);
      case ClipPathLayer():
        final Path? clip = layer.clipPath;
        return clip == null ? null : _ClipPath(clip, layer.clipBehavior);
      case TransformLayer():
        final Matrix4? m = layer.transform;
        return m == null ? null : _Transform(m);
      case OpacityLayer():
        final int alpha = layer.alpha ?? 255;
        if (alpha == 255) {
          return _OffsetThen(layer.offset, null);
        }
        log.compositedEffectsApplied++;
        return _OffsetThen(
          layer.offset,
          _SaveLayer(ui.Paint()..color = ui.Color.fromARGB(alpha, 0, 0, 0), carriesAlpha: _live(alpha)),
        );
      case ImageFilterLayer():
        final ui.ImageFilter? filter = layer.imageFilter;
        if (filter == null) {
          return null;
        }
        _noteFilter();
        log.compositedEffectsApplied++;
        return _OffsetThen(layer.offset, _SaveLayer(ui.Paint()..imageFilter = filter));
      case ColorFilterLayer():
        final ColorFilter? filter = layer.colorFilter;
        if (filter == null) {
          return null;
        }
        _noteFilter();
        return _SaveLayer(ui.Paint()..colorFilter = filter);
      case ShaderMaskLayer():
        final Shader? shader = layer.shader;
        final Rect? maskRect = layer.maskRect;
        final BlendMode? blend = layer.blendMode;
        if (shader == null || maskRect == null || blend == null) {
          return null;
        }
        if (!_ShaderMask.staysInside.contains(blend)) {
          // Drawn anyway, because inside the children it is the right answer;
          // named, because outside them it paints where the engine does not.
          log.unhandledLayers.add(layer.runtimeType.toString());
        }
        return _ShaderMask(shader, maskRect, blend);
      case LeaderLayer():
        return _OffsetThen(layer.offset, null);
      case OffsetLayer():
        return _OffsetThen(layer.offset, null);
      case AnnotatedRegionLayer<Object>():
        // Pure metadata for hit testing; painting the children inline is exact.
        return null;
      case ContainerLayer() when layer.runtimeType == ContainerLayer:
        return null;
      default:
        // `BackdropFilterLayer` lands here and cannot land anywhere else: a
        // backdrop filter reads what is already on the destination, and
        // `ui.Canvas.saveLayer` has no backdrop parameter — there is no canvas
        // call that reproduces it. `FollowerLayer` lands here too, because its
        // transform is resolved against a leader at composition time.
        log.unhandledLayers.add(layer.runtimeType.toString());
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Canvas effects. Each is a matched save/restore pair so the walk can wrap a
// child in it without knowing what it is.
// ---------------------------------------------------------------------------

/// Where a live layer was before the walk painted the render object that owns
/// it, put back afterwards.
///
/// A render object that keeps its own layer writes its position into it from
/// `paint` and then pushes it: `RenderLeaderLayer` sets `layer.offset`,
/// `RenderFollowerLayer` the follower's offsets. That layer is the one on
/// screen, and the walk calls `paint` with the root's offset rather than the
/// one the layer's parent composites it at — so the write moves the live
/// layer. Unrestored, a `SelectionArea` in a bar (its
/// `CompositedTransformTarget`) shifts the bar's title whenever a level above
/// the bar is captured, and leaves it there until the bar repaints.
final class _LiveOffsets {
  _LiveOffsets._(this._layer, this._offset, this._linked);

  static _LiveOffsets? of(RenderObject owner) {
    // ignore: invalid_use_of_protected_member
    final ContainerLayer? layer = owner.layer;
    return switch (layer) {
      OffsetLayer() => _LiveOffsets._(layer, layer.offset, null),
      LeaderLayer() => _LiveOffsets._(layer, layer.offset, null),
      FollowerLayer() => _LiveOffsets._(layer, layer.unlinkedOffset, layer.linkedOffset),
      _ => null,
    };
  }

  final ContainerLayer _layer;
  final Offset? _offset;
  final Offset? _linked;

  void restore() {
    switch (_layer) {
      case final OffsetLayer layer:
        layer.offset = _offset!;
      case final LeaderLayer layer:
        layer.offset = _offset!;
      case final FollowerLayer layer:
        layer
          ..unlinkedOffset = _offset
          ..linkedOffset = _linked;
    }
  }
}

abstract class _CanvasEffect {
  const _CanvasEffect();

  /// Whether this effect opens a layer whose alpha the engine would be free to
  /// fold into something below it.
  bool get carriesAlpha => false;

  /// Where the content this effect wraps paints, given where it was asked to.
  ///
  /// The same place for every effect but one: [_FilterAt] moves the canvas to
  /// the layer's corner itself, and the content then paints at zero, as it
  /// does inside its own layer on screen.
  Offset childOffset(Offset offset) => offset;

  void begin(Canvas canvas);

  void end(Canvas canvas);
}

class _SaveLayer extends _CanvasEffect {
  const _SaveLayer(this.paint, {this.carriesAlpha = false});

  final ui.Paint paint;

  @override
  final bool carriesAlpha;

  /// Null bounds on purpose: the recorder then infers the layer's extent from
  /// what is drawn inside it, which is what makes a flattened effect identical
  /// to the layer it replaces. Explicit bounds are worse: they move a blur's
  /// edge by one code value over 18 327 pixels instead of 1 383, and they do
  /// not fix the opacity/colour-filter fold, which is not a bounds problem.
  @override
  void begin(Canvas canvas) => canvas.saveLayer(null, paint);

  @override
  void end(Canvas canvas) => canvas.restore();
}

/// An image filter applied in the space of a layer at [offset], with the
/// content it wraps painted at zero inside it.
///
/// The engine translates by an `ImageFilterLayer`'s offset before it applies
/// the filter (`image_filter_layer.cc`), so the filter's origin is the layer's
/// corner. A blur or a translate cannot tell, which is why a bare `saveLayer`
/// passed for them; a scale or a rotation can, and drawn about the canvas's
/// origin it lands the content at the offset scaled.
///
/// The content paints at zero rather than back at [offset] under a translate
/// that undoes this one, and that is not a matter of taste. Skia takes the
/// filter's origin from the transform at the `saveLayer`, so the two spellings
/// agree there; Impeller does not, and measured, the undoing translate inside
/// the layer lands a scaled subtree at half its offset exactly as if there were
/// no translate at all. Painting at zero is also what the content does inside
/// its own layer on screen.
///
/// A filter that resamples is still not byte-exact on Skia at
/// `FilterQuality.low`, at any offset; see the note at the top of this file.
class _FilterAt extends _CanvasEffect {
  const _FilterAt(this.offset, this.paint);

  final Offset offset;
  final ui.Paint paint;

  @override
  Offset childOffset(Offset offset) => Offset.zero;

  @override
  void begin(Canvas canvas) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..saveLayer(null, paint);
  }

  @override
  void end(Canvas canvas) {
    canvas
      ..restore()
      ..restore();
  }
}

class _OffsetThen extends _CanvasEffect {
  const _OffsetThen(this.offset, this.inner);

  final Offset offset;
  final _CanvasEffect? inner;

  @override
  bool get carriesAlpha => inner?.carriesAlpha ?? false;

  @override
  void begin(Canvas canvas) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    inner?.begin(canvas);
  }

  @override
  void end(Canvas canvas) {
    inner?.end(canvas);
    canvas.restore();
  }
}

class _Transform extends _CanvasEffect {
  const _Transform(this.transform);

  final Matrix4 transform;

  @override
  void begin(Canvas canvas) {
    canvas
      ..save()
      ..transform(transform.storage);
  }

  @override
  void end(Canvas canvas) => canvas.restore();
}

/// The clip effects mirror `ClipContext._clipAndPaint` (`painting/clip.dart:15-37`)
/// including the extra `saveLayer` that `Clip.antiAliasWithSaveLayer` adds.
abstract class _Clip extends _CanvasEffect {
  const _Clip(this.behavior, this.bounds);

  final Clip behavior;
  final Rect bounds;

  void applyClip(Canvas canvas, {required bool doAntiAlias});

  @override
  void begin(Canvas canvas) {
    canvas.save();
    switch (behavior) {
      case Clip.none:
        break;
      case Clip.hardEdge:
        applyClip(canvas, doAntiAlias: false);
      case Clip.antiAlias:
        applyClip(canvas, doAntiAlias: true);
      case Clip.antiAliasWithSaveLayer:
        applyClip(canvas, doAntiAlias: true);
        canvas.saveLayer(bounds, ui.Paint());
    }
  }

  @override
  void end(Canvas canvas) {
    if (behavior == Clip.antiAliasWithSaveLayer) {
      canvas.restore();
    }
    canvas.restore();
  }
}

class _ClipRect extends _Clip {
  const _ClipRect(this.rect, Clip behavior) : super(behavior, rect);

  final Rect rect;

  @override
  void applyClip(Canvas canvas, {required bool doAntiAlias}) => canvas.clipRect(rect, doAntiAlias: doAntiAlias);
}

class _ClipRRect extends _Clip {
  _ClipRRect(this.rrect, Clip behavior) : super(behavior, rrect.outerRect);

  final RRect rrect;

  @override
  void applyClip(Canvas canvas, {required bool doAntiAlias}) => canvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
}

class _ClipRSuperellipse extends _Clip {
  _ClipRSuperellipse(this.rse, Clip behavior) : super(behavior, rse.outerRect);

  final RSuperellipse rse;

  @override
  void applyClip(Canvas canvas, {required bool doAntiAlias}) => canvas.clipRSuperellipse(rse, doAntiAlias: doAntiAlias);
}

class _ClipPath extends _Clip {
  _ClipPath(this.path, Clip behavior) : super(behavior, path.getBounds());

  final Path path;

  @override
  void applyClip(Canvas canvas, {required bool doAntiAlias}) => canvas.clipPath(path, doAntiAlias: doAntiAlias);
}

class _ShaderMask extends _CanvasEffect {
  const _ShaderMask(this.shader, this.maskRect, this.blendMode);

  /// The blend modes under which this flattening is exact: the ones that leave
  /// a transparent destination transparent, whatever the shader is.
  ///
  /// The engine's layer covers only the children's paint bounds, and the mask
  /// is drawn inside that layer, so nothing outside what the children painted
  /// can be touched by it. This layer is unbounded — the walk is top-down and
  /// cannot know the children's extent before they paint — so the mask covers
  /// its whole rect, and the two agree only where the mode turns a transparent
  /// destination into a transparent result. Over `D = 0` srcIn, srcATop and
  /// modulate are `S·Da`, dstIn, dstOut and dst are a multiple of `D`, and
  /// clear is nothing: all seven are zero there. Every other mode keeps a
  /// `S·(1 − Da)` term, which is the whole of the source — src, srcOver,
  /// dstOver, srcOut, dstATop, xor, plus, screen and every separable and
  /// non-separable mode after it — and paints the mask across the empty part
  /// of its rect. Those are named as unhandled, so diagnostics show where the
  /// pass and the engine part — the pipeline has no fallback to send them to
  /// yet (#32); the masking modes a `ShaderMask` is nearly always used for are
  /// exact here.
  static const Set<BlendMode> staysInside = <BlendMode>{
    BlendMode.clear,
    BlendMode.dst,
    BlendMode.srcIn,
    BlendMode.dstIn,
    BlendMode.dstOut,
    BlendMode.srcATop,
    BlendMode.modulate,
  };

  final Shader shader;
  final Rect maskRect;
  final BlendMode blendMode;

  @override
  void begin(Canvas canvas) => canvas.saveLayer(null, ui.Paint());

  /// The mask is drawn in its own rect's space, not the layer's: the engine
  /// translates to `maskRect.topLeft` before it draws the shader
  /// (`shader_mask_layer.cc`), and `RenderShaderMask` builds the shader at
  /// `Offset.zero & size` for exactly that. Drawn at `maskRect` in place, a
  /// mask anywhere but the origin reads its gradient shifted by its own
  /// position.
  @override
  void end(Canvas canvas) {
    canvas
      ..save()
      ..translate(maskRect.left, maskRect.top)
      ..drawRect(
        Offset.zero & maskRect.size,
        ui.Paint()
          ..shader = shader
          ..blendMode = blendMode,
      )
      ..restore()
      ..restore();
  }
}
