// A press never draws the glass smaller than the resting box, because the
// label is laid out inside it.
//
// `flutter test test/glass_press_floor_test.dart`
//
// Found by the showcase's alert scene: a `Row(icon, 'Delete')` that fills its
// button overflowed by 0.727 px on the spring-back, where the press value
// undershoots to 1 - maxOvershoot and the glass shrank below its box.
//
// The geometry arm sweeps every press value the spring can reach and asserts
// the floor; its control is the same sweep through the unfloored formula,
// which must find a box smaller than the rest — so the floor is not a
// statement about a sweep too gentle to reach the undershoot. The break,
// undone by swapping the string back: in `GlassPress.rect`,
// `math.max(rest.width, ` and `math.max(rest.height, ` removed — the widget
// arm's row overflows.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  test('every press the spring reaches is at least the resting box', () {
    const press = GlassPress();
    const sizes = <Size>[Size(44, 44), Size(132, 44), Size(320, 48), Size(44, 160)];
    const fingers = <Offset>[Offset.zero, Offset(30, 0), Offset(0, 30), Offset(-20, 20), Offset(4, -1)];
    var checked = 0;
    var unflooredBelow = 0;
    for (final Size rest in sizes) {
      for (var i = 0; i <= 46; i++) {
        final double p = (1 - GlassPress.maxOvershoot) + i * (2 * GlassPress.maxOvershoot - 1) / 46;
        for (final Offset finger in fingers) {
          final Rect r = press.rect(rest, p, finger);
          expect(r.width, greaterThanOrEqualTo(rest.width), reason: '$rest at $p, $finger');
          expect(r.height, greaterThanOrEqualTo(rest.height), reason: '$rest at $p, $finger');
          checked++;
          // The formula without the floor, as it stood when the overflow was found.
          final double k =
              1 + press.grow * p.clamp(1 - GlassPress.maxOvershoot, GlassPress.maxOvershoot) / rest.longestSide;
          final double reach = _tanh(finger.distance / press.pullReach);
          final Offset towards = finger.distance == 0 ? Offset.zero : finger / finger.distance;
          final double sx = press.maxStretch * reach * towards.dx.abs();
          final double sy = press.maxStretch * reach * towards.dy.abs();
          if (rest.width * k * (1 + sx) / (1 + sy) < rest.width ||
              rest.height * k * (1 + sy) / (1 + sx) < rest.height) {
            unflooredBelow++;
          }
        }
      }
    }
    expect(checked, 4 * 47 * 5);
    expect(unflooredBelow, greaterThan(0), reason: 'the sweep never reached a shrinking press');
  });

  testWidgets('a label that fills its button does not overflow through a press and its spring-back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 400), devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            child: Center(
              child: GlassButton(
                onPressed: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[SizedBox(width: 24, height: 20), SizedBox(width: 41.3, height: 20)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(Row)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    var frames = 0;
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      expect(tester.takeException(), isNull, reason: 'frame $i of the release');
      frames++;
    }
    expect(frames, 90);
  });
}

double _tanh(double x) {
  final double e = math.exp(-2 * x.abs());
  return (1 - e) / (1 + e) * x.sign;
}
