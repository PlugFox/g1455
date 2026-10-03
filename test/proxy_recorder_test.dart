// Phase A, step 2 — recording a proxy at a chosen resolution, and the map back.
//
// `flutter test test/glass/proxy_recorder_test.dart`
//
// The capture is the biggest single line of the budget (40% of the addition over
// the floor, D63) and resolution is the one knob on it whose quality cost has
// already been measured. What this file checks is not that knob's price — that
// belongs to a device — but the four ways an implementation of it is silently
// wrong:
//
//  1. **It is not the same picture.** A recorder that crops where it should
//     scale passes every size assertion. Checked by mean colour, which a crop
//     of an asymmetric scene cannot reproduce.
//  2. **The map is off.** An error in `texel = (logical - origin) * scale` is a
//     fraction of a pixel of shift over the whole backdrop, visible on the rim
//     and nowhere else. Checked by landmark, at four divisors and at a region
//     whose origin is not zero — the case that catches a missing `- origin`.
//  3. **The size is off by a row.** `Rect.fromLTWH` stores `bottom = top + h`,
//     so an awkward `top` makes `height` differ by an ULP and `ceil` turns that
//     into a whole extra row. The arm reproduces the trap first and then shows
//     the snap removing it, because a fix nobody watched fail is not a fix.
//  4. **The two routes have drifted.** The pass and the stock capture must agree
//     at full resolution, or the fallback is not a fallback.
//
// And one arm that is about the numbers rather than the code: the damage table
// in `ProxyResolution` is re-derived from the report it was taken from, which is
// still on disk. A constant copied by hand is a constant that drifts.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_recorder.dart';
import 'package:g1455/src/proxy/proxy_resolution.dart';

const Size kArea = Size(200, 200);
const Color kPage = Color(0xFF102030);
const Color kBox = Color(0xFF80C0A0);
const Color kOther = Color(0xFFC08040);

const Color kMarkColour = Color(0xFFE00000);

const Rect kLandmark = Rect.fromLTWH(40, 40, 80, 60);
const Rect kSecond = Rect.fromLTWH(40, 120, 80, 40);

/// Small on purpose. A landmark the size of a quadrant is found by a map that
/// is wrong by tens of pixels — measured: dropping `- region.topLeft` from
/// [ProxyRecording.toTexel] still hit [kLandmark] at every divisor, and the arm
/// passed. Two logical px across at the eighth is what makes a shift a miss.
const Rect kMark = Rect.fromLTWH(140, 60, 12, 8);

/// Inside the smaller region below, and on the page. Chosen so the *wrong* map
/// puts it outside the image rather than on another colour — which is the other
/// half of what the first version got wrong: the reader clamped, so an
/// out-of-range texel came back as the edge pixel and the edge was page-coloured.
const Offset kOnPage = Offset(150, 30);

void main() {
  // -------------------------------------------------------------------------
  // 1. The two routes agree, so the fallback is one.
  // -------------------------------------------------------------------------

  testWidgets('the pass and the stock capture agree at full resolution', (
    WidgetTester tester,
  ) async {
    final RenderRepaintBoundary root = await _mount(tester);
    final Rect region = Offset.zero & kArea;
    final ProxyRecording ours = ProxyRecorder.walk(
      root,
      region: region,
      resolution: const ProxyResolution.full(),
      devicePixelRatio: 1,
    );
    final ProxyRecording stock = ProxyRecorder.stock(
      root,
      region: region,
      resolution: const ProxyResolution.full(),
      devicePixelRatio: 1,
    );
    final _Diff diff = await _compare(tester, ours.image, stock.image);
    expect(ours.log, isNotNull, reason: 'the pass route reports what it saw');
    expect(stock.log, isNull, reason: 'the stock route runs no pass and must not pretend to');
    expect(ours.log!.layersMinted, 0);
    ours.dispose();
    stock.dispose();
    expect(diff.differing, 0, reason: 'the two routes have drifted: $diff');
  });

  // -------------------------------------------------------------------------
  // 2. Size, and that it is a scale rather than a crop.
  // -------------------------------------------------------------------------

  testWidgets('every divisor gives the size the engine computes, and the same picture', (
    WidgetTester tester,
  ) async {
    final RenderRepaintBoundary root = await _mount(tester);
    final Rect region = Offset.zero & kArea;

    final ProxyRecording full = ProxyRecorder.walk(
      root,
      region: region,
      resolution: const ProxyResolution.full(),
      devicePixelRatio: 3,
    );
    final _Rgb reference = await _meanColour(tester, full.image);

    for (final int divisor in <int>[1, 2, 4, 8]) {
      final resolution = ProxyResolution.divisor(divisor);
      final ProxyRecording rec = ProxyRecorder.walk(
        root,
        region: region,
        resolution: resolution,
        devicePixelRatio: 3,
      );
      expect(rec.image.width, rec.expectedSize.width, reason: 'divisor $divisor width');
      expect(rec.image.height, rec.expectedSize.height, reason: 'divisor $divisor height');
      expect(rec.image.width, (200 * 3 / divisor).ceil(), reason: 'divisor $divisor is not the ratio');

      // The control that separates a downscale from a crop: this corpus is
      // asymmetric, so a crop of any corner has a different mean.
      final _Rgb mean = await _meanColour(tester, rec.image);
      debugPrint('divisor $divisor: ${rec.image.width}x${rec.image.height} mean $mean');
      expect(
        mean.distanceTo(reference),
        lessThan(2.0),
        reason: 'divisor $divisor is not the same picture: $mean against $reference',
      );
      rec.dispose();
    }
    full.dispose();
  });

  // -------------------------------------------------------------------------
  // 3. The map, at four divisors and at an origin that is not zero.
  // -------------------------------------------------------------------------

  testWidgets('a landmark lands where toTexel says, from a region at the origin', (
    WidgetTester tester,
  ) async {
    final RenderRepaintBoundary root = await _mount(tester);
    await _checkLandmark(tester, root, Offset.zero & kArea);
  });

  testWidgets('and from one that is not — the case a missing origin term passes', (
    WidgetTester tester,
  ) async {
    final RenderRepaintBoundary root = await _mount(tester);
    // Deliberately inside the landmark's own quadrant, so a recorder that
    // ignored `region.topLeft` would still find *something* coloured and only
    // the exact texel disagrees.
    await _checkLandmark(tester, root, const Rect.fromLTWH(24, 16, 140, 150));
  });

  testWidgets('toLogical is the inverse of toTexel', (WidgetTester tester) async {
    final RenderRepaintBoundary root = await _mount(tester);
    final ProxyRecording rec = ProxyRecorder.walk(
      root,
      region: const Rect.fromLTWH(24, 16, 140, 150),
      resolution: const ProxyResolution.quarter(),
      devicePixelRatio: 3,
    );
    for (final Offset p in <Offset>[
      const Offset(24, 16),
      const Offset(80, 90),
      const Offset(163.5, 165.5),
    ]) {
      final Offset back = rec.toLogical(rec.toTexel(p));
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    }
    rec.dispose();
  });

  // -------------------------------------------------------------------------
  // 4. The extra row, reproduced and then removed.
  // -------------------------------------------------------------------------

  testWidgets('snapping removes the row the ceil would have added', (WidgetTester tester) async {
    final RenderRepaintBoundary root = await _mount(tester);
    // `bottom = top + height` loses the height by an ULP at this top, and
    // `toImageSync` ceils. Reproduced first, so the arm fails if the trap ever
    // stops existing rather than quietly asserting nothing.
    const double top = 33.333333333333336;
    const double height = 60;
    const Rect awkward = Rect.fromLTWH(20, top, 80, height);
    expect(
      awkward.height,
      greaterThan(height),
      reason: 'the ULP is gone — this arm no longer tests anything',
    );
    expect((2 * awkward.height).ceil(), (2 * height).ceil() + 1, reason: 'the trap did not reproduce');

    final ProxyRecording rec = ProxyRecorder.walk(
      root,
      region: awkward,
      resolution: const ProxyResolution.full(),
      devicePixelRatio: 2,
    );
    debugPrint(
      'awkward region ${awkward.height} -> snapped ${rec.region.height}, '
      'image ${rec.image.width}x${rec.image.height}',
    );
    expect(rec.region.height, 61, reason: 'snapping is outward to whole logical pixels');
    expect(rec.image.height, 122, reason: 'a fractional top leaked into the texel count');
    expect(rec.image.height, rec.expectedSize.height);
    rec.dispose();
  });

  testWidgets('a region already on whole pixels is left alone', (WidgetTester tester) async {
    final RenderRepaintBoundary root = await _mount(tester);
    const Rect exact = Rect.fromLTWH(20, 30, 80, 60);
    final ProxyRecording rec = ProxyRecorder.walk(
      root,
      region: exact,
      resolution: const ProxyResolution.full(),
      devicePixelRatio: 2,
    );
    expect(rec.region, exact);
    expect(rec.image.width, 160);
    expect(rec.image.height, 120);
    rec.dispose();
  });

  // -------------------------------------------------------------------------
  // 5. The numbers, against the report they came from.
  // -------------------------------------------------------------------------

  test('both damage tables are what the ladder reports on disk say', () {
    for (final (String path, bool corrected) in <(String, bool)>[
      (ProxyResolution.damageSource, false),
      (ProxyResolution.damageSourceCorrected, true),
    ]) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'the report the constants came from is gone: $path');
      final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final view = report['view']! as Map<String, Object?>;
      // The recipe is a field in the report for exactly this: two ladders that
      // differ only in it look identical from their arms.
      expect(
        view['blur_corrected_for_resolution'],
        corrected,
        reason: '$path is the other recipe',
      );
      // And the optics, because the first version of this table quoted a report
      // taken before M13 recalibrated them and was wrong for that reason alone.
      final optics = report['optics']! as Map<String, Object?>;
      expect(optics['shoulder'], isNotNull, reason: '$path predates the M13 optics');

      final arms = (report['arms']! as List<Object?>).cast<Map<String, Object?>>();
      // The four these runs graded; the light branch's rows come from their
      // own run and are checked against it in `proxy_resolution_test.dart`.
      for (final String finish in const <String>['clear', 'thinLight', 'frosted', 'regularDark']) {
        // The ladder called the dark branch `regular` until D230.
        final String ladderName = finish == 'regularDark' ? 'regular' : finish;
        for (final int divisor in ProxyResolution.measuredDivisors) {
          final List<double> mean = <double>[
            for (final Map<String, Object?> arm in arms)
              if (arm['finish'] == ladderName &&
                  arm['axis'] == 'resolution' &&
                  arm['resolution_divisor'] == divisor &&
                  arm['delta_e_mean'] != null)
                arm['delta_e_mean']! as double,
          ];
          expect(mean, hasLength(7), reason: '$finish/$divisor: the report has a different shape');
          final double average = mean.reduce((double a, double b) => a + b) / mean.length;
          final double? quoted = ProxyResolution.divisor(
            divisor,
          ).meanDamage(finish, blurCorrected: corrected);
          expect(quoted, isNotNull, reason: '$finish/$divisor is in the report and not in the table');
          expect(
            quoted!,
            closeTo(average, 0.001),
            reason: '$finish/$divisor ($path): table says $quoted, the report says $average',
          );
        }
      }
    }
  });

  test('the correction is not uniformly an improvement', () {
    // The finding this pair of tables exists to carry: removing the over-blur
    // takes away something that was partly cancelling the lost detail, so the
    // sign of the change depends on the content. `clear` cannot move at all —
    // its sigma is zero, so there is nothing to correct — and that is the
    // control that says the difference is the recipe.
    for (final int divisor in <int>[2, 4, 8]) {
      final r = ProxyResolution.divisor(divisor);
      expect(
        r.meanDamage('clear', blurCorrected: true),
        r.meanDamage('clear'),
        reason: 'a finish with no blur moved under a blur correction',
      );
    }
    expect(
      const ProxyResolution.divisor(8).meanDamage('frosted', blurCorrected: true)!,
      lessThan(const ProxyResolution.divisor(8).meanDamage('frosted')! * 0.9),
      reason: 'the heaviest blur at the deepest divisor gained the most',
    );
    expect(
      const ProxyResolution.divisor(8).meanDamage('regularDark', blurCorrected: true)!,
      greaterThan(const ProxyResolution.divisor(8).meanDamage('regularDark')!),
      reason: 'and one cell went the other way, which is the point',
    );
  });

  test('an unmeasured point refuses instead of interpolating', () {
    // The eighth was graded but never priced: M10 fitted the cost law at 1, 1/2
    // and 1/4. `pow(1/8, 0.9)` would look like an answer.
    expect(const ProxyResolution.divisor(8).captureCostFactor(ProxyCostModel.areaCharged), isNull);
    expect(const ProxyResolution.divisor(3).captureCostFactor(ProxyCostModel.areaCharged), isNull);
    // 5 rather than 3: the ladder ran 3 and 6 in D187, so the divisors it has
    // never run are now the ones that are not 2, 3, 4, 6 or 8.
    expect(const ProxyResolution.divisor(5).meanDamage('regularDark'), isNull);
    expect(const ProxyResolution.quarter().meanDamage('nosuchfinish'), isNull);
    expect(const ProxyResolution.quarter().captureCostFactor(ProxyCostModel.unmeasured), isNull);
  });

  test('on a frame-charged capture the divisor costs a little instead of saving', () {
    // D119, measured on the scale axis on Metal: not "a saving that rounds to
    // one" but a small loss, consistent in sign across four cells, two
    // instruments and two running orders. The quality is spent for less than
    // nothing.
    expect(const ProxyResolution.full().captureCostFactor(ProxyCostModel.frameCharged), 1.00);
    expect(const ProxyResolution.half().captureCostFactor(ProxyCostModel.frameCharged), 1.04);
    expect(const ProxyResolution.quarter().captureCostFactor(ProxyCostModel.frameCharged), 1.06);
    // And the eighth was not run on either platform's scale axis, so it refuses
    // on both models rather than on one.
    expect(const ProxyResolution.divisor(8).captureCostFactor(ProxyCostModel.frameCharged), isNull);
    expect(const ProxyResolution.divisor(8).captureCostFactor(ProxyCostModel.areaCharged), isNull);

    expect(const ProxyResolution.half().captureCostFactor(ProxyCostModel.areaCharged), 0.53);
    expect(const ProxyResolution.quarter().captureCostFactor(ProxyCostModel.areaCharged), 0.27);
    // The two platforms disagree by a factor of four on the same knob, which is
    // the whole reason the model is a parameter rather than a constant.
    expect(
      const ProxyResolution.quarter().captureCostFactor(ProxyCostModel.frameCharged)! /
          const ProxyResolution.quarter().captureCostFactor(ProxyCostModel.areaCharged)!,
      greaterThan(3.5),
    );
  });

  test('the finish decides more than the divisor does', () {
    // The reading that should survive into whatever picks a working point: three
    // steps of divisor on one finish move less than one step of finish does.
    const quarter = ProxyResolution.quarter();
    final double clear = quarter.meanDamage('clear')!;
    final double regular = quarter.meanDamage('regularDark')!;
    final double clearSpread = clear - const ProxyResolution.half().meanDamage('clear')!;
    expect(clear / regular, greaterThan(4.0), reason: 'the finishes have converged: $clear/$regular');
    expect(
      clear - regular,
      greaterThan(clearSpread),
      reason: 'one step of finish is no longer worth more than one step of divisor',
    );
    // And what it is worth against the only external unit this project has.
    expect(regular / ProxyResolution.kMaterialScaleDeltaE, lessThan(0.01));
  });
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

final GlobalKey _boundaryKey = GlobalKey();

Future<RenderRepaintBoundary> _mount(WidgetTester tester) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kArea, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox.fromSize(
              size: kArea,
              child: ColoredBox(
                color: kPage,
                child: Stack(
                  children: <Widget>[
                    Positioned.fromRect(
                      rect: kLandmark,
                      child: const ColoredBox(color: kBox),
                    ),
                    Positioned.fromRect(
                      rect: kSecond,
                      child: const ColoredBox(color: kOther),
                    ),
                    Positioned.fromRect(
                      rect: kMark,
                      child: const ColoredBox(color: kMarkColour),
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
  await tester.pumpAndSettle();
  return _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
}

/// Records [region] at four divisors and checks that the landmark's centre and a
/// point off it land on the colours [ProxyRecording.toTexel] predicts.
Future<void> _checkLandmark(WidgetTester tester, RenderRepaintBoundary root, Rect region) async {
  for (final int divisor in <int>[1, 2, 4, 8]) {
    final ProxyRecording rec = ProxyRecorder.walk(
      root,
      region: region,
      resolution: ProxyResolution.divisor(divisor),
      devicePixelRatio: 3,
    );
    final _Rgb onBox = await _pixelAt(tester, rec, kLandmark.center);
    final _Rgb onMark = await _pixelAt(tester, rec, kMark.center);
    final _Rgb offBox = await _pixelAt(tester, rec, kOnPage);
    final _Rgb second = await _pixelAt(tester, rec, kSecond.center);
    debugPrint('region $region divisor $divisor: box=$onBox mark=$onMark off=$offBox second=$second');
    expect(onBox.distanceTo(_Rgb.of(kBox)), lessThan(2), reason: 'divisor $divisor: landmark moved');
    expect(onMark.distanceTo(_Rgb.of(kMarkColour)), lessThan(2), reason: 'divisor $divisor: mark moved');
    expect(offBox.distanceTo(_Rgb.of(kPage)), lessThan(2), reason: 'divisor $divisor: page moved');
    expect(second.distanceTo(_Rgb.of(kOther)), lessThan(2), reason: 'divisor $divisor: second moved');
    rec.dispose();
  }
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  factory _Rgb.of(Color c) => _Rgb(c.r * 255, c.g * 255, c.b * 255);

  final double r;
  final double g;
  final double b;

  double distanceTo(_Rgb other) => ((r - other.r).abs() + (g - other.g).abs() + (b - other.b).abs()) / 3;

  @override
  String toString() => '(${r.toStringAsFixed(1)}, ${g.toStringAsFixed(1)}, ${b.toStringAsFixed(1)})';
}

Future<_Rgb> _pixelAt(WidgetTester tester, ProxyRecording rec, Offset logical) async {
  final Offset texel = rec.toTexel(logical);
  final int x = texel.dx.floor();
  final int y = texel.dy.floor();
  // Never clamped. A clamp turns "the map sent this off the texture" into "the
  // edge pixel", and the edge of this fixture is page-coloured — which is how
  // the first version of this arm passed with the origin term deleted.
  expect(
    x >= 0 && x < rec.image.width && y >= 0 && y < rec.image.height,
    isTrue,
    reason: 'toTexel($logical) = $texel is outside ${rec.image.width}x${rec.image.height}',
  );
  late _Rgb out;
  await tester.runAsync(() async {
    final ByteData bytes = (await rec.image.toByteData())!;
    final Uint8List px = bytes.buffer.asUint8List();
    final int at = (y * rec.image.width + x) * 4;
    out = _Rgb(px[at].toDouble(), px[at + 1].toDouble(), px[at + 2].toDouble());
  });
  return out;
}

Future<_Rgb> _meanColour(WidgetTester tester, ui.Image image) async {
  late _Rgb out;
  await tester.runAsync(() async {
    final ByteData bytes = (await image.toByteData())!;
    final Uint8List px = bytes.buffer.asUint8List();
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    for (var i = 0; i < px.length; i += 4) {
      r += px[i];
      g += px[i + 1];
      b += px[i + 2];
    }
    final int n = px.length ~/ 4;
    out = _Rgb(r / n, g / n, b / n);
  });
  return out;
}

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.total);

  final int maxDelta;
  final int differing;
  final int total;

  @override
  String toString() => '$differing/$total px, worst $maxDelta';
}

Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  late _Diff diff;
  await tester.runAsync(() async {
    final Uint8List pa = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List pb = (await b.toByteData())!.buffer.asUint8List();
    var maxDelta = 0;
    var differing = 0;
    for (var i = 0; i < pa.length; i += 4) {
      var worst = 0;
      for (var c = 0; c < 4; c++) {
        final int d = (pa[i + c] - pb[i + c]).abs();
        if (d > worst) {
          worst = d;
        }
      }
      if (worst > 0) {
        differing++;
        if (worst > maxDelta) {
          maxDelta = worst;
        }
      }
    }
    diff = _Diff(maxDelta, differing, pa.length ~/ 4);
  });
  return diff;
}
