// The controls under `TextDirection.rtl`: mirrored, as iOS mirrors them.
//
// `flutter test test/glass_rtl_test.dart`
//
// Each arm runs both directions and compares them, so a control that ignores
// the direction fails by agreeing with itself: the left-to-right arm is the
// control for the right-to-left one.
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassSwitchState`, `double _visual(double position) => _rtl ? 1 -
//    position : position;` -> `=> position;`: the switch's knob arm fails;
//  - in `_GlassSegmentedControlState`, `int _visual(int i) => _rtl ?? false ?
//    widget.segments.length - 1 - i : i;` -> `=> i;`: the drop held over the
//    first segment's label is drawn over the last's;
//  - in `_CellOverlay._cell`, `(rtl ? count - 1 - i : i)` -> `i`: the held
//    cell is brightened under the other item.
//  - in `_StepperPainter.paint`, `final double decrementAt = rtl ? half : 0;`
//    -> `= 0;` (and `incrementAt` -> `= half;`): the plus is drawn at the
//    right under rtl, over the half a tap decrements from;
//  - in `_DotsPainter.paint`, `rtl ? size.width - x - w : x` -> `x`: the first
//    page's wide dot is at the left; in `_along`, `_rtl ? _geometry.width - x
//    : x` -> `x`: a tap toward the left goes back.
//  - in `_TabGeometry.drawn`, `rtl ? width - centre(i) : centre(i)` ->
//    `centre(i)`: the resting capsule is drawn under the last item; in
//    `_TabGeometry.indexUnder`, `indexAt(rtl ? width - x : x, count)` ->
//    `indexAt(x, count)`: a tap selects the item at the mirrored position; in
//    `_onUp`, `* (g.rtl ? -1 : 1)` -> `* 1`: a flick carries the drop back
//    toward the item it left;
//  - in `_GlassSegmentedControlState.didUpdateWidget`, the `else if` that
//    places `_at` when the count changes dropped: under rtl the capsule stays
//    where the old first segment was drawn; in `didChangeDependencies`,
//    `_at.value = widget.segments.length - 1 - _at.value` dropped: held over A
//    while the direction flips, the release selects C.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'component_scene.dart';

const Size kScreen = Size(400, 300);

void main() {
  testWidgets('a switch is on to the left, and a drag leftward turns it on', (WidgetTester tester) async {
    final knobX = <TextDirection, ({double off, double on})>{};
    for (final TextDirection direction in TextDirection.values) {
      var on = false;
      await _mount(
        tester,
        direction,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) =>
              GlassSwitch(value: on, onChanged: (bool v) => setState(() => on = v)),
        ),
      );
      final Rect box = tester.getRect(find.byType(GlassSwitch));
      final double off = _knob(tester).globalRect.center.dx - box.left;
      // Toward where on is, from the knob: past the slop and the middle.
      final double toward = direction == TextDirection.rtl ? -1 : 1;
      final TestGesture gesture = await tester.startGesture(_knob(tester).globalRect.center);
      await gesture.moveBy(Offset(24 * toward, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(on, isTrue, reason: '$direction: dragging toward on did not turn it on');
      knobX[direction] = (off: off, on: _knob(tester).globalRect.center.dx - box.left);
    }
    // ignore: avoid_print
    print('knob centre from the switch\'s left: $knobX');
    final ltr = knobX[TextDirection.ltr]!;
    final rtl = knobX[TextDirection.rtl]!;
    expect(ltr.off, lessThan(ltr.on));
    expect(rtl.off, closeTo(ltr.on, 1e-6), reason: 'rtl off is not where ltr on is');
    expect(rtl.on, closeTo(ltr.off, 1e-6), reason: 'rtl on is not where ltr off is');
  });

  testWidgets('a slider runs from the right: its knob, its fill and a tap', (WidgetTester tester) async {
    for (final TextDirection direction in TextDirection.values) {
      var value = 0.3;
      await _mount(
        tester,
        direction,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => SizedBox(
            width: 300,
            child: GlassSlider(value: value, onChanged: (double v) => setState(() => value = v)),
          ),
        ),
      );
      final Rect box = tester.getRect(find.byType(GlassSlider));
      final double end = SliderGeometry.fillEnd(0.3, box.width, textDirection: direction);
      expect(
        _knob(tester).globalRect.center.dx - box.left,
        closeTo(end, 0.01),
        reason: '$direction: the knob is not where the fill ends',
      );
      // The fill is blue on the side of 0: sample just inside each end.
      final Uint8List px = await _shot(tester);
      int blueAt(double x) => px[(box.center.dy.round() * kScreen.width.toInt() + x.round()) * 4 + 2];
      final double low = direction == TextDirection.ltr ? box.left + 24 : box.right - 24;
      final double high = direction == TextDirection.ltr ? box.right - 24 : box.left + 24;
      expect(blueAt(low), greaterThan(200), reason: '$direction: no fill at the 0 end');
      expect(blueAt(high), lessThan(200), reason: '$direction: fill at the 1 end');
      // A tap near the 1 end.
      await tester.tapAt(Offset(high, box.center.dy));
      await tester.pumpAndSettle();
      expect(value, greaterThan(0.9), reason: '$direction: a tap at the 1 end set $value');
    }
    expect(SliderGeometry.fillEnd(0.3, 300, textDirection: TextDirection.rtl), 300 - SliderGeometry.fillEnd(0.3, 300));
  });

  testWidgets('a segmented control starts at the right, and its drop follows its labels', (WidgetTester tester) async {
    for (final TextDirection direction in TextDirection.values) {
      final selected = <int>[];
      await _mount(
        tester,
        direction,
        SizedBox(
          width: 300,
          child: GlassSegmentedControl(
            segments: const <Widget>[Text('A'), Text('B'), Text('C')],
            selectedIndex: 1,
            onSelected: selected.add,
          ),
        ),
      );
      final Offset a = tester.getCenter(find.text('A'));
      final Offset c = tester.getCenter(find.text('C'));
      expect(a.dx < c.dx, direction == TextDirection.ltr, reason: '$direction: the labels are not in order');
      // Held over A, the drop is under A.
      final TestGesture gesture = await tester.startGesture(a);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final RenderGlassSurface drop = tester.renderObject(find.byType(GlassSurface));
      expect(drop.globalRect.center.dx, closeTo(a.dx, 2), reason: '$direction: the drop is not under A');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, <int>[0], reason: '$direction: pressing A did not select A');
    }
  });

  testWidgets('a segmented control keeps its capsule under the selected segment as segments come and go', (
    WidgetTester tester,
  ) async {
    // `_at` is where the capsule is drawn; under rtl a segment added moves
    // where the selected one is drawn, so the capsule is placed again.
    for (final TextDirection direction in TextDirection.values) {
      Widget control(List<String> labels) => SizedBox(
        width: 300,
        child: GlassSegmentedControl(
          segments: <Widget>[for (final String l in labels) Text(l)],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      );
      await _mount(tester, direction, control(<String>['A', 'B', 'C']));
      await _mount(tester, direction, control(<String>['A', 'B', 'C', 'D']), keep: true);
      await tester.pumpAndSettle();
      final Rect box = tester.getRect(find.byType(GlassSegmentedControl));
      final int count = 4;
      final double pitch = (box.width - 4) / count;
      final double at = _capsuleAt(tester);
      final double drawnX = box.left + 2 + pitch * (at + 0.5);
      expect(drawnX, closeTo(tester.getCenter(find.text('A')).dx, 1), reason: '$direction: the capsule left A');
    }
  });

  testWidgets('a segmented control held while the direction flips selects the segment it was held over', (
    WidgetTester tester,
  ) async {
    final selected = <int>[];
    Widget control() => SizedBox(
      width: 300,
      child: GlassSegmentedControl(
        segments: const <Widget>[Text('A'), Text('B'), Text('C')],
        selectedIndex: 1,
        onSelected: selected.add,
      ),
    );
    await _mount(tester, TextDirection.ltr, control());
    // Dragged a little, so the release reads where the drop is, not the
    // segment pressed.
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await gesture.moveBy(const Offset(8, 0));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _mount(tester, TextDirection.rtl, control(), keep: true);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, <int>[0], reason: 'the release selected the segment mirrored from the one held');
  });

  testWidgets('a tab bar starts at the right: its capsule, its taps and its held drop follow its labels', (
    WidgetTester tester,
  ) async {
    for (final TextDirection direction in TextDirection.values) {
      final selected = <int>[];
      await _mount(
        tester,
        direction,
        SizedBox(
          width: 300,
          child: GlassTabBar(
            items: const <GlassTabItem>[
              GlassTabItem(label: 'A', icon: Icons.circle),
              GlassTabItem(label: 'B', icon: Icons.circle),
              GlassTabItem(label: 'C', icon: Icons.circle),
              GlassTabItem(label: 'D', icon: Icons.circle),
            ],
            selectedIndex: 0,
            onSelected: selected.add,
          ),
        ),
      );
      final Offset a = tester.getCenter(find.text('A'));
      final Offset d = tester.getCenter(find.text('D'));
      expect(a.dx < d.dx, direction == TextDirection.ltr, reason: '$direction: the labels are not in order');
      // At rest the capsule is under the selected item, A.
      final Rect capsule = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is DecoratedBox &&
              w.decoration is ShapeDecoration &&
              (w.decoration as ShapeDecoration).shape is StadiumBorder,
        ),
      );
      expect(capsule.center.dx, closeTo(a.dx, 2), reason: '$direction: the capsule is not under A');
      // A tap on each other item selects that item.
      for (final String label in <String>['B', 'C', 'D']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(selected, <int>[1, 2, 3], reason: '$direction: a tap selected another item than the one under it');
      // Held over C, the drop is under C, and letting go selects C.
      selected.clear();
      final Offset c = tester.getCenter(find.text('C'));
      final TestGesture gesture = await tester.startGesture(c);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_knob(tester).globalRect.center.dx, closeTo(c.dx, 2), reason: '$direction: the drop is not under C');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, <int>[2], reason: '$direction: holding C did not select C');
      // Flicked from B toward C, the drop carries on past C to D.
      selected.clear();
      final double towardC = direction == TextDirection.ltr ? 1 : -1;
      await tester.flingFrom(tester.getCenter(find.text('B')), Offset(60 * towardC, 0), 2000);
      await tester.pumpAndSettle();
      expect(selected, <int>[3], reason: '$direction: a flick toward C did not carry on to D');
    }
  });

  testWidgets('a toolbar group brightens the held item\'s own cell', (WidgetTester tester) async {
    for (final TextDirection direction in TextDirection.values) {
      await _mount(
        tester,
        direction,
        GlassButtonGroup(
          items: <GlassToolbarItem>[
            GlassToolbarItem(
              icon: const SizedBox(key: ValueKey<int>(0)),
              label: 'a',
              onPressed: () {},
            ),
            GlassToolbarItem(
              icon: const SizedBox(key: ValueKey<int>(1)),
              label: 'b',
              onPressed: () {},
            ),
          ],
        ),
      );
      final Offset first = tester.getCenter(find.byKey(const ValueKey<int>(0)));
      final Offset second = tester.getCenter(find.byKey(const ValueKey<int>(1)));
      final Uint8List resting = await _shot(tester);
      final TestGesture gesture = await tester.startGesture(first);
      await tester.pump();
      final Uint8List held = await _shot(tester);
      int lift(Offset at) {
        final int i = (at.dy.round() * kScreen.width.toInt() + at.dx.round() + 8) * 4;
        return held[i] - resting[i];
      }

      expect(lift(first), greaterThan(30), reason: '$direction: the held item\'s cell did not brighten');
      expect(lift(second), lessThan(5), reason: '$direction: the other item\'s cell brightened');
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });
  testWidgets('a stepper puts minus at the end: its glyphs, its taps and its held light agree', (
    WidgetTester tester,
  ) async {
    for (final TextDirection direction in TextDirection.values) {
      final steps = <double>[];
      var value = 5.0;
      final ComponentScene scene = await ComponentScene.mount(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => GlassStepper(
            value: value,
            onChanged: (double v) {
              steps.add(v);
              setState(() => value = v);
            },
          ),
        ),
        textDirection: direction,
      );
      final Offset centre = tester.getCenter(find.byType(GlassStepper));
      final Offset left = centre - Offset(kGlassStepperSize.width / 4, 0);
      final Offset right = centre + Offset(kGlassStepperSize.width / 4, 0);
      // The plus has a vertical stroke 5 px above its centre and the minus
      // has none: ink there against the glass 12 px aside, past both arms.
      final Uint8List rest = await scene.pixels();
      double stroke(Offset at) =>
          (meanAt(rest, at - const Offset(0, 5), side: 1) - meanAt(rest, at - const Offset(12, 5), side: 1)).abs();
      final double leftInk = stroke(left);
      final double rightInk = stroke(right);
      // ignore: avoid_print
      print('$direction: vertical stroke left $leftInk, right $rightInk');
      expect((leftInk - rightInk).abs(), greaterThan(20), reason: '$direction: no half carries the plus\'s stroke');
      final bool plusRight = rightInk > leftInk;
      expect(plusRight, direction == TextDirection.ltr, reason: '$direction: the plus is drawn on the wrong side');
      final Offset minus = plusRight ? left : right;
      final Offset plus = plusRight ? right : left;

      // Held, the minus glyph's half is the one lit — off the glyph, at its
      // outer quarter.
      final Offset minusOuter = centre + (minus - centre) * 1.5;
      final Offset plusOuter = centre + (plus - centre) * 1.5;
      final TestGesture finger = await tester.startGesture(minus);
      await tester.pump();
      final Uint8List held = await scene.pixels();
      await finger.up();
      await tester.pump(const Duration(seconds: 1));
      expect(
        meanAt(held, minusOuter) - meanAt(rest, minusOuter),
        greaterThan(20),
        reason: '$direction: the held minus half is not lit',
      );
      expect(meanAt(held, plusOuter), meanAt(rest, plusOuter), reason: '$direction: the plus half lit');
      expect(steps, <double>[4], reason: '$direction: pressing the minus glyph did not decrement');

      await tester.tapAt(plus);
      await tester.pump();
      expect(steps, <double>[4, 5], reason: '$direction: tapping the plus glyph did not increment');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a page control runs from the right: its current dot, a tap toward a side, a scrub', (
    WidgetTester tester,
  ) async {
    for (final TextDirection direction in TextDirection.values) {
      final rtl = direction == TextDirection.rtl;
      final pages = <int>[];
      var page = 0;
      final ComponentScene scene = await ComponentScene.mount(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => GlassPageControl(
            count: 5,
            currentPage: page,
            onPageChanged: (int p) {
              pages.add(p);
              setState(() => page = p);
            },
          ),
        ),
        textDirection: direction,
      );
      final Rect box = tester.getRect(find.byType(GlassSurface));
      // The first page's dot is the wide one, 10…30 px from the capsule's
      // start; 22 px from its end is the gap between the last two round dots.
      // So 22 px in is ink at the start and glass at the end — and the other
      // way round on dots that were not mirrored.
      final Uint8List px = await scene.pixels();
      double ink(double x) =>
          (meanAt(px, Offset(x, box.center.dy), side: 1) - meanAt(px, Offset(x, box.top + 3), side: 1)).abs();
      final double startEdge = rtl ? box.right - 22 : box.left + 22;
      final double endEdge = rtl ? box.left + 22 : box.right - 22;
      // ignore: avoid_print
      print('$direction: ink at the start dot\'s edge ${ink(startEdge)}, at the end dot\'s ${ink(endEdge)}');
      expect(ink(startEdge) - ink(endEdge), greaterThan(20), reason: '$direction: the current dot is not at the start');

      // A tap toward the end goes on one; toward the start, back one.
      final Offset towardEnd = rtl ? box.centerLeft + const Offset(4, 0) : box.centerRight - const Offset(4, 0);
      final Offset towardStart = rtl ? box.centerRight - const Offset(4, 0) : box.centerLeft + const Offset(4, 0);
      await tester.tapAt(towardEnd);
      await scene.frames(30);
      expect(pages, <int>[1], reason: '$direction: a tap toward the end did not go on one');
      await tester.tapAt(towardStart);
      await scene.frames(30);
      expect(pages, <int>[1, 0], reason: '$direction: a tap toward the start did not go back one');

      // A scrub from the first dot toward the end asks for each page.
      pages.clear();
      final Offset start = Offset(rtl ? box.right - 20 : box.left + 20, box.center.dy);
      final TestGesture finger = await tester.startGesture(start);
      for (var i = 1; i <= 20; i++) {
        await finger.moveTo(start + Offset((rtl ? -1 : 1) * (box.width - 20) * i / 20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finger.up();
      await scene.frames(30);
      expect(pages, <int>[1, 2, 3, 4], reason: '$direction: a scrub toward the end did not walk the pages');
      await tester.pumpWidget(const SizedBox());
    }
  });
}

/// A key of its own per mount: one global key carried across mounts would
/// reparent the old subtree, state and all, into the new host.
GlobalKey _shotKey = GlobalKey();

/// The resting knob, or the drop it becomes: the one clear surface.
RenderGlassSurface _knob(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);

/// Where the segmented control's capsule is drawn, as a segment index.
double _capsuleAt(WidgetTester tester) {
  final CustomPaint paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere(
        (CustomPaint p) => p.painter.runtimeType.toString() == '_CapsulePainter',
      );
  return ((paint.painter! as dynamic).at as Animation<double>).value;
}

/// [keep] rebuilds the same tree with [control] and [direction] in place —
/// one host, one state — instead of mounting afresh.
Future<void> _mount(WidgetTester tester, TextDirection direction, Widget control, {bool keep = false}) async {
  if (!keep) {
    _shotKey = GlobalKey();
  }
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen),
      child: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: keep ? _hostKey : _hostKey = GlobalKey(),
            hardware: GlassHardware.appleMetal,
            tier: const GlassTierChoice(GlassTier.cheap, GlassTierReason.pinnedByHost),
            backdrop: const Color(0xFF404040),
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(child: ColoredBox(color: Color(0xFF404040))),
                    Positioned(left: 50, top: 120, child: control),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

GlobalKey _hostKey = GlobalKey();

Future<Uint8List> _shot(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
  late Uint8List px;
  await tester.runAsync(() async {
    px = (await shot.toByteData())!.buffer.asUint8List();
  });
  shot.dispose();
  return px;
}
