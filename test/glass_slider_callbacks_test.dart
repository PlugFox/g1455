// A slider's onChangeStart and onChangeEnd bracket each gesture: exactly one
// start before any change, exactly one end after the last, and the end carries
// the last value the slider sent — as Material's `Slider` does.
//
// `flutter test test/glass_slider_callbacks_test.dart`
//
// A slider has two recognizers, a tap and a drag, and each has its own way to
// end: a held finger is a tap down before the drag starts, and a quick tap is
// a drag that gives up before the tap wins. Each row of the table is one of
// those orders, run with and without stops, outside any scrollable and inside
// a horizontal one, where the slider lifts its drop on touch-down. The log of
// each row is checked whole against what it should be, so a row whose gesture
// never reached the slider fails on its changes rather than passing on its
// silence.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

typedef _Gesture = Future<void> Function(WidgetTester tester, _Rig rig);

/// The x of [value] on the track, for the slider at [box].
double _x(Rect box, double value) => box.left + 19 + value * (box.width - 38);

final Map<String, _Gesture> _gestures = <String, _Gesture>{
  'quick tap': (WidgetTester tester, _Rig rig) async {
    await tester.tapAt(Offset(_x(rig.box, 1), rig.box.center.dy));
    await tester.pumpAndSettle();
  },
  'held, then lifted': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 1), rig.box.center.dy));
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pumpAndSettle();
  },
  'held, then dragged': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 0.5), rig.box.center.dy));
    await tester.pump(const Duration(milliseconds: 150));
    await _sweep(tester, g, rig.box, 0.5, 1);
    await g.up();
    await tester.pumpAndSettle();
  },
  'dragged': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 0.5), rig.box.center.dy));
    await _sweep(tester, g, rig.box, 0.5, 0);
    await g.up();
    await tester.pumpAndSettle();
  },
  'dragged, then cancelled': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 0.5), rig.box.center.dy));
    await _sweep(tester, g, rig.box, 0.5, 1);
    await g.cancel();
    await tester.pumpAndSettle();
  },
  'held, then cancelled': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 1), rig.box.center.dy));
    await tester.pump(const Duration(milliseconds: 150));
    await g.cancel();
    await tester.pumpAndSettle();
  },
  'disabled mid-drag': (WidgetTester tester, _Rig rig) async {
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 0.5), rig.box.center.dy));
    await _sweep(tester, g, rig.box, 0.5, 0.8);
    rig.disable();
    await tester.pump();
    await _sweep(tester, g, rig.box, 0.8, 1);
    await g.up();
    await tester.pumpAndSettle();
  },
  'arrow key': (WidgetTester tester, _Rig rig) async {
    rig.focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
  },
};

Future<void> _sweep(WidgetTester tester, TestGesture g, Rect box, double from, double to) async {
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset(_x(box, from + (to - from) * i / 10), box.center.dy));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  // The hand-over from the tap to the drag cancels the tap; the drop the tap
  // lifted must stay up through it, since the drag that wins is the same
  // change and does not lift it again.
  testWidgets('held, then dragged: the drop stays lifted through the hand-over', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, divisions: null, scrolled: false);
    final TestGesture g = await tester.startGesture(Offset(_x(rig.box, 0.5), rig.box.center.dy));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lift(tester), 1, reason: 'a held finger did not lift the drop: the arm sees nothing');
    await _sweep(tester, g, rig.box, 0.5, 0.8);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lift(tester), 1, reason: 'the drop came down when the drag took over from the tap');
    await g.up();
    await tester.pumpAndSettle();
    expect(_lift(tester), 0);
  });

  for (final MapEntry<String, _Gesture> row in _gestures.entries) {
    for (final int? divisions in <int?>[4, null]) {
      for (final bool scrolled in <bool>[false, true]) {
        testWidgets('${row.key}, divisions $divisions, ${scrolled ? 'in a carousel' : 'alone'}: one start, one end', (
          WidgetTester tester,
        ) async {
          final _Rig rig = await _Rig.mount(tester, divisions: divisions, scrolled: scrolled);
          await row.value(tester, rig);
          final List<String> log = rig.log;
          // ignore: avoid_print
          print('${row.key} / $divisions / $scrolled: $log');
          expect(log, isNotEmpty, reason: 'the gesture never reached the slider');
          expect(log.first, 'start 0.5', reason: 'the first call is not the start, with the value before it');
          expect(log.where((String e) => e.startsWith('start')), hasLength(1), reason: 'not one start: $log');
          expect(log.where((String e) => e.startsWith('end')), hasLength(1), reason: 'not one end: $log');
          expect(log.last, startsWith('end'), reason: 'something came after the end: $log');
          final Iterable<String> changes = log.where((String e) => e.startsWith('changed'));
          expect(changes, isNotEmpty, reason: 'the gesture changed nothing, so it tells nothing: $log');
          expect(
            log.last.substring(4),
            changes.last.substring(8),
            reason: 'the end does not carry the last value sent: $log',
          );
        });
      }
    }
  }
}

/// The held drop's lift, 0 at rest and 1 held.
double _lift(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name)
    .materialize;

class _Rig {
  _Rig(this.box, this.log, this.disable, this.focus);

  final Rect box;
  final List<String> log;
  final VoidCallback disable;
  final FocusNode focus;

  static Future<_Rig> mount(WidgetTester tester, {required int? divisions, required bool scrolled}) async {
    final log = <String>[];
    var value = 0.5;
    var enabled = true;
    late StateSetter set;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    String f(double v) => v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    final Widget slider = StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        set = setState;
        return SizedBox(
          width: 300,
          child: GlassSlider(
            key: const ValueKey<String>('slider'),
            value: value,
            divisions: divisions,
            focusNode: focus,
            onChanged: enabled ? (double v) => setState(() => log.add('changed ${f(value = v)}')) : null,
            onChangeStart: (double v) => log.add('start ${f(v)}'),
            onChangeEnd: (double v) => log.add('end ${f(v)}'),
          ),
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: scrolled
            ? ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  const SizedBox(width: 100),
                  Center(child: slider),
                  const SizedBox(width: 1000),
                ],
              )
            : Center(child: slider),
      ),
    );
    return _Rig(
      tester.getRect(find.byKey(const ValueKey<String>('slider'))),
      log,
      () => set(() => enabled = false),
      focus,
    );
  }
}
