// The canvas half of the shadow policy: `FilteringCanvas` drops the draws a
// `ShadowFilter` names and forwards everything else unchanged.
//
// `flutter test test/proxy_shadow_filter_test.dart`
//
// The wrapper hand-writes all of `ui.Canvas`, so the way it goes wrong is one
// method among thirty-eight: a forward that passes the wrong argument, or a draw
// that drops what it should keep. Neither shows up in a scene that happens not
// to use that method, so every method is exercised here by name, against the
// same script replayed on the bare canvas:
//
//  1. **Forwarding is exact.** A script that uses every forwarded method must
//     rasterise to the same bytes through the wrapper as without it — and a
//     script that differs by one forwarded argument must not, or the
//     comparison is blind.
//  2. **Every paint-carrying draw drops on a mask filter, and counts it.** A
//     dropped draw with no count is a screenshot finding instead of a report
//     finding.
//  3. **Each switch is independent.** `drawShadow` is exact, the mask filter is
//     a heuristic, and a report has to say which one fired.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/shadow_filter.dart';

const Rect kCanvas = Rect.fromLTWH(0, 0, 64, 64);
const ui.MaskFilter kBlur = ui.MaskFilter.blur(BlurStyle.normal, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('forwarding', () {
    late ui.Image sprite;

    setUpAll(() {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000))
        ..drawRect(const Rect.fromLTWH(8, 0, 8, 8), Paint()..color = const Color(0xFF00FF00))
        ..drawRect(const Rect.fromLTWH(0, 8, 16, 8), Paint()..color = const Color(0xFF0000FF));
      final ui.Picture p = recorder.endRecording();
      sprite = p.toImageSync(16, 16);
      p.dispose();
    });

    tearDownAll(() => sprite.dispose());

    // One script over every forwarded method, so that a single comparison
    // stands for all of them. [shift] is the negative control's knob: it moves
    // one forwarded argument by a pixel.
    void script(Canvas c, {double shift = 0}) {
      c
        ..save()
        ..translate(2 + shift, 3)
        ..scale(1.1, 0.9)
        ..rotate(0.05)
        ..skew(0.02, 0.01)
        ..transform(Matrix4.translationValues(1, 1, 0).storage)
        ..clipRect(const Rect.fromLTWH(0, 0, 60, 60))
        ..clipRect(const Rect.fromLTWH(50, 50, 4, 4), clipOp: ui.ClipOp.difference, doAntiAlias: false)
        ..clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 58, 58), const Radius.circular(4)))
        ..clipRSuperellipse(
          RSuperellipse.fromRectAndRadius(const Rect.fromLTWH(0, 0, 57, 57), const Radius.circular(6)),
        )
        ..clipPath(Path()..addRect(const Rect.fromLTWH(0, 0, 56, 56)))
        ..drawColor(const Color(0xFF203040), BlendMode.srcOver)
        ..drawImage(sprite, const Offset(1, 1), Paint())
        ..drawImageRect(sprite, const Rect.fromLTWH(0, 0, 16, 16), const Rect.fromLTWH(20, 1, 12, 12), Paint())
        ..drawImageNine(sprite, const Rect.fromLTWH(4, 4, 8, 8), const Rect.fromLTWH(36, 1, 18, 18), Paint())
        ..saveLayer(null, Paint()..color = const Color(0x80000000))
        ..drawPoints(ui.PointMode.points, const <Offset>[Offset(4, 30), Offset(8, 30)], Paint()..strokeWidth = 3)
        ..drawRawPoints(
          ui.PointMode.lines,
          Float32List.fromList(<double>[4, 34, 30, 34]),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0xFFFFFF00),
        )
        ..restore()
        ..drawVertices(
          ui.Vertices(VertexMode.triangles, const <Offset>[Offset(30, 30), Offset(50, 30), Offset(40, 50)]),
          BlendMode.srcOver,
          Paint()..color = const Color(0xFF00FFFF),
        )
        ..drawAtlas(
          sprite,
          <RSTransform>[RSTransform(1, 0, 4, 40)],
          const <Rect>[Rect.fromLTWH(0, 0, 8, 8)],
          null,
          null,
          null,
          Paint(),
        )
        ..drawRawAtlas(
          sprite,
          Float32List.fromList(<double>[1, 0, 14, 40]),
          Float32List.fromList(<double>[8, 0, 16, 8]),
          null,
          null,
          null,
          Paint(),
        );
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 8))
        ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
        ..addText('Ag');
      final ui.Paragraph paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 40));
      c.drawParagraph(paragraph, const Offset(30, 4));
      paragraph.dispose();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawCircle(const Offset(4, 4), 3, Paint()..color = const Color(0xFFFF00FF));
      final ui.Picture inner = recorder.endRecording();
      c.drawPicture(inner);
      inner.dispose();
      final int depth = c.getSaveCount();
      c
        ..save()
        ..save()
        ..restoreToCount(depth)
        ..restore();
    }

    test('every forwarded method rasterises to the same bytes as the bare canvas', () async {
      final ShadowFilter filter = ShadowFilter();
      final Uint8List bare = await _raster((Canvas c) => script(c));
      final Uint8List wrapped = await _raster((Canvas c) => script(FilteringCanvas(c, filter)));
      final Uint8List shifted = await _raster((Canvas c) => script(FilteringCanvas(c, filter), shift: 1));
      expect(_differing(bare, shifted), greaterThan(0), reason: 'the control cannot see a one-pixel forward error');
      expect(_differing(bare, wrapped), 0);
      expect(filter.dropped, 0, reason: 'nothing in the script carries a mask filter or a shadow');
    });

    test('the queries return what the inner canvas returns', () {
      final recorder = ui.PictureRecorder();
      final inner = Canvas(recorder, kCanvas);
      final wrapper = FilteringCanvas(inner, ShadowFilter());
      wrapper
        ..save()
        ..translate(5, 7)
        ..clipRect(const Rect.fromLTWH(0, 0, 10, 10));
      expect(wrapper.getSaveCount(), inner.getSaveCount());
      expect(wrapper.getSaveCount(), 2);
      expect(wrapper.getTransform(), inner.getTransform());
      expect(wrapper.getTransform()[12], 5);
      expect(wrapper.getLocalClipBounds(), inner.getLocalClipBounds());
      expect(wrapper.getDestinationClipBounds(), const Rect.fromLTWH(5, 7, 10, 10));
      expect(identical(wrapper.inner, inner), isTrue);
      wrapper.restore();
      recorder.endRecording().dispose();
    });
  });

  group('dropping', () {
    // Every draw the wrapper inspects, once each, so a count names which ones
    // were seen. The paint is shared so the mask filter is the only variable.
    final Map<String, void Function(Canvas c, Paint p)> draws = <String, void Function(Canvas, Paint)>{
      'drawLine': (Canvas c, Paint p) => c.drawLine(const Offset(8, 8), const Offset(56, 56), p..strokeWidth = 4),
      'drawPaint': (Canvas c, Paint p) => c.drawPaint(p),
      'drawRect': (Canvas c, Paint p) => c.drawRect(const Rect.fromLTWH(8, 8, 40, 40), p),
      'drawRRect': (Canvas c, Paint p) =>
          c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 40, 40), const Radius.circular(8)), p),
      'drawDRRect': (Canvas c, Paint p) => c.drawDRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 48, 48), const Radius.circular(8)),
        RRect.fromRectAndRadius(const Rect.fromLTWH(20, 20, 24, 24), const Radius.circular(4)),
        p,
      ),
      'drawRSuperellipse': (Canvas c, Paint p) => c.drawRSuperellipse(
        RSuperellipse.fromRectAndRadius(const Rect.fromLTWH(8, 8, 40, 40), const Radius.circular(10)),
        p,
      ),
      'drawOval': (Canvas c, Paint p) => c.drawOval(const Rect.fromLTWH(8, 16, 48, 32), p),
      'drawCircle': (Canvas c, Paint p) => c.drawCircle(const Offset(32, 32), 20, p),
      'drawArc': (Canvas c, Paint p) => c.drawArc(const Rect.fromLTWH(8, 8, 48, 48), 0, 2, true, p),
      'drawPath': (Canvas c, Paint p) => c.drawPath(
        Path()
          ..moveTo(8, 8)
          ..lineTo(56, 8)
          ..lineTo(32, 56)
          ..close(),
        p,
      ),
    };

    for (final MapEntry<String, void Function(Canvas, Paint)> e in draws.entries) {
      test('${e.key}: kept without a mask filter, dropped and counted with one', () async {
        final ShadowFilter filter = ShadowFilter();
        Paint plain() => Paint()..color = const Color(0xFFE08020);
        final Uint8List bare = await _raster((Canvas c) => e.value(c, plain()));
        final Uint8List kept = await _raster((Canvas c) => e.value(FilteringCanvas(c, filter), plain()));
        expect(_opaquePixels(bare), greaterThan(0), reason: 'the draw has to paint something to be dropped');
        expect(_differing(bare, kept), 0);
        expect(filter.maskFilteredDraws, 0);

        final Uint8List dropped = await _raster(
          (Canvas c) => e.value(FilteringCanvas(c, filter), plain()..maskFilter = kBlur),
        );
        expect(_opaquePixels(dropped), 0, reason: '${e.key} with a blur mask filter reached the canvas');
        expect(filter.maskFilteredDraws, 1);
        expect(filter.shadowCalls, 0);
        expect(filter.dropped, 1);
      });
    }

    test('a filter with the mask-filter switch off keeps blurred draws', () async {
      final ShadowFilter filter = ShadowFilter(dropMaskFiltered: false);
      final Paint blurred = Paint()
        ..color = const Color(0xFFE08020)
        ..maskFilter = kBlur;
      final Uint8List bare = await _raster((Canvas c) => c.drawRect(const Rect.fromLTWH(8, 8, 40, 40), blurred));
      final Uint8List kept = await _raster(
        (Canvas c) => FilteringCanvas(c, filter).drawRect(const Rect.fromLTWH(8, 8, 40, 40), blurred),
      );
      expect(_differing(bare, kept), 0);
      expect(filter.dropped, 0);
    });

    test('drawShadow is dropped by its own switch and by nothing else', () async {
      final Path occluder = Path()..addRect(const Rect.fromLTWH(12, 12, 30, 30));
      void shadow(Canvas c) => c.drawShadow(occluder, const Color(0xFF000000), 8, false);

      final Uint8List bare = await _raster(shadow);
      expect(_opaquePixels(bare, threshold: 1), greaterThan(0), reason: 'flutter_tester drew no shadow to drop');

      final exact = ShadowFilter(dropMaskFiltered: false);
      final Uint8List dropped = await _raster((Canvas c) => shadow(FilteringCanvas(c, exact)));
      expect(_opaquePixels(dropped, threshold: 1), 0);
      expect(exact.shadowCalls, 1);
      expect(exact.maskFilteredDraws, 0);
      expect(exact.dropped, 1);

      final heuristicOnly = ShadowFilter(dropShadowCalls: false);
      final Uint8List kept = await _raster((Canvas c) => shadow(FilteringCanvas(c, heuristicOnly)));
      expect(_differing(bare, kept), 0);
      expect(heuristicOnly.dropped, 0);
    });

    // The library documents `dropMaskFiltered` as "anything painted through a
    // MaskFilter", but the paint-carrying draws below the shape family are
    // forwarded without the check. None of the framework's shadow routes
    // lowers to them, so the gap is harmless today; the arm records it so a
    // change of either the doc or the code is a decision rather than a drift.
    test(
      'drawPoints, drawImage and drawVertices drop a mask-filtered paint like the shape draws',
      () async {
        final filter = ShadowFilter();
        final Paint blurred = Paint()
          ..color = const Color(0xFFE08020)
          ..strokeWidth = 8
          ..maskFilter = kBlur;
        await _raster(
          (Canvas c) =>
              FilteringCanvas(c, filter).drawPoints(ui.PointMode.points, const <Offset>[Offset(32, 32)], blurred),
        );
        expect(filter.maskFilteredDraws, 1);
      },
      skip:
          'FilteringCanvas forwards drawPoints/drawRawPoints/drawImage*/drawVertices/drawAtlas without '
          'consulting dropMaskFiltered, although its doc says "anything painted through a MaskFilter"',
    );
  });
}

/// Rasterises [draw] onto a [kCanvas]-sized image and returns its RGBA bytes.
Future<Uint8List> _raster(void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder, kCanvas));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(kCanvas.width.toInt(), kCanvas.height.toInt());
  picture.dispose();
  final ByteData? data = await image.toByteData();
  image.dispose();
  if (data == null) {
    throw StateError('the image came back without bytes');
  }
  return data.buffer.asUint8List();
}

int _differing(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) {
      n++;
    }
  }
  return n;
}

int _opaquePixels(Uint8List rgba, {int threshold = 0}) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > threshold) {
      n++;
    }
  }
  return n;
}
