// A byte-identity gate for changes that must not move a pixel: a repacked
// uniform block, a renamed uniform, a reordered writer.
//
// `flutter test test/glass_pixels_identity_test.dart`
//   runs everything that needs no files, on any host:
//   - the scenes render the same bytes twice, and a tint moved by 1e-3
//     changes them;
//   - every name in each of the three shaders resolves to the float its
//     writer fills (`test/pixels/lane_oracle.dart`), and a layout with one
//     vector's lanes swapped is told apart;
//   - the surface and group programs draw every scene to the same bytes as a
//     copy of themselves with each name declared on its own, in the writers'
//     order, compiled in this run — and a copy with `uSlotMax`'s lanes
//     swapped does not.
//   These hold a shader to the writers' order. A writer that moves a value to
//   another index moves it for both copies alike, and only the files below
//   see that.
// `... --dart-define=PIXELS_DIR=<dir> --dart-define=PIXELS_WRITE=true`
//   writes the reference frames, before the change.
// `... --dart-define=PIXELS_DIR=<dir>`
//   compares against them, after it, and asserts how many pixels it compared.
//
// The reference frames are not committed. The scenes are rasterized by Skia
// on the CPU, and the same frames on Linux x64 and macOS arm64 differ in a
// few dozen pixels by one code value — the arithmetic is the same, the
// instructions are not — so the files compare frames from one machine, before
// and after; what runs everywhere compares within a run.
//
// The scenes are in `test/pixels/identity_scenes.dart`: every program the
// package ships, through the widgets that write its uniforms.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'pixels/identity_scenes.dart';
import 'pixels/lane_oracle.dart';

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

  test('every name in the three shaders reads the float its writer fills', () {
    const shaders = 'lib/shaders';
    final List<(String, String, List<Lane>, Set<String>)> programs = <(String, String, List<Lane>, Set<String>)>[
      ('surface', '$shaders/glass_surface.frag', kSurfaceLanes, <String>{}),
      // The ripple's file defines GLASS_RIPPLE itself and includes the surface.
      ('ripple', '$shaders/glass_surface_ripple.frag', kRippleLanes, <String>{}),
      ('group', '$shaders/glass_group.frag', kGroupLanes, <String>{}),
    ];
    for (final (String name, String path, List<Lane> lanes, Set<String> defines) in programs) {
      late int names;
      late int floats;
      final List<String> wrong = laneMismatches(
        path,
        lanes,
        defines: defines,
        compared: (int n, int f) => (names, floats) = (n, f),
      );
      print('$name: $names names over $floats floats, ${wrong.length} misplaced');
      expect(names, lanes.length, reason: name);
      expect(floats, greaterThan(30), reason: '$name: the declarations were not read');
      expect(wrong, isEmpty, reason: name);
    }

    // The known answers, in the same run: a vector read with its lanes
    // swapped, and two scalars of the ripple's tail exchanged.
    final List<String> slotMax = laneMismatches(
      '$shaders/glass_surface.frag',
      withSwizzle(kSurfaceLanes, 'uSlotMax', 'yx'),
    );
    expect(slotMax, hasLength(1), reason: 'a swapped uSlotMax was not told apart: $slotMax');
    final List<Lane> tail = <Lane>[...kRippleLanes];
    final int count = tail.indexWhere((Lane l) => l.name == 'uWaveCount');
    final int light = tail.indexWhere((Lane l) => l.name == 'uRippleLight');
    final Lane was = tail[count];
    tail[count] = tail[light];
    tail[light] = was;
    final List<String> exchanged = laneMismatches('$shaders/glass_surface_ripple.frag', tail);
    expect(exchanged, hasLength(2), reason: 'an exchanged ripple tail was not told apart: $exchanged');
  });

  testWidgets('the packed programs draw what an unpacked copy in the writers\' order draws', (
    WidgetTester tester,
  ) async {
    const shaders = 'lib/shaders';
    late final ui.FragmentProgram surface;
    late final ui.FragmentProgram group;
    late final ui.FragmentProgram surfaceSwapped;
    late final ui.FragmentProgram groupSwapped;
    addTearDown(deleteCompiledPrograms);
    await tester.runAsync(() async {
      Future<ui.FragmentProgram> build(String name, String file, List<Lane> lanes) =>
          compileProgram(name, unpackedReference('$shaders/$file', lanes), includeDir: shaders);
      surface = await build('surface', 'glass_surface.frag', kSurfaceLanes);
      group = await build('group', 'glass_group.frag', kGroupLanes);
      surfaceSwapped = await build(
        'surface_swapped',
        'glass_surface.frag',
        withSwizzle(kSurfaceLanes, 'uSlotMax', 'yx'),
      );
      groupSwapped = await build('group_swapped', 'glass_group.frag', withSwizzle(kGroupLanes, 'uSlotMax', 'yx'));
    });

    final List<(String, Uint8List)> packed = await renderIdentityScenes(tester);
    final List<(String, Uint8List)> unpacked = await renderIdentityScenes(tester, surface: surface, group: group);
    final List<(String, Uint8List)> swapped = await renderIdentityScenes(
      tester,
      surface: surfaceSwapped,
      group: groupSwapped,
    );
    expect(unpacked.length, packed.length);
    var compared = 0;
    for (var i = 0; i < packed.length; i++) {
      final (String name, Uint8List bytes) = packed[i];
      expect(unpacked[i].$1, name);
      final int differing = _differing(bytes, unpacked[i].$2);
      final int moved = _differing(bytes, swapped[i].$2);
      print('$name: ${bytes.length ~/ 4} px compared, $differing differ unpacked, $moved with uSlotMax swapped');
      expect(differing, 0, reason: '$name: the packed program reads a lane its writer did not fill');
      compared += bytes.length ~/ 4;
      // The ripple's frames are drawn by the ripple program, which this arm
      // leaves in place; every other scene must see the swap.
      if (!name.startsWith('ripple')) {
        expect(moved, greaterThan(1000), reason: '$name: a swapped uSlotMax drew the same picture');
      }
    }
    expect(compared, 5 * kIdentityScreen.width * kIdentityScreen.height * kIdentityDpr * kIdentityDpr);
  });

  testWidgets('the frames are the reference frames, byte for byte', (WidgetTester tester) async {
    final List<(String, Uint8List)> frames = await renderIdentityScenes(tester);
    var compared = 0;
    if (_write) {
      Directory(_dir).createSync(recursive: true);
    }
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
