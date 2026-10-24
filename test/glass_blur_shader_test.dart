// The atlas's blur on Impeller: `glass_blur.frag`, two nested layers of
// `ImageFilter.shader`, and the engine's blur where the shader is not used.
//
// `flutter test --enable-impeller test/glass_blur_shader_test.dart`
//
// That it delivers the sigma asked is `proxy_blur_test.dart`'s instrument,
// which blurs through the same `saveBlurLayers`; this file holds what that
// instrument cannot see. It reads a grating across, so a vertical pass that
// read the wrong axis, a y flipped on one backend, an edge darkened by a
// filter that pads its input with transparency, or a layer off the origin
// that samples from the origin would all pass it.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_blur.dart';

/// Whether this run has `ImageFilter.shader`, and so the shader.
final bool _impeller = ui.ImageFilter.isShaderFilterSupported;

void main() {
  group('which blur is drawn', () {
    late ui.FragmentProgram? loaded;
    setUp(() {
      loaded = glassBlurProgram;
      addTearDown(() {
        glassBlurProgram = loaded;
        debugGlassBlurShader = true;
      });
    });

    test('without the program, one layer of the engine\'s blur', () {
      glassBlurProgram = null;
      expect(_layers(2), 1);
    });

    test('on Impeller, two layers up to the ceiling and one past it', () {
      expect(glassBlurProgram, isNotNull, reason: 'flutter_test_config.dart did not load it');
      expect(_layers(0.5), 2);
      expect(_layers(kGlassBlurMaxSigma), 2);
      expect(_layers(kGlassBlurMaxSigma + 0.01), 1, reason: 'past the ceiling the engine downsamples, cheaper');
    }, skip: !_impeller);

    test('debugGlassBlurShader off is the engine\'s blur, as the bench\'s other arm', () {
      debugGlassBlurShader = false;
      expect(_layers(2), 1);
    }, skip: !_impeller);

    test('on Skia there is no program to load', () {
      // `ImageFilter.shader` throws there; the engine's blur is the Gaussian
      // the finishes were calibrated with.
      expect(glassBlurProgram, isNull);
      expect(_layers(2), 1);
    }, skip: _impeller);
  });

  group('the shader', () {
    testWidgets('blurs down as it blurs across', (WidgetTester tester) async {
      // The same grating both ways, the one blurred image transposed onto the
      // other: the vertical pass is the horizontal pass's kernel, on the axis
      // it says, with nothing of the other axis in it.
      final ui.Image across = _grating(down: false);
      final ui.Image down = _grating(down: true);
      final ui.Image a = _blur(across, 2.6);
      final ui.Image d = _blur(down, 2.6);
      final Uint8List pa = await _pixels(tester, a);
      final Uint8List pd = await _pixels(tester, d);
      final Uint8List sa = await _pixels(tester, across);
      var worst = 0;
      var blurred = 0;
      for (var y = 0; y < a.height; y++) {
        for (var x = 0; x < a.width; x++) {
          final int va = pa[(y * a.width + x) * 4];
          final int vd = pd[(x * d.width + y) * 4];
          worst = (va - vd).abs() > worst ? (va - vd).abs() : worst;
          if (va != sa[(y * a.width + x) * 4]) {
            blurred++;
          }
        }
      }
      expect(blurred, greaterThan(a.width * a.height ~/ 2), reason: 'the grating was not blurred');
      expect(worst, lessThanOrEqualTo(1), reason: 'the vertical pass is not the horizontal one turned');
      for (final ui.Image i in <ui.Image>[across, down, a, d]) {
        i.dispose();
      }
    }, skip: !_impeller);

    testWidgets('keeps up as up, on every backend', (WidgetTester tester) async {
      // GLES's textures are upside down to Metal's and Vulkan's, and the shader
      // flips its read there. Light above dark comes back light above dark.
      final ui.Image halves = _halves();
      final ui.Image blurred = _blur(halves, 2);
      final Uint8List px = await _pixels(tester, blurred);
      final List<int> column = <int>[for (var y = 0; y < blurred.height; y++) px[(y * blurred.width + 16) * 4]];
      expect(column.first, greaterThan(250), reason: 'the top is not light: $column');
      expect(column.last, lessThan(5), reason: 'the bottom is not dark: $column');
      // And each pass alone: two passes that both read upside down put the
      // picture back, so only one of them on its own can show a flip.
      for (final (double dx, double dy) in <(double, double)>[(1, 0), (0, 1)]) {
        final ui.Image one = _onePass(halves, dx, dy, 2);
        final Uint8List p = await _pixels(tester, one);
        final List<int> c = <int>[for (var y = 0; y < one.height; y++) p[(y * one.width + 16) * 4]];
        expect(c.first, greaterThan(250), reason: 'pass ($dx, $dy) turned the picture over: $c');
        expect(c.last, lessThan(5), reason: 'pass ($dx, $dy) turned the picture over: $c');
        one.dispose();
      }
      halves.dispose();
      blurred.dispose();
    }, skip: !_impeller);

    testWidgets('clamps to the edge, both passes', (WidgetTester tester) async {
      // A flat field blurred is the same flat field, to its last texel. One
      // `ImageFilter.compose` of the two passes fails this: its outer pass is
      // handed an input padded with transparency, and the border darkens.
      // (The shader's own clamp is for a backend whose sampler does not clamp;
      // `flutter_tester`'s does, so this cannot see it go.)
      final ui.Image flat = _flat(const Color(0xFFFFFFFF));
      final ui.Image blurred = _blur(flat, kGlassBlurMaxSigma);
      final Uint8List px = await _pixels(tester, blurred);
      var darkest = 255;
      for (var i = 0; i < px.length; i += 4) {
        darkest = px[i] < darkest ? px[i] : darkest;
        expect(px[i + 3], 255, reason: 'transparency came in at texel ${i ~/ 4}');
      }
      expect(darkest, 255, reason: 'the edge darkened');
      flat.dispose();
      blurred.dispose();
    }, skip: !_impeller);

    testWidgets('blurs a layer off the origin as it blurs one on it', (WidgetTester tester) async {
      // An atlas's classes are blurred region by region, each its own pair of
      // layers wherever it sits. The shader reads its input in the layer's own
      // texels, so where the layer is changes nothing.
      final ui.Image source = _grating(down: false);
      final ui.Image here = _blur(source, 2.6);
      const offset = Offset(37, 21);
      final recorder = ui.PictureRecorder();
      final Rect region = offset & Size(source.width.toDouble(), source.height.toDouble());
      final canvas = Canvas(recorder);
      canvas.clipRect(region);
      final int layers = saveBlurLayers(canvas, region, 2.6);
      canvas.drawImage(source, offset, Paint());
      for (var i = 0; i < layers; i++) {
        canvas.restore();
      }
      final ui.Picture picture = recorder.endRecording();
      final ui.Image there = picture.toImageSync(source.width + 37, source.height + 21);
      picture.dispose();
      final Uint8List ph = await _pixels(tester, here);
      final Uint8List pt = await _pixels(tester, there);
      var worst = 0;
      for (var y = 0; y < here.height; y++) {
        for (var x = 0; x < here.width; x++) {
          final int d = (ph[(y * here.width + x) * 4] - pt[((y + 21) * there.width + x + 37) * 4]).abs();
          worst = d > worst ? d : worst;
        }
      }
      expect(worst, lessThanOrEqualTo(1), reason: 'the layer off the origin read other texels');
      for (final ui.Image i in <ui.Image>[source, here, there]) {
        i.dispose();
      }
    }, skip: !_impeller);
  });
}

int _layers(double sigma) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final int layers = saveBlurLayers(canvas, const Rect.fromLTWH(0, 0, 8, 8), sigma);
  for (var i = 0; i < layers; i++) {
    canvas.restore();
  }
  recorder.endRecording().dispose();
  return layers;
}

ui.Image _blur(ui.Image source, double sigma) {
  final recorder = ui.PictureRecorder();
  final Rect bounds = Offset.zero & Size(source.width.toDouble(), source.height.toDouble());
  final canvas = Canvas(recorder, bounds);
  final int layers = saveBlurLayers(canvas, bounds, sigma);
  canvas.drawImage(source, Offset.zero, Paint());
  for (var i = 0; i < layers; i++) {
    canvas.restore();
  }
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

/// [source] through one pass of the shader, along ([dx], [dy]).
ui.Image _onePass(ui.Image source, double dx, double dy, double sigma) {
  final recorder = ui.PictureRecorder();
  final Rect bounds = Offset.zero & Size(source.width.toDouble(), source.height.toDouble());
  Canvas(recorder, bounds)
    ..saveLayer(
      bounds,
      Paint()
        ..imageFilter = ui.ImageFilter.shader(
          glassBlurProgram!.fragmentShader()
            ..setFloat(2, dx)
            ..setFloat(3, dy)
            ..setFloat(4, sigma),
        ),
    )
    ..drawImage(source, Offset.zero, Paint())
    ..restore();
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

ui.Image _picture(int width, int height, void Function(Canvas canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}

/// Bars 4 texels wide every 12, across a 96 by 48 picture, or down a 48 by
/// 96 one: the one the other transposed.
ui.Image _grating({required bool down}) {
  const long = 96;
  const short = 48;
  return _picture(down ? short : long, down ? long : short, (Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = const Color(0xFF404040));
    final paint = Paint()..color = const Color(0xFFC0C0C0);
    for (var t = 0; t < long; t += 12) {
      canvas.drawRect(
        down
            ? Rect.fromLTWH(0, t.toDouble(), short.toDouble(), 4)
            : Rect.fromLTWH(t.toDouble(), 0, 4, short.toDouble()),
        paint,
      );
    }
  });
}

ui.Image _halves() => _picture(32, 32, (Canvas canvas) {
  canvas
    ..drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = const Color(0xFF000000))
    ..drawRect(const Rect.fromLTWH(0, 0, 32, 16), Paint()..color = const Color(0xFFFFFFFF));
});

ui.Image _flat(Color color) =>
    _picture(40, 24, (Canvas canvas) => canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 24), Paint()..color = color));

Future<Uint8List> _pixels(WidgetTester tester, ui.Image image) async {
  late Uint8List px;
  await tester.runAsync(() async {
    px = (await image.toByteData())!.buffer.asUint8List();
  });
  return px;
}
