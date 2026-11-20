// Glass partly past the screen's edge reads the screen clamped to that edge
// (#42).
//
// `flutter test test/glass_offscreen_edge_test.dart`
//
// The known answer is the same disc fully on screen. The backdrop is a
// vertical gradient, the same in every column, so the screen clamped at its
// right edge is the screen itself, continued: a disc half past that edge must
// draw its on-screen half exactly as the same disc fully on screen draws its
// left half, and a disc mostly past it its left fifth. Read for `frosted`
// with its own optics, where the bend reaches across the edge, and with
// `GlassOptics.none`, where only the blur does.
//
// Before the fix the part of a slot past the screen held nothing, and the
// cut disc went dark toward the edge: 83 code values at the edge, over about
// 15 px, with optics and without; after it, 1.
//
// Breaks, each undone by swapping the string back:
//  - `layout.record(scene, screen: sceneBounds ?? _boundsOf(root))` ->
//    `layout.record(scene)` in `GlassProxyPipeline.capture`: both arms fail.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(300, 240);
const double kSize = 96;
const double kTop = 72;
const double kInside = 24;
final GlobalKey _shotKey = GlobalKey();

void main() {
  final Map<String, GlassFinish> finishes = <String, GlassFinish>{
    'frosted': GlassFinish.frosted,
    'frosted without optics': GlassFinish.frosted.copyWith(optics: GlassOptics.none),
  };
  // How much of the disc is left on screen: half of it, and a fifth.
  const List<double> visibles = <double>[kSize / 2, 20];
  for (final MapEntry<String, GlassFinish>(key: String name, value: GlassFinish finish) in finishes.entries) {
    for (final double visible in visibles) {
      testWidgets('$name with ${visible.toInt()} px on screen draws them as the whole disc does (#42)', (
        WidgetTester tester,
      ) async {
        final Uint8List whole = await _shot(tester, finish, left: kInside);
        final Uint8List cut = await _shot(tester, finish, left: kScreen.width - visible);
        final Uint8List bare = await _shot(tester, null, left: 0);

        var worst = 0;
        var glassy = 0;
        for (var y = kTop.toInt(); y < kTop + kSize; y++) {
          for (var dx = 0; dx < visible; dx++) {
            final int a = _at(y, kInside.toInt() + dx);
            final int b = _at(y, (kScreen.width - visible).toInt() + dx);
            var off = 0;
            for (var c = 0; c < 3; c++) {
              final int d = (whole[a + c] - cut[b + c]).abs();
              if (d > worst) {
                worst = d;
              }
              off += (whole[a + c] - bare[a + c]).abs();
            }
            if (off > 6) {
              glassy++;
            }
          }
        }
        // ignore: avoid_print
        print('$name, ${visible.toInt()} px on screen: worst $worst code values, $glassy px of glass read');
        expect(
          glassy,
          greaterThan(visible * kSize / 4),
          reason: 'no glass where the arm reads: it compares backdrop to backdrop',
        );
        expect(worst, lessThanOrEqualTo(2), reason: 'the cut disc is not the whole disc\'s part: the edge reads dark');
      });
    }
  }
}

int _at(int y, int x) => (y * kScreen.width.toInt() + x) * 4;

Future<Uint8List> _shot(WidgetTester tester, GlassFinish? finish, {required double left}) async {
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
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[Color(0xFFB0C4DE), Color(0xFFF5DEB3)],
                          ),
                        ),
                      ),
                    ),
                    if (finish != null)
                      Positioned(
                        top: kTop,
                        left: left,
                        width: kSize,
                        height: kSize,
                        child: GlassSurface(borderRadius: kGlassCapsule, finish: finish, labelled: false),
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
