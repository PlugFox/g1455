// Larger accessibility text (`MediaQuery.textScaler`) on the controls whose
// labels sit in a box that does not grow, and on the field, whose box does.
//
// `flutter test test/glass_text_scale_test.dart`
//
// What is claimed (#20): the tab bar's and the segmented control's labels stop
// at the default size, as UIKit's do, so nothing is cut mid-word — and a
// smaller text size is kept; the field grows with its line from 44, as a
// `UITextField` does, so large text is not pressed against its edge.
//
// Breaks, each undone by swapping the string back:
//  - in `GlassAtMostDefaultTextSize.build`, `clamp(maxScaleFactor: 1)` ->
//    `clamp(maxScaleFactor: 4)`: the tab bar and segmented arms find labels at
//    twice the size;
//  - in `_GlassTextFieldState._height`, `math.max(kGlassFieldHeight, line +
//    22)` -> `kGlassFieldHeight`: the field arm finds the line 44 tall in a
//    44-tall capsule;
//  - in `GlassAtMostDefaultTextSize.build`, the `data == null` pass-through
//    replaced by a clamp of a default `MediaQueryData`: the no-MediaQuery arm
//    finds one made up under the labels.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable, RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('a tab bar\'s labels stop at the default size, and keep a smaller one', (WidgetTester tester) async {
    for (final (double scale, double drawn) in <(double, double)>[(2, 1), (0.85, 0.85)]) {
      await _mount(
        tester,
        scale,
        SizedBox(
          width: 360,
          child: GlassTabBar(
            items: const <GlassTabItem>[
              GlassTabItem(label: 'Home', icon: Icons.home),
              GlassTabItem(label: 'Search', icon: Icons.search),
              GlassTabItem(label: 'Library', icon: Icons.library_music),
              GlassTabItem(label: 'Profile', icon: Icons.person),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      for (final label in <String>['Home', 'Library']) {
        expect(_scaleOf(tester, label), drawn, reason: 'at $scale: $label');
      }
    }
  });

  testWidgets('a segmented control\'s labels stop at the default size', (WidgetTester tester) async {
    await _mount(
      tester,
      2,
      SizedBox(
        width: 300,
        child: GlassSegmentedControl(
          segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    for (final label in <String>['Day', 'Week']) {
      expect(_scaleOf(tester, label), 1, reason: label);
    }
  });

  testWidgets('a segmented control with no MediaQuery above it lays its labels out as they are', (
    WidgetTester tester,
  ) async {
    // A `RawView`, which adds no MediaQuery: there is no text scale to clamp,
    // and the clamp passes its child through rather than ask for one.
    await tester.pumpWidget(
      RawView(
        view: tester.view,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            backdrop: const Color(0xFF406080),
            child: Center(
              child: SizedBox(
                width: 300,
                child: GlassSegmentedControl(
                  segments: const <Widget>[Text('Day'), Text('Week')],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
      wrapWithView: false,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(MediaQuery.maybeOf(tester.element(find.text('Day'))), isNull, reason: 'the clamp made a MediaQuery up');
    expect(_scaleOf(tester, 'Day'), 1);
  });

  testWidgets('a field grows with its line from 44, and keeps 11 above and below it', (WidgetTester tester) async {
    for (final scale in <double>[1, 2, 3]) {
      await _mount(
        tester,
        scale,
        SizedBox(
          width: 300,
          child: GlassTextField(controller: TextEditingController(text: 'Display name')),
        ),
      );
      final Rect field = tester.getRect(find.byType(GlassSurface));
      final Rect line = tester.getRect(find.byType(EditableText));
      final RenderEditable editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
      expect(editable.textScaler.scale(10) / 10, scale, reason: 'the field\'s text did not scale');
      if (scale == 1) {
        expect(field.height, kGlassFieldHeight, reason: 'at the default size the field is iOS\'s 44');
      } else {
        expect(field.height, greaterThan(kGlassFieldHeight), reason: 'at $scale the field did not grow');
      }
      expect(line.top - field.top, greaterThanOrEqualTo(10.99), reason: 'at $scale the line touches the top');
      expect(field.bottom - line.bottom, greaterThanOrEqualTo(10.99), reason: 'at $scale the line touches the bottom');
    }
  });

  testWidgets('a search bar\'s field grows with its text as a field does', (WidgetTester tester) async {
    await _mount(tester, 2, const SizedBox(width: 340, child: GlassSearchBar()));
    expect(tester.getRect(find.byType(GlassSurface)).height, greaterThan(kGlassFieldHeight));
  });
}

/// The text scale [label] is laid out at.
double _scaleOf(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).textScaler.scale(10) / 10;

Future<void> _mount(WidgetTester tester, double scale, Widget control) async {
  await tester.pumpWidget(
    MaterialApp(
      // A fresh app per scale: one state could keep a field's height.
      key: ValueKey<double>(scale),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: GlassHost(hardware: GlassHardware.appleMetal, backdrop: const Color(0xFF406080), child: child!),
      ),
      home: Center(child: control),
    ),
  );
  await tester.pumpAndSettle();
}
