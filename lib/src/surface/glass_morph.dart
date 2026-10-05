// One glass that becomes another: a button turning into its menu, a pill into
// a panel. The child is swapped and the glass flows to the new child's size.
//
// **Built on the group's smooth union, and only while it moves.** Mid-morph
// the glass is two shapes of one liquid: the *body* — the glass the old child
// sat on, its size following the spring towards the new one — and a *bud*, a
// capsule of the size the body is about to have, held at the same corner and
// running ahead of it. Where the bud is ahead the fold pulls the body after
// it, so the outline has a neck between the old shape and the new one; that
// is the picture an `AnimatedContainer` cannot draw, and it costs a group:
// two shapes folded in one fused draw. At rest none of it exists — the morph
// is a lone `GlassSurface` holding its child.
//
// **The body is one render object for the whole life of the widget**, at rest
// and mid-morph, carried between the two trees by a `GlobalKey`. That is not
// tidiness. A capture is keyed by the surface it was taken for and taken after
// the frame, so a surface mounted on a frame has no slot on that frame and
// draws nothing: a body rebuilt at every start and end would blink out for a
// frame each time. Kept, it reads the slot it already has.
//
// Both ends are exact, which is why the bud and not the body is the shape that
// comes and goes. At the start the bud is at presence zero, which changes no
// pixel of a fold (D209). After that it is never less than `k` inside its own
// outline (`GlassSurface.presence` is a field offset, so that is a presence),
// and a shape `k` inside another changes no pixel either — so where it shares
// the held corner's edges with the body it never swells them, and at the end,
// no larger than the body, it can be dropped without a pixel changing. What is
// left is the body at the new size: the very surface the morph rests as.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'glass_finish.dart';
import 'glass_group.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';
import 'glass_tier.dart';
import 'glass_travel.dart';

/// The spacing a morph's union is folded at, in logical pixels — the default
/// of [GlassMorph.spacing].
///
/// Sixteen, the spacing the presence arms were measured at (D209), which is a
/// blend radius of 32: a neck of a few dozen pixels between a 44-pt button and
/// the panel it opens, thick enough to read as liquid and short of the swell a
/// wider fold puts on every edge (`k / 4` where two edges coincide).
///
/// {@category Composition}
const double kGlassMorphSpacing = 16;

/// How a [GlassMorph] moves: a spring, by its perceptual duration and bounce.
///
/// SwiftUI's `spring(duration:bounce:)`, through
/// [SpringDescription.withDurationAndBounce], which is the same arithmetic.
/// The spring drives the body's size; the cross-fade and the bud are timed
/// off the same progress, so a slower spring slows all of it together.
///
/// ```dart
/// GlassMorph(
///   motion: const GlassMorphMotion(duration: Duration(milliseconds: 350), bounce: 0.1),
///   child: child,
/// )
/// ```
///
/// {@category Composition}
@immutable
class GlassMorphMotion {
  /// A spring that takes roughly [duration], overshooting by [bounce].
  const GlassMorphMotion({required this.duration, this.bounce = 0})
    : assert(bounce > -1 && bounce < 1, 'A bounce of ±1 never settles.');

  /// The default: fluid, with a little overshoot — the glass lands slightly
  /// past its new size and settles back, which is what makes it read as
  /// liquid rather than as a resized box. For controls and menus.
  static const GlassMorphMotion fluid = GlassMorphMotion(duration: Duration(milliseconds: 450), bounce: 0.18);

  /// Critically damped and a little slower: no overshoot. For large panels,
  /// where a bounce of the same proportion is tens of pixels of the screen
  /// moving twice.
  static const GlassMorphMotion calm = GlassMorphMotion(duration: Duration(milliseconds: 550));

  /// Roughly how long the morph takes — for a bouncy spring, its period.
  final Duration duration;

  /// From 0 (no overshoot) towards 1 (more); negative values are overdamped.
  final double bounce;

  /// The spring this describes.
  SpringDescription get spring => SpringDescription.withDurationAndBounce(duration: duration, bounce: bounce);

  @override
  bool operator ==(Object other) => other is GlassMorphMotion && other.duration == duration && other.bounce == bounce;

  @override
  int get hashCode => Object.hash(duration, bounce);
}

/// A piece of glass that flows to the size of whatever child it is given.
///
/// Swap the [child] for one of a different identity — another type, or the
/// same type with another [Key], exactly the rule [AnimatedSwitcher] follows —
/// and the glass grows or shrinks to the new child while the old content
/// fades out and the new fades in. The way a button becomes its menu in
/// iOS 26:
///
/// ```dart
/// Align(
///   alignment: Alignment.topRight, // holds the corner the morph holds
///   child: GlassMorph(
///     alignment: Alignment.topRight,
///     borderRadius: isOpen ? const BorderRadius.all(Radius.circular(24)) : kGlassCapsule,
///     child: isOpen
///         ? MenuPanel(key: const ValueKey<String>('menu'), onClose: () => setState(() => isOpen = false))
///         : IconButton(
///             key: const ValueKey<String>('button'),
///             onPressed: () => setState(() => isOpen = true),
///             icon: const Icon(Icons.more_horiz),
///           ),
///   ),
/// )
/// ```
///
/// A child of the same identity is updated in place, as in any widget: no
/// morph, and the glass takes its new size at once. A change of [width],
/// [height] or [borderRadius] alone does morph, with nothing to cross-fade.
///
/// **No size is typed.** The glass measures the child: each one is laid out
/// against the morph's own constraints, loosened, and the glass is that size —
/// which is why [width] and [height] are overrides and not inputs. Each pins
/// one axis: the child is laid out at exactly that width or height, the glass
/// is that wide or tall, and the other axis is still measured.
///
/// **One frame of measurement.** The new child is laid out for the first time
/// on the frame it is swapped in, and that frame draws the morph at its start
/// — the old glass, the new content transparent — so the motion is visible
/// from the next frame. Nothing is ever drawn at a size that was not measured.
///
/// ## Alignment: what holds still
///
/// [alignment] is the point of the glass that **does not move relative to the
/// morph's own box** while the glass changes size. `Alignment.topRight` keeps
/// the top-right corners of the old and new glass together and grows the rest
/// down and to the left; `Alignment.center` grows evenly about the middle;
/// `Alignment.centerLeft` holds the left edge's midpoint.
///
/// The morph's box is itself the glass's current size, placed by its parent —
/// as [AnimatedSize]'s is — so what holds still *on the screen* is decided by
/// both, and this is the mistake that gets made: a morph inside a [Center]
/// grows from its centre whatever [alignment] says, because [Center] moves the
/// box to keep it centred. To hold a corner on screen, put the morph where its
/// parent holds the same corner — `Align(alignment: Alignment.topRight)`, a
/// [Positioned] with `top` and `right`, the end of a [Row] — and give it the
/// same [alignment]. The bud is placed by [alignment] too, so a mismatch also
/// sends the neck the wrong way.
///
/// The default, [Alignment.center], is the one that cannot surprise a parent
/// that centres; a morph from a control anchored in a corner wants that
/// corner.
///
/// ## The picture
///
/// Mid-morph the glass is two shapes in a [GlassGroup] at [spacing]: the
/// *body*, which follows the spring from the old size to the new, and a *bud*
/// — a capsule held at the same [alignment], at the size the body is about to
/// have — running ahead of it. Where the bud leads, the fold pulls the body
/// after it: a rounded front with a waist where it meets the body's straighter
/// edges, which closes as the body catches up. The bud is held at least the
/// blend radius inside its own outline, so it never bulges past the held
/// corner and is invisible by the time the body arrives.
///
/// Only a morph that **grows** on some axis has a bud; one that shrinks on
/// both is the body receding, with the cross-fade — the new shape is inside
/// the old one, and there is nothing for glass to run ahead into.
///
/// Content is clipped to the body, not to the bud: the glass leads, the
/// content follows the size. The old content fades out over the first half of
/// the spring's progress and the new fades in over the second.
///
/// A swap mid-morph starts again from where the glass is: the body from its
/// current size and radius, the content from its current opacity, an earlier
/// bud fading out from where it was. Nothing jumps, but the spring's velocity
/// is not carried: the new morph starts from rest. Up to [kMaxFusedShapes]
/// shapes can be in flight — the body and eleven buds of swaps in quick
/// succession; the oldest are dropped past that, which is the one way to make
/// the outline jump.
///
/// ## When there is no neck
///
/// The union is drawn only when it can be, and otherwise the morph is the body
/// alone — a plain resize with the cross-fade, which is what
/// `AnimatedContainer` would draw:
///
///  - for a morph that shrinks on both axes (above);
///  - at [spacing] zero, which is how to ask for that on purpose;
///  - below [GlassTier.full], where a group does not fuse and two overlapping
///    flat panels would tint their overlap twice;
///  - while the platform asks for reduced motion
///    (`MediaQuery.disableAnimationsOf`) — and then there is no motion at all:
///    the new child and its size arrive on the frame they are swapped in.
///
/// ## What it costs
///
/// **At rest, a lone [GlassSurface]:** no group, no fused draw, no capture of
/// its own beyond any surface's. The group exists only while the glass moves.
///
/// **While it moves, a capture per frame, and that is the honest price.** The
/// body changes size on every frame of the spring, so the capture's input
/// changes on every frame — the same price as animating
/// [GlassSurface.materialize], and the reason the motion is short. The fused
/// draw adds about 0.030 cycles per device pixel per shape over the pixels it
/// covers (D169, see [GlassGroup]) — two shapes, while the morph lasts, plus
/// the capture's own reach for the bridge (`k` times the fold's depression,
/// a quarter of `k` for two shapes).
///
/// Forming the union is a few captures of its own whatever is declared — the
/// swap, the bud joining the register, the layer watch settling on the group
/// that now holds the body: the first five frames, measured, after which a
/// declared region (below) holds.
///
/// A [GlassTravel] directly around the morph buys nothing: its region is its
/// own box, which here is the morph's box and changes with it. One around an
/// ancestor of **fixed** size that holds every size the morph takes — a slot in
/// a toolbar, a `SizedBox` in a corner of a `Stack` — is a region that does not
/// move, and then the morph moves on the proxy already held, as a slider's
/// drop does; the content the morph covers must not repaint for that to hold
/// (see [GlassTravel]). The bud and the overshoot must stay inside the region.
///
/// ## Limits
///
/// One level of glass: the morph is not a [GlassAbove], nor is it meant to
/// morph across levels — a bar becoming a sheet that stands on other glass is
/// two widgets. It is its own group, so it cannot share a silhouette with
/// neighbours in an enclosing [GlassGroup] while it moves; at rest it is a
/// member of that group like any surface. Content under an [Opacity] mid-fade
/// is composited through a layer, which glass inside the content does not
/// survive (D185) — the content is meant to be labels and icons. Hit testing
/// follows the body: mid-morph only the new child is hit, and only where the
/// body has reached.
///
/// See also:
///
///  * [GlassMorphMotion], the spring.
///  * [GlassGroup], the fused draw it borrows while it moves.
///  * [GlassMenuAnchor], a menu that grows out of its button in the overlay
///    rather than in place.
///  * [The morph on the site](https://g1455.plugfox.dev/components/morph).
///
/// {@category Composition}
class GlassMorph extends StatefulWidget {
  /// Glass that holds [child] and flows to the size of each new one.
  const GlassMorph({
    required this.child,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.motion = GlassMorphMotion.fluid,
    this.spacing = kGlassMorphSpacing,
    this.finish,
    this.labelled = true,
    this.onEnd,
    super.key,
  }) : assert(width == null || width >= 0),
       assert(height == null || height >= 0),
       assert(spacing >= 0);

  /// What the glass holds, and what it measures. A child of another identity
  /// ([Widget.canUpdate] false) starts a morph.
  final Widget child;

  /// The point of the glass that holds still in the morph's box while the
  /// size changes. **Read the class's section on it**: on screen, the parent
  /// has to hold the same point.
  final AlignmentGeometry alignment;

  /// Pins the glass's width, and lays the child out at exactly it. Null
  /// measures the child.
  final double? width;

  /// Pins the glass's height, and lays the child out at exactly it. Null
  /// measures the child.
  final double? height;

  /// The corner radii of the glass around this child; a change morphs.
  /// [kGlassCapsule] makes a pill at any size, and a morph between a capsule
  /// and a panel moves the radius with the size.
  final BorderRadius borderRadius;

  /// The spring. [GlassMorphMotion.fluid] by default; [GlassMorphMotion.calm]
  /// for large panels.
  final GlassMorphMotion motion;

  /// The [GlassGroup.spacing] of the union while the glass moves: how far the
  /// neck reaches. Zero morphs without a union — the body alone, no neck, no
  /// group even mid-morph.
  final double spacing;

  /// The optics, or null for the host's.
  final GlassFinish? finish;

  /// See [GlassSurface.labelled].
  final bool labelled;

  /// Called when a morph has settled and the glass is a lone surface again.
  final VoidCallback? onEnd;

  @override
  State<GlassMorph> createState() => _GlassMorphState();
}

/// A child the morph holds, with what it was given when it arrived.
class _Entry {
  _Entry(this.child, this.width, this.height, this.radius);

  Widget child;
  double? width;
  double? height;
  BorderRadius radius;

  /// The opacity it starts the current morph from.
  double opacity0 = 1;

  /// Keys its place among the contents, so its state survives the others
  /// coming and going.
  late final Key key = ObjectKey(this);
}

/// A capsule arriving ahead of the body, towards the new size.
class _Bud {
  _Bud({required this.leading, this.presence0 = 0, this.size});

  /// The bud of the morph in flight; false for one left over from a morph a
  /// swap interrupted, which only fades.
  final bool leading;

  /// Where a left-over bud fades from: its presence and size when the swap
  /// came. The leading bud's are functions of the progress.
  final double presence0;
  final Size? size;

  late final Key key = ObjectKey(this);
}

/// What the layout measured, kept for the build that follows it.
class _MorphGeometry {
  /// The body's last size: where a morph that starts now starts from.
  Size? body;

  /// The current child's measured size, and which child it was measured for.
  Size? current;
  Object? currentTag;
}

class _GlassMorphState extends State<GlassMorph> with SingleTickerProviderStateMixin<GlassMorph> {
  late final AnimationController _progress = AnimationController.unbounded(vsync: this, value: 1);

  /// Keeps the body one render object at rest and mid-morph; see the file
  /// comment for why that is load-bearing.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'GlassMorph body');
  final _MorphGeometry _geometry = _MorphGeometry();

  /// The children, oldest first; the last is the current one.
  late List<_Entry> _entries = <_Entry>[_Entry(widget.child, widget.width, widget.height, widget.borderRadius)];
  List<_Bud> _buds = const <_Bud>[];

  /// Where the body started: null at rest.
  Size? _from;
  BorderRadius _fromRadius = BorderRadius.zero;
  int _generation = 0;

  bool get _morphing => _from != null;
  _Entry get _current => _entries.last;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GlassMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _Entry current = _current;
    if (Widget.canUpdate(current.child, widget.child)) {
      current.child = widget.child;
      if (current.width == widget.width && current.height == widget.height && current.radius == widget.borderRadius) {
        return;
      }
      _start(current);
      return;
    }
    // A child coming back while it is still fading out is revived rather than
    // mounted twice: its state is still there, and so would be a GlobalKey.
    final _Entry? revived = _entries.where((_Entry e) => Widget.canUpdate(e.child, widget.child)).firstOrNull;
    final _Entry next = revived ?? _Entry(widget.child, widget.width, widget.height, widget.borderRadius);
    if (revived != null) {
      revived.child = widget.child;
    }
    _start(next);
  }

  /// The widget's pins and radius, onto the entry it now shows.
  void _pin(_Entry next) => next
    ..width = widget.width
    ..height = widget.height
    ..radius = widget.borderRadius;

  void _start(_Entry next) {
    final Size? body = _geometry.body;
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) || body == null) {
      // Reduced motion, or a swap before the first layout: arrive at once.
      _pin(next);
      _settle(next, notify: false);
      return;
    }
    final double t = _morphing ? _progress.value : 1;
    // The leading bud is shaped by the outgoing child's size, read before it
    // stops being the current one.
    final Size? measured = _measuredCurrent;
    // Everything starts again from where it is, so an interrupted morph does
    // not jump: the body from its size and radius, the content from its
    // opacity, the buds from their presence. Read before the new pins land:
    // a morph that keeps its child is [next] and [_current] at once, and a
    // radius read after would start where it is going.
    _fromRadius = _morphing ? _bodyRadius(t) : _resolve(_current.radius, body);
    _pin(next);
    for (final _Entry e in _entries) {
      e.opacity0 = _morphing ? _opacity(e, t) : (identical(e, _current) ? 1 : 0);
    }
    if (!_entries.contains(next)) {
      next.opacity0 = 0;
    }
    _entries = <_Entry>[
      for (final _Entry e in _entries)
        if (!identical(e, next) && e.opacity0 > 0) e,
      next,
    ];
    _buds = <_Bud>[
      if (_morphing)
        for (final _Bud b in _buds)
          if (_budAt(b, t, measured) case (:final Size size, :final double presence))
            _Bud(leading: false, presence0: presence, size: size),
      _Bud(leading: true),
    ];
    // The body is one shape of the fold: the rest is what one draw carries.
    if (_buds.length > kMaxFusedShapes - 1) {
      _buds = _buds.sublist(_buds.length - (kMaxFusedShapes - 1));
    }
    _from = body;
    final int generation = ++_generation;
    _progress
      ..stop()
      ..value = 0;
    _progress.animateWith(SpringSimulation(widget.motion.spring, 0, 1, 0)).then((_) {
      if (mounted && generation == _generation) {
        setState(() => _settle(_current, notify: true));
      }
    });
  }

  /// Back to rest: [current] alone, on a lone surface.
  void _settle(_Entry current, {required bool notify}) {
    _generation++;
    _progress
      ..stop()
      ..value = 1;
    current.opacity0 = 1;
    _entries = <_Entry>[current];
    _buds = const <_Bud>[];
    _from = null;
    if (notify) {
      widget.onEnd?.call();
    }
  }

  /// The current child's measured size, once the layout has measured it.
  Size? get _measuredCurrent => identical(_geometry.currentTag, _current) ? _geometry.current : null;

  // --- The timing, all off the spring's progress, clamped. ---------------

  static const Curve _fadeOut = Interval(0, 0.5, curve: Curves.easeIn);
  static const Curve _fadeIn = Interval(0.5, 1, curve: Curves.easeOut);
  static const Curve _budIn = Interval(0, 0.3, curve: Curves.easeOut);
  static const Curve _budLead = Curves.easeOutCubic;

  double _opacity(_Entry e, double t) {
    final double c = t.clamp(0.0, 1.0);
    return identical(e, _current)
        ? e.opacity0 + (1 - e.opacity0) * _fadeIn.transform(c)
        : e.opacity0 * (1 - _fadeOut.transform(c));
  }

  /// The size and presence [b] is drawn at, at progress [t] — or null when it
  /// draws nothing: before the new child is measured, and for a morph that
  /// grows on neither axis, where a bud would lead from inside the body and
  /// could never show.
  ///
  /// **The leading bud** is a capsule of the size the body will have a little
  /// later — the same lerp on an ease-out of the progress, so it runs ahead —
  /// held at a field offset of at least `k` inside its own outline. That
  /// floor is what makes both ends exact. Where the body's edge and the bud's
  /// are `k` or more apart the fold's `h` is exactly zero, so along the edges
  /// the two share — the held corner's — the bud never swells the outline, and
  /// at the end, the bud no larger than the body, it is invisible to the bit
  /// and can be dropped without a pixel changing. Between, it shows only where
  /// it is ahead of the body by more than the floor: on the sides that grow.
  /// A capsule because an offset deeper than a corner's radius squares the
  /// corner off — the level sets of a stadium are stadiums.
  ({Size size, double presence})? _budAt(_Bud b, double t, Size? to) {
    final double c = t.clamp(0.0, 1.0);
    if (!b.leading) {
      final double presence = b.presence0 * (1 - _fadeOut.transform(c));
      return presence > 0 ? (size: b.size!, presence: presence) : null;
    }
    final Size? from = _from;
    if (from == null || to == null || (to.width <= from.width && to.height <= from.height)) {
      return null;
    }
    final Size size = Size.lerp(from, to, _budLead.transform(c))!;
    final double blend = 2 * widget.spacing;
    // [RenderGlassSurface.presenceInset] at presence zero, for this size.
    final double absent = size.shortestSide / 2 + 2 * blend + 1;
    // Half a pixel past `k`, against rounding in `(1 - p)^2`.
    final double floor = blend + 0.5;
    if (floor >= absent) {
      return null;
    }
    final double inset = floor + (absent - floor) * (1 - _budIn.transform(c));
    return (size: size, presence: 1 - math.sqrt(inset / absent));
  }

  BorderRadius _bodyRadius(double t) {
    final Size? to = _measuredCurrent;
    if (to == null) {
      return _fromRadius;
    }
    return BorderRadius.lerp(_fromRadius, _resolve(_current.radius, to), t.clamp(0.0, 1.0))!;
  }

  /// [radius] as the engine draws it on [size] — scaled to fit, as
  /// [RenderGlassSurface.shape] does — so that a capsule lerps from its real
  /// radius and not from 1e9.
  static BorderRadius _resolve(BorderRadius radius, Size size) {
    final RRect r = radius.toRRect(Offset.zero & size).scaleRadii();
    return BorderRadius.only(
      topLeft: r.tlRadius,
      topRight: r.trRadius,
      bottomLeft: r.blRadius,
      bottomRight: r.brRadius,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (BuildContext context, Widget? _) => _frame(context, _morphing ? _progress.value : 1),
  );

  Widget _frame(BuildContext context, double t) {
    final bool morphing = _morphing;
    final Size? measured = _measuredCurrent;
    final buds = <(_Bud, Size, double)>[
      if (morphing && widget.spacing > 0)
        for (final _Bud b in _buds)
          if (_budAt(b, t, measured) case (:final Size size, :final double presence)) (b, size, presence),
    ];
    final bool union =
        buds.isNotEmpty &&
        GlassTheme.of(context).tier.tier.readsBackdrop &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final AlignmentGeometry alignment = widget.alignment;
    final _Entry current = _current;
    final Widget body = GlassSurface(
      key: _bodyKey,
      borderRadius: morphing ? _bodyRadius(t) : current.radius,
      // A fused member draws the group's optics, and one that names its own
      // is reported as a declaration the picture cannot honour.
      finish: union ? null : widget.finish,
      labelled: widget.labelled,
      child: _MorphContent(
        geometry: _geometry,
        alignment: alignment,
        from: _from,
        progress: t,
        pins: <(double?, double?)>[for (final _Entry e in _entries) (e.width, e.height)],
        currentTag: current,
        children: <Widget>[
          for (final _Entry e in _entries)
            KeyedSubtree(
              key: e.key,
              child: IgnorePointer(
                ignoring: !identical(e, current),
                child: ExcludeSemantics(
                  excluding: !identical(e, current),
                  child: Opacity(opacity: morphing ? _opacity(e, t) : 1, child: e.child),
                ),
              ),
            ),
        ],
      ),
    );
    if (!union) {
      return body;
    }
    return GlassGroup(
      spacing: widget.spacing,
      finish: widget.finish,
      labelled: widget.labelled,
      child: _MorphStage(
        alignment: alignment,
        budSizes: <Size>[for (final (_, Size size, _) in buds) size],
        children: <Widget>[
          for (final (_Bud b, _, double presence) in buds)
            GlassSurface(
              key: b.key,
              borderRadius: kGlassCapsule,
              presence: presence,
              labelled: widget.labelled,
            ),
          // Last: its content paints over the group's glass, and it is hit
          // first.
          body,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The content: every child measured, the body's size lerped between them.
// ---------------------------------------------------------------------------

/// Lays every child out against its own constraints loosened, and is the
/// body: the current child's size, or — mid-morph — the size the spring has
/// reached between [from] and it. The children are placed by [alignment] in
/// it and clipped to it.
///
/// It measures *inside* the body because a glass surface is sized by its
/// child, and the constraints it is handed are the morph's own whether the
/// body is at rest or in a group's stage: the stage passes them through.
class _MorphContent extends MultiChildRenderObjectWidget {
  const _MorphContent({
    required this.geometry,
    required this.alignment,
    required this.from,
    required this.progress,
    required this.pins,
    required this.currentTag,
    required super.children,
  });

  final _MorphGeometry geometry;
  final AlignmentGeometry alignment;
  final Size? from;
  final double progress;
  final List<(double?, double?)> pins;
  final Object currentTag;

  @override
  _RenderMorphContent createRenderObject(BuildContext context) => _RenderMorphContent(geometry)
    ..alignment = alignment.resolve(Directionality.maybeOf(context))
    ..from = from
    ..progress = progress
    ..pins = pins
    ..currentTag = currentTag;

  @override
  void updateRenderObject(BuildContext context, _RenderMorphContent renderObject) => renderObject
    ..geometry = geometry
    ..alignment = alignment.resolve(Directionality.maybeOf(context))
    ..from = from
    ..progress = progress
    ..pins = pins
    ..currentTag = currentTag;
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMorphContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderMorphContent(this.geometry);

  _MorphGeometry geometry;

  Alignment _alignment = Alignment.center;
  set alignment(Alignment value) {
    if (value != _alignment) {
      _alignment = value;
      markNeedsLayout();
    }
  }

  Size? _from;
  set from(Size? value) {
    if (value != _from) {
      _from = value;
      markNeedsLayout();
    }
  }

  double _progress = 1;
  set progress(double value) {
    if (value != _progress) {
      _progress = value;
      markNeedsLayout();
    }
  }

  List<(double?, double?)> _pins = const <(double?, double?)>[];
  set pins(List<(double?, double?)> value) {
    if (!listEquals(value, _pins)) {
      _pins = value;
      markNeedsLayout();
    }
  }

  Object? currentTag;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  /// [constraints] loosened, with the pinned axes tight.
  BoxConstraints _childConstraints(BoxConstraints constraints, int index) {
    final (double? width, double? height) = index < _pins.length ? _pins[index] : (null, null);
    var c = constraints.loosen();
    if (width != null) {
      c = c.tighten(width: constraints.constrainWidth(width));
    }
    if (height != null) {
      c = c.tighten(height: constraints.constrainHeight(height));
    }
    return c;
  }

  Size _body(BoxConstraints constraints, Size to) {
    final Size? from = _from;
    if (from == null) {
      return constraints.constrain(to);
    }
    // Unclamped: the spring's overshoot is the glass landing past its size.
    final Size lerped = Size.lerp(from, to, _progress)!;
    return constraints.constrain(Size(math.max(0, lerped.width), math.max(0, lerped.height)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? last = lastChild;
    if (last == null) {
      return constraints.smallest;
    }
    return _body(constraints, last.getDryLayout(_childConstraints(constraints, childCount - 1)));
  }

  @override
  void performLayout() {
    RenderBox? child = firstChild;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    var index = 0;
    Size to = Size.zero;
    while (child != null) {
      child.layout(_childConstraints(constraints, index), parentUsesSize: true);
      to = child.size;
      child = childAfter(child);
      index++;
    }
    size = _body(constraints, to);
    geometry
      ..body = size
      ..current = to
      ..currentTag = currentTag;
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _MorphParentData;
      parentData.offset = _alignment.inscribe(child.size, Offset.zero & size).topLeft;
      child = parentData.nextSibling;
    }
  }

  bool get _overflows {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _MorphParentData;
      if (!(Offset.zero & size).contains(parentData.offset) ||
          parentData.offset.dx + child.size.width > size.width + 1e-6 ||
          parentData.offset.dy + child.size.height > size.height + 1e-6) {
        return true;
      }
      child = parentData.nextSibling;
    }
    return false;
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_overflows) {
      _clip.layer = null;
      defaultPaint(context, offset);
      return;
    }
    // The content follows the body, not the bud: the glass leads.
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      size.contains(position) && defaultHitTestChildren(result, position: position);

  double _intrinsic(double Function(RenderBox child) of, double? pin) {
    final RenderBox? last = lastChild;
    if (pin != null) {
      return pin;
    }
    return last == null ? 0 : of(last);
  }

  (double?, double?) get _currentPins => _pins.isEmpty ? (null, null) : _pins.last;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsic((RenderBox c) => c.getMinIntrinsicWidth(height), _currentPins.$1);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsic((RenderBox c) => c.getMaxIntrinsicWidth(height), _currentPins.$1);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsic((RenderBox c) => c.getMinIntrinsicHeight(width), _currentPins.$2);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsic((RenderBox c) => c.getMaxIntrinsicHeight(width), _currentPins.$2);

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// The stage: the body and its buds, inside the group, while the glass moves.
// ---------------------------------------------------------------------------

/// The body (the last child) laid out against the morph's own constraints,
/// and the buds placed by [alignment] in the body's box at their own sizes —
/// past it, where the glass leads. The stage is the body's size: the buds
/// overflow it, which a glass may (see [GlassGroup]) and which only hit
/// testing notices.
class _MorphStage extends MultiChildRenderObjectWidget {
  const _MorphStage({
    required this.alignment,
    required this.budSizes,
    required super.children,
  });

  final AlignmentGeometry alignment;

  /// One per bud, in order.
  final List<Size> budSizes;

  @override
  _RenderMorphStage createRenderObject(BuildContext context) => _RenderMorphStage()
    ..alignment = alignment.resolve(Directionality.maybeOf(context))
    ..budSizes = budSizes;

  @override
  void updateRenderObject(BuildContext context, _RenderMorphStage renderObject) => renderObject
    ..alignment = alignment.resolve(Directionality.maybeOf(context))
    ..budSizes = budSizes;
}

class _RenderMorphStage extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  Alignment _alignment = Alignment.center;
  set alignment(Alignment value) {
    if (value != _alignment) {
      _alignment = value;
      markNeedsLayout();
    }
  }

  List<Size> _budSizes = const <Size>[];
  set budSizes(List<Size> value) {
    if (!listEquals(value, _budSizes)) {
      _budSizes = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => lastChild?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  void performLayout() {
    final RenderBox? body = lastChild;
    if (body == null) {
      size = constraints.smallest;
      return;
    }
    // The body first: laying it out is what measures the current child.
    body.layout(constraints, parentUsesSize: true);
    size = body.size;
    (body.parentData! as _MorphParentData).offset = Offset.zero;
    RenderBox? child = firstChild;
    var index = 0;
    while (child != null && !identical(child, body)) {
      final Size bud = index < _budSizes.length ? _budSizes[index] : size;
      child.layout(BoxConstraints.tight(bud));
      (child.parentData! as _MorphParentData).offset = _alignment.inscribe(bud, Offset.zero & size).topLeft;
      child = childAfter(child);
      index++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? body = lastChild;
    return body != null && body.hitTest(result, position: position);
  }
}
