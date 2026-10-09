import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart' show GlassProxyHandle, GlassProxyScope;
import 'package:g1455_example/src/catalog/catalog.dart';
import 'package:g1455_example/src/pages/home_showcase.dart';

Future<void> _frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
}

Showcase _scene(String title) => kShowcases.singleWhere((Showcase s) => s.title == title);

/// A scene as the gallery stages it: a tile of the gallery's height, under a
/// host, with the text scaled by [textScale].
Future<void> _mount(WidgetTester tester, String title, {double width = 343, double textScale = 1}) async {
  tester.view
    ..physicalSize = Size(width, 360) * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: GlassHost(child: child!),
      ),
      home: Material(
        type: MaterialType.transparency,
        child: Builder(builder: _scene(title).builder),
      ),
    ),
  );
  await _frames(tester, 40);
}

GlassProxyHandle _handle(WidgetTester tester) =>
    GlassProxyScope.maybeOf(tester.element(find.byType(GlassSurface).first))!;

/// What a scene spends on its backdrop: the host's captures, and the textures
/// a declared backdrop renders — a scene whose glass is all declared never
/// captures, so for it the first alone would be still whatever happened.
(int, int) _work(WidgetTester tester) => (
  _handle(tester).snapshots,
  GlassBackdrop.maybeOf(tester.element(find.byType(GlassSurface).first))?.renders ?? 0,
);

/// Idle frames after the scene has settled spend nothing on the backdrop.
Future<void> _quietAtRest(WidgetTester tester) async {
  await _frames(tester, 40);
  final (int, int) before = _work(tester);
  await _frames(tester, 60);
  expect(_work(tester), before, reason: 'a scene at rest captured or rendered its backdrop');
}

void main() {
  test('no page spells the package version out: it is read from the pubspec', () {
    // A literal agrees with the pubspec on the day it is written and on no
    // release after, and nothing renders differently when it goes stale.
    final String version = Site.version;
    final List<File> sources = <File>[
      for (final FileSystemEntity e in Directory('lib').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart') && !e.path.endsWith('.g.dart')) e,
    ];
    expect(sources.length, greaterThan(10), reason: 'the scan found no sources');
    final List<String> spelled = <String>[
      for (final File f in sources)
        if (f.readAsStringSync().contains(version)) f.path,
    ];
    expect(spelled, isEmpty, reason: '$version is written out by hand');
  });

  for (final String title in <String>['Shop', 'Onboarding', 'Library']) {
    for (final (double width, double scale) in const <(double, double)>[(343, 1), (560, 1), (343, 1.4)]) {
      testWidgets('$title mounts at $width wide, text ×$scale, without overflow, and is still at rest', (
        WidgetTester tester,
      ) async {
        await _mount(tester, title, width: width, textScale: scale);
        expect(find.byType(GlassSurface), findsWidgets);
        await _quietAtRest(tester);
      });
    }
  }

  // The controls on "still at rest", one per scene: in each, something does
  // move the quantity the check reads. Onboarding's is its swipe, below.
  testWidgets('Shop: a new finish renders the declaration again, and only that', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _mount(tester, 'Shop');
    final (int snapshots, int renders) = _work(tester);
    expect(renders, greaterThan(0), reason: 'the scene declares nothing');
    await tester.tap(find.bySemanticsLabel('Mint'));
    await _frames(tester, 20);
    final (int snapshotsAfter, int rendersAfter) = _work(tester);
    expect(rendersAfter, greaterThan(renders), reason: 'the counter does not count here');
    expect(snapshotsAfter, snapshots);
    await _quietAtRest(tester);
    semantics.dispose();
  });

  testWidgets('Library: a scroll under the glass captures', (WidgetTester tester) async {
    await _mount(tester, 'Library');
    final int before = _handle(tester).snapshots;
    await tester.drag(find.byType(ListView), const Offset(0, -120), kind: PointerDeviceKind.mouse);
    await _frames(tester, 20);
    expect(_handle(tester).snapshots, greaterThan(before), reason: 'the counter does not count here');
    await _quietAtRest(tester);
  });

  testWidgets('Shop: the stepper changes the quantity, the badge counts it, and nothing is captured', (
    WidgetTester tester,
  ) async {
    await _mount(tester, 'Shop');
    int badge() => tester.widget<GlassBadge>(find.byType(GlassBadge)).count!;
    expect(badge(), 1);
    expect(find.text('1 in bag · €129'), findsOneWidget);

    final Rect stepper = tester.getRect(find.byType(GlassStepper));
    await tester.tapAt(Offset(stepper.right - 16, stepper.center.dy));
    await _frames(tester);
    expect(badge(), 2, reason: 'the plus half did not step');
    expect(find.text('2 in bag · €258'), findsOneWidget);

    await tester.tapAt(Offset(stepper.left + 16, stepper.center.dy));
    await tester.tapAt(Offset(stepper.left + 16, stepper.center.dy));
    await _frames(tester);
    expect(badge(), 0);
    expect(find.text('Not in your bag'), findsOneWidget);

    // Every piece of glass samples the declaration: the control on that is
    // the counter, since the pixels would be the same over a capture.
    final List<RenderGlassSurface> surfaces = <RenderGlassSurface>[
      for (final Element e in find.byType(GlassSurface).evaluate())
        if (e.findRenderObject() case final RenderGlassSurface r) r,
    ];
    expect(surfaces, isNotEmpty);
    for (final RenderGlassSurface s in surfaces) {
      expect(s.readsDeclaredBackdrop, isTrue);
    }
    expect(_handle(tester).snapshots, 0, reason: 'a scene whose glass is all declared captured');
  });

  testWidgets('Onboarding: the dots follow a swipe, and Next and the dots turn the page', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _mount(tester, 'Onboarding');
    PageController pages() => tester.widget<PageView>(find.byType(PageView)).controller!;
    String said() => tester.getSemantics(find.byType(GlassPageControl)).value;
    expect(said(), 'Page 1 of 4');

    // The control on the scenes' "still at rest": a swipe does capture.
    final int before = _handle(tester).snapshots;
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await _frames(tester, 40);
    expect(_handle(tester).snapshots, greaterThan(before), reason: 'the counter does not count here');
    expect(pages().page, 1);
    expect(said(), 'Page 2 of 4', reason: 'the dots did not follow the swipe');

    await tester.tap(find.text('Next'));
    await _frames(tester, 40);
    expect(pages().page, 2);
    expect(said(), 'Page 3 of 4');

    // A tap on the dots, right of the current one, moves a page that way.
    final Rect dots = tester.getRect(find.byType(GlassPageControl));
    await tester.tapAt(Offset(dots.right - 6, dots.center.dy));
    await _frames(tester, 40);
    expect(pages().page, 3);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Start'));
    await _frames(tester, 40);
    expect(pages().page, 0);
    semantics.dispose();
  });

  testWidgets('Library: a scroll down folds the tab bar, a scroll up brings it back, and the search filters', (
    WidgetTester tester,
  ) async {
    await _mount(tester, 'Library');
    final ValueNotifier<bool> minimized = GlassTabBarMinimizer.maybeOf(tester.element(find.byType(GlassTabBar)))!;
    expect(minimized.value, isFalse);

    // A mouse, as on the site: a finger is left to the page around the tile.
    final Finder list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -200), kind: PointerDeviceKind.mouse);
    await _frames(tester, 40);
    expect(minimized.value, isTrue, reason: 'a scroll down did not fold the bar');
    await tester.drag(list, const Offset(0, 80), kind: PointerDeviceKind.mouse);
    await _frames(tester, 40);
    expect(minimized.value, isFalse, reason: 'a scroll up did not bring it back');

    // A finger does not scroll it.
    final double at = tester
        .state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)))
        .position
        .pixels;
    await tester.drag(list, const Offset(0, -200));
    await _frames(tester, 40);
    expect(
      tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable))).position.pixels,
      at,
    );

    await tester.enterText(
      find.descendant(of: find.byType(GlassSearchBar), matching: find.byType(EditableText)),
      'tides',
    );
    await _frames(tester, 30);
    expect(find.text('Saltwater Hymn'), findsOneWidget);
    expect(find.text('Harbour Lights'), findsOneWidget);
    expect(find.text('Paper Suns'), findsNothing);

    // A song tapped is the one in the accessory.
    await tester.tap(find.text('Harbour Lights'));
    await _frames(tester, 10);
    expect(find.text('Harbour Lights · The Low Tides'), findsOneWidget);
  });
}
