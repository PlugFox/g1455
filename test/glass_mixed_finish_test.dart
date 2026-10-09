// Two finishes on one screen: each surface blurred by its own.
//
// `flutter test test/glass_mixed_finish_test.dart`
//
// A finish decides two things the *pipeline* does — how much the atlas is
// blurred, and which damage table prices the divisor. If the host's finish
// decided both for every surface, a `GlassSurface(finish: GlassFinish.clear)`
// under a `regular` host would draw σ 2.6 of blur it does not have, and
// nothing would say so: the shader gets the clear tint and optics, and the
// picture looks like glass. The drop a pressed control turns into is clear
// glass on a regular screen, so this is not hypothetical.
//
// The arm that makes the claim is a swap: host `regular` with one surface
// declaring `clear`, against host `clear` with the other declaring `regular`.
// The same two materials in the same two places, so the frames must be equal —
// and with one blur for the whole atlas they differ everywhere under the glass,
// because the host decides whose blur it is.
//
// Each class is blurred over its own slots' box rather than the whole atlas.
// Breaks, undone by swapping the string back: that box shrunk to one texel, on
// either pass, fails the swap (the class's glass reads nothing); shrunk by 8
// texels it does not — the slots' own 2.5 σ of bleed is wider, and that is the
// claim the box rests on: nothing a class samples lies outside it.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 320);
const Rect kLeft = Rect.fromLTWH(40, 100, 150, 100);
const Rect kRight = Rect.fromLTWH(200, 100, 150, 100);
final GlobalKey _shotKey = GlobalKey();

void main() {
  for (final ProxyBlurPass pass in <ProxyBlurPass>[ProxyBlurPass.split, ProxyBlurPass.folded]) {
    testWidgets('each surface is blurred by its own finish (${pass.name})', (
      WidgetTester tester,
    ) async {
      final ({Uint8List pixels, int slots}) a = await _shot(
        tester,
        pass,
        host: GlassFinish.regularDark,
        right: GlassFinish.clear,
      );
      final ({Uint8List pixels, int slots}) b = await _shot(
        tester,
        pass,
        host: GlassFinish.clear,
        left: GlassFinish.regularDark,
      );
      final ({Uint8List pixels, int slots}) allRegular = await _shot(
        tester,
        pass,
        host: GlassFinish.regularDark,
      );
      final ({Uint8List pixels, int slots}) allClear = await _shot(
        tester,
        pass,
        host: GlassFinish.clear,
      );

      // The instrument first: the two finishes really do differ under the glass,
      // or every equality below is two copies of one picture.
      expect(
        _differing(allRegular.pixels, allClear.pixels, kRight),
        greaterThan(1000),
        reason: 'regular and clear drew the same right panel',
      );

      expect(
        _differing(a.pixels, b.pixels, Offset.zero & kScreen),
        0,
        reason: 'which finish is the host\'s changed the picture',
      );
      // Against a host of one finish the atlas is laid out differently — the
      // bleed follows the blurriest finish present, so a slot's origin moves —
      // and a fractional displacement then lands on a different bilinear phase:
      // measured, 9 pixels one code value apart in the clear half. So these two
      // are held to a code value, and the swap above, which shares the layout,
      // to zero.
      expect(
        _worst(a.pixels, allRegular.pixels, kLeft),
        lessThanOrEqualTo(1),
        reason: 'the regular half moved',
      );
      expect(
        _worst(a.pixels, allClear.pixels, kRight),
        lessThanOrEqualTo(1),
        reason: 'the clear half is not clear',
      );

      // And the pair was kept apart rather than merged: with one finish the
      // packer puts these two in one slot, with two it may not.
      expect(
        allRegular.slots,
        1,
        reason: 'the control pair was never merged, so nothing below is about merging',
      );
      expect(a.slots, 2, reason: 'two blurs were merged into one slot');
    });
  }
}

Future<({Uint8List pixels, int slots})> _shot(
  WidgetTester tester,
  ProxyBlurPass pass, {
  required GlassFinish host,
  GlassFinish? left,
  GlassFinish? right,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: GlobalKey(),
            hardware: GlassHardware.appleMetal,
            finish: host,
            resolution: ProxyResolution.divisor(1),
            blurPass: pass,
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
                    ),
                    Positioned.fromRect(
                      rect: kLeft,
                      child: GlassSurface(finish: left),
                    ),
                    Positioned.fromRect(
                      rect: kRight,
                      child: GlassSurface(finish: right),
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
  final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final ui.Image image = (boundary.layer! as OffsetLayer).toImageSync(Offset.zero & kScreen);
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return (pixels: out, slots: handle.frame!.layout.slots.length);
}

int _differing(Uint8List a, Uint8List b, Rect area) {
  expect(a.length, kScreen.width * kScreen.height * 4);
  expect(b.length, a.length);
  var n = 0;
  var compared = 0;
  final int w = kScreen.width.toInt();
  for (var y = area.top.toInt(); y < area.bottom.toInt(); y++) {
    for (var x = area.left.toInt(); x < area.right.toInt(); x++) {
      final int i = (y * w + x) * 4;
      compared++;
      if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
        n++;
      }
    }
  }
  expect(compared, area.width * area.height, reason: 'part of the area was not compared');
  return n;
}

int _worst(Uint8List a, Uint8List b, Rect area) {
  final int w = kScreen.width.toInt();
  var worst = 0;
  for (var y = area.top.toInt(); y < area.bottom.toInt(); y++) {
    for (var x = area.left.toInt(); x < area.right.toInt(); x++) {
      final int i = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        final int d = (a[i + c] - b[i + c]).abs();
        if (d > worst) {
          worst = d;
        }
      }
    }
  }
  return worst;
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 3),
        Paint()..color = Color.fromARGB(255, 30 + (y.toInt() * 5 % 210), 120, 210 - (y.toInt() % 160)),
      );
    }
    for (var x = 0.0; x < size.width; x += 11) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 2, size.height),
        Paint()..color = const Color(0x88FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
