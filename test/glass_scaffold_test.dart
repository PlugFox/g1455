// `GlassScaffold`: where the bars go, what the body is told, and whose host.
//
// `flutter test test/glass_scaffold_test.dart`
//
// No pixels: the scaffold draws nothing of its own, so what can be wrong with
// it is a rect or a number — the body's padding, a bar's box, how many hosts
// there are. The glass the bars draw is tested where the bars are.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 800);
const EdgeInsets kSafe = EdgeInsets.only(top: 47, bottom: 34);

const Key kTop = Key('top');
const Key kBottom = Key('bottom');
const Key kAction = Key('action');

/// The top bar's extent: the safe area, the margin above, the bar and the gap.
const double kTopExtent = 47 + 8 + kGlassScaffoldBarHeight + 8;

/// The bottom bar's: the gap above it, the bar, and the safe area under it.
const double kBottomExtent = 8 + 60 + 34;

void main() {
  testWidgets('the bars sit inside the safe area and the body is told their extents', (WidgetTester tester) async {
    EdgeInsets? told;
    await _mount(
      tester,
      GlassScaffold(
        topBar: const SizedBox.expand(key: kTop),
        bottomBar: const SizedBox(key: kBottom, height: 60),
        floatingAction: const SizedBox(key: kAction, width: 50, height: 50),
        body: Builder(
          builder: (BuildContext context) {
            told = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    expect(told, const EdgeInsets.only(top: kTopExtent, bottom: kBottomExtent));
    expect(tester.getRect(find.byKey(kTop)), const Rect.fromLTWH(12, 47 + 8, 400 - 24, kGlassScaffoldBarHeight));
    expect(tester.getRect(find.byKey(kBottom)), const Rect.fromLTWH(12, 800 - 34 - 60, 400 - 24, 60));
    expect(
      tester.getRect(find.byKey(kAction)),
      const Rect.fromLTWH(400 - 16 - 50, 800 - kBottomExtent - 16 - 50, 50, 50),
    );
  });

  testWidgets('the body fills the screen, starts below the top bar and scrolls under it', (
    WidgetTester tester,
  ) async {
    await _mount(
      tester,
      GlassScaffold(
        topBar: const SizedBox.expand(key: kTop),
        bottomBar: const SizedBox(key: kBottom, height: 60),
        body: ListView.builder(
          itemCount: 40,
          itemExtent: 80,
          itemBuilder: (BuildContext context, int i) => SizedBox(key: ValueKey<int>(i)),
        ),
      ),
    );

    expect(tester.getRect(find.byType(ListView)), Offset.zero & kScreen);
    expect(tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dy, kTopExtent);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<int>(1))).dy,
      lessThan(kTopExtent),
      reason: 'the list does not scroll under the bar',
    );

    // And at the far end the last row ends above the bottom bar, not under it.
    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byKey(const ValueKey<int>(39))).dy, 800 - kBottomExtent);
  });

  testWidgets('without bars the body is told the safe area, and the action sits above it', (
    WidgetTester tester,
  ) async {
    EdgeInsets? told;
    await _mount(
      tester,
      GlassScaffold(
        floatingAction: const SizedBox(key: kAction, width: 50, height: 50),
        body: Builder(
          builder: (BuildContext context) {
            told = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(told, kSafe);
    expect(find.byType(GlassScrollEdge), findsNothing);
    expect(tester.getBottomRight(find.byKey(kAction)), const Offset(400 - 16, 800 - 34 - 16));
  });

  testWidgets('right to left, the action is at the left', (WidgetTester tester) async {
    await _mount(
      tester,
      const GlassScaffold(
        floatingAction: SizedBox(key: kAction, width: 50, height: 50),
        body: SizedBox.expand(),
      ),
      textDirection: TextDirection.rtl,
    );
    expect(tester.getTopLeft(find.byKey(kAction)).dx, 16);
  });

  testWidgets('the top bar stands in a soft scroll edge by default, lifted alone without one', (
    WidgetTester tester,
  ) async {
    await _mount(
      tester,
      const GlassScaffold(
        topBar: SizedBox.expand(key: kTop),
        body: SizedBox.expand(),
      ),
    );
    final GlassScrollEdge edge = tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge));
    expect(edge.side, GlassScrollEdgeSide.top);
    expect(edge.style, GlassScrollEdgeStyle.soft);
    expect(edge.extent, kTopExtent);
    expect(find.ancestor(of: find.byKey(kTop), matching: find.byType(GlassAbove)), findsOneWidget);

    await _mount(
      tester,
      const GlassScaffold(
        topBar: SizedBox.expand(key: kTop),
        scrollEdge: null,
        body: SizedBox.expand(),
      ),
    );
    expect(find.byType(GlassScrollEdge), findsNothing);
    expect(find.ancestor(of: find.byKey(kTop), matching: find.byType(GlassAbove)), findsOneWidget);
    expect(tester.getRect(find.byKey(kTop)), const Rect.fromLTWH(12, 47 + 8, 400 - 24, kGlassScaffoldBarHeight));
  });

  testWidgets('the bottom bar and the action are lifted over the body', (WidgetTester tester) async {
    await _mount(
      tester,
      const GlassScaffold(
        bottomBar: SizedBox(key: kBottom, height: 60),
        floatingAction: SizedBox(key: kAction, width: 50, height: 50),
        body: SizedBox.expand(),
      ),
    );
    expect(find.ancestor(of: find.byKey(kBottom), matching: find.byType(GlassAbove)), findsOneWidget);
    expect(find.ancestor(of: find.byKey(kAction), matching: find.byType(GlassAbove)), findsOneWidget);
  });

  testWidgets('it mounts a host only where there is none, unless told', (WidgetTester tester) async {
    const Widget scaffold = GlassScaffold(body: SizedBox.expand());

    await _mount(tester, scaffold);
    expect(find.byType(GlassHost), findsOneWidget, reason: 'no host was mounted with none above');

    await _mount(tester, const GlassHost(child: scaffold));
    expect(find.byType(GlassHost), findsOneWidget, reason: 'a second host was mounted under the first');

    await _mount(tester, const GlassHost(child: GlassScaffold(host: true, body: SizedBox.expand())));
    expect(find.byType(GlassHost), findsNWidgets(2));

    await _mount(tester, const GlassScaffold(host: false, body: SizedBox.expand()));
    expect(find.byType(GlassHost), findsNothing);
  });

  for (final bool ancestor in <bool>[false, true]) {
    testWidgets(
      'a bar and a tab bar over a list draw glass ${ancestor ? 'under a host above' : 'under its own host'}',
      (
        WidgetTester tester,
      ) async {
        var tab = 0;
        final Widget scaffold = StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => GlassScaffold(
            topBar: const GlassBar(child: Text('Library')),
            bottomBar: GlassTabBar(
              items: const <GlassTabItem>[
                GlassTabItem(icon: Icons.home, label: 'Home'),
                GlassTabItem(icon: Icons.search, label: 'Search'),
              ],
              selectedIndex: tab,
              onSelected: (int i) => setState(() => tab = i),
            ),
            body: ListView.builder(
              itemCount: 40,
              itemExtent: 80,
              itemBuilder: (BuildContext context, int i) =>
                  ColoredBox(color: Color.lerp(const Color(0xFF223355), const Color(0xFFCC8844), i / 40)!),
            ),
          ),
        );
        await _mount(tester, ancestor ? GlassHost(child: scaffold) : scaffold);
        await tester.pump();
        await tester.pump();
        expect(find.byType(GlassHost), findsOneWidget);

        final List<RenderGlassSurface> surfaces = tester
            .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
            .toList();
        final RenderGlassSurface bar = tester.renderObject<RenderGlassSurface>(
          find.ancestor(of: find.text('Library'), matching: find.byType(GlassSurface)),
        );
        expect(surfaces, contains(bar));
        expect(bar.paintsWithProxy, greaterThan(0), reason: 'the top bar never drew glass');

        // The bottom bar's glass: the tab bar's own, not its resting drop.
        final RenderGlassSurface tabBar = tester.renderObject<RenderGlassSurface>(
          find.descendant(of: find.byType(GlassTabBar), matching: find.byType(GlassSurface)).first,
        );
        expect(tabBar.paintsWithProxy, greaterThan(0), reason: 'the tab bar never drew glass');

        // And a tap on a tab still reaches the tab bar through the scaffold.
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
        expect(tab, 1);
      },
    );
  }
}

GlassProxyHandle? _handleOf(WidgetTester tester) =>
    tester.widgetList<GlassProxyScope>(find.byType(GlassProxyScope)).firstOrNull?.handle;

Future<void> _mount(WidgetTester tester, Widget child, {TextDirection textDirection = TextDirection.ltr}) async {
  tester.view
    ..physicalSize = kScreen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, padding: kSafe, viewPadding: kSafe),
      child: Directionality(textDirection: textDirection, child: child),
    ),
  );
  expect(_handleOf(tester) == null, find.byType(GlassHost).evaluate().isEmpty);
}
