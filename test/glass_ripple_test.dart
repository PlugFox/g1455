// The ripple (D229): a viscous wave from where the glass was touched.
//
// `flutter test test/glass_ripple_test.dart`
//
// Four claims, each a different way of being wrong:
//
//  1. **The ripple program is the surface program until a wave exists.** It is
//     the same source behind a define, so at zero waves it must draw the same
//     bytes — and the base binary must not contain the ripple at all, which
//     `shader_targets_test.dart` checks at the compiler. A wave is the
//     control: it must differ, and only inside the shape.
//  2. **The amplitude is a bound, not a scale.** Every term is normalised so
//     that no fragment moves further than the sum of the amplitudes alive,
//     which is what keeps a wave's samples inside the shape. A normalisation
//     that made the bound loose would pass that; the arm also asserts it is
//     reached.
//  3. **Viscosity is one knob over the whole model**: thin rings and
//     overshoots, thick does neither, and either dies in finite time — and a
//     held finger stops costing frames once its dimple has sunk.
//  4. **A wave costs the draw and nothing upstream.** No capture, no repaint
//     of the content, and the frame after the last wave is byte-identical to
//     the frame before the touch.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

// ignore_for_file: avoid_print

const Size kScreen = Size(400, 300);
const Rect kGlass = Rect.fromLTWH(60, 50, 280, 200);
final GlobalKey _shotKey = GlobalKey();

/// The surface program's floats, and the ripple program's: the same block
/// with the count, `uWave[4]`, `uWaveAmp[4]`, the reach and the light after it.
const int kSurfaceUniformFloats = 34;
const int kRippleUniformFloats = kSurfaceUniformFloats + 1 + kMaxRippleWaves * 8 + 2;

void main() {
  // -------------------------------------------------------------------------
  // 1. The two programs.
  // -------------------------------------------------------------------------

  testWidgets('each program takes exactly the floats its writer sets', (WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final (String asset, int expected) in <(String, int)>[
        (kGlassShaderAsset, kSurfaceUniformFloats),
        (kGlassRippleShaderAsset, kRippleUniformFloats),
      ]) {
        final ui.FragmentShader shader = (await ui.FragmentProgram.fromAsset(asset)).fragmentShader();
        var count = 0;
        while (count < 4096) {
          try {
            shader.setFloat(count, 0);
          } on Object {
            break;
          }
          count++;
        }
        shader.dispose();
        expect(count, expected, reason: '$asset: the uniform block moved');
      }
    });
  });

  testWidgets('at zero waves the ripple program draws the surface program, byte for byte', (
    WidgetTester tester,
  ) async {
    late ui.Image backdrop;
    late ui.Image base;
    late ui.Image still;
    late ui.Image wave;
    await tester.runAsync(() async {
      backdrop = _backdrop();
      final ui.FragmentProgram surface = await ui.FragmentProgram.fromAsset(kGlassShaderAsset);
      final ui.FragmentProgram ripple = await ui.FragmentProgram.fromAsset(kGlassRippleShaderAsset);
      base = _render(surface, backdrop, null);
      still = _render(ripple, backdrop, const <GlassRippleWave>[]);
      wave = _render(ripple, backdrop, <GlassRippleWave>[_probeWave]);
    });
    final _Diff same = await _compare(tester, base, still);
    final _Diff moved = await _compare(tester, base, wave, outside: kProbeShape);
    print('zero waves: $same; one wave: $moved');
    expect(same.differing, 0, reason: 'the ripple program is not the surface program at rest — $same');
    // The control: the arm above is "two programs agree", and a ripple program
    // whose waves never reached the fragment would agree too.
    expect(moved.differing, greaterThan(500), reason: 'a wave changed nothing — $moved');
    expect(moved.outside, 0, reason: 'a wave drew outside the shape — $moved');
    for (final ui.Image i in <ui.Image>[backdrop, base, still, wave]) {
      i.dispose();
    }
  });

  // -------------------------------------------------------------------------
  // 2. The amplitude is a bound, and it is reached.
  // -------------------------------------------------------------------------

  test('no fragment moves further than the reach', () {
    for (final double viscosity in <double>[0, 0.6, 1]) {
      final field = GlassRippleField(GlassRipple(viscosity: viscosity))..down(1, const Offset(10, -5));
      var worst = 0.0;
      var frames = 0;
      for (var ms = 16; ms <= 600; ms += 16) {
        if (ms == 160) {
          field.up(1);
        }
        field.advance(Duration(milliseconds: ms), extent: 200);
        if (field.waves.isEmpty || field.reach < 0.05) {
          continue;
        }
        frames++;
        worst = math.max(worst, _peak(field.waves, step: 1) / field.reach);
      }
      print('viscosity $viscosity: peak / reach at most ${worst.toStringAsFixed(3)} over $frames frames');
      expect(frames, greaterThan(10));
      expect(worst, lessThanOrEqualTo(1 + 1e-9));
    }
  });

  test('and the bound is the amplitude, reached, for a plain front and for a dimple', () {
    // The known answers. A normalisation that made the bound loose would pass
    // the arm above at any looseness; these two terms reach it exactly, at
    // u = 1/sqrt(2) and r = sigma/sqrt(2), up to the softened radius (a front
    // far from its touch) and the grid.
    const front = GlassRippleWave(
      centre: Offset.zero,
      radius: 90,
      halfWidth: 10,
      front: 5,
      ringing: 0,
      dimple: 0,
      sigma: 20,
    );
    const dimple = GlassRippleWave(
      centre: Offset.zero,
      radius: 0,
      halfWidth: 10,
      front: 0,
      ringing: 0,
      dimple: -5,
      sigma: 20,
    );
    const ringing = GlassRippleWave(
      centre: Offset.zero,
      radius: 90,
      halfWidth: 10,
      front: 5,
      ringing: 3,
      dimple: 0,
      sigma: 20,
    );
    final double a = _peak(const <GlassRippleWave>[front]) / front.bound;
    final double b = _peak(const <GlassRippleWave>[dimple]) / dimple.bound;
    final double c = _peak(const <GlassRippleWave>[ringing]) / ringing.bound;
    print(
      'peak / bound: front ${a.toStringAsFixed(4)}, dimple ${b.toStringAsFixed(4)}, '
      'ringing front ${c.toStringAsFixed(4)} (its bound is 2|u| + k, loose by design)',
    );
    expect(a, inInclusiveRange(0.99, 1));
    expect(b, inInclusiveRange(0.99, 1));
    expect(c, lessThanOrEqualTo(1));
  });

  // -------------------------------------------------------------------------
  // 3. Viscosity, lifetime, a held finger.
  // -------------------------------------------------------------------------

  test('thin overshoots on release and thick does not', () {
    double lowest(double viscosity) {
      final field = GlassRippleField(GlassRipple(viscosity: viscosity))..down(1, Offset.zero);
      var low = 0.0;
      for (var ms = 0; ms <= 1500; ms += 4) {
        if (ms == 400) {
          field.up(1);
        }
        field.advance(Duration(milliseconds: ms), extent: 1e6);
        // The dimple is negative; past zero it is a crest.
        for (final GlassRippleWave w in field.waves) {
          low = math.max(low, w.dimple);
        }
      }
      return low;
    }

    final double thin = lowest(0);
    final double thick = lowest(1);
    print('highest crest of the dimple after release: thin $thin px, thick $thick px');
    expect(thin, greaterThan(0.5), reason: 'a thin liquid did not spring back past level');
    expect(thick, lessThanOrEqualTo(0), reason: 'honey overshot');
  });

  test('a ringing dimple outlives its zero crossings', () {
    // Held long enough for the press front to be gone, on a surface so small
    // the release front is gone by 0.1 s: after that the dimple is the touch.
    // It crosses zero at ~0.07 s and ~0.19 s after release while its envelope
    // is still 1.6 px, and a touch judged by the value dropped there.
    final field = GlassRippleField(const GlassRipple(viscosity: 0))..down(1, Offset.zero);
    for (var ms = 0; ms <= 1500; ms += 4) {
      field.advance(Duration(milliseconds: ms), extent: 0);
    }
    field.up(1);
    var lastAlive = 0;
    for (var ms = 1504; ms <= 3000; ms += 4) {
      field.advance(Duration(milliseconds: ms), extent: 0);
      if (!field.isEmpty) {
        lastAlive = ms - 1504;
      }
    }
    // The known answer: the envelope `scale * exp(-zeta omega t) / sqrt(1 - zeta^2)`
    // reaches the 0.02 px floor at exactly this time. A touch judged by the
    // value instead dies at whichever crossing a frame lands in (440 ms, the
    // break's run).
    const ripple = GlassRipple(viscosity: 0);
    final double scale = ripple.press * ripple.amplitude;
    final double z = ripple.springZeta;
    final double predicted = math.log(scale / (0.02 * math.sqrt(1 - z * z))) / (z * ripple.springOmega) * 1000;
    print('a released thin dimple lives $lastAlive ms, its envelope predicts ${predicted.toStringAsFixed(1)}');
    expect(lastAlive.toDouble(), closeTo(predicted, 8), reason: 'dropped before its envelope was gone');
  });

  test('a tap dies in finite time, and a held finger stops changing once its dimple has sunk', () {
    for (final double viscosity in <double>[0, 1]) {
      final field = GlassRippleField(GlassRipple(viscosity: viscosity))..down(1, const Offset(20, 0));
      field.advance(Duration.zero, extent: 170);
      field.up(1);
      var ms = 16;
      while (!field.isEmpty && ms < 10000) {
        field.advance(Duration(milliseconds: ms), extent: 170);
        ms += 16;
      }
      print('viscosity $viscosity: a tap lives $ms ms');
      expect(field.isEmpty, isTrue);
      expect(ms, lessThan(3000));

      final held = GlassRippleField(GlassRipple(viscosity: viscosity))..down(1, Offset.zero);
      var changing = true;
      ms = 0;
      while (changing && ms < 10000) {
        changing = held.advance(Duration(milliseconds: ms), extent: 170);
        ms += 16;
      }
      print('viscosity $viscosity: a held finger settles at $ms ms');
      expect(changing, isFalse);
      expect(ms, lessThan(2000));
      expect(held.isEmpty, isFalse, reason: 'the dimple under the finger went away');
      expect(held.waves.single.dimple, lessThan(0));
    }
  });

  test('more touches than the draw takes drop the weakest waves, and say so', () {
    final field = GlassRippleField(const GlassRipple());
    for (var i = 0; i < 6; i++) {
      field.down(i, Offset(i * 10.0, 0));
      field.advance(Duration(milliseconds: i * 30), extent: 1e6);
      field.up(i);
    }
    field.advance(const Duration(milliseconds: 200), extent: 1e6);
    expect(field.waves.length, kMaxRippleWaves);
    expect(field.dropped, greaterThan(0));
    for (var i = 1; i < field.waves.length; i++) {
      expect(field.waves[i].bound, lessThanOrEqualTo(field.waves[i - 1].bound));
    }
  });

  test('a dragged finger lets go where it is, and its press front stays where it landed', () {
    const landed = Offset(-80, 0);
    const left = Offset(70, 10);
    final field = GlassRippleField(const GlassRipple())..down(1, landed);
    for (var ms = 0; ms <= 120; ms += 8) {
      field.advance(Duration(milliseconds: ms), extent: 170);
      field.move(1, Offset.lerp(landed, left, ms / 120)!);
    }
    field.up(1, left);
    // Two frames: a front is born at zero and rises.
    field.advance(const Duration(milliseconds: 128), extent: 170);
    field.advance(const Duration(milliseconds: 160), extent: 170);
    final GlassRippleWave press = field.waves.firstWhere((GlassRippleWave w) => w.front < 0);
    final GlassRippleWave release = field.waves.firstWhere((GlassRippleWave w) => w.front > 0);
    print('press front at ${press.centre}, release front at ${release.centre} (dimple ${release.dimple})');
    expect(press.centre, landed);
    expect(release.centre, left, reason: 'the release front started where the finger landed');
    expect(release.dimple, lessThan(0), reason: 'the dimple did not follow the finger');
    expect(press.dimple, 0);

    // The control: a finger that never moved folds its dimple into the press
    // front, as it did before a drag existed, and lets go where it landed.
    final still = GlassRippleField(const GlassRipple())..down(1, landed);
    for (var ms = 0; ms <= 120; ms += 8) {
      still.advance(Duration(milliseconds: ms), extent: 170);
    }
    still.up(1, landed);
    still.advance(const Duration(milliseconds: 128), extent: 170);
    still.advance(const Duration(milliseconds: 160), extent: 170);
    expect(still.waves.map((GlassRippleWave w) => w.centre).toSet(), <Offset>{landed});
    expect(still.waves.firstWhere((GlassRippleWave w) => w.front < 0).dimple, lessThan(0));
  });

  // -------------------------------------------------------------------------
  // 4. End to end: the draw and nothing upstream.
  // -------------------------------------------------------------------------

  testWidgets('a tap ripples, captures nothing, repaints no content, and leaves no trace', (
    WidgetTester tester,
  ) async {
    final hostKey = GlobalKey();
    final paints = _Counter();
    final backdrop = ValueNotifier<int>(0);
    addTearDown(backdrop.dispose);
    await _pump(
      tester,
      _Scene(paints: paints, ripple: const GlassRipple(), backdrop: backdrop),
      hostKey: hostKey,
    );
    final RenderGlassSurface glass = tester.renderObject(find.byType(GlassSurface));
    final dynamic host = hostKey.currentState! as dynamic;
    expect(glass.paintsWithOptics, greaterThan(0), reason: 'the glass never drew its optics');

    final Uint8List before = await _pixels(tester, _frame());
    final int recorded = host.recorded as int;
    final int painted = paints.value;

    final TestGesture finger = await tester.startGesture(const Offset(150, 120));
    var differed = 0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (i == 5) {
        differed = await _differing(tester, before);
      }
    }
    await finger.up();
    var frames = 0;
    while (tester.binding.hasScheduledFrame && frames < 600) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    final int after = await _differing(tester, before);
    print(
      'mid-wave $differed px differ; settled after $frames frames; '
      'ticks ${glass.rippleTicks}, ripple draws ${glass.rippleDraws}, '
      'captures ${(host.recorded as int) - recorded}, content paints ${paints.value - painted}; '
      'after: $after px',
    );
    expect(differed, greaterThan(500), reason: 'the wave is not on the screen');
    expect(glass.rippleDraws, greaterThan(10));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the wave never stopped asking for frames');
    expect((host.recorded as int) - recorded, 0, reason: 'a wave took a capture');
    expect(paints.value - painted, 0, reason: 'a wave repainted what the glass holds');
    expect(after, 0, reason: 'the settled frame is not the frame before the touch');

    // The control for "captures 0": the same counter, on the same mount, does
    // count a change behind the glass. Without it the arm above passes on a
    // host that had stopped recording anything.
    final int held = host.recorded as int;
    backdrop.value++;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    print('a repainted backdrop: ${(host.recorded as int) - held} captures');
    expect((host.recorded as int) - held, greaterThan(0), reason: 'the capture counter cannot move');
  });

  testWidgets('reduced motion, a theme, and a touch that goes through', (WidgetTester tester) async {
    // Reduced motion: declared, and nothing happens.
    final paints = _Counter();
    await _pump(
      tester,
      _Scene(paints: paints, ripple: const GlassRipple()),
      hostKey: GlobalKey(),
      reduceMotion: true,
    );
    RenderGlassSurface glass = tester.renderObject(find.byType(GlassSurface));
    await tester.tapAt(const Offset(150, 120));
    await tester.pump(const Duration(milliseconds: 16));
    expect(glass.effectiveRipple, isNull);
    expect(glass.rippleTicks, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Through the theme, and translucent: an empty glass over a button lets
    // the button hear the tap, and ripples anyway.
    var taps = 0;
    await _pump(
      tester,
      _Scene(paints: paints, themed: const GlassRipple(), onBehindTap: () => taps++),
      hostKey: GlobalKey(),
    );
    glass = tester.renderObject(find.byType(GlassSurface));
    await tester.tapAt(const Offset(150, 120));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(taps, 1, reason: 'the glass swallowed the tap');
    expect(glass.rippleTicks, greaterThan(0), reason: 'the theme\'s ripple did not apply');

    // And with no ripple declared, the glass is not a hit target at all.
    await _pump(
      tester,
      _Scene(paints: paints, onBehindTap: () => taps++),
      hostKey: GlobalKey(),
    );
    glass = tester.renderObject(find.byType(GlassSurface));
    final result = BoxHitTestResult();
    glass.hitTest(result, position: const Offset(90, 70));
    expect(result.path, isEmpty);
    await tester.pumpAndSettle();
  });
}

/// The longest displacement [waves] put on any fragment of a 280 x 200 grid
/// around them, every [step] px.
double _peak(List<GlassRippleWave> waves, {double step = 0.25}) {
  var peak = 0.0;
  for (var y = -100.0; y <= 100; y += step) {
    for (var x = -140.0; x <= 140; x += step) {
      var d = Offset.zero;
      for (final GlassRippleWave w in waves) {
        d += w.displacementAt(Offset(x, y));
      }
      peak = math.max(peak, d.distance);
    }
  }
  return peak;
}

// ---------------------------------------------------------------------------
// The scene.
// ---------------------------------------------------------------------------

class _Counter {
  int value = 0;
}

class _Scene extends StatelessWidget {
  const _Scene({required this.paints, this.ripple, this.themed, this.onBehindTap, this.backdrop});

  final _Counter paints;
  final Listenable? backdrop;
  final GlassRipple? ripple;
  final GlassRipple? themed;
  final VoidCallback? onBehindTap;

  @override
  Widget build(BuildContext context) {
    final Widget surface = GlassSurface(
      ripple: ripple,
      child: onBehindTap == null ? CustomPaint(painter: _Label(paints)) : null,
    );
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: onBehindTap == null
                    ? CustomPaint(painter: _Bars(repaint: backdrop))
                    : GestureDetector(
                        onTap: onBehindTap,
                        child: CustomPaint(painter: _Bars()),
                      ),
              ),
            ),
            Positioned.fromRect(
              rect: kGlass,
              child: themed == null
                  ? surface
                  : GlassTheme(
                      data: GlassThemeData(ripple: themed),
                      child: surface,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass's content: a mark that counts its own paints.
class _Label extends CustomPainter {
  _Label(this.paints);

  final _Counter paints;

  @override
  void paint(Canvas canvas, Size size) {
    paints.value++;
    canvas.drawRect(const Rect.fromLTWH(12, 12, 20, 6), Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_Label oldDelegate) => false;
}

class _Bars extends CustomPainter {
  _Bars({super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E2A44));
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), Paint()..color = const Color(0xFFE0B040));
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), Paint()..color = const Color(0xFF40C0E0));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

Widget _mount(Widget child, {Key? hostKey, bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(size: kScreen, devicePixelRatio: 1, disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(key: hostKey, hardware: GlassHardware.appleMetal, child: child),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget child, {Key? hostKey, bool reduceMotion = false}) async {
  await tester.pumpWidget(_mount(child, hostKey: hostKey, reduceMotion: reduceMotion));
  for (var i = 1; i < 6; i++) {
    await tester.pump();
  }
}

ui.Image _frame() {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

Future<Uint8List> _pixels(WidgetTester tester, ui.Image image) async {
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return out;
}

Future<int> _differing(WidgetTester tester, Uint8List before) async {
  final Uint8List now = await _pixels(tester, _frame());
  expect(now.length, before.length);
  expect(now.length, kScreen.width * kScreen.height * 4);
  var differing = 0;
  for (var i = 0; i < now.length; i += 4) {
    if (now[i] != before[i] || now[i + 1] != before[i + 1] || now[i + 2] != before[i + 2]) {
      differing++;
    }
  }
  return differing;
}

// ---------------------------------------------------------------------------
// The programs, driven directly.
// ---------------------------------------------------------------------------

const Size kProbe = Size(200, 150);

/// The probe's glass: the whole probe, inset 10, radius 24.
final RSuperellipse kProbeShape = RSuperellipse.fromRectAndRadius(
  (Offset.zero & kProbe).deflate(10),
  const Radius.circular(24),
);

/// A front mid-flight with a dimple, as the field would make one.
const GlassRippleWave _probeWave = GlassRippleWave(
  centre: Offset(-20, 5),
  radius: 40,
  halfWidth: 12,
  front: -6,
  ringing: 1.5,
  dimple: -4,
  sigma: 22,
);

ui.Image _backdrop() {
  final recorder = ui.PictureRecorder();
  _Bars().paint(Canvas(recorder), kProbe);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(kProbe.width.toInt(), kProbe.height.toInt());
  picture.dispose();
  return image;
}

/// The surface program's block as `_paintOptics` writes it, at dpr 1 over a
/// slot that is the whole probe — and, given [waves], the ripple tail.
ui.Image _render(ui.FragmentProgram program, ui.Image backdrop, List<GlassRippleWave>? waves) {
  final ui.FragmentShader shader = program.fragmentShader();
  var i = 0;
  void w(double v) => shader.setFloat(i++, v);
  const GlassFinish finish = GlassFinish.regularDark;
  final GlassOptics optics = finish.optics;
  final Rect box = (Offset.zero & kProbe).deflate(10);
  for (final double v in <double>[
    kProbe.width, kProbe.height, 0, 0, 1, //
    0.5, 0.5, kProbe.width - 0.5, kProbe.height - 0.5,
    box.width / 2, box.height / 2, box.center.dx, box.center.dy, 24,
    optics.thickness, optics.strength, optics.edgePower, optics.shoulder,
    finish.tint.r, finish.tint.g, finish.tint.b, finish.tint.a,
    kRimWidthLogical, finish.rim.r, finish.rim.g, finish.rim.b, finish.rim.a,
    1, 0, 0, 0, 0, 0, 0,
  ]) {
    w(v);
  }
  expect(i, kSurfaceUniformFloats);
  if (waves != null) {
    w(waves.length.toDouble());
    final List<List<double>> rows = <List<double>>[
      for (var k = 0; k < kMaxRippleWaves; k++)
        k < waves.length ? waves[k].uniforms() : const <double>[0, 0, 0, 1, 0, 0, 0, 0],
    ];
    for (final List<double> r in rows) {
      r.take(4).forEach(w);
    }
    for (final List<double> r in rows) {
      r.skip(4).forEach(w);
    }
    final double reach = waves.fold(0, (double s, GlassRippleWave x) => s + x.bound);
    w(reach > 1e-3 ? reach : 1e-3);
    w(0.08);
    expect(i, kRippleUniformFloats);
  }
  shader.setImageSampler(0, backdrop, filterQuality: FilterQuality.low);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Offset.zero & kProbe, Paint()..shader = shader);
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(kProbe.width.toInt(), kProbe.height.toInt());
  } finally {
    picture.dispose();
    shader.dispose();
  }
}

class _Diff {
  const _Diff(this.differing, this.worst, this.outside);

  final int differing;
  final int worst;

  /// Of [differing], pixels whose centre is outside the shape asked about.
  final int outside;

  @override
  String toString() => '$differing px differ, worst $worst, $outside outside the shape';
}

Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b, {RSuperellipse? outside}) async {
  late _Diff diff;
  await tester.runAsync(() async {
    final Uint8List x = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List y = (await b.toByteData())!.buffer.asUint8List();
    expect(x.length, y.length);
    var differing = 0;
    var worst = 0;
    var out = 0;
    for (var i = 0; i < x.length; i += 4) {
      var delta = 0;
      for (var c = 0; c < 4; c++) {
        delta = math.max(delta, (x[i + c] - y[i + c]).abs());
      }
      if (delta == 0) {
        continue;
      }
      differing++;
      worst = math.max(worst, delta);
      final int p = i ~/ 4;
      final centre = Offset(p % a.width + 0.5, p ~/ a.width + 0.5);
      if (outside != null && !outside.contains(centre)) {
        out++;
      }
    }
    diff = _Diff(differing, worst, out);
  });
  return diff;
}
