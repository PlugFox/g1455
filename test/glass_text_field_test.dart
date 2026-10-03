// A text field on glass: the caret blinks and the text changes, and neither
// is a capture.
//
// `flutter test test/glass_text_field_test.dart`
//
// Both are inside the surface's own subtree, which the capture skips and the
// layer watch excludes. The arm that could tell the two apart is the second
// one: the same EditableText *under* a glass it is not part of, where every
// blink is content under glass and must be seen — and is (4 records in two
// seconds). Without it, "0 records while blinking" would read the same on a
// host that saw nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('a focused field blinking over a still screen records nothing', (WidgetTester tester) async {
    final GlobalKey hostKey = GlobalKey();
    final controller = TextEditingController();
    final focus = FocusNode();
    await _mount(tester, hostKey, GlassTextField(controller: controller, focusNode: focus, placeholder: 'Type'));
    focus.requestFocus();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dynamic host = hostKey.currentState;
    final int before = host.recorded as int;
    // Two seconds of a caret: four blinks.
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final int blinking = (host.recorded as int) - before;
    // Typing: the text changes inside the glass.
    await tester.enterText(find.byType(EditableText), 'hello');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final int typed = (host.recorded as int) - before - blinking;
    // ignore: avoid_print
    print('field: recorded while blinking $blinking, while typing $typed');
    expect(blinking, 0, reason: 'the caret retook the proxy');
    expect(typed, 0, reason: 'typing retook the proxy');
    expect(find.text('Type'), findsNothing, reason: 'the placeholder stayed over the text');
    focus.dispose();
    controller.dispose();
  });

  testWidgets('the control: the same caret under somebody else\'s glass is seen', (WidgetTester tester) async {
    final GlobalKey hostKey = GlobalKey();
    final focus = FocusNode();
    final controller = TextEditingController(text: 'abc');
    await _mount(
      tester,
      hostKey,
      Stack(
        children: <Widget>[
          EditableText(
            controller: controller,
            focusNode: focus,
            style: const TextStyle(fontSize: 17, color: Color(0xFF000000)),
            cursorColor: const Color(0xFF007AFF),
            backgroundCursorColor: const Color(0xFF8E8E93),
          ),
          const Positioned.fill(child: GlassSurface(borderRadius: BorderRadius.zero)),
        ],
      ),
    );
    focus.requestFocus();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dynamic host = hostKey.currentState;
    final int before = host.recorded as int;
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final int blinking = (host.recorded as int) - before;
    // ignore: avoid_print
    print('control: recorded while blinking $blinking');
    expect(blinking, greaterThan(2), reason: 'a caret under glass blinked unseen');
    focus.dispose();
    controller.dispose();
  });

  testWidgets('the search preset says search and shows its placeholder', (WidgetTester tester) async {
    await _mount(tester, GlobalKey(), const GlassTextField.search());
    expect(find.text('Search'), findsOneWidget);
    final EditableText field = tester.widget(find.byType(EditableText));
    expect(field.textInputAction, TextInputAction.search);
  });
}

Future<void> _mount(WidgetTester tester, GlobalKey hostKey, Widget field) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        child: ColoredBox(
          color: const Color(0xFF406080),
          child: Center(child: SizedBox(width: 300, child: field)),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}
