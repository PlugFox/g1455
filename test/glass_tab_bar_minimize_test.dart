// A tab bar that collapses to its selected tab when the content scrolls down
// — iOS 26's `tabBarMinimizeBehavior(.onScrollDown)` — and what the collapse
// costs: nothing captured, nothing under it repainted.
//
// `flutter test test/glass_tab_bar_minimize_test.dart`
//
// Five items on a 400-wide scaffold, so the bar stacks icon over label and is
// 60 tall, as a phone's; the collapsed circle is that tall.
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassTabBarMinimizerState._onScroll`, `if (_run >
//    kGlassTabMinimizeScroll)` -> `if (_run > 1e9)`: nothing collapses; the
//    behaviour arm fails, and so does the `never` arm, on its check that the
//    minimizer saw the scroll;
//  - in `_GlassTabBarState._minimizeTo`, `if (_reduceMotion) {` ->
//    `if (false) {`: the reduced-motion arm finds the collapse animated;
//  - in `_GlassTabBarState._follow`, `_minimizeTo(target);` ->
//    `setState(() => _minimizeTo(target));`: the declared run takes 2 records,
//    one on the first frame of each direction, before the shape has moved — a
//    rebuild of the whole bar costs a capture even when nothing it draws
//    changed (one per bare `setState`, before this feature as after it);
//  - `debugGlassTabMinimizeTravel` is the cost arm's own control: off, every
//    frame of the collapse is a capture.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart' show GlassProxyFrame;
import 'package:g1455/src/surface/glass_tab_bar.dart' show debugGlassTabMinimizeTravel;

const Size kScreen = Size(400, 800);

/// The bar's box on the screen: the scaffold's margins, no safe area.
const double kBarLeft = 12;
const double kBarWidth = 400 - 24;

const List<GlassTabItem> kItems = <GlassTabItem>[
  GlassTabItem(icon: Icons.home, label: 'Home'),
  GlassTabItem(icon: Icons.search, label: 'Search'),
  GlassTabItem(icon: Icons.favorite, label: 'Saved'),
  GlassTabItem(icon: Icons.inbox, label: 'Inbox'),
  GlassTabItem(icon: Icons.person, label: 'Profile'),
];

void main() {
  testWidgets('scrolled down the bar collapses to the selected tab; scrolled up it expands', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, selected: 2, accessory: true);
    final Rect open = rig.bar.globalRect;
    final Rect accessoryOpen = rig.accessory.globalRect;
    expect(open.width, closeTo(kBarWidth, 0.01));
    expect(open.height, 60);
    expect(accessoryOpen.bottom, closeTo(open.top - 8, 0.01), reason: 'the accessory is not above the bar');

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final Rect shut = rig.bar.globalRect;
    expect(shut, Rect.fromLTWH(kBarLeft, open.top, 60, 60), reason: 'not a circle of the bar\'s height at its start');
    final Rect inline = rig.accessory.globalRect;
    expect(inline.left, closeTo(shut.right + 8, 0.01), reason: 'the accessory did not move beside the circle');
    expect(inline.right, closeTo(kBarLeft + kBarWidth, 0.01));
    expect(inline.center.dy, closeTo(shut.center.dy, 0.01));
    // The circle shows the selected item, and only it.
    expect(find.byIcon(Icons.favorite), findsNWidgets(2), reason: 'the row and the circle');
    expect(rig.box, rig.boxBefore, reason: 'the bar\'s box changed size, and with it the body\'s padding');

    await tester.drag(find.byType(ListView), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(rig.bar.globalRect, open, reason: 'scrolling up did not expand it');
    expect(rig.accessory.globalRect, accessoryOpen);

    // And at the top of the content it is open whatever came before.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(rig.bar.globalRect.width, 60);
    rig.scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(rig.bar.globalRect, open, reason: 'at the top of the content the bar stayed collapsed');
  });

  testWidgets('a bar that does not ask to collapse does not', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, behavior: GlassTabBarMinimizeBehavior.never);
    final Rect open = rig.bar.globalRect;
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(rig.scroll.offset, greaterThan(100), reason: 'the content did not scroll');
    expect(rig.bar.globalRect, open);
    expect(rig.minimizer.value, isTrue, reason: 'the scaffold\'s minimizer did not see the scroll');
  });

  testWidgets('a tap on the collapsed circle expands the bar and selects nothing', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Rig rig = await _Rig.mount(tester, selected: 1);
    final Rect open = rig.bar.globalRect;
    rig.minimizer.value = true;
    await tester.pumpAndSettle();
    expect(rig.bar.globalRect.width, 60);
    // One button for the whole bar, named for the selected tab; the items are
    // not reachable while they are not on screen.
    expect(find.semantics.byLabel('Search'), findsOne);
    expect(find.semantics.byLabel('Profile'), findsNothing);
    // Where the last item was is the content's now, not the bar's.
    expect(
      tester
          .hitTestOnBinding(Offset(kBarLeft + kBarWidth - 20, open.center.dy))
          .path
          .any(
            (HitTestEntry e) => e.target is RenderGlassSurface,
          ),
      isFalse,
    );

    await tester.tapAt(rig.bar.globalRect.center);
    await tester.pumpAndSettle();
    expect(rig.bar.globalRect, open);
    expect(rig.selections, isEmpty, reason: 'expanding selected a tab');
    expect(find.semantics.byLabel('Profile'), findsOne);
    // The control: expanded, the same tap selects.
    await tester.tapAt(Offset(kBarLeft + 7 + (kBarWidth - 14) / 5 * 0.5, open.center.dy));
    await tester.pumpAndSettle();
    expect(rig.selections, <int>[0]);
    semantics.dispose();
  });

  testWidgets('collapsing takes no capture and repaints nothing under the bar', (WidgetTester tester) async {
    addTearDown(() => debugGlassTabMinimizeTravel = true);
    final results = <bool, _Run>{};
    for (final bool travel in <bool>[false, true]) {
      debugGlassTabMinimizeTravel = travel;
      final _Rig rig = await _Rig.mount(tester, accessory: true);
      final int atlasAtRest = rig.atlasPixels;
      final int records = rig.recorded;
      final int snapshots = rig.handle.snapshots;
      final int paints = _Row.paints;
      final List<Layer?> pictures = _rowPictures(tester);
      expect(pictures, hasLength(greaterThan(10)));
      var frames = 0;
      var changed = 0;
      for (final bool collapse in <bool>[true, false]) {
        rig.minimizer.value = collapse;
        while (tester.binding.hasScheduledFrame && frames < 200) {
          final Rect was = rig.bar.globalRect;
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
          if (rig.bar.globalRect != was) {
            changed++;
          }
        }
      }
      results[travel] = _Run(
        frames: frames,
        changed: changed,
        records: rig.recorded - records,
        snapshots: rig.handle.snapshots - snapshots,
        paints: _Row.paints - paints,
        repainted: <int>[
          for (final (int i, Layer? l) in _rowPictures(tester).indexed)
            if (i >= pictures.length || !identical(l, pictures[i])) i,
        ].length,
        atlasAtRest: atlasAtRest,
      );
      if (travel) {
        // The on-screen count can see a repaint: one row repainted is one.
        final List<Layer?> before = _rowPictures(tester);
        tester.renderObject(find.byType(_Row).at(3)).markNeedsPaint();
        await tester.pump();
        final List<Layer?> after = _rowPictures(tester);
        expect(
          <int>[
            for (var i = 0; i < after.length; i++)
              if (!identical(after[i], before[i])) i,
          ],
          <int>[3],
        );
      }
    }
    debugPrint('undeclared ${results[false]}\ndeclared ${results[true]}');
    final _Run off = results[false]!;
    final _Run on = results[true]!;
    // Observable: the shape changed on many frames in both runs.
    expect(off.changed, greaterThan(8));
    expect(on.changed, off.changed, reason: 'the two runs did not animate alike');
    // The control: undeclared, a shape changing is a capture on every frame.
    expect(off.records, greaterThanOrEqualTo(off.changed ~/ 2), reason: 'the undeclared collapse was held: $off');
    // Declared, none — by the quantity named and the one it moves.
    expect(on.records, 0, reason: '$on');
    expect(on.snapshots, 0, reason: '$on');
    // The body under the bar is neither laid out nor repainted, either way —
    // what the undeclared run paints of it, it paints into its captures.
    expect(off.repainted, 0);
    expect(on.repainted, 0);
    expect(off.paints, greaterThan(0), reason: 'the undeclared captures painted no row: the count is blind');
    expect(on.paints, 0);
    // And the other way: the regions are captured instead of the boxes, so at
    // rest the atlas holds the accessory's whole travel.
    expect(on.atlasAtRest, greaterThan(off.atlasAtRest), reason: 'the regions cost the atlas nothing: $on, $off');
  });

  testWidgets('under reduced motion the bar collapses on the next frame and stays still', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, reduceMotion: true);
    final int records = rig.recorded;
    rig.minimizer.value = true;
    await tester.pump();
    expect(rig.bar.globalRect.width, 60, reason: 'the collapse was animated');
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump();
    expect(rig.recorded - records, lessThanOrEqualTo(1));
    rig.minimizer.value = false;
    await tester.pump();
    expect(rig.bar.globalRect.width, closeTo(kBarWidth, 0.01));
  });
}

/// The picture each row's repaint boundary holds: a row repainted on screen
/// holds a new one, and a row painted into a capture does not — the walk
/// leaves every layer it finds where it was.
List<Layer?> _rowPictures(WidgetTester tester) => <Layer?>[
  for (final RenderObject row in tester.renderObjectList(find.byType(_Row))) _boundaryAbove(row).debugLayer?.firstChild,
];

RenderObject _boundaryAbove(RenderObject node) {
  RenderObject? at = node;
  while (at != null && !at.isRepaintBoundary) {
    at = at.parent;
  }
  return at!;
}

class _Run {
  const _Run({
    required this.frames,
    required this.changed,
    required this.records,
    required this.snapshots,
    required this.paints,
    required this.repainted,
    required this.atlasAtRest,
  });

  final int frames;
  final int changed;
  final int records;
  final int snapshots;
  final int paints;
  final int repainted;
  final int atlasAtRest;

  @override
  String toString() =>
      '$frames frames, the bar changed on $changed: $records records, $snapshots snapshots, '
      '$paints row paints run (into captures), $repainted rows repainted on screen; atlas at rest $atlasAtRest px';
}

class _Rig {
  _Rig._(this.tester, this.hostKey, this.scroll, this.selections, this.boxBefore);

  final WidgetTester tester;
  final GlobalKey hostKey;
  final ScrollController scroll;
  final List<int> selections;
  final Size boxBefore;

  static Future<_Rig> mount(
    WidgetTester tester, {
    int selected = 0,
    bool accessory = false,
    bool reduceMotion = false,
    GlassTabBarMinimizeBehavior behavior = GlassTabBarMinimizeBehavior.onScrollDown,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view
      ..physicalSize = kScreen * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final hostKey = GlobalKey();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final selections = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => reduceMotion
            ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
            : child!,
        home: GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          child: GlassScaffold(
            bottomBar: GlassTabBar(
              items: kItems,
              selectedIndex: selected,
              onSelected: selections.add,
              minimizeBehavior: behavior,
              bottomAccessory: accessory ? const Text('Now playing') : null,
            ),
            body: ListView.builder(
              controller: scroll,
              itemCount: 60,
              itemExtent: 40,
              itemBuilder: (BuildContext context, int i) => _Row(i),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final rig = _Rig._(tester, hostKey, scroll, selections, Size.zero);
    return _Rig._(tester, hostKey, scroll, selections, rig.box);
  }

  RenderGlassSurface get bar => tester.renderObject<RenderGlassSurface>(
    find.ancestor(of: find.text('Home'), matching: find.byType(GlassSurface)).first,
  );

  RenderGlassSurface get accessory => tester.renderObject<RenderGlassSurface>(
    find.ancestor(of: find.text('Now playing'), matching: find.byType(GlassSurface)).first,
  );

  Size get box => tester.getSize(find.byType(GlassTabBar));

  ValueNotifier<bool> get minimizer => GlassTabBarMinimizer.maybeOf(tester.element(find.byType(GlassTabBar)))!;

  int get recorded => (hostKey.currentState! as dynamic).recorded as int;

  GlassProxyHandle get handle => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

  int get atlasPixels {
    var n = 0;
    for (final GlassProxyFrame? f in <GlassProxyFrame?>[handle.frame, ...handle.upper]) {
      if (f != null) {
        n += f.image.width * f.image.height;
      }
    }
    return n;
  }
}

class _Row extends StatelessWidget {
  const _Row(this.i);

  final int i;

  static int paints = 0;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RowPainter(i));
}

class _RowPainter extends CustomPainter {
  _RowPainter(this.i);

  final int i;

  @override
  void paint(Canvas canvas, Size size) {
    _Row.paints++;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = HSVColor.fromAHSV(1, (i * 37 % 360).toDouble(), 0.6, 0.9).toColor(),
    );
  }

  @override
  bool shouldRepaint(_RowPainter oldDelegate) => oldDelegate.i != i;
}
