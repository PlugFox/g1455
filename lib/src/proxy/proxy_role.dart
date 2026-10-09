// What a subtree is, as far as the glass proxy is concerned — declared by the
// application, because the engine cannot report it.
//
// The same shape as `Overlay.opaque`, which exists because opacity is not
// readable from a render tree, and as `CoverDeclaration` in `occlusion.dart`
// (the commonest opaque widget in Flutter, `ColoredBox`, paints through a
// private render object). The engine does not supply the answer; the
// application does.
//
// **What this is not.** Automatic content simplification does not pay:
// replacing text and images with mean-colour blocks saves 24…28% and costs
// 0.95…9.6 ΔE, while lowering the proxy resolution saves 47…73% and costs 0.47,
// so it loses on both axes at once. Nothing here is sold as "cheaper pixels".
// The three things it *is* for:
//
//  - Content that cannot be read at all. A platform view or a `Texture` paints
//    nothing into a recording — `PlatformViewLayer::Paint` without an embedder
//    draws nothing and logs an error (`platform_view_layer.cc:36-41`) — so the
//    stock capture leaves a hole there too. A stub is the only option, not the
//    cheap one.
//  - Retake frequency. A subtree replaced by a stub cannot dirty the proxy, and
//    the retake ceiling is a finish parameter rather than a constant.
//  - Foreign side effects. The pass executes somebody else's `paint()`, so
//    counters, analytics and lazy initialisation in it all happen a second time
//    per frame, and [GlassProxy.hidden] is the only way to stop them.
//
// Nothing here changes the real frame: in the live pipeline every one of these
// is a `RenderProxyBox` that paints its child.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The four declarations, in the order of how much they subtract.
///
/// Each is made with the [GlassProxy] constructor of the same name, and read
/// back from [GlassProxy.role] or [RenderGlassProxy.role].
///
/// | Role | What the capture does with the subtree |
/// |---|---|
/// | [hidden] | Skips it: nothing drawn, its `paint` not run. |
/// | [replace] | Draws a [GlassProxyPainter] in its place. |
/// | [opaque] | Draws it, and treats its box as an occlusion cover. |
/// | [verbatim] | Draws it with the shadow filter off. |
///
/// {@category Capture control}
enum GlassProxyRole {
  /// Not drawn into the proxy, and not descended into: the subtree's `paint`
  /// does not run for the capture, so counters, analytics and lazy
  /// initialisation in it happen once per frame rather than twice.
  ///
  /// Painter's order still holds, so this is a subtraction and not a hole:
  /// whatever painted earlier at that place stays visible. Over a page with an
  /// opaque background the result is the background.
  hidden,

  /// Drawn by a [GlassProxyPainter] instead of by the subtree's own `paint`.
  ///
  /// The only way to put something into the capture where a platform view or
  /// a `Texture` is: those record nothing into it, and glass over them shows
  /// a hole without a stand-in.
  replace,

  /// Paints opaquely over its own box, so the descent may stop before it.
  ///
  /// Read by `OcclusionPlan`, not by the pass: a declaration says "this covers
  /// itself", never "this covers the region" — the geometry decides that;
  /// otherwise every `ColoredBox` in a tree would be a full-screen cover.
  opaque,

  /// Exempt from canvas-level policy inside the subtree.
  ///
  /// Today that policy is exactly the shadow filter, and this exists because
  /// half of it is a heuristic: `ShadowFilter.dropMaskFiltered` drops anything
  /// painted through a `MaskFilter`, which is *usually* a shadow. A design that
  /// blurs a highlight on purpose has no other way to keep it.
  verbatim,
}

/// Draws a stand-in for a subtree in the proxy, for [GlassProxy.replace].
///
/// Deliberately shaped like `CustomPainter`, including the `runtimeType`
/// comparison in front of [shouldRepaint] — this is the same problem and there
/// is no reason to make it look like a different one. Two differences, both
/// deliberate:
///
///  - The canvas is clipped to `size` before [paint] runs. A `CustomPainter`
///    that overdraws produces a visible artefact somebody notices; a stub that
///    overdraws corrupts the backdrop of surfaces elsewhere on the screen, with
///    no visual signal anywhere and no pixel test that would catch it.
///  - [isOpaque] is read, and answering true makes the stub an occlusion cover
///    as well as a substitution.
///
/// [SolidProxyPainter] and [GradientProxyPainter] cover the common cases. A
/// painter of one's own:
///
/// ```dart
/// class MapTilePainter extends GlassProxyPainter {
///   const MapTilePainter(this.land, this.water);
///
///   final Color land;
///   final Color water;
///
///   @override
///   void paint(Canvas canvas, Size size) {
///     canvas
///       ..drawRect(Offset.zero & size, Paint()..color = land)
///       ..drawRect(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4), Paint()..color = water);
///   }
///
///   @override
///   bool shouldRepaint(MapTilePainter oldPainter) => oldPainter.land != land || oldPainter.water != water;
///
///   @override
///   bool get isOpaque => land.a >= 1 && water.a >= 1;
/// }
/// ```
///
/// See also:
///
///  * [GlassProxy.replace], which takes one.
///  * [Capture control on the site](https://g1455.plugfox.dev/foundations/capture).
///
/// {@category Capture control}
abstract class GlassProxyPainter {
  /// Lets subclasses be `const`.
  const GlassProxyPainter();

  /// Paints the stand-in. Local space: the subtree's origin is `Offset.zero`,
  /// exactly as in `CustomPainter`.
  void paint(Canvas canvas, Size size);

  /// Whether the proxy has to be re-recorded because this painter replaced
  /// [oldPainter].
  ///
  /// The retake oracle is what reads this, through
  /// [RenderGlassProxy.proxyChanges]. A painter that always answers false is a
  /// declaration that never dirties the proxy by changing.
  ///
  /// It does not hide the subtree from the host, which watches the composited
  /// layers: a child that composites a new frame — a video, a platform view —
  /// is still a change and still a retake. What the painter decides is what
  /// that retake shows, not whether it happens.
  bool shouldRepaint(covariant GlassProxyPainter oldPainter);

  /// Whether [paint] covers the whole of `size` opaquely.
  ///
  /// The same claim [GlassProxyRole.opaque] makes, and it is unverifiable the
  /// same way. A rounded stub is not opaque: the corners are exactly where a
  /// covered pixel would survive.
  bool get isOpaque => false;
}

/// A stub of one flat colour — the cheapest thing that stands for a subtree.
///
/// Opaque, and so an occlusion cover too, when [color] is.
///
/// {@category Capture control}
class SolidProxyPainter extends GlassProxyPainter {
  /// A stub that fills the subtree's box with [color].
  const SolidProxyPainter(this.color);

  /// The fill. A change repaints the proxy.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, Paint()..color = color);

  @override
  bool shouldRepaint(SolidProxyPainter oldPainter) => oldPainter.color != color;

  @override
  bool get isOpaque => color.a >= 1.0;
}

/// A stub of one gradient. Keeps a local mean where a flat colour would not —
/// which is the axis a blur cannot restore: a low-pass removes what is
/// above its cutoff and cannot bring back a mean that is no longer there.
///
/// Never reported opaque, whatever the gradient's stops are.
///
/// {@category Capture control}
class GradientProxyPainter extends GlassProxyPainter {
  /// A stub that fills the subtree's box with [gradient].
  const GradientProxyPainter(this.gradient);

  /// The fill, stretched over the subtree's box. A change repaints the proxy.
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(GradientProxyPainter oldPainter) => oldPainter.gradient != gradient;
}

/// Declares what its subtree is in the glass proxy.
///
/// One widget for four declarations rather than four widgets, because all four
/// are the same statement — the app telling the proxy something the render tree
/// does not carry — and splitting them would make the caller learn four names to
/// find one.
///
/// **Nesting: the outermost wins, and the inner one is then unreachable.** A
/// [GlassProxy.replace] under a [GlassProxy.hidden] is never visited, because
/// the descent stops at the outer one. That is worth knowing rather than
/// pretending the two compose.
///
/// ## What it changes
///
/// **What the capture sees, not when the host captures.** The host decides
/// when to retake by watching the composited layers, and a declaration does
/// not hide a subtree from that: a video that composites a new frame is still
/// a change, under [GlassProxy.replace] as anywhere. What changes is what the
/// glass shows of it. In the real frame every declaration paints its child as
/// if it were not there.
///
/// | Constructor | Use it for |
/// |---|---|
/// | [GlassProxy.hidden] | Content the glass should not show, or whose `paint` must not run twice. |
/// | [GlassProxy.replace] | A platform view, a `Texture`, or anything the glass should see as something simpler. |
/// | [GlassProxy.opaque] | A box that paints every pixel of itself, so what is under it need not be drawn. |
/// | [GlassProxy.verbatim] | A blurred highlight the shadow filter would drop. |
///
/// > **Note:** A platform view or a `Texture` records nothing into the
/// > capture. Glass over one shows a hole — whatever painted before it, which
/// > is usually the page's background — unless a [GlassProxy.replace] stands
/// > in for it.
///
/// ```dart
/// GlassProxy.replace(
///   painter: const SolidProxyPainter(Color(0xFF1C2B3A)), // the map's mean colour
///   child: const AndroidView(viewType: 'map'),
/// )
/// ```
///
/// See also:
///
///  * [GlassProxyRole], what each declaration does.
///  * [SolidProxyPainter] and [GradientProxyPainter], the stand-ins it ships.
///  * [GlassContentDeclaration], which governs when a proxy may be held.
///  * [Capture control on the site](https://g1455.plugfox.dev/foundations/capture).
///
/// {@category Capture control}
class GlassProxy extends SingleChildRenderObjectWidget {
  /// See [GlassProxyRole.hidden]. The capture skips [child] and does not run
  /// its `paint`; whatever painted earlier at that place shows instead.
  ///
  /// ```dart
  /// GlassProxy.hidden(child: ImpressionTracker(child: banner))
  /// ```
  const GlassProxy.hidden({super.key, required Widget super.child}) : role = GlassProxyRole.hidden, painter = null;

  /// See [GlassProxyRole.replace]. [child] still lays out and still paints into
  /// the real frame; only the proxy sees [painter] instead.
  ///
  /// ```dart
  /// GlassProxy.replace(
  ///   painter: const GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF0B3D2E), Color(0xFF6FA8DC)])),
  ///   child: Texture(textureId: cameraTextureId),
  /// )
  /// ```
  const GlassProxy.replace({super.key, required Widget super.child, required this.painter})
    : role = GlassProxyRole.replace;

  /// See [GlassProxyRole.opaque]. A promise that [child] paints every pixel
  /// of its box opaquely, which makes it an occlusion cover: what is under it
  /// is not drawn into the capture. Nothing checks the promise.
  ///
  /// ```dart
  /// GlassProxy.opaque(child: const ColoredBox(color: Color(0xFFFFFFFF), child: header))
  /// ```
  const GlassProxy.opaque({super.key, required Widget super.child}) : role = GlassProxyRole.opaque, painter = null;

  /// See [GlassProxyRole.verbatim]. [child] is drawn into the capture with
  /// the shadow filter off, so a deliberate `MaskFilter` blur survives.
  ///
  /// ```dart
  /// GlassProxy.verbatim(child: GlowingOrb(color: accent))
  /// ```
  const GlassProxy.verbatim({super.key, required Widget super.child}) : role = GlassProxyRole.verbatim, painter = null;

  /// Which of the four declarations this is, set by the constructor.
  final GlassProxyRole role;

  /// Non-null exactly when [role] is [GlassProxyRole.replace].
  final GlassProxyPainter? painter;

  @override
  RenderGlassProxy createRenderObject(BuildContext context) => RenderGlassProxy(role: role, painter: painter);

  @override
  void updateRenderObject(BuildContext context, RenderGlassProxy renderObject) {
    // Painter first: a role change from `replace` to anything else would
    // otherwise leave the old painter in place for the width of one assignment,
    // and the setters notify.
    renderObject
      ..painter = painter
      ..role = role;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<GlassProxyRole>('role', role))
      ..add(DiagnosticsProperty<GlassProxyPainter>('painter', painter, defaultValue: null));
  }
}

/// The marker the proxy pass reads. In the real frame it is a plain proxy box.
///
/// Being a render object of our own is what keeps the lookup at O(1): the node
/// arrives at `PaintingContext.paintChild` by itself and the pass does one `is`
/// check on it. Any design where the pass *searches* for a declaration pays on
/// every node of the tree instead.
///
/// {@category Capture control}
class RenderGlassProxy extends RenderProxyBox {
  /// A marker declaring [role], with [painter] for [GlassProxyRole.replace].
  RenderGlassProxy({
    GlassProxyRole role = GlassProxyRole.opaque,
    GlassProxyPainter? painter,
    RenderBox? child,
  }) // Not initializing formals: both fields are behind setters that notify,
    // and the constructor must not notify a listener nobody could have
    // attached yet.
    // ignore: prefer_initializing_formals
    : _role = role,
       // ignore: prefer_initializing_formals
       _painter = painter,
       super(child);

  /// The declaration. A change fires [proxyChanges].
  GlassProxyRole get role => _role;
  GlassProxyRole _role;
  set role(GlassProxyRole value) {
    if (value == _role) {
      return;
    }
    _role = value;
    _proxyChanges.notify();
  }

  /// The stand-in drawn under [GlassProxyRole.replace]. A change fires
  /// [proxyChanges] when the new painter is of another type, or its
  /// [GlassProxyPainter.shouldRepaint] says so.
  GlassProxyPainter? get painter => _painter;
  GlassProxyPainter? _painter;
  set painter(GlassProxyPainter? value) {
    final GlassProxyPainter? old = _painter;
    if (identical(old, value)) {
      return;
    }
    _painter = value;
    // `RenderCustomPaint._didUpdatePainter`'s rule (`custom_paint.dart`): a
    // different implementation is a repaint whatever it says about itself,
    // because `shouldRepaint` may only compare against its own kind.
    if (old == null || value == null || value.runtimeType != old.runtimeType || value.shouldRepaint(old)) {
      _proxyChanges.notify();
    }
  }

  /// Fires when this subtree's contribution to the proxy has changed.
  ///
  /// The retake oracle's input, subscribed by `GlassHost` through
  /// `RetakeOracle.watch`. A `Listenable` so that `shouldRepaint` returning
  /// false is distinguishable from `shouldRepaint` never having been called.
  ///
  /// It fires on this subtree's *declaration* changing, which is a role or a
  /// painter. Content that repaints in place under an ordinary widget is
  /// invisible here and says so through `GlassProxyHandle.noteChange`.
  Listenable get proxyChanges => _proxyChanges;
  final _ProxyChanges _proxyChanges = _ProxyChanges();

  /// Draws the stub at [offset], clipped to this box.
  void paintProxy(Canvas canvas, Offset offset) {
    final GlassProxyPainter? p = _painter;
    if (p == null) {
      return;
    }
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..clipRect(Offset.zero & size);
    p.paint(canvas, size);
    canvas.restore();
  }

  /// How many markers of each role the subtree holds.
  ///
  /// The other half of the counters the pass keeps: a marker that is in the tree
  /// and never reached — because an ancestor was hidden, or because the region
  /// does not contain it — is otherwise indistinguishable from one that fired.
  static Map<GlassProxyRole, int> countIn(RenderObject root) {
    final counts = <GlassProxyRole, int>{};
    void visit(RenderObject node) {
      if (node is RenderGlassProxy) {
        counts.update(node.role, (int n) => n + 1, ifAbsent: () => 1);
      }
      node.visitChildren(visit);
    }

    visit(root);
    return counts;
  }

  @override
  void dispose() {
    _proxyChanges.dispose();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<GlassProxyRole>('role', role))
      ..add(DiagnosticsProperty<GlassProxyPainter>('painter', painter, defaultValue: null));
  }
}

/// `ChangeNotifier.notifyListeners` is `@protected`, and this notifier is a
/// field rather than a superclass — a `RenderObject` already has a `dispose`
/// and a listener list of its own, and mixing a second set into it would put
/// two unrelated lifecycles on one object.
class _ProxyChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}
