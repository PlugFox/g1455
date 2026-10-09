// Increase contrast, and legibility over a backdrop the application cannot
// describe by one colour.
//
// `flutter test test/glass_legibility_test.dart`
//
//  1. **The level range is exact, over any backdrop.** Every rung shows
//     `mix(b, tint, a)`, monotone in each channel of `b`, so the least and the
//     greatest luminance over the whole cube of backdrops are the fill over
//     black and the fill over white. Checked against a 17³ grid and 4096 random
//     colours, and the grid is required to reach both ends — a range that was
//     merely *wide enough* would pass a one-sided check.
//  2. **A dim is the same law.** `mix(mix(b, black, d), tint, a)` against
//     `dimmed(d).opaqueFillOver(b)`, over the same grid, to 1e-9.
//  3. **The numbers the documentation quotes are the arithmetic's.** `regular`
//     is AA for white over any backdrop (6.05); `frosted` and `clear` need a dim
//     of 0.682 for AA and 0.531 for 3:1 once the level is stored in 8 bits
//     (0.679 and 0.527 before), where Apple's suggested 35% reaches
//     1.98; the better of black and white is never below 4.59 against one level.
//     And the dim is the *least*: a thousandth less misses the floor.
//  4. **The floor is met in pixels.** A frosted card over a white screen,
//     declared rich, with an AA floor: the level drawn at the panel's centre
//     clears 4.5 against the chosen label at every rung, and without the floor
//     it does not.
//  5. **Increase contrast lays an opaque line on the edge, at every rung.** Read
//     in pixels at the panel's first interior column: the label colour exactly,
//     against a level it stands out from by more than WCAG's 3:1 for a boundary;
//     without the switch, that column is the calibrated additive rim. The host
//     reads the switch from `MediaQuery` when nothing is passed.
//  6. **A fused group draws it along the silhouette,** so the bridge between two
//     panels — which no member's own shape has — gets an outline too.
//
// Breaks, each failing its own arm: `levelRange` returning the fill over the
// mean grey instead of over black (1); the dim's tint left undivided by `a'`
// (2); `dimmingFor` returning `hi + 0.01` (3); `legibility` ignoring
// `richBackdrop` (4: a declared white mean hides nothing, so the break has to be
// over a backdrop whose mean is not white — the arm's backdrop is half black and
// half white); `uRimMix` set to 0 in `RenderGlassSurface` (5, full rung only —
// the cheap rung's line is the canvas's) and in `RenderGlassGroup` (6).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

// The arms print what they read; a person reads them once.
// ignore_for_file: avoid_print

const Size kScreen = Size(360, 220);
const Size kPanel = Size(200, 60);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);

void main() {
  final shipped = <GlassFinish>[GlassFinish.regularDark, GlassFinish.frosted, GlassFinish.clear];

  List<Color> grid() => <Color>[
    for (var r = 0; r <= 16; r++)
      for (var g = 0; g <= 16; g++)
        for (var b = 0; b <= 16; b++) Color.from(alpha: 1, red: r / 16, green: g / 16, blue: b / 16),
  ];
  List<Color> random() {
    final rng = math.Random(204);
    return <Color>[
      for (var i = 0; i < 4096; i++)
        Color.from(alpha: 1, red: rng.nextDouble(), green: rng.nextDouble(), blue: rng.nextDouble()),
    ];
  }

  // -------------------------------------------------------------------------
  // 1. The range.
  // -------------------------------------------------------------------------

  test('the level range is exact over every backdrop, and the grid reaches both ends', () {
    for (final GlassFinish finish in shipped) {
      final (:Color darkest, :Color lightest) = finish.levelRange();
      final double lo = darkest.computeLuminance();
      final double hi = lightest.computeLuminance();
      var seenLo = double.infinity;
      var seenHi = -double.infinity;
      for (final Color b in <Color>[...grid(), ...random()]) {
        final double l = finish.opaqueFillOver(b).computeLuminance();
        expect(l, greaterThanOrEqualTo(lo - 1e-12), reason: '${finish.name} over $b');
        expect(l, lessThanOrEqualTo(hi + 1e-12), reason: '${finish.name} over $b');
        seenLo = math.min(seenLo, l);
        seenHi = math.max(seenHi, l);
      }
      print(
        '${finish.name}: luminance ${lo.toStringAsFixed(4)}..${hi.toStringAsFixed(4)}, '
        'seen ${seenLo.toStringAsFixed(4)}..${seenHi.toStringAsFixed(4)}',
      );
      // Reached, not merely bounded: the grid holds black and white, so a range
      // wider than the truth fails here even though it passes above.
      expect(seenLo, closeTo(lo, 1e-12));
      expect(seenHi, closeTo(hi, 1e-12));
    }
  });

  // -------------------------------------------------------------------------
  // 2. A dim is the same law.
  // -------------------------------------------------------------------------

  test('a dim under the glass is the glass with a different tint', () {
    for (final GlassFinish finish in shipped) {
      for (final double d in <double>[0, 0.1, kAppleDimmingOpacity, 0.679, 1]) {
        final GlassFinish dimmed = finish.dimmed(d);
        expect(dimmed.name, finish.name, reason: 'the damage tables are keyed by the name');
        expect(dimmed.blurSigmaLogical, finish.blurSigmaLogical);
        expect(dimmed.rim, finish.rim);
        final double a = finish.tint.a;
        var worst = 0.0;
        for (final Color b in grid()) {
          double law(double base, double t) => ((1 - d) * base) * (1 - a) + t * a;
          final Color got = dimmed.opaqueFillOver(b);
          worst = math.max(worst, (got.r - law(b.r, finish.tint.r)).abs());
          worst = math.max(worst, (got.g - law(b.g, finish.tint.g)).abs());
          worst = math.max(worst, (got.b - law(b.b, finish.tint.b)).abs());
        }
        expect(worst, lessThan(1e-9), reason: '${finish.name} dimmed $d');
      }
    }
  });

  // -------------------------------------------------------------------------
  // 3. The quoted numbers.
  // -------------------------------------------------------------------------

  test('the numbers the documentation quotes, and the dim is the least one', () {
    expect(GlassFinish.regularDark.foregroundOverAny(), kWhite);
    expect(GlassFinish.regularDark.worstContrast(kWhite), closeTo(6.05, 0.005));
    expect(GlassFinish.regularDark.dimmingFor(kTextContrastAA), 0);
    for (final GlassFinish finish in <GlassFinish>[GlassFinish.frosted, GlassFinish.clear]) {
      expect(finish.foregroundOverAny(), kBlack);
      expect(finish.worstContrast(kBlack), closeTo(1.76, 0.005));
      final double aa = finish.dimmingFor(kTextContrastAA)!;
      final double nonText = finish.dimmingFor(kNonTextContrast)!;
      final double apple = finish.dimmed(kAppleDimmingOpacity).worstContrast(kWhite);
      print('${finish.name}: dim for AA $aa, for 3:1 $nonText; Apple\'s 35% reaches $apple');
      expect(aa, closeTo(0.682, 0.0005));
      expect(nonText, closeTo(0.531, 0.0005));
      expect(apple, closeTo(1.98, 0.005));
      expect(finish.dimmed(aa).worstContrast(kWhite), greaterThanOrEqualTo(kTextContrastAA));
      // The least, twice over: the continuous floor sits at 0.679, and the
      // storage correction costs no more than a few thousandths above it.
      expect(finish.dimmed(0.678).worstContrast(kWhite), lessThan(kTextContrastAA));
      expect(aa - 0.679, inInclusiveRange(0, 0.005));
    }
    // The better of black and white against one level, over every level.
    var least = double.infinity;
    for (var v = 0; v <= 1000; v++) {
      final level = Color.from(alpha: 1, red: v / 1000, green: v / 1000, blue: v / 1000);
      least = math.min(
        least,
        math.max(GlassFinish.contrastRatio(level, kBlack), GlassFinish.contrastRatio(level, kWhite)),
      );
    }
    expect(least, closeTo(4.59, 0.005));
  });

  test('the theme resolves the floor against what was declared', () {
    // Flat and declared: chosen against it, and frosted over light already
    // clears AA with black — nothing to dim.
    final flat = const GlassThemeData(
      finish: GlassFinish.frosted,
      backdrop: Color(0xFFE8E8E8),
      minLabelContrast: kTextContrastAA,
    ).legibility();
    expect(flat.finish, GlassFinish.frosted);
    expect(flat.label, kBlack);
    // The same screen declared rich: the worst case, and the dim that meets it.
    final rich = const GlassThemeData(
      finish: GlassFinish.frosted,
      backdrop: Color(0xFFE8E8E8),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
    ).legibility();
    expect(rich.finish, GlassFinish.frosted.dimmed(GlassFinish.frosted.dimmingFor(kTextContrastAA)!));
    expect(rich.label, kWhite);
    expect(rich.finish.worstContrast(rich.label), greaterThanOrEqualTo(kTextContrastAA));
    // No floor: the finish is the finish.
    expect(const GlassThemeData(finish: GlassFinish.clear, richBackdrop: true).legibility().finish, GlassFinish.clear);
    // The outline only exists under the switch.
    expect(const GlassThemeData().legibility().rim, isNull);
  });

  // -------------------------------------------------------------------------
  // 4. The floor in pixels.
  // -------------------------------------------------------------------------

  testWidgets('a rich backdrop with an AA floor is legible at the panel, at every rung', (
    WidgetTester tester,
  ) async {
    for (final GlassTier tier in GlassTier.values) {
      final worst = <bool, double>{};
      for (final bool floor in <bool>[false, true]) {
        await _mount(
          tester,
          finish: GlassFinish.frosted,
          tier: tier,
          // Half black, half white, and the panel straddles the join: no one
          // level describes what is under it, which is what "rich" declares.
          halves: true,
          richBackdrop: true,
          backdrop: const Color(0xFF808080),
          minLabelContrast: floor ? kTextContrastAA : null,
        );
        final Color label = GlassThemeData(
          finish: GlassFinish.frosted,
          richBackdrop: true,
          minLabelContrast: floor ? kTextContrastAA : null,
        ).legibility().label;
        // Both halves, well inside the panel and past the refraction band.
        final Color dark = await _pixel(tester, 120, 110);
        final Color light = await _pixel(tester, 240, 110);
        worst[floor] = math.min(
          GlassFinish.contrastRatio(dark, label),
          GlassFinish.contrastRatio(light, label),
        );
        print(
          '${tier.name}, floor $floor: label ${_hex(label)} over ${_hex(dark)} / ${_hex(light)} '
          '— worst ${worst[floor]!.toStringAsFixed(2)}',
        );
      }
      if (tier != GlassTier.opaque) {
        // The bottom rung shows no image, so there is nothing to fail over.
        expect(worst[false], lessThan(kTextContrastAA), reason: 'the arm has to be able to fail');
      }
      expect(worst[true], greaterThanOrEqualTo(kTextContrastAA), reason: tier.name);
    }
  });

  // -------------------------------------------------------------------------
  // 5. Increase contrast.
  // -------------------------------------------------------------------------

  testWidgets('increase contrast lays the label colour on the edge, at every rung', (
    WidgetTester tester,
  ) async {
    const Color light = Color(0xFFE8E8E8);
    final Color expected = GlassFinish.frosted.highContrastRim(backdrop: light);
    expect(expected, kBlack);
    for (final GlassTier tier in GlassTier.values) {
      final edge = <bool, Color>{};
      for (final bool on in <bool>[false, true]) {
        await _mount(
          tester,
          finish: GlassFinish.frosted,
          tier: tier,
          backdrop: light,
          highContrast: on,
        );
        // x = 80 is the panel's first column; the middle row is on the straight
        // part of the edge, away from the corners.
        edge[on] = await _pixel(tester, 80, 110);
      }
      final Color inside = await _pixel(tester, 180, 110);
      final double contrast = GlassFinish.contrastRatio(edge[true]!, inside);
      print(
        '${tier.name}: edge ${_hex(edge[false]!)} -> ${_hex(edge[true]!)}, '
        'against the level ${_hex(inside)} at ${contrast.toStringAsFixed(2)}',
      );
      expect(_distance(edge[true]!, expected), lessThanOrEqualTo(1), reason: tier.name);
      expect(contrast, greaterThanOrEqualTo(kNonTextContrast));
      // Without the switch the edge is the additive rim, which over this light
      // level is *lighter* than the level — the opposite direction.
      expect(edge[false]!.computeLuminance(), greaterThan(inside.computeLuminance() - 1e-3));
    }
  });

  testWidgets('the host reads the switch from MediaQuery when nothing is passed', (
    WidgetTester tester,
  ) async {
    GlassThemeData? seen;
    for (final bool platform in <bool>[false, true]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: kScreen, highContrast: platform),
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            child: Builder(
              builder: (BuildContext context) {
                seen = GlassTheme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen!.highContrast, platform);
    }
    // An explicit value wins: macOS relays nothing, so an application passes
    // what it read natively.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: kScreen),
        child: GlassHost(
          hardware: GlassHardware.appleMetal,
          highContrast: true,
          child: Builder(
            builder: (BuildContext context) {
              seen = GlassTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(seen!.highContrast, isTrue);
  });

  // -------------------------------------------------------------------------
  // 6. Along the silhouette.
  // -------------------------------------------------------------------------

  testWidgets('a fused group draws the outline along the bridge', (WidgetTester tester) async {
    final counts = <bool, int>{};
    for (final bool on in <bool>[false, true]) {
      await _mount(
        tester,
        finish: GlassFinish.frosted,
        tier: GlassTier.full,
        backdrop: const Color(0xFFE8E8E8),
        highContrast: on,
        grouped: true,
      );
      // The gap between the two panels, x 170..190: only the bridge is there,
      // and only an outline along the bridge can be black.
      var dark = 0;
      final Uint8List px = await _pixels(tester);
      for (var y = 60; y < 160; y++) {
        for (var x = 172; x < 188; x++) {
          final int i = (y * kScreen.width.toInt() + x) * 4;
          if (px[i] < 40 && px[i + 1] < 40 && px[i + 2] < 40) {
            dark++;
          }
        }
      }
      counts[on] = dark;
    }
    print('bridge gap, dark pixels: ${counts[false]} without, ${counts[true]} with');
    expect(counts[false], 0);
    expect(counts[true], greaterThan(10));
  });
}

// ---------------------------------------------------------------------------
// The fixture.
// ---------------------------------------------------------------------------

final GlobalKey _shotKey = GlobalKey();

Future<void> _mount(
  WidgetTester tester, {
  required GlassFinish finish,
  required GlassTier tier,
  Color? backdrop,
  bool halves = false,
  bool richBackdrop = false,
  double? minLabelContrast,
  bool highContrast = false,
  bool grouped = false,
}) async {
  const radius = BorderRadius.all(Radius.circular(24));
  final Widget glass = grouped
      ? GlassGroup(
          spacing: 40,
          child: Stack(
            children: const <Widget>[
              Positioned(left: 80, top: 80, width: 90, height: 60, child: GlassSurface(borderRadius: radius)),
              Positioned(left: 190, top: 80, width: 90, height: 60, child: GlassSurface(borderRadius: radius)),
            ],
          ),
        )
      : Stack(
          children: const <Widget>[
            Positioned(left: 80, top: 80, width: 200, height: 60, child: GlassSurface(borderRadius: radius)),
          ],
        );
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            resolution: const ProxyResolution.full(),
            finish: finish,
            backdrop: backdrop,
            richBackdrop: richBackdrop,
            minLabelContrast: minLabelContrast,
            highContrast: highContrast,
            tier: GlassTierChoice(tier, GlassTierReason.pinnedByHost),
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    if (halves)
                      const Positioned.fill(
                        // Stretched: a childless `ColoredBox` takes its smallest
                        // size, and a row's cross axis is loose, so without it
                        // both halves are zero tall and the "black" half is the
                        // absence of a backdrop.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: ColoredBox(color: kBlack)),
                            Expanded(child: ColoredBox(color: kWhite)),
                          ],
                        ),
                      )
                    else
                      Positioned.fill(child: ColoredBox(color: backdrop ?? const Color(0xFF808080))),
                    // Keyed on everything the arms vary, so no two arms share a
                    // render object and a retained layer.
                    Positioned.fill(
                      child: KeyedSubtree(
                        key: ValueKey<Object>(
                          Object.hash(tier, highContrast, minLabelContrast, grouped, halves),
                        ),
                        child: glass,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
  late Uint8List px;
  await tester.runAsync(() async {
    px = (await shot.toByteData())!.buffer.asUint8List();
  });
  shot.dispose();
  return px;
}

Future<Color> _pixel(WidgetTester tester, int x, int y) async {
  final Uint8List px = await _pixels(tester);
  final int i = (y * kScreen.width.toInt() + x) * 4;
  return Color.fromARGB(255, px[i], px[i + 1], px[i + 2]);
}

int _distance(Color a, Color b) {
  int c(double v) => (v * 255).round();
  return <int>[
    (c(a.r) - c(b.r)).abs(),
    (c(a.g) - c(b.g)).abs(),
    (c(a.b) - c(b.b)).abs(),
  ].reduce(math.max);
}

String _hex(Color c) =>
    '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0')}';
