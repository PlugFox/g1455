import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455_example/main.dart';
import 'package:g1455_example/src/settings_menu.dart';

Future<void> _frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final Object? e = tester.takeException();
    expect(e, isNull);
  }
}

void main() {
  setUp(() {
    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
  });

  testWidgets('every page mounts its glass under one host, quietly', (WidgetTester tester) async {
    await tester.pumpWidget(const GlassExampleApp(initialLocation: '/demos/kit'));
    await _frames(tester, 4);
    expect(find.byType(GlassHost), findsOneWidget);
    for (final String tab in <String>['Controls', 'Blobs', 'Cards', 'Scroll']) {
      await tester.tap(find.descendant(of: find.byType(GlassTabBar), matching: find.text(tab)));
      await _frames(tester);
      expect(find.byType(GlassSurface), findsWidgets, reason: tab);
    }
  });

  // Also the example's control on the host's repaint assertion: every pick is a
  // `setState` above the `Scaffold`, which re-runs its layout at the same
  // geometry and repaints a host boundary that draws nothing of its own.
  // Without the guard in `_debugRepaintMintedPicture` this arm throws.
  testWidgets('every preset applies, and the host wears what it names', (WidgetTester tester) async {
    await tester.pumpWidget(const GlassExampleApp(initialLocation: '/demos/scroll'));
    await _frames(tester, 4);
    expect(_barLabel(GlassPreset.ultra.label), findsOneWidget, reason: 'the app opens on Ultra');
    await _openMenu(tester);
    for (final GlassPreset preset in GlassPreset.values) {
      await tester.tap(_inMenu(preset.label));
      await _frames(tester, 6);
      final GlassHost host = tester.widget(find.byType(GlassHost));
      final GlassSettings s = preset.settings;
      expect(host.finish, s.finishIn(Brightness.dark), reason: preset.label);
      expect(host.tier.tier, s.rendering.tier, reason: preset.label);
      expect(host.ripple?.viscosity, s.ripple.viscosity, reason: preset.label);
      expect(_barLabel(preset.label), findsOneWidget, reason: preset.label);
      expect(_inMenu(preset.description), findsOneWidget, reason: 'the menu closed, or names another preset');
    }
    // The barrier closes it.
    await tester.tapAt(const Offset(40, 500));
    await _frames(tester, 20);
    expect(_inMenu(GlassPreset.low.description), findsNothing);
  });

  testWidgets('a change makes the settings custom, and changing it back is the preset again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GlassExampleApp(initialLocation: '/demos/scroll'));
    await _frames(tester, 4);
    await _openMenu(tester);
    await tester.tap(_inMenu('Clear'));
    await _frames(tester, 6);
    expect(_barLabel('Custom'), findsOneWidget);
    expect(_inMenu('Your own settings'), findsOneWidget);
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).finish!.name, 'clear');

    // Custom is shown, not picked: tapping it changes nothing.
    await tester.tap(_inMenu('Custom'));
    await _frames(tester, 6);
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).finish!.name, 'clear');

    await tester.tap(_inMenu('Indigo'));
    await _frames(tester, 6);
    final GlassFinish tinted = tester.widget<GlassHost>(find.byType(GlassHost)).finish!;
    expect(tinted.name, 'clear', reason: 'a tint renamed the finish, so its damage table is lost');
    expect(tinted.tint.a, GlassFinish.clear.tint.a);
    expect(tinted.tint, isNot(GlassFinish.clear.tint));

    await tester.tap(_inMenu('Regular'));
    await _frames(tester, 2);
    await tester.tap(_inMenu('Neutral'));
    await _frames(tester, 6);
    expect(_barLabel(GlassPreset.ultra.label), findsOneWidget, reason: 'back at Ultra\'s settings, not Ultra');

    await tester.tap(_inMenu('Increased'));
    await _frames(tester, 6);
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).highContrast, isTrue);
    expect(_barLabel('Custom'), findsOneWidget);
  });

  testWidgets('the site opens dark whatever the platform says, and the menu changes it', (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const GlassExampleApp(initialLocation: '/demos/scroll'));
    await _frames(tester, 4);
    Brightness appearance() => MediaQuery.platformBrightnessOf(tester.element(find.byType(GlassHost)));
    GlassFinish? finish() => tester.widget<GlassHost>(find.byType(GlassHost)).finish;
    expect(appearance(), Brightness.dark);
    expect(finish(), GlassFinish.regularDark);

    await _openMenu(tester);
    // The first "Light" is the appearance's; the second the material's.
    await tester.tap(_inMenu('Light').first);
    await _frames(tester, 6);
    expect(appearance(), Brightness.light);
    expect(finish(), GlassFinish.regularLight, reason: 'the appearance picks the branch of .regular');
    await tester.tapAt(const Offset(40, 500));
    await _frames(tester, 20);

    await _openMenu(tester);
    // The first "System" is the appearance's; the second the contrast's.
    await tester.tap(_inMenu('System').first);
    await _frames(tester, 6);
    expect(appearance(), Brightness.light);
    expect(_barLabel(GlassPreset.ultra.label), findsOneWidget, reason: 'the appearance is not part of a preset');

    // A preset keeps the appearance.
    await tester.tap(_inMenu(GlassPreset.medium.label));
    await _frames(tester, 6);
    expect(appearance(), Brightness.light);
    expect(_barLabel(GlassPreset.medium.label), findsOneWidget);
  });

  testWidgets('a ripple from the menu, and a touch on the glass makes a wave', (WidgetTester tester) async {
    await tester.pumpWidget(const GlassExampleApp(initialLocation: '/demos/scroll'));
    await _frames(tester, 4);
    // Ultra, which is the one preset with a ripple.
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).ripple?.viscosity, 0.5);
    await _openMenu(tester);
    await tester.tap(_inMenu('Honey'));
    await _frames(tester, 6);
    expect(tester.widget<GlassHost>(find.byType(GlassHost)).ripple?.viscosity, 1);
    await tester.tapAt(const Offset(40, 500));
    await _frames(tester, 20);
    final Finder bar = find.byType(GlassTabBar);
    final RenderGlassSurface glass = tester
        .renderObjectList<RenderGlassSurface>(
          find.descendant(of: bar, matching: find.byType(GlassSurface)),
        )
        .first;
    await tester.tapAt(tester.getTopLeft(bar) + const Offset(30, 30));
    await _frames(tester, 10);
    expect(glass.rippleTicks, greaterThan(0), reason: 'the tab bar did not ripple');
  });
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await _frames(tester, 20);
}

Finder _inMenu(String text) => find.descendant(of: find.byType(GlassSettingsMenu), matching: find.text(text));

/// The preset's name on the app bar's button, which is outside the menu.
Finder _barLabel(String text) => find.descendant(of: find.byKey(kSettingsButtonKey), matching: find.text(text));
