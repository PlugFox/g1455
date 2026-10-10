// The order in which the Dart writers fill each program's floats, stated a
// second time and independently of the shaders, and the two ways a test holds
// a shader to it.
//
// The shaders pack their uniforms into vectors and name every quantity by a
// macro over a lane, so a repack that puts one name on the wrong lane still
// compiles, still draws, and draws something plausible. Two checks see it:
//
// - [laneMismatches] reads a shader's declarations and macros and says which
//   float index each name resolves to: no rendering, so it covers all three
//   programs on any host.
// - [unpackedReference] writes a copy of a shader with every name declared as
//   a plain uniform in the order below, which compiles to a program reading
//   the floats exactly where the writers put them. Drawn in place of the real
//   program, it must give the same bytes — compared within one run, so on
//   whatever the host rasterizes with.

import 'dart:io';
import 'dart:ui' as ui;

/// One entry of a writer's order: a quantity of [width] floats, or ([kept]) an
/// array the shader declares on its own, which keeps its declaration.
///
/// [swizzle] is for the negative control only: the reference reads this
/// quantity's lanes in that order, as a repack that mis-ordered them would.
class Lane {
  const Lane(this.name, this.width, {this.swizzle}) : kept = false;

  const Lane.kept(this.name, this.width) : kept = true, swizzle = null;

  final String name;
  final int width;
  final bool kept;
  final String? swizzle;
}

/// `glass_surface.frag`, as `RenderGlassSurface` writes it.
const List<Lane> kSurfaceLanes = <Lane>[
  Lane('uTexSize', 2),
  Lane('uMapOrigin', 2),
  Lane('uMapScale', 1),
  Lane('uSlotMin', 2),
  Lane('uSlotMax', 2),
  Lane('uHalf', 2),
  Lane('uCenter', 2),
  Lane('uRadius', 1),
  Lane('uThickness', 1),
  Lane('uStrength', 1),
  Lane('uEdgePower', 1),
  Lane('uShoulder', 1),
  Lane('uTint', 4),
  Lane('uRimWidth', 1),
  Lane('uRim', 4),
  Lane('uPixel', 1),
  Lane('uRimMix', 1),
  Lane('uWiden', 2),
  Lane('uFade', 3),
];

/// `glass_surface_ripple.frag`: the surface's floats, then the waves.
const List<Lane> kRippleLanes = <Lane>[
  ...kSurfaceLanes,
  Lane.kept('uWave', 16),
  Lane.kept('uWaveAmp', 16),
  Lane('uWaveCount', 1),
  Lane('uRippleReach', 1),
  Lane('uRippleLight', 1),
];

/// `glass_group.frag`, as `RenderGlassGroup` writes it.
const List<Lane> kGroupLanes = <Lane>[
  Lane('uTexSize', 2),
  Lane('uMapOrigin', 2),
  Lane('uMapScale', 1),
  Lane('uSlotMin', 2),
  Lane('uSlotMax', 2),
  Lane('uCount', 1),
  Lane('uBlend', 1),
  Lane.kept('uBox', 48),
  Lane.kept('uRadius', 12),
  Lane('uThickness', 1),
  Lane('uStrength', 1),
  Lane('uEdgePower', 1),
  Lane('uShoulder', 1),
  Lane('uTint', 4),
  Lane('uRimWidth', 1),
  Lane('uRim', 4),
  Lane('uPixel', 1),
  Lane('uCullK', 1),
  Lane('uRimMix', 1),
];

/// [lanes] with [name] read in [swizzle] order: the negative control's layout.
List<Lane> withSwizzle(List<Lane> lanes, String name, String swizzle) {
  final int at = lanes.indexWhere((Lane l) => l.name == name && !l.kept);
  if (at < 0) {
    throw StateError('$name is not in the layout');
  }
  return <Lane>[...lanes]..[at] = Lane(name, lanes[at].width, swizzle: swizzle);
}

/// The shader at [path] with `#include "…"` inlined and the conditional blocks
/// resolved under [defines]. Engine includes (`<…>`) are left out: they
/// declare no uniforms.
List<String> _preprocess(String path, Set<String> defines) {
  final String dir = path.substring(0, path.lastIndexOf('/'));
  final List<String> out = <String>[];
  final List<bool> live = <bool>[];
  bool on() => !live.contains(false);
  final Set<String> defined = <String>{...defines};
  for (final String line in File(path).readAsLinesSync()) {
    final String t = line.trim();
    final RegExpMatch? cond = RegExp(r'^#(ifdef|ifndef)\s+(\w+)').firstMatch(t);
    if (cond != null) {
      live.add(defined.contains(cond.group(2)) == (cond.group(1) == 'ifdef'));
      continue;
    }
    if (t.startsWith('#else')) {
      live.add(!live.removeLast());
      continue;
    }
    if (t.startsWith('#endif')) {
      live.removeLast();
      continue;
    }
    if (!on()) {
      continue;
    }
    final RegExpMatch? include = RegExp(r'^#include\s+"([^"]+)"').firstMatch(t);
    if (include != null) {
      out.addAll(_preprocess('$dir/${include.group(1)}', defined));
      continue;
    }
    final RegExpMatch? define = RegExp(r'^#define\s+(\w+)\s*$').firstMatch(t);
    if (define != null) {
      defined.add(define.group(1)!);
    }
    out.add(line);
  }
  return out;
}

const Map<String, int> _widths = <String, int>{'float': 1, 'vec2': 2, 'vec3': 3, 'vec4': 4};

final RegExp _uniform = RegExp(r'^uniform\s+(\w+)\s+(\w+)\s*(?:\[\s*(\w+)\s*\])?\s*;');
final RegExp _macro = RegExp(r'^#define\s+(\w+)\s+(.*?)\s*(?://.*)?$');

/// Which float index every name in [lanes] resolves to in the shader at
/// [path], against the index the writers put it at: one line per name that
/// disagrees, and one if the shader declares floats the layout does not.
///
/// [compared] is told how many names were resolved, so that a parse that found
/// nothing cannot pass for a parse that found everything in place.
List<String> laneMismatches(
  String path,
  List<Lane> lanes, {
  Set<String> defines = const <String>{},
  void Function(int names, int floats)? compared,
}) {
  final List<String> lines = _preprocess(path, defines);
  final Map<String, String> macros = <String, String>{};
  final Map<String, ({int offset, int size})> uniforms = <String, ({int offset, int size})>{};
  var floats = 0;
  for (final String line in lines) {
    final String t = line.trim();
    final RegExpMatch? m = _macro.firstMatch(t);
    if (m != null) {
      macros[m.group(1)!] = m.group(2)!;
      continue;
    }
    final RegExpMatch? u = _uniform.firstMatch(t);
    if (u == null || u.group(1) == 'sampler2D') {
      continue;
    }
    final int? width = _widths[u.group(1)];
    if (width == null) {
      throw StateError('a uniform of type ${u.group(1)}: $t');
    }
    final String? count = u.group(3);
    final int n = count == null ? 1 : int.tryParse(count) ?? int.parse(macros[count]!);
    uniforms[u.group(2)!] = (offset: floats, size: width * n);
    floats += width * n;
  }

  List<int> resolve(String expr) {
    final String e = expr.trim();
    final RegExpMatch? ctor = RegExp(r'^vec[234]\((.*)\)$').firstMatch(e);
    if (ctor != null) {
      return <int>[for (final String arg in ctor.group(1)!.split(',')) ...resolve(arg)];
    }
    final RegExpMatch? ref = RegExp(r'^(\w+)(?:\.([xyzwrgba]+))?$').firstMatch(e);
    final ({int offset, int size})? decl = ref == null ? null : uniforms[ref.group(1)];
    if (decl == null) {
      throw StateError('cannot resolve `$e`');
    }
    final String? swizzle = ref!.group(2);
    if (swizzle == null) {
      return <int>[for (var i = 0; i < decl.size; i++) decl.offset + i];
    }
    return <int>[for (final int c in swizzle.codeUnits) decl.offset + 'xyzw'.indexOf(_xyzw(c))];
  }

  final List<String> out = <String>[];
  var at = 0;
  var names = 0;
  for (final Lane lane in lanes) {
    final List<int> expected = <int>[for (var i = 0; i < lane.width; i++) at + i];
    if (lane.swizzle != null) {
      expected.setAll(0, <int>[for (final int c in lane.swizzle!.codeUnits) at + 'xyzw'.indexOf(_xyzw(c))]);
    }
    at += lane.width;
    final ({int offset, int size})? decl = uniforms[lane.name];
    final List<int> actual = decl != null && !macros.containsKey(lane.name)
        ? <int>[for (var i = 0; i < decl.size; i++) decl.offset + i]
        : macros.containsKey(lane.name)
        ? resolve(macros[lane.name]!)
        : <int>[];
    names++;
    if (actual.length != expected.length || !_same(actual, expected)) {
      out.add('${lane.name}: written at $expected, read from $actual');
    }
  }
  if (floats != at) {
    out.add('the shader declares $floats floats, the writers fill $at');
  }
  compared?.call(names, floats);
  return out;
}

String _xyzw(int c) => switch (String.fromCharCode(c)) {
  'r' => 'x',
  'g' => 'y',
  'b' => 'z',
  'a' => 'w',
  final String s => s,
};

bool _same(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The shader at [path] rewritten to read every name in [lanes] from a uniform
/// of its own, declared in the layout's order — no vectors, no macros — and
/// the rest of the source untouched.
///
/// The packed declarations removed are exactly those the names' macros read,
/// so a declaration the layout does not account for stays and shifts every
/// index after it, which shows as a different picture.
String unpackedReference(String path, List<Lane> lanes) {
  final List<String> lines = File(path).readAsLinesSync();
  final Set<String> named = <String>{
    for (final Lane l in lanes)
      if (!l.kept) l.name,
  };
  final Set<String> packed = <String>{};
  for (final String line in lines) {
    final RegExpMatch? m = _macro.firstMatch(line.trim());
    if (m != null && named.contains(m.group(1))) {
      packed.addAll(RegExp(r'\b(\w+)\b').allMatches(m.group(2)!).map((Match w) => w.group(1)!));
    }
  }

  String declare(Lane l) {
    final String type = l.width == 1 ? 'float' : 'vec${l.width}';
    final String? s = l.swizzle;
    return s == null
        ? 'uniform $type ${l.name};'
        : 'uniform $type ${l.name}_lanes;\n#define ${l.name} ${l.name}_lanes.$s';
  }

  // Runs of plain names, each keyed by the array declared before it (or by
  // nothing, for the run that opens the block).
  final Map<String?, List<String>> runs = <String?, List<String>>{};
  String? after;
  for (final Lane l in lanes) {
    if (l.kept) {
      after = l.name;
    } else {
      (runs[after] ??= <String>[]).add(declare(l));
    }
  }

  final List<String> out = <String>[];
  var opened = false;
  for (final String line in lines) {
    final String t = line.trim();
    final RegExpMatch? m = _macro.firstMatch(t);
    if (m != null && named.contains(m.group(1))) {
      continue;
    }
    final RegExpMatch? u = _uniform.firstMatch(t);
    if (u != null && packed.contains(u.group(2))) {
      if (!opened) {
        out.addAll(runs.remove(null) ?? const <String>[]);
        opened = true;
      }
      continue;
    }
    out.add(line);
    if (u != null && runs.containsKey(u.group(2))) {
      out.addAll(runs.remove(u.group(2))!);
    }
  }
  if (runs.isNotEmpty) {
    throw StateError('no place found for ${runs.keys} in $path');
  }
  return out.join('\n');
}

/// Compiles [source] as `flutter test` compiles the package's shaders and
/// loads it as a program, through the test's own asset directory: the only
/// place `FragmentProgram.fromAsset` reads from.
///
/// [name] is the asset key under `lane_oracle/`, which nothing else uses.
/// [includeDir] is where the source's `#include "…"` resolve.
Future<ui.FragmentProgram> compileProgram(String name, String source, {required String includeDir}) async {
  // `flutter test` runs on `flutter_tester`, which sits beside `impellerc`.
  final String engine = File(Platform.resolvedExecutable).parent.path;
  const assets = 'build/unit_test_assets';
  if (!Directory(assets).existsSync()) {
    throw StateError('no $assets: this check runs under `flutter test` from the package root');
  }
  final Directory dir = Directory('$assets/lane_oracle')..createSync(recursive: true);
  final input = File('${dir.path}/$name.src.frag')..writeAsStringSync(source);
  final String out = '${dir.path}/$name.frag';
  // The targets the tool builds for `TargetPlatform.tester`.
  final ProcessResult r = Process.runSync('$engine/impellerc', <String>[
    '--sksl',
    '--runtime-stage-vulkan',
    '--iplr',
    '--sl=$out',
    '--spirv=$out.spirv',
    '--input=${input.path}',
    '--input-type=frag',
    '--include=$includeDir',
    '--include=$engine/shader_lib',
  ]);
  final String said = '${r.stdout}${r.stderr}'.trim();
  if (r.exitCode != 0 || said.contains('Compilation failed')) {
    throw StateError('impellerc refused $name: $said');
  }
  return ui.FragmentProgram.fromAsset('lane_oracle/$name.frag');
}

/// Removes what [compileProgram] wrote.
void deleteCompiledPrograms() {
  final dir = Directory('build/unit_test_assets/lane_oracle');
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}
