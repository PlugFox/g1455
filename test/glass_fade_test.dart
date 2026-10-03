// A glass that fades across itself (GlassFade), on the full rung and the
// cheap one.
//
// `flutter test test/glass_fade_test.dart`
//
// The known answer is the two frames either side of it: B, the screen with no
// glass, and G, the same glass unfaded. Faded, every pixel must be
// `B + (G - B) * (1 - smoothstep(t))`, t its place between `begin` and `end` —
// so the arm checks the law at every pixel, not a picture against itself.
// Read only where |G - B| is large, so that a code value of rounding is a
// small fraction of what is being divided.
//
// Breaks, each undone by swapping the string back:
//  - `..setFloat(33, fade.$3)` -> `..setFloat(33, 0)` in `_paintOptics`: the
//    fade's origin is lost and the law fails by most of the ramp;
//  - `1.0 - fade * fade * (3.0 - 2.0 * fade)` -> `1.0` in the shader: the
//    full rung draws G;
//  - `_faded(Paint()..color = fill, fadeMask, fill)` -> `Paint()..color =
//    fill`: the cheap rung draws G.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(300, 240);
final GlobalKey _shotKey = GlobalKey();

const GlassFinish _tinted = GlassFinish(
  name: 'identity',
  blurSigmaLogical: 0,
  tint: Color.fromRGBO(255, 40, 0, 0.6),
  rim: Color.fromRGBO(0, 0, 0, 0),
  optics: GlassOptics.none,
);

// The panel, and a fade over its middle: whole above y = 40 in the panel,
// gone below 140.
const Rect _panel = Rect.fromLTWH(30, 40, 240, 180);
final GlassFade _fade = GlassFade.vertical(from: 40, extent: 100);

void main() {
  for (final GlassTier tier in <GlassTier>[GlassTier.full, GlassTier.cheap]) {
    testWidgets('a faded ${tier.name} glass is B + (G - B)(1 - smoothstep)', (
      WidgetTester tester,
    ) async {
      final Uint8List b = await _shot(tester, tier, glass: false);
      final Uint8List g = await _shot(tester, tier, glass: true);
      final Uint8List f = await _shot(tester, tier, glass: true, fade: _fade);
      var compared = 0;
      var worst = 0.0;
      var inRamp = 0;
      for (var y = 0; y < kScreen.height; y++) {
        // Panel-local, at the pixel's centre.
        final double t = ((y + 0.5 - _panel.top - _fade.begin.dy) / (_fade.end.dy - _fade.begin.dy)).clamp(0.0, 1.0);
        final double keep = 1 - t * t * (3 - 2 * t);
        for (var x = 0; x < kScreen.width; x++) {
          // Inside the panel by two pixels: the edge's coverage is its own law.
          if (x < _panel.left + 2 || x >= _panel.right - 2 || y < _panel.top + 2 || y >= _panel.bottom - 2) {
            continue;
          }
          final int i = (y * kScreen.width.toInt() + x) * 4;
          for (var c = 0; c < 3; c++) {
            final int span = g[i + c] - b[i + c];
            if (span.abs() < 60) {
              continue;
            }
            final double want = b[i + c] + span * keep;
            final double err = (f[i + c] - want).abs();
            compared++;
            if (keep > 0.05 && keep < 0.95) {
              inRamp++;
            }
            if (err > worst) {
              worst = err;
            }
          }
        }
      }
      // ignore: avoid_print
      print('${tier.name}: compared $compared ($inRamp in the ramp), worst ${worst.toStringAsFixed(2)} code values');
      expect(compared, greaterThan(20000));
      expect(inRamp, greaterThan(5000), reason: 'the ramp was not where the arm reads');
      // A code value of rounding on the shader; the cheap rung's gradient is
      // eight linear pieces of the smoothstep, which is 0.6% of the span.
      expect(worst, lessThan(tier == GlassTier.full ? 1.5 : 3.0));
    });
  }
}

Future<Uint8List> _shot(
  WidgetTester tester,
  GlassTier tier, {
  required bool glass,
  GlassFade? fade,
}) async {
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
            finish: GlassFinish.identity,
            tier: GlassTierChoice(tier, GlassTierReason.pinnedByHost),
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: RepaintBoundary(child: CustomPaint(painter: _Stripes())),
                    ),
                    if (glass)
                      Positioned.fromRect(
                        rect: _panel,
                        child: GlassSurface(
                          finish: _tinted,
                          borderRadius: BorderRadius.zero,
                          fade: fade,
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

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF103050));
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 5, size.height), Paint()..color = const Color(0xFF20E0A0));
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
