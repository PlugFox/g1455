// A slider with stops: a tap, a drag, a key and a screen reader all land on
// one, and the caller hears of each stop once.
//
// `flutter test test/glass_slider_divisions_test.dart`
//
// The control for every arm is the same slider without `divisions`, run
// through the same gesture: it lands between stops and reports every move, so
// a pass is the snapping and not a gesture that happened to land on a stop.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('a tap lands on the nearest stop', (WidgetTester tester) async {
    for (final int? divisions in <int?>[4, null]) {
      final changes = <double>[];
      await _mount(tester, divisions: divisions, value: 0, onChanged: changes.add);
      final Rect box = tester.getRect(find.byType(GlassSlider));
      // 0.4 of the way along the knob's travel.
      await tester.tapAt(Offset(box.left + 19 + 0.4 * (box.width - 38), box.center.dy));
      await tester.pumpAndSettle();
      if (divisions == null) {
        expect(changes.single, closeTo(0.4, 0.01), reason: 'the control did not land where it was tapped');
      } else {
        expect(changes.single, 0.5);
      }
    }
  });

  testWidgets('a drag reports each stop once, and nothing between', (WidgetTester tester) async {
    final calls = <int?, List<double>>{};
    for (final int? divisions in <int?>[4, null]) {
      final changes = <double>[];
      await _mount(tester, divisions: divisions, value: 0, onChanged: changes.add);
      final Rect box = tester.getRect(find.byType(GlassSlider));
      final TestGesture gesture = await tester.startGesture(Offset(box.left + 19, box.center.dy));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(Offset((box.width - 38) / 40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      calls[divisions] = changes;
    }
    // ignore: avoid_print
    print('onChanged across the track: ${calls[4]!.length} calls with stops, ${calls[null]!.length} without');
    expect(calls[4], <double>[0.25, 0.5, 0.75, 1]);
    expect(calls[null]!.length, greaterThan(20), reason: 'the control reported too few moves to tell');
  });

  testWidgets('a screen reader steps one division', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final changes = <double>[];
    await _mount(tester, divisions: 4, value: 0.5, onChanged: changes.add);
    final SemanticsNode node = tester.getSemantics(find.byType(GlassSlider));
    final SemanticsData data = node.getSemanticsData();
    expect(data.value, '50%');
    expect(data.increasedValue, '75%');
    expect(data.decreasedValue, '25%');
    tester.semantics.increase(find.semantics.byValue('50%'));
    await tester.pump();
    expect(changes, <double>[0.75]);
    semantics.dispose();
  });

  testWidgets('a value between stops is stepped onto one', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _mount(tester, divisions: 4, value: 0.6, onChanged: (_) {});
    final SemanticsData data = tester.getSemantics(find.byType(GlassSlider)).getSemanticsData();
    expect(data.increasedValue, '75%');
    expect(data.decreasedValue, '50%');
    semantics.dispose();
  });
}

Future<void> _mount(
  WidgetTester tester, {
  required int? divisions,
  required double value,
  required ValueChanged<double> onChanged,
}) async {
  var current = value;
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: StatefulBuilder(
          key: ValueKey<int?>(divisions),
          builder: (BuildContext context, StateSetter setState) => SizedBox(
            width: 300,
            child: GlassSlider(
              value: current,
              divisions: divisions,
              onChanged: (double v) {
                onChanged(v);
                setState(() => current = v);
              },
            ),
          ),
        ),
      ),
    ),
  );
}
