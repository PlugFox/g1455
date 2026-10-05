import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455_example/main.dart';
import 'package:g1455_example/src/widgets/site_icon.dart';
import 'package:g1455_example/src/app/routes.dart';
import 'package:g1455_example/src/catalog/catalog.dart';
import 'package:g1455_example/src/demos/demos.dart';
import 'package:g1455_example/src/pages/entry_page.dart';
import 'package:g1455_example/src/pages/home_page.dart';
import 'package:g1455_example/src/pages/home_showcase.dart';
import 'package:g1455_example/src/pages/not_found_page.dart';
import 'package:g1455_example/src/widgets/icons.dart';
import 'package:g1455_example/src/widgets/side_scroller.dart';
import 'package:squid/squid.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

Future<void> _frames(WidgetTester tester, [int n = 30, String? reason]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull, reason: reason);
  }
}

void _size(WidgetTester tester, Size logical) {
  tester.view
    ..physicalSize = logical * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  group('catalog', () {
    test('every page has a unique address, an icon, a summary and a guide', () {
      final Set<String> paths = <String>{};
      for (final Entry e in kEntries) {
        expect(paths.add(e.path), isTrue, reason: 'two pages at ${e.path}');
        expect(knownIconNames, contains(e.icon), reason: '${e.path}: unknown icon ${e.icon}');
        expect(e.summary, isNotEmpty, reason: e.path);
        expect(e.summary.length, lessThanOrEqualTo(220), reason: '${e.path}: too long for a meta description');
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(e.id), isTrue, reason: e.path);
        if (e.section != Section.demos) {
          expect(e.guide, isNotEmpty, reason: e.path);
        }
      }
      for (final Section s in Section.values) {
        expect(entriesOf(s), isNotEmpty, reason: '${s.id} has no pages');
      }
    });

    test('every component has a demo, code and an API table', () {
      for (final Entry e in entriesOf(Section.components)) {
        expect(hasDemo(e), isTrue, reason: e.path);
        expect(e.code, isNotNull, reason: e.path);
        expect(e.properties, isNotNull, reason: e.path);
        expect(e.api, isNotEmpty, reason: e.path);
      }
    });

    test('links inside the guides go to pages that exist', () {
      final Set<String> paths = <String>{for (final Entry e in kEntries) e.path};
      final link = RegExp(r'\]\((/[^)#?\s]*)');
      for (final Entry e in kEntries) {
        for (final RegExpMatch m in link.allMatches('${e.guide}\n${e.properties ?? ''}')) {
          expect(paths, contains(m.group(1)), reason: '${e.path} links to ${m.group(1)}');
        }
      }
    });

    test('API links follow dartdoc names', () {
      expect(Site.api('GlassSlider'), endsWith('/GlassSlider-class.html'));
      expect(Site.api('GlassTier'), endsWith('/GlassTier.html'));
      expect(Site.api('kGlassCapsule'), endsWith('/kGlassCapsule-constant.html'));
      expect(Site.api('showGlassDialog()'), endsWith('/showGlassDialog.html'));
      expect(Site.api('GlassTextField.search'), endsWith('/GlassTextField/GlassTextField.search.html'));
    });
  });

  group('addresses', () {
    test('every page opens from its own address, the tab included', () {
      for (final Entry e in kEntries) {
        final NavigationStack stack = stackFromUri(Uri.parse(e.path));
        expect(stack.first, isA<HomeRoute>());
        expect((stack.last as AppRoute).uri.path, e.path);
      }
      final NavigationStack code = stackFromUri(Uri.parse('${entriesOf(Section.components).first.path}?tab=code'));
      expect((code.last as EntryRoute).tab, EntryTab.code);
      expect((code.last as EntryRoute).uri.queryParameters['tab'], 'code');
    });

    test('a section opens its first page, and nonsense is not found', () {
      final NavigationStack section = stackFromUri(Uri.parse('/components/'));
      expect((section.last as EntryRoute).entry, entriesOf(Section.components).first);
      expect(stackFromUri(Uri.parse('/nope')).last, isA<NotFoundRoute>());
      expect(stackFromUri(Uri.parse('/components/nope')).last, isA<NotFoundRoute>());
      expect(stackFromUri(Uri.parse('/a/b/c')).last, isA<NotFoundRoute>());
      expect(stackFromUri(Uri.parse('/')).single, isA<HomeRoute>());
    });
  });

  group('pages', () {
    for (final Size size in const <Size>[Size(1440, 900), Size(375, 812)]) {
      testWidgets('the home page at ${size.width.toInt()} wide: every scene and every section', (
        WidgetTester tester,
      ) async {
        _size(tester, size);
        await tester.pumpWidget(const GlassExampleApp(initialLocation: '/'));
        await _frames(tester, 6);
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(GlassHost), findsOneWidget);
        // Built as it scrolls: the footer only once scrolled to, and every
        // scene and every section on the way builds and runs.
        final Finder page = find.descendant(of: find.byType(HomePage), matching: find.byType(CustomScrollView));
        Finder onPage(Finder finder) => find.descendant(of: page, matching: finder);
        expect(onPage(find.textContaining('MIT licensed')), findsNothing);
        final Finder scrollable = find.descendant(of: page, matching: find.byType(Scrollable)).first;
        for (final String title in <String>[
          for (final Showcase showcase in kShowcases) showcase.title,
          for (final Section s in Section.values) s.title,
        ]) {
          // Built is enough: the grid builds a little past the screen's edge.
          for (var i = 0; i < 40 && onPage(find.text(title)).evaluate().isEmpty; i++) {
            await tester.drag(scrollable, const Offset(0, -200));
            await _frames(tester, 2, title);
          }
          expect(onPage(find.text(title)), findsWidgets, reason: title);
        }
        await tester.scrollUntilVisible(onPage(find.textContaining('MIT licensed')), 400, scrollable: scrollable);
        await _frames(tester, 2);
        expect(onPage(find.text(kShowcases.first.title)), findsNothing);
      });
    }

    testWidgets('a row that scrolls sideways: a button at the end that has more, and a mouse drags it', (
      WidgetTester tester,
    ) async {
      _size(tester, const Size(1024, 900));
      await tester.pumpWidget(const GlassExampleApp(initialLocation: '/'));
      await _frames(tester, 10);
      // The test font is wider than any real one: the hero above the row is
      // taller than the window.
      final Finder page = find.descendant(of: find.byType(HomePage), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byType(SideScroller), 200, scrollable: page);
      // Out from under the site's bar, which floats over the top of the page.
      await tester.drag(page, const Offset(0, 300));
      await _frames(tester, 10);
      final Finder row = find.byType(SideScroller).first;
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.descendant(of: row, matching: find.byType(Scrollable))).position;
      double opacity(String tooltip) => tester
          .widget<AnimatedOpacity>(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(AnimatedOpacity)))
          .opacity;
      expect(position().maxScrollExtent, greaterThan(0), reason: 'the row fits: nothing to test');
      expect(opacity('More'), 1);
      expect(opacity('Back'), 0);

      await tester.tap(find.byTooltip('More'));
      await _frames(tester, 40);
      expect(position().pixels, greaterThan(0));
      expect(opacity('Back'), 1);

      final double before = position().pixels;
      final TestGesture mouse = await tester.startGesture(
        tester.getCenter(row) + const Offset(-200, -20),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(40, 0));
      await mouse.moveBy(const Offset(120, 0));
      await mouse.up();
      await _frames(tester, 40);
      expect(position().pixels, lessThan(before), reason: 'a mouse did not drag the row');
    });

    testWidgets('a deep link opens its page and its tab, and a tab is an address', (WidgetTester tester) async {
      _size(tester, const Size(1280, 900));
      final Entry entry = entriesOf(Section.components).firstWhere((Entry e) => e.code != null);
      await tester.pumpWidget(GlassExampleApp(initialLocation: '${entry.path}?tab=code'));
      await _frames(tester, 10);
      final EntryPage page = tester.widget(find.byType(EntryPage));
      expect(page.entry, entry);
      expect(page.tab, EntryTab.code);
      final Finder guide = find.descendant(of: find.byType(GlassSegmentedControl), matching: find.text('Guide'));
      await tester.ensureVisible(guide);
      await _frames(tester, 4);
      await tester.tap(guide);
      await _frames(tester, 20);
      expect(tester.widget<EntryPage>(find.byType(EntryPage)).tab, EntryTab.guide);
    });

    testWidgets('narrow: the navigation is a sheet behind the menu button', (WidgetTester tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(const GlassExampleApp(initialLocation: '/'));
      await _frames(tester, 6);
      await tester.tap(find.byWidgetPredicate((Widget w) => w is SiteIcon && w.icon == SFIcons.sf_line_3_horizontal));
      await _frames(tester, 30);
      // Near the top of the sheet, so it is on screen without a scroll.
      final Entry target = entriesOf(Section.start).elementAt(1);
      await tester.tap(find.text(target.title).last);
      await _frames(tester, 40);
      expect(tester.widget<EntryPage>(find.byType(EntryPage)).entry, target);
    });

    testWidgets('an unknown address is not found, and the way back is home', (WidgetTester tester) async {
      _size(tester, const Size(1024, 768));
      await tester.pumpWidget(const GlassExampleApp(initialLocation: '/nowhere'));
      await _frames(tester, 6);
      expect(find.byType(NotFoundPage), findsOneWidget);
      await tester.tap(find.text('Back to the overview'));
      await _frames(tester, 30);
      expect(find.byType(HomePage), findsOneWidget);
    });

    // Every page builds, its demo included, at a phone's width and a desktop's.
    for (final Size size in const <Size>[Size(375, 812), Size(1366, 900)]) {
      testWidgets('every page builds at ${size.width.toInt()} wide', (WidgetTester tester) async {
        _size(tester, size);
        for (final Entry e in kEntries) {
          await tester.pumpWidget(GlassExampleApp(key: ValueKey<String>(e.path), initialLocation: e.path));
          await _frames(tester, 4, e.path);
          expect(find.byType(GlassHost), findsOneWidget, reason: e.path);
        }
      });
    }
  });
}
