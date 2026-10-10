// The modals' smaller contracts: how an alert lays out its actions, what a
// press that slides off a button does, the menu controller seen from outside
// its builder, and a sheet released short of dismissal.
//
// `flutter test test/glass_modal_controls_test.dart`
//
// `glass_modal_test.dart` covers the levels a modal stacks and the dismissal
// paths. These are the paths it does not take: each is something an app does
// routinely and that looks right until the one case where it does not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  testWidgets('two actions sit side by side; three stack, each the full width', (WidgetTester tester) async {
    Future<void> open(List<String> labels) async {
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
                      for (final String l in labels)
                        GlassAlertAction(label: l, onPressed: () => Navigator.of(context).pop()),
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
    }

    Rect button(String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first,
    );

    await open(<String>['Cancel', 'OK']);
    expect(button('Cancel').top, button('OK').top);
    expect(button('Cancel').right, lessThan(button('OK').left));
    expect(button('Cancel').width, closeTo(button('OK').width, 0.01));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await open(<String>['One', 'Two', 'Three']);
    final Rect one = button('One');
    final Rect two = button('Two');
    final Rect three = button('Three');
    expect(one.left, two.left);
    expect(one.width, two.width);
    expect(two.width, three.width);
    expect(two.top - one.bottom, closeTo(8, 0.01), reason: 'stacked actions keep an 8 px gap');
    expect(three.top - two.bottom, closeTo(8, 0.01));
    expect(one.width, greaterThan(200), reason: 'a stacked action spans the alert');
  });

  testWidgets('a press that slides off an alert action does not press it', (WidgetTester tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassDialog<void>(
                context: context,
                builder: (BuildContext context) => GlassAlert(
                  title: const Text('Title'),
                  actions: <GlassAlertAction>[GlassAlertAction(label: 'Go', onPressed: () => pressed++)],
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
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 50));
    await finger.moveBy(const Offset(0, 200));
    await finger.up();
    await tester.pumpAndSettle();
    expect(pressed, 0, reason: 'a press dragged away from the button pressed it');
    // The control: the same button tapped does press, so the zero above is not
    // a button that never responds.
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });

  testWidgets('a menu controller opens and closes from outside its builder, and is inert unmounted', (
    WidgetTester tester,
  ) async {
    final controller = GlassMenuController();
    expect(controller.isOpen, isFalse);
    controller
      ..open()
      ..close();
    expect(controller.isOpen, isFalse, reason: 'an unmounted controller opened something');

    final show = ValueNotifier<bool>(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      _App(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (BuildContext context, bool shown, Widget? _) => Align(
            alignment: Alignment.topLeft,
            child: shown
                ? GlassMenuAnchor(
                    controller: controller,
                    items: const <GlassMenuItem>[GlassMenuItem(label: 'Rename')],
                    builder: (BuildContext context, GlassMenuController c) => const Text('anchor'),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
    expect(controller.isOpen, isFalse);
    expect(find.text('Rename'), findsNothing);

    controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(find.text('Rename'), findsOneWidget);

    controller.close();
    expect(controller.isOpen, isFalse, reason: 'isOpen is false from the moment close is called');
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);

    show.value = false;
    await tester.pumpAndSettle();
    controller.open();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse, reason: 'a controller kept driving a disposed anchor');
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('a sheet released after a short slow drag rises back and stays', (WidgetTester tester) async {
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 300, child: Center(child: Text('sheet body'))),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final double rest = tester.getCenter(find.text('sheet body')).dy;

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Moved at all, so the release below is a release of a drag; whether it
    // moved with the finger is the next arm's question.
    expect(tester.getCenter(find.text('sheet body')).dy, greaterThan(rest));
    // Still for a while, so the release carries no velocity.
    await tester.pump(const Duration(milliseconds: 300));
    await finger.up();
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget, reason: 'a short slow drag dismissed the sheet');
    expect(tester.getCenter(find.text('sheet body')).dy, closeTo(rest, 0.5));
  });

  // The drag used to move the route's controller, whose value the sheet reads
  // through the entrance curve — flat near the top — so 116 px of finger moved
  // the sheet 4.5 px. Now the drag is an offset of its own, in pixels: every
  // pixel of finger after the drag is accepted is a pixel of sheet.
  //
  // Break, undone by swapping the string back: in `_GlassSheetRoute._drag`,
  // `_drop.value += rest;` -> `_drop.value += rest / 4;` — the sheet lags the
  // finger and this arm fails while the release arms above still pass.
  testWidgets('a dismissible sheet follows the finger while it is dragged, pixel for pixel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 300, child: Center(child: Text('sheet body'))),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final double rest = tester.getCenter(find.text('sheet body')).dy;
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    // Past the slop, so the drag is accepted; what it delivers of these 20 px
    // is the recognizer's business, and is read rather than assumed.
    await finger.moveBy(const Offset(0, 20));
    await tester.pump();
    final double accepted = tester.getCenter(find.text('sheet body')).dy;
    expect(accepted - rest, inInclusiveRange(0, 20));
    for (final double dy in <double>[24, 48, 24]) {
      final double before = tester.getCenter(find.text('sheet body')).dy;
      await finger.moveBy(Offset(0, dy));
      await tester.pump();
      expect(tester.getCenter(find.text('sheet body')).dy - before, closeTo(dy, 0.01), reason: 'the sheet lags');
    }
    await finger.up();
    await tester.pumpAndSettle();
  });

  // The route is gone the moment it is popped, but its sheet is still on the
  // screen sliding out, and a finger already on it still drags it. Its release
  // past a third used to pop again — and what it popped was the page under it.
  testWidgets('a sheet popped while a finger drags it does not pop the page under it on release', (
    WidgetTester tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _App(
        navigatorKey: navigator,
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => Center(
                    child: GestureDetector(
                      onTap: () => showGlassSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(height: 300, child: Center(child: Text('sheet body'))),
                      ),
                      child: const Text('page two'),
                    ),
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('page two'));
    await tester.pumpAndSettle();

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    await finger.moveBy(const Offset(0, 20));
    await tester.pump();
    await finger.moveBy(const Offset(0, 150));
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('sheet body'), findsOneWidget, reason: 'the sheet left before the release');
    final double leaving = tester.getCenter(find.text('sheet body')).dy;
    await finger.up();
    await tester.pump(const Duration(milliseconds: 16));
    // It goes on leaving from where the finger left it, rather than springing
    // back up on its way out.
    expect(tester.getCenter(find.text('sheet body')).dy, greaterThanOrEqualTo(leaving));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
    expect(find.text('page two'), findsOneWidget, reason: 'the release popped the page under the sheet');
  });

  testWidgets('a sheet with a route pushed over it while dragged settles back on release, closing neither', (
    WidgetTester tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _App(
        navigatorKey: navigator,
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 300, child: Center(child: Text('sheet body'))),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final double rest = tester.getCenter(find.text('sheet body')).dy;
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    await finger.moveBy(const Offset(0, 20));
    await tester.pump();
    await finger.moveBy(const Offset(0, 150));
    await tester.pump();
    // Over the sheet, and leaving the finger's pointer where it was.
    navigator.currentState!.push<void>(
      PageRouteBuilder<void>(opaque: false, pageBuilder: (_, _, _) => const IgnorePointer(child: Text('on top'))),
    );
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(find.text('on top'), findsOneWidget, reason: 'the release popped the route over the sheet');
    expect(find.text('sheet body'), findsOneWidget, reason: 'the sheet closed under a route over it');
    expect(tester.getCenter(find.text('sheet body')).dy, closeTo(rest, 0.5));
  });

  // Apple's sheet rises above the keyboard; Material's leaves it to the
  // content. A sheet that floats at its content's height has nowhere to hide a
  // focused field but under the keyboard, so it stands on the keyboard's top
  // instead of the window's bottom — and tells its content there is no inset
  // left, so content padded for the keyboard the Material way is not padded
  // twice.
  testWidgets('a sheet stands above the keyboard, at medium and at large, and its content sees no inset', (
    WidgetTester tester,
  ) async {
    const keyboard = 250.0;
    final double window = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final insets = <double>[];
    addTearDown(tester.view.resetViewInsets);
    for (final GlassSheetDetent detent in GlassSheetDetent.values) {
      await tester.pumpWidget(
        _App(
          home: Builder(
            builder: (BuildContext context) => Center(
              child: GestureDetector(
                onTap: () => showGlassSheet<void>(
                  context: context,
                  detents: GlassSheetDetent.values,
                  initialDetent: detent,
                  builder: (BuildContext context) {
                    insets.add(MediaQuery.viewInsetsOf(context).bottom);
                    return const SizedBox(height: 200, child: Center(child: Text('sheet body')));
                  },
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      Rect sheet() =>
          tester.getRect(find.ancestor(of: find.text('sheet body'), matching: find.byType(GlassSurface)).first);
      final double bottom = detent == GlassSheetDetent.large ? window : window - kGlassSheetInset;
      expect(sheet().bottom, closeTo(bottom, 0.01), reason: '$detent without a keyboard');

      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
      await tester.pumpAndSettle();
      expect(sheet().bottom, closeTo(bottom - keyboard, 0.01), reason: '$detent: the keyboard covers the sheet');
      expect(insets.last, 0, reason: '$detent: the content was told the inset the sheet already took');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(sheet().bottom, closeTo(bottom, 0.01), reason: '$detent: the sheet did not come back down');
      await tester.pumpWidget(const SizedBox());
    }
  });
}

class _App extends StatelessWidget {
  const _App({required this.home, this.navigatorKey});

  final Widget home;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    builder: (BuildContext context, Widget? child) =>
        GlassHost(hardware: GlassHardware.appleMetal, backdrop: const Color(0xFF406080), child: child!),
    home: home,
  );
}
