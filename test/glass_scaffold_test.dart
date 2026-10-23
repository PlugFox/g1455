// `GlassScaffold`: where the bars go, what the body is told, and whose host.
//
// `flutter test test/glass_scaffold_test.dart`
//
// No pixels: the scaffold draws nothing of its own, so what can be wrong with
// it is a rect or a number — the body's padding, a bar's box, how many hosts
// there are. The glass the bars draw is tested where the bars are.
//
// Breaks, each undone by swapping the string back:
//  - in `GlassScaffold.build`, `barMargin.resolve(direction)` ->
//    `barMargin.resolve(TextDirection.ltr)`: a directional margin's start
//    stays at the left under rtl;
//  - in `_GlassScaffoldLayout.performLayout`, `size.height - keyboard` ->
//    `size.height`: the keyboard arm finds the body running under it.

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

  testWidgets('over the keyboard the body ends at it and the action stands on it; the bottom bar stays under', (
    WidgetTester tester,
  ) async {
    for (final bool resize in <bool>[true, false]) {
      ({EdgeInsets padding, EdgeInsets insets})? told;
      await _mount(
        tester,
        keyboard: 300,
        GlassScaffold(
          resizeToAvoidBottomInset: resize,
          bottomBar: const SizedBox(key: kBottom, height: 60),
          floatingAction: const SizedBox(key: kAction, width: 50, height: 50),
          body: Builder(
            key: const Key('body'),
            builder: (BuildContext context) {
              told = (padding: MediaQuery.paddingOf(context), insets: MediaQuery.viewInsetsOf(context));
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final Rect body = tester.getRect(find.byKey(const Key('body')));
      if (resize) {
        expect(body, const Rect.fromLTWH(0, 0, 400, 800 - 300), reason: 'the body runs under the keyboard');
        expect(told!.insets.bottom, 0, reason: 'the body is told of a keyboard it already ends at');
        // The bar is under the keyboard, so nothing of it is left to pad for.
        expect(told!.padding.bottom, 0);
        expect(tester.getRect(find.byKey(kAction)).bottom, 800 - 300 - 16, reason: 'the action is under the keyboard');
      } else {
        expect(body, const Rect.fromLTWH(0, 0, 400, 800));
        expect(told!.insets.bottom, 300);
        expect(told!.padding.bottom, 8 + 60 + 8);
      }
      // The bar stays at the bottom, where the keyboard covers it, as a tab
      // bar does on iOS: its margin under it, the safe area gone with the
      // keyboard up.
      expect(tester.getRect(find.byKey(kBottom)).bottom, 800 - 8);
    }
  });

  testWidgets('the body\'s constraints carry the bottom bar\'s extent: equal while it is, and hashed alike', (
    WidgetTester tester,
  ) async {
    // The extent rides on the constraints, so a body is laid out again when
    // only the bar's height changed — and two that are equal are one key to a
    // cache keyed on constraints, as the framework's equal sizes are.
    Future<BoxConstraints> bodyUnder(double bar) async {
      late BoxConstraints seen;
      await _mount(
        tester,
        GlassScaffold(
          bottomBar: SizedBox(key: kBottom, height: bar),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              seen = constraints;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      return seen;
    }

    final BoxConstraints a = await bodyUnder(60);
    await _mount(tester, const SizedBox());
    final BoxConstraints again = await bodyUnder(60);
    final BoxConstraints taller = await bodyUnder(80);
    expect(identical(a, again), isFalse);
    expect(again, a);
    expect(again.hashCode, a.hashCode, reason: 'two equal constraints hash apart');
    expect(taller == a, isFalse, reason: 'a new bar height left the body\'s constraints equal');
    expect(a == BoxConstraints.tight(kScreen), isFalse, reason: 'the extent is not part of what is compared');
    expect(taller.biggest, a.biggest, reason: 'the arm is about the extent, not the size');
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

  testWidgets('a directional bar margin puts its start at the right, right to left', (WidgetTester tester) async {
    for (final TextDirection direction in TextDirection.values) {
      await _mount(
        tester,
        const GlassScaffold(
          barMargin: EdgeInsetsDirectional.fromSTEB(30, 8, 4, 8),
          topBar: SizedBox.expand(key: kTop),
          bottomBar: SizedBox(key: kBottom, height: 60),
          body: SizedBox.expand(),
        ),
        textDirection: direction,
      );
      final (double left, double right) = direction == TextDirection.rtl ? (4, 30) : (30, 4);
      for (final Key bar in <Key>[kTop, kBottom]) {
        final Rect box = tester.getRect(find.byKey(bar));
        expect((box.left, kScreen.width - box.right), (left, right), reason: '$bar, $direction');
      }
      expect(tester.getTopLeft(find.byKey(kTop)).dy, 47 + 8);
    }
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

/// [keyboard] is the keyboard's height: the bottom inset, which takes the
/// safe area's bottom padding with it, as the engine reports them.
Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  TextDirection textDirection = TextDirection.ltr,
  double keyboard = 0,
}) async {
  tester.view
    ..physicalSize = kScreen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: kScreen,
        padding: kSafe.copyWith(bottom: keyboard > 0 ? 0 : kSafe.bottom),
        viewPadding: kSafe,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: Directionality(textDirection: textDirection, child: child),
    ),
  );
  expect(_handleOf(tester) == null, find.byType(GlassHost).evaluate().isEmpty);
}
