// What a screen reader is told, and what it can do, for each control and
// modal that takes a tap: a name, a role, a state, and the action a sighted
// user's gesture stands for.
//
// `flutter test test/glass_semantics_test.dart`
//
// The tab bar's, the segmented control's and the switch's role and state are
// claimed beside their pixels, in their own tests; these are the rest, and the
// labels each control takes.
//
// Breaks, each undone by swapping the string back:
//  - `label: widget.semanticLabel,` dropped from the switch's or the slider's
//    `Semantics`: the label arm finds no node by that name;
//  - `onIncrease: _enabled && up != value ? () => _step(up) : null,` ->
//    `onIncrease: null,`: the slider arm finds no increase action;
//  - `ExcludeSemantics(excluding: widget.semanticLabel != null, ...)` ->
//    `excluding: false`: the button arm hears its icon's glyph too;
//  - `label: _barrierLabel,` dropped from the anchors' barrier: the menu and
//    popover arms find nothing to close them by;
//  - `String get barrierLabel => dismissLabel;` -> `=> 'Dismiss';`: the
//    sheet arm finds no barrier by the caller's name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('a switch and a slider say what they are for', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _App(
        home: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GlassSwitch(value: true, onChanged: (_) {}, semanticLabel: 'Wi-Fi'),
            SizedBox(
              width: 300,
              child: GlassSlider(value: 0.25, onChanged: (_) {}, semanticLabel: 'Volume'),
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(GlassSwitch)),
      isSemantics(label: 'Wi-Fi', hasToggledState: true, isToggled: true, isEnabled: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byType(GlassSlider)),
      isSemantics(label: 'Volume', isSlider: true, value: '25%'),
    );
    semantics.dispose();
  });

  testWidgets('a screen reader steps a slider by a tenth, start to end, and not past its ends', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final calls = <String>[];
    var value = 0.5;
    var enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _App(
        home: Center(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return SizedBox(
                width: 300,
                child: GlassSlider(
                  value: value,
                  semanticLabel: 'Volume',
                  onChangeStart: (double v) => calls.add('start $v'),
                  onChanged: enabled
                      ? (double v) {
                          calls.add('changed $v');
                          setState(() => value = v);
                        }
                      : null,
                  onChangeEnd: (double v) => calls.add('end $v'),
                ),
              );
            },
          ),
        ),
      ),
    );
    Finder slider() => find.byType(GlassSlider);
    expect(
      tester.getSemantics(slider()),
      isSemantics(
        value: '50%',
        increasedValue: '60%',
        decreasedValue: '40%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    tester.semantics.increase(find.semantics.byLabel('Volume'));
    await tester.pump();
    expect(value, closeTo(0.6, 1e-9));
    expect(calls, <String>['start 0.5', 'changed ${0.5 + 0.1}', 'end ${0.5 + 0.1}']);
    expect(tester.getSemantics(slider()), isSemantics(value: '60%'));
    expect(tester.takeException(), isNull);

    rebuild(() => value = 1);
    await tester.pump();
    expect(
      tester.getSemantics(slider()),
      isSemantics(value: '100%', hasIncreaseAction: false, hasDecreaseAction: true, decreasedValue: '90%'),
    );

    rebuild(() => enabled = false);
    await tester.pump();
    expect(
      tester.getSemantics(slider()),
      isSemantics(isEnabled: false, hasIncreaseAction: false, hasDecreaseAction: false),
    );
    semantics.dispose();
  });

  testWidgets('a button\'s semantic label speaks in place of its child', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassButton(
            semanticLabel: 'Settings',
            onPressed: () => pressed++,
            child: const Text('⚙'),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(GlassButton)),
      isSemantics(label: 'Settings', isButton: true, isEnabled: true, hasTapAction: true),
    );
    expect(find.semantics.byLabel('⚙'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Settings'));
    expect(pressed, 1);

    // Without one, the child speaks: the label is the button's own text.
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassButton(onPressed: () => pressed++, child: const Text('Save')),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(GlassButton)), isSemantics(label: 'Save', isButton: true));
    semantics.dispose();
  });

  testWidgets('a toolbar group\'s items are buttons by their labels', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final pressed = <String>[];
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassButtonGroup(
            items: <GlassToolbarItem>[
              GlassToolbarItem(icon: const Icon(Icons.undo), label: 'Undo', onPressed: () => pressed.add('Undo')),
              const GlassToolbarItem(icon: Icon(Icons.redo), label: 'Redo', onPressed: null),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.undo)),
      isSemantics(label: 'Undo', isButton: true, isEnabled: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.redo)),
      isSemantics(label: 'Redo', isButton: true, isEnabled: false, hasTapAction: false),
    );
    tester.semantics.tap(find.semantics.byLabel('Undo'));
    expect(pressed, <String>['Undo']);
    semantics.dispose();
  });

  testWidgets('an alert\'s actions are buttons, and one closes it', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassDialog<void>(
                context: context,
                builder: (BuildContext context) => GlassAlert(
                  title: const Text('Title'),
                  actions: <GlassAlertAction>[
                    const GlassAlertAction(label: 'Later'),
                    GlassAlertAction(label: 'OK', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('OK')), isSemantics(isButton: true, isEnabled: true));
    expect(tester.getSemantics(find.text('Later')), isSemantics(isButton: true, isEnabled: false));
    tester.semantics.tap(find.semantics.byLabel('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a sheet\'s barrier says the caller\'s label and closes it', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassSheet<void>(
                context: context,
                barrierLabel: 'Schließen',
                builder: (_) => const SizedBox(height: 200, child: Center(child: Text('sheet body'))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('Dismiss'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
    semantics.dispose();
  });

  testWidgets('an open menu\'s items are buttons, and its barrier closes it', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final chosen = <String>[];
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassMenuAnchor(
            items: <GlassMenuItem>[
              GlassMenuItem(label: 'Rename', onPressed: () => chosen.add('Rename')),
              const GlassMenuItem(label: 'Move'),
            ],
            builder: (BuildContext context, GlassMenuController c) => GlassButton(
              semanticLabel: 'More',
              onPressed: c.open,
              child: const Icon(Icons.more_horiz),
            ),
          ),
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('More'));
    await tester.pumpAndSettle();
    // The anchor is what the menu turned into: not there to be found twice.
    expect(find.semantics.byLabel('More'), findsNothing);
    expect(tester.getSemantics(find.text('Rename')), isSemantics(isButton: true, isEnabled: true));
    expect(tester.getSemantics(find.text('Move')), isSemantics(isButton: true, isEnabled: false));

    tester.semantics.tap(find.semantics.byLabel('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(chosen, isEmpty);
    expect(tester.takeException(), isNull);

    tester.semantics.tap(find.semantics.byLabel('More'));
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('Rename'));
    await tester.pumpAndSettle();
    expect(chosen, <String>['Rename']);
    expect(find.text('Rename'), findsNothing);
    semantics.dispose();
  });

  testWidgets('an open popover closes by its barrier\'s label', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassPopoverAnchor(
            width: 200,
            barrierLabel: 'Close',
            popoverBuilder: (_) => const SizedBox(height: 120, child: Center(child: Text('popover body'))),
            builder: (BuildContext context, GlassMenuController c) =>
                GlassButton(onPressed: c.open, child: const Text('Filters')),
          ),
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('popover body'), findsOneWidget);
    expect(find.semantics.byLabel('Dismiss'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('popover body'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

/// The host where a modal needs it: above the navigator.
class _App extends StatelessWidget {
  const _App({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) =>
        GlassHost(hardware: GlassHardware.appleMetal, backdrop: const Color(0xFF406080), child: child!),
    home: ColoredBox(color: const Color(0xFF406080), child: home),
  );
}
