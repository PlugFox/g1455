// Who gets the finger: a switch or a slider under a horizontal scrollable
// claims the pointer on touch-down; under a vertical one it does not.
//
// `flutter test test/glass_gesture_arena_test.dart`
//
// **What was measured first, and it is not what the request assumed.** A
// switch in a `PageView` already won a horizontal drag before this change,
// headless: both recognizers are horizontal drags with the same slop, and the
// deeper one — the switch's — sees each move first and accepts first. What it
// did not have is the pointer *on touch-down*: the drop lifted only when the
// tap's 100 ms timeout ran out or the drag passed its slop, and the knob
// jumped by the slop when it did. So the claim's arm is the frame after
// touch-down, and its negative control is the same scene with the claim
// turned off (`debugGlassControlsClaimOverride = false`): nothing lifted yet.
//
// The second half is where the claim must **not** happen. Under a vertical
// list, a vertical swipe that starts on a switch is a scroll; a control that
// claimed every pointer would take it. Its negative control is the claim
// forced on, under which the list does not move — so the pass is the rule,
// not a list that scrolls whatever the switch does.
//
// Breaks, each undone by swapping the string back:
//  - in `_controlGestures`, `DragStartBehavior.down` -> `DragStartBehavior.start`:
//    the unclaimed switch's knob loses the 18 px slop;
//  - in `_GlassSwitchState._dragEnd`, `_commit(_dragFurthest < slop && _claimed
//    ? !widget.value : _position.value >= 0.5);` -> `_commit(_position.value >=
//    0.5);`: a claimed tap is a drag of nothing, and toggles nothing.
//
// The segmented control has no drag recognizer of its own — it follows raw
// pointer events — so its claim is an eager recognizer that only wins, and
// its arm's negative control is the page moving with the drag unclaimed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/surface/glass_controls.dart' show debugGlassControlsClaimOverride;

void main() {
  tearDown(() => debugGlassControlsClaimOverride = null);

  testWidgets('in a PageView a switch takes the pointer on touch-down, and a drag across toggles it', (
    WidgetTester tester,
  ) async {
    final lifted = <bool?, double>{};
    final pages = <bool?, double>{};
    for (final bool? override in <bool?>[null, false]) {
      debugGlassControlsClaimOverride = override;
      var on = false;
      final controller = PageController(initialPage: 1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _paged(controller, (StateSetter setState) => _switch(on, (bool v) => setState(() => on = v))),
      );
      final Offset knob = tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22);
      final TestGesture gesture = await tester.startGesture(knob);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      lifted[override] = _drop(tester).materialize;
      // Slowly across, two px a frame: the page sees the same moves.
      for (var i = 0; i < 16; i++) {
        await gesture.moveBy(const Offset(2, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      pages[override] = controller.page! - 1;
      await gesture.up();
      await tester.pumpAndSettle();
      expect(on, isTrue, reason: 'claim $override: a drag across did not toggle the switch');
    }
    // ignore: avoid_print
    print('page offset during the drag: claimed ${pages[null]}, unclaimed ${pages[false]}');
    expect(pages[null], 0, reason: 'claimed, the page moved');
    expect(pages[false], 0, reason: 'unclaimed, the page moved: the deeper recognizer did not win');
    // ignore: avoid_print
    print('drop 32 ms after touch-down: claimed ${lifted[null]}, unclaimed ${lifted[false]}');
    expect(lifted[null], greaterThan(0), reason: 'claimed, the drop did not lift on touch-down');
    expect(lifted[false], 0, reason: 'unclaimed, the drop lifted before the tap\'s timeout: the arm sees nothing');
  });

  testWidgets('claimed, a tap still toggles; claimed or not, a drag is measured from touch-down', (
    WidgetTester tester,
  ) async {
    var on = false;
    final controller = PageController(initialPage: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _paged(controller, (StateSetter setState) => _switch(on, (bool v) => setState(() => on = v))),
    );
    await tester.tap(find.byType(GlassSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue, reason: 'a claimed tap did nothing');

    // The switch's knob, carried 20 px of its 22 by a finger moving 20 from
    // touch-down. A drag measured from the slop would have carried it 2. Twice:
    // claimed, where the drag is won at touch-down anyway, and outside any
    // scrollable, where it is won at the slop and only
    // `DragStartBehavior.down` gives the slop back. (The slider cannot tell:
    // it places its knob under the finger, wherever the drag started.)
    for (final bool paged in <bool>[true, false]) {
      Widget control(StateSetter setState) => _switch(false, (_) {});
      await tester.pumpWidget(
        paged
            ? _paged(PageController(initialPage: 1), control)
            : MaterialApp(
                home: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) => Center(child: control(setState)),
                ),
              ),
      );
      final double rest = _drop(tester).globalRect.center.dx;
      final TestGesture gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22),
      );
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(5, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_drop(tester).globalRect.center.dx - rest, closeTo(20, 0.01), reason: 'paged $paged: lost the slop');
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('under a vertical list a swipe that starts on a switch scrolls the list', (WidgetTester tester) async {
    final scrolled = <bool?, double>{};
    for (final bool? override in <bool?>[null, true]) {
      debugGlassControlsClaimOverride = override;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          // Keyed per arm: a list kept across the two would hand the first
          // arm's offset to the second's controller.
          home: ListView(
            key: ValueKey<bool?>(override),
            controller: controller,
            children: <Widget>[
              for (var i = 0; i < 30; i++)
                SizedBox(
                  height: 60,
                  child: Center(
                    child: GlassSwitch(key: ValueKey<int>(i), value: false, onChanged: (_) {}),
                  ),
                ),
            ],
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<int>(3))));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      scrolled[override] = controller.offset;
    }
    // ignore: avoid_print
    print('list offset after a swipe from a switch: by the rule ${scrolled[null]}, claim forced ${scrolled[true]}');
    expect(scrolled[true], 0, reason: 'a claiming switch let the list scroll: the arm sees nothing');
    expect(scrolled[null], greaterThan(50), reason: 'a switch in a vertical list took the swipe');
  });

  testWidgets('in a PageView a drag across a segmented control moves the selection and not the page', (
    WidgetTester tester,
  ) async {
    // The control follows raw pointer events and is in no arena, so before
    // it claimed, the page won the drag and both followed the finger. The
    // negative control is that, with the claim turned off.
    final outcome = <bool?, ({List<int> selected, double page})>{};
    for (final bool? override in <bool?>[null, false]) {
      debugGlassControlsClaimOverride = override;
      final selected = <int>[];
      // From the last segment leftward: a page view on its first page has
      // nowhere to go rightward, and would pass this arm for that reason.
      var index = 2;
      final controller = PageController(initialPage: 1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _paged(
          controller,
          (StateSetter setState) => SizedBox(
            width: 300,
            child: GlassSegmentedControl(
              segments: const <Widget>[Text('A'), Text('B'), Text('C')],
              selectedIndex: index,
              onSelected: (int i) => setState(() {
                selected.add(i);
                index = i;
              }),
            ),
          ),
        ),
      );
      final Offset a = tester.getCenter(find.text('A'));
      final Offset c = tester.getCenter(find.text('C'));
      final TestGesture gesture = await tester.startGesture(c);
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(Offset.lerp(c, a, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      final double during = controller.page! - 1;
      await gesture.up();
      await tester.pumpAndSettle();
      outcome[override] = (selected: selected, page: during);
    }
    // ignore: avoid_print
    print('segmented control dragged in a PageView: $outcome');
    expect(outcome[false]!.page, greaterThan(0.1), reason: 'unclaimed, the page did not move: the arm is blind');
    expect(outcome[null]!.page, 0, reason: 'claimed, the page moved with the drag');
    expect(outcome[null]!.selected, <int>[0], reason: 'claimed, the drag did not select where it was let go');
  });

  testWidgets('under a vertical list a segmented control claims nothing', (WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: <Widget>[
            for (var i = 0; i < 20; i++)
              SizedBox(
                height: 80,
                child: GlassSegmentedControl(
                  key: ValueKey<int>(i),
                  segments: const <Widget>[Text('A'), Text('B')],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
          ],
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<int>(2))));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(50), reason: 'a segmented control in a vertical list took the swipe');
  });
}

Widget _switch(bool on, ValueChanged<bool> onChanged) => GlassSwitch(value: on, onChanged: onChanged);

/// The control on the middle of three pages, so the page can follow a drag
/// either way: on the first page a rightward drag has nowhere to go, and an
/// arm that dragged rightward there would find the page still for that reason.
/// Use a controller with `initialPage: 1`.
Widget _paged(PageController controller, Widget Function(StateSetter setState) control) => MaterialApp(
  // Keyed by the controller: a page view kept across arms keeps its state.
  key: ObjectKey(controller),
  home: StatefulBuilder(
    builder: (BuildContext context, StateSetter setState) => PageView(
      controller: controller,
      children: <Widget>[
        const Center(child: Text('the page before')),
        Center(child: control(setState)),
        const Center(child: Text('the page after')),
      ],
    ),
  ),
);

RenderGlassSurface _drop(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);
