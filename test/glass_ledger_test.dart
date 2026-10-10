// What the register adds up to, and against what.
//
// `flutter test test/glass_ledger_test.dart`
//
// Three separate things are checked here and they fail in different ways.
//
//  1. **The shape's own area**, against the engine that draws it. A closed form
//     for "how much glass is that" is the sort of thing that is 5% wrong
//     forever, because nothing ever contradicts it. The engine can be asked —
//     `RSuperellipse.contains` is a native call — so it is, and the constant the
//     package carries is the answer rather than a derivation. The arm that
//     makes it mean something is the negative control: a **circular** corner
//     has an exact answer, `1 - pi/4`, and the measured coefficient has to
//     differ from it by more than the tolerance. Without that, a `contains`
//     secretly answering for a rounded rect would pass.
//  2. **The cost constants**, re-derived from the two device runs they came
//     from. Those reports are 15 MB each and are not in git; their digests,
//     the cells a constant is read from, are tracked under `provenance/`.
//     So the numbers in `lib/` have a source in the
//     repository, which is the rule that already caught one wrong table.
//  3. **The refusals**, which are most of the value. Two platforms were
//     measured, their laws have different *shapes* rather than different
//     constants, and neither range covers the other's. Everything outside both
//     comes back null.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

/// The two seeds of the glass-area grid, distilled.
const List<String> kAreaDigests = <String>[
  'provenance/digest/s25u-area-a.json',
  'provenance/digest/s25u-area-b.json',
];

/// One scenario of that grid, pooled over both seeds.
typedef AreaPoint = ({String scene, double area, int surfaces, double plain, double fake});

double _median(List<double> xs) {
  final List<double> s = List<double>.of(xs)..sort();
  // Upper median, which is what the device's own analysis and `digest.py` take.
  return s[s.length ~/ 2];
}

List<AreaPoint> _readAreaGrid() {
  final values = <String, List<double>>{};
  final meta = <String, ({double area, int surfaces})>{};
  var caveats = 0;
  for (final String path in kAreaDigests) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('the digest a constant came from is gone: $path');
    }
    final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    caveats += (report['caveats']! as List<Object?>).length;
    for (final Object? c in report['cells']! as List<Object?>) {
      final cell = c! as Map<String, Object?>;
      final String scene = cell['scene']! as String;
      values
          .putIfAbsent('$scene/${cell['variant']}', () => <double>[])
          .addAll((cell['values']! as List<Object?>).cast<num>().map((num v) => v.toDouble()));
      meta[scene] = (
        area: ((cell['counters']! as Map<String, Object?>)['surface_area_logical']! as num).toDouble(),
        surfaces: (cell['axes']! as Map<String, Object?>)['shape_count']! as int,
      );
    }
  }
  expect(caveats, 0, reason: 'a caveated run is not a measurement');
  return <AreaPoint>[
    for (final String scene in meta.keys)
      (
        scene: scene,
        area: meta[scene]!.area,
        surfaces: meta[scene]!.surfaces,
        plain: _median(values['$scene/plain']!),
        fake: _median(values['$scene/fake']!),
      ),
  ];
}

/// The area of one corner that the engine's shape does *not* cover, as a
/// fraction of `rx·ry`, by sampling that corner's own box.
///
/// Corner-local rather than whole-shape: the discretization error goes with the
/// boundary's length times the cell size, and sampling a 240x200 box at the same
/// cost puts cells 20x larger against the same curve. Measured, because it
/// matters: the whole-box reading came back 0.2335 where this one says 0.2268,
/// and the difference is three times the effect being looked for.
double _cornerCut(ui.RSuperellipse shape, ui.Rect corner, {int samples = 600}) {
  var inside = 0;
  for (var i = 0; i < samples; i++) {
    for (var j = 0; j < samples; j++) {
      final offset = ui.Offset(
        corner.left + corner.width * (i + 0.5) / samples,
        corner.top + corner.height * (j + 0.5) / samples,
      );
      if (shape.contains(offset)) {
        inside++;
      }
    }
  }
  final double cell = corner.width * corner.height / (samples * samples);
  return (corner.width * corner.height - inside * cell) / (corner.width * corner.height);
}

void main() {
  // -------------------------------------------------------------------------
  // 1. The shape, against the engine.
  // -------------------------------------------------------------------------

  test('the corner coefficient belongs to the corner, and it is not a circle', () {
    const Rect box = Rect.fromLTWH(0, 0, 240, 200);
    const double circular = 1 - math.pi / 4;
    final cases = <String, (RSuperellipse, Rect)>{
      'r = 2': (
        RSuperellipse.fromRectAndRadius(box, const Radius.circular(2)),
        const Rect.fromLTWH(0, 0, 2, 2),
      ),
      'r = 24': (
        RSuperellipse.fromRectAndRadius(box, const Radius.circular(24)),
        const Rect.fromLTWH(0, 0, 24, 24),
      ),
      'r = 48': (
        RSuperellipse.fromRectAndRadius(box, const Radius.circular(48)),
        const Rect.fromLTWH(0, 0, 48, 48),
      ),
      'elliptical 40x16': (
        RSuperellipse.fromRectXY(box, 40, 16),
        const Rect.fromLTWH(0, 0, 40, 16),
      ),
      'one corner of 40': (
        RSuperellipse.fromRectAndCorners(box, topLeft: const Radius.circular(40)),
        const Rect.fromLTWH(0, 0, 40, 40),
      ),
    };
    for (final MapEntry<String, (RSuperellipse, Rect)> e in cases.entries) {
      final double c = _cornerCut(e.value.$1, e.value.$2);
      expect(
        c,
        closeTo(GlassLedger.cornerCutCoefficient, 0.002),
        reason:
            '${e.key}: the engine cuts $c of rx·ry, the package assumes '
            '${GlassLedger.cornerCutCoefficient}',
      );
      // The control. A rounded rectangle's corner has a closed form and it is
      // not this number: if `contains` were answering for one — or if the
      // sampling were too coarse to tell — every line above would still pass.
      expect(
        (c - circular).abs(),
        greaterThan(0.008),
        reason: '${e.key}: the engine\'s superellipse is indistinguishable from a circular corner',
      );
    }
  });

  test('and it stops being a constant where the engine degenerates to a circle', () {
    // The domain of the constant, measured rather than assumed. At exactly half
    // the shorter side the round superellipse *is* a circle and the coefficient
    // is the circular one to three digits; the package keeps one constant and
    // therefore over-cuts a stadium, which is recorded here as the size of the
    // error rather than corrected by a fit over four points.
    const Rect box = Rect.fromLTWH(0, 0, 240, 200);
    final double atHalf = _cornerCut(
      RSuperellipse.fromRectAndRadius(box, const Radius.circular(100)),
      const Rect.fromLTWH(0, 0, 100, 100),
    );
    expect(atHalf, closeTo(1 - math.pi / 4, 0.004));
    final double over = (GlassLedger.cornerCutCoefficient - atHalf) * 4 * 100 * 100;
    expect(
      over / (box.width * box.height),
      lessThan(0.01),
      reason: 'the constant costs a stadium more than a percent of its box',
    );
  });

  test('the closed form is the engine, over a corpus of shapes', () {
    const Rect box = Rect.fromLTWH(0, 0, 240, 200);
    final shapes = <String, RSuperellipse>{
      'uniform 24': RSuperellipse.fromRectAndRadius(box, const Radius.circular(24)),
      'elliptical 40x16': RSuperellipse.fromRectXY(box, 40, 16),
      'two corners': RSuperellipse.fromRectAndCorners(
        box,
        topLeft: const Radius.circular(40),
        bottomRight: const Radius.circular(12),
      ),
      // Radii that overflow their box: the engine scales them and so must the
      // closed form, or an over-radiused panel reports a negative area.
      'over-radiused': RSuperellipse.fromRectAndRadius(box, const Radius.circular(400)),
    };
    for (final MapEntry<String, RSuperellipse> e in shapes.entries) {
      // Per axis, which is what the engine does — `scaleRadii()` is the RRect
      // rule and gives a different shape here (see `shapeAreaOf`).
      final RSuperellipse s = RSuperellipse.fromRectAndCorners(
        box,
        topLeft: Radius.elliptical(
          math.min(e.value.tlRadiusX, box.width / 2),
          math.min(e.value.tlRadiusY, box.height / 2),
        ),
        topRight: Radius.elliptical(
          math.min(e.value.trRadiusX, box.width / 2),
          math.min(e.value.trRadiusY, box.height / 2),
        ),
        bottomRight: Radius.elliptical(
          math.min(e.value.brRadiusX, box.width / 2),
          math.min(e.value.brRadiusY, box.height / 2),
        ),
        bottomLeft: Radius.elliptical(
          math.min(e.value.blRadiusX, box.width / 2),
          math.min(e.value.blRadiusY, box.height / 2),
        ),
      );
      double sampledCut = 0;
      for (final (Rect corner, double rx, double ry) in <(Rect, double, double)>[
        (Rect.fromLTWH(box.left, box.top, s.tlRadiusX, s.tlRadiusY), s.tlRadiusX, s.tlRadiusY),
        (
          Rect.fromLTWH(box.right - s.trRadiusX, box.top, s.trRadiusX, s.trRadiusY),
          s.trRadiusX,
          s.trRadiusY,
        ),
        (
          Rect.fromLTWH(box.right - s.brRadiusX, box.bottom - s.brRadiusY, s.brRadiusX, s.brRadiusY),
          s.brRadiusX,
          s.brRadiusY,
        ),
        (
          Rect.fromLTWH(box.left, box.bottom - s.blRadiusY, s.blRadiusX, s.blRadiusY),
          s.blRadiusX,
          s.blRadiusY,
        ),
      ]) {
        if (rx <= 0 || ry <= 0) {
          continue;
        }
        sampledCut += _cornerCut(e.value, corner, samples: 400) * rx * ry;
      }
      final double sampled = box.width * box.height - sampledCut;
      final double closed = GlassLedger.shapeAreaOf(e.value);
      expect(
        (closed - sampled).abs() / (box.width * box.height),
        lessThan(0.005),
        reason: '${e.key}: closed form $closed against the engine\'s $sampled',
      );
      expect(closed, greaterThan(0));
      expect(closed, lessThanOrEqualTo(box.width * box.height));
    }
  });

  // -------------------------------------------------------------------------
  // 2. The cost constants, from the runs they came from.
  // -------------------------------------------------------------------------

  test('the area law is what the two device runs say', () {
    final List<AreaPoint> grid = _readAreaGrid();
    expect(grid, hasLength(5));

    // The tax is `fake - plain`: a translucent surface against an opaque one of
    // the same shape in the same place. Naming the denominator is the whole
    // point — see the ratio caveat in docs/METHODOLOGY.md — and this one is the floor.
    final List<AreaPoint> fixedCount = grid.where((AreaPoint p) => p.surfaces == 2).toList();
    expect(fixedCount, hasLength(3), reason: 'the area axis is not three points');
    double tax(AreaPoint p) => p.fake - p.plain;

    // Proportional fit through the origin, which is the model the tax claims.
    final double k =
        fixedCount.fold<double>(0, (double a, AreaPoint p) => a + p.area * tax(p)) /
        fixedCount.fold<double>(0, (double a, AreaPoint p) => a + p.area * p.area);
    expect(
      k,
      closeTo(GlassLoad.kTaxPerLogicalPx2, GlassLoad.kTaxPerLogicalPx2 * 0.01),
      reason: 'the constant in the package is not the slope of its own report',
    );

    final double mean = fixedCount.fold<double>(0, (double a, AreaPoint p) => a + tax(p)) / fixedCount.length;
    final double ssr = fixedCount.fold<double>(
      0,
      (double a, AreaPoint p) => a + math.pow(tax(p) - k * p.area, 2),
    );
    final double sst = fixedCount.fold<double>(
      0,
      (double a, AreaPoint p) => a + math.pow(tax(p) - mean, 2),
    );
    expect(1 - ssr / sst, greaterThan(0.998), reason: 'the area axis is not a straight line');

    // And the second term, on the other axis: same area, 2 / 6 / 12 surfaces.
    final List<AreaPoint> fixedArea = grid.where((AreaPoint p) => (p.area - 56160).abs() < 1).toList()
      ..sort((AreaPoint a, AreaPoint b) => a.surfaces.compareTo(b.surfaces));
    expect(fixedArea.map((AreaPoint p) => p.surfaces), <int>[2, 6, 12]);
    final Map<int, double> excess = <int, double>{
      for (final AreaPoint p in fixedArea) p.surfaces: tax(p) - k * p.area,
    };
    expect(
      excess[12]!,
      closeTo(GlassLoad.kFragmentationExcessAt12, GlassLoad.kFragmentationExcessAt12 * 0.02),
    );
    // The quadratic the package extrapolates with, against the two points it
    // was not calibrated on. It is 15% out at n = 6 and 400 cycles out at
    // n = 2 — which is 0.6% of that scenario's whole tax — and that is the
    // accuracy of the second term, stated rather than implied.
    double model(int n) => GlassLoad.kFragmentationExcessAt12 * n * n / 144;
    expect((model(6) - excess[6]!).abs() / excess[6]!, lessThan(0.20));
    expect((model(2) - excess[2]!).abs(), lessThan(0.01 * (fixedArea.first.fake - fixedArea.first.plain)));

    // The headline an app author is given: at equal glass, twelve surfaces cost
    // 1.41x the tax of two.
    expect(tax(fixedArea.last) / tax(fixedArea.first), closeTo(1.41, 0.02));
  });

  test('the digests are the runs they claim to be', () {
    for (final String path in kAreaDigests) {
      final report = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      final environment = report['environment']! as Map<String, Object?>;
      expect(environment['build_mode'], 'profile', reason: '$path is not a measurement');
      expect(environment['os'], 'android');
      expect(
        environment['device_pixel_ratio'],
        3.0,
        reason: 'the law is quoted in logical px², and the report has to say what one is',
      );
      expect((report['config']! as Map<String, Object?>)['measure_ms'], 30000);
      expect(report['metric'], 'gpu_cycles_per_frame');
    }
  });

  // -------------------------------------------------------------------------
  // 3. Reading a screen against them.
  // -------------------------------------------------------------------------

  test('a screen of glass is priced on Adreno and refused everywhere else', () {
    final ledger = GlassLedger()
      ..register(_FixedSurface(const Rect.fromLTWH(0, 0, 200, 100)))
      ..register(_FixedSurface(const Rect.fromLTWH(0, 700, 200, 100)));
    const Size view = Size(400, 800);

    final GlassLoad adreno = ledger.read(
      viewSize: view,
      model: GlassSurfaceCostModel.adrenoCycles,
    );
    expect(adreno.surfaceCount, 2);
    expect(adreno.rectAreaLogical, 40000);
    expect(adreno.screensOfGlass, closeTo(40000 / 320000, 1e-9));
    expect(adreno.areaTaxCycles, closeTo(GlassLoad.kTaxPerLogicalPx2 * 40000, 1e-6));
    expect(adreno.taxCycles, greaterThan(adreno.areaTaxCycles!));
    expect(adreno.verdict, GlassLoadVerdict.withinMeasured);

    for (final GlassSurfaceCostModel model in <GlassSurfaceCostModel>[
      GlassSurfaceCostModel.metalThroughput,
      GlassSurfaceCostModel.unmeasured,
    ]) {
      final GlassLoad other = ledger.read(viewSize: view, model: model);
      expect(other.areaTaxCycles, isNull, reason: '$model priced a cycle it never measured');
      expect(other.fragmentationExcessCycles, isNull);
      expect(other.taxCycles, isNull);
      expect(other.mergingSaves, isNull);
      // And the geometry is the same on every platform: what differs is the
      // price, not the screen.
      expect(other.rectAreaLogical, adreno.rectAreaLogical);
      expect(other.surfaceCount, adreno.surfaceCount);
    }
    expect(
      ledger.read(viewSize: view, model: GlassSurfaceCostModel.unmeasured).verdict,
      GlassLoadVerdict.hardwareUnmeasured,
    );
  });

  test('each platform is read against its own measured range', () {
    GlassLoad at(double screens, GlassSurfaceCostModel model) {
      const Size view = Size(400, 800);
      final ledger = GlassLedger()..register(_FixedSurface(Rect.fromLTWH(0, 0, 400, 800 * screens)));
      return ledger.read(viewSize: view, model: model);
    }

    // Adreno: a law fitted from 0.10 to 0.30 screens and no cliff anywhere,
    // because the grid stopped. Past that the answer is "unknown", which is a
    // different word from "fine".
    expect(at(0.25, GlassSurfaceCostModel.adrenoCycles).verdict, GlassLoadVerdict.withinMeasured);
    expect(
      at(0.40, GlassSurfaceCostModel.adrenoCycles).verdict,
      GlassLoadVerdict.pastMeasuredRange,
    );

    // Metal: no law, but throughput measured out to 25.6 screens with a step of
    // 18x between two of them. So the three answers are the three things that
    // were seen.
    expect(at(10, GlassSurfaceCostModel.metalThroughput).verdict, GlassLoadVerdict.withinMeasured);
    expect(
      at(15, GlassSurfaceCostModel.metalThroughput).verdict,
      GlassLoadVerdict.betweenMeasuredPoints,
    );
    expect(
      at(20, GlassSurfaceCostModel.metalThroughput).verdict,
      GlassLoadVerdict.overMeasuredCliff,
    );
    // The two platforms disagree about the same screen by two whole verdicts,
    // which is the point of carrying two tables: 10 screens of glass is fine on
    // one and off the end of the only fit on the other.
    expect(at(10, GlassSurfaceCostModel.adrenoCycles).verdict, GlassLoadVerdict.pastMeasuredRange);
  });

  test('merging is worth the excess and nothing else', () {
    // The rule the API exists to make sayable: at equal glass area the saving
    // from merging is entirely the fragmentation term, because the area term
    // does not move. So a screen with one big panel has nothing to gain and a
    // screen of chips has everything.
    GlassLoad chips(int n) {
      final ledger = GlassLedger();
      for (var i = 0; i < n; i++) {
        ledger.register(_FixedSurface(Rect.fromLTWH(i * 30.0, 0, 20, 20)));
      }
      return ledger.read(viewSize: const Size(400, 800), model: GlassSurfaceCostModel.adrenoCycles);
    }

    expect(chips(1).mergingSaves, isNull, reason: 'one surface cannot be merged with itself');
    final double? few = chips(2).mergingSaves;
    final double? many = chips(12).mergingSaves;
    expect(few, isNotNull);
    expect(many! > few!, isTrue, reason: 'fragmentation did not get worse with fragmentation');
    // Small chips: the area term is tiny, so almost the whole tax is excess.
    expect(many, greaterThan(0.5));
  });

  // -------------------------------------------------------------------------
  // 4. Who declares the hardware.
  // -------------------------------------------------------------------------

  test('the platform answers for Apple and refuses for everything else', () {
    final TargetPlatform? was = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = was);
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(GlassHardware.detect(), GlassHardware.appleMetal);
    }
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        GlassHardware.detect(),
        GlassHardware.unmeasured,
        reason: '$platform was given somebody else\'s numbers',
      );
    }
  });

  test('one declaration answers both questions, and they do not agree by accident', () {
    expect(GlassHardware.adrenoVulkan.captureCostModel, ProxyCostModel.areaCharged);
    expect(GlassHardware.adrenoVulkan.surfaceCostModel, GlassSurfaceCostModel.adrenoCycles);
    expect(GlassHardware.appleMetal.captureCostModel, ProxyCostModel.frameCharged);
    expect(GlassHardware.appleMetal.surfaceCostModel, GlassSurfaceCostModel.metalThroughput);
    expect(GlassHardware.unmeasured.captureCostModel, ProxyCostModel.unmeasured);
    expect(GlassHardware.unmeasured.surfaceCostModel, GlassSurfaceCostModel.unmeasured);

    // The reason it is one declaration: the same device decides both, and the
    // two questions do not answer each other. On Metal the proxy's resolution
    // is the largest lever the route has while the glass *area* is the
    // thing that will eventually stop it — a host that declared them
    // separately could get half of that.
    //
    // Two derivations that sound right are wrong here: "the chooser returns
    // full resolution on Metal", and "a device nobody priced keeps the whole
    // picture, because a measured quality loss against an unmeasured saving is
    // not a trade" — an unpriced device ran at 37 fps under that. Every
    // family reaches the same divisor at the same budget; what the
    // declaration separates is whether that divisor comes with a price.
    for (final GlassHardware hardware in GlassHardware.values) {
      final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
        finish: 'regularDark',
        finishSigmaLogical: 2.6,
        devicePixelRatio: 2,
        costModel: hardware.captureCostModel,
      );
      expect(
        choice.resolution,
        const ProxyResolution.quarter(),
        reason: '$hardware did not reach the working point the devices measured',
      );
      expect(
        choice.routeCostFactor == null,
        hardware == GlassHardware.unmeasured || hardware == GlassHardware.adrenoVulkan,
        reason: '$hardware: the route is priced on Metal alone',
      );
    }
    // The negative control in the same arm, and it is about the *ledger*
    // now rather than the divisor: the unmeasured family still refuses every
    // price it is asked for. That refusal is the one that survived.
    expect(
      GlassLedger().read(viewSize: const Size(400, 800), model: GlassHardware.unmeasured.surfaceCostModel).verdict,
      GlassLoadVerdict.hardwareUnmeasured,
    );
  });
}

/// A surface that is simply somewhere, for testing the arithmetic without a
/// render tree.
class _FixedSurface implements GlassSurfaceGeometry {
  _FixedSurface(this.rect);

  final Rect rect;

  // Never composited: this surface is arithmetic, not a render object.
  @override
  Layer? get compositedLayer => null;

  @override
  Layer? get drawLayer => null;

  // In the proxy's terms it is a full-rung surface: these arms are about the
  // arithmetic, and the rung has its own file.
  @override
  bool get excludedFromProxy => true;

  @override
  GlassSurfaceRecord? readGeometry() => GlassSurfaceRecord(
    rect: rect,
    shapeArea: GlassLedger.shapeAreaOf(
      RSuperellipse.fromRectAndRadius(rect, const Radius.circular(12)),
    ),
  );
}
