// The scroll edge effect against Apple's own, read by one instrument.
//
// `flutter test test/glass_scroll_edge_test.dart`
//
// Apple's frames are in `provenance/scroll_edge/` (iOS 26.5, iPhone 17 Pro:
// bars 116 and 86 pt on 874, dpr 3). The instrument reads a frame row by row
// against its known answer — the same screen with the effect hidden — for the
// lines' contrast (the blur) and the flat field's level (the tint), and solves
// the plateau's `mix(x, C, a)` from the two levels it has.
//
// Three arms, in the order that makes each one mean something:
//
//  1. the instrument on Apple's frames returns what the original Swift and
//     Python tools returned — the port is the instrument, not a second one;
//  2. our effect, drawn over the same fixture at the same size and read by
//     the same instrument, lands on Apple's numbers inside a stated
//     tolerance per quantity;
//  3. the hard style the same way.
//
// Breaks, each undone by swapping the string back:
//  - `kGlassScrollEdgeSigma = 1.6` -> `0.0` (no blur): arm 2's top plateau
//    contrast is 0.75 against Apple's 0.12;
//  - `_kTopTintCentre = -10.5` -> `-30.5`: the tint's 50% crossing moves 20 pt;
//  - `if (!top) {` -> `if (false) {` (the bottom falls through to the glass):
//    the bottom acquires a blur Apple's does not have. Read first at the
//    bottom's plateau alone, this broke nothing — the glass the break lays
//    sits above the plateau — so the arm reads the least contrast over the
//    whole ramp instead.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kPhone = Size(402, 874);
const double kScale = 3;
const double kTop = 116;
const double kBottom = 86;
final GlobalKey _shotKey = GlobalKey();

void main() {
  test('the instrument reads Apple\'s frames as the spike\'s tools did', () async {
    final _Fit dark = _fit(await _frame('soft_dark'), await _frame('hidden_dark'));
    final _Fit light = _fit(await _frame('soft_light'), await _frame('hidden_light'));
    // ignore: avoid_print
    print('apple dark  $dark\napple light $light');
    // fit_soft.py, phone: dark top a 0.250 C -1.0 contrast 0.157, tint 50%
    // 105.5, blur 50% 109.9; light top a 0.860 C 254.4; bottom a 0.260 / 0.862.
    expect(dark.top.a, closeTo(0.250, 0.005));
    expect(dark.top.c, closeTo(-1.0, 3));
    expect(dark.top.residual, closeTo(0.157, 0.01));
    expect(dark.top.tint50, closeTo(105.5, 0.6));
    expect(dark.top.blur50, closeTo(109.9, 0.6));
    expect(light.top.a, closeTo(0.860, 0.005));
    expect(light.top.c, closeTo(254.4, 3));
    expect(dark.bottom.a, closeTo(0.260, 0.01));
    expect(light.bottom.a, closeTo(0.862, 0.01));
    expect(dark.bottom.tint50, closeTo(808.5, 1));
  });

  for (final GlassScrollEdgeAppearance appearance in GlassScrollEdgeAppearance.values) {
    testWidgets('our soft edge reads as Apple\'s, ${appearance.name}', (WidgetTester tester) async {
      final String field = appearance == GlassScrollEdgeAppearance.dark ? 'dark' : 'light';
      final _Fit apple = (await tester.runAsync(
        () async => _fit(await _frame('soft_$field'), await _frame('hidden_$field')),
      ))!;
      final _Image known = await _ours(tester, appearance, style: null);
      final _Image effect = await _ours(tester, appearance, style: GlassScrollEdgeStyle.soft);
      final _Fit ours = _fit(effect, known);
      // ignore: avoid_print
      print('ours  ${appearance.name} $ours\napple ${appearance.name} $apple');
      // The plateau: the tint is Apple's constant and the blur its sigma, so
      // these are a check on the drawing, not on a fit.
      expect(ours.top.a, closeTo(apple.top.a, 0.02));
      expect(ours.top.c, closeTo(apple.top.c, 6));
      expect(ours.top.residual, closeTo(apple.top.residual, 0.05));
      // The ramps: the tint is an erf placed on Apple's centre; the blur is a
      // smoothstep through Apple's 10% and 90% points, whose middle sits 5 pt
      // off the measured one (the measured ramp is asymmetric).
      expect(ours.top.tint50, closeTo(apple.top.tint50, 2));
      expect(ours.top.tint10, closeTo(apple.top.tint10, 3));
      expect(ours.top.tint90, closeTo(apple.top.tint90, 3));
      expect(ours.top.blur10, closeTo(apple.top.blur10, 3));
      expect(ours.top.blur90, closeTo(apple.top.blur90, 3));
      expect(ours.top.blur50, closeTo(apple.top.blur50, 6));
      // The bottom: no blur on either, and a tint whose centre is a fraction
      // of the inset fitted across two devices: 0.82 is the mean of this
      // phone's 0.753 and the iPad's 0.883, so on this device it is 5.7 pt
      // off by construction, and the drawing adds up to 1.5.
      expect(apple.bottom.leastContrast, greaterThan(0.85), reason: 'the reading of Apple\'s bottom moved');
      expect(ours.bottom.leastContrast, greaterThan(0.85), reason: 'the bottom blurs, and Apple\'s does not');
      expect(ours.bottom.a, closeTo(apple.bottom.a, 0.04));
      expect(ours.bottom.tint50, closeTo(apple.bottom.tint50, 7.5));
    });
  }

  testWidgets('our hard edge reads as Apple\'s', (WidgetTester tester) async {
    for (final String field in <String>['dark', 'light']) {
      final _Image appleKnown = (await tester.runAsync(() => _frame('hidden_$field')))!;
      final _Image apple = (await tester.runAsync(() => _frame('hard_$field')))!;
      final GlassScrollEdgeAppearance appearance = field == 'dark'
          ? GlassScrollEdgeAppearance.dark
          : GlassScrollEdgeAppearance.light;
      final _Image known = await _ours(tester, appearance, style: null);
      final _Image ours = await _ours(tester, appearance, style: GlassScrollEdgeStyle.hard);
      final ({double edgeTop, double edgeBottom, double level}) a = _band(apple, appleKnown);
      final ({double edgeTop, double edgeBottom, double level}) o = _band(ours, known);
      // ignore: avoid_print
      print('hard $field: apple $a, ours $o');
      expect(o.edgeTop, closeTo(a.edgeTop, 1.5));
      expect(o.edgeBottom, closeTo(a.edgeBottom, 5));
      expect(o.level, closeTo(a.level, 4));
    }
  });
}

/// One frame, RGBA, device pixels.
class _Image {
  _Image(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;

  double grey(int x, int y) {
    final int i = (y * width + x) * 4;
    return (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3;
  }
}

/// Apple's frame [name]. Inside a widget test this must run under
/// `tester.runAsync` — the fake clock never completes an engine future.
Future<_Image> _frame(String name) async {
  final Uint8List bytes = File('provenance/scroll_edge/phone_$name.png').readAsBytesSync();
  late _Image out;
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData())!;
  out = _Image(image.width, image.height, data.buffer.asUint8List());
  image.dispose();
  return out;
}

/// Our screen: Apple's fixture, our effect at both edges (or none, for the
/// known answer), at Apple's size and density.
Future<_Image> _ours(
  WidgetTester tester,
  GlassScrollEdgeAppearance appearance, {
  required GlassScrollEdgeStyle? style,
}) async {
  final bool dark = appearance == GlassScrollEdgeAppearance.dark;
  tester.view
    ..physicalSize = kPhone * kScale
    ..devicePixelRatio = kScale;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kPhone, devicePixelRatio: kScale),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(
          key: UniqueKey(),
          hardware: GlassHardware.appleMetal,
          child: RepaintBoundary(
            key: _shotKey,
            child: SizedBox.fromSize(
              size: kPhone,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _Fixture(dark: dark)),
                    ),
                  ),
                  if (style != null) ...<Widget>[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: GlassScrollEdge(
                        side: GlassScrollEdgeSide.top,
                        extent: kTop,
                        style: style,
                        appearance: appearance,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GlassScrollEdge(
                        side: GlassScrollEdgeSide.bottom,
                        extent: kBottom,
                        style: style,
                        appearance: appearance,
                      ),
                    ),
                  ],
                ],
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
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final ui.Image image = (boundary.layer! as OffsetLayer).toImageSync(
    Offset.zero & kPhone,
    pixelRatio: kScale,
  );
  late _Image out;
  await tester.runAsync(() async {
    final ByteData data = (await image.toByteData())!;
    out = _Image(image.width, image.height, Uint8List.fromList(data.buffer.asUint8List()));
  });
  image.dispose();
  return out;
}

/// `ScrollEdgeReference.Fixture` in `ios/Runner/GlassReference.swift`.
class _Fixture extends CustomPainter {
  _Fixture({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final double half = (size.width / 2).floorToDouble();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, half, size.height),
      Paint()..color = const Color.fromRGBO(244, 241, 234, 1),
    );
    final Paint line = Paint()..color = const Color.fromRGBO(27, 27, 27, 1);
    for (var x = 0.0; x < half; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), line);
    }
    final int level = ((dark ? 0.2 : 0.9) * 255).round();
    canvas.drawRect(
      Rect.fromLTWH(half, 0, size.width - half, size.height),
      Paint()..color = Color.fromARGB(255, level, level, level),
    );
  }

  @override
  bool shouldRepaint(_Fixture oldDelegate) => oldDelegate.dark != dark;
}

/// One row of the reading: the lines' contrast against the known answer's,
/// and the means of the field and of the lines, effect and known.
typedef _Row = ({double y, double contrast, double field, double fieldKnown, double lines, double linesKnown});

List<_Row> _rows(_Image a, _Image b) {
  expect(a.width, b.width);
  expect(a.height, b.height);
  final double half = (a.width / kScale / 2).floorToDouble() * kScale;
  final int lx0 = (30 * kScale).round(), lx1 = (150 * kScale).round();
  final int fx0 = (half + 20 * kScale).round(), fx1 = a.width - (120 * kScale).round();
  final rows = <_Row>[];
  for (var y = 0.0; y * kScale < a.height; y += 1) {
    final int row = (y * kScale).toInt();
    var mnA = 999.0, mxA = -1.0, mnB = 999.0, mxB = -1.0, sA = 0.0, sB = 0.0;
    for (var x = lx0; x < lx1; x++) {
      final double va = a.grey(x, row), vb = b.grey(x, row);
      mnA = math.min(mnA, va);
      mxA = math.max(mxA, va);
      mnB = math.min(mnB, vb);
      mxB = math.max(mxB, vb);
      sA += va;
      sB += vb;
    }
    var fa = 0.0, fb = 0.0;
    for (var x = fx0; x < fx1; x++) {
      fa += a.grey(x, row);
      fb += b.grey(x, row);
    }
    rows.add((
      y: y,
      contrast: (mxA - mnA) / math.max(1, mxB - mnB),
      field: fa / (fx1 - fx0),
      fieldKnown: fb / (fx1 - fx0),
      lines: sA / (lx1 - lx0),
      linesKnown: sB / (lx1 - lx0),
    ));
  }
  return rows;
}

class _Side {
  _Side(
    this.a,
    this.c,
    this.residual,
    this.tint10,
    this.tint50,
    this.tint90,
    this.blur10,
    this.blur50,
    this.blur90,
    this.leastContrast,
  );
  final double a, c, residual;

  /// The lowest tint-corrected contrast anywhere on the ramp: a blur that is
  /// not at the plateau — glass placed off the edge — shows here and nowhere
  /// else (the break that first failed to break, below).
  final double leastContrast;
  final double tint10, tint50, tint90, blur10, blur50, blur90;

  @override
  String toString() =>
      'a ${a.toStringAsFixed(3)} C ${c.toStringAsFixed(1)} residual ${residual.toStringAsFixed(3)} '
      'tint ${tint90.toStringAsFixed(1)}/${tint50.toStringAsFixed(1)}/${tint10.toStringAsFixed(1)} '
      'blur ${blur90.toStringAsFixed(1)}/${blur50.toStringAsFixed(1)}/${blur10.toStringAsFixed(1)} '
      'least ${leastContrast.toStringAsFixed(3)}';
}

class _Fit {
  _Fit(this.top, this.bottom);
  final _Side top;
  final _Side bottom;

  @override
  String toString() => 'top [$top] bottom [$bottom]';
}

/// `fit_soft.py`'s plateau and crossings: the same ranges, the same algebra.
_Fit _fit(_Image effect, _Image known) {
  final List<_Row> rows = _rows(effect, known);
  _Side side((double, double) plateau, (double, double) ramp) {
    final List<_Row> sel = rows.where((r) => r.y >= plateau.$1 && r.y <= plateau.$2).toList();
    double mean(double Function(_Row) f) => sel.map(f).reduce((a, b) => a + b) / sel.length;
    final double contrast = mean((r) => r.contrast);
    final double field = mean((r) => r.field), fieldKnown = mean((r) => r.fieldKnown);
    final double lines = mean((r) => r.lines), linesKnown = mean((r) => r.linesKnown);
    final double a = 1 - (field - lines) / (fieldKnown - linesKnown);
    final double c = (field - fieldKnown * (1 - a)) / a;
    final double residual = contrast / (1 - a);
    final List<_Row> span = rows.where((r) => r.y >= ramp.$1 && r.y <= ramp.$2).toList();
    final mt = <(double, double)>[];
    final mb = <(double, double)>[];
    var least = double.infinity;
    for (final _Row r in span) {
      final double t = ((r.field - r.fieldKnown) / (field - fieldKnown)).clamp(0.0, 1.0);
      final double cc = r.contrast / (1 - a * t);
      least = math.min(least, cc);
      final double b = residual >= 0.95 ? 0 : ((1 - cc) / (1 - residual)).clamp(0.0, 1.0);
      mt.add((r.y, t));
      mb.add((r.y, b));
    }
    double cross(List<(double, double)> ms, double level) {
      for (var i = 0; i + 1 < ms.length; i++) {
        final (double y0, double v0) = ms[i];
        final (double y1, double v1) = ms[i + 1];
        if ((v0 - level) * (v1 - level) <= 0 && v0 != v1) {
          return y0 + (level - v0) / (v1 - v0) * (y1 - y0);
        }
      }
      return double.nan;
    }

    return _Side(
      a,
      c,
      residual,
      cross(mt, 0.1),
      cross(mt, 0.5),
      cross(mt, 0.9),
      cross(mb, 0.1),
      cross(mb, 0.5),
      cross(mb, 0.9),
      least,
    );
  }

  return _Fit(side((45, 58), (55, 160)), side((866, 873), (730, 874)));
}

/// The hard band: where it ends at each edge (the first row whose lines are
/// back to the known answer's contrast, pt) and its level over the field.
({double edgeTop, double edgeBottom, double level}) _band(_Image effect, _Image known) {
  final List<_Row> rows = _rows(effect, known);
  final double edgeTop = rows.firstWhere((r) => r.y > 45 && r.contrast > 0.5).y;
  final double edgeBottom = rows.lastWhere((r) => r.y < 870 && r.contrast > 0.5).y + 1;
  final List<_Row> band = rows.where((r) => r.y >= 70 && r.y <= 95).toList();
  final double level = band.map((r) => r.field).reduce((a, b) => a + b) / band.length;
  return (edgeTop: edgeTop, edgeBottom: edgeBottom, level: level);
}
