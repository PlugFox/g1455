// A held drop that stretches as it launches and squashes as it brakes.
//
// Read off nothing — a feel, like the drop's springs. Apple's held drops in the
// tab bar and the segmented control lean into a fast slide and bulge as they
// stop; what is taken here is the shape of that and not its numbers, which
// have not been measured. So it is a spec with a zero, not a constant.
//
// The input is the drop's **acceleration** along its travel, the second
// derivative of where it is, smoothed: a drop gliding at a constant speed is
// round, one setting off is long and thin, one stopping is short and fat. The
// sign is the acceleration against the velocity, so a drop launching leftwards
// stretches too. The deformation keeps the area — `w (1 + s)` by `h / (1 + s)`
// — follows its target through a spring, so it wobbles back rather than snaps,
// and is clamped to `maxStretch` either way.
//
// What it costs, by construction:
//
//  - **no capture.** The drop changes its size inside the `GlassTravel` region
//    it already moves in, whose capture is the region and not the drop's box.
//    Each control's region is grown by the most the spec can stretch or squash
//    it, so a deformation never leaves it;
//  - a **repaint of the drop's own layer** on the frames the stretch changes,
//    where moving alone would have re-recorded the same draw from the old
//    paint (`drawRecordsOnMove`): the same one draw a frame, through a paint;
//  - a **ticker** while the drop is moving or the stretch is springing back,
//    and none at rest or while a finger holds the drop still;
//  - the regions are a few px larger on every side (the most the spec can
//    reach), which is that much more of the atlas while held.
//
// Off under reduced motion (`MediaQuery.disableAnimations`), and off with
// [GlassDropMotion.none].

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_theme.dart';

/// How a held drop deforms as it moves: stretched along its travel while it
/// speeds up, squashed while it slows down, round at a constant speed.
///
/// Read by [GlassSwitch], [GlassSlider], [GlassSegmentedControl] and
/// [GlassTabBar] from [GlassThemeData.dropMotion], unless the widget names its
/// own. [none] turns it off, and so does the platform's reduced-motion switch.
///
/// A feel rather than a measurement: Apple's held drops lean into a fast slide
/// and bulge as they stop, and what is taken here is the shape of that, not
/// its numbers. The deformation keeps the drop's area and follows its target
/// through a spring, so it wobbles back rather than snapping.
///
/// It costs no capture — the drop changes size inside the travel region it
/// already moves in — and a repaint of the drop's own layer on the frames the
/// stretch changes.
///
/// ```dart
/// // Softer for the whole screen, and none at all on one switch.
/// GlassHost(
///   dropMotion: const GlassDropMotion(maxStretch: 0.06),
///   child: navigator!,
/// )
///
/// GlassSwitch(
///   value: on,
///   onChanged: (bool value) => setState(() => on = value),
///   dropMotion: GlassDropMotion.none,
/// )
/// ```
///
/// See also:
///
///  * [GlassHost.dropMotion] and [GlassThemeData.dropMotion], where it is set
///    for a screen or a subtree.
///  * [GlassDropStretch], the model, for a custom control that feeds it itself.
///  * [GlassDropStretchDriver], the ticker the package's controls run it on.
///  * [Drop motion](https://g1455.plugfox.dev/foundations/drop-motion) on the
///    site.
///
/// {@category Foundations}
@immutable
class GlassDropMotion {
  /// A drop motion with the package's defaults: up to 12% of stretch, on a
  /// spring with a damping ratio of 0.5.
  const GlassDropMotion({
    this.maxStretch = 0.12,
    this.saturation = 10000,
    this.smoothing = const Duration(milliseconds: 16),
    this.stiffness = 900,
    this.damping = 30,
  }) : assert(maxStretch >= 0 && maxStretch <= 0.5),
       assert(saturation > 0),
       assert(stiffness > 0),
       assert(damping >= 0);

  /// No deformation at all: the drop is the shape it is held at.
  static const GlassDropMotion none = GlassDropMotion(maxStretch: 0);

  /// The most the drop stretches or squashes: at 0.12 it is up to 12% longer
  /// and 1/1.12 as thick launching, and 12% shorter and 1/0.88 as thick
  /// braking. Zero is [none].
  final double maxStretch;

  /// The acceleration along the travel, logical px/s², that takes the drop to
  /// three quarters of [maxStretch] (`tanh(1)`): the deformation saturates
  /// smoothly towards [maxStretch] past it. A tab bar's drop springing one tab
  /// over starts at about 27 000 px/s² and is past it in a frame or two, so —
  /// after [smoothing] and the spring — the defaults draw it about 7% long
  /// setting off and 5% short arriving; three tabs, 11% and 12%; a finger
  /// dragged at 1000 px/s and let stop, 9% and 8%; the switch's 22 px, 3%.
  final double saturation;

  /// The time constant of the low-pass on the velocity and on the
  /// acceleration. A second derivative of positions sampled once a frame from
  /// a finger is mostly noise without it.
  final Duration smoothing;

  /// The spring the deformation follows its target with, at unit mass: what
  /// makes it wobble back rather than snap. 900 and 30 is a damping ratio of
  /// 0.5 — a little jelly, back in about half a second.
  final double stiffness;

  /// The spring's damping, at unit mass. See [stiffness].
  final double damping;

  /// Whether this deforms nothing.
  bool get isNone => maxStretch == 0;

  /// [none] when [context] asks for reduced motion; this otherwise.
  GlassDropMotion orNoneUnderReducedMotion(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? none : this;

  /// The motion a control in [context] uses: its own [declared], else the
  /// theme's — and [none] either way under reduced motion.
  static GlassDropMotion resolve(BuildContext context, GlassDropMotion? declared) =>
      (declared ?? GlassTheme.of(context).dropMotion).orNoneUnderReducedMotion(context);

  /// How far past its held size a drop of [size] can reach, per side, under
  /// this motion: half the stretch across, half the squash down. What a
  /// control grows its travel region by, so a deformation never leaves it.
  Size reach(Size size) =>
      isNone ? Size.zero : Size(size.width * maxStretch / 2, size.height * (1 / (1 - maxStretch) - 1) / 2);

  /// This motion with the named fields replaced.
  GlassDropMotion copyWith({
    double? maxStretch,
    double? saturation,
    Duration? smoothing,
    double? stiffness,
    double? damping,
  }) => GlassDropMotion(
    maxStretch: maxStretch ?? this.maxStretch,
    saturation: saturation ?? this.saturation,
    smoothing: smoothing ?? this.smoothing,
    stiffness: stiffness ?? this.stiffness,
    damping: damping ?? this.damping,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassDropMotion &&
      other.maxStretch == maxStretch &&
      other.saturation == saturation &&
      other.smoothing == smoothing &&
      other.stiffness == stiffness &&
      other.damping == damping;

  @override
  int get hashCode => Object.hash(maxStretch, saturation, smoothing, stiffness, damping);

  @override
  String toString() => isNone
      ? 'GlassDropMotion.none'
      : 'GlassDropMotion(max ${maxStretch.toStringAsFixed(2)}, '
            'saturation ${saturation.toStringAsFixed(0)} px/s², '
            'smoothing ${smoothing.inMilliseconds} ms, spring $stiffness/$damping)';
}

/// The deformation of one drop, fed where the drop is once a frame.
///
/// Pure: no ticker, no widget. [value] is signed — positive stretched along
/// the travel, negative squashed — and [apply] turns it into a size.
///
/// ```dart
/// final GlassDropStretch stretch = GlassDropStretch();
/// // Once a frame, with the seconds since the last one and where the drop is.
/// final double s = stretch.step(1 / 60, dropX);
/// final Size drawn = GlassDropStretch.apply(dropSize, s);
/// ```
///
/// {@category Foundations}
class GlassDropStretch {
  /// A round, still drop deformed by [motion].
  GlassDropStretch([this.motion = const GlassDropMotion()]);

  /// The spec. Changing it keeps the state; [GlassDropMotion.none] makes the
  /// next [step] return 0 and forget it.
  GlassDropMotion motion;

  /// Below this speed, logical px/s, the direction of travel fades out of the
  /// sign — so a drop at rest with a jitter of acceleration stays round, and
  /// a turnaround passes through round rather than flipping.
  static const double kDirectionSpeed = 40;

  bool _has = false;
  double _x = 0;
  double _v = 0;
  double _a = 0;
  double _s = 0;
  double _ds = 0;
  double _target = 0;

  /// The deformation now, between `-maxStretch` and `maxStretch`.
  double get value => _s;

  /// What the spring is heading for.
  double get target => _target;

  /// The smoothed velocity and acceleration along the travel, logical px/s
  /// and px/s².
  double get velocity => _v;

  /// The smoothed acceleration along the travel, logical px/s². See
  /// [velocity].
  double get acceleration => _a;

  /// The position last fed to [step] or [jump].
  double get position => _x;

  /// Round, still in shape and heading nowhere: nothing left to animate unless
  /// the drop moves again.
  bool get isSettled => _s.abs() < 1e-3 && _ds.abs() < 1e-2 && _target.abs() < 1e-3 && _v.abs() < 1 && _a.abs() < 50;

  /// Forgets everything: round, still, and the next [step] is a first sample.
  void reset() {
    _has = false;
    _v = _a = _s = _ds = _target = 0;
  }

  /// The drop is at [x] without having travelled there — a slider's knob
  /// placed under a tap. Its motion so far is forgotten; its shape is not.
  void jump(double x) {
    _x = x;
    _has = true;
    _v = _a = 0;
  }

  /// Advances [dt] seconds to a drop at [x], logical px along its travel, and
  /// returns [value].
  double step(double dt, double x) {
    final GlassDropMotion m = motion;
    if (m.isNone) {
      reset();
      _x = x;
      _has = true;
      return 0;
    }
    if (!_has || dt <= 0) {
      _x = x;
      _has = true;
      return _s;
    }
    // A frame dropped for a second is not a second of motion.
    final double h = dt.clamp(1 / 1000, 1 / 20);
    final double tau = math.max(m.smoothing.inMicroseconds / 1e6, 1e-6);
    final double k = 1 - math.exp(-h / tau);
    final double v = _v + ((x - _x) / h - _v) * k;
    _a += ((v - _v) / h - _a) * k;
    _v = v;
    _x = x;
    // Against the velocity: speeding up in either direction is positive.
    final double along = _a * _tanh(_v / kDirectionSpeed);
    _target = m.maxStretch * _tanh(along / m.saturation);
    // Semi-implicit Euler, in steps short enough to be stable at any spec a
    // person would choose.
    var left = h;
    while (left > 1e-9) {
      final double sub = math.min(left, 1 / 480);
      _ds += (-m.stiffness * (_s - _target) - m.damping * _ds) * sub;
      _s += _ds * sub;
      left -= sub;
    }
    if (_s.abs() > m.maxStretch) {
      _s = _s.sign * m.maxStretch;
      _ds = 0;
    }
    return _s;
  }

  /// A drop of [size] deformed by [stretch] along x: the area kept.
  static Size apply(Size size, double stretch) =>
      stretch == 0 ? size : Size(size.width * (1 + stretch), size.height / (1 + stretch));

  static double _tanh(double x) {
    if (x > 20) {
      return 1;
    }
    if (x < -20) {
      return -1;
    }
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}

/// Runs a [GlassDropStretch] off a ticker while its drop moves, and says when
/// the deformation changed. The package's controls' half of the mechanism.
///
/// Woken by the owner when the drop's position changes; stops itself once the
/// drop is still and the stretch has sprung back. A finger holding a drop
/// still therefore costs no frames.
///
/// It starts with [GlassDropMotion.none]: set [motion] from the control's
/// build, usually through [GlassDropMotion.resolve].
///
/// {@category Foundations}
class GlassDropStretchDriver extends ChangeNotifier {
  /// A driver that reads the drop through [position] on [vsync]'s ticker.
  GlassDropStretchDriver({required TickerProvider vsync, required this.position}) {
    _ticker = vsync.createTicker(_tick);
  }

  /// Where the drop is now, logical px along its travel.
  final double Function() position;

  final GlassDropStretch _model = GlassDropStretch(GlassDropMotion.none);
  late final Ticker _ticker;
  Duration? _last;
  double _shown = 0;

  /// The deformation to draw.
  double get value => _shown;

  /// Whether the ticker is running.
  bool get isActive => _ticker.isActive;

  /// The spec the stretch follows. Setting [GlassDropMotion.none] stops the
  /// ticker and puts the drop back to round at once.
  GlassDropMotion get motion => _model.motion;

  /// Never notifies: set from a build's dependencies, which rebuild anyway.
  set motion(GlassDropMotion value) {
    if (value == _model.motion) {
      return;
    }
    _model.motion = value;
    if (value.isNone) {
      _model.reset();
      _shown = 0;
      _ticker.stop();
    }
  }

  /// The drop moved, or is about to: sample it every frame until it settles.
  void wake() {
    if (_model.motion.isNone || _ticker.isActive) {
      return;
    }
    _last = null;
    _ticker.start();
  }

  /// The drop is where it is without having travelled there. See
  /// [GlassDropStretch.jump].
  void jump() => _model.jump(position());

  void _tick(Duration elapsed) {
    final Duration? last = _last;
    _last = elapsed;
    // The first frame after a wake is one frame of motion: the position
    // changed since the last sample by one event's worth.
    final double dt = last == null ? 1 / 60 : (elapsed - last).inMicroseconds / 1e6;
    final double x = position();
    final bool moved = x != _model.position;
    _model.step(dt, x);
    if (!moved && _model.isSettled) {
      _model
        ..reset()
        ..jump(x);
      _ticker.stop();
      _publish(0);
      return;
    }
    _publish(_model.value);
  }

  void _publish(double s) {
    // Changes under a hundredth of a percent are not drawn: each one is a
    // relayout and a repaint of the drop.
    if (s == _shown || ((s - _shown).abs() < 1e-4 && s != 0)) {
      return;
    }
    _shown = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
