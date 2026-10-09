// A segmented control whose selection lifts into a glass drop under a finger.
//
// Read off Apple's own `UISegmentedControl` on iOS 26.5, pressed by XCUITest
// on an iPhone 17 Pro simulator (spike 32, `TabBarReferenceTests.testSegments`
// over spike 27's grid, a 360 pt control):
//
//  - the track is **not glass**: a flat fill of (118, 118, 128) at 0.12 —
//    iOS's `tertiarySystemFill` — under which the grid's lines stay sharp
//    (solved from two levels under it: a 0.120–0.124, C 116/118/127);
//  - it is 32 pt tall; the selected segment sits on a white capsule inset
//    2 pt, 86 x 28 on a pitch of 89 — the pitch less 3;
//  - pressed, the capsule becomes a **clear drop** 110 x 44 pt — 12 pt larger
//    across on each side and 8 pt above and below — standing out of the track;
//  - the drop slightly **minifies** what is under it: the grid inside it has a
//    pitch of 0.950 x the undisplaced one across and 0.795 down. Neither a
//    uniform zoom (rms 3.22 px) nor a margin (rms 2.98) explains it well — the
//    rim's own bend dominates a drop this thin — and the margin is the better
//    of the two at 8.7 device px, 2.9 pt ([GlassOptics.widen], as the switch's
//    is: D218);
//  - dragged, it follows the finger; let go, it settles on the segment under
//    it, and that is the selection.
//
// Not taken: the track grew about 9 pt sideways on the frame held still and
// not while dragged — one frame, so not read; the drop disperses at its rim
// and ours does not (D103).
//
// What it costs: at rest, nothing — the track and the capsule are paint, and
// the drop is at presence 0 and captured for nothing. Held, one clear glass
// over a track that is not glass, so **one level**: the capsule fading under
// the drop changes what it shows while it lifts and settles, and those frames
// are captures; while it slides, the labels under it do not change and it
// moves inside its own `GlassTravel` behind its own boundary, so a slide is
// drawn from the proxy already held. Its stretch and squash
// ([GlassDropMotion]) stays inside that region too: down, the region is grown
// by the most the motion reaches; across, where the region is fixed before the
// width is known, the drop is pressed flat against the region's end rather
// than let out of it — so no capture either way, and a relayout of the drop on
// the frames it changes.
//
// Under a horizontal scrollable it claims the pointer on touch-down, as the
// switch and the slider do (`glass_controls.dart`); its gestures are raw
// pointer events, which no arena would otherwise keep from the page.
//
// A keyboard reaches it: the arrow keys select the segment beside the selected
// one, and the focus ring is drawn around the track behind a boundary of its
// own (`glass_focus.dart`). Under `TextDirection.rtl` the segments run right to
// left, and so do the capsule, the drop and the arrows: `_at` is where the
// capsule is *drawn*, a visual index, and only the selection is logical.
//
// A segment is any widget. The selected one is drawn over the white capsule,
// so it is handed an ink that reads there through [IconTheme] and
// [DefaultTextStyle] — which is what a custom glyph (an SVG, an image) reads
// its colour from, as an [Icon] and a [Text] do.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassMinTapTarget;
import 'glass_concentric.dart';
import 'glass_controls.dart' show glassControlClaimsPointer, kGlassDropOptics;
import 'glass_drop_motion.dart';
import 'glass_finish.dart';
import 'glass_focus.dart';
import 'glass_surface.dart';
import 'glass_travel.dart';

/// The track's fill: iOS's `tertiarySystemFill`, read off the simulator as
/// (116–127) at 0.12 (spike 32).
///
/// Not glass: a flat fill, under which what is behind the control stays
/// sharp. [GlassSegmentedControl.trackColor]'s default.
///
/// {@category Panels and controls}
const Color kGlassSegmentTrack = Color.fromRGBO(118, 118, 128, 0.12);

/// How far past the resting capsule the held drop reaches, across and down,
/// logical px (spike 32: 86 x 28 -> 110 x 44).
///
/// 12 across on each side and 8 above and below, so the held drop stands out
/// of the 32 px track.
///
/// {@category Panels and controls}
const Size kGlassSegmentDropGrow = Size(_kGrowX, _kGrowY);
const double _kGrowX = 12;
const double _kGrowY = 8;

/// How much of the backdrop past its box the held drop shows (spike 32: a
/// margin of 2.9 pt is the better of two poor fits).
///
/// The held drop's [GlassOptics.widen], which slightly minifies the segments
/// under it, as the switch's drop does with [kGlassSwitchDropWiden].
///
/// {@category Panels and controls}
const double kGlassSegmentDropWiden = 2.9;

const double _kHeight = 32;
const double _kInset = 2;

/// The control's layout at one width. Pure, so the gesture code, the paint
/// and the layout agree — and read at layout and at paint, never at build:
/// see [_GlassSegmentedControlState.build] for why there is no
/// `LayoutBuilder` here.
@immutable
class _SegmentGeometry {
  _SegmentGeometry(this.width, this.count)
    : pitch = (width - 2 * _kInset) / count,
      capsule = Size(math.max(0, (width - 2 * _kInset) / count - 3), _kHeight - 2 * _kInset);

  final double width;
  final int count;
  final double pitch;
  final Size capsule;

  Size get drop =>
      Size(capsule.width + 2 * kGlassSegmentDropGrow.width, capsule.height + 2 * kGlassSegmentDropGrow.height);

  double centre(double i) => _kInset + pitch * (i + 0.5);

  double indexAt(double x) => ((x - _kInset) / pitch - 0.5).clamp(0.0, count - 1.0);
}

/// How far the held drop reaches past the control's box, per side, plus two
/// for the rounding — the same at every width: across, the drop's growth less
/// the capsule's 1.5 short of the pitch and the inset (12 - 1.5 - 2); down,
/// half of what the drop is taller than the track ((28 + 16 - 32) / 2).
const Size _kMargin = Size(
  _kGrowX - 1.5 - _kInset + 2,
  (_kHeight - 2 * _kInset + 2 * _kGrowY - _kHeight) / 2 + 2,
);

/// [_kMargin] and, down, the most [motion] can squash the held drop — whose
/// height is the same at every width. Across it is not, so a stretch is kept
/// inside the region by [_DropLayout] instead.
Size _marginFor(GlassDropMotion motion) =>
    _kMargin + Offset(0, motion.reach(const Size(0, _kHeight - 2 * _kInset + 2 * _kGrowY)).height);

/// A row of mutually exclusive segments; the selected one lifts into a clear
/// glass drop while a finger is on it. See the file comment for what it costs.
///
/// The labels take the ambient [DefaultTextStyle] and [IconTheme]: the control
/// sits in the content layer, and its track is not glass. The selected one is
/// given an ink that reads on the capsule through the same two, so a segment
/// that is not an [Icon] or a [Text] reads `IconTheme.of(context).color` to
/// match.
///
/// The track is 32 px tall and takes the whole width it is given, split
/// evenly between the segments; the control is laid out [kGlassMinTapTarget]
/// tall so it takes taps above and below the track. A tap selects the segment
/// pressed; a drag carries the drop and selects where it is let go. A focused
/// control selects the segment beside the selected one on an arrow key.
///
/// Under [TextDirection.rtl] the first segment is at the right.
///
/// ```dart
/// GlassSegmentedControl(
///   segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
///   selectedIndex: range,
///   onSelected: (int i) => setState(() => range = i),
/// )
/// ```
///
/// > **Note:** at rest it costs nothing — the track and the capsule are paint.
/// > Held, the drop is one clear glass over a track that is not glass: the
/// > frames where it lifts and settles are captures, and a slide is drawn from
/// > the proxy already held.
///
/// See also:
///
///  * [GlassTabBar], the same drop on a glass bar.
///  * [GlassSwitch], a two-way choice as a switch.
///  * [GlassDropMotion], how the held drop stretches and squashes.
///  * [Segmented control on the site](https://g1455.plugfox.dev/components/segmented-control).
///
/// {@category Panels and controls}
class GlassSegmentedControl extends StatefulWidget {
  /// A control of [segments] — at least two — with [selectedIndex] on the
  /// capsule. [onSelected] null disables it.
  const GlassSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    this.trackColor = kGlassSegmentTrack,
    this.thumbColor = const Color(0xFFFFFFFF),
    this.dropMotion,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(segments.length >= 2);

  /// The control's focus. Null makes one the control owns.
  final FocusNode? focusNode;

  /// Whether the control takes the focus as soon as it is built.
  final bool autofocus;

  /// One widget per segment — a `Text`, an `Icon`.
  final List<Widget> segments;

  /// The selected segment's index into [segments]. The capsule slides to it
  /// when it changes, unless a finger is down on the control.
  final int selectedIndex;

  /// Called with the segment a tap or a drag settles on, when it is not
  /// [selectedIndex]. Null disables the control; it is then drawn at half
  /// opacity.
  final ValueChanged<int>? onSelected;

  /// The track's fill. [kGlassSegmentTrack], iOS's, by default.
  final Color trackColor;

  /// The resting capsule under the selected segment.
  final Color thumbColor;

  /// How the held drop deforms as it launches and brakes. Null takes
  /// [GlassThemeData.dropMotion]; [GlassDropMotion.none] keeps its shape.
  /// Off under reduced motion either way.
  final GlassDropMotion? dropMotion;

  @override
  State<GlassSegmentedControl> createState() => _GlassSegmentedControlState();
}

class _GlassSegmentedControlState extends State<GlassSegmentedControl> with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController.unbounded(vsync: this);
  late final AnimationController _at = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  late final _WhileVisible _capsuleRepaint = _WhileVisible(_lift, _at);
  late final GlassDropStretchDriver _stretch = GlassDropStretchDriver(
    vsync: this,
    position: () => _at.value * (_geometry?.pitch ?? 1),
  );
  GlassDropMotion _motion = GlassDropMotion.none;
  bool _down = false;
  bool _moved = false;
  double _downX = 0;
  int _pressed = 0;
  VelocityTracker? _tracker;
  bool _focused = false;

  /// Under [TextDirection.rtl]; null before the first build has asked.
  bool? _rtl;

  /// Where segment [i] is drawn, counted from the left; and back.
  int _visual(int i) => _rtl ?? false ? widget.segments.length - 1 - i : i;

  // The tab bar's springs and tolerance (glass_tab_bar.dart), for the same
  // reasons: a feel, and a tail that ends under a device pixel.
  static const SpringDescription _liftSpring = SpringDescription(mass: 1, stiffness: 520, damping: 34);
  static const SpringDescription _slideSpring = SpringDescription(mass: 1, stiffness: 380, damping: 36);
  static const Tolerance _tolerance = Tolerance(distance: 0.004, velocity: 0.05);

  bool get _enabled => widget.onSelected != null;

  @override
  void initState() {
    super.initState();
    // Only while there is a drop to deform: the resting capsule keeps its
    // shape and needs no ticker.
    _at.addListener(() => _down || _lift.value > 0 ? _stretch.wake() : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    final bool rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    if (rtl != _rtl) {
      _rtl = rtl;
      // The capsule is placed, not slid: the segments under it just moved.
      if (!_down) {
        _at.value = _visual(widget.selectedIndex).toDouble();
      }
    }
  }

  @override
  void didUpdateWidget(GlassSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    if (!_enabled && _down) {
      _down = false;
      _liftTo(0);
    }
    if (widget.selectedIndex != oldWidget.selectedIndex && !_down) {
      _slideTo(widget.selectedIndex, 0);
    }
  }

  @override
  void dispose() {
    _stretch.dispose();
    _capsuleRepaint.dispose();
    _lift.dispose();
    _at.dispose();
    super.dispose();
  }

  void _liftTo(double target) {
    _lift
        .animateWith(SpringSimulation(_liftSpring, _lift.value, target, _lift.velocity, tolerance: _tolerance))
        .then((_) => _lift.value = target);
  }

  /// Slides the capsule to segment [index] — a selection, not a place.
  void _slideTo(int index, double velocity) {
    final double to = _visual(index).toDouble();
    _at
        .animateWith(SpringSimulation(_slideSpring, _at.value, to, velocity, tolerance: _tolerance))
        .then((_) => _at.value = to);
  }

  /// Selects the segment [steps] from the selected one, toward the end of the
  /// list — rightward, unless the control runs the other way.
  void _select(int steps) {
    final int to = (widget.selectedIndex + steps).clamp(0, widget.segments.length - 1);
    if (to != widget.selectedIndex) {
      widget.onSelected?.call(to);
    }
  }

  void _onDown(PointerDownEvent e) {
    final _SegmentGeometry? g = _geometry;
    if (!_enabled || g == null || _down) {
      return;
    }
    _down = true;
    _moved = false;
    _downX = e.localPosition.dx;
    _tracker = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.localPosition);
    _liftTo(1);
    final int i = _pressed = _visual(g.indexAt(e.localPosition.dx).round());
    _slideTo(i, 0);
  }

  void _onMove(PointerMoveEvent e) {
    final _SegmentGeometry? g = _geometry;
    if (!_down || g == null) {
      return;
    }
    _tracker?.addPosition(e.timeStamp, e.localPosition);
    if (!_moved && (e.localPosition.dx - _downX).abs() < 4) {
      return;
    }
    _moved = true;
    _at.value = g.indexAt(e.localPosition.dx);
  }

  void _onUp(PointerUpEvent e) {
    final _SegmentGeometry? g = _geometry;
    if (!_down || g == null) {
      return;
    }
    _down = false;
    final double velocity = _moved ? (_tracker?.getVelocity().pixelsPerSecond.dx ?? 0) / g.pitch : 0;
    final int i = _moved
        ? _visual((_at.value + velocity * 0.08).round().clamp(0, widget.segments.length - 1))
        : _pressed;
    _slideTo(i, velocity);
    _liftTo(0);
    if (i != widget.selectedIndex) {
      widget.onSelected?.call(i);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (!_down) {
      return;
    }
    _down = false;
    _slideTo(widget.selectedIndex, 0);
    _liftTo(0);
  }

  _SegmentGeometry? get _geometry {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    return _SegmentGeometry(box.size.width, widget.segments.length);
  }

  // **No `LayoutBuilder`, which the tab bar has two of.** A `LayoutBuilder` is
  // a build scope: every tick of an animation built under it schedules its
  // layout, the boundary it sits in relays out and therefore repaints, and
  // here what that boundary paints is the track — content under the drop —
  // so every frame of a slide was a capture (30 of 30 in the first run of the
  // slide arm). The tab bar does not see it because everything its builders
  // repaint is inside the bar's glass. So the width is read where it exists:
  // the capsule is a painter driven by the animations without a build, the
  // drop is placed by a layout delegate, and the gestures read the box.
  @override
  Widget build(BuildContext context) {
    Widget body = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: SizedBox(
        height: math.max(_kHeight, kGlassMinTapTarget.height),
        child: Center(
          child: SizedBox(
            height: _kHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(shape: const StadiumBorder(), color: widget.trackColor),
                  ),
                ),
                GlassFocusRing(visible: _focused && _enabled, radius: kGlassCapsule),
                // The capsule: painted, not built, so it moves without a
                // build — and behind its own boundary.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CapsulePainter(
                        lift: _lift,
                        at: _at,
                        count: widget.segments.length,
                        colour: widget.thumbColor,
                        repaint: _capsuleRepaint,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: RepaintBoundary(child: _labels())),
                Positioned(
                  left: -_marginFor(_motion).width,
                  right: -_marginFor(_motion).width,
                  top: -_marginFor(_motion).height,
                  bottom: -_marginFor(_motion).height,
                  child: _dropStage(_marginFor(_motion)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The control follows the raw pointer and is in no arena, so under a
    // horizontal scrollable the page won the drag and moved with it: both
    // followed the finger. There it claims the pointer on touch-down, as the
    // switch and the slider do — an eager recognizer that wins at once and
    // does nothing else, the `Listener` still doing the work. Elsewhere it
    // stays out of the arena, so a vertical list still scrolls over it.
    // Always the detector, an empty one when not claiming: a wrapper that came
    // and went would rebuild the drop's region under it.
    body = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: _enabled && glassControlClaimsPointer(context)
          ? <Type, GestureRecognizerFactory>{
              EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (EagerGestureRecognizer _) {},
              ),
            }
          : const <Type, GestureRecognizerFactory>{},
      child: body,
    );
    // The arrow along the row selects toward its end: rightward, unless the
    // row runs the other way.
    final int right = _rtl ?? false ? -1 : 1;
    return Semantics(
      container: true,
      enabled: _enabled,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool on) => setState(() => _focused = on),
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): _SelectIntent(right),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _SelectIntent(-right),
        },
        actions: <Type, Action<Intent>>{
          _SelectIntent: CallbackAction<_SelectIntent>(onInvoke: (_SelectIntent intent) => _select(intent.steps)),
        },
        // Segment labels are not text to select, as a button's are not.
        child: SelectionContainer.disabled(child: _enabled ? body : Opacity(opacity: 0.5, child: body)),
      ),
    );
  }

  Widget _labels() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _kInset),
    child: Row(
      children: <Widget>[
        for (var i = 0; i < widget.segments.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == widget.selectedIndex,
              enabled: _enabled,
              onTap: _enabled ? () => widget.onSelected?.call(i) : null,
              child: Center(
                child: i == widget.selectedIndex ? _onThumb(widget.segments[i]) : widget.segments[i],
              ),
            ),
          ),
      ],
    ),
  );

  /// The selected segment's label in a colour that reads on the capsule under
  /// it — black on the white one, white on a dark one — rather than in the
  /// ambient label colour, which on a dark page is the capsule's own white.
  Widget _onThumb(Widget label) {
    final Color thumb = widget.thumbColor;
    final Color ink = thumb.computeLuminance() > 0.4 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return DefaultTextStyle.merge(
      style: TextStyle(color: ink),
      child: IconTheme.merge(
        data: IconThemeData(color: ink),
        child: label,
      ),
    );
  }

  /// The drop's region — the control plus [margin] — and the boundary it
  /// moves behind. Rebuilt on every tick, which is safe here and only here:
  /// no `LayoutBuilder` above it in this control, and the stage is a relayout
  /// boundary (tight constraints), so a tick relays out the drop and nothing
  /// else.
  Widget _dropStage(Size margin) => GlassTravel(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_lift, _at, _stretch]),
        builder: (BuildContext context, Widget? _) => CustomSingleChildLayout(
          delegate: _DropLayout(
            lift: _lift.value,
            at: _at.value,
            count: widget.segments.length,
            margin: margin,
            // Deformed only as far as it has lifted: the drop arriving is round.
            stretch: _stretch.value * _lift.value.clamp(0.0, 1.0),
          ),
          child: GlassSurface(
            borderRadius: kGlassCapsule,
            finish: GlassFinish.clear.copyWith(
              optics: kGlassDropOptics.copyWith(widen: kGlassSegmentDropWiden),
            ),
            // By its optics, not its shape — see `GlassTabBar`'s drop.
            materialize: _lift.value.clamp(0.0, 1.0),
            labelled: false,
          ),
        ),
      ),
    ),
  );
}

/// Selects the segment [steps] from the selected one.
class _SelectIntent extends Intent {
  const _SelectIntent(this.steps);

  final int steps;
}

/// Places the drop in the stage: the stage is the control grown by
/// [margin], so the control's own geometry is read off the stage's size.
class _DropLayout extends SingleChildLayoutDelegate {
  _DropLayout({
    required this.lift,
    required this.at,
    required this.count,
    required this.margin,
    required this.stretch,
  });

  final double lift;
  final double at;
  final int count;
  final Size margin;

  /// See [GlassDropStretch.apply].
  final double stretch;

  _SegmentGeometry _geometry(Size stage) => _SegmentGeometry(stage.width - 2 * margin.width, count);

  /// The drop's box in the stage, and never past it: a drop stretched out of
  /// its travel region would be captured again on every frame it was out, so
  /// at the ends it is pressed flat against the region instead.
  Rect _rect(Size stage) {
    final _SegmentGeometry g = _geometry(stage);
    final Size size = GlassDropStretch.apply(
      Size(
        lerpDouble(g.capsule.width, g.drop.width, lift)!,
        lerpDouble(g.capsule.height, g.drop.height, lift)!,
      ),
      stretch,
    );
    final Rect drop = Rect.fromCenter(
      center: Offset(margin.width + g.centre(at), margin.height + _kHeight / 2),
      width: size.width,
      height: size.height,
    );
    if (stretch == 0) {
      return drop;
    }
    final Rect inside = drop.intersect(Offset.zero & stage);
    return inside.isEmpty ? drop : inside;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tight(_rect(constraints.biggest).size);

  @override
  Offset getPositionForChild(Size size, Size childSize) => _rect(size).topLeft;

  @override
  bool shouldRelayout(_DropLayout oldDelegate) =>
      oldDelegate.lift != lift ||
      oldDelegate.at != at ||
      oldDelegate.count != count ||
      oldDelegate.margin != margin ||
      oldDelegate.stretch != stretch;
}

/// The resting capsule under the selected segment, fading as the drop lifts.
class _CapsulePainter extends CustomPainter {
  _CapsulePainter({
    required this.lift,
    required this.at,
    required this.count,
    required this.colour,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Animation<double> lift;
  final Animation<double> at;
  final int count;
  final Color colour;

  double _fade() => 1 - lift.value.clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final double fade = _fade();
    if (fade <= 0) {
      return;
    }
    final g = _SegmentGeometry(size.width, count);
    final Rect box = Rect.fromCenter(
      center: Offset(g.centre(at.value), size.height / 2),
      width: g.capsule.width,
      height: g.capsule.height,
    );
    // Concentric with the track, 2 in: 14 inside 16. The half side is the
    // capsule a segment narrower than the capsule is tall still needs.
    final RRect shape = RRect.fromRectAndRadius(
      box,
      Radius.circular(math.min(GlassConcentric.radius(_kHeight / 2, _kInset), box.shortestSide / 2)),
    );
    canvas
      ..drawRRect(
        shape.shift(const Offset(0, 1)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.08 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawRRect(shape, Paint()..color = colour.withValues(alpha: colour.a * fade));
  }

  @override
  bool shouldRepaint(_CapsulePainter oldDelegate) =>
      oldDelegate.colour != colour || oldDelegate.count != count || oldDelegate.lift != lift || oldDelegate.at != at;
}

/// Notifies when the capsule's picture would change: while it is visible, and
/// once on the tick it goes. Not `Listenable.merge(lift, at)`, which repaints
/// on every tick of a slide with the capsule gone — and every repaint mints a
/// picture the layer watch must call a change, even an empty one: the second
/// cause of the slide arm's 30 captures in 30 frames.
class _WhileVisible extends ChangeNotifier {
  _WhileVisible(this.lift, this.at) {
    lift.addListener(_tick);
    at.addListener(_tick);
  }

  final Animation<double> lift;
  final Animation<double> at;
  bool _wasVisible = true;

  void _tick() {
    final bool visible = lift.value < 1;
    if (visible || _wasVisible) {
      notifyListeners();
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    lift.removeListener(_tick);
    at.removeListener(_tick);
    super.dispose();
  }
}
