// The modal layer — alert, sheet, menu — and the toolbar's group.
//
// `flutter test test/glass_modal_test.dart`
//
// What is claimed: each modal is glass captured by the host above the
// navigator, a level above the page's glass (so a dialog over a glass bar
// shows the bar), and each says so in debug when there is no host to capture
// it. The toolbar's group is one surface whatever its count.
//
// Breaks, each undone by swapping the string back:
//  - `lift: kGlassModalLift,` -> `lift: 1,` in `_Materializing`: the alert is
//    then a level with the page's lifted bar, and the stacking arm finds it in
//    the bar's level instead of above it;
//  - `_assertHosted(context, 'GlassAlert');` -> `;`: the unhosted arm throws
//    nothing;
//  - the menu's items not reversed when it opens upward
//    (`down ? widget.items : widget.items.reversed.toList()` -> `widget.items`),
//    and the anchor left visible under it (`visible: !_open` -> `true`): each
//    fails the menu arm (D228);
//  - `themes.wrap(` dropped from either `showGlassDialog`'s page or the
//    sheet's: the theme arm finds that modal's text in the app's error style;
//  - `Size.lerp(_from, full, _progress)` -> `full` in `_RenderGrow`: the menu
//    and the popover arms find the panel whole on its first frame, not the
//    anchor's size at the anchor's corner;
//  - the anchor's semantics left to `Visibility` (`maintainSemantics: true,`
//    dropped and `ExcludeSemantics` not excluding): closing the popover over
//    an anchor with a semantics node trips the framework's
//    `!semantics.parentDataDirty` in the grow arm, which holds semantics on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

void main() {
  testWidgets('an alert over a page with a lifted glass bar is a level above it', (WidgetTester tester) async {
    await tester.pumpWidget(_App(home: const _Page()));
    await tester.tap(find.text('open alert'));
    await tester.pumpAndSettle();
    final GlassProxyHandle handle = _handle(tester);
    final RenderGlassSurface alert = _surfaceAbove(tester, find.text('Title'));
    final RenderGlassSurface bar = _surfaceAbove(tester, find.text('bar'));
    final RenderGlassSurface card = _surfaceAbove(tester, find.text('card'));
    // Card 0, bar 1 (lifted over the card), alert 2.
    expect(handle.frame!.keys, contains(card));
    expect(handle.upper, hasLength(2));
    expect(handle.upper[0]!.keys, contains(bar));
    expect(handle.upper[1]!.keys, contains(alert));
    expect(alert.presence, 1);
    expect(alert.materialize, 1);
    expect(alert.size.width, kGlassAlertWidth);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('a dialog with no host above the navigator says so', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassDialog<void>(
                context: context,
                builder: (_) => const GlassAlert(title: Text('Title')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final Object? error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('GlassHost'));
  });

  testWidgets('a sheet rises, is glass, and goes when dragged down', (WidgetTester tester) async {
    await tester.pumpWidget(_App(home: const _Page()));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final RenderGlassSurface sheet = _surfaceAbove(tester, find.text('sheet body'));
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(sheet.globalRect.left, closeTo(kGlassSheetInset, 0.01));
    expect(sheet.globalRect.bottom, closeTo(screen.height - kGlassSheetInset, 0.01));
    expect(_handle(tester).upper.last!.keys, contains(sheet));
    await tester.drag(find.text('sheet body'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
  });

  testWidgets('a sheet with a max width is that wide, centred over the bottom', (WidgetTester tester) async {
    await tester.pumpWidget(
      _App(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showGlassSheet<void>(
                context: context,
                constraints: const BoxConstraints(maxWidth: 300),
                builder: (_) => const SizedBox(height: 200, child: Center(child: Text('narrow body'))),
              ),
              child: const Text('open narrow sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open narrow sheet'));
    await tester.pumpAndSettle();
    final Rect sheet = _surfaceAbove(tester, find.text('narrow body')).globalRect;
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(sheet.width, closeTo(300, 0.01));
    expect(sheet.center.dx, closeTo(screen.width / 2, 0.01));
    expect(sheet.bottom, closeTo(screen.height - kGlassSheetInset, 0.01));
  });

  testWidgets('a menu stands over its anchor, as Apple places one, and closes on a choice', (
    WidgetTester tester,
  ) async {
    // Spike 34's two anchors: one on the right with room below, which opens
    // down with its top-right corner on the anchor's; one on the left near the
    // bottom, which opens up with its bottom-left corner on the anchor's and
    // its items reversed. 250 wide, rows of 42, 10 above and below.
    final chosen = <String>[];
    await tester.pumpWidget(_App(home: _Page(onMenu: chosen.add)));
    for (final (String name, bool down) in <(String, bool)>[('top menu', true), ('menu', false)]) {
      final Rect anchor = tester.getRect(find.text(name));
      await tester.tap(find.text(name));
      await tester.pump();
      final RenderGlassSurface menu = _surfaceAbove(tester, find.text('Rename'));
      expect(menu.materialize, lessThan(1), reason: 'the $name did not materialize');
      expect(menu.presence, 1, reason: 'the $name was eroded, which draws a line');
      await tester.pumpAndSettle();
      expect(menu.materialize, 1);
      final Rect box = menu.globalRect;
      expect(box.size, const Size(kGlassMenuWidth, 2 * kGlassMenuRowHeight + 20));
      final Rect anchorBox = tester.getRect(
        find.ancestor(of: find.text(name), matching: find.byType(GlassMenuAnchor)),
      );
      if (down) {
        expect(box.top, closeTo(anchorBox.top - 1, 0.01), reason: '$name: top not on the anchor\'s');
        expect(box.right, closeTo(anchorBox.right + 3, 0.01), reason: '$name: not on the anchor\'s right');
        expect(tester.getCenter(find.text('Rename')).dy, lessThan(tester.getCenter(find.text('Delete')).dy));
      } else {
        expect(box.bottom, closeTo(anchorBox.bottom + 1, 0.01), reason: '$name: bottom not on the anchor\'s');
        expect(box.left, closeTo(anchorBox.left - 4, 0.01), reason: '$name: not on the anchor\'s left');
        expect(
          tester.getCenter(find.text('Rename')).dy,
          greaterThan(tester.getCenter(find.text('Delete')).dy),
          reason: '$name: opening up, the first item is not nearest the anchor',
        );
      }
      expect(
        tester.widget<Visibility>(find.ancestor(of: find.text(name), matching: find.byType(Visibility)).first).visible,
        isFalse,
        reason: '$name: the anchor shows under its menu',
      );
      expect(anchor, isNotNull);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
    }
    expect(chosen, <String>['Rename', 'Rename']);
  });

  testWidgets('a dialog and a sheet carry the text style of where they were asked for', (WidgetTester tester) async {
    // The page's style is one no ancestor of the navigator has: whatever the
    // modal's text resolves to, it came from the caller's context.
    const page = TextStyle(fontFamily: 'Page', fontSize: 13, decoration: TextDecoration.none);
    await tester.pumpWidget(
      _App(
        home: const DefaultTextStyle(style: page, child: _Page()),
      ),
    );
    for (final (String open, String text) in <(String, String)>[
      ('open alert', 'Title'),
      ('open sheet', 'sheet body'),
    ]) {
      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
      final TextStyle style = DefaultTextStyle.of(tester.element(find.text(text))).style;
      expect(style.fontFamily, 'Page', reason: '$open: the caller\'s text style did not reach the modal');
      expect(style.decoration, TextDecoration.none, reason: '$open: underlined, the app\'s error style');
      await tester.tapAt(const Offset(4, 4));
      Navigator.of(tester.element(find.text(text))).maybePop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a menu and a popover grow out of the anchor\'s corner', (WidgetTester tester) async {
    final chosen = <String>[];
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_App(home: _Page(onMenu: chosen.add)));
    for (final (String name, String inside, Alignment corner) in <(String, String, Alignment)>[
      ('top menu', 'Rename', Alignment.topRight),
      ('menu', 'Rename', Alignment.bottomLeft),
      ('popover', 'popover body', Alignment.topLeft),
    ]) {
      final Rect anchor = tester.getRect(
        find.ancestor(of: find.text(name), matching: find.byWidgetPredicate((Widget w) => w is Visibility)).first,
      );
      await tester.tap(find.text(name));
      await tester.pump();
      final RenderGlassSurface panel = _surfaceAbove(tester, find.text(inside));
      final Rect first = panel.globalRect;
      // On its first frame it is the anchor, give or take the few points the
      // corners are set off by (spike 34) and one frame's growth.
      expect(first.width, closeTo(anchor.width, 4), reason: '$name: whole on its first frame');
      expect(first.height, closeTo(anchor.height, 4), reason: '$name: whole on its first frame');
      await tester.pumpAndSettle();
      final Rect open = panel.globalRect;
      expect(open.width, name == 'popover' ? 200 : kGlassMenuWidth, reason: '$name: did not grow to its width');
      expect(open.height, name == 'popover' ? 160 : 2 * kGlassMenuRowHeight + 20, reason: name);
      // The corner it shares with the anchor stays put while it grows.
      expect((corner.withinRect(first) - corner.withinRect(open)).distance, lessThan(0.01), reason: name);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text(inside), findsNothing, reason: '$name: the barrier did not close it');
    }
    semantics.dispose();
  });

  testWidgets('a toolbar group of three is one surface; a press brightens one cell', (WidgetTester tester) async {
    final pressed = <int>[];
    await tester.pumpWidget(
      _App(
        home: Center(
          child: GlassButtonGroup(
            items: <GlassToolbarItem>[
              for (var i = 0; i < 3; i++)
                GlassToolbarItem(icon: Text('i$i'), label: 'item $i', onPressed: () => pressed.add(i)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(tester.getSize(find.byType(GlassSurface)), const Size(3 * kGlassToolbarItemWidth, kGlassToolbarHeight));
    final TestGesture g = await tester.startGesture(tester.getCenter(find.text('i1')));
    await tester.pump();
    final CustomPaint paint = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(GlassSurface), matching: find.byType(CustomPaint)).first,
    );
    expect(paint.painter, isNotNull, reason: 'the held cell is not brightened');
    await g.up();
    await tester.pump();
    expect(pressed, <int>[1]);
  });
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

RenderGlassSurface _surfaceAbove(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderGlassSurface>(find.ancestor(of: finder, matching: find.byType(GlassSurface)).first);

/// The host where a modal needs it: above the navigator.
class _App extends StatelessWidget {
  const _App({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) =>
        GlassHost(hardware: GlassHardware.appleMetal, backdrop: const Color(0xFF406080), child: child!),
    home: home,
  );
}

class _Page extends StatelessWidget {
  const _Page({this.onMenu});

  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF406080),
    child: Stack(
      children: <Widget>[
        const Positioned(left: 20, right: 20, top: 140, height: 200, child: GlassCard(child: Text('card'))),
        const Positioned(
          left: 20,
          right: 20,
          top: 120,
          height: 60,
          child: GlassAbove(child: GlassBar(child: Text('bar'))),
        ),
        Positioned(
          left: 20,
          top: 30,
          child: GlassPopoverAnchor(
            width: 200,
            popoverBuilder: (_) => const SizedBox(height: 160, child: Center(child: Text('popover body'))),
            // A semantics node of its own, as an app's button has: closing
            // over it is what tripped the framework's semantics assertion.
            builder: (BuildContext context, GlassMenuController c) => Semantics(
              button: true,
              label: 'popover',
              child: GestureDetector(onTap: c.open, child: const Text('popover')),
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 30,
          child: GlassMenuAnchor(
            items: <GlassMenuItem>[
              GlassMenuItem(label: 'Rename', onPressed: () => onMenu?.call('Rename')),
              GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: () => onMenu?.call('Delete')),
            ],
            builder: (BuildContext context, GlassMenuController c) =>
                GestureDetector(onTap: c.open, child: const Text('top menu')),
          ),
        ),
        Positioned(
          left: 20,
          top: 400,
          child: Builder(
            builder: (BuildContext context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GestureDetector(
                  onTap: () => showGlassDialog<void>(
                    context: context,
                    builder: (BuildContext context) => GlassAlert(
                      title: const Text('Title'),
                      message: const Text('A message of one line.'),
                      actions: <GlassAlertAction>[
                        GlassAlertAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                        GlassAlertAction(label: 'OK', isDefault: true, onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  child: const Text('open alert'),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => showGlassSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(height: 300, child: Center(child: Text('sheet body'))),
                  ),
                  child: const Text('open sheet'),
                ),
                const SizedBox(height: 20),
                GlassMenuAnchor(
                  items: <GlassMenuItem>[
                    GlassMenuItem(label: 'Rename', onPressed: () => onMenu?.call('Rename')),
                    GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: () => onMenu?.call('Delete')),
                  ],
                  builder: (BuildContext context, GlassMenuController c) =>
                      GestureDetector(onTap: c.open, child: const Text('menu')),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
