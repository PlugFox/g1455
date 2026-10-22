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
//    finds the light grey on the sheet's opaque light glass;
//  - in `_GlassSwitchState._switchBody`, `widget.trackColor ??
//    glassSecondarySystemFill(label)` -> `?? glassSecondarySystemFill(const
//    Color(0xFF000000))`, or the same for `glassSystemGreen`, and in
//    `_sliderBody` for its fill and its track: the controls arm fails on dark
//    glass;
//  - in `_GlassSegmentedControlState.build`, `glassTertiarySystemFill(
//    glassAmbientLabel(context))` -> `glassTertiarySystemFill(const Color(
//    0xFF000000))`, or in `_thumb`, `_kDarkThumb` -> `const Color(0xFFFFFFFF)`:
//    the segmented arm fails on dark glass;
//  - in `_GlassTabBarState._look`, `widget.activeColor ?? glassSystemBlue(
//    ambient.color ?? …)` -> `?? const Color(0xFF007AFF)`; in
//    `_GlassTextFieldState.build`, `glassSystemBlue(label)` -> `const Color(
//    0xFF007AFF)`; in `_GlassSearchBarState.build`, Cancel's `glassSystemBlue(
//    glassAmbientLabel(context))` -> `const Color(0xFF007AFF)`: the blue arm
//    fails on dark glass.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint, RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Color kLightFill = Color(0x33787880);
const Color kDarkFill = Color(0x5C787880);
const Color kLightRed = Color(0xFFFF3B30);
const Color kDarkRed = Color(0xFFFF453A);

/// iOS's colours in light and in dark, for the controls' defaults.
const ({Color light, Color dark}) kSecondaryFill = (light: Color(0x29787880), dark: Color(0x52787880));
const ({Color light, Color dark}) kTertiaryFill = (light: Color(0x1F767680), dark: Color(0x3D767680));
const ({Color light, Color dark}) kGreen = (light: Color(0xFF34C759), dark: Color(0xFF30D158));
const ({Color light, Color dark}) kBlue = (light: Color(0xFF007AFF), dark: Color(0xFF0A84FF));
const ({Color light, Color dark}) kThumb = (light: Color(0xFFFFFFFF), dark: Color(0xFF636366));

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

  testWidgets('a switch\'s and a slider\'s tracks, green and blue are those of the glass they sit on', (
    WidgetTester tester,
  ) async {
    for (final (GlassFinish finish, bool dark) in _finishes) {
      Color pick(({Color light, Color dark}) c) => dark ? c.dark : c.light;
      for (final bool on in <bool>[false, true]) {
        await tester.pumpWidget(
          _App(
            finish: finish,
            home: Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GlassSwitch(value: on, onChanged: (_) {}),
                    SizedBox(width: 200, child: GlassSlider(value: 0.5, onChanged: (_) {})),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final Color track = on ? pick(kGreen) : pick(kSecondaryFill);
        expect(_stadiums(tester).first, track, reason: 'on ${finish.name}: the switch\'s track, ${on ? 'on' : 'off'}');
      }
      expect(
        _painted(tester, find.descendant(of: find.byType(GlassSlider), matching: find.byType(CustomPaint))),
        containsAllInOrder(<Color>[pick(kSecondaryFill), pick(kBlue)]),
        reason: 'on ${finish.name}: the slider\'s track and fill',
      );
    }
  });

  testWidgets('a segmented control\'s track and capsule are those of the label around it', (
    WidgetTester tester,
  ) async {
    for (final (GlassFinish finish, bool dark) in _finishes) {
      Color pick(({Color light, Color dark}) c) => dark ? c.dark : c.light;
      await tester.pumpWidget(
        _App(
          finish: finish,
          home: Center(
            child: GlassCard(
              child: SizedBox(
                width: 240,
                child: GlassSegmentedControl(
                  segments: const <Widget>[Text('Day'), Text('Week')],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder control = find.byType(GlassSegmentedControl);
      expect(
        _stadiums(tester, within: control),
        <Color?>[pick(kTertiaryFill)],
        reason: 'on ${finish.name}: the track',
      );
      expect(
        _painted(tester, find.descendant(of: control, matching: find.byType(CustomPaint))),
        contains(pick(kThumb)),
        reason: 'on ${finish.name}: the capsule',
      );
      // The capsule's ink reads on it: black on white, white on the dark grey.
      expect(_ink(tester, 'Day'), dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000));
    }
  });

  testWidgets('a selected tab, a caret and Cancel are systemBlue of their appearance', (WidgetTester tester) async {
    for (final (GlassFinish finish, bool dark) in _finishes) {
      final Color blue = dark ? kBlue.dark : kBlue.light;
      await tester.pumpWidget(
        _App(
          finish: finish,
          home: Builder(
            // Cancel stands beside the glass, in the page's label: dark glass
            // goes with a dark page.
            builder: (BuildContext context) => DefaultTextStyle.merge(
              style: TextStyle(color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(width: 360, child: GlassSearchBar(autofocus: true, onCancel: () {})),
                  SizedBox(
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
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_ink(tester, 'A'), blue, reason: 'on ${finish.name}: the selected tab');
      expect(tester.widget<EditableText>(find.byType(EditableText)).cursorColor, blue, reason: 'on ${finish.name}');
      expect(_ink(tester, 'Cancel'), blue, reason: 'on ${finish.name}: Cancel');
    }
  });
}

/// Dark glass and light, and whether it is the dark.
const List<(GlassFinish, bool)> _finishes = <(GlassFinish, bool)>[
  (GlassFinish.regularDark, true),
  (GlassFinish.regularLight, false),
];

/// The colours of the rounded rects [finder]'s painters draw, in order, made
/// from their 32-bit values: a fill faded by `withValues` compares equal to
/// the constant it was made from only so.
List<Color> _painted(WidgetTester tester, Finder finder) {
  final recorder = _RRectColours();
  for (final RenderCustomPaint box in tester.renderObjectList<RenderCustomPaint>(finder)) {
    box.painter?.paint(recorder, box.size);
  }
  return recorder.colours;
}

/// A canvas that keeps the colour of each rounded rect drawn on it.
class _RRectColours implements Canvas {
  final List<Color> colours = <Color>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => colours.add(Color(paint.color.toARGB32()));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The colour of every stadium-shaped fill on the screen, or [within] one
/// widget, in paint order.
List<Color?> _stadiums(WidgetTester tester, {Finder? within}) {
  final Finder stadium = find.byWidgetPredicate(
    (Widget w) =>
        w is DecoratedBox &&
        w.decoration is ShapeDecoration &&
        (w.decoration as ShapeDecoration).shape is StadiumBorder,
  );
  return tester
      .widgetList<DecoratedBox>(within == null ? stadium : find.descendant(of: within, matching: stadium))
      .map((DecoratedBox b) => (b.decoration as ShapeDecoration).color)
      .toList();
}

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
