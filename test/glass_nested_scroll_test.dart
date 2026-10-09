// A control in a carousel row of a vertical list: the nearest scrollable is
// horizontal, so the control lifts its drop on touch-down — and a vertical
// swipe that starts on it must still scroll the list, and change nothing.
//
// `flutter test test/glass_nested_scroll_test.dart`
//
// The vertical arm's negative control is the same swipe started on a plain
// box in the same row: the list scrolls by that much, so a pass is the control
// letting go and not a list that would have scrolled past anything. The
// horizontal arm's is the same control disabled — which is in no arena — under
// which the carousel follows the drag; enabled, it must not. The tap arm is
// the reason a control competes at all.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

enum _Kind { toggle, slider, segmented }

void main() {
  for (final _Kind kind in _Kind.values) {
    testWidgets('$kind: a vertical swipe that starts on it scrolls the outer list and changes nothing', (
      WidgetTester tester,
    ) async {
      final scrolled = <bool, double>{};
      for (final bool onControl in <bool>[true, false]) {
        final _Scene scene = await _Scene.mount(tester, kind);
        final Offset from = onControl ? tester.getCenter(scene.control) : tester.getCenter(find.byKey(_spacer));
        final TestGesture gesture = await tester.startGesture(from);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        scrolled[onControl] = scene.vertical.offset;
        if (onControl) {
          expect(scene.changes, isEmpty, reason: 'the swipe changed the control');
        }
      }
      // ignore: avoid_print
      print('$kind: outer list after a swipe: from the control ${scrolled[true]}, from beside it ${scrolled[false]}');
      expect(scrolled[false], greaterThan(50), reason: 'the list did not scroll from beside the control: blind arm');
      expect(scrolled[true], scrolled[false], reason: 'the control took the swipe from the outer list');
    });

    testWidgets('$kind: a horizontal drag drives the control and not the carousel', (WidgetTester tester) async {
      final moved = <bool, double>{};
      for (final bool enabled in <bool>[true, false]) {
        final _Scene scene = await _Scene.mount(tester, kind, enabled: enabled);
        final Rect box = tester.getRect(scene.control);
        // From the control's left end rightward: off to on, 0 to most, first
        // segment to last — and past the switch's short track, so that the
        // carousel has room to show it followed. The carousel starts mid-way
        // so it can.
        final Offset from = Offset(box.left + 19, box.center.dy);
        final Offset to = from + Offset(math.max(80, box.width - 38), 0);
        final TestGesture gesture = await tester.startGesture(from);
        for (var i = 1; i <= 20; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 20)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        moved[enabled] = scene.horizontal.offset - _carouselStart;
        await gesture.up();
        await tester.pumpAndSettle();
        if (enabled) {
          expect(scene.changes, isNotEmpty, reason: 'the drag did not drive the control');
          expect(scene.changes.last, kind == _Kind.toggle ? true : (kind == _Kind.slider ? greaterThan(0.9) : 2));
        }
      }
      // ignore: avoid_print
      print('$kind: carousel moved during the drag: enabled ${moved[true]}, disabled ${moved[false]}');
      expect(moved[false]!.abs(), greaterThan(20), reason: 'the carousel did not follow a disabled control: blind arm');
      expect(moved[true], 0, reason: 'the carousel moved with a drag on the control');
    });

    testWidgets('$kind: a tap still acts', (WidgetTester tester) async {
      final _Scene scene = await _Scene.mount(tester, kind);
      final Rect box = tester.getRect(scene.control);
      await tester.tapAt(Offset(box.right - 19, box.center.dy));
      await tester.pumpAndSettle();
      expect(scene.changes, hasLength(1));
      expect(scene.changes.single, kind == _Kind.toggle ? true : (kind == _Kind.slider ? 1.0 : 2));
      expect(scene.vertical.offset, 0);
      expect(scene.horizontal.offset, _carouselStart);
    });
  }
}

const Key _spacer = ValueKey<String>('spacer');
const double _carouselStart = 60;

class _Scene {
  _Scene(this.vertical, this.horizontal, this.control, this.changes);

  final ScrollController vertical;
  final ScrollController horizontal;
  final Finder control;
  final List<Object> changes;

  static Future<_Scene> mount(WidgetTester tester, _Kind kind, {bool enabled = true}) async {
    final vertical = ScrollController();
    final horizontal = ScrollController(initialScrollOffset: _carouselStart);
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);
    final changes = <Object>[];
    var on = false;
    var value = 0.0;
    var index = 0;
    const Key key = ValueKey<String>('control');
    await tester.pumpWidget(
      MaterialApp(
        // Keyed per mount: a list kept across arms keeps its offset.
        key: UniqueKey(),
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => ListView(
            controller: vertical,
            children: <Widget>[
              for (var i = 0; i < 3; i++) const SizedBox(height: 80),
              SizedBox(
                height: 80,
                child: ListView(
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    const SizedBox(width: 300),
                    Center(
                      child: SizedBox(
                        width: 240,
                        child: Align(
                          widthFactor: 1,
                          child: switch (kind) {
                            _Kind.toggle => GlassSwitch(
                              key: key,
                              value: on,
                              onChanged: enabled ? (bool v) => setState(() => changes.add(on = v)) : null,
                            ),
                            _Kind.slider => GlassSlider(
                              key: key,
                              value: value,
                              onChanged: enabled ? (double v) => setState(() => changes.add(value = v)) : null,
                            ),
                            _Kind.segmented => GlassSegmentedControl(
                              key: key,
                              segments: const <Widget>[Text('A'), Text('B'), Text('C')],
                              selectedIndex: index,
                              onSelected: enabled ? (int i) => setState(() => changes.add(index = i)) : null,
                            ),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(key: _spacer, width: 100, height: 80),
                    const SizedBox(width: 600),
                  ],
                ),
              ),
              for (var i = 0; i < 20; i++) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
    return _Scene(vertical, horizontal, find.byKey(key), changes);
  }
}
