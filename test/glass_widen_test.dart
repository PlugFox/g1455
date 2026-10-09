// `GlassOptics.widen` and `zoom`: the glass shows its box grown by a margin,
// which minifies the backdrop — what iOS's held switch does — or magnified
// about its centre, which is what its tab bar's drop does.
//
// `flutter test test/glass_widen_test.dart`
//
// The backdrop is a ramp, red = x and green = y, one code per logical pixel at
// dpr 1. Bilinear sampling of a linear ramp is exact, so the law is checkable
// to a code at every pixel: under a widened glass the pixel at x shows
// `c + (x - c)(widen / half + 1 / zoom)`.
//
// Breaks, each undone by swapping the string back:
//  - `..setFloat(29, walk.dx)` -> `..setFloat(29, 0.0)` in
//    `RenderGlassSurface._paintOptics`: the widened arm reads the ramp at slope 1;
//  - `finish.optics.reach(record.rect.size / 2)` -> `0.0` in `GlassHost._capture`:
//    the samples past the box clamp to the slot, and the outer band reads flat.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(300, 300);
const Rect kGlass = Rect.fromLTWH(60, 100, 180, 100);
final GlobalKey _shotKey = GlobalKey();

void main() {
  testWidgets('a widened glass shows its box grown by the margin, to a code', (
    WidgetTester tester,
  ) async {
    for (final (double widen, double zoom) in <(double, double)>[
      (0, 1),
      (10, 1),
      (-8, 1),
      (0, 1.17),
      (0, 0.9),
      (5, 1.1),
    ]) {
      final Uint8List px = await _shot(tester, widen, zoom);
      final double kx = 1 + widen / (kGlass.width / 2) + 1 / zoom - 1;
      final double ky = 1 + widen / (kGlass.height / 2) + 1 / zoom - 1;
      var compared = 0;
      var worst = 0.0;
      // Every pixel inside, short of the one-device-pixel coverage edge.
      for (var y = kGlass.top.toInt() + 1; y < kGlass.bottom - 1; y++) {
        for (var x = kGlass.left.toInt() + 1; x < kGlass.right - 1; x++) {
          final double ex = kGlass.center.dx + (x + 0.5 - kGlass.center.dx) * kx - 0.5;
          final double ey = kGlass.center.dy + (y + 0.5 - kGlass.center.dy) * ky - 0.5;
          final int i = (y * kScreen.width.toInt() + x) * 4;
          worst = [worst, (px[i] - ex).abs(), (px[i + 1] - ey).abs()].reduce((a, b) => a > b ? a : b);
          compared++;
        }
      }
      // ignore: avoid_print
      print('widen $widen zoom $zoom: $compared pixels, worst ${worst.toStringAsFixed(2)} codes');
      expect(compared, 178 * 98);
      // Half a code of rounding plus half of 8-bit quantization.
      expect(worst, lessThanOrEqualTo(1.0), reason: 'widen $widen zoom $zoom');
    }
  });

  test('materializing takes the margin and the zoom in; the reach is what samples land past', () {
    final GlassFinish f = GlassFinish.clear.copyWith(
      optics: GlassFinish.clear.optics.copyWith(widen: 5),
    );
    expect(f.materializing(0.5).optics.widen, 2.5);
    final GlassFinish z = GlassFinish.clear.copyWith(
      optics: GlassFinish.clear.optics.copyWith(zoom: 1.2),
    );
    expect(z.materializing(0.5).optics.zoom, closeTo(1.1, 1e-12));
    // What the capture must hold past the box: the margin, and what a
    // minifying zoom reaches along the longer half-extent; magnifying, none.
    expect(const GlassOptics(widen: 5).reach(const Size(90, 50)), 5);
    expect(const GlassOptics(zoom: 0.9).reach(const Size(90, 50)), closeTo(10, 1e-9));
    expect(const GlassOptics(zoom: 1.17, widen: -3).reach(const Size(90, 50)), 0);
    expect(f == GlassFinish.clear, isFalse, reason: 'widen is not in equality');
  });
}

Future<Uint8List> _shot(WidgetTester tester, double widen, double zoom) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: UniqueKey(),
            hardware: GlassHardware.appleMetal,
            finish: GlassFinish.regularDark,
            resolution: ProxyResolution.divisor(1),
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: RepaintBoundary(child: CustomPaint(painter: _Ramp())),
                    ),
                    Positioned.fromRect(
                      rect: kGlass,
                      child: GlassSurface(
                        borderRadius: BorderRadius.zero,
                        finish: GlassFinish.identity.copyWith(
                          optics: GlassOptics.none.copyWith(widen: widen, zoom: zoom),
                        ),
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
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final ui.Image image = (boundary.layer! as OffsetLayer).toImageSync(Offset.zero & kScreen);
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return out;
}

class _Ramp extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Rows of green first, then columns of red added on top: one code per
    // pixel on each axis, and the two channels independent.
    for (var y = 0; y < size.height; y++) {
      canvas.drawRect(
        Rect.fromLTWH(0, y.toDouble(), size.width, 1),
        Paint()..color = Color.fromARGB(255, 0, y, 0),
      );
    }
    for (var x = 0; x < size.width; x++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 1, size.height),
        Paint()
          ..color = Color.fromARGB(255, x, 0, 0)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(_Ramp oldDelegate) => false;
}
