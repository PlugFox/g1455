// The fills and greys laid on glass that is not glass — a tab bar's resting
// capsule, an alert's action capsules, a destructive red, a sheet's grabber —
// in the appearance of the glass they lie on, as iOS draws each of them.
//
// `flutter test test/glass_appearance_fills_test.dart`
//
// Each arm runs on dark glass and on light, and the light arm is the control:
// a colour fixed for one appearance passes it and fails the other.
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassTabBarState._content`, `glassSystemFill(DefaultTextStyle.of(
//    context).style.color ?? …)` -> `glassSystemFill(const Color(0xFF000000))`:
//    the capsule arm finds the light fill on dark glass;
//  - in `_AlertButtonState.build`, `glassSystemFill(widget.label)` ->
//    `glassSystemFill(const Color(0xFF000000))`, or `glassSystemRed(widget
//    .label)` -> `const Color(0xFFFF3B30)`: the alert arm fails on dark glass;
//  - in `_GlassMenuAnchorState._content`, `glassSystemRed(DefaultTextStyle.of(
//    context).style.color!)` -> `glassSystemRed(const Color(0xFF000000))`: the
//    menu arm fails on dark glass;
//  - in `_GlassSheet.build`, the grabber's `extent <= 0 ? route.finish :
//    GlassFinish.lerp(base, large, extent)` -> `route.finish`: the large arm
//    finds the light grey on the sheet's opaque light glass.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Color kLightFill = Color(0x33787880);
const Color kDarkFill = Color(0x5C787880);
const Color kLightRed = Color(0xFFFF3B30);
const Color kDarkRed = Color(0xFFFF453A);

/// Dark glass and light, each with the fill and red that go on it.
const List<(GlassFinish, Color, Color)> kAppearances = <(GlassFinish, Color, Color)>[
  (GlassFinish.regularDark, kDarkFill, kDarkRed),
  (GlassFinish.regularLight, kLightFill, kLightRed),
];

void main() {
  testWidgets('a tab bar\'s resting capsule is systemFill of the bar\'s appearance', (WidgetTester tester) async {
    for (final (GlassFinish finish, Color fill, Color _) in kAppearances) {
      await tester.pumpWidget(
        _App(
          finish: finish,
          home: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: GlassTabBar(
                items: const <GlassTabItem>[
                  GlassTabItem(label: 'A', icon: Icons.circle),
                  GlassTabItem(label: 'B', icon: Icons.circle),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_stadiums(tester), <Color?>[fill], reason: 'on ${finish.name}');
    }
  });

  testWidgets('an alert\'s action capsules are systemFill of its appearance, and its red is systemRed', (
    WidgetTester tester,
  ) async {
    for (final (GlassFinish finish, Color fill, Color red) in kAppearances) {
      await tester.pumpWidget(
        _App(
          finish: finish,
          home: Builder(
            builder: (BuildContext context) => Center(
              child: GestureDetector(
                onTap: () => showGlassDialog<void>(
                  context: context,
                  builder: (BuildContext context) => GlassAlert(
                    title: const Text('Title'),
                    actions: <GlassAlertAction>[
                      GlassAlertAction(label: 'Cancel', onPressed: () {}),
                      GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () {}),
                    ],
                  ),
                ),
                child: const Text('open alert'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open alert'));
      await tester.pumpAndSettle();
      expect(_stadiums(tester), <Color?>[fill, fill], reason: 'on ${finish.name}: the action capsules');
      expect(_ink(tester, 'Delete'), red, reason: 'on ${finish.name}: the destructive label');
    }
  });

  testWidgets('a menu\'s destructive row is systemRed of its appearance', (WidgetTester tester) async {
    for (final (GlassFinish finish, Color _, Color red) in kAppearances) {
      await tester.pumpWidget(
        _App(
          finish: finish,
          home: Center(
            child: GlassMenuAnchor(
              items: <GlassMenuItem>[GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: () {})],
              builder: (BuildContext context, GlassMenuController c) =>
                  GestureDetector(onTap: c.open, child: const Text('open menu')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open menu'));
      await tester.pumpAndSettle();
      expect(_ink(tester, 'Delete'), red, reason: 'on ${finish.name}');
    }
  });

  testWidgets('a sheet\'s grabber follows the finish drawn at its detent, not the one it opened in', (
    WidgetTester tester,
  ) async {
    // Clear glass over black reads dark, so a white label and the light grey;
    // its large finish is its tint at full alpha, opaque white, which reads
    // light — so the grabber at large is the dark grey.
    for (final (GlassSheetDetent detent, Color grey) in <(GlassSheetDetent, Color)>[
      (GlassSheetDetent.medium, kGlassDisabledLightLabel),
      (GlassSheetDetent.large, kGlassDisabledDarkLabel),
    ]) {
      await tester.pumpWidget(
        _App(
          key: ValueKey<GlassSheetDetent>(detent),
          backdrop: const Color(0xFF000000),
          home: Builder(
            builder: (BuildContext context) => Center(
              child: GestureDetector(
                onTap: () => showGlassSheet<void>(
                  context: context,
                  finish: GlassFinish.clear,
                  detents: const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
                  initialDetent: detent,
                  builder: (_) => const SizedBox(height: 200, child: Center(child: Text('sheet'))),
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(_stadiums(tester), <Color?>[grey], reason: 'at ${detent.name}');
    }
  });
}

/// The colour of every stadium-shaped fill on the screen, in paint order.
List<Color?> _stadiums(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is StadiumBorder,
      ),
    )
    .map((DecoratedBox b) => (b.decoration as ShapeDecoration).color)
    .toList();

/// The colour [label] is drawn in.
Color? _ink(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

class _App extends StatelessWidget {
  const _App({super.key, required this.home, this.finish, this.backdrop = const Color(0xFF406080)});

  final Widget home;
  final GlassFinish? finish;
  final Color backdrop;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // A fresh app per finish, so no route or state is carried across.
    key: ValueKey<String?>(finish?.name),
    builder: (BuildContext context, Widget? child) =>
        GlassHost(hardware: GlassHardware.appleMetal, finish: finish, backdrop: backdrop, child: child!),
    home: home,
  );
}
