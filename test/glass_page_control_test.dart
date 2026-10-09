// GlassPageControl: the dots, a tap and a scrub, a page controller, what a
// screen reader is told, and what turning a page costs.
//
// `flutter test test/glass_page_control_test.dart`
//
//  1. **A tap moves one page toward the side tapped; a scrub follows the
//     finger; the ends hold.**
//  2. **A controller drives it both ways:** a swipe of the page view moves
//     the dots and reports the page; a tap on the control turns the view.
//  3. **Semantics: one adjustable node,** "Page n of m", whose increase and
//     decrease turn the page and vanish at the ends.
//  4. **The current dot is wider and brighter** — pixels: lit where the
//     current dot is and not where a resting dot's gap would be.
//  5. **One surface, and turning a page is no capture and repaints nothing
//     under the glass.** Controls: the same host records a repainted
//     backdrop, and the arm checks the dots did move (by pixels) — a zero
//     over dots that never moved would say nothing.
//  6. **Following a page view adds no capture to the view's own:** the same
//     swipe costs the same captures with the control following it and with a
//     display whose dots stay put (43 and 43 here) — the swipe itself is the
//     page view's price.
//
// Breaks, each undone by swapping the string back:
//  - in `glass_page_control.dart`, `super(repaint: repaint);` ->
//    `super(repaint: null);`: arm 5's dots never move between frames (207 ->
//    207) and arm 2's swipe leaves them where they were (72 -> 72);
//  - `_goTo(_page + (x < current ? -1 : 1));` -> `_goTo(_page + 1);`: arm 1's
//    left tap goes right.

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'component_scene.dart';

/// The capsule's width for [count] dots at the default current width.
double _width(int count) => 2 * 10 + (count - 1) * (kGlassPageDot + kGlassPageDotGap) + 20;

/// The resting centre of dot [i] with [current] the current page, in the
/// capsule's coordinates.
double _dotX(int i, int current) {
  var x = 10.0;
  for (var j = 0; j < i; j++) {
    x += (j == current ? 20 : kGlassPageDot) + kGlassPageDotGap;
  }
  return x + (i == current ? 10 : kGlassPageDot / 2);
}

/// How far the pixel at [x] along the capsule's middle stands from the glass
/// above it, at the same x: the dots' ink, whichever way the label colour
/// points — dark dots are darker than the glass, light ones lighter.
double _ink(Uint8List px, Rect box, double x) =>
    (meanAt(px, Offset(box.left + x, box.center.dy), side: 1) - meanAt(px, Offset(box.left + x, box.top + 3), side: 1))
        .abs();

void main() {
  testWidgets('a tap moves one page toward its side, a scrub follows the finger, the ends hold', (
    WidgetTester tester,
  ) async {
    final pages = <int>[];
    var page = 2;
    Widget control() => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => GlassPageControl(
        count: 5,
        currentPage: page,
        onPageChanged: (int p) {
          pages.add(p);
          setState(() => page = p);
        },
      ),
    );
    final ComponentScene scene = await ComponentScene.mount(tester, control());
    final Rect box = tester.getRect(find.byType(GlassSurface));
    expect(box.width, _width(5));
    expect(box.height, kGlassPageControlHeight);
    expect(tester.getSize(find.byType(GlassPageControl)).height, greaterThanOrEqualTo(kGlassMinTapTarget.height));

    await tester.tapAt(box.centerLeft + const Offset(4, 0));
    await scene.frames(30);
    expect(pages, <int>[1], reason: 'a tap left of the current dot did not go back one');
    await tester.tapAt(box.centerRight - const Offset(4, 0));
    await scene.frames(30);
    expect(pages, <int>[1, 2], reason: 'a tap right of the current dot did not go on one');

    // A scrub from the first dot to the last asks for each page on the way.
    pages.clear();
    final Offset start = Offset(box.left + _dotX(0, page), box.center.dy);
    final TestGesture finger = await tester.startGesture(start);
    for (var i = 1; i <= 20; i++) {
      await finger.moveTo(start + Offset((box.width - 20) * i / 20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await scene.frames(30);
    // ignore: avoid_print
    print('scrub: $pages');
    expect(pages, <int>[1, 2, 3, 4], reason: 'a scrub skipped or repeated a page');
    expect(pages.toSet().length, pages.length, reason: 'a scrub asked for one page twice in a row');

    // At the end, a tap toward it does nothing.
    pages.clear();
    await tester.tapAt(box.centerRight - const Offset(4, 0));
    await scene.frames(30);
    expect(pages, isEmpty, reason: 'a tap past the last page reported one');

    // Without a callback or a controller it is a display: taps go nowhere.
    await scene.pump(const GlassPageControl(count: 3, currentPage: 1));
    await tester.tapAt(tester.getRect(find.byType(GlassSurface)).centerRight - const Offset(4, 0));
    await scene.frames(5);
    expect(pages, isEmpty);
  });

  testWidgets('a controller: a swipe moves the dots and reports the page; a tap turns the view', (
    WidgetTester tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    final pages = <int>[];
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 300,
            height: 120,
            child: PageView(
              controller: controller,
              children: <Widget>[for (var i = 0; i < 4; i++) ColoredBox(color: Color(0xFF203040 + i * 0x101010))],
            ),
          ),
          GlassPageControl(count: 4, controller: controller, onPageChanged: pages.add),
        ],
      ),
    );
    final Rect box = tester.getRect(find.byType(GlassSurface));
    final Uint8List before = await scene.pixels();

    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
    await scene.frames(60);
    expect(controller.page, 1);
    expect(pages, <int>[1], reason: 'the swipe reported no page, or more than one');
    final Uint8List after = await scene.pixels();
    final double secondBefore = _ink(before, box, _dotX(1, 1) + 7);
    final double secondAfter = _ink(after, box, _dotX(1, 1) + 7);
    // ignore: avoid_print
    print('the second dot\'s far end: ink $secondBefore before the swipe, $secondAfter after');
    expect(secondAfter - secondBefore, greaterThan(20), reason: 'the dots did not follow the swipe');

    await tester.tapAt(box.centerRight - const Offset(4, 0));
    await scene.frames(60);
    expect(controller.page, 2, reason: 'a tap on the control did not turn the view');
    expect(pages, <int>[1, 2]);
  });

  testWidgets('semantics: "Page n of m", and actions that turn it and stop at the ends', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var page = 0;
    await ComponentScene.mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => GlassPageControl(
          count: 3,
          currentPage: page,
          semanticLabel: 'Photos',
          onPageChanged: (int p) => setState(() => page = p),
        ),
      ),
    );
    final Finder control = find.byType(GlassPageControl);
    expect(
      tester.getSemantics(control),
      matchesSemantics(label: 'Photos', value: 'Page 1 of 3', increasedValue: 'Page 2 of 3', hasIncreaseAction: true),
    );
    tester.semantics.increase(find.semantics.byLabel('Photos'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(page, 1);
    expect(
      tester.getSemantics(control),
      matchesSemantics(
        label: 'Photos',
        value: 'Page 2 of 3',
        increasedValue: 'Page 3 of 3',
        decreasedValue: 'Page 1 of 3',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    // A display offers nothing to do.
    await tester.pumpWidget(const SizedBox());
    await ComponentScene.mount(
      tester,
      GlassPageControl(count: 3, currentPage: 2, semanticFormatterCallback: (int p, int n) => '${p + 1}/$n'),
    );
    expect(tester.getSemantics(find.byType(GlassPageControl)), matchesSemantics(value: '3/3'));
    handle.dispose();
  });

  testWidgets('the current dot is wider and brighter than the rest', (WidgetTester tester) async {
    final ComponentScene scene = await ComponentScene.mount(tester, const GlassPageControl(count: 4, currentPage: 1));
    final Rect box = tester.getRect(find.byType(GlassSurface));
    final Uint8List px = await scene.pixels();
    double at(double x) => _ink(px, box, x);
    // The current dot's far end: 7 px right of its centre, which on a resting
    // dot is already the gap.
    final double currentEdge = at(_dotX(1, 1) + 7);
    final double restingEdge = at(_dotX(0, 1) + 7);
    final double currentCentre = at(_dotX(1, 1));
    final double restingCentre = at(_dotX(0, 1));
    // ignore: avoid_print
    print('current: centre $currentCentre, +7 $currentEdge; resting: centre $restingCentre, +7 $restingEdge');
    expect(currentCentre - restingCentre, greaterThan(20), reason: 'the current dot is not brighter');
    expect(currentEdge - restingEdge, greaterThan(20), reason: 'the current dot is not wider');
  });

  testWidgets('one surface; turning a page captures nothing and repaints nothing under the glass', (
    WidgetTester tester,
  ) async {
    var page = 0;
    late StateSetter set;
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          set = setState;
          return GlassPageControl(count: 5, currentPage: page, onPageChanged: (int p) => setState(() => page = p));
        },
      ),
    );
    expect(scene.surfaces, 1);
    expect(scene.load.surfaceCount, 1);
    final Rect box = tester.getRect(find.byType(GlassSurface));

    final int recorded = scene.recorded;
    final int painted = scene.paints.value;
    final double lit = _ink(await scene.pixels(), box, _dotX(0, 0));
    set(() => page = 3);
    await scene.frames(3);
    final double moving = _ink(await scene.pixels(), box, _dotX(0, 0));
    await scene.frames(30);
    await tester.tapAt(box.centerLeft + const Offset(4, 0));
    await scene.frames(30);
    final int captures = scene.recorded - recorded;
    final int paints = scene.paints.value - painted;
    // ignore: avoid_print
    print('first dot $lit -> $moving mid-turn; page $page; captures $captures, backdrop paints $paints');
    expect(lit - moving, greaterThan(5), reason: 'the dots did not move, so the arm measured nothing');
    expect(page, 2);
    expect(captures, 0, reason: 'turning a page took a capture');
    expect(paints, 0, reason: 'turning a page repainted what is under the glass');

    final int control = await scene.repaintBackdrop();
    expect(control, greaterThan(0), reason: 'the capture counter cannot move on this mount');
  });

  testWidgets('following a page view adds no capture to what the page view itself costs', (
    WidgetTester tester,
  ) async {
    // The swipe is content changing in the host, and the host retakes for it
    // whether or not any dot moves: that is the page view's price. What the
    // control may not do is add to it. So the same swipe is run twice, with
    // the control following the view and with the same surface as a display
    // whose dots never move — and the counts must agree. The first count
    // being far from zero is the arm's own control: a counter that cannot
    // move would agree at zero.
    Future<(int, double)> swipe({required bool following}) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final ComponentScene scene = await ComponentScene.mount(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 300,
              height: 120,
              child: PageView(
                controller: controller,
                children: <Widget>[for (var i = 0; i < 4; i++) ColoredBox(color: Color(0xFF203040 + i * 0x101010))],
              ),
            ),
            if (following) GlassPageControl(count: 4, controller: controller) else const GlassPageControl(count: 4),
          ],
        ),
      );
      final Rect box = tester.getRect(find.byType(GlassSurface));
      final Uint8List before = await scene.pixels();
      final int recorded = scene.recorded;
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await scene.frames(60);
      final int captures = scene.recorded - recorded;
      final double moved = _ink(await scene.pixels(), box, _dotX(1, 1) + 7) - _ink(before, box, _dotX(1, 1) + 7);
      await tester.pumpWidget(const SizedBox());
      return (captures, moved);
    }

    final (int following, double followed) = await swipe(following: true);
    final (int display, double still) = await swipe(following: false);
    // ignore: avoid_print
    print('a swipe: $following captures following the view (dots moved $followed), $display as a display ($still)');
    expect(followed, greaterThan(20), reason: 'the following control did not follow');
    expect(still, 0, reason: 'the display moved');
    expect(display, greaterThan(0), reason: 'the swipe cost nothing, so agreement would say nothing');
    expect(following, display, reason: 'following the view cost captures of its own');
  });

  test('debugFillProperties', () {
    final builder = DiagnosticPropertiesBuilder();
    const GlassPageControl(count: 4, currentPage: 2).debugFillProperties(builder);
    final List<String> said = builder.properties
        .where((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode n) => n.toString())
        .toList();
    expect(said, containsAll(<String>['count: 4', 'currentPage: 2', 'display']));
  });
}
