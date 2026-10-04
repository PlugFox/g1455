import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455_example/main.dart';
import 'package:g1455_example/src/catalog/catalog.dart';
import 'package:g1455_example/src/widgets/selection.dart';

Future<void> _frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
}

/// Lets a toast run out, so no timer outlives the test.
Future<void> _settle(WidgetTester tester) => _frames(tester, 160);

void _size(WidgetTester tester, Size logical) {
  tester.view
    ..physicalSize = logical * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// What the app put on the clipboard, by the platform channel.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

const String _title = 'Opened on Medium settings';

Finder _barLabel(String text) => find.descendant(of: find.byKey(kSettingsButtonKey), matching: find.text(text));

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(const GlassExampleApp(initialLocation: '/', opensReduced: true));
  await _frames(tester, 20);
}

void main() {
  group('the reduced-quality notice', () {
    testWidgets('is shown over Medium, and turning the glass on picks High', (WidgetTester tester) async {
      _size(tester, const Size(1280, 800));
      await _open(tester);
      expect(find.text(_title), findsOneWidget);
      expect(_barLabel(GlassPreset.medium.label), findsOneWidget);

      await tester.tap(find.text('Turn the glass on'));
      await _frames(tester, 30);
      expect(find.text(_title), findsNothing);
      expect(_barLabel(GlassPreset.high.label), findsOneWidget);
    });

    testWidgets('keeping Medium closes it and changes nothing', (WidgetTester tester) async {
      _size(tester, const Size(1280, 800));
      await _open(tester);
      await tester.tap(find.text('Keep Medium'));
      await _frames(tester, 30);
      expect(find.text(_title), findsNothing);
      expect(_barLabel(GlassPreset.medium.label), findsOneWidget);
    });

    testWidgets('copies the address and says so', (WidgetTester tester) async {
      _size(tester, const Size(1280, 800));
      final List<String> copied = _clipboard(tester);
      await _open(tester);
      await tester.tap(find.text('Copy link'));
      await _frames(tester, 30);
      expect(copied, <String>[Uri.base.toString()]);
      expect(find.text(_title), findsNothing);
      expect(find.text('Link copied: paste it into Chrome'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('scrolls to its buttons on a short window with large text', (WidgetTester tester) async {
      _size(tester, const Size(640, 280));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester);
      expect(find.text(_title), findsOneWidget);

      final Finder keep = find.text('Keep Medium');
      await tester.scrollUntilVisible(
        keep,
        60,
        scrollable: find.descendant(of: find.byType(GlassSurface), matching: find.byType(Scrollable)).last,
      );
      await _frames(tester, 4);
      await tester.tap(keep);
      await _frames(tester, 30);
      expect(find.text(_title), findsNothing);
    });
  });

  group('copying a selection', () {
    testWidgets('from a page header copies, clears and says so', (WidgetTester tester) async {
      _size(tester, const Size(1280, 800));
      final List<String> copied = _clipboard(tester);
      final Entry entry = entriesOf(Section.components).first;
      await tester.pumpWidget(GlassExampleApp(initialLocation: entry.path));
      await _frames(tester, 20);

      // The header's, not the app bar's or the menu's.
      final Finder title = find.descendant(of: find.byType(SiteSelectionArea), matching: find.text(entry.title));
      await tester.longPress(title);
      await _frames(tester, 10);
      await tester.tap(find.text('Copy'));
      await _frames(tester, 10);

      expect(copied, hasLength(1));
      expect(entry.title, contains(copied.single));
      expect(find.text('Copied'), findsOneWidget);
      expect(find.text('Copy'), findsNothing, reason: 'the menu stayed open');
      await _settle(tester);
    });

    testWidgets('from a guide copies, clears and says so', (WidgetTester tester) async {
      _size(tester, const Size(1280, 800));
      final List<String> copied = _clipboard(tester);
      final Entry entry = entriesOf(Section.components).first;
      await tester.pumpWidget(GlassExampleApp(initialLocation: entry.path));
      await _frames(tester, 20);

      final Finder prose = find.byType(MarkdownWidget).first;
      await tester.ensureVisible(prose);
      await _frames(tester, 10);
      await tester.longPressAt(tester.getTopLeft(prose) + const Offset(12, 10));
      await _frames(tester, 10);
      await tester.tap(find.text('Copy'));
      await _frames(tester, 10);

      expect(copied, hasLength(1));
      expect(copied.single, isNotEmpty);
      expect(find.text('Copied'), findsOneWidget);
      expect(find.text('Copy'), findsNothing, reason: 'the menu stayed open');
      await _settle(tester);
    });
  });
}
