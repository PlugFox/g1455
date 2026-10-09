// A declared backdrop: glass that samples a texture the application gave it
// instead of a capture of the screen.
//
// `flutter test test/glass_backdrop_test.dart`
//
// The claim has the shape this package keeps catching defects in: glass over a
// declared colour and glass over a captured screen of that colour draw the same
// pixels, so a declaration that silently fell back to the capture would pass
// every picture. The arms are therefore counters first — captures taken, which
// source a surface sampled, textures rendered — each against a twin that must
// move where it does not; and the pictures second, each with a deliberately
// false declaration that must come out different.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 600);
const Color _kGrey = Color(0xFF6A6A6A);
const Color _kOrange = Color(0xFFE0782A);
const Rect _kPanel = Rect.fromLTWH(100, 250, 200, 100);
final GlobalKey _shotKey = GlobalKey();

void main() {
  testWidgets('glass over a declared colour takes no capture, and its twin over the painted colour does', (
    WidgetTester tester,
  ) async {
    final declaredKey = GlobalKey();
    await _pump(tester, _scene(hostKey: declaredKey, declared: true));
    final dynamic declared = declaredKey.currentState! as dynamic;
    final RenderGlassSurface surface = _surface(tester);
    expect(declared.recorded, 0, reason: 'a declared backdrop was captured anyway');
    expect(_handle(tester).snapshots, 0);
    expect(_handle(tester).frame, isNull);
    expect(surface.readsDeclaredBackdrop, isTrue);
    expect(surface.paintsWithDeclaredBackdrop, greaterThan(0), reason: 'the declaration was never sampled');
    expect(surface.paintsWithOptics, greaterThan(0), reason: 'the declared glass drew without its optics');
    expect(surface.paintsWithoutProxy, 0);

    // The twin: the same screen, the colour painted and not declared.
    final capturedKey = GlobalKey();
    await _pump(tester, _scene(hostKey: capturedKey, declared: false));
    expect((capturedKey.currentState! as dynamic).recorded, greaterThan(0), reason: 'the control captured nothing');
    expect(_surface(tester).paintsWithDeclaredBackdrop, 0);
    expect(_surface(tester).readsDeclaredBackdrop, isFalse);
  });

  testWidgets('a declared colour draws what the capture of that colour draws, and a false one does not', (
    WidgetTester tester,
  ) async {
    for (final GlassFinish finish in <GlassFinish>[GlassFinish.regularDark, GlassFinish.clear]) {
      final ui.Image captured = await _shot(tester, _scene(declared: false, finish: finish));
      final ui.Image declared = await _shot(tester, _scene(declared: true, finish: finish));
      final _Diff same = await _compare(tester, captured, declared, _kPanel);
      expect(same.compared, greaterThan(15000), reason: 'the panel was not compared');
      expect(same.maxDelta, lessThanOrEqualTo(2), reason: '${finish.name}: declared and captured differ: $same');

      // A declaration that lies — orange declared over a grey screen, and not
      // painted — has to show orange. Without this the arm above passes on a
      // surface that ignores the declaration.
      final ui.Image lying = await _shot(
        tester,
        _scene(declared: true, finish: finish, declaredColor: _kOrange, paintBackdrop: false),
      );
      final _Diff lie = await _compare(tester, captured, lying, _kPanel);
      expect(lie.maxDelta, greaterThan(20), reason: '${finish.name}: the false declaration was not drawn: $lie');
      // And only under the glass: outside the panel the screen is the grey.
      final _Diff outside = await _compare(tester, captured, lying, const Rect.fromLTWH(0, 0, 400, 200));
      expect(outside.maxDelta, 0, reason: 'an undrawn declaration reached the screen: $outside');
    }
  });

  testWidgets('a declared gradient draws what its capture draws, and the map into it is the one used', (
    WidgetTester tester,
  ) async {
    const painter = GradientProxyPainter(
      LinearGradient(colors: <Color>[Color(0xFF103080), Color(0xFFF0D040)], stops: <double>[0.3, 0.7]),
    );
    // Sigma 0 first: the texture is the screen texel for texel, so the two
    // agree to rounding. Then a blurred finish, where the declaration's blur is
    // the pipeline's arithmetic at another divisor and agrees less exactly.
    for (final (GlassFinish finish, int tolerance) in <(GlassFinish, int)>[
      (GlassFinish.clear, 2),
      (GlassFinish.regularDark, 4),
    ]) {
      final ui.Image captured = await _shot(tester, _gradientScene(painter, declared: false, finish: finish));
      final ui.Image declared = await _shot(tester, _gradientScene(painter, declared: true, finish: finish));
      final _Diff same = await _compare(tester, captured, declared, _kPanel);
      expect(same.compared, greaterThan(15000));
      expect(same.maxDelta, lessThanOrEqualTo(tolerance), reason: '${finish.name}: $same');
    }

    // The negative control of the map: the same declaration sampled 60 px off
    // has to differ, or the arm above compared two pictures that do not depend
    // on where the texture is read.
    final ui.Image captured = await _shot(tester, _gradientScene(painter, declared: false, finish: GlassFinish.clear));
    await _shot(tester, _gradientScene(painter, declared: true, finish: GlassFinish.clear));
    _surface(tester).debugSampleShift = const Offset(60, 0);
    _surface(tester).markNeedsPaint();
    await tester.pump();
    final ui.Image shifted = _grab();
    final _Diff off = await _compare(tester, captured, shifted, _kPanel);
    expect(off.maxDelta, greaterThan(20), reason: 'a shifted sample read the same pixels: $off');
  });

  testWidgets('the texture is made once per finish and size, not per frame', (WidgetTester tester) async {
    await _pump(tester, _scene(declared: true, finish: GlassFinish.regularDark));
    final GlassBackdropDeclaration declaration = _declaration(tester);
    final int first = declaration.renders;
    expect(first, 1, reason: 'one colour, one surface: one texel');
    for (var i = 0; i < 6; i++) {
      _surface(tester).markNeedsPaint();
      await tester.pump();
    }
    expect(declaration.renders, first, reason: 'a repaint re-rendered the declaration');

    // A gradient is a function of the box and the blur: resizing the box makes
    // it again, and only then.
    const painter = GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)]));
    await _pump(tester, _gradientScene(painter, declared: true, finish: GlassFinish.regularDark));
    final GlassBackdropDeclaration gradient = _declaration(tester);
    expect(gradient.renders, 1);
    for (var i = 0; i < 4; i++) {
      _surface(tester).markNeedsPaint();
      await tester.pump();
    }
    expect(gradient.renders, 1);
    await _pump(tester, _gradientScene(painter, declared: true, finish: GlassFinish.regularDark, inset: 20));
    expect(_declaration(tester).renders, 2, reason: 'a resized backdrop kept the old texture');
  });

  testWidgets('GlassBackdrop.gradient is the gradient painter by name', (WidgetTester tester) async {
    const gradient = LinearGradient(colors: <Color>[Color(0xFF103080), Color(0xFFF0D040)]);
    final ui.Image named = await _shot(
      tester,
      _wrap(
        GlassHost(
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.clear,
          child: GlassBackdrop.gradient(
            gradient,
            child: Stack(
              children: <Widget>[Positioned.fromRect(rect: _kPanel, child: const GlassSurface())],
            ),
          ),
        ),
      ),
    );
    expect(_surface(tester).paintsWithDeclaredBackdrop, greaterThan(0));
    final ui.Image painted = await _shot(
      tester,
      _gradientScene(const GradientProxyPainter(gradient), declared: true, finish: GlassFinish.clear),
    );
    expect((await _compare(tester, named, painted, const Rect.fromLTWH(0, 0, 400, 600))).maxDelta, 0);
  });

  testWidgets('a materializing surface renders a texture per blur step, not per frame', (WidgetTester tester) async {
    const painter = GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)]));
    Widget scene(double materialize) => _wrap(
      GlassHost(
        hardware: GlassHardware.appleMetal,
        finish: GlassFinish.regularDark,
        child: GlassBackdrop.painter(
          painter,
          child: Stack(
            children: <Widget>[
              Positioned.fromRect(
                rect: _kPanel,
                child: GlassSurface(materialize: materialize),
              ),
            ],
          ),
        ),
      ),
    );
    // Sixty frames of a slow materialize: the sigma moves on every one.
    for (var i = 1; i <= 60; i++) {
      await tester.pumpWidget(scene(i / 60));
    }
    final int renders = _declaration(tester).renders;
    // The finish's blur in quarter-pixel steps, plus the final one.
    final int steps = (GlassFinish.regularDark.blurSigmaLogical * 4).ceil() + 1;
    expect(renders, lessThanOrEqualTo(steps), reason: '$renders textures for $steps blur steps');
    expect(renders, greaterThan(1), reason: 'the blur never moved, so the arm measured nothing');
  });

  testWidgets('two finishes over one declaration render a texture each', (WidgetTester tester) async {
    const painter = GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)]));
    await _pump(
      tester,
      _wrap(
        GlassHost(
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.regularDark,
          child: GlassBackdrop.painter(
            painter,
            child: const Stack(
              children: <Widget>[
                Positioned(left: 20, top: 40, width: 160, height: 80, child: GlassSurface()),
                Positioned(
                  left: 20,
                  top: 200,
                  width: 160,
                  height: 80,
                  child: GlassSurface(finish: GlassFinish.clear),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(_declaration(tester).renders, 2);
    expect(_surfaces(tester).every((RenderGlassSurface s) => s.paintsWithDeclaredBackdrop > 0), isTrue);
  });

  testWidgets('GlassBackdrop.live hands its subtree back to the capture', (WidgetTester tester) async {
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _wrap(
        GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.regularDark,
          child: GlassBackdrop.color(
            _kGrey,
            child: Stack(
              children: <Widget>[
                const Positioned(left: 20, top: 40, width: 160, height: 80, child: GlassSurface()),
                Positioned(
                  left: 20,
                  top: 200,
                  width: 160,
                  height: 80,
                  child: GlassBackdrop.live(child: const GlassSurface()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final List<RenderGlassSurface> surfaces = _surfaces(tester);
    expect(surfaces[0].paintsWithDeclaredBackdrop, greaterThan(0));
    expect(surfaces[1].readsDeclaredBackdrop, isFalse);
    expect(surfaces[1].paintsWithDeclaredBackdrop, 0);
    expect((hostKey.currentState! as dynamic).recorded, greaterThan(0), reason: 'the live surface was not captured');
    // And the capture holds only the live one: the declared surface costs the
    // atlas nothing.
    expect(_handle(tester).frame!.keys, <Object>[surfaces[1]]);
    final GlassLoad load = GlassScope.maybeOf(tester.element(find.byType(GlassSurface).first))!
        .read(viewSize: kScreen, model: GlassSurfaceCostModel.adrenoCycles);
    expect(load.surfaceCount, 2);
    expect(load.capturedSurfaceCount, 1, reason: 'the ledger priced a capture for the declared surface');
  });

  testWidgets('a fused group over a declared backdrop samples it and captures nothing', (WidgetTester tester) async {
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _wrap(
        GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.regularDark,
          child: GlassBackdrop.color(
            _kGrey,
            child: const Center(
              child: GlassGroup(
                spacing: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(width: 160, height: 80, child: GlassSurface()),
                    SizedBox(height: 20),
                    SizedBox(width: 160, height: 80, child: GlassSurface()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final RenderGlassGroup group = tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup));
    expect(group.paintsWithDeclaredBackdrop, greaterThan(0), reason: 'the fused draw did not read the declaration');
    expect(group.fusedPaints, greaterThan(0));
    expect((hostKey.currentState! as dynamic).recorded, 0);
  });

  testWidgets('a texture the application holds is declared as it is, and replacing it re-renders', (
    WidgetTester tester,
  ) async {
    final ui.Image blue = _solidImage(const Color(0xFF2050C0));
    final ui.Image red = _solidImage(const Color(0xFFC02020));
    addTearDown(blue.dispose);
    addTearDown(red.dispose);
    final hostKey = GlobalKey();
    Widget scene(ui.Image image) => _wrap(
      GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        finish: GlassFinish.clear,
        child: GlassBackdrop.texture(
          image,
          child: Stack(
            children: <Widget>[Positioned.fromRect(rect: _kPanel, child: const GlassSurface())],
          ),
        ),
      ),
    );
    await _pump(tester, scene(blue));
    expect(_declaration(tester).renders, 1);
    final int blueRed = await _redAt(tester, _grab(), _kPanel.center);
    await _pump(tester, scene(red));
    expect(_declaration(tester).renders, 2, reason: 'a new texture was not rendered');
    final int redRed = await _redAt(tester, _grab(), _kPanel.center);
    expect(redRed - blueRed, greaterThan(100), reason: 'the glass still shows the old texture');
    expect((hostKey.currentState! as dynamic).recorded, 0);
  });

  testWidgets('an image that has not loaded leaves the glass on the capture until it does', (
    WidgetTester tester,
  ) async {
    late Uint8List png;
    await tester.runAsync(() async {
      final ui.Image image = _solidImage(_kGrey);
      png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
    });
    final hostKey = GlobalKey();
    final provider = MemoryImage(png);
    await tester.pumpWidget(
      _wrap(
        GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.regularDark,
          child: GlassBackdrop.image(
            provider,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: ColoredBox(color: _kGrey)),
                Positioned.fromRect(rect: _kPanel, child: const GlassSurface()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final RenderGlassSurface surface = _surface(tester);
    expect(surface.readsDeclaredBackdrop, isFalse, reason: 'declared before the image decoded');
    expect((hostKey.currentState! as dynamic).recorded, greaterThan(0), reason: 'the glass waited on nothing');

    // The decode is an engine future, so it completes only outside the fake clock.
    await tester.runAsync(() => precacheImage(provider, tester.element(find.byType(GlassSurface))));
    await tester.pump();
    await tester.pump();
    expect(surface.readsDeclaredBackdrop, isTrue);
    final int before = surface.paintsWithDeclaredBackdrop;
    surface.markNeedsPaint();
    await tester.pump();
    expect(surface.paintsWithDeclaredBackdrop, greaterThan(before));
  });

  testWidgets('glass with no declaration above it is unchanged', (WidgetTester tester) async {
    await _pump(tester, _scene(declared: false));
    final RenderGlassSurface surface = _surface(tester);
    expect(surface.readsDeclaredBackdrop, isFalse);
    expect(surface.paintsWithProxy, greaterThan(0));
    expect(surface.paintsWithDeclaredBackdrop, 0);
    expect(surface.toStringDeep(), isNot(contains('samples a GlassBackdrop')));
  });
}

Widget _wrap(Widget child) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _shotKey,
        child: SizedBox.fromSize(size: kScreen, child: child),
      ),
    ),
  ),
);

/// A grey screen with one panel on it: the grey painted by a `ColoredBox` and
/// captured, or declared (and painted by the declaration).
Widget _scene({
  Key? hostKey,
  required bool declared,
  GlassFinish finish = GlassFinish.regularDark,
  Color declaredColor = _kGrey,
  bool paintBackdrop = true,
}) {
  final Widget panel = Stack(
    children: <Widget>[
      if (!declared || !paintBackdrop) const Positioned.fill(child: ColoredBox(color: _kGrey)),
      Positioned.fromRect(rect: _kPanel, child: const GlassSurface()),
    ],
  );
  return _wrap(
    GlassHost(
      key: hostKey,
      hardware: GlassHardware.appleMetal,
      finish: finish,
      child: KeyedSubtree(
        // Fresh render objects for each arm, so no counter carries over.
        key: ValueKey<Object>((declared, finish, declaredColor, paintBackdrop)),
        child: declared ? GlassBackdrop.color(declaredColor, paintBackdrop: paintBackdrop, child: panel) : panel,
      ),
    ),
  );
}

/// The same with a gradient painted by [painter] across the screen.
Widget _gradientScene(
  GlassProxyPainter painter, {
  required bool declared,
  GlassFinish finish = GlassFinish.regularDark,
  double inset = 0,
}) {
  final Widget panel = Stack(
    children: <Widget>[Positioned.fromRect(rect: _kPanel.translate(-inset, -inset), child: const GlassSurface())],
  );
  return _wrap(
    GlassHost(
      hardware: GlassHardware.appleMetal,
      finish: finish,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: KeyedSubtree(
          key: ValueKey<Object>((declared, finish)),
          child: declared
              ? GlassBackdrop.painter(painter, child: panel)
              : CustomPaint(painter: _Adapter(painter), child: panel),
        ),
      ),
    ),
  );
}

class _Adapter extends CustomPainter {
  const _Adapter(this.painter);

  final GlassProxyPainter painter;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, size);

  @override
  bool shouldRepaint(_Adapter oldDelegate) => false;
}

Future<void> _pump(WidgetTester tester, Widget scene, {int frames = 4}) async {
  await tester.pumpWidget(scene);
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<ui.Image> _shot(WidgetTester tester, Widget scene) async {
  await _pump(tester, scene);
  return _grab();
}

ui.Image _grab() {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

ui.Image _solidImage(Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = color);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(8, 8);
  picture.dispose();
  return image;
}

List<RenderGlassSurface> _surfaces(WidgetTester tester) =>
    tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface)).toList();

RenderGlassSurface _surface(WidgetTester tester) => _surfaces(tester).single;

GlassProxyHandle _handle(WidgetTester tester) =>
    GlassProxyScope.maybeOf(tester.element(find.byType(GlassSurface).first))!;

GlassBackdropDeclaration _declaration(WidgetTester tester) =>
    GlassBackdrop.maybeOf(tester.element(find.byType(GlassSurface).first))!;

Future<int> _redAt(WidgetTester tester, ui.Image image, Offset at) async {
  late int value;
  await tester.runAsync(() async {
    final Uint8List px = (await image.toByteData())!.buffer.asUint8List();
    value = px[(at.dy.round() * image.width + at.dx.round()) * 4];
  });
  return value;
}

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.compared);

  final int maxDelta;
  final int differing;

  /// How many pixels were compared: an arm that compared none would report no
  /// difference.
  final int compared;

  @override
  String toString() => '$differing/$compared px differ, worst $maxDelta';
}

/// The worst channel difference between [a] and [b] inside [region].
Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b, Rect region) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  late _Diff diff;
  await tester.runAsync(() async {
    final Uint8List pa = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List pb = (await b.toByteData())!.buffer.asUint8List();
    var maxDelta = 0;
    var differing = 0;
    var compared = 0;
    for (var y = region.top.floor(); y < region.bottom.ceil(); y++) {
      for (var x = region.left.floor(); x < region.right.ceil(); x++) {
        final int i = (y * a.width + x) * 4;
        compared++;
        var worst = 0;
        for (var c = 0; c < 4; c++) {
          final int d = (pa[i + c] - pb[i + c]).abs();
          if (d > worst) {
            worst = d;
          }
        }
        if (worst > 0) {
          differing++;
          if (worst > maxDelta) {
            maxDelta = worst;
          }
        }
      }
    }
    diff = _Diff(maxDelta, differing, compared);
  });
  return diff;
}
