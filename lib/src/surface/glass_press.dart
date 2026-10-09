// A glass control that swells under the finger, leans toward it while the
// finger drags, and springs back when it lets go.
//
// **Read off nothing.** iOS 26's interactive glass does this and no spike here
// has measured it: S4 photographed the material at rest, and the held frames
// D217 took are the switch's and the slider's drops, not a button's. Another
// package grows the longest side by a fixed ~17 logical px (1.3x a 56 circle,
// 1.13x a 132 pill), which is a hypothesis about the *shape* of the law — a
// fixed growth, not a fixed ratio — and that shape is what is taken here. The
// amount is not: 17 on the package's own 44 px tap target is 1.39x, more than
// any held drop the package has read (1.57x is a knob becoming a lens, not a
// panel swelling), so the default is 12 and a spec with a zero, like
// [GlassDropMotion].
//
// What it costs, by construction — asserted in `glass_press_test.dart` and
// `glass_press_region_test.dart`:
//
//  - **two captures a press, and none while it moves.** The glass grows
//    inside a travel region declared around it, whose capture is the region
//    and not the glass's box, so the capture input does not move while the
//    glass does (D208's mechanism). The region is the resting box grown by
//    [GlassPress.margin] — the most the spec can reach — so nothing it draws
//    leaves it. It is declared **from touch-down until the spring settles**,
//    and its coming and going are a capture each;
//  - **no repaint of anything but the glass.** The glass is laid out inside a
//    render object that is a relayout *and* repaint boundary of its own, so a
//    frame of the press relays out the glass and re-records a layer that holds
//    nothing but the glass's own — never a picture under it. Not a
//    `LayoutBuilder` and not a `Transform`: the first relays out its ancestors
//    and repaints whatever boundary they are in (the segmented control paid 30
//    captures in 30 frames for one); the second scales the glass's draw but
//    not the map into its slot, which `RenderGlassSurface` takes from its
//    global rect unscaled;
//  - a slot that is the region rather than the box, while a press is under
//    way — and only then. Declared always, the region cost every enabled
//    button its slot again at rest: 7056 logical px² against 3600 for a 44 px
//    button, 5981 a button in a row of five, for zero captures a press. On
//    demand the resting slot is the box's, exactly a button without a press,
//    for one capture as the region appears and one as it goes. And no frame
//    of the swell is drawn from the old slot: the spring's first tick is at
//    rest, so the frame that declares the region draws the glass at its box
//    and the capture taken after it is in place before the glass grows —
//    checked pixel for pixel against the always-declared arm, frame by frame;
//  - the rim reads a little past the box's bleed, so a larger slot changes it
//    by a few code values on a few pixels: the always-declared arm drew a
//    resting button differently from one with no press (22 channels over 2 at
//    dpr 2). On demand it does not;
//  - a ticker while the spring moves, none at rest or while a finger holds
//    still.
//
// Off under reduced motion, and with [GlassPress.none] — and then the control
// builds no region, no boundary and no ticker: the tree it always built.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'glass_theme.dart';
import 'glass_travel.dart';

/// How a pressed glass control responds: it grows by [grow] while held, and
/// leans up to [maxPull] toward a finger that drags, stretched up to
/// [maxStretch] along the drag and squashed across it.
///
/// Read by [GlassButton] from [GlassThemeData.press] unless the button names
/// its own. [none] turns it off, and so does the platform's reduced-motion
/// switch.
///
/// A feel rather than a measurement — see the numbers on each field. It costs
/// two captures a press and none while the glass moves: the glass grows inside
/// a travel region declared around it ([margin] past its box) from touch-down
/// until the spring settles, behind a boundary of its own. At rest it costs
/// nothing.
///
/// ```dart
/// // No swell on one button, and a gentler one everywhere else.
/// GlassButton(press: GlassPress.none, onPressed: save, child: const Text('Save'))
///
/// GlassHost(press: const GlassPress(grow: 8), child: navigator!)
/// ```
///
/// See also:
///
///  * [GlassDropMotion], the same kind of spec for a control's held drop.
///  * [GlassTravel], the declaration that makes the growth free.
///
/// {@category Foundations}
@immutable
class GlassPress {
  /// A press with the package's defaults: 12 px of growth on the longest side,
  /// up to 3 px of lean and 5% of stretch toward the finger, on a spring with
  /// a damping ratio of about 0.6.
  const GlassPress({
    this.grow = 12,
    this.maxStretch = 0.05,
    this.maxPull = 3,
    this.pullReach = 12,
    this.stiffness = 500,
    this.damping = 26,
  }) : assert(grow >= 0),
       assert(maxStretch >= 0 && maxStretch <= 0.25),
       assert(maxPull >= 0),
       assert(pullReach > 0),
       assert(stiffness > 0),
       assert(damping >= 0);

  /// No response at all: the control keeps its box, and builds no region for
  /// it.
  static const GlassPress none = GlassPress(grow: 0, maxStretch: 0, maxPull: 0);

  /// The most the press's spring is allowed to carry the growth past full, as
  /// a fraction of [grow] — the overshoot [margin] reserves room for. The
  /// default spring overshoots by about 10%.
  static const double maxOvershoot = 1.15;

  /// How much longer the longest side is while held, logical px; the shorter
  /// side grows by the same factor. A fixed amount rather than a ratio, which
  /// is the hypothesis borrowed (see the file comment): 12 is 1.27x a 44 px
  /// circle and 1.09x a 132 px pill.
  final double grow;

  /// The most the glass stretches along a drag, as a fraction: at 0.05 it is
  /// up to 5% longer toward the finger and 1/1.05 as thick across — the area
  /// is kept.
  final double maxStretch;

  /// The most the glass's centre moves toward a dragging finger, logical px.
  final double maxPull;

  /// How far the finger has to drag, logical px, for the lean and the stretch
  /// to reach three quarters of their most (`tanh(1)`). The default reaches
  /// about 90% at Flutter's touch slop, 18 px, past which a tap is cancelled
  /// and the glass springs back.
  final double pullReach;

  /// The spring the growth and the lean follow, at unit mass.
  final double stiffness;

  /// The spring's damping, at unit mass. See [stiffness].
  final double damping;

  /// Whether this responds to nothing.
  bool get isNone => grow == 0 && maxStretch == 0 && maxPull == 0;

  /// [none] when [context] asks for reduced motion; this otherwise.
  GlassPress orNoneUnderReducedMotion(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? none : this;

  /// The press a control in [context] uses: its own [declared], else the
  /// theme's — and [none] either way under reduced motion.
  static GlassPress resolve(BuildContext context, GlassPress? declared) =>
      (declared ?? GlassTheme.of(context).press).orNoneUnderReducedMotion(context);

  /// Where the glass of a control resting at [rest] is drawn, in the resting
  /// box's coordinates, at [press] (0 at rest, 1 held — more or less while the
  /// spring overshoots) with the finger [finger] px from where it came down.
  ///
  /// Pure, so a custom control and a test can ask it. Never outside the
  /// resting box grown by [margin], and never smaller than the resting box on
  /// either side: the label is laid out inside the glass, and a spring's
  /// undershoot or a squash below the resting size overflowed a label that
  /// fills its button.
  Rect rect(Size rest, double press, Offset finger) {
    final Rect box = Offset.zero & rest;
    if (isNone || rest.isEmpty) {
      return box;
    }
    final double p = press.clamp(1 - maxOvershoot, maxOvershoot);
    final double k = 1 + grow * p / rest.longestSide;
    final double distance = finger.distance;
    final double reach = _tanh(distance / pullReach);
    final Offset towards = distance == 0 ? Offset.zero : finger / distance;
    final double sx = maxStretch * reach * towards.dx.abs();
    final double sy = maxStretch * reach * towards.dy.abs();
    return Rect.fromCenter(
      center: box.center + towards * (maxPull * reach),
      width: math.max(rest.width, rest.width * k * (1 + sx) / (1 + sy)),
      height: math.max(rest.height, rest.height * k * (1 + sy) / (1 + sx)),
    );
  }

  /// How far past a resting box of [rest] the glass can reach, per side —
  /// across and down: the growth at [maxOvershoot], stretched, and the lean,
  /// plus one for the rounding. What the control's travel region adds to its
  /// box, and so what the press costs the atlas while it is on: for the
  /// defaults, 12.3 px a side on a 44 px circle, and 14.5 across by 7.5 down
  /// on a 132 x 44 pill.
  ///
  /// Per axis, because the shorter side grows by the same factor and so by
  /// less: one margin for both would hold a pill's region twice as tall as
  /// its glass can reach.
  Size margin(Size rest) {
    if (isNone || rest.isEmpty) {
      return Size.zero;
    }
    // The most either side is multiplied by: the growth at its overshoot,
    // times a stretch along that side (whose squash only shrinks the other).
    final double k = (1 + grow * maxOvershoot / rest.longestSide) * (1 + maxStretch);
    return Size(rest.width * (k - 1) / 2 + maxPull + 1, rest.height * (k - 1) / 2 + maxPull + 1);
  }

  /// This press with the named fields replaced.
  GlassPress copyWith({
    double? grow,
    double? maxStretch,
    double? maxPull,
    double? pullReach,
    double? stiffness,
    double? damping,
  }) => GlassPress(
    grow: grow ?? this.grow,
    maxStretch: maxStretch ?? this.maxStretch,
    maxPull: maxPull ?? this.maxPull,
    pullReach: pullReach ?? this.pullReach,
    stiffness: stiffness ?? this.stiffness,
    damping: damping ?? this.damping,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassPress &&
      other.grow == grow &&
      other.maxStretch == maxStretch &&
      other.maxPull == maxPull &&
      other.pullReach == pullReach &&
      other.stiffness == stiffness &&
      other.damping == damping;

  @override
  int get hashCode => Object.hash(grow, maxStretch, maxPull, pullReach, stiffness, damping);

  @override
  String toString() => isNone
      ? 'GlassPress.none'
      : 'GlassPress(grow $grow, stretch ${maxStretch.toStringAsFixed(2)}, pull $maxPull over $pullReach, '
            'spring $stiffness/$damping)';

  static double _tanh(double x) {
    if (x > 20) {
      return 1;
    }
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}

/// Builds a pressed control's glass inside a travel region of its own; with
/// it off, nothing but the glass. A `@visibleForTesting` seam: the press
/// test's negative control turns the region off and watches the capture count
/// move.
@visibleForTesting
bool debugGlassPressTravel = true;

/// Declares a pressed control's region while it is at rest too, rather than
/// only from touch-down until its spring settles. A `@visibleForTesting` seam:
/// the arm the on-demand default was measured against.
@visibleForTesting
bool debugGlassPressRegionAtRest = false;

/// The region a pressed control's glass grows in: the resting box of
/// [RenderGlassPressBody], grown by the press's [GlassPress.margin] at that size.
///
/// A [GlassTravelRegion] that answers for itself instead of through a
/// [RenderGlassTravel], because the box it describes is larger than anything
/// laid out: the control's own box has to stay the resting one.
class _PressRegion extends GlassTravelRegion {
  RenderGlassPressBody? _body;
  Size _margin = Size.zero;

  /// Whether the region is declared now; when not, the glass is captured at
  /// its own box, as if there were no region at all.
  bool declared = true;

  @override
  Rect? get globalRect {
    final RenderGlassPressBody? body = _body;
    if (!declared || body == null || !body.attached || !body.hasSize) {
      return null;
    }
    final Size m = _margin;
    return MatrixUtils.transformRect(
      body.getTransformTo(null),
      Rect.fromLTRB(-m.width, -m.height, body.size.width + m.width, body.size.height + m.height),
    );
  }
}

/// A control's glass, grown and leaned by [press] at [value] with the finger
/// [finger] px from where it came down — inside a travel region of its own.
///
/// The control's layout is [child]'s at rest whatever the press does: what
/// places it places the resting box, and the glass is drawn past it.
class GlassPressStage extends StatefulWidget {
  /// The glass of [child] responding to [value] and [finger] under [press].
  const GlassPressStage({
    required this.press,
    required this.value,
    required this.finger,
    required this.child,
    this.active = true,
    super.key,
  });

  /// Whether the press is under way — held, or springing back — on this
  /// build: the travel region is declared only then. At rest the glass is
  /// its box, and is captured at its box.
  final bool active;

  /// The spec. Must not be [GlassPress.none]: a control with none builds
  /// [child] alone.
  final GlassPress press;

  /// 0 at rest, 1 held; past either end while the spring overshoots.
  final double value;

  /// The finger from where it came down, logical px — already scaled toward
  /// zero by whatever springs it back.
  final Offset finger;

  /// The glass, and what is on it.
  final Widget child;

  @override
  State<GlassPressStage> createState() => _GlassPressStageState();
}

class _GlassPressStageState extends State<GlassPressStage> {
  final _PressRegion _region = _PressRegion();

  @override
  Widget build(BuildContext context) {
    _region.declared = widget.active || debugGlassPressRegionAtRest;
    final Widget body = _PressStage(
      press: widget.press,
      region: _region,
      child: _PressBody(press: widget.press, value: widget.value, finger: widget.finger, child: widget.child),
    );
    return debugGlassPressTravel ? GlassTravelScope(region: _region, child: body) : body;
  }
}

class _PressStage extends SingleChildRenderObjectWidget {
  const _PressStage({required this.press, required this.region, required Widget super.child});

  final GlassPress press;
  final _PressRegion region;

  @override
  _RenderPressStage createRenderObject(BuildContext context) => _RenderPressStage(press, region);

  @override
  void updateRenderObject(BuildContext context, _RenderPressStage renderObject) {
    renderObject
      ..press = press
      ..region = region;
  }
}

class _PressBody extends SingleChildRenderObjectWidget {
  const _PressBody({required this.press, required this.value, required this.finger, required Widget super.child});

  final GlassPress press;
  final double value;
  final Offset finger;

  @override
  RenderGlassPressBody createRenderObject(BuildContext context) => RenderGlassPressBody(press, value, finger);

  @override
  void updateRenderObject(BuildContext context, RenderGlassPressBody renderObject) {
    renderObject
      ..press = press
      ..value = value
      ..finger = finger;
  }
}

/// The constraints of the stage's measuring pass: the control's own, in a type
/// that never equals the resting box's tight ones, so the body lays out again
/// after it even when the two describe the same size.
class _MeasureConstraints extends BoxConstraints {
  _MeasureConstraints(BoxConstraints c)
    : super(minWidth: c.minWidth, maxWidth: c.maxWidth, minHeight: c.minHeight, maxHeight: c.maxHeight);

  BoxConstraints get plain =>
      BoxConstraints(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight);
}

/// The control's footprint: the glass's resting size, measured by laying the
/// body out under the control's constraints, and then the body laid out again
/// as a boundary at exactly that size.
///
/// Two layouts of the glass on a frame the control itself relays out, which is
/// a frame its label or its constraints changed; none on a frame of the press.
class _RenderPressStage extends RenderProxyBox {
  _RenderPressStage(this._press, this._region);

  GlassPress _press;
  set press(GlassPress value) {
    if (value == _press) {
      return;
    }
    _press = value;
    markNeedsLayout();
  }

  _PressRegion _region;
  set region(_PressRegion value) {
    if (identical(value, _region)) {
      return;
    }
    if (identical(_region._body, child)) {
      _region._body = null;
    }
    _region = value;
    markNeedsLayout();
  }

  @override
  void detach() {
    if (identical(_region._body, child)) {
      _region._body = null;
    }
    super.detach();
  }

  @override
  void performLayout() {
    final RenderBox? body = child;
    if (body == null) {
      size = constraints.smallest;
      return;
    }
    body.layout(_MeasureConstraints(constraints), parentUsesSize: true);
    final Size rest = constraints.constrain(body.size);
    // Tight and unused: the body is now a relayout boundary, so a frame of the
    // press relays out the body and stops there.
    body.layout(BoxConstraints.tight(rest));
    size = rest;
    _region
      .._body = body is RenderGlassPressBody ? body : null
      .._margin = _press.margin(rest);
  }
}

/// The glass's frame: a relayout and repaint boundary at the resting size,
/// laying its child out at the pressed size and drawing it past its own box.
///
/// Not exported: public so that a test can read [pressLayouts].
class RenderGlassPressBody extends RenderProxyBox {
  RenderGlassPressBody(this._press, this._value, this._finger);

  GlassPress _press;
  set press(GlassPress value) {
    if (value == _press) {
      return;
    }
    _press = value;
    _relayoutForPress();
  }

  double _value;
  set value(double v) {
    if (v == _value) {
      return;
    }
    _value = v;
    _relayoutForPress();
  }

  Offset _finger;
  set finger(Offset v) {
    if (v == _finger) {
      return;
    }
    _finger = v;
    _relayoutForPress();
  }

  /// Where the child is drawn in this box.
  Offset _childOffset = Offset.zero;

  /// How many times this box was laid out for the press alone — the trace of
  /// the boundary, without which a press that relaid out the whole screen
  /// would pass every pixel arm.
  @visibleForTesting
  int pressLayouts = 0;

  bool _forPress = false;

  @override
  bool get isRepaintBoundary => true;

  void _relayoutForPress() {
    _forPress = true;
    markNeedsLayout();
    _forPress = false;
  }

  @override
  void markNeedsLayout() {
    // From below — the label changed, or the child was replaced — the resting
    // size may have changed, and only the stage measures it: on past this
    // boundary to it. Only the press's own change stops here.
    if (!_forPress && parent != null) {
      markParentNeedsLayout();
      return;
    }
    super.markNeedsLayout();
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    final BoxConstraints c = constraints;
    if (c is _MeasureConstraints) {
      child?.layout(c.plain, parentUsesSize: true);
      size = c.constrain(child?.size ?? Size.zero);
      _childOffset = Offset.zero;
      return;
    }
    size = c.biggest;
    if (child == null) {
      return;
    }
    if (!_afterMeasure) {
      pressLayouts++;
    }
    final Rect drawn = _press.rect(size, _value, _finger);
    // Not tight, by a hair: a child laid out tight is a relayout boundary of
    // its own, and a label that changed under it would relay out inside the
    // old box and never reach the stage that measures it.
    child.layout(
      BoxConstraints(
        minWidth: drawn.width,
        maxWidth: drawn.width + _kSlack,
        minHeight: drawn.height,
        maxHeight: drawn.height + _kSlack,
      ),
      parentUsesSize: true,
    );
    _childOffset = drawn.center - child.size.center(Offset.zero);
    _afterMeasure = false;
  }

  /// Set when the stage measured this box, so the layout that follows is not
  /// counted as the press's.
  bool _afterMeasure = true;

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    if (constraints is _MeasureConstraints) {
      _afterMeasure = true;
    }
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  static const double _kSlack = 1e-3;

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) {
      context.paintChild(child, offset + _childOffset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) {
      return false;
    }
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('press', _value))
      ..add(DiagnosticsProperty<Offset>('finger', _finger))
      ..add(DiagnosticsProperty<GlassPress>('spec', _press));
  }
}
