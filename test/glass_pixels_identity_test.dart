// A byte-identity gate for changes that must not move a pixel: a repacked
// uniform block, a renamed uniform, a reordered writer.
//
// `flutter test test/glass_pixels_identity_test.dart`
//   runs the controls only: the scenes render the same bytes twice, and a tint
//   moved by 1e-3 changes them.
// `... --dart-define=PIXELS_DIR=<dir> --dart-define=PIXELS_WRITE=1`
//   writes the reference frames, before the change.
// `... --dart-define=PIXELS_DIR=<dir>`
//   compares against them, after it, and asserts how many pixels it compared.
//
// The scenes are in `test/pixels/identity_scenes.dart`: every program the
// package ships, through the widgets that write its uniforms.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'pixels/identity_scenes.dart';

// ignore_for_file: avoid_print

const String _dir = String.fromEnvironment('PIXELS_DIR');
const bool _write = bool.fromEnvironment('PIXELS_WRITE');

void main() {
  testWidgets('the scenes are deterministic, and a 1e-3 tint is visible to them', (WidgetTester tester) async {
    final List<(String, Uint8List)> a = await renderIdentityScenes(tester);
    final List<(String, Uint8List)> b = await renderIdentityScenes(tester);
    final List<(String, Uint8List)> moved = await renderIdentityScenes(tester, perturb: true);
    expect(a.length, 5);
    for (var i = 0; i < a.length; i++) {
      final (String name, Uint8List bytes) = a[i];
      print('$name: ${fnv64(bytes)}, ${litPixels(bytes)} lit px');
      expect(litPixels(bytes), greaterThan(100000), reason: '$name drew nothing');
      expect(_differing(bytes, b[i].$2), 0, reason: '$name is not deterministic');
    }
    // Only the first scene carries the perturbed surface.
    final int differing = _differing(a[0].$2, moved[0].$2);
    print('a 1e-3 tint: $differing px differ');
    expect(differing, greaterThan(1000));
  });

  testWidgets('the frames are the reference frames, byte for byte', (WidgetTester tester) async {
    final List<(String, Uint8List)> frames = await renderIdentityScenes(tester);
    var compared = 0;
    for (final (String name, Uint8List bytes) in frames) {
      final file = File('$_dir/$name.rgba');
      if (_write) {
        file.writeAsBytesSync(bytes);
        print('wrote $name: ${fnv64(bytes)}');
        continue;
      }
      final Uint8List reference = file.readAsBytesSync();
      expect(bytes.length, reference.length, reason: name);
      final int differing = _differing(bytes, reference);
      print('$name: ${bytes.length ~/ 4} px compared, $differing differ (${fnv64(bytes)})');
      expect(differing, 0, reason: name);
      compared += bytes.length ~/ 4;
    }
    if (!_write) {
      expect(compared, 5 * kIdentityScreen.width * kIdentityScreen.height * kIdentityDpr * kIdentityDpr);
    }
  }, skip: _dir.isEmpty);
}

int _differing(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) {
      n++;
    }
  }
  return n;
}
