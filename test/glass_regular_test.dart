// `.regular` is two materials, and the host picks the one the screen is on.
//
// `flutter test test/glass_regular_test.dart`
//
//  1. **The constants are the run's.** `provenance/regular/` is the digest of
//     the native reference rig (Apple's own glass) in either appearance and of
//     eight flat greys under a bar-sized capsule. The dark fit has to land on
//     [GlassFinish.regularDark] — the reference's own, from an iPad — which
//     is what says the simulator reads this material; `.clear` reading the same in both appearances is what says the
//     appearance reached the native side and moved nothing it should not.
//  2. **The choice.** Against the appearance alone, and against a declared
//     backdrop on each side of each threshold.
//  3. **The host follows it.** Unnamed, a light screen gets the light branch,
//     a dark one the dark, a dark band declared on a light screen the dark;
//     the appearance changing under a mounted host moves the branch; a named
//     finish holds whatever the appearance does; with no host above,
//     `GlassTheme.of` answers the same way.
//
// Breaks, each undone by swapping the string back:
//  - in `GlassFinish.regular`, `return level < threshold ? regularDark :
//    regularLight;` -> `return appearance == Brightness.dark ? regularDark :
//    regularLight;`: a declared level is ignored, and the choice arm and the
//    declared-level arm fail on it;
//  - in `_GlassHostState.didChangeDependencies`, `} else if (resolved != _finish) {`
//    -> `} else if (false) {`: the host keeps the branch it mounted with, and
//    the appearance arm fails;
//  - in `_GlassHostState.didUpdateWidget`, `final GlassFinish resolved =
//    _resolveFinish();` -> `final GlassFinish resolved = _finish;`: a newly
//    declared level or finish is not seen, and the declared-level arm fails.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const String kDigest = 'provenance/regular/d230-regular-branches.json';

/// Least squares through (x, y): slope, intercept and the worst residual.
({double slope, double intercept, double worst}) _fit(List<double> xs, List<double> ys) {
  final int n = xs.length;
  final double mx = xs.reduce((double a, double b) => a + b) / n;
  final double my = ys.reduce((double a, double b) => a + b) / n;
  var sxy = 0.0;
  var sxx = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  final double slope = sxy / sxx;
  final double intercept = my - slope * mx;
  var worst = 0.0;
  for (var i = 0; i < n; i++) {
    final double r = (ys[i] - (slope * xs[i] + intercept)).abs();
    if (r > worst) {
      worst = r;
    }
  }
  return (slope: slope, intercept: intercept, worst: worst);
}

List<double> _doubles(Object? list) => <double>[for (final Object? v in list! as List<Object?>) (v! as num).toDouble()];

void main() {
  final Map<String, Object?> digest = jsonDecode(File(kDigest).readAsStringSync()) as Map<String, Object?>;
  final s4 = digest['s4']! as Map<String, Object?>;
  final flat = digest['flat']! as Map<String, Object?>;

  ({double slope, double intercept, double worst}) s4Fit(String style, String material) {
    final m = (s4[style]! as Map<String, Object?>)[material]! as Map<String, Object?>;
    return _fit(_doubles(m['backdrop_luma']), _doubles(m['material_luma']));
  }

  // -------------------------------------------------------------------------
  // 1. The constants are the run's.
  // -------------------------------------------------------------------------

  test('the dark fit is the reference\'s, so the simulator reads this material', () {
    final fit = s4Fit('dark', 'regular');
    const GlassFinish dark = GlassFinish.regularDark;
    expect(fit.slope, closeTo(1 - dark.tint.a, 0.003));
    expect(fit.intercept / (1 - fit.slope), closeTo(255 * dark.tint.r, 2), reason: 'the tint is not the reference\'s');
  });

  test('the light branch is the light fit, and the law describes it as well as the dark', () {
    final fit = s4Fit('light', 'regular');
    const GlassFinish light = GlassFinish.regularLight;
    expect(fit.slope, closeTo(1 - light.tint.a, 0.003));
    expect(fit.intercept / (1 - fit.slope), closeTo(255 * light.tint.r, 1));
    expect(light.tint.r, light.tint.g, reason: 'every flat level read neutral');
    expect(light.tint.g, light.tint.b);
    expect(fit.worst, lessThan(1.5), reason: 'mix(base, tint, a) does not describe it');
    expect(light.blurSigmaLogical, GlassFinish.regularDark.blurSigmaLogical);
  });

  test('the appearance reached the native side and moved only `.regular`', () {
    final dark = s4Fit('dark', 'clear');
    final light = s4Fit('light', 'clear');
    expect(light.slope, closeTo(dark.slope, 0.001));
    expect(light.intercept, closeTo(dark.intercept, 0.2));
    // And it did move `.regular`, or the two fits above are one fit twice.
    expect(s4Fit('light', 'regular').intercept - s4Fit('dark', 'regular').intercept, greaterThan(100));
  });

  test('each threshold sits between the greys that bracket the switch', () {
    for (final (String key, double threshold) in <(String, double)>[
      ('light_threshold', GlassFinish.kRegularSwitchLight),
      ('dark_threshold', GlassFinish.kRegularSwitchDark),
    ]) {
      final rows = <({double level, double glass})>[
        for (final Map<String, Object?> r in (flat[key]! as List<Object?>).cast<Map<String, Object?>>())
          (level: (r['level']! as num).toDouble(), glass: (r['glass']! as num).toDouble()),
      ];
      // Dark glass reads under mid-grey and light glass over it, with nothing
      // in between: a switch, not a ramp.
      final double lastDark = rows.lastWhere((r) => r.glass < 128).level;
      final double firstLight = rows.firstWhere((r) => r.glass >= 128).level;
      expect(rows.where((r) => r.glass >= 128 && r.level < lastDark), isEmpty, reason: '$key is not one switch');
      expect(firstLight - lastDark, 4, reason: '$key was not read to one step');
      expect(threshold, (lastDark + firstLight) / 2, reason: key);
    }
  });

  // -------------------------------------------------------------------------
  // 2. The choice.
  // -------------------------------------------------------------------------

  test('the appearance picks the branch of an undeclared screen, a declared level picks its own', () {
    expect(GlassFinish.regular(appearance: Brightness.light), GlassFinish.regularLight);
    expect(GlassFinish.regular(appearance: Brightness.dark), GlassFinish.regularDark);
    Color grey(int v) => Color.fromARGB(255, v, v, v);
    for (final (Brightness appearance, int below, int above) in <(Brightness, int, int)>[
      (Brightness.light, 53, 55),
      (Brightness.dark, 221, 223),
    ]) {
      expect(GlassFinish.regular(appearance: appearance, backdrop: grey(below)), GlassFinish.regularDark);
      expect(GlassFinish.regular(appearance: appearance, backdrop: grey(above)), GlassFinish.regularLight);
    }
    // A colour by its luma: a saturated blue is dark whatever its channels.
    expect(
      GlassFinish.regular(appearance: Brightness.light, backdrop: const Color(0xFF0000FF)),
      GlassFinish.regularDark,
    );
  });

  // -------------------------------------------------------------------------
  // 3. The host follows it.
  // -------------------------------------------------------------------------

  testWidgets('the appearance moving under a mounted host moves its branch', (WidgetTester tester) async {
    // The host is one widget instance throughout, so nothing rebuilds it but
    // the appearance it depends on — which is how an application's appearance
    // changes: `MediaQuery` notifies its dependents, and the host's parent need
    // not rebuild at all. A first version of this arm re-pumped the host with
    // each appearance, and `didUpdateWidget` caught the change before the
    // dependency path was ever exercised: its break broke nothing.
    final appearance = ValueNotifier<Brightness>(Brightness.light);
    GlassFinish? seen;
    final Widget host = GlassHost(
      hardware: GlassHardware.appleMetal,
      child: Builder(
        builder: (BuildContext context) {
          seen = GlassTheme.of(context).finish;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<Brightness>(
          valueListenable: appearance,
          builder: (BuildContext context, Brightness b, Widget? child) => MediaQuery(
            data: MediaQueryData(platformBrightness: b),
            child: child!,
          ),
          child: host,
        ),
      ),
    );
    expect(seen, GlassFinish.regularLight);
    appearance.value = Brightness.dark;
    await tester.pump();
    expect(seen, GlassFinish.regularDark);
    appearance.value = Brightness.light;
    await tester.pump();
    expect(seen, GlassFinish.regularLight);
    appearance.dispose();
  });

  testWidgets('a declared level picks the branch, and a named finish holds', (WidgetTester tester) async {
    GlassFinish? seen;
    Future<GlassFinish> mount({Color? backdrop, GlassFinish? finish}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassHost(
              hardware: GlassHardware.appleMetal,
              backdrop: backdrop,
              finish: finish,
              child: Builder(
                builder: (BuildContext context) {
                  seen = GlassTheme.of(context).finish;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      return seen!;
    }

    // One state throughout: each step is `didUpdateWidget`.
    expect(await mount(), GlassFinish.regularLight);
    // A dark band declared on a light screen is dark glass, as Apple's is.
    expect(await mount(backdrop: const Color(0xFF202020)), GlassFinish.regularDark);
    expect(await mount(backdrop: const Color(0xFFF4F1EA)), GlassFinish.regularLight);
    // Named, it holds.
    expect(await mount(finish: GlassFinish.regularDark), GlassFinish.regularDark);
  });

  testWidgets('with no host above, the theme answers the same way', (WidgetTester tester) async {
    late GlassFinish seen;
    for (final (Brightness appearance, GlassFinish expected) in <(Brightness, GlassFinish)>[
      (Brightness.light, GlassFinish.regularLight),
      (Brightness.dark, GlassFinish.regularDark),
    ]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(platformBrightness: appearance),
          child: Builder(
            builder: (BuildContext context) {
              seen = GlassTheme.of(context).finish;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, expected);
    }
  });
}
