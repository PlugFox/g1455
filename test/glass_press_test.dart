// A pressed button swells and leans toward a dragging finger, and what that
// costs the capture: the region's coming and going, and nothing while it moves.
//
// `flutter test test/glass_press_test.dart`
//
// The claim is about the capture and the content, because that is what a
// press could cost everyone else: the glass changes its size on every frame of
// the spring, and a glass whose box changes is retaken unless it moves inside
// a declared region — and a relayout that climbed past the glass would
// repaint the boundary the screen's content is in, which the layer watch
// calls a change under the glass.
//
// The negative control for the capture is an arm: `debugGlassPressTravel`
// off builds the same press without its region, and the count moves. The
// region is declared from touch-down until the spring settles, which is two
// captures a press; the arm declared always is the zero they are counted
// against. The two
// for the boundary are breaks, each undone by swapping the string back:
//  - in `RenderGlassPressBody`, `bool get isRepaintBoundary => true;` ->
//    `=> false;`: every frame of the press repaints the screen's boundary, and
//    the content arm counts the painter beside the button repainting;
//  - in `RenderGlassPressBody.markNeedsLayout`, `if (!_forPress && parent !=
//    null)` -> `if (false)`: a label that grows under a boundary laid out
//    tight never reaches the stage that measures it, and the relabel arm's
//    button keeps its old width.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/surface/glass_press.dart'
    show RenderGlassPressBody, debugGlassPressRegionAtRest, debugGlassPressTravel;

const Size kScreen = Size(400, 400);

void main() {
  group('the geometry', () {
    const press = GlassPress();
    const sizes = <Size>[Size(44, 44), Size(132, 44), Size(320, 48), Size(44, 160)];

    test('at rest it is the box; held, the longest side is [grow] longer', () {
      for (final Size rest in sizes) {
        expect(press.rect(rest, 0, Offset.zero), Offset.zero & rest);
        final Rect held = press.rect(rest, 1, Offset.zero);
        expect(held.size.longestSide - rest.longestSide, closeTo(press.grow, 1e-9));
        expect(held.size.aspectRatio, closeTo(rest.aspectRatio, 1e-9), reason: 'not a uniform growth');
        expect((held.center - rest.center(Offset.zero)).distance, lessThan(1e-9));
      }
      // The hypothesis' two readings, for scale: 1.27x a 44 circle, 1.09x a
      // 132 pill, where the package that proposed the law has 1.3x and 1.13x.
      expect(press.rect(const Size(44, 44), 1, Offset.zero).width / 44, closeTo(1.27, 0.01));
      expect(press.rect(const Size(132, 44), 1, Offset.zero).width / 132, closeTo(1.09, 0.01));
    });

    test('dragged, it leans toward the finger, stretched along and squashed across, area kept', () {
      const rest = Size(132, 44);
      final Rect held = press.rect(rest, 1, Offset.zero);
      for (final Offset finger in const <Offset>[Offset(30, 0), Offset(-30, 0), Offset(0, 30), Offset(0, -30)]) {
        final Rect r = press.rect(rest, 1, finger);
        final Offset lean = r.center - held.center;
        expect(math.cos(lean.direction - finger.direction), closeTo(1, 1e-9), reason: '$finger: not toward it');
        expect(lean.distance, lessThanOrEqualTo(press.maxPull));
        expect(lean.distance, greaterThan(press.maxPull * 0.9), reason: '$finger: past the reach, nearly all of it');
        final bool across = finger.dx != 0;
        final double along = across ? r.width / held.width : r.height / held.height;
        expect(along, greaterThan(1.04), reason: '$finger: not stretched along the drag');
        expect(along, lessThanOrEqualTo(1 + press.maxStretch));
        expect(r.width * r.height, closeTo(held.width * held.height, 1e-6), reason: '$finger: area not kept');
      }
    });

    test('it never leaves the margin, and the check could see it if it did', () {
      // Every press the spring can reach, every direction, short and long
      // drags. The control: the same sweep against a margin without the lean
      // finds glass outside it — so "never" is a statement about the margin,
      // not about a sweep too gentle to reach it.
      var checked = 0;
      var escapedWithoutLean = 0;
      for (final Size rest in sizes) {
        final Size m = press.margin(rest);
        final Rect region = Rect.fromLTRB(-m.width, -m.height, rest.width + m.width, rest.height + m.height);
        final Rect leanless = region.deflate(press.maxPull);
        for (var p = 1 - GlassPress.maxOvershoot; p <= GlassPress.maxOvershoot + 1e-9; p += 0.05) {
          for (var a = 0; a < 16; a++) {
            for (final double d in const <double>[0, 4, 12, 40, 400]) {
              final Rect r = press.rect(rest, p, Offset.fromDirection(a * math.pi / 8, d));
              checked++;
              expect(region.expandToInclude(r), region, reason: '$rest at $p, $d px: $r outside $region');
              if (leanless.expandToInclude(r) != leanless) {
                escapedWithoutLean++;
              }
            }
          }
        }
      }
      expect(checked, greaterThan(1000));
      expect(escapedWithoutLean, greaterThan(0), reason: 'the sweep never reaches the edge of the margin');
      // And the two numbers the documentation quotes.
      expect(press.margin(const Size(44, 44)).width, closeTo(12.3, 0.05));
      expect(press.margin(const Size(132, 44)).width, closeTo(14.5, 0.05));
      expect(press.margin(const Size(132, 44)).height, closeTo(7.5, 0.05));
    });

    test('none is the box, at every press', () {
      expect(GlassPress.none.isNone, isTrue);
      expect(GlassPress.none.margin(const Size(44, 44)), Size.zero);
      expect(GlassPress.none.rect(const Size(44, 44), 1, const Offset(30, 0)), Offset.zero & const Size(44, 44));
    });
  });

  testWidgets('held, the glass grows and leans; dragged and let go, it costs two captures and repaints nothing', (
    WidgetTester tester,
  ) async {
    // Three arms: the region declared from touch-down until the settle (the
    // default), declared always, and never.
    final Map<String, int> captures = <String, int>{};
    for (final String arm in <String>['on demand', 'always', 'never']) {
      final bool travel = arm != 'never';
      debugGlassPressTravel = travel;
      debugGlassPressRegionAtRest = arm == 'always';
      addTearDown(() {
        debugGlassPressTravel = true;
        debugGlassPressRegionAtRest = false;
      });
      final hostKey = GlobalKey();
      final paints = _Counter();
      await _mount(tester, hostKey, _Screen(paints: paints));
      final dynamic host = hostKey.currentState! as dynamic;
      final RenderGlassSurface glass = _glass(tester);
      final Rect rest = glass.globalRect;
      final Rect box = tester.getRect(find.byType(GlassButton));
      final int before = host.recorded as int;
      final int paintsBefore = paints.value;
      final RenderGlassPressBody body = tester.allRenderObjects.whereType<RenderGlassPressBody>().single;
      final int layoutsBefore = body.pressLayouts;

      final TestGesture gesture = await tester.startGesture(rest.center);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final Rect held = glass.globalRect;
      if (travel) {
        expect(held.width - rest.width, closeTo(const GlassPress().grow, 0.01), reason: 'the glass did not grow');
        expect(held.center, rest.center, reason: 'held still, the glass moved');
      }
      // Under the touch slop, so the tap holds: toward the right.
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final Rect leaning = glass.globalRect;
      if (travel) {
        expect(leaning.center.dx - held.center.dx, greaterThan(1), reason: 'the glass did not lean to the finger');
        expect(leaning.width / leaning.height, greaterThan(held.width / held.height), reason: 'not stretched');
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(glass.globalRect.size, rest.size, reason: 'the glass did not spring back');
      expect(tester.getRect(find.byType(GlassButton)), box, reason: 'the button\'s layout moved');
      final int taken = captures[arm] = (host.recorded as int) - before;
      if (travel) {
        expect(body.pressLayouts - layoutsBefore, greaterThan(30), reason: 'the press was not laid out by the body');
        // A capture paints the content once, into the proxy; anything past
        // that is a repaint the press caused.
        expect(paints.value - paintsBefore, taken, reason: '$arm: the press repainted the content beside it');
      }
    }
    // ignore: avoid_print
    print('captures across a press: $captures');
    expect(
      captures['never'],
      greaterThan(10),
      reason: 'without the region the press was not retaken: the arm is blind',
    );
    expect(captures['always'], 0, reason: 'a region declared throughout retook the proxy');
    // One as the region appears at touch-down, one as it goes at the settle;
    // `glass_press_region_test.dart` has what that buys at rest.
    expect(captures['on demand'], 2, reason: 'the press retook more than its region\'s coming and going');
  });

  testWidgets('a label that changes under the boundary still resizes the button', (WidgetTester tester) async {
    final label = ValueNotifier<String>('Go');
    addTearDown(label.dispose);
    await _mount(tester, GlobalKey(), _Screen(paints: _Counter(), label: label));
    final double narrow = tester.getSize(find.byType(GlassButton)).width;
    final double glassNarrow = _glass(tester).size.width;
    label.value = 'Go somewhere far';
    await tester.pump();
    final double wide = tester.getSize(find.byType(GlassButton)).width;
    expect(wide, greaterThan(narrow + 40), reason: 'the button kept the width of its old label');
    expect(_glass(tester).size.width, wide, reason: 'the glass kept the width of its old label');
    expect(glassNarrow, narrow);
  });

  testWidgets('with none, or under reduced motion, the glass keeps its box and no region is built', (
    WidgetTester tester,
  ) async {
    for (final (GlassPress? press, bool reduced) in <(GlassPress?, bool)>[
      (GlassPress.none, false),
      (null, true),
    ]) {
      await _mount(
        tester,
        GlobalKey(),
        _Screen(paints: _Counter(), press: press),
        reducedMotion: reduced,
      );
      expect(tester.allRenderObjects.whereType<RenderGlassPressBody>(), isEmpty, reason: '$press, $reduced: built');
      final Rect rest = _glass(tester).globalRect;
      final TestGesture gesture = await tester.startGesture(rest.center);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_glass(tester).globalRect, rest, reason: '$press, reduced $reduced: the glass moved');
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the theme carries the press, and a button may name its own', (WidgetTester tester) async {
    expect(const GlassThemeData().press, const GlassPress());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(
          press: const GlassPress(grow: 20),
          child: Center(
            child: GlassButton(onPressed: () {}, child: const SizedBox(width: 40, height: 20)),
          ),
        ),
      ),
    );
    final Rect rest = _glass(tester).globalRect;
    final TestGesture gesture = await tester.startGesture(rest.center);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_glass(tester).globalRect.width - rest.width, closeTo(20, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

class _Counter {
  int value = 0;
}

class _Screen extends StatelessWidget {
  const _Screen({required this.paints, this.label, this.press});

  final _Counter paints;
  final ValueNotifier<String>? label;
  final GlassPress? press;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: kScreen,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
        ),
        // A panel of the screen's own, so there is a capture to keep.
        const Positioned(left: 20, top: 20, width: 200, height: 60, child: GlassSurface()),
        // Content in the boundary the button is in: what a relayout that
        // climbed past the press's own boundary would repaint.
        Positioned(left: 10, top: 300, width: 20, height: 20, child: CustomPaint(painter: _Probe(paints))),
        Positioned(
          left: 100,
          top: 160,
          child: label == null
              ? GlassButton(
                  onPressed: () {},
                  press: press,
                  child: const SizedBox(width: 92, height: 24),
                )
              : ValueListenableBuilder<String>(
                  valueListenable: label!,
                  builder: (BuildContext context, String text, Widget? _) => GlassButton(
                    onPressed: () {},
                    child: Text(text, style: const TextStyle(fontSize: 14)),
                  ),
                ),
        ),
      ],
    ),
  );
}

Future<void> _mount(WidgetTester tester, GlobalKey hostKey, Widget screen, {bool reducedMotion = false}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: kScreen, devicePixelRatio: 2, disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: hostKey,
            hardware: GlassHardware.appleMetal,
            child: RepaintBoundary(child: screen),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// The button's glass: the one surface that is not the screen's panel.
RenderGlassSurface _glass(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.globalRect.top > 100);

class _Probe extends CustomPainter {
  _Probe(this.paints);

  final _Counter paints;

  @override
  void paint(Canvas canvas, Size size) {
    paints.value++;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF808080));
  }

  @override
  bool shouldRepaint(_Probe oldDelegate) => false;
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
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
