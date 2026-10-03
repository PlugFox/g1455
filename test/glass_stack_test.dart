// Glass on glass — a lens on a tab bar, a drop on a card.
//
// `flutter test test/glass/glass_stack_test.dart`
//
// The capture skips every glass subtree (the self-capture rule), so a glass
// written inside another one used to sample the screen *under both*: the bar's
// tint and its icons were simply not there through the lens. The host now
// records levels bottom up, and a level's walk draws the glass below it through
// that glass's own published frame (`RenderGlassSurface._paintIntoProxy`).
//
// The arm is the identity again, one level up: an identity lens inside a tinted
// bar must be invisible — the frame with the lens is the frame without it. The
// bar is tinted rather than identity so that "the lens sees the bar's glass" and
// "the lens sees the backdrop" are different pictures; the icon under the lens
// is there so that "the lens sees the bar's content" is too.
//
// Breaks, each undone by swapping the string back:
//  - `levels.policy(child, level)` -> `skipGlassSurfaces(child)` in
//    `GlassHost._captureUpper`: the lens reads a capture without the bar, the
//    identity arm fails;
//  - `levels.bears(surface)` -> `false` in `_noteCompositedChanges`: the bar's
//    whole subtree is excluded from the watch again, and the changed icon under
//    the lens is held over;
//  - the same swap fails the resized arm: a bar resized inside its declared
//    travel changes no capture rect, and what sees it is the watch over the
//    bar's content. (Watching the bar's actual rect as well was tried and
//    broke nothing when removed, D218.)

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 300);
final GlobalKey _shotKey = GlobalKey();

const GlassFinish _tinted = GlassFinish(
  name: 'identity',
  blurSigmaLogical: 0,
  tint: Color.fromRGBO(255, 40, 0, 0.5),
  rim: Color.fromRGBO(0, 0, 0, 0),
  optics: GlassOptics.none,
);

void main() {
  _resizedArm();
  testWidgets('an identity lens on a tinted bar shows the bar and its icon', (
    WidgetTester tester,
  ) async {
    final Uint8List without = await _shot(tester, const _Scene(lens: false));
    final Uint8List withLens = await _shot(tester, const _Scene(lens: true));
    final GlassProxyHandle handle = _handle(tester);
    final RenderGlassSurface lens = _lens(tester);
    final RenderGlassSurface bar = _bar(tester);
    final (:int differing, :int worst) = _diff(without, withLens);
    // ignore: avoid_print
    print(
      'lens: differing $differing, worst $worst; upper levels ${handle.upper.length}, '
      'bar drawn into the proxy ${bar.paintsIntoProxy}',
    );
    expect(handle.upper, hasLength(1), reason: 'the lens is not a level of its own');
    expect(handle.upper.single!.keys, contains(lens));
    expect(handle.frame!.keys, isNot(contains(lens)));
    expect(bar.paintsIntoProxy, greaterThan(0), reason: 'the bar never drew into the capture');
    expect(lens.paintsWithProxy, greaterThan(0), reason: 'the lens never drew at all');
    expect(differing, 0, reason: 'the lens shows something other than the bar under it');

    // The control: the same lens sampling twelve pixels to the side must be
    // visible, or the arm above compared two frames in which the lens drew
    // nothing.
    lens
      ..debugSampleShift = const Offset(12, 0)
      ..markNeedsPaint();
    await tester.pump();
    final ({int differing, int worst}) shifted = _diff(without, await _pixels(tester));
    expect(shifted.differing, greaterThan(500), reason: 'a shifted lens changed nothing');
  });

  testWidgets('a screen with no glass on glass records one level, as before', (
    WidgetTester tester,
  ) async {
    await _shot(tester, const _Scene(lens: true, beside: true));
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.upper, isEmpty);
    expect(_bar(tester).paintsIntoProxy, 0);
    expect(handle.frame!.keys, contains(_lens(tester)));
  });

  testWidgets('a change under the lens, inside the bar, is seen', (WidgetTester tester) async {
    // Under the default declaration the host holds until the layer watch sees
    // a change, and the watch used to skip the bar's whole subtree — right
    // while nothing stood on the bar, because nothing in it was in any proxy.
    // The icon is now in the lens's.
    final colour = ValueNotifier<Color>(const Color(0xFF00C853));
    await _pump(tester, _Scene(lens: true, icon: colour), frames: 6);
    final GlassProxyHandle handle = _handle(tester);
    final int before = handle.generation;
    colour.value = const Color(0xFF2962FF);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final Uint8List live = await _pixels(tester);
    final Uint8List fresh = await _shot(
      tester,
      _Scene(lens: true, icon: ValueNotifier<Color>(const Color(0xFF2962FF))),
    );
    final (:int differing, :int worst) = _diff(live, fresh);
    // ignore: avoid_print
    print('icon changed: generations ${handle.generation - before}, differing $differing');
    expect(handle.generation - before, greaterThan(0), reason: 'the change was held over');
    expect(differing, 0, reason: 'the lens still shows the old icon');
    colour.dispose();
  });
}

void _resizedArm() {
  testWidgets('a bar resized under the lens inside its travel is seen', (WidgetTester tester) async {
    // The bar's capture is its travel region, which does not move, and the
    // layer watch excludes its draw. What sees the bottom edge rising through
    // the lens is the watch over what the bar bears.
    // Declared, so the host holds until something says otherwise: the
    // identity finish has no damage table, its ceiling is zero, and an
    // undeclared host would record every frame whether or not it saw this.
    const GlassContentDeclaration declared = GlassContentDeclaration.declared;
    final height = ValueNotifier<double>(100);
    await _pump(tester, _Scene(lens: true, barHeight: height), frames: 6, content: declared);
    final GlassProxyHandle handle = _handle(tester);
    final int before = handle.generation;
    height.value = 70;
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final Uint8List live = await _pixels(tester);
    final Uint8List fresh = await _shot(
      tester,
      _Scene(lens: true, barHeight: ValueNotifier<double>(70)),
      content: declared,
    );
    final (:int differing, :int worst) = _diff(live, fresh);
    // ignore: avoid_print
    print('bar resized: generations ${handle.generation - before}, differing $differing, worst $worst');
    expect(handle.generation - before, greaterThan(0), reason: 'the resize was held over');
    expect(differing, 0, reason: 'the lens still shows the taller bar');
    height.dispose();
  });
}

class _Scene extends StatelessWidget {
  const _Scene({required this.lens, this.beside = false, this.icon, this.barHeight});

  /// The bar's height, inside a `GlassTravel` of its tallest: only its bottom
  /// edge moves, and the lens is over that edge.
  final ValueNotifier<double>? barHeight;

  final bool lens;

  /// The lens as the bar's sibling rather than its child: one level.
  final bool beside;

  final ValueNotifier<Color>? icon;

  @override
  Widget build(BuildContext context) {
    // With a resizable bar, the lens hangs past its bottom in both states, as
    // a tab bar's drop does — a lens that only starts to overhang mid-arm
    // adds a clip layer, and the watch sees that rather than the resize.
    final lensBox = barHeight == null
        ? (left: 30.0, top: 20.0, width: 90.0, height: 60.0)
        : (left: 30.0, top: 50.0, width: 90.0, height: 60.0);
    final Widget lensSurface = const GlassSurface(
      key: ValueKey<String>('lens'),
      borderRadius: BorderRadius.all(Radius.circular(24)),
    );
    final Widget iconBox = RepaintBoundary(
      child: icon == null
          ? const ColoredBox(color: Color(0xFF00C853))
          : ValueListenableBuilder<Color>(
              valueListenable: icon!,
              builder: (BuildContext context, Color c, Widget? _) => ColoredBox(color: c),
            ),
    );
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
            ),
            Positioned(
              left: 20,
              top: 120,
              width: 360,
              height: 100,
              child: _resizable(
                GlassSurface(
                  key: const ValueKey<String>('bar'),
                  finish: _tinted,
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  child: Stack(
                    children: <Widget>[
                      Positioned(left: 50, top: 30, width: 40, height: 40, child: iconBox),
                      if (lens && !beside)
                        Positioned(
                          left: lensBox.left,
                          top: lensBox.top,
                          width: lensBox.width,
                          height: lensBox.height,
                          child: lensSurface,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (lens && beside) Positioned(left: 40, top: 20, width: 90, height: 60, child: lensSurface),
          ],
        ),
      ),
    );
  }
}

extension on _Scene {
  /// The bar as it is, or — with [barHeight] — inside a travel region of its
  /// full box, top-aligned at the notifier's height, behind a boundary so its
  /// relayout repaints nothing else.
  Widget _resizable(Widget bar) {
    final ValueNotifier<double>? height = barHeight;
    if (height == null) {
      return bar;
    }
    return RepaintBoundary(
      child: GlassTravel(
        child: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (BuildContext context, double h, Widget? child) => SizedBox(height: h, child: child),
            child: bar,
          ),
        ),
      ),
    );
  }
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 4),
        Paint()..color = Color.fromARGB(255, 30 + (y.toInt() * 3 % 210), 120, 210 - (y.toInt() % 160)),
      );
    }
    for (var x = 0.0; x < size.width; x += 17) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, size.height), Paint()..color = const Color(0x66FFFFFF));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

RenderGlassSurface _lens(WidgetTester tester) => tester.renderObject(find.byKey(const ValueKey<String>('lens')));

RenderGlassSurface _bar(WidgetTester tester) => tester.renderObject(find.byKey(const ValueKey<String>('bar')));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int frames = 4,
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      // dpr 1 and a finish with no blur: the proxy is recorded 1:1, which is
      // what makes the identity exact rather than a resampling.
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: UniqueKey(),
            hardware: GlassHardware.appleMetal,
            finish: GlassFinish.identity,
            content: content,
            child: child,
          ),
        ),
      ),
    ),
  );
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<Uint8List> _shot(
  WidgetTester tester,
  Widget child, {
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
}) async {
  await _pump(tester, child, frames: 5, content: content);
  return _pixels(tester);
}

Future<Uint8List> _pixels(WidgetTester tester) async {
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

({int differing, int worst}) _diff(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  expect(a.length, greaterThan(1000));
  var differing = 0;
  var worst = 0;
  for (var i = 0; i < a.length; i += 4) {
    var d = 0;
    for (var c = 0; c < 4; c++) {
      final int e = (a[i + c] - b[i + c]).abs();
      if (e > d) {
        d = e;
      }
    }
    if (d > 0) {
      differing++;
      if (d > worst) {
        worst = d;
      }
    }
  }
  return (differing: differing, worst: worst);
}
