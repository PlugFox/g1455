// The search field's drawn glyph and the button group's held cell: two small
// painters that must follow the state they draw.
//
// `flutter test test/glass_field_toolbar_test.dart`
//
//  1. **The magnifier takes the label colour the glass chose** (at 60%), and changes
//     with it when the backdrop changes — it is drawn rather than taken from
//     a font, so nothing else would recolour it.
//  2. **A held toolbar cell lights while held and only then**: a press that
//     slides off clears the light and runs nothing, where a tap runs the item.
//  3. **A ring or a light on a cell that is gone is dropped**: the last item
//     focused, or held, then the group shrunk — neither may stay on a cell
//     past the end. The ring's control is the same group not shrunk, which
//     keeps it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('the search magnifier is drawn in the label colour, and follows it to another backdrop', (
    WidgetTester tester,
  ) async {
    final submitted = <String>[];
    Future<void> mount(Color backdrop) => _mount(
      tester,
      backdrop,
      // Built at runtime, as an app that passes a callback does.
      // ignore: prefer_const_constructors
      GlassTextField.search(onSubmitted: submitted.add),
    );

    await mount(const Color(0xFF101014));
    final Color onDark = _magnifierColour(tester);
    final EditableText field = tester.widget(find.byType(EditableText));
    expect(field.textInputAction, TextInputAction.search);
    expect(field.keyboardType, TextInputType.text);
    expect(field.obscureText, isFalse);
    expect(find.text('Search'), findsOneWidget);
    expect(onDark, _labelOf(tester), reason: 'the glyph is not in the field\'s label colour');

    await mount(const Color(0xFFF4F4F8));
    final Color onLight = _magnifierColour(tester);
    expect(onLight, _labelOf(tester));
    expect(onLight == onDark, isFalse, reason: 'the backdrop change moved no label colour, so the arm sees nothing');

    await tester.enterText(find.byType(EditableText), 'glass');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, <String>['glass']);
  });

  testWidgets('a held toolbar cell lights while held; sliding off clears it and runs nothing', (
    WidgetTester tester,
  ) async {
    final pressed = <int>[];
    Future<void> mount(Color overlay) => _mount(
      tester,
      const Color(0xFF406080),
      GlassButtonGroup(
        pressedOverlay: overlay,
        items: <GlassToolbarItem>[
          GlassToolbarItem(
            icon: const SizedBox(key: ValueKey<int>(0)),
            onPressed: () => pressed.add(0),
          ),
          GlassToolbarItem(
            icon: const SizedBox(key: ValueKey<int>(1)),
            onPressed: () => pressed.add(1),
          ),
          const GlassToolbarItem(icon: SizedBox(key: ValueKey<int>(2)), onPressed: null),
        ],
      ),
    );
    await mount(const Color(0x40FFFFFF));
    expect(_overlay(tester), isNull);

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<int>(1))));
    await tester.pump(const Duration(milliseconds: 150));
    final dynamic held = _overlay(tester);
    expect(held, isNotNull, reason: 'a held cell is not lit');
    expect(held.index, 1);
    // A new overlay colour while held reaches the painter, and an equal one
    // does not ask for a repaint.
    final RenderCustomPaint box = tester.renderObject(
      find.descendant(of: find.byType(GlassButtonGroup), matching: find.byType(CustomPaint)).first,
    );
    await mount(const Color(0x40FFFFFF));
    expect(box.debugNeedsPaint, isFalse, reason: 'an equal overlay repainted the group');
    await mount(const Color(0x60FF0000));
    expect((_overlay(tester)! as dynamic).color, const Color(0x60FF0000));

    await finger.moveBy(const Offset(0, 200));
    await finger.up();
    await tester.pump();
    expect(_overlay(tester), isNull, reason: 'the light outlived the press');
    expect(pressed, isEmpty, reason: 'a press slid off the cell ran it');

    await tester.tap(find.byKey(const ValueKey<int>(1)));
    await tester.pump();
    expect(pressed, <int>[1], reason: 'the control: a tap runs the item');

    // A disabled cell neither lights nor runs.
    await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<int>(2))));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_overlay(tester), isNull);
  });

  testWidgets('a focused last item that is removed takes its ring with it', (WidgetTester tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    Widget group(int n) => GlassButtonGroup(
      items: <GlassToolbarItem>[
        for (var i = 0; i < n; i++)
          GlassToolbarItem(
            icon: SizedBox(key: ValueKey<int>(i)),
            onPressed: () {},
          ),
      ],
    );
    for (final int to in <int>[3, 2]) {
      await _mount(tester, const Color(0xFF406080), KeyedSubtree(key: ValueKey<int>(to), child: group(3)));
      // Backward from nothing focused: the last item is the first focused,
      // and nothing else in the group was — so the scope has no earlier item
      // to hand the focus back to when it goes.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      final dynamic ringed = _overlay(tester);
      expect(ringed, isNotNull, reason: 'tabbing to the last item showed no ring: the arm sees nothing');
      expect(ringed.focused, 2);
      await _mount(tester, const Color(0xFF406080), KeyedSubtree(key: ValueKey<int>(to), child: group(to)));
      final dynamic after = _overlay(tester);
      final int? focused = after?.focused as int?;
      // ignore: avoid_print
      print('ring after shrinking 3 -> $to: $focused');
      if (to == 3) {
        expect(focused, 2, reason: 'the control lost its ring with nothing removed');
      } else {
        expect(focused == null || focused < to, isTrue, reason: 'the ring stayed on removed cell $focused of $to');
      }
    }
  });

  testWidgets('a held last item that is removed takes its light with it', (WidgetTester tester) async {
    Widget group(int n) => GlassButtonGroup(
      items: <GlassToolbarItem>[
        for (var i = 0; i < n; i++)
          GlassToolbarItem(
            icon: SizedBox(key: ValueKey<int>(i)),
            onPressed: () {},
          ),
      ],
    );
    await _mount(tester, const Color(0xFF406080), group(3));
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<int>(2))));
    await tester.pump(const Duration(milliseconds: 150));
    expect((_overlay(tester)! as dynamic).index, 2, reason: 'the held cell is not lit: the arm sees nothing');
    await _mount(tester, const Color(0xFF406080), group(2));
    expect(_overlay(tester), isNull, reason: 'the light stayed on a removed cell');
    await finger.up();
  });
}

Future<void> _mount(WidgetTester tester, Color backdrop, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GlassHost(
        hardware: GlassHardware.appleMetal,
        backdrop: backdrop,
        child: ColoredBox(
          color: backdrop,
          child: Center(
            child: SizedBox(width: 300, child: Center(child: child)),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// The painter of the drawn magnifier: the only `CustomPaint` under the field
/// whose painter carries a colour of its own.
Color _magnifierColour(WidgetTester tester) {
  final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
    find.descendant(of: find.byType(GlassTextField), matching: find.byType(CustomPaint)),
  );
  final dynamic painter = paints
      .map((CustomPaint p) => p.painter)
      .firstWhere((CustomPainter? p) => p != null && p.runtimeType.toString() == '_MagnifierPainter');
  return painter.color as Color;
}

/// The colour the field gives its leading glyph: the label its glass resolved,
/// at the 60% it uses for a secondary glyph.
Color _labelOf(WidgetTester tester) {
  final GlassThemeData theme = GlassTheme.of(tester.element(find.byType(EditableText)));
  final Color label = theme.legibility().label;
  return label.withValues(alpha: label.a * 0.6);
}

CustomPainter? _overlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.descendant(of: find.byType(GlassButtonGroup), matching: find.byType(CustomPaint)))
    .map((CustomPaint p) => p.painter)
    .whereType<CustomPainter>()
    .where((CustomPainter p) => p.runtimeType.toString() == '_CellOverlay')
    .firstOrNull;
