// GlassStepper: the steps, the autorepeat, the limits, what a screen reader
// is told, the held half's light, and what a press costs.
//
// `flutter test test/glass_stepper_test.dart`
//
//  1. **A press steps once, at once; a hold repeats; a limit stops it.** The
//     control for the repeat is the same hold with `autorepeat: false`, which
//     steps once — so the repeat count is the timer's, not the gesture's.
//  2. **Semantics: one adjustable node** whose increase and decrease move the
//     value and vanish at the limits.
//  3. **A held half is lit and the other is not** — pixels, with the control
//     that a transparent overlay lights nothing.
//  4. **One surface, and a press is no capture and repaints nothing under
//     the glass.** The controls: the ledger counts a second stepper as a
//     second surface, and the same host does record a repainted backdrop.
//
// Breaks, each undone by swapping the string back:
//  - in `glass_stepper.dart`, `if (_held == half) {` -> `if (_held == null) {`
//    (the periodic timer never starts): arm 1 counts 2 steps instead of 7,
//    and arm 4's hold never passes 5;
//  - `..blendMode = BlendMode.plus` -> `..blendMode = BlendMode.dst`: arm 3's
//    held half is not lit (213 -> 213 where it was 213 -> 255).

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'component_scene.dart';

void main() {
  testWidgets('a press steps once, a hold repeats, a limit stops it', (WidgetTester tester) async {
    final steps = <double>[];
    var value = 0.0;
    Future<void> mount({double max = 100, bool autorepeat = true, bool wraps = false, double step = 1}) =>
        ComponentScene.mount(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => GlassStepper(
              value: value,
              max: max,
              step: step,
              wraps: wraps,
              autorepeat: autorepeat,
              onChanged: (double v) {
                steps.add(v);
                setState(() => value = v);
              },
            ),
          ),
        );

    await mount();
    final Offset centre = tester.getCenter(find.byType(GlassStepper));
    final Offset plus = centre + Offset(kGlassStepperSize.width / 4, 0);
    final Offset minus = centre - Offset(kGlassStepperSize.width / 4, 0);

    // At 0 the minus half is disabled: nothing happens.
    await tester.tapAt(minus);
    await tester.pump();
    expect(steps, isEmpty, reason: 'the minus half stepped past min');

    await tester.tapAt(plus);
    await tester.pump();
    expect(steps, <double>[1], reason: 'a tap is one step');

    // A hold: one at the press, one at the delay, then one per interval.
    steps.clear();
    TestGesture finger = await tester.startGesture(plus);
    await tester.pump();
    expect(steps, <double>[2], reason: 'the step lands on the press, not on the release');
    await tester.pump(kGlassStepperRepeatDelay);
    for (var i = 0; i < 5; i++) {
      await tester.pump(kGlassStepperRepeatInterval);
    }
    await finger.up();
    await tester.pump(const Duration(seconds: 1));
    final int held = steps.length;
    // ignore: avoid_print
    print(
      'held for ${kGlassStepperRepeatDelay.inMilliseconds} + 5 x ${kGlassStepperRepeatInterval.inMilliseconds} ms: '
      '$held steps',
    );
    expect(held, 7, reason: 'press + delay + five intervals');

    // The control: the same hold without autorepeat steps once.
    value = 0;
    steps.clear();
    await mount(autorepeat: false);
    finger = await tester.startGesture(plus);
    await tester.pump(kGlassStepperRepeatDelay * 3);
    await finger.up();
    await tester.pump();
    expect(steps, <double>[1], reason: 'without autorepeat a hold is one step');

    // A limit stops the repeat, and the half is disabled there.
    value = 0;
    steps.clear();
    await mount(max: 3);
    finger = await tester.startGesture(plus);
    await tester.pump(kGlassStepperRepeatDelay);
    for (var i = 0; i < 10; i++) {
      await tester.pump(kGlassStepperRepeatInterval);
    }
    await finger.up();
    await tester.pump();
    expect(steps, <double>[1, 2, 3], reason: 'the repeat ran past max');
    await tester.tapAt(plus);
    await tester.pump();
    expect(steps, <double>[1, 2, 3], reason: 'the plus half stepped past max');

    // Wrapping: past max lands on min.
    value = 3;
    steps.clear();
    await mount(max: 3, wraps: true);
    await tester.tapAt(plus);
    await tester.pump();
    expect(steps, <double>[0]);

    // A tenth three times is 0.3, not 0.30000000000000004.
    value = 0;
    steps.clear();
    await mount(max: 1, step: 0.1);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(plus);
      await tester.pump();
    }
    expect(steps.last, 0.3);
  });

  testWidgets('semantics: one adjustable node, its value, and actions that stop at the limits', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    var value = 4.0;
    await ComponentScene.mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => GlassStepper(
          value: value,
          max: 5,
          semanticLabel: 'Copies',
          onChanged: (double v) => setState(() => value = v),
        ),
      ),
    );
    final Finder stepper = find.byType(GlassStepper);
    expect(
      tester.getSemantics(stepper),
      matchesSemantics(
        label: 'Copies',
        value: '4',
        increasedValue: '5',
        decreasedValue: '3',
        hasEnabledState: true,
        isEnabled: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    tester.semantics.increase(find.semantics.byLabel('Copies'));
    await tester.pump();
    expect(value, 5);
    expect(
      tester.getSemantics(stepper),
      matchesSemantics(
        label: 'Copies',
        value: '5',
        decreasedValue: '4',
        hasEnabledState: true,
        isEnabled: true,
        hasDecreaseAction: true,
      ),
      reason: 'increase is offered at max',
    );

    // Disabled: no actions, and said so.
    await ComponentScene.mount(tester, const GlassStepper(value: 2, onChanged: null, semanticLabel: 'Copies'));
    expect(
      tester.getSemantics(find.byType(GlassStepper)),
      matchesSemantics(label: 'Copies', value: '2', hasEnabledState: true),
    );
    handle.dispose();
  });

  testWidgets('a held half is lit, the other is not; a transparent overlay lights nothing', (
    WidgetTester tester,
  ) async {
    Future<(double, double, double, double)> press({Color? overlay}) async {
      final ComponentScene scene = await ComponentScene.mount(
        tester,
        GlassStepper(value: 5, pressedOverlay: overlay, onChanged: (_) {}),
      );
      final Offset centre = tester.getCenter(find.byType(GlassStepper));
      // Off the glyphs: a quarter of a half in from the outer end.
      final Offset left = centre - Offset(kGlassStepperSize.width * 3 / 8, 0);
      final Offset right = centre + Offset(kGlassStepperSize.width * 3 / 8, 0);
      final Uint8List rest = await scene.pixels();
      final TestGesture finger = await tester.startGesture(centre + Offset(kGlassStepperSize.width / 4, 0));
      await tester.pump();
      final Uint8List held = await scene.pixels();
      await finger.up();
      await tester.pump(const Duration(seconds: 1));
      return (meanAt(rest, left), meanAt(held, left), meanAt(rest, right), meanAt(held, right));
    }

    final (double leftRest, double leftHeld, double rightRest, double rightHeld) = await press();
    // ignore: avoid_print
    print('rim overlay: minus half $leftRest -> $leftHeld, plus half $rightRest -> $rightHeld');
    expect(rightHeld - rightRest, greaterThan(20), reason: 'the held plus half is not lit');
    expect(leftHeld, leftRest, reason: 'the minus half lit with the plus half');

    final (_, _, double clearRest, double clearHeld) = await press(overlay: const Color(0x00000000));
    expect(clearHeld, clearRest, reason: 'a transparent overlay changed the glass');
  });

  testWidgets('one surface; a press and its repeat capture nothing and repaint nothing under the glass', (
    WidgetTester tester,
  ) async {
    var value = 0.0;
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            GlassStepper(value: value, onChanged: (double v) => setState(() => value = v)),
      ),
    );
    expect(scene.surfaces, 1);
    expect(scene.load.surfaceCount, 1);

    final int recorded = scene.recorded;
    final int painted = scene.paints.value;
    final Offset plus = tester.getCenter(find.byType(GlassStepper)) + Offset(kGlassStepperSize.width / 4, 0);
    final TestGesture finger = await tester.startGesture(plus);
    await scene.frames(60); // ~1 s held: the press, the delay and the repeat.
    await finger.up();
    await scene.frames(10);
    final int captures = scene.recorded - recorded;
    final int paints = scene.paints.value - painted;
    // ignore: avoid_print
    print('held ~1 s: value $value, captures $captures, backdrop paints $paints');
    expect(value, greaterThan(5), reason: 'the hold never repeated, so the arm measured nothing');
    expect(captures, 0, reason: 'a press or its repeat took a capture');
    expect(paints, 0, reason: 'a press repainted what is under the glass');

    // The controls: the same host records a repainted backdrop, and the ledger
    // counts a second stepper.
    final int control = await scene.repaintBackdrop();
    // ignore: avoid_print
    print('a repainted backdrop: $control captures');
    expect(control, greaterThan(0), reason: 'the capture counter cannot move on this mount');
    await scene.pump(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassStepper(value: 0, onChanged: (_) {}),
          GlassStepper(value: 0, onChanged: (_) {}),
        ],
      ),
    );
    expect(scene.surfaces, 2, reason: 'the ledger cannot count a second stepper');
  });

  test('debugFillProperties names what differs from the defaults', () {
    final builder = DiagnosticPropertiesBuilder();
    const GlassStepper(value: 3, max: 9, onChanged: null, wraps: true).debugFillProperties(builder);
    final List<String> said = builder.properties
        .where((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode n) => n.toString())
        .toList();
    expect(said, containsAll(<String>['value: 3.0', 'max: 9.0', 'disabled', 'wraps']));
    expect(said.where((String s) => s.startsWith('min')), isEmpty, reason: 'a default was reported');
  });
}
