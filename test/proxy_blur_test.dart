// Phase A — is the proxy's resolution independent of the finish's blur?
//
// `flutter test test/glass/proxy_blur_test.dart`
//
// The budget treats them as two line items: capture 40%, blur 17% (D63). But
// recording at 1/k is itself a low-pass — the detail above the texel grid is
// never rasterized, and the magnification back is a reconstruction filter — so
// part of the finish's sigma may already be paid for by the divisor. If that is
// true, two numbers already in use are wrong in opposite directions: the ladder's
// resolution rungs are *pessimistic* (they blur on top of a blur, so they score
// both lost detail and extra blur), and the blur budget at a low divisor is
// *overstated*.
//
// **The instrument is an MTF, not a ΔE.** Matching two blurred pictures by
// distance gives one number with no model in it; a sine grating gives the
// attenuation per spatial frequency, and a Gaussian's is
// `MTF(f) = exp(-2π²σ²f²)`, so every frequency reports its own sigma. Those
// sigmas agreeing across seven periods *is* the check that the filter is
// Gaussian-like; their disagreeing is the finding that it is not.
//
// Three things this arm needs, and each of them is a way it could have lied:
//
//  - **A known answer in the same run.** Our own `ImageFilter.blur` at a stated
//    sigma is read back through the same instrument. Without it a fitted 2.0 is
//    unfalsifiable.
//  - **One period per image.** Seven gratings stacked in bands would have a
//    vertical blur of sigma 8 mixing three of them; a full-frame grating that is
//    constant in y is exactly invariant under the vertical pass.
//  - **A window away from the edges, a whole number of periods wide.** The blur
//    clamps at the border, and a Fourier coefficient over a fractional period
//    leaks.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_recorder.dart';
import 'package:g1455/src/proxy/proxy_resolution.dart';

/// Wide enough that every period below divides it, and that a window can drop
/// 32 px of clamped border from each side and still hold whole periods.
const int kWidth = 384;
const int kHeight = 32;

/// Seven, because a sigma is only believable where the attenuation is neither
/// negligible nor total: each arm uses the periods whose MTF lands inside the
/// readable band and says which those were.
const List<int> kPeriods = <int>[8, 12, 16, 24, 32, 48, 64];

/// `Glass.regular`'s blur, in logical pixels — the calibrated finish, and the
/// one whose sigma is small enough for a divisor to threaten it.
const double kRegularSigma = 2.6;

/// `Glass.frosted`'s, for contrast: a blur no divisor here comes close to.
const double kFrostedSigma = 8.0;

/// Gaussian-equivalent sigma delivered per texel of the recording — read at a
/// device pixel ratio of 1, where a texel is `divisor` logical pixels wide, and
/// checked at 2 by the arm that says the constant belongs to the texel.
///
/// 0.356 / 0.308 / 0.294 for divisors 2 / 4 / 8; the first is the high one
/// because at a divisor of 2 the attenuation is only readable near the texel
/// scale, where the model is at its weakest, so the value taken is the one the
/// two well-sampled divisors agree on.
const double kSigmaPerDivisor = ProxyResolution.sigmaPerTexel;

void main() {
  testWidgets('the instrument returns a sigma it was given', (WidgetTester tester) async {
    // The known answer. `ImageFilter.blur` is a box approximation rather than a
    // true Gaussian, so this also measures how much that costs — and everything
    // below is quoted against this arm rather than against the ideal.
    for (final double sigma in <double>[1.5, 2.6, 4.0, 8.0]) {
      final _Fit fit = await _fit(tester, (ui.Image ref) => _blur(ref, sigma));
      debugPrint('control sigma $sigma -> ${fit.describe()}');
      expect(fit.periods, isNotEmpty, reason: 'nothing was readable at sigma $sigma');
      expect(
        fit.sigma,
        closeTo(sigma, sigma * 0.12),
        reason: 'the instrument does not return a known sigma: $fit',
      );
      // The spread across frequencies is the model check: a filter that is not
      // Gaussian returns a different sigma at every frequency.
      expect(fit.spread / fit.sigma, lessThan(0.25), reason: 'not Gaussian-like: $fit');
    }
  });

  testWidgets('a divisor is a low-pass, and this is how much of one', (WidgetTester tester) async {
    final delivered = <int, double>{};
    for (final int divisor in <int>[2, 4, 8]) {
      final _Fit fit = await _fitDivisor(tester, divisor);
      delivered[divisor] = fit.sigma;
      debugPrint('divisor $divisor delivers ${fit.describe()}');
      expect(fit.periods, isNotEmpty);
      expect(fit.spread / fit.sigma, lessThan(0.1), reason: 'divisor $divisor is not Gaussian-like: $fit');
    }

    // Proportional to the divisor, which is what a filter whose only length is
    // the texel has to be. Checked rather than assumed — and the constant that
    // comes out is the one the last arm reasons with.
    for (final MapEntry<int, double> e in delivered.entries) {
      debugPrint('divisor ${e.key}: ${(e.value / e.key).toStringAsFixed(3)} sigma per unit');
      expect(
        e.value / e.key,
        closeTo(kSigmaPerDivisor, kSigmaPerDivisor * 0.25),
        reason: 'the delivered sigma is not $kSigmaPerDivisor per unit of divisor: $delivered',
      );
    }
  });

  testWidgets('the sigma belongs to the texel, not to the divisor', (WidgetTester tester) async {
    // The constant above was measured at a device pixel ratio of 1, and the
    // quality ladder runs at 2 — so the way it travels is not a detail. If the
    // filter's only length is the texel, then at twice the resolution the same
    // divisor delivers half the sigma in logical pixels.
    for (final int divisor in <int>[4, 8]) {
      final _Fit one = await _fitDivisor(tester, divisor);
      final _Fit two = await _fitDivisor(tester, divisor, dpr: 2);
      debugPrint(
        'divisor $divisor: dpr 1 -> ${one.sigma.toStringAsFixed(3)}, '
        'dpr 2 -> ${two.sigma.toStringAsFixed(3)} '
        '(ratio ${(one.sigma / two.sigma).toStringAsFixed(3)}), '
        'per texel ${(two.sigma * 2 / divisor).toStringAsFixed(3)}',
      );
      expect(two.periods, isNotEmpty);
      expect(
        two.sigma,
        closeTo(one.sigma / 2, one.sigma / 2 * 0.12),
        reason: 'the sigma does not follow the texel: $one against $two',
      );
      // And it is the same constant the package holds, expressed per texel.
      expect(
        two.sigma * 2 / divisor,
        closeTo(ProxyResolution.sigmaPerTexel, ProxyResolution.sigmaPerTexel * 0.2),
      );
    }
  });

  testWidgets('the divisor and the finish compose in quadrature', (WidgetTester tester) async {
    // The consequence. If they do, then blurring a 1/k recording by the finish's
    // whole sigma — which is what the quality rig does — produces
    // sqrt(sigma_k^2 + sigma_f^2), and the residual that reaches the finish
    // exactly is sqrt(sigma_f^2 - sigma_k^2).
    for (final int divisor in <int>[2, 4]) {
      for (final double finish in <double>[kRegularSigma, kFrostedSigma]) {
        final _Fit alone = await _fitDivisor(tester, divisor);
        final _Fit together = await _fitDivisor(tester, divisor, thenBlurLogical: finish);
        final double predicted = math.sqrt(alone.sigma * alone.sigma + finish * finish);
        debugPrint(
          'divisor $divisor + finish $finish: measured ${together.sigma.toStringAsFixed(3)}, '
          'quadrature ${predicted.toStringAsFixed(3)}, '
          'over-blur ${(together.sigma / finish).toStringAsFixed(3)}x',
        );
        expect(
          together.sigma,
          closeTo(predicted, predicted * 0.15),
          reason: 'divisor $divisor + $finish does not compose in quadrature: $together',
        );
      }
    }
  });

  testWidgets('rendering at the corrected residual lands on the finish', (
    WidgetTester tester,
  ) async {
    // The loop closed. Everything above measures; this applies what was measured
    // and reads the answer back through the same instrument.
    for (final int divisor in <int>[2, 4]) {
      final resolution = ProxyResolution.divisor(divisor);
      final double residual = resolution.residualSigmaFor(kRegularSigma, 1)!;
      final _Fit corrected = await _fitDivisor(tester, divisor, thenBlurLogical: residual);
      final _Fit naive = await _fitDivisor(tester, divisor, thenBlurLogical: kRegularSigma);
      debugPrint(
        'divisor $divisor -> regular: asking for ${residual.toStringAsFixed(2)} lands on '
        '${corrected.sigma.toStringAsFixed(3)}, asking for $kRegularSigma lands on '
        '${naive.sigma.toStringAsFixed(3)}',
      );
      expect(
        corrected.sigma,
        closeTo(kRegularSigma, kRegularSigma * 0.08),
        reason: 'the correction did not land on the finish: $corrected',
      );
      // And it is an improvement, not a wash: the uncorrected recipe is further
      // from the finish than the corrected one, at every divisor.
      expect(
        (corrected.sigma - kRegularSigma).abs(),
        lessThan((naive.sigma - kRegularSigma).abs()),
        reason: 'divisor $divisor: the correction did not help',
      );
    }
  });

  test('the ceiling a finish puts on the divisor', () {
    expect(ProxyResolution.maxDivisorFor(kRegularSigma, 1), 8);
    expect(ProxyResolution.maxDivisorFor(kFrostedSigma, 1), 26);
    expect(const ProxyResolution.divisor(16).residualSigmaFor(kRegularSigma, 1), isNull);
    expect(
      const ProxyResolution.quarter().residualSigmaFor(kRegularSigma, 1),
      closeTo(2.306, 0.001),
    );
    // Zero by construction: the measurement's own reference is the full-resolution
    // recording, so its filter is divided out rather than absent.
    expect(const ProxyResolution.full().deliveredSigmaLogical(1), 0.0);
    expect(const ProxyResolution.full().residualSigmaFor(kRegularSigma, 1), kRegularSigma);
    // The ceiling doubles with the device pixel ratio, because the texel halves:
    // on a phone at dpr 2 the divisor a calibrated finish tolerates is 17, not 8.
    expect(ProxyResolution.maxDivisorFor(kRegularSigma, 2), 17);
    expect(const ProxyResolution.quarter().deliveredSigmaLogical(2), closeTo(0.6, 1e-9));
  });

  test('what that means for a working point', () {
    // Arithmetic on what the arms above measured, kept as a checked statement
    // rather than a paragraph.
    for (final int divisor in <int>[2, 4, 8, 16]) {
      final double delivered = kSigmaPerDivisor * divisor;
      final double residual = kRegularSigma * kRegularSigma - delivered * delivered;
      debugPrint(
        'regular (sigma $kRegularSigma) at divisor $divisor: the divisor delivers '
        '${delivered.toStringAsFixed(2)}, so the blur pass should ask for '
        '${residual <= 0 ? "NOTHING — the divisor already exceeds the finish" : math.sqrt(residual).toStringAsFixed(2)} '
        'rather than $kRegularSigma',
      );
    }

    // Two consequences, both against numbers the ladder already quotes.
    //
    // First: a proxy blurred by the finish's whole sigma after a divisor is
    // *over-blurred*, and the resolution rungs of the M11 ladder carry that
    // over-blur inside their damage. At a quarter it is 12%.
    final double atQuarter = math.sqrt(
      math.pow(kSigmaPerDivisor * 4, 2) + kRegularSigma * kRegularSigma,
    );
    expect(atQuarter / kRegularSigma, closeTo(1.10, 0.05));

    // Second: a divisor puts a floor under the finish, and `regular` at an
    // eighth is within 8% of it — so the eighth is the last rung at which the
    // calibrated material is reachable at all, and the sixteenth is not.
    expect(kSigmaPerDivisor * 8, lessThan(kRegularSigma));
    expect(kSigmaPerDivisor * 8 / kRegularSigma, greaterThan(0.9));
    expect(kSigmaPerDivisor * 16, greaterThan(kRegularSigma));
    // Frosted is never threatened: eight times the divisor is still half its
    // sigma. The finish decides how far the resolution can be taken.
    expect(kSigmaPerDivisor * 8, lessThan(kFrostedSigma / 2));
  });
}

// ---------------------------------------------------------------------------
// The instrument.
// ---------------------------------------------------------------------------

/// A fitted sigma and what it was fitted from.
class _Fit {
  const _Fit(this.sigma, this.spread, this.periods, this.perPeriod);

  final double sigma;

  /// Half the spread of the per-frequency sigmas — the model check.
  final double spread;

  final List<int> periods;
  final List<double> perPeriod;

  String describe() =>
      'sigma ${sigma.toStringAsFixed(3)} +- ${spread.toStringAsFixed(3)} from periods $periods '
      '(${perPeriod.map((double s) => s.toStringAsFixed(2)).join(", ")})';

  @override
  String toString() => describe();
}

/// Fits a sigma from the attenuation of [arm] against the unfiltered recording.
Future<_Fit> _fit(WidgetTester tester, ui.Image Function(ui.Image reference) arm) async {
  final sigmas = <double>[];
  final used = <int>[];
  for (final int period in kPeriods) {
    final ProxyRecording reference = await _reference(tester, period);
    final ui.Image filtered = arm(reference.image);
    final double? sigma = await _sigmaFromPair(tester, reference.image, filtered, period);
    reference.dispose();
    filtered.dispose();
    if (sigma != null) {
      sigmas.add(sigma);
      used.add(period);
    }
  }
  return _summarise(sigmas, used);
}

/// The same, for the arm that records at [divisor] and magnifies back — with an
/// optional blur applied *to the small image*, which is what a shipping surface
/// does and what the quality rig does.
Future<_Fit> _fitDivisor(
  WidgetTester tester,
  int divisor, {
  double? thenBlurLogical,
  double dpr = 1,
}) async {
  final sigmas = <double>[];
  final used = <int>[];
  // The filter's only length is the texel, whose size in logical pixels is
  // `divisor / dpr` — so both the domain rule and the answer are stated in
  // texels and converted once, rather than being quietly a dpr-1 statement.
  final double texelLogical = divisor / dpr;
  final int fullWidth = (kWidth * dpr).round();
  final int fullHeight = (kHeight * dpr).round();
  for (final int period in kPeriods) {
    // A Gaussian equivalent is only defined where the real filter looks
    // Gaussian, and this one does not near its own texel: a box's MTF is a
    // sinc, which agrees with `exp(-2pi^2 s^2 f^2)` to second order at low
    // frequency and then goes its own way. Measured, at divisor 8 and dpr 1:
    // periods 32, 48 and 64 return 2.37 / 2.36 / 2.35, and periods 12 and 24
    // return 4.34 and 3.76. Four texels per period is where the two curves are
    // still the same curve.
    if (period < 4 * texelLogical) {
      continue;
    }
    final RenderRepaintBoundary root = await _mount(tester, period);
    final ProxyRecording full = ProxyRecorder.walk(
      root,
      region: const Rect.fromLTWH(0, 0, kWidth * 1.0, kHeight * 1.0),
      resolution: const ProxyResolution.full(),
      devicePixelRatio: dpr,
    );
    final ProxyRecording small = ProxyRecorder.walk(
      root,
      region: const Rect.fromLTWH(0, 0, kWidth * 1.0, kHeight * 1.0),
      resolution: ProxyResolution.divisor(divisor),
      devicePixelRatio: dpr,
    );
    ui.Image reduced = small.image;
    ui.Image? blurred;
    if (thenBlurLogical != null) {
      // Sigma travels in logical pixels and is converted at the texel scale, so
      // every divisor asks for the same amount of blur rather than the same
      // number of texels — exactly what `playground/quality.dart` does.
      blurred = _blur(reduced, thenBlurLogical * small.scale);
      reduced = blurred;
    }
    final ui.Image magnified = _magnify(reduced, fullWidth, fullHeight);
    // Both images live on the reference's grid, so the period and the margin
    // are in its pixels and the sigma comes back in them too.
    final double? sigma = await _sigmaFromPair(
      tester,
      full.image,
      magnified,
      (period * dpr).round(),
      margin: (32 * dpr).round(),
    );
    magnified.dispose();
    blurred?.dispose();
    full.dispose();
    small.dispose();
    if (sigma != null) {
      sigmas.add(sigma / dpr);
      used.add(period);
    }
  }
  return _summarise(sigmas, used);
}

_Fit _summarise(List<double> sigmas, List<int> periods) {
  if (sigmas.isEmpty) {
    return const _Fit(double.nan, double.nan, <int>[], <double>[]);
  }
  final sorted = List<double>.of(sigmas)..sort();
  final double median = sorted[sorted.length ~/ 2];
  final double spread = (sorted.last - sorted.first) / 2;
  return _Fit(median, spread, periods, sigmas);
}

/// `MTF(f) = exp(-2π²σ²f²)`, inverted. Null when the attenuation is outside the
/// band where a log of it means anything.
Future<double?> _sigmaFromPair(
  WidgetTester tester,
  ui.Image reference,
  ui.Image arm,
  int period, {
  int margin = 32,
}) async {
  final double a0 = await _amplitude(tester, reference, period, margin);
  final double a1 = await _amplitude(tester, arm, period, margin);
  if (a0 <= 0) {
    return null;
  }
  final double mtf = a1 / a0;
  // Below 0.02 the coefficient is ringing and quantisation; above 0.98 the log
  // is a difference of two numbers that agree.
  if (mtf <= 0.02 || mtf >= 0.98) {
    return null;
  }
  final double f = 1 / period;
  return math.sqrt(-math.log(mtf) / (2 * math.pi * math.pi * f * f));
}

/// The single-frequency Fourier coefficient of the grating, over a centred
/// window that holds a whole number of periods and excludes the clamped border.
Future<double> _amplitude(WidgetTester tester, ui.Image image, int period, int margin) async {
  final int available = image.width - 2 * margin;
  final int span = (available ~/ period) * period;
  final int start = (image.width - span) ~/ 2;

  late double amplitude;
  await tester.runAsync(() async {
    final Uint8List px = (await image.toByteData())!.buffer.asUint8List();
    final double f = 1 / period;
    var total = 0.0;
    for (var y = 0; y < image.height; y++) {
      var re = 0.0;
      var im = 0.0;
      for (var i = 0; i < span; i++) {
        final int x = start + i;
        final double v = px[(y * image.width + x) * 4].toDouble();
        final double phase = 2 * math.pi * f * x;
        re += v * math.cos(phase);
        im += v * math.sin(phase);
      }
      total += 2 * math.sqrt(re * re + im * im) / span;
    }
    amplitude = total / image.height;
  });
  return amplitude;
}

// ---------------------------------------------------------------------------
// Sources and image operations.
// ---------------------------------------------------------------------------

final GlobalKey _boundaryKey = GlobalKey();

Future<RenderRepaintBoundary> _mount(WidgetTester tester, int period) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(kWidth * 1.0, kHeight * 1.0), devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: kWidth * 1.0,
              height: kHeight * 1.0,
              child: CustomPaint(painter: _Grating(period)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
}

Future<ProxyRecording> _reference(WidgetTester tester, int period) async {
  final RenderRepaintBoundary root = await _mount(tester, period);
  return ProxyRecorder.walk(
    root,
    region: const Rect.fromLTWH(0, 0, kWidth * 1.0, kHeight * 1.0),
    resolution: const ProxyResolution.full(),
    devicePixelRatio: 1,
  );
}

/// A vertical square-wave grating: bars over a background, 50% duty cycle.
///
/// Vector content rather than a decoded image, because that is what a proxy
/// records — at a divisor the rasterizer computes each bar's coverage of a
/// texel, which is the filter under test, and edges are what carries high
/// frequency in a real interface anyway.
///
/// **Bars rather than adjacent columns of a sine, and that is not cosmetic.**
/// The first version of this painter drew one rect per logical pixel with the
/// sine's value in it, and two antialiased rects sharing an edge do not compose:
/// each blends `srcOver` at its own coverage, so at a divisor the background
/// shows through every seam. Measured: it attenuated a period-64 grating to
/// 0.746 where the filter's own answer is 0.995, and the error grew with the
/// divisor — an artefact indistinguishable from the effect being measured. With
/// a 50% duty cycle no two drawn shapes touch, every bar blends against a
/// background that is already there, and the coverage is the area.
class _Grating extends CustomPainter {
  const _Grating(this.period);

  final int period;

  /// The fundamental's amplitude is `4/pi` of the bar's half-swing, but only the
  /// *ratio* at that frequency is read, so the constant cancels. The harmonics
  /// sit at 3f, 5f… and do not reach the coefficient at f.
  static const int background = 64;
  static const int bar = 192;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color.fromARGB(255, background, background, background),
    );
    final paint = Paint()..color = const Color.fromARGB(255, bar, bar, bar);
    final double half = period / 2;
    for (double x = 0; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, half, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Grating oldDelegate) => oldDelegate.period != period;
}

ui.Image _blur(ui.Image source, double sigmaTexels) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(
    source,
    Offset.zero,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigmaTexels,
        sigmaY: sigmaTexels,
        // Clamp, not the default decal: a decal darkens the border, and the
        // border of a proxy is the edge of the screen.
        tileMode: TileMode.clamp,
      ),
  );
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

ui.Image _magnify(ui.Image source, int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    // Explicit: `Paint.filterQuality` defaults to `none`, which is nearest —
    // the same defect that killed the precedents' path (D1) — and a nearest
    // magnification is not the reconstruction a sampler performs.
    Paint()..filterQuality = FilterQuality.low,
  );
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}
