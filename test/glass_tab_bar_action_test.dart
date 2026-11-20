// A tab bar's trailing action — iOS 26's search tab, set apart from the
// others as a circle beside the bar — and what it costs: one surface more,
// and nothing when the bar around it moves or collapses.
//
// `flutter test test/glass_tab_bar_action_test.dart`
//
// Five items in a scaffold 400 wide, so the bar is 376 with the scaffold's
// margins: with an action, 376 - 60 - 12 = 304 for the bar, still a phone's
// stacked layout, 60 tall, and a 60 circle 12 past its end.
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassTabBarState._tree`, `final double lead = rtl ? full - width :
//    0;` -> `final double lead = 0;`: under rtl the bar is drawn over the
//    circle, and the rtl arm fails, and the collapse arm's rtl half;
//  - `if (g.height != 60) {` -> `if (false) {`: on a wide bar the circle is
//    60 beside a 44-tall bar, and the wide arm fails;
//  - in the accessory's `inline` rect, `lead + width` -> `full`: collapsed,
//    the accessory runs under the circle, and the collapse arm fails;
//  - in `_action`, `() => widget.trailingAction?.onPressed?.call()` ->
//    `action.onPressed`: a kept build calls the first callback, and the
//    rebuild arm fails;
//  - in `_drawsAlike`, `p.selected != q.selected` dropped: the circle keeps
//    its old colour when the app selects it, and the colour arm fails;
//  - in `_content`, `|| _actionSelected` dropped: the capsule stays on a tab
//    while the action is the selection, and the selection arm fails; so does
//    `&& !_actionSelected` dropped from the row's `highlighted`, on the
//    accent.

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/surface/glass_components.dart' show glassSystemBlue;

const Size kScreen = Size(400, 800);

/// The scaffold's margin either side of its bottom bar, with no safe area.
const double kMargin = 12;

const List<GlassTabItem> kItems = <GlassTabItem>[
  GlassTabItem(icon: Icons.home, label: 'Home'),
  GlassTabItem(icon: Icons.favorite, label: 'Saved'),
  GlassTabItem(icon: Icons.inbox, label: 'Inbox'),
  GlassTabItem(icon: Icons.music_note, label: 'Music'),
  GlassTabItem(icon: Icons.person, label: 'Profile'),
];

void main() {
  testWidgets('the action is a circle as tall as the bar, past its end; the bar takes what is left', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester);
    final Rect bar = rig.bar.globalRect;
    final Rect circle = rig.circle.globalRect;
    expect(bar.left, kMargin);
    expect(bar.width, closeTo(kScreen.width - 2 * kMargin - 60 - 12, 0.01));
    expect(bar.height, 60);
    expect(circle.size, const Size(60, 60));
    expect(circle.right, closeTo(kScreen.width - kMargin, 0.01));
    expect(circle.left - bar.right, closeTo(12, 0.01), reason: 'the gap is not 12');
    expect(circle.center.dy, closeTo(bar.center.dy, 0.01));
    expect(rig.box.width, closeTo(kScreen.width - 2 * kMargin, 0.01), reason: 'the box is not the whole width');
  });

  testWidgets('on a wide bar the circle is as tall as the side-by-side layout, 44', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, screen: const Size(1000, 800));
    final Rect bar = rig.bar.globalRect;
    final Rect circle = rig.circle.globalRect;
    expect(bar.height, 44);
    expect(circle.size, const Size(44, 44));
    expect(bar.width, closeTo(1000 - 2 * kMargin - 44 - 12, 0.01));
    expect(circle.right, closeTo(1000 - kMargin, 0.01));
  });

  testWidgets('under right to left the circle is on the left and the bar after it', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, direction: TextDirection.rtl);
    final Rect bar = rig.bar.globalRect;
    final Rect circle = rig.circle.globalRect;
    expect(circle.left, closeTo(kMargin, 0.01));
    expect(bar.left - circle.right, closeTo(12, 0.01));
    expect(bar.right, closeTo(kScreen.width - kMargin, 0.01));
    // Item 0 is at the right end and item 1 next to it, and a tap there
    // selects it.
    final double pitch = (bar.width - 14) / kItems.length;
    await tester.tapAt(Offset(bar.right - 7 - pitch * 1.5, bar.center.dy));
    await tester.pumpAndSettle();
    expect(rig.selections, <int>[1]);
    expect(rig.pressed, 0);
  });

  testWidgets('a tap on the circle calls the action and selects no tab; a tap on a tab selects it', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, selected: 1);
    await tester.tapAt(rig.circle.globalRect.center);
    await tester.pumpAndSettle();
    expect(rig.pressed, 1);
    expect(rig.selections, isEmpty, reason: 'the action selected a tab');
    // The last item's centre, in the bar the action left: 7 in from its ends.
    final Rect bar = rig.bar.globalRect;
    final double pitch = (bar.width - 14) / kItems.length;
    await tester.tapAt(Offset(bar.left + 7 + pitch * 4.5, bar.center.dy));
    await tester.pumpAndSettle();
    expect(rig.selections, <int>[4]);
    expect(rig.pressed, 1);
  });

  testWidgets('the circle is a button named by its label, selected when it says so, disabled with no callback', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _Rig.mount(tester, actionSelected: true);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Search')),
      matchesSemantics(
        label: 'Search',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await _Rig.mount(tester, enabled: false);
    final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Search'));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(node.flagsCollection.isSelected, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('the icon builder is handed the accent while the action is selected, the label colour while not', (
    WidgetTester tester,
  ) async {
    final looks = <GlassTabItemLook>[];
    final selected = ValueNotifier<bool>(false);
    addTearDown(selected.dispose);
    Widget builder(BuildContext context, GlassTabItemLook look) {
      looks.add(look);
      return Icon(Icons.search, size: look.iconSize, color: look.color);
    }

    await _Rig.mount(tester, iconBuilder: builder, actionSelectedBy: selected);
    final GlassTabItemLook rest = looks.last;
    expect(rest.index, kItems.length, reason: 'not one past the last tab');
    expect(rest.selected, isFalse);
    expect(rest.iconSize, 26);
    final Color label = rest.color;
    selected.value = true;
    await tester.pumpAndSettle();
    final GlassTabItemLook on = looks.last;
    expect(on.selected, isTrue);
    expect(on.color, glassSystemBlue(label), reason: 'the selected action is not in the accent');
    // And the bar's own selection gives up the accent meanwhile.
    expect(tester.widget<Icon>(find.byIcon(Icons.home).first).color, label);
  });

  testWidgets('while the action is selected no tab is: no capsule, no accent, and the semantics say none', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final selected = ValueNotifier<bool>(true);
    addTearDown(selected.dispose);
    await _Rig.mount(tester, selected: 2, actionSelectedBy: selected);
    Finder capsule() => find.byWidgetPredicate(
      (Widget w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );
    Color inbox() => tester.widget<Icon>(find.byIcon(Icons.inbox).first).color!;
    final Color searching = inbox();
    expect(capsule(), findsNothing, reason: 'the bar kept its capsule under a selected action');
    expect(inbox(), tester.widget<Icon>(find.byIcon(Icons.home).first).color, reason: 'Inbox is in the accent');
    expect(tester.getSemantics(find.bySemanticsLabel('Inbox')).flagsCollection.isSelected, Tristate.isFalse);
    expect(tester.getSemantics(find.bySemanticsLabel('Search')).flagsCollection.isSelected, Tristate.isTrue);
    // Given back, the bar's own selection is where it was.
    selected.value = false;
    await tester.pumpAndSettle();
    expect(capsule(), findsOneWidget);
    expect(inbox(), isNot(searching));
    expect(tester.getSemantics(find.bySemanticsLabel('Inbox')).flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Search')).flagsCollection.isSelected, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('collapsed, the bar leaves the circle where it was and the accessory moves between the two', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, accessory: true);
    final Rect circle = rig.circle.globalRect;
    final Rect open = rig.accessory.globalRect;
    expect(open.left, closeTo(kMargin, 0.01));
    expect(open.right, closeTo(kScreen.width - kMargin, 0.01), reason: 'the accessory is not over both');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final Rect shut = rig.bar.globalRect;
    final Rect beside = rig.accessory.globalRect;
    expect(shut.size, const Size(60, 60));
    expect(shut.left, closeTo(kMargin, 0.01));
    expect(rig.circle.globalRect, circle, reason: 'the action moved with the collapse');
    expect(beside.left, closeTo(shut.right + 8, 0.6));
    expect(beside.right, closeTo(circle.left - 12, 0.6), reason: 'the accessory is not short of the circle');
    // Under right to left, the same, mirrored.
    final _Rig rtl = await _Rig.mount(tester, accessory: true, direction: TextDirection.rtl);
    final Rect rtlCircle = rtl.circle.globalRect;
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(rtl.accessory.globalRect.left, closeTo(rtlCircle.right + 12, 0.6));
    expect(rtl.accessory.globalRect.right, closeTo(rtl.bar.globalRect.left - 8, 0.6));
  });

  testWidgets('at rest the action is one surface more; rebuilt the same it is not retaken, and calls the latest', (
    WidgetTester tester,
  ) async {
    final calls = <String>[];
    final callback = ValueNotifier<String>('first');
    addTearDown(callback.dispose);
    final _Rig rig = await _Rig.mount(tester, calls: calls, callbackName: callback);
    expect(rig.handle.frame!.keys, hasLength(2), reason: 'the bar and the circle read the backdrop');
    final int recorded = rig.recorded;
    callback.value = 'second';
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(rig.recorded, recorded, reason: 'a new action with the same look retook the capture');
    await tester.tapAt(rig.circle.globalRect.center);
    await tester.pumpAndSettle();
    expect(calls, <String>['second']);
  });
}

class _Rig {
  _Rig._(this.tester, this.hostKey, this.selections, this.taps);

  final WidgetTester tester;
  final GlobalKey hostKey;
  final List<int> selections;
  final List<void> taps;

  int get pressed => taps.length;

  static Future<_Rig> mount(
    WidgetTester tester, {
    int selected = 0,
    bool accessory = false,
    bool enabled = true,
    bool actionSelected = false,
    ValueListenable<bool>? actionSelectedBy,
    GlassTabItemBuilder? iconBuilder,
    List<String>? calls,
    ValueListenable<String>? callbackName,
    Size screen = kScreen,
    TextDirection? direction,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view
      ..physicalSize = screen * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final hostKey = GlobalKey();
    final selections = <int>[];
    final taps = <void>[];
    final ValueListenable<bool> on = actionSelectedBy ?? ValueNotifier<bool>(actionSelected);
    final ValueListenable<String> name = callbackName ?? ValueNotifier<String>('');
    Widget home = GlassHost(
      key: hostKey,
      hardware: GlassHardware.appleMetal,
      child: GlassScaffold(
        bottomBar: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[on, name]),
          builder: (BuildContext context, Widget? _) {
            final String called = name.value;
            return GlassTabBar(
              items: kItems,
              selectedIndex: selected,
              onSelected: selections.add,
              minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
              bottomAccessory: accessory ? const Text('Now playing') : null,
              trailingAction: GlassTabBarAction(
                icon: iconBuilder == null ? Icons.search : null,
                iconBuilder: iconBuilder,
                label: 'Search',
                selected: on.value,
                onPressed: enabled
                    ? () {
                        taps.add(null);
                        calls?.add(called);
                      }
                    : null,
              ),
            );
          },
        ),
        body: ListView.builder(
          itemCount: 60,
          itemExtent: 40,
          itemBuilder: (BuildContext context, int i) => ColoredBox(
            color: HSVColor.fromAHSV(1, (i * 37 % 360).toDouble(), 0.6, 0.9).toColor(),
          ),
        ),
      ),
    );
    if (direction != null) {
      home = Directionality(textDirection: direction, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: home));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return _Rig._(tester, hostKey, selections, taps);
  }

  RenderGlassSurface get bar => tester.renderObject<RenderGlassSurface>(
    find.ancestor(of: find.text('Home'), matching: find.byType(GlassSurface)).first,
  );

  RenderGlassSurface get circle => tester.renderObject<RenderGlassSurface>(
    find.descendant(of: find.byType(GlassButton), matching: find.byType(GlassSurface)).first,
  );

  RenderGlassSurface get accessory => tester.renderObject<RenderGlassSurface>(
    find.ancestor(of: find.text('Now playing'), matching: find.byType(GlassSurface)).first,
  );

  Size get box => tester.getSize(find.byType(GlassTabBar));

  int get recorded => (hostKey.currentState! as dynamic).recorded as int;

  GlassProxyHandle get handle => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
}
