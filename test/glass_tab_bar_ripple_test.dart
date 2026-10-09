// A touch on the tab bar reaches the bar's glass, so a declared ripple answers
// it.
//
// `flutter test test/glass_tab_bar_ripple_test.dart`
//
// Found by the example's ripple test: when the minimizer moved the bar's press
// `Listener` from the bar's ancestor to a sibling over it, its opaque hit test
// ended at the listener, and the bar's glass never heard a touch. The arm
// counts both: the press still reaches the bar (a tap selects), and the glass
// ticks its ripple. The break, undone by swapping the string back: in
// `glass_tab_bar.dart`, the press listener's `HitTestBehavior.translucent` ->
// `HitTestBehavior.opaque` — the ripple count stays 0 and selection still
// works, which is why the selection alone could not see it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  for (final GlassTabBarMinimizeBehavior behavior in GlassTabBarMinimizeBehavior.values) {
    testWidgets('a tap ripples the bar and selects ($behavior)', (WidgetTester tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 400), devicePixelRatio: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassHost(
              hardware: GlassHardware.appleMetal,
              ripple: const GlassRipple(),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassTabBar(
                      minimizeBehavior: behavior,
                      selectedIndex: selected,
                      onSelected: (int i) => setState(() => selected = i),
                      items: const <GlassTabItem>[
                        GlassTabItem(icon: Icons.home, label: 'Home'),
                        GlassTabItem(icon: Icons.search, label: 'Search'),
                        GlassTabItem(icon: Icons.person, label: 'Profile'),
                      ],
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
      final Finder bar = find.byType(GlassTabBar);
      final RenderGlassSurface glass = tester
          .renderObjectList<RenderGlassSurface>(find.descendant(of: bar, matching: find.byType(GlassSurface)))
          .first;
      expect(glass.rippleTicks, 0);
      await tester.tap(find.text('Profile'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(glass.rippleTicks, greaterThan(0), reason: 'the bar did not ripple');
      expect(selected, 2, reason: 'the press did not reach the bar');
      await tester.pumpAndSettle();
    });
  }
}
