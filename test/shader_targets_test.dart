// Supporting Skia costs nothing at runtime and everything at authoring time —
// and this is the half of that cost which can be enforced.
//
// Every shader this package registers is compiled for five targets, and the
// SkSL one is the odd one out: it refuses `textureLod` and every screen-space
// derivative, and it refuses them **after** the build has
// decided whether to care. On Android and macOS the tool retries without
// `--sksl`, prints a warning nobody reads and ships an asset with no SkSL
// stage; the application finds out at the user's first `FragmentProgram.
// fromAsset`. For web the target list is `['--sksl']` alone and the
// retry has nowhere to fall back to, so the build dies instead
// (`shader_compiler.dart:205-206`, `:270-292`). Either way the author who broke
// it sees green.
//
// So the gate is here rather than in prose: the same five targets the SDK
// builds, over the list the bundle actually carries, with impellerc's own
// verdict. The escape from a refusal is compile-time — `#ifdef
// SKIA_GRAPHICS_BACKEND` for the fallback, `IMPELLER_GRAPHICS_BACKEND` for the
// real technique — so a refusal here is a shader to guard, not a
// platform to drop.
//
// **The known answer is in the same arm**, because "everything compiled" is
// what a gate that compiles nothing also reports: an unguarded `dFdx` must fail
// SkSL and pass the other four, in this run, on this engine. And the runtime
// half is not a second opinion on the first — `flutter test` builds the bundle
// for `TargetPlatform.tester` (`--sksl --runtime-stage-vulkan`) and runs it on
// **Skia**, so loading every one of those assets here is the user-visible form
// of the same question, taken on the backend that asks it.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: avoid_print

/// `flutter test` runs on `flutter_tester`, which sits beside `impellerc`.
final Directory kEngine = File(Platform.resolvedExecutable).parent;

const String kSkSL = '--sksl';

/// The five targets the SDK's own shader compiler can ask for, as one list.
///
/// Named here rather than derived per platform because the union is the
/// question: iOS asks for metal alone, web for SkSL alone, Android for SkSL and
/// three runtime stages, the tester for SkSL and vulkan
/// (`shader_compiler.dart:180-206`). A shader that builds for all five builds
/// for every platform Flutter has.
const List<String> kTargets = <String>[
  kSkSL,
  '--runtime-stage-vulkan',
  '--runtime-stage-gles',
  '--runtime-stage-gles3',
  '--runtime-stage-metal',
];

/// The key prefix the pubspec declares its shaders under, which the tool
/// resolves to `lib/`.
const String kPrefix = 'packages/g1455/';

/// The surface's shader — as an asset key and as a file.
const ({String asset, String file}) kPackageShader = (
  asset: 'packages/g1455/shaders/glass_surface.frag',
  file: 'lib/shaders/glass_surface.frag',
);

/// Whether `impellerc` accepted the source, and what it said.
///
/// **Both signals, and that is not belt-and-braces.** `impellerc` fails two
/// ways: SkSL rejecting a derivative prints `Compilation failed` and can exit
/// **0**, while SkSL rejecting an explicit level of detail prints `There was a
/// compiler error: …` and exits **1** with no `Compilation failed` in it. Read
/// by exit code alone the first refusal passes; read by text alone the second
/// does.
({bool ok, String message}) _compile(
  String input,
  List<String> targets, {
  required String out,
}) {
  final ProcessResult r = Process.runSync('${kEngine.path}/impellerc', <String>[
    ...targets,
    '--iplr',
    '--sl=$out',
    '--spirv=$out.spirv',
    '--input=$input',
    '--input-type=frag',
    '--include=${input.substring(0, input.lastIndexOf('/'))}',
    '--include=${kEngine.path}/shader_lib',
  ]);
  final String text = '${r.stdout}${r.stderr}'.trim();
  final bool failed = r.exitCode != 0 || text.contains('Compilation failed');
  return (
    ok: !failed,
    message: text
        .split('\n')
        .map((String l) => l.trim())
        .firstWhere(
          (String l) => l.startsWith('error:') || l.startsWith('There was a compiler error'),
          orElse: () => text.isEmpty ? '(no output)' : text.split('\n').first,
        ),
  );
}

/// The `shaders:` list out of `pubspec.yaml`, which is what reaches a bundle:
/// each entry as the key it loads by and the file it compiles from.
///
/// Parsed rather than restated, because a hand-kept copy of this list would go
/// stale in the direction that matters: the shader somebody adds is the shader
/// nobody thought to add here.
List<({String asset, String file})> _registered() => <({String asset, String file})>[
  for (final String s in _shadersIn('pubspec.yaml'))
    if (s.startsWith(kPrefix))
      (asset: s, file: 'lib/${s.substring(kPrefix.length)}')
    else
      throw StateError('$s is not declared through $kPrefix, so its key differs by host'),
];

List<String> _shadersIn(String pubspec) {
  final List<String> lines = File(pubspec).readAsLinesSync();
  final int start = lines.indexWhere((String l) => l.trimRight() == '  shaders:');
  expect(start, isNot(-1), reason: '$pubspec has no `shaders:` block any more');
  final entry = RegExp(r'^\s+-\s+(\S+\.frag)\s*$');
  final comment = RegExp(r'^\s*#');
  final List<String> found = <String>[];
  for (final String line in lines.skip(start + 1)) {
    final RegExpMatch? m = entry.firstMatch(line);
    if (m != null) {
      found.add(m.group(1)!);
    } else if (line.trim().isNotEmpty && !comment.hasMatch(line)) {
      break;
    }
  }
  return found;
}

/// `return` statements inside `main()` of [source], comments stripped.
///
/// The rule is impellerc's own since #191969 (in 3.49 and master, not in
/// 3.47): a fragment shader that samples a texture and returns early from
/// `main()` can crash ANGLE's d3dcompiler on Windows (#190809, open), and
/// Windows is an Impeller target since 3.47. Checked here by text so that it
/// holds on the stable compiler too, which does not warn yet.
int _returnsInMain(String source) {
  final String code = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//[^\n]*'), '');
  final RegExpMatch? head = RegExp(r'void\s+main\s*\(\s*\)\s*\{').firstMatch(code);
  if (head == null) {
    throw StateError('no main() found');
  }
  var depth = 1;
  var i = head.end;
  while (depth > 0 && i < code.length) {
    if (code[i] == '{') depth++;
    if (code[i] == '}') depth--;
    i++;
  }
  return RegExp(r'\breturn\b').allMatches(code.substring(head.end, i)).length;
}

bool _samples(String source) => source.contains('sampler2D');

void main() {
  late Directory tmp;
  late List<({String asset, String file})> shaders;

  setUpAll(() {
    if (!File('${kEngine.path}/impellerc').existsSync()) {
      fail('no impellerc beside ${kEngine.path}; this check needs the engine artifacts');
    }
    tmp = Directory.systemTemp.createTempSync('shader_targets_');
    shaders = _registered();
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('the bundle list parses, and nothing the package ships is missing from it', () {
    // The denominator. A parse that silently returned one entry would pass
    // every arm below, and the cross-check is independent of the parse: the
    // file mentions `.frag` exactly as often as the list claims to carry it.
    final int mentions = '.frag'.allMatches(File('pubspec.yaml').readAsStringSync()).length;
    print('pubspec.yaml: ${shaders.length} shaders registered, $mentions mentions of .frag');
    expect(shaders.length, mentions, reason: 'a .frag is named outside the shaders: list');
    expect(shaders, contains(kPackageShader));

    for (final (:String asset, :String file) in shaders) {
      expect(File(file).existsSync(), isTrue, reason: '$asset is registered and $file is absent');
    }
    // A package shader that nobody registered is in no bundle at all, which is
    // a failure mode with no symptom until something loads it.
    final Iterable<String> own = Directory('lib/shaders')
        .listSync()
        .whereType<File>()
        .map((File f) => f.path)
        .where((String p) => p.endsWith('.frag'));
    expect(own, hasLength(3));
    expect(shaders.map((s) => s.file), containsAll(own));
  });

  test('no shader that samples returns early from main() (#190809, Windows)', () {
    // The known answer first: impellerc on master warns on exactly this.
    const bad =
        'uniform sampler2D uTex;\nout vec4 c;\n'
        'void main() { if (true) { c = vec4(0); return; } c = texture(uTex, vec2(0)); }';
    expect(_samples(bad) && _returnsInMain(bad) > 0, isTrue);
    // And a return outside main() is not one: both package shaders have them.
    expect(_returnsInMain('float f() { return 1.0; }\nvoid main() { }'), 0);

    var sampling = 0;
    for (final (asset: _, file: String s) in shaders) {
      final String source = File(s).readAsStringSync();
      if (!_samples(source)) continue;
      sampling++;
      expect(_returnsInMain(source), 0, reason: '$s samples a texture and returns early from main()');
    }
    print('$sampling sampling shaders, none returns early from main()');
    expect(sampling, greaterThan(1));
  });

  test('every shader in the bundle compiles for all five targets', () {
    var compiled = 0;
    for (final (asset: _, file: String s) in shaders) {
      final String out = '${tmp.path}/${s.replaceAll('/', '_')}.out';
      final ({bool ok, String message}) all = _compile(s, kTargets, out: out);
      if (!all.ok) {
        // Attribution, and only on the unhappy path: the union says a platform
        // is broken, the per-target pass says which one and what it said.
        final List<String> failed = <String>[];
        for (final String t in kTargets) {
          final ({bool ok, String message}) one = _compile(s, <String>[t], out: '$out.$t');
          if (!one.ok) failed.add('$t: ${one.message}');
        }
        fail(
          '$s does not build for every target.\n'
          '${failed.isEmpty ? all.message : failed.join('\n')}\n'
          'The escape is compile-time: #ifdef SKIA_GRAPHICS_BACKEND for the '
          'fallback, IMPELLER_GRAPHICS_BACKEND for the real technique. '
          'Left unguarded, a SkSL refusal kills the web build and ships every '
          'other platform an asset that throws on Skia at runtime.',
        );
      }
      compiled++;
    }
    print('$compiled shaders x ${kTargets.length} targets, no refusals');
    expect(compiled, shaders.length);
  });

  test('and the gate can see a refusal: an unguarded derivative fails SkSL and only SkSL', () {
    // The known answer, in the same run, on the same engine. Without it "every
    // shader compiled" reads identically to a gate whose compiler stopped
    // refusing anything — which is not hypothetical: SkSL is a moving target
    // and this arm is what will notice when it moves.
    final File probe = File('${tmp.path}/known_answer.frag')
      ..writeAsStringSync(
        '#version 460 core\n'
        '#include <flutter/runtime_effect.glsl>\n'
        'uniform vec2 uSlope;\n'
        'out vec4 fragColor;\n'
        'void main() {\n'
        '    float d = dot(FlutterFragCoord().xy, uSlope);\n'
        '    fragColor = vec4(dFdx(d), 0.0, 0.0, 1.0);\n'
        '}\n',
      );
    expect(
      _compile(probe.path, kTargets, out: '${tmp.path}/known_answer.out').ok,
      isFalse,
      reason: 'an unguarded dFdx now builds for all five targets — the arm above proves nothing',
    );
    for (final String t in kTargets) {
      final ({bool ok, String message}) one = _compile(probe.path, <String>[t], out: '${tmp.path}/known_answer.$t.out');
      if (t == kSkSL) {
        expect(one.ok, isFalse, reason: 'SkSL took a derivative');
        expect(one.message, isNotEmpty);
        print('known answer: $t refuses -> ${one.message}');
      } else {
        expect(one.ok, isTrue, reason: 'the probe fails on $t too, so SkSL is not what refused');
      }
    }
  });

  test('the package shader carries an SkSL stage rather than a blessing', () {
    // Compiling for `--sksl` and *containing* SkSL are different claims, and
    // only the second is what loads on Skia. The difference between the two
    // artifacts is the stage, in bytes.
    final String withSksl = '${tmp.path}/package.all.out';
    final String without = '${tmp.path}/package.impeller.out';
    final String source = kPackageShader.file;
    expect(_compile(source, kTargets, out: withSksl).ok, isTrue);
    expect(
      _compile(source, kTargets.where((String t) => t != kSkSL).toList(), out: without).ok,
      isTrue,
    );
    final int a = File(withSksl).lengthSync();
    final int b = File(without).lengthSync();
    print('$source: $b bytes of Impeller stages, $a with SkSL (+${a - b})');
    expect(a, greaterThan(b), reason: 'the SkSL target was accepted and emitted nothing');
  });

  test('the ripple is not in the surface binary: deleting every GLASS_RIPPLE block changes no byte', () {
    // The ripple's cost claim at the compiler. The ripple program is the
    // surface's source behind a define, and a path a program carries and does
    // not take was measured at 52-62% of the modes that do not take it — so the claim
    // that a still panel pays nothing is the claim that this binary has no
    // ripple in it, which is a comparison of bytes, not of timings.
    final String source = File(kPackageShader.file).readAsStringSync();
    final block = RegExp(r'#ifdef GLASS_RIPPLE\n.*?#endif\n', dotAll: true);
    final int blocks = block.allMatches(source).length;
    // The uniforms, the displacement, the light. A count that fell to zero
    // would compare the file with itself.
    expect(blocks, 3, reason: 'the ripple blocks moved or were renamed');
    final Directory dir = Directory('${tmp.path}/stripped')..createSync();
    final File stripped = File('${dir.path}/glass_surface.frag')..writeAsStringSync(source.replaceAll(block, ''));
    final File nudged = File('${dir.path}/nudged.frag')
      ..writeAsStringSync(stripped.readAsStringSync().replaceFirst('0.5 - d / uPixel', '0.5001 - d / uPixel'));
    expect(nudged.readAsStringSync(), isNot(stripped.readAsStringSync()));

    final Map<String, List<int>> bytes = <String, List<int>>{};
    for (final (String name, String input) in <(String, String)>[
      ('shipped', kPackageShader.file),
      ('stripped', stripped.path),
      ('nudged', nudged.path),
      ('ripple', 'lib/shaders/glass_surface_ripple.frag'),
    ]) {
      final String out = '${tmp.path}/strip.$name.out';
      expect(_compile(input, kTargets, out: out).ok, isTrue, reason: '$name did not compile');
      bytes[name] = File(out).readAsBytesSync();
    }
    bool same(String a, String b) => listEquals(bytes[a], bytes[b]);
    print(
      'surface binary ${bytes['shipped']!.length} B; stripped identical: ${same('shipped', 'stripped')}; '
      'one constant nudged identical: ${same('shipped', 'nudged')}; ripple ${bytes['ripple']!.length} B',
    );
    // The known answer first: the comparison sees one constant in the fragment.
    expect(same('shipped', 'nudged'), isFalse, reason: 'a changed constant compiled to the same bytes');
    expect(same('shipped', 'ripple'), isFalse);
    expect(same('shipped', 'stripped'), isTrue, reason: 'the surface binary carries part of the ripple');
  });

  group('on the Skia backend this test itself runs on', () {
    testWidgets('every shader in the bundle loads', (WidgetTester tester) async {
      // The same question as the compile matrix, asked the way a user's app
      // asks it. `flutter test` builds for `TargetPlatform.tester` — SkSL and
      // vulkan — and draws on Skia, so a missing SkSL stage arrives here as the
      // throw it would arrive as in production.
      await tester.runAsync(() async {
        var loaded = 0;
        for (final (asset: String s, file: _) in shaders) {
          try {
            await ui.FragmentProgram.fromAsset(s);
            loaded++;
          } on Object catch (e) {
            fail('$s is in the bundle and does not load on Skia: $e');
          }
        }
        print('$loaded of ${shaders.length} shaders loaded on Skia');
        expect(loaded, shaders.length);
      });
    });
  });
}
