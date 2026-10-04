// The drop's stretch, as a model: fed where the drop is once a frame, it says
// how long and thin the drop is drawn.
//
// `flutter test test/glass_drop_motion_test.dart`
//
// The claims are the ones a person sees: round at rest and gliding, long
// setting off and short arriving — in either direction — never past the clamp,
// and nothing at all when the spec is none. What the controls do with it, and
// that it costs them no capture, is in their own files.
//
// Breaks, each undone by swapping the string back:
//  - in `GlassDropStretch.step`, `_a * _tanh(_v / kDirectionSpeed)` ->
//    `_a.abs()`: braking stretches instead of squashing, and the braking arm
//    fails;
//  - in `GlassDropStretch.step`, drop the clamp after the spring: the clamp
//    arm overshoots.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const double _frame = 1 / 60;

/// Feeds [x] at every frame from 0 to [seconds] and returns what the drop
/// was drawn as on each.
List<double> _run(GlassDropStretch s, double Function(double t) x, double seconds) => <double>[
  for (var t = 0.0; t <= seconds; t += _frame) s.step(_frame, x(t)),
];

void main() {
  test('at rest the drop is round', () {
    final s = GlassDropStretch();
    expect(_run(s, (_) => 120, 1), everyElement(0));
    expect(s.isSettled, isTrue);
  });

  test('gliding at a constant speed the drop is round, either way', () {
    for (final double speed in <double>[300, -300, 1200]) {
      final s = GlassDropStretch();
      // Already moving when first seen: no launch to see.
      s.jump(0);
      final List<double> drawn = _run(s, (double t) => speed * t, 1);
      expect(drawn.skip(30).map((double v) => v.abs()), everyElement(lessThan(1e-3)), reason: 'at $speed px/s');
    }
  });

  test('setting off it stretches, arriving it squashes, in either direction', () {
    for (final double sign in <double>[1, -1]) {
      final s = GlassDropStretch();
      // A tab's spring over three tabs, from rest at 0.
      final sim = _Spring(distance: 3 * 71.5);
      final List<double> drawn = _run(s, (double t) => sign * sim.at(t), 1.5);
      final double most = drawn.reduce(math.max);
      final double least = drawn.reduce(math.min);
      expect(most, greaterThan(0.05), reason: 'sign $sign: did not stretch setting off');
      expect(least, lessThan(-0.05), reason: 'sign $sign: did not squash arriving');
      // The stretch comes first.
      expect(drawn.indexOf(most), lessThan(drawn.indexOf(least)), reason: 'sign $sign');
      expect(drawn.last.abs(), lessThan(1e-3), reason: 'sign $sign: did not spring back');
    }
  });

  test('a finger let stop squashes the drop, and it springs back', () {
    final s = GlassDropStretch();
    final List<double> drawn = _run(s, (double t) => 1000 * math.min(t, 0.4), 1.5);
    final int stop = (0.4 / _frame).round();
    expect(drawn.take(stop).reduce(math.max), greaterThan(0.03));
    expect(drawn.skip(stop).reduce(math.min), lessThan(-0.03));
    expect(drawn.last.abs(), lessThan(1e-3));
    expect(s.isSettled, isTrue);
  });

  test('clamped to the spec, however hard it is thrown', () {
    for (final double max in <double>[0.12, 0.3]) {
      final s = GlassDropStretch(GlassDropMotion(maxStretch: max, saturation: 100));
      // A teleport back and forth: accelerations of millions of px/s².
      final List<double> drawn = _run(s, (double t) => (t * 60).floor().isEven ? 0 : 400, 1);
      expect(drawn.map((double v) => v.abs()), everyElement(lessThanOrEqualTo(max)));
      expect(drawn.map((double v) => v.abs()).reduce(math.max), closeTo(max, 1e-9), reason: 'never reached');
    }
  });

  test('none deforms nothing, and forgets what it had', () {
    final s = GlassDropStretch(GlassDropMotion.none);
    expect(_run(s, (double t) => _Spring(distance: 200).at(t), 1), everyElement(0));
    final t = GlassDropStretch();
    _run(t, (double t) => 1000 * t, 0.1);
    expect(t.value, isNot(0));
    t.motion = GlassDropMotion.none;
    expect(t.step(_frame, 200), 0);
    expect(GlassDropMotion.none.isNone, isTrue);
    expect(const GlassDropMotion(maxStretch: 0), GlassDropMotion.none);
    expect(GlassDropMotion.none.reach(const Size(100, 40)), Size.zero);
  });

  test('a jump is not a launch', () {
    final s = GlassDropStretch();
    s.step(_frame, 0);
    s.jump(250);
    expect(_run(s, (_) => 250, 0.5), everyElement(0));
  });

  test('the deformation keeps the area, and the reach bounds it', () {
    const held = Size(99.5, 74);
    const motion = GlassDropMotion();
    for (final double s in <double>[motion.maxStretch, -motion.maxStretch, 0.05]) {
      final Size drawn = GlassDropStretch.apply(held, s);
      expect(drawn.width * drawn.height, closeTo(held.width * held.height, 1e-9));
      final Size reach = motion.reach(held);
      expect((drawn.width - held.width) / 2, lessThanOrEqualTo(reach.width + 1e-9));
      expect((drawn.height - held.height) / 2, lessThanOrEqualTo(reach.height + 1e-9));
    }
  });

  testWidgets('the theme carries it, a control may name its own, and reduced motion turns it off', (
    WidgetTester tester,
  ) async {
    const own = GlassDropMotion(maxStretch: 0.2);
    final seen = <GlassDropMotion>[];
    Future<void> pump({GlassDropMotion? theme, GlassDropMotion? declared, bool reduced = false}) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: GlassTheme(
          data: theme == null ? const GlassThemeData() : GlassThemeData(dropMotion: theme),
          child: Builder(
            builder: (BuildContext context) {
              seen.add(GlassDropMotion.resolve(context, declared));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await pump();
    await pump(theme: GlassDropMotion.none);
    await pump(theme: GlassDropMotion.none, declared: own);
    await pump(declared: own, reduced: true);
    expect(seen, <GlassDropMotion>[const GlassDropMotion(), GlassDropMotion.none, own, GlassDropMotion.none]);
    expect(const GlassThemeData().dropMotion, const GlassDropMotion());
    expect(const GlassThemeData().copyWith(dropMotion: own).dropMotion, own);
    expect(const GlassThemeData(dropMotion: own), isNot(const GlassThemeData()));
  });

  testWidgets('a host declares it for every drop below', (WidgetTester tester) async {
    const own = GlassDropMotion(maxStretch: 0.2);
    GlassDropMotion? seen;
    Future<void> pump(GlassHost Function(Widget child) host) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: host(
          Builder(
            builder: (BuildContext context) {
              seen = GlassDropMotion.resolve(context, null);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await pump((Widget child) => GlassHost(child: child));
    expect(seen, const GlassDropMotion());
    await pump((Widget child) => GlassHost(dropMotion: own, child: child));
    expect(seen, own);
    await pump((Widget child) => GlassHost(dropMotion: GlassDropMotion.none, child: child));
    expect(seen, GlassDropMotion.none);
  });
}

/// The tab bar's slide spring (stiffness 380, damping 36, unit mass) from rest
/// at 0 to [distance], in closed form.
class _Spring {
  _Spring({required this.distance});

  final double distance;

  double at(double t) {
    const double k = 380;
    const double c = 36;
    final double w0 = math.sqrt(k);
    final double zeta = c / (2 * w0);
    final double wd = w0 * math.sqrt(1 - zeta * zeta);
    final double e = math.exp(-zeta * w0 * t);
    return distance * (1 - e * (math.cos(wd * t) + zeta * w0 / wd * math.sin(wd * t)));
  }
}
