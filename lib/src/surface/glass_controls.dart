// Controls whose knob turns into a glass drop while it is held: a switch and a
// slider.
//
// What the drop is was read off Apple's own controls rather than chosen
// (spike 27). A held `NSSwitch` / `NSSlider` on macOS 27 is a **clear** drop —
// no tint, no blur — that bends the backdrop in a band at its rim and leaves the
// middle exactly where it was: the grid lines through the centre of the drop
// sat on the undisplaced grid to the half pixel, so there is no magnification
// and nothing here needs an optics axis the finish does not have. It is
// 1.4–1.6x the resting knob. At rest the knob is an opaque white capsule and
// not glass at all. On iOS, pressed by a finger (D217), both drops are 1.57x;
// the slider's does not magnify either, but the **switch's minifies** — ×0.85
// across and ×0.79 down, which is one margin of 5 pt drawn into the drop
// rather than one zoom (D218), and is `GlassOptics.widen` on its finish.
//
// Three mechanisms carry it, each built and tested on its own:
//
//  - the drop is a [GlassSurface] at `presence` 0 at rest — drawing nothing and
//    **captured for nothing**, so a screen full of switches costs the atlas
//    nothing, and the clear finish's divisor nothing, until one is held;
//  - it grows and fades in through `presence`, which is a field offset and
//    costs no capture;
//  - it moves inside a [GlassTravel] region behind its own repaint boundary, so
//    a drag is drawn from the proxy already held;
//  - it stretches as it launches and squashes as it brakes
//    ([GlassDropMotion]) inside that same region, grown by the most the
//    motion can reach — a repaint of the drop's own layer, and no capture.
//
// What is *not* free is content that changes under the drop. The switch's track
// changes colour only when the value commits, so a drag costs one capture when
// the drop appears and none while it moves. The slider's fill ends under the
// drop and follows it, so every frame of a slider drag is a real change under
// glass and is retaken — the honest price, stated rather than hidden.
//
// **Who gets the finger.** Under a horizontal scrollable — a `PageView`, a
// carousel — a control claims the pointer the moment it comes down
// ([_ClaimingDragRecognizer]): the drop lifts on that frame rather than after
// the tap's 100 ms timeout or the drag's slop, and the page never sees the
// gesture. Anywhere else it competes as it always did, because under a
// vertical list a vertical swipe that starts on a switch is a scroll, and a
// control that won every arena it touched would take it. Drags measure from
// where the finger came down (`DragStartBehavior.down`), so the knob does not
// jump by the slop.
//
// A keyboard reaches both: Space or Enter toggles the switch, the arrow keys
// step the slider, and the focus ring is drawn where no capture sees it
// (`glass_focus.dart`). Under `TextDirection.rtl` both mirror: the switch is on
// to the left and the slider fills from the right.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassMinTapTarget;
import 'glass_drop_motion.dart';
import 'glass_finish.dart';
import 'glass_focus.dart';
import 'glass_surface.dart';
import 'glass_travel.dart';

/// How much larger a held drop is than the resting knob, by default.
///
/// iOS 26: 1.57x for both the switch and the slider, read off the device's own
/// screenshots under a finger (D217). macOS 27 differs per control — 1.4x the
/// slider, 1.6x the switch (D210) — which is why the controls take it as
/// `dropScale`.
///
/// {@category Panels and controls}
const double kGlassDropScale = 1.57;

/// How far past its own box the held switch's drop shows, logical px — the
/// iOS switch's drop minifies what is under it (×0.85 across, ×0.79 down on a
/// 58 × 38 pt drop), which is this one margin rather than one zoom (D218). The
/// slider's drop, read the same way, does not minify, and its default is 0.
/// See [GlassOptics.widen].
///
/// {@category Panels and controls}
const double kGlassSwitchDropWiden = 5;

/// The optics of a held drop, which are not the material's.
///
/// Read off iOS's slider drop under a finger (D217's frames, D218): the grid
/// moves 2.1–2.5 device px — 1.15 pt — at 2.7–3 pt in from the rim and not
/// at all from 10 pt in. The material's optics move it ~28 pt at 3 pt in,
/// which on a drop 38 pt tall is the whole drop folded: a tab bar's label
/// under it came out as an hourglass. So: a reach of 10, and the amplitude
/// that puts 1.15 pt at 3 pt in on the material's own curve shape (whose
/// exponents two readings cannot identify, and are borrowed).
///
/// Shared by every drop in the package — the switch's, the slider's, the
/// segmented control's and the tab bar's — each of which adds its own
/// [GlassOptics.widen] or [GlassOptics.zoom] to it.
///
/// {@category Panels and controls}
const GlassOptics kGlassDropOptics = GlassOptics(thickness: 10, strength: -4.1);

/// How long the drop of a [GlassSwitch] or a [GlassSlider] takes to lift or
/// settle.
///
/// A feel rather than a reading. The segmented control and the tab bar lift
/// theirs on a spring instead.
///
/// {@category Panels and controls}
const Duration kGlassDropDuration = Duration(milliseconds: 180);

/// How opaque a disabled switch or slider is, drawn as one group.
///
/// iOS 26 draws a disabled `UISwitch` and `UISlider` whole at alpha 0.502 —
/// knob, track and fill alike, in both appearances, their colours unchanged
/// (D221). One group, not each part at a half: the knob reads pure white at
/// that alpha, so the track under it does not show through. macOS does
/// something else per part (the switch's accent ×0.69, the slider's fill
/// gone); these controls are iOS's, as their sizes are.
///
/// {@category Panels and controls}
const double kGlassDisabledOpacity = 0.5;

/// The iOS 26 switch's track, logical px. Its resting knob is 38 x 24.
///
/// The track is laid out in a box [kGlassMinTapTarget] tall, so the switch
/// takes taps above and below what it draws.
///
/// {@category Panels and controls}
const Size kGlassSwitchSize = Size(64, 28);
const Size _kSwitchKnob = Size(38, 24);

/// The slider's resting knob and track thickness, logical px.
const Size _kSliderKnob = Size(38, 24);
const double _kSliderTrack = 6;

/// A knob that becomes a drop: an opaque white capsule at rest, and a clear
/// glass drop [scale] times its size while [lift] is 1.
///
/// Laid out at its resting size and drawn past it, so what places it — a
/// `Positioned`, an `Align` — places the knob's centre and not the drop's box.
class _Drop extends StatelessWidget {
  const _Drop({
    required this.rest,
    required this.lift,
    required this.scale,
    this.widen = 0,
    this.stretch = 0,
    this.focused = false,
  });

  final Size rest;

  /// [GlassOptics.widen] of the held drop.
  final double widen;

  /// The held drop against [rest].
  final double scale;

  /// 0 at rest, 1 held.
  final double lift;

  /// The deformation along x, already scaled by [lift]: see
  /// [GlassDropStretch.apply].
  final double stretch;

  /// Whether the resting knob wears the focus ring.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final double now = 1 + (scale - 1) * lift;
    return SizedBox.fromSize(
      size: rest,
      // Loose both ways: the squashed axis of a drop held at `dropScale` 1 is
      // smaller than its rest, and a minimum left to the tight box above
      // would hold it there.
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SizedBox.fromSize(
          size: GlassDropStretch.apply(rest * now, stretch),
          child: GlassSurface(
            borderRadius: kGlassCapsule,
            finish: GlassFinish.clear.copyWith(optics: kGlassDropOptics.copyWith(widen: widen)),
            // Arrives by its optics, not its shape: `presence` would erode
            // the capsule to its medial axis, a bright stripe (spike 30).
            materialize: lift,
            labelled: false,
            // The white knob is the surface's content, so it is drawn over the
            // glass and kept out of every capture — nothing under a drop is ever
            // the knob it replaced.
            child: lift >= 1
                ? null
                : Opacity(
                    opacity: 1 - lift,
                    child: _Knob(focused: focused),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The resting knob: an opaque white capsule — ringed, when [focused], from
/// inside the drop's subtree, which no capture sees.
class _Knob extends StatelessWidget {
  const _Knob({this.focused = false});

  final bool focused;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: focused ? const _KnobRing() : null,
    child: const DecoratedBox(
      decoration: ShapeDecoration(
        color: Color(0xFFFFFFFF),
        shape: StadiumBorder(),
        shadows: <BoxShadow>[
          BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    ),
  );
}

class _KnobRing extends CustomPainter {
  const _KnobRing();

  @override
  void paint(Canvas canvas, Size size) => paintGlassFocusRing(canvas, Offset.zero & size, kGlassCapsule);

  @override
  bool shouldRepaint(_KnobRing oldDelegate) => false;
}

/// Overrides whether the switch and the slider claim the pointer on touch-down
/// — true always, false never — instead of asking whether the nearest
/// scrollable is horizontal. A `@visibleForTesting` seam: the gesture test's
/// negative controls are the two answers the scrollable did not give.
@visibleForTesting
bool? debugGlassControlsClaimOverride;

/// Whether a control in [context] takes the pointer on touch-down: when the
/// nearest scrollable scrolls the same way the control drags, and only then.
///
/// Shared by the switch, the slider and the segmented control; not exported.
bool glassControlClaimsPointer(BuildContext context) {
  final bool? forced = debugGlassControlsClaimOverride;
  if (forced != null) {
    return forced;
  }
  final ScrollableState? scrollable = Scrollable.maybeOf(context);
  return scrollable != null && axisDirectionToAxis(scrollable.axisDirection) == Axis.horizontal;
}

/// A horizontal drag that, when [claim] says so, wins its arena on the pointer
/// coming down — the way `EagerGestureRecognizer` does — rather than at the
/// touch slop. Won at once, a drag with `DragStartBehavior.down` starts at
/// once, so the tap that would have competed with it is the drag's to tell:
/// an end that travelled under the slop is a tap.
class _ClaimingDragRecognizer extends HorizontalDragGestureRecognizer {
  _ClaimingDragRecognizer({super.debugOwner});

  bool claim = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (claim) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    }
  }
}

/// The recognizers of a control: a tap, and a horizontal drag measured from
/// touch-down that may [claim] the pointer.
Map<Type, GestureRecognizerFactory> _controlGestures({
  required Object owner,
  required bool claim,
  required DeviceGestureSettings? settings,
  GestureTapDownCallback? onTapDown,
  GestureTapUpCallback? onTapUp,
  GestureTapCallback? onTap,
  GestureTapCancelCallback? onTapCancel,
  GestureDragStartCallback? onStart,
  GestureDragUpdateCallback? onUpdate,
  GestureDragEndCallback? onEnd,
  GestureDragCancelCallback? onCancel,
}) => <Type, GestureRecognizerFactory>{
  TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
    () => TapGestureRecognizer(debugOwner: owner),
    (TapGestureRecognizer t) => t
      ..onTapDown = onTapDown
      ..onTapUp = onTapUp
      ..onTap = onTap
      ..onTapCancel = onTapCancel
      ..gestureSettings = settings,
  ),
  _ClaimingDragRecognizer: GestureRecognizerFactoryWithHandlers<_ClaimingDragRecognizer>(
    () => _ClaimingDragRecognizer(debugOwner: owner),
    (_ClaimingDragRecognizer d) => d
      ..claim = claim
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = onStart
      ..onUpdate = onUpdate
      ..onEnd = onEnd
      ..onCancel = onCancel
      ..gestureSettings = settings,
  ),
};

/// Steps a slider by [steps] of its unit: one per arrow key.
class _StepIntent extends Intent {
  const _StepIntent(this.steps);

  final int steps;
}

/// A disabled control's body: drawn whole at [kGlassDisabledOpacity].
///
/// The `saveLayer` an [Opacity] opens is what makes it one group, and it is
/// safe here only because nothing under it is glass: a disabled control cannot
/// be held, so its knob is the plain [_Knob] and no drop is in the tree.
Widget _disabled(Widget child) => Opacity(opacity: kGlassDisabledOpacity, child: child);

/// The region a drop may move and grow in, and the boundary it moves behind.
///
/// [margin] past the control's own box on every side, because a held drop is
/// larger than the track it sits on — and larger again stretched or squashed —
/// and a drop that grew out of its region would be retaken on every frame of
/// the growth.
class _DropStage extends StatelessWidget {
  const _DropStage({required this.margin, required this.child});

  final double margin;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: -margin,
    top: -margin,
    right: -margin,
    bottom: -margin,
    child: GlassTravel(
      // A boundary of its own, so moving the drop repaints a layer that holds
      // nothing but the drop — no picture under the glass is re-minted, and the
      // layer watch has no change to report.
      child: RepaintBoundary(
        child: Stack(clipBehavior: Clip.none, children: <Widget>[child]),
      ),
    ),
  );
}

/// How far past its box a control's drop region reaches, per side: the held
/// drop's growth over the resting knob, and the most [motion] can stretch or
/// squash the held drop, plus 4 for the rounding.
double _margin(Size knob, double scale, GlassDropMotion motion) {
  final Size reach = motion.reach(knob * scale);
  return (scale - 1) * knob.width / 2 + math.max(reach.width, reach.height) + 4;
}

/// The drop at [lift] (0 at rest, 1 held) and its [stretch]: eased in, and
/// deformed only as far as it is lifted, so the resting knob keeps its shape.
_Drop _drop({
  required Size rest,
  required double scale,
  required double widen,
  required double lift,
  required double stretch,
  bool focused = false,
}) => _Drop(
  rest: rest,
  scale: scale,
  widen: widen,
  lift: Curves.easeOut.transform(lift),
  stretch: stretch * lift.clamp(0.0, 1.0),
  focused: focused,
);

/// A switch whose knob becomes a clear glass drop while it is held.
///
/// At rest it is iOS's switch: a track of [kGlassSwitchSize] in [trackColor]
/// or [activeColor], and an opaque white knob that is not glass at all. A tap
/// toggles it; a horizontal drag carries the knob and commits on release,
/// on whichever side of the middle it was let go. While a finger is down the
/// knob is a clear drop [dropScale] times its size that minifies the track
/// under it by [dropWiden].
///
/// The switch holds no value of its own: [onChanged] is told the new one and
/// the caller passes it back as [value].
///
/// Space or Enter toggles a focused switch, and the focus ring is drawn around
/// its track. Under [TextDirection.rtl] it is mirrored: on is to the left.
///
/// ```dart
/// MergeSemantics(
///   child: Row(
///     children: <Widget>[
///       const Expanded(child: Text('Wi-Fi')),
///       GlassSwitch(
///         value: wifi,
///         onChanged: (bool on) => setState(() => wifi = on),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// > **Note:** what a held switch costs is one capture when the drop appears
/// > and none while it moves: the drop moves inside a [GlassTravel] region of
/// > its own, and the track changes colour only when the value commits.
///
/// See also:
///
///  * [GlassSlider], the same drop on a continuous value.
///  * [GlassDropMotion], how the held drop stretches and squashes.
///  * [kGlassDisabledOpacity], how a disabled switch is drawn.
///  * [Switch on the site](https://g1455.plugfox.dev/components/switch).
///
/// {@category Panels and controls}
class GlassSwitch extends StatefulWidget {
  /// A switch showing [value], reporting a change through [onChanged] — null
  /// to disable it.
  ///
  /// [dropScale] must be at least 1: a held drop is never smaller than the
  /// knob it replaces.
  const GlassSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFF34C759),
    this.trackColor = const Color(0x29787880),
    this.dropScale = kGlassDropScale,
    this.dropWiden = kGlassSwitchDropWiden,
    this.dropMotion,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(dropScale >= 1);

  /// The switch's focus. Null makes one the switch owns.
  final FocusNode? focusNode;

  /// Whether the switch takes the focus as soon as it is built.
  final bool autofocus;

  /// How much larger the held drop is than the resting knob. See
  /// [kGlassDropScale]; macOS's own switch is 1.6.
  final double dropScale;

  /// How much of the backdrop past its box the held drop shows, which
  /// minifies it. See [kGlassSwitchDropWiden]; 0 is a drop that does not.
  final double dropWiden;

  /// How the held drop deforms as it launches and brakes. Null takes
  /// [GlassThemeData.dropMotion]; [GlassDropMotion.none] keeps its shape.
  /// Off under reduced motion either way.
  final GlassDropMotion? dropMotion;

  /// Whether the switch is on. The knob slides to it when it changes, unless
  /// a finger is dragging it.
  final bool value;

  /// Null disables the switch, which is also what the semantics say; it is
  /// then drawn at [kGlassDisabledOpacity].
  final ValueChanged<bool>? onChanged;

  /// The track when on. iOS's green by default.
  final Color activeColor;

  /// The track when off.
  final Color trackColor;

  /// What a screen reader says the switch is for. Null leaves it to a
  /// `MergeSemantics` around the switch and its row's label.
  final String? semanticLabel;

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch> with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: kGlassDropDuration,
  );
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.value ? 1 : 0,
  );
  late final AnimationController _colour = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: widget.value ? 1 : 0,
  );
  bool _dragging = false;
  bool _focused = false;

  /// Under [TextDirection.rtl]: on is to the left.
  bool _rtl = false;

  /// How far the drag has gone from where the finger came down, at the most —
  /// what tells a claimed drag from a tap.
  double _dragTravel = 0;
  double _dragFurthest = 0;

  /// Where the knob is drawn for a value position: mirrored under rtl.
  double _visual(double position) => _rtl ? 1 - position : position;

  late final GlassDropStretchDriver _stretch = GlassDropStretchDriver(
    vsync: this,
    position: () => lerpDouble(_from, _to, _visual(_position.value))!,
  );
  GlassDropMotion _motion = GlassDropMotion.none;

  static const double _inset = (28 - 24) / 2;
  static double get _from => _inset + _kSwitchKnob.width / 2;
  static double get _to => kGlassSwitchSize.width - _inset - _kSwitchKnob.width / 2;

  @override
  void initState() {
    super.initState();
    // Only while there is a drop to deform: a value set from outside moves
    // the resting knob, which keeps its shape and needs no ticker.
    _position.addListener(() => _lift.value > 0 ? _stretch.wake() : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
  }

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    if (!_enabled && _lift.value > 0) {
      // Disabled mid-drag: the drag's end will never arrive. A finger held
      // still needs none of this — the disposed tap recognizer calls the
      // `onTapCancel` it was built with — but a drag has already won its arena
      // and is dropped without a word (D221).
      _dragging = false;
      _lift.value = 0;
      _position.animateTo(widget.value ? 1 : 0, curve: Curves.easeOutCubic);
    }
    if (widget.value != oldWidget.value) {
      if (!_dragging) {
        _position.animateTo(widget.value ? 1 : 0, curve: Curves.easeOutCubic);
      }
      _colour.animateTo(widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _stretch.dispose();
    _lift.dispose();
    _position.dispose();
    _colour.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  void _commit(bool value) {
    if (value != widget.value) {
      widget.onChanged?.call(value);
    } else {
      _position.animateTo(value ? 1 : 0, curve: Curves.easeOutCubic);
    }
  }

  void _dragStart(DragStartDetails _) {
    _dragging = true;
    _dragTravel = _dragFurthest = 0;
    _lift.forward();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _dragTravel += d.delta.dx;
    _dragFurthest = math.max(_dragFurthest, _dragTravel.abs());
    _position.value += (_rtl ? -d.delta.dx : d.delta.dx) / (_to - _from);
  }

  void _dragEnd(DragEndDetails _) {
    _dragging = false;
    _lift.reverse();
    // A claimed pointer is a drag from touch-down, taps included: one that
    // never left the slop is the tap the tap recognizer would have seen.
    final double slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
    _commit(_dragFurthest < slop && _claimed ? !widget.value : _position.value >= 0.5);
  }

  void _dragCancel() {
    _dragging = false;
    _lift.reverse();
    _position.animateTo(widget.value ? 1 : 0, curve: Curves.easeOutCubic);
  }

  bool _claimed = false;

  @override
  Widget build(BuildContext context) {
    final double margin = _margin(_kSwitchKnob, widget.dropScale, _motion) + _inset;
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    _claimed = glassControlClaimsPointer(context);
    final bool enabled = _enabled;
    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? () => _commit(!widget.value) : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool on) => setState(() => _focused = on),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _commit(!widget.value)),
        },
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: _controlGestures(
            owner: this,
            claim: _claimed,
            settings: MediaQuery.maybeGestureSettingsOf(context),
            onTapDown: enabled ? (_) => _lift.forward() : null,
            onTapCancel: enabled ? () => _dragging ? null : _lift.reverse() : null,
            onTap: enabled
                ? () {
                    _lift.reverse();
                    _commit(!widget.value);
                  }
                : null,
            onStart: enabled ? _dragStart : null,
            onUpdate: enabled ? _dragUpdate : null,
            onEnd: enabled ? _dragEnd : null,
            onCancel: enabled ? _dragCancel : null,
          ),
          child: SizedBox(
            width: kGlassSwitchSize.width,
            height: math.max(kGlassSwitchSize.height, kGlassMinTapTarget.height),
            child: Center(
              child: SizedBox.fromSize(size: kGlassSwitchSize, child: _switchBody(margin)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchBody(double margin) {
    final Widget body = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _colour,
              builder: (BuildContext context, Widget? _) => DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: Color.lerp(widget.trackColor, widget.activeColor, _colour.value),
                ),
              ),
            ),
          ),
        ),
        GlassFocusRing(visible: _focused && _enabled, radius: kGlassCapsule),
        if (!_enabled)
          AnimatedBuilder(
            animation: _position,
            builder: (BuildContext context, Widget? _) => Positioned.fromRect(
              rect: Rect.fromCenter(
                center: Offset(
                  lerpDouble(_from, _to, _visual(_position.value))!,
                  kGlassSwitchSize.height / 2,
                ),
                width: _kSwitchKnob.width,
                height: _kSwitchKnob.height,
              ),
              child: const _Knob(),
            ),
          )
        else
          _DropStage(
            margin: margin,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_lift, _position, _stretch]),
              builder: (BuildContext context, Widget? _) => Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: Offset(
                    margin + lerpDouble(_from, _to, _visual(_position.value))!,
                    margin + kGlassSwitchSize.height / 2,
                  ),
                  width: _kSwitchKnob.width,
                  height: _kSwitchKnob.height,
                ),
                child: _drop(
                  rest: _kSwitchKnob,
                  scale: widget.dropScale,
                  widen: widget.dropWiden,
                  lift: _lift.value,
                  stretch: _stretch.value,
                ),
              ),
            ),
          ),
      ],
    );
    return _enabled ? body : _disabled(body);
  }
}

/// A slider whose knob becomes a clear glass drop while it is held.
///
/// Every frame of a drag changes the fill under the drop, so every frame of a
/// drag is a capture — see the file comment. The knob moving is not.
///
/// The value runs from 0 to 1 and is the caller's: [onChanged] is told each
/// new one while a finger is down — a tap places the knob, a drag carries it —
/// and the caller passes it back as [value]. [onChangeStart] and
/// [onChangeEnd] bracket the gesture. A screen reader's increase and decrease
/// move it by [semanticStep] — or by one division, when [divisions] snaps the
/// value to `divisions + 1` stops, as Material's `Slider` does.
///
/// The arrow keys step a focused slider by the same unit, and the focus ring
/// is drawn around its knob. Under [TextDirection.rtl] it is mirrored: 0 is
/// at the right and the fill grows leftward, and the left arrow increases.
///
/// ```dart
/// GlassSlider(
///   value: volume,
///   semanticLabel: 'Volume',
///   onChanged: (double v) => setState(() => volume = v),
///   onChangeEnd: (double v) => player.setVolume(v),
/// )
/// ```
///
/// > **Note:** the fill ends under the drop and follows it, so every frame of
/// > a drag is a real change under glass and is retaken. A screen of sliders
/// > at rest costs nothing; a held one costs a capture a frame.
///
/// See also:
///
///  * [GlassSwitch], the same drop on a boolean.
///  * [SliderGeometry.fillEnd], where the fill ends for a value.
///  * [GlassDropMotion], how the held drop stretches and squashes.
///  * [Slider on the site](https://g1455.plugfox.dev/components/slider).
///
/// {@category Panels and controls}
class GlassSlider extends StatefulWidget {
  /// A slider showing [value], reporting a change through [onChanged] — null
  /// to disable it.
  ///
  /// [dropScale] must be at least 1, and [semanticStep] above 0 and at most 1.
  const GlassSlider({
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = const Color(0xFF0A84FF),
    this.trackColor = const Color(0x29787880),
    this.dropScale = kGlassDropScale,
    this.dropWiden = 0,
    this.dropMotion,
    this.semanticLabel,
    this.semanticStep = 0.1,
    this.divisions,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(dropScale >= 1),
       assert(semanticStep > 0 && semanticStep <= 1),
       assert(divisions == null || divisions > 0);

  /// How many equal steps the value snaps to between 0 and 1, or null for a
  /// continuous slider. A drag, a tap, a key and a screen reader all land on
  /// a stop, and [onChanged] is told only when the stop changes.
  final int? divisions;

  /// The slider's focus. Null makes one the slider owns.
  final FocusNode? focusNode;

  /// Whether the slider takes the focus as soon as it is built.
  final bool autofocus;

  /// How much larger the held drop is than the resting knob. See
  /// [kGlassDropScale]; macOS's own slider is 1.4.
  final double dropScale;

  /// See [GlassSwitch.dropWiden]. 0, because iOS's slider drop does not
  /// minify (D218).
  final double dropWiden;

  /// See [GlassSwitch.dropMotion].
  final GlassDropMotion? dropMotion;

  /// Between 0 and 1.
  final double value;

  /// Null disables the slider; it is then drawn at [kGlassDisabledOpacity].
  final ValueChanged<double>? onChanged;

  /// Called with the value before the gesture, as a finger comes down or a
  /// screen reader steps the value.
  final ValueChanged<double>? onChangeStart;

  /// Called with the value at the end of the gesture, as the finger lifts or
  /// a screen reader's step lands.
  final ValueChanged<double>? onChangeEnd;

  /// The fill from 0 to [value]. iOS's blue by default.
  final Color activeColor;

  /// The track behind the fill.
  final Color trackColor;

  /// What a screen reader says the slider is for. Null leaves it to a
  /// `MergeSemantics` around the slider and its row's label.
  final String? semanticLabel;

  /// How far a screen reader's increase or decrease — and an arrow key —
  /// moves the value: a tenth, as Flutter's own continuous slider does.
  /// Ignored when [divisions] is set: the step is then one division.
  final double semanticStep;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: kGlassDropDuration,
  );

  late final GlassDropStretchDriver _stretch = GlassDropStretchDriver(
    vsync: this,
    position: () => _visual(widget.value.clamp(0.0, 1.0)) * _span,
  );
  GlassDropMotion _motion = GlassDropMotion.none;

  /// The next change of value is a tap placing the knob, not a drag moving
  /// it: the drop is there without having travelled.
  bool _placing = false;

  bool _focused = false;

  /// Under [TextDirection.rtl]: 0 is at the right.
  bool _rtl = false;

  /// Where along the track a value is drawn, 0 at the left: mirrored under rtl.
  double _visual(double value) => _rtl ? 1 - value : value;

  /// [value] on the nearest stop, when there are stops.
  double _snap(double value) {
    final int? n = widget.divisions;
    return n == null ? value : (value * n).round() / n;
  }

  /// What one step of a key or a screen reader is.
  double get _unit {
    final int? n = widget.divisions;
    return n == null ? widget.semanticStep : 1 / n;
  }

  double get _span {
    final RenderObject? box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? math.max(0, box.size.width - _kSliderKnob.width) : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
  }

  @override
  void didUpdateWidget(GlassSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    if (!_enabled) {
      // Disabled mid-drag: see the switch's.
      _lift.value = 0;
      _placing = false;
    }
    if (widget.value != oldWidget.value) {
      if (_placing) {
        _placing = false;
        _stretch.jump();
      } else if (_lift.value > 0) {
        _stretch.wake();
      }
    }
  }

  @override
  void dispose() {
    _stretch.dispose();
    _lift.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  double _valueAt(Offset local) {
    final double width = (context.findRenderObject()! as RenderBox).size.width;
    final double span = width - _kSliderKnob.width;
    if (span <= 0) {
      return widget.value;
    }
    return _snap(_visual(((local.dx - _kSliderKnob.width / 2) / span).clamp(0.0, 1.0)));
  }

  /// Tells [GlassSlider.onChanged] of [v] — on a slider with stops, only when
  /// it is another stop: a drag across one stop is many events and one value.
  void _change(double v) {
    if (widget.divisions != null && v == widget.value) {
      return;
    }
    widget.onChanged?.call(v);
  }

  void _start(Offset local) {
    _lift.forward();
    final double v = _valueAt(local);
    _placing = v != widget.value;
    widget.onChangeStart?.call(widget.value);
    _change(v);
  }

  void _end() {
    _placing = false;
    _lift.reverse();
    widget.onChangeEnd?.call(widget.value);
  }

  /// A screen reader's increase or decrease: a whole change, start to end, with
  /// no drop, since nothing is held.
  void _step(double to) {
    widget.onChangeStart?.call(widget.value);
    widget.onChanged?.call(to);
    widget.onChangeEnd?.call(to);
  }

  static String _percent(double v) => '${(v * 100).round()}%';

  /// The value [steps] units from the current one, on a stop and in range.
  ///
  /// From between two stops the first step lands on the next stop *that
  /// way* — not on the stop nearest a whole unit on, which from 0.6 in
  /// quarters would step down past 0.5 to 0.25 (Material's `Slider` does).
  double _stepped(int steps) {
    final double value = widget.value.clamp(0.0, 1.0);
    final int? n = widget.divisions;
    if (n == null) {
      return (value + steps * _unit).clamp(0.0, 1.0);
    }
    const double eps = 1e-9;
    final int from = steps > 0 ? (value * n + eps).floor() : (value * n - eps).ceil();
    return ((from + steps) / n).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double margin = _margin(_kSliderKnob, widget.dropScale, _motion);
    _rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final double value = widget.value.clamp(0.0, 1.0);
    final double up = _stepped(1);
    final double down = _stepped(-1);
    final bool enabled = _enabled;
    // The arrow along the track increases toward its 1: rightward, unless the
    // track runs the other way.
    final int right = _rtl ? -1 : 1;
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      enabled: enabled,
      value: _percent(value),
      increasedValue: enabled && up != value ? _percent(up) : null,
      decreasedValue: enabled && down != value ? _percent(down) : null,
      onIncrease: enabled && up != value ? () => _step(up) : null,
      onDecrease: enabled && down != value ? () => _step(down) : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool on) => setState(() => _focused = on),
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(right),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-right),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(-1),
        },
        actions: <Type, Action<Intent>>{
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (_StepIntent intent) {
              final double to = _stepped(intent.steps);
              if (to != widget.value) {
                _step(to);
              }
              return null;
            },
          ),
        },
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: _controlGestures(
            owner: this,
            claim: glassControlClaimsPointer(context),
            settings: MediaQuery.maybeGestureSettingsOf(context),
            onStart: enabled ? (DragStartDetails d) => _start(d.localPosition) : null,
            onUpdate: enabled ? (DragUpdateDetails d) => _change(_valueAt(d.localPosition)) : null,
            onEnd: enabled ? (_) => _end() : null,
            onCancel: enabled ? _end : null,
            onTapDown: enabled ? (TapDownDetails d) => _start(d.localPosition) : null,
            onTapUp: enabled ? (_) => _end() : null,
            onTapCancel: enabled ? () => _lift.reverse() : null,
          ),
          child: SizedBox(height: kGlassMinTapTarget.height, child: _sliderBody(value, margin)),
        ),
      ),
    );
  }

  Widget _sliderBody(double value, double margin) {
    final Widget body = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _SliderTrack(value, widget.trackColor, widget.activeColor, rtl: _rtl)),
          ),
        ),
        if (!_enabled)
          // The same box the drop's region pads back down to, so the knob sits
          // where the enabled one does.
          Positioned.fill(
            child: Align(
              alignment: Alignment(_visual(value) * 2 - 1, 0),
              child: SizedBox.fromSize(size: _kSliderKnob, child: const _Knob()),
            ),
          )
        else
          _DropStage(
            margin: margin,
            child: Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(margin),
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_lift, _stretch]),
                  // `Align` puts the resting knob's centre at
                  // `rest / 2 + value * (width - rest)`, which is where
                  // [SliderGeometry.fillEnd] ends the fill.
                  builder: (BuildContext context, Widget? _) => Align(
                    alignment: Alignment(_visual(value) * 2 - 1, 0),
                    child: _drop(
                      rest: _kSliderKnob,
                      scale: widget.dropScale,
                      widen: widget.dropWiden,
                      lift: _lift.value,
                      stretch: _stretch.value,
                      focused: _focused && _enabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return _enabled ? body : _disabled(body);
  }
}

class _SliderTrack extends CustomPainter {
  _SliderTrack(this.value, this.track, this.active, {this.rtl = false});

  final double value;
  final Color track;
  final Color active;

  /// Drawn mirrored: the fill from the right.
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      // The left-to-right track reflected, so the two directions are the same
      // pixels mirrored rather than two drawings that could drift apart.
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
      _paint(canvas, size);
      canvas.restore();
    } else {
      _paint(canvas, size);
    }
  }

  void _paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final Rect bar = Rect.fromLTRB(
      _kSliderKnob.width / 2 - _kSliderTrack / 2,
      y - _kSliderTrack / 2,
      size.width - _kSliderKnob.width / 2 + _kSliderTrack / 2,
      y + _kSliderTrack / 2,
    );
    final RRect whole = RRect.fromRectAndRadius(bar, const Radius.circular(_kSliderTrack / 2));
    canvas.drawRRect(whole, Paint()..color = track);
    // The fill is a capsule of its own, not the track clipped: a clip cuts
    // its end square, and the lifted drop is clear and magnifies exactly that
    // end (Apple's held slider rounds it, spike 27 `held/`). Shorter than the
    // track is thick, it cannot be a capsule ending at `end`, so it is the
    // track's own cap cut there, which the resting knob covers anyway.
    final double end = SliderGeometry.fillEnd(value, size.width);
    final RRect fill = RRect.fromLTRBR(
      bar.left,
      bar.top,
      math.max(end, bar.left + _kSliderTrack),
      bar.bottom,
      const Radius.circular(_kSliderTrack / 2),
    );
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(bar.left, bar.top, end, bar.bottom))
      ..drawRRect(fill, Paint()..color = active)
      ..restore();
  }

  @override
  bool shouldRepaint(_SliderTrack oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.track != track ||
      oldDelegate.active != active ||
      oldDelegate.rtl != rtl;
}

/// Where the slider's fill ends for a value, on a slider `width` wide.
///
/// Public so that a test, or a widget drawn alongside a [GlassSlider], can
/// put something exactly where the fill ends — which is also the centre of
/// the resting knob.
///
/// {@category Panels and controls}
abstract final class SliderGeometry {
  /// The x of the fill's end, logical px from the slider's left edge, for
  /// [value] (0 to 1) on a slider [width] wide: half the resting knob in from
  /// the left at 0, and half the knob in from the right at 1 — and the other
  /// way round under [TextDirection.rtl].
  static double fillEnd(double value, double width, {TextDirection textDirection = TextDirection.ltr}) {
    final double ltr = _kSliderKnob.width / 2 + value * math.max(0, width - _kSliderKnob.width);
    return textDirection == TextDirection.rtl ? width - ltr : ltr;
  }
}
