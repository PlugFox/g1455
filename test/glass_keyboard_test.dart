// The keyboard: every control takes the focus, is worked by its keys, and
// shows a focus ring that is not glass — and what the ring costs the capture.
//
// `flutter test test/glass_keyboard_test.dart`
//
// Each key arm has its control: the same key before the control has the
// focus, which must do nothing, so a pass is the focus routing the key and not
// a key that reaches everything.
// The stepper's and the page control's arrows run both directions, so arrows
// that ignore it fail under rtl (`final int right = _rtl ? -1 : 1;` -> `= 1;`
// in the page control: the left arrow goes back).
//
// The ring's arm is the one about cost, and its control is the place the ring
// is drawn. A button's ring is drawn inside the button's surface, which no
// capture holds; a switch's around its track, behind a boundary of its own,
// which is ordinary content. Both are put beside the same panel of glass,
// close enough that the ring lies in the panel's capture: the switch's is
// retaken — the counter can see a ring — and the button's is not.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 300);

void main() {
  testWidgets('a button: Tab focuses it, Space and Enter press it', (WidgetTester tester) async {
    var pressed = 0;
    await _mount(tester, GlassButton(onPressed: () => pressed++, child: const Text('Go')));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, 0, reason: 'a key reached a button without the focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 2);
  });

  testWidgets('a disabled button takes no focus', (WidgetTester tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await _mount(tester, GlassButton(focusNode: node, child: const Text('Go')));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });

  testWidgets('a switch: Space and Enter toggle it', (WidgetTester tester) async {
    var on = false;
    await _mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            GlassSwitch(value: on, onChanged: (bool v) => setState(() => on = v)),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(on, isFalse, reason: 'a key reached a switch without the focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(on, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(on, isFalse);
  });

  testWidgets('a slider: the arrows step it, by a tenth or by a division', (WidgetTester tester) async {
    for (final (int? divisions, double step) in <(int?, double)>[(null, 0.1), (4, 0.25)]) {
      var value = 0.5;
      final changes = <double>[];
      await _mount(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => SizedBox(
            width: 300,
            child: GlassSlider(
              key: ValueKey<int?>(divisions),
              value: value,
              divisions: divisions,
              onChanged: (double v) => setState(() => value = v),
              onChangeEnd: changes.add,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 0.5, reason: '$divisions: a key reached a slider without the focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(0.5 + step, 1e-9), reason: '$divisions: right');
      // A frame between keys, as a held key's repeats have: the control is
      // the caller's, and steps from the value it was last built with.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value, closeTo(0.5 - step, 1e-9), reason: '$divisions: down twice');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, closeTo(0.5 - step, 1e-9), reason: '$divisions: up and left');
      expect(changes, hasLength(5), reason: '$divisions: each key is one whole change');
    }
  });

  testWidgets('a segmented control: the arrows select the segment beside', (WidgetTester tester) async {
    var selected = 1;
    await _mount(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => SizedBox(
          width: 300,
          child: GlassSegmentedControl(
            segments: const <Widget>[Text('A'), Text('B'), Text('C')],
            selectedIndex: selected,
            onSelected: (int i) => setState(() => selected = i),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 1, reason: 'a key reached the control without the focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 2, reason: 'past the last segment');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(selected, 0);
  });

  testWidgets('a stepper: the arrows step it, mirrored under rtl, and stop at a limit', (WidgetTester tester) async {
    for (final TextDirection direction in TextDirection.values) {
      var value = 5.0;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => GlassStepper(
            key: ValueKey<TextDirection>(direction),
            value: value,
            max: 7,
            onChanged: (double v) => setState(() => value = v),
          ),
        ),
        textDirection: direction,
      );
      // The arrow toward the plus glyph: rightward, unless the stepper runs
      // the other way.
      final LogicalKeyboardKey towardPlus = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowLeft;
      final LogicalKeyboardKey towardMinus = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowRight;
      await tester.sendKeyEvent(towardPlus);
      await tester.pump();
      expect(value, 5, reason: '$direction: a key reached a stepper without the focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(towardPlus);
      await tester.pump();
      expect(value, 6, reason: '$direction: toward the plus');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 7, reason: '$direction: up');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 7, reason: '$direction: past max');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(towardMinus);
      await tester.pump();
      expect(value, 5, reason: '$direction: down and toward the minus');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a page control: the arrows turn the page, mirrored under rtl, and stop at the ends', (
    WidgetTester tester,
  ) async {
    for (final TextDirection direction in TextDirection.values) {
      var page = 1;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => GlassPageControl(
            key: ValueKey<TextDirection>(direction),
            count: 3,
            currentPage: page,
            onPageChanged: (int p) => setState(() => page = p),
          ),
        ),
        textDirection: direction,
      );
      final LogicalKeyboardKey towardEnd = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowLeft;
      final LogicalKeyboardKey towardStart = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowRight;
      await tester.sendKeyEvent(towardEnd);
      await tester.pumpAndSettle();
      expect(page, 1, reason: '$direction: a key reached the control without the focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(towardEnd);
      await tester.pumpAndSettle();
      expect(page, 2, reason: '$direction: toward the end');
      await tester.sendKeyEvent(towardEnd);
      await tester.pumpAndSettle();
      expect(page, 2, reason: '$direction: past the last page');
      await tester.sendKeyEvent(towardStart);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(page, 0, reason: '$direction: toward the start and down');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(page, 1, reason: '$direction: up');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a disabled stepper and a display page control take no focus', (WidgetTester tester) async {
    for (final bool stepper in <bool>[true, false]) {
      final node = FocusNode();
      addTearDown(node.dispose);
      await _mount(
        tester,
        stepper
            ? GlassStepper(value: 5, onChanged: null, focusNode: node)
            : GlassPageControl(count: 3, focusNode: node),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isFalse, reason: stepper ? 'the disabled stepper' : 'the display');
      await tester.pumpWidget(const SizedBox());
    }
    // The control: the same node on an enabled one does take it.
    final node = FocusNode();
    addTearDown(node.dispose);
    await _mount(tester, GlassStepper(value: 5, onChanged: (_) {}, focusNode: node));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });

  testWidgets('a toolbar group: Tab walks its items, Enter presses the focused one', (WidgetTester tester) async {
    final pressed = <String>[];
    await _mount(
      tester,
      GlassButtonGroup(
        items: <GlassToolbarItem>[
          GlassToolbarItem(icon: const SizedBox.square(dimension: 20), label: 'a', onPressed: () => pressed.add('a')),
          GlassToolbarItem(icon: const SizedBox.square(dimension: 20), label: 'b', onPressed: () => pressed.add('b')),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, <String>['a', 'b']);
  });

  testWidgets('the ring shows on focus, and only the ring that is content costs a capture', (
    WidgetTester tester,
  ) async {
    final results = <String, ({int captures, int ringPixels})>{};
    for (final String control in <String>['button', 'switch', 'stepper', 'page control']) {
      final hostKey = GlobalKey();
      final Widget child = switch (control) {
        'button' => GlassButton(onPressed: () {}, child: const SizedBox(width: 40, height: 20)),
        'switch' => GlassSwitch(value: false, onChanged: (_) {}),
        'stepper' => GlassStepper(value: 5, onChanged: (_) {}),
        _ => GlassPageControl(count: 3, onPageChanged: (_) {}),
      };
      await _mount(tester, child, hostKey: hostKey, beside: true);
      final dynamic host = hostKey.currentState! as dynamic;
      final Uint8List before = await _shot(tester);
      final int recorded = host.recorded as int;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final Uint8List after = await _shot(tester);
      // The ring is the system blue; count the pixels that turned it.
      var ring = 0;
      for (var i = 0; i < after.length; i += 4) {
        final bool blue = after[i] < 40 && after[i + 1] > 110 && after[i + 1] < 150 && after[i + 2] > 230;
        final bool was = before[i] < 40 && before[i + 1] > 110 && before[i + 1] < 150 && before[i + 2] > 230;
        if (blue && !was) {
          ring++;
        }
      }
      results[control] = (captures: (host.recorded as int) - recorded, ringPixels: ring);
    }
    // ignore: avoid_print
    print('focus ring beside a panel: $results');
    expect(results['button']!.ringPixels, greaterThan(100), reason: 'the button showed no ring');
    expect(results['switch']!.ringPixels, greaterThan(100), reason: 'the switch showed no ring');
    expect(results['switch']!.captures, greaterThan(0), reason: 'a ring in the panel\'s capture was not seen');
    expect(results['button']!.captures, 0, reason: 'the button\'s ring was captured');
    // Glass controls both, ringed from inside their own surface as a button is.
    for (final String control in <String>['stepper', 'page control']) {
      expect(results[control]!.ringPixels, greaterThan(100), reason: 'the $control showed no ring');
      expect(results[control]!.captures, 0, reason: 'the $control\'s ring was captured');
    }
  });
}

final GlobalKey _shotKey = GlobalKey();

/// Mounts [control] at (100, 120) over a still screen, in a host; with
/// [beside], a panel of glass whose capture reaches over the control's edge.
Future<void> _mount(
  WidgetTester tester,
  Widget control, {
  GlobalKey? hostKey,
  bool beside = false,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen),
      child: Directionality(
        textDirection: textDirection,
        // What a `WidgetsApp` installs: Tab and the activation keys mean
        // nothing without them.
        child: Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            // The scope a navigator would give: key events start from the
            // primary focus, and with none they reach no shortcut at all.
            child: FocusScope(
              autofocus: true,
              child: Align(
                alignment: Alignment.topLeft,
                child: GlassHost(
                  key: hostKey ?? GlobalKey(),
                  hardware: GlassHardware.appleMetal,
                  child: RepaintBoundary(
                    key: _shotKey,
                    child: SizedBox.fromSize(
                      size: kScreen,
                      child: Stack(
                        children: <Widget>[
                          const Positioned.fill(child: ColoredBox(color: Color(0xFF404040))),
                          // Ending 2 px above the control: the ring is inside its
                          // capture, the control is not under it.
                          if (beside)
                            const Positioned(left: 60, top: 60, width: 200, height: 58, child: GlassSurface()),
                          Positioned(left: 100, top: 120, child: control),
                        ],
                      ),
                    ),
                  ),
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
