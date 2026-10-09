// A stepper: a minus and a plus in one glass capsule, as `UIStepper` lays
// them out — two halves and a hairline between them.
//
// What it costs: **one surface**, whatever is held. The two halves are not
// two glasses joined by a blend group: they are one capsule, and a group is a
// way to get a silhouette, not a price — two capsules fused into one
// draw at least what one draws, plus the fold. A held half brightens its own
// cell of the capsule the way `GlassButtonGroup` does: the finish's rim, added
// with `plus`, drawn on the surface's own canvas and clipped to the capsule,
// with nothing between the overlay and the glass that would open a
// `saveLayer`.
//
// A press, the autorepeat and the glyph dimming at a limit are all inside the
// surface's subtree, which is a repaint boundary the capture skips — so none
// of them is a capture, and none repaints what is under the glass. Asserted,
// with the control that makes the counter move, in `glass_stepper_test.dart`.
// The focus ring is drawn there too, as a button's is (`glass_focus.dart`).
//
// Under `TextDirection.rtl` the capsule mirrors, as UIKit's controls do: the
// minus is at the right and the plus at the left, and the arrow keys follow
// the glyphs — the hit areas, the glyphs, the held light and the keys all
// read the one direction the build reads, so none can disagree.
//
// **Not measured:** the sizes. Apple's material and several controls were
// read off the device; the iOS 26 stepper was not among them. 94 is
// `UIStepper`'s width since iOS 7, and the height is the segmented control's
// track. Both are named as layout, not as readings.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassDisabledDarkLabel, kGlassDisabledLightLabel, kGlassMinTapTarget;
import 'glass_finish.dart';
import 'glass_focus.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// The stepper's capsule, logical px: `UIStepper`'s 94 across, and the
/// segmented control's 32-px track down.
///
/// **Layout, not a reading** — the iOS 26 stepper was not measured here. The
/// control is laid out [kGlassMinTapTarget] tall around it, so it takes taps
/// above and below what it draws.
///
/// {@category Panels and controls}
const Size kGlassStepperSize = Size(94, 32);

/// How long a held half waits before it starts to repeat, and how often it
/// repeats after that.
///
/// `UIStepper`'s `autorepeat` feel: the first step lands on the press, the
/// second half a second later, then ten a second. A feel, not a reading.
///
/// {@category Panels and controls}
const Duration kGlassStepperRepeatDelay = Duration(milliseconds: 500);

/// See [kGlassStepperRepeatDelay].
///
/// {@category Panels and controls}
const Duration kGlassStepperRepeatInterval = Duration(milliseconds: 100);

/// A minus and a plus in one glass capsule, stepping a number between [min]
/// and [max] — iOS's `UIStepper`.
///
/// A press steps at once; held, the half repeats after
/// [kGlassStepperRepeatDelay] every [kGlassStepperRepeatInterval] until the
/// finger lifts or the value reaches a limit ([autorepeat]). At a limit the
/// half that would pass it is disabled and its glyph dims, unless [wraps].
///
/// The stepper holds no value of its own and shows none: [onChanged] is told
/// the new one, the caller passes it back as [value], and puts it in a label
/// beside the stepper as iOS does.
///
/// ```dart
/// Row(
///   children: <Widget>[
///     Expanded(child: Text('Copies: $copies')),
///     GlassStepper(
///       value: copies.toDouble(),
///       min: 1,
///       max: 10,
///       semanticLabel: 'Copies',
///       onChanged: (double v) => setState(() => copies = v.round()),
///     ),
///   ],
/// )
/// ```
///
/// > **Note:** one surface, whatever is held. A press, the autorepeat and a
/// > glyph dimming at a limit are drawn inside the glass, so none of them is
/// > a capture.
///
/// A screen reader hears one adjustable control — its [semanticLabel] and the
/// value — and increases or decreases it by [step]. A keyboard steps a focused
/// stepper with the arrow keys, and the focus ring is drawn around the
/// capsule.
///
/// Under [TextDirection.rtl] it is mirrored: the minus is at the right, and
/// the left arrow increases.
///
/// See also:
///
///  * [GlassButtonGroup], several actions in one capsule, the same way.
///  * [GlassSlider], a continuous value.
///
/// {@category Panels and controls}
class GlassStepper extends StatefulWidget {
  /// A stepper showing [value] between [min] and [max] in steps of [step],
  /// reporting a change through [onChanged] — null to disable it.
  const GlassStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.wraps = false,
    this.autorepeat = true,
    this.finish,
    this.pressedOverlay,
    this.semanticLabel,
    this.semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(min <= max),
       assert(step > 0);

  /// The value, between [min] and [max].
  final double value;

  /// Called with the stepped value. Null disables the stepper: the glass
  /// stays as it is and both glyphs dim to [kGlassDisabledDarkLabel] or
  /// [kGlassDisabledLightLabel], as a disabled [GlassButton]'s label does.
  final ValueChanged<double>? onChanged;

  /// The smallest value. 0 by default, as `UIStepper`'s.
  final double min;

  /// The largest value. 100 by default, as `UIStepper`'s.
  final double max;

  /// How far one press moves the value. 1 by default.
  final double step;

  /// Whether stepping past [max] lands on [min] and past [min] on [max]. Off
  /// by default, as `UIStepper.wraps` is; then the half that would pass a
  /// limit is disabled at it.
  final bool wraps;

  /// Whether a held half keeps stepping. On by default, as
  /// `UIStepper.autorepeat` is.
  final bool autorepeat;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// What is added over a held half. Null takes the finish's rim, as
  /// [GlassButton] does.
  final Color? pressedOverlay;

  /// What a screen reader says the stepper is for.
  final String? semanticLabel;

  /// How a screen reader says a value. Null says it as a number, without a
  /// fraction when it has none.
  final String Function(double value)? semanticFormatterCallback;

  /// The stepper's focus. Null makes one the stepper owns.
  final FocusNode? focusNode;

  /// Whether the stepper takes the focus as soon as it is built.
  final bool autofocus;

  @override
  State<GlassStepper> createState() => _GlassStepperState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('value', value))
      ..add(DoubleProperty('min', min, defaultValue: 0.0))
      ..add(DoubleProperty('max', max, defaultValue: 100.0))
      ..add(DoubleProperty('step', step, defaultValue: 1.0))
      ..add(FlagProperty('enabled', value: onChanged != null, ifFalse: 'disabled'))
      ..add(FlagProperty('wraps', value: wraps, ifTrue: 'wraps'))
      ..add(FlagProperty('autorepeat', value: autorepeat, ifFalse: 'no autorepeat'))
      ..add(DiagnosticsProperty<GlassFinish>('finish', finish, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null))
      ..add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null))
      ..add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
  }
}

/// The two halves, in reading order: the minus at the start.
enum _Half { decrement, increment }

/// Steps a stepper along [half]: one per arrow key.
class _StepIntent extends Intent {
  const _StepIntent(this.half);

  final _Half half;
}

class _GlassStepperState extends State<GlassStepper> {
  _Half? _held;
  Timer? _repeat;
  bool _focused = false;

  /// The value last reported, until the caller's rebuild hands it back: a
  /// repeat that fires before that rebuild steps from here, not from the
  /// value it already stepped from.
  double? _emitted;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(GlassStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _emitted = null;
    // Disabled under a finger, or a half that reached its limit while held:
    // stop. The tap recognizer that was built for the half is disposed with
    // the handlers and calls the `onTapCancel` it had — from inside this
    // build, where a `setState` would throw — so the held state is dropped
    // here rather than there (the same order as `GlassButton`'s).
    final _Half? held = _held;
    if (held != null && !_canStep(held)) {
      _release();
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  /// The value one step along [half], or null when there is none to take.
  double? _next(_Half half) {
    final double value = (_emitted ?? widget.value).clamp(widget.min, widget.max);
    final double raw = half == _Half.increment ? value + widget.step : value - widget.step;
    // Cleaned of the binary residue a tenth leaves after three additions
    // (0.30000000000000004), which a label would show and a comparison
    // with a limit would fail.
    final double next = (raw * 1e9).roundToDouble() / 1e9;
    if (next > widget.max) {
      return widget.wraps ? widget.min : (value < widget.max ? widget.max : null);
    }
    if (next < widget.min) {
      return widget.wraps ? widget.max : (value > widget.min ? widget.min : null);
    }
    return next;
  }

  bool _canStep(_Half half) => _enabled && _next(half) != null;

  void _stepAlong(_Half half) {
    final double? next = _next(half);
    if (next == null || !_enabled) {
      _stopRepeat();
      return;
    }
    _emitted = next;
    widget.onChanged!(next);
  }

  void _press(_Half half) {
    if (!_canStep(half)) {
      return;
    }
    setState(() => _held = half);
    _stepAlong(half);
    if (widget.autorepeat) {
      _repeat?.cancel();
      _repeat = Timer(kGlassStepperRepeatDelay, () {
        _stepAlong(half);
        if (_held == half) {
          _repeat = Timer.periodic(kGlassStepperRepeatInterval, (_) => _stepAlong(half));
        }
      });
    }
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  /// Lets go without a `setState`, for the build that disabled the half.
  void _release() {
    _stopRepeat();
    _held = null;
  }

  void _lift() {
    _stopRepeat();
    if (_held != null && mounted) {
      setState(() => _held = null);
    }
  }

  String _say(double v) {
    final String Function(double)? say = widget.semanticFormatterCallback;
    if (say != null) {
      return say(v);
    }
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final GlassThemeData theme = GlassTheme.of(context);
    final GlassFinish finish = widget.finish ?? theme.finish;
    final Color label = theme.legibility(finish).label;
    final Color dimmed = label.computeLuminance() < 0.5 ? kGlassDisabledDarkLabel : kGlassDisabledLightLabel;
    final Color overlay = widget.pressedOverlay ?? finish.rim;
    final double value = widget.value.clamp(widget.min, widget.max);
    final double? up = _enabled ? _next(_Half.increment) : null;
    final double? down = _enabled ? _next(_Half.decrement) : null;
    final bool rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    // The arrow toward a glyph steps along it: the plus is rightward, unless
    // the capsule runs the other way.
    final _Half right = rtl ? _Half.decrement : _Half.increment;
    final _Half left = rtl ? _Half.increment : _Half.decrement;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      enabled: _enabled,
      value: _say(value),
      increasedValue: up == null ? null : _say(up),
      decreasedValue: down == null ? null : _say(down),
      onIncrease: up == null ? null : () => _stepAlong(_Half.increment),
      onDecrease: down == null ? null : () => _stepAlong(_Half.decrement),
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool on) => setState(() => _focused = on),
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(right),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(left),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(_Half.increment),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(_Half.decrement),
        },
        actions: <Type, Action<Intent>>{
          // One step a key, with no autorepeat of the stepper's own: a held
          // key repeats by itself.
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (_StepIntent intent) {
              if (_canStep(intent.half)) {
                _stepAlong(intent.half);
              }
              return null;
            },
          ),
        },
        child: ExcludeSemantics(
          child: SizedBox(
            width: kGlassStepperSize.width,
            height: math.max(kGlassStepperSize.height, kGlassMinTapTarget.height),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.fromSize(
                  size: kGlassStepperSize,
                  child: GlassSurface(
                    borderRadius: kGlassCapsule,
                    finish: widget.finish,
                    child: CustomPaint(
                      size: kGlassStepperSize,
                      painter: _StepperPainter(
                        held: _held,
                        overlay: overlay,
                        glyph: label,
                        dimmed: dimmed,
                        decrementEnabled: _canStep(_Half.decrement),
                        incrementEnabled: _canStep(_Half.increment),
                        rtl: rtl,
                        focusRing: _focused && _enabled,
                      ),
                    ),
                  ),
                ),
                // Over the glass and the whole 44-tall box, so a tap anywhere
                // in a half lands: a `GlassSurface` hit-tests only its child.
                // The row follows the ambient direction, as the painter does.
                Positioned.fill(
                  child: Row(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    children: <Widget>[for (final _Half half in _Half.values) Expanded(child: _target(half))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One half's hit area: the whole half of the 44-tall box, opaque.
  Widget _target(_Half half) {
    final bool enabled = _canStep(half);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press(half) : null,
      onTapUp: enabled ? (_) => _lift() : null,
      onTapCancel: enabled ? _lift : null,
    );
  }
}

/// The glyphs, the hairline, a held half's light and the focus ring, all on
/// the surface's own canvas.
class _StepperPainter extends CustomPainter {
  const _StepperPainter({
    required this.held,
    required this.overlay,
    required this.glyph,
    required this.dimmed,
    required this.decrementEnabled,
    required this.incrementEnabled,
    required this.rtl,
    required this.focusRing,
  });

  final _Half? held;
  final Color overlay;
  final Color glyph;
  final Color dimmed;
  final bool decrementEnabled;
  final bool incrementEnabled;

  /// Whether the minus is at the right.
  final bool rtl;
  final bool focusRing;

  @override
  void paint(Canvas canvas, Size size) {
    final double half = size.width / 2;
    if (focusRing) {
      // Past the capsule, on the surface's own canvas, which the capture
      // skips: see `glass_focus.dart`.
      paintGlassFocusRing(canvas, Offset.zero & size, kGlassCapsule);
    }
    // The left half's left edge and the right half's, in the order drawn.
    final double decrementAt = rtl ? half : 0;
    final double incrementAt = rtl ? 0 : half;
    final _Half? lit = held;
    if (lit != null && overlay.a > 0) {
      // `plus` on the glass's own canvas, clipped to the capsule: see the
      // file comment and `GlassButton`.
      canvas
        ..save()
        ..clipRSuperellipse(kGlassCapsule.toRSuperellipse(Offset.zero & size).scaleRadii())
        ..drawRect(
          Rect.fromLTWH(lit == _Half.decrement ? decrementAt : incrementAt, 0, half, size.height),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = overlay,
        )
        ..restore();
    }
    // The hairline: half the height, the label at a fifth.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(half, size.height / 2), width: 1, height: size.height / 2),
      Paint()..color = glyph.withValues(alpha: glyph.a * 0.2),
    );
    const double arm = 7;
    final Paint minus = _stroke(decrementEnabled ? glyph : dimmed);
    final Paint plus = _stroke(incrementEnabled ? glyph : dimmed);
    final Offset down = Offset(decrementAt + half / 2, size.height / 2);
    final Offset up = Offset(incrementAt + half / 2, size.height / 2);
    canvas
      ..drawLine(down.translate(-arm, 0), down.translate(arm, 0), minus)
      ..drawLine(up.translate(-arm, 0), up.translate(arm, 0), plus)
      ..drawLine(up.translate(0, -arm), up.translate(0, arm), plus);
  }

  static Paint _stroke(Color colour) => Paint()
    ..color = colour
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(_StepperPainter oldDelegate) =>
      oldDelegate.held != held ||
      oldDelegate.overlay != overlay ||
      oldDelegate.glyph != glyph ||
      oldDelegate.dimmed != dimmed ||
      oldDelegate.decrementEnabled != decrementEnabled ||
      oldDelegate.incrementEnabled != incrementEnabled ||
      oldDelegate.rtl != rtl ||
      oldDelegate.focusRing != focusRing;
}
