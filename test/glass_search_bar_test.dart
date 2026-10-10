// GlassSearchBar: the clear button, Cancel, what a screen reader is told, and
// what the focus costs.
//
// `flutter test test/glass_search_bar_test.dart`
//
//  1. **The clear button is there while there is text,** empties the field,
//     reports `''` and keeps the focus.
//  2. **Cancel slides in on focus and out on blur;** a tap empties the field,
//     lets go of the focus and calls `onCancel`. Without
//     `showsCancelButton` there is none; under reduced motion it arrives in
//     one frame.
//  3. **Semantics:** the clear button and Cancel are buttons with labels.
//  4. **One surface; typing and the clear button are no capture,** with the
//     host's own control. And Cancel's slide, which narrows the glass, is
//     *counted* rather than assumed free: 16 captures over its 250 ms, none
//     after — and the control, the same focus under reduced motion, costs at
//     most one, so the 16 are the slide's. (A `GlassTravel` around the row
//     was tried and left the 16 where they were; see the file comment.)
//
// Breaks, each undone by swapping the string back:
//  - in `glass_search_bar.dart`, `value.text.isEmpty ? const SizedBox.shrink()`
//    -> `value.text.isNotEmpty && false ? const SizedBox.shrink()`: arm 1
//    finds a clear button over an empty field;
//  - `if (reduce) {` -> `if (!reduce) {`: arm 2's reduced-motion Cancel
//    slides, and arm 4's slide is a jump.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'component_scene.dart';

Widget _bar(Widget child) => SizedBox(width: 340, child: Overlay.wrap(child: child));

/// The clear button: the only `Semantics` labelled so.
Finder get _clear => find.bySemanticsLabel('Clear text');

void main() {
  testWidgets('the clear button is there while there is text, empties the field and keeps the focus', (
    WidgetTester tester,
  ) async {
    final changes = <String>[];
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final SemanticsHandle handle = tester.ensureSemantics();
    await ComponentScene.mount(
      tester,
      _bar(GlassSearchBar(controller: controller, focusNode: focus, onChanged: changes.add)),
    );
    expect(_clear, findsNothing, reason: 'a clear button over an empty field');
    expect(find.text('Search'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'glass');
    await tester.pump();
    expect(changes, <String>['glass']);
    expect(_clear, findsOneWidget, reason: 'no clear button over text');
    expect(focus.hasFocus, isTrue);

    await tester.tap(_clear);
    await tester.pump();
    expect(controller.text, '');
    expect(changes, <String>['glass', ''], reason: 'clearing reported nothing');
    expect(focus.hasFocus, isTrue, reason: 'clearing let go of the focus');
    expect(_clear, findsNothing);
    handle.dispose();
  });

  testWidgets('Cancel slides in on focus and out on blur; a tap empties, blurs and calls onCancel', (
    WidgetTester tester,
  ) async {
    var cancelled = 0;
    final changes = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final SemanticsHandle handle = tester.ensureSemantics();
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      _bar(GlassSearchBar(focusNode: focus, onChanged: changes.add, onCancel: () => cancelled++)),
    );
    double field() => tester.getSize(find.byType(GlassSurface)).width;
    final double wide = field();
    expect(find.text('Cancel').hitTestable(), findsNothing, reason: 'Cancel before the focus');

    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final double mid = field();
    await scene.frames(20);
    final double narrow = field();
    // ignore: avoid_print
    print('field width: $wide at rest, $mid mid-slide, $narrow with Cancel');
    expect(mid, lessThan(wide));
    expect(narrow, lessThan(mid), reason: 'Cancel arrived in one frame');
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Cancel')),
      matchesSemantics(label: 'Cancel', isButton: true, hasTapAction: true),
    );

    await tester.enterText(find.byType(EditableText), 'abc');
    await tester.tap(find.text('Cancel'));
    await scene.frames(20);
    expect(cancelled, 1);
    expect(changes.last, '', reason: 'Cancel left the query');
    expect(focus.hasFocus, isFalse, reason: 'Cancel kept the focus');
    expect(field(), wide, reason: 'Cancel did not slide out');

    // Reduced motion: there in one frame.
    await scene.pump(_bar(GlassSearchBar(focusNode: focus)), reduceMotion: true);
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(field(), narrow, reason: 'Cancel slid under reduced motion');
    focus.unfocus();
    await scene.frames(2);

    // None asked for: none, and the field keeps its width with the focus.
    await scene.pump(_bar(GlassSearchBar(focusNode: focus, showsCancelButton: false)));
    focus.requestFocus();
    await scene.frames(20);
    expect(find.text('Cancel'), findsNothing);
    expect(field(), wide);
    handle.dispose();
  });

  testWidgets('Cancel turned on while the field has the focus slides in', (WidgetTester tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      _bar(GlassSearchBar(focusNode: focus, showsCancelButton: false)),
    );
    focus.requestFocus();
    await scene.frames(20);
    expect(find.text('Cancel'), findsNothing);
    await scene.pump(_bar(GlassSearchBar(focusNode: focus)));
    await scene.frames(20);
    expect(find.text('Cancel').hitTestable(), findsOneWidget, reason: 'Cancel was turned on under the focus');
    // And off again, under the same focus.
    await scene.pump(_bar(GlassSearchBar(focusNode: focus, showsCancelButton: false)));
    await scene.frames(20);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('one surface; typing and clearing capture nothing; what Cancel\'s slide costs is counted', (
    WidgetTester tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final ComponentScene scene = await ComponentScene.mount(tester, _bar(GlassSearchBar(focusNode: focus)));
    expect(scene.surfaces, 1, reason: 'the clear button or Cancel is glass');

    // The slide: the field's glass narrows over still content.
    int recorded = scene.recorded;
    focus.requestFocus();
    await scene.frames(30);
    final int slide = scene.recorded - recorded;

    recorded = scene.recorded;
    final int painted = scene.paints.value;
    await tester.enterText(find.byType(EditableText), 'liquid');
    await scene.frames(10);
    expect(_clear, findsOneWidget);
    await tester.tap(_clear);
    await scene.frames(10);
    final int typed = scene.recorded - recorded;
    final int paints = scene.paints.value - painted;
    final int control = await scene.repaintBackdrop();
    // ignore: avoid_print
    print(
      'Cancel sliding in: $slide captures over 30 frames; typing and clearing: $typed, backdrop paints '
      '$paints; a repainted backdrop: $control',
    );
    expect(typed, 0, reason: 'typing or the clear button took a capture');
    expect(paints, 0, reason: 'typing repainted what is under the glass');
    expect(control, greaterThan(0), reason: 'the capture counter cannot move on this mount');
    // A glass whose box changes is retaken, so the slide costs a capture a
    // frame — and nothing after it.
    expect(slide, inInclusiveRange(10, 20), reason: 'the slide is not a capture a frame for 250 ms');
    recorded = scene.recorded;
    await scene.frames(30);
    expect(scene.recorded - recorded, 0, reason: 'the bar kept capturing after Cancel arrived');

    // The control that names the cause: the same focus under reduced motion,
    // where Cancel arrives in one frame, costs at most that frame.
    focus.unfocus();
    await scene.frames(30);
    await scene.pump(_bar(GlassSearchBar(focusNode: focus)), reduceMotion: true);
    recorded = scene.recorded;
    focus.requestFocus();
    await scene.frames(30);
    final int jump = scene.recorded - recorded;
    // ignore: avoid_print
    print('Cancel arriving under reduced motion: $jump captures');
    expect(jump, lessThanOrEqualTo(1), reason: 'the captures were not the slide\'s');
  });

  test('debugFillProperties', () {
    final builder = DiagnosticPropertiesBuilder();
    const GlassSearchBar(showsCancelButton: false, cancelLabel: 'Abbrechen').debugFillProperties(builder);
    final List<String> said = builder.properties
        .where((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode n) => n.toString())
        .toList();
    expect(said, containsAll(<String>['no cancel button', 'cancelLabel: "Abbrechen"']));
  });
}
