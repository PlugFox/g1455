// The tab bar: a selection that lifts into a clear drop over the bar's own
// glass — glass on glass — and what that costs the capture (D218).
//
// `flutter test test/glass/glass_tab_bar_test.dart`
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassTabBarState._onUp`, `: _pressed;` -> `: _at.value.round();`: a
//    quick tap lands on the item the drop has reached, not the one pressed,
//    and the tap arm selects the wrong one;
//  - in `_TabGeometry.margin`, `+ reach.height` -> `+ 0`: the drop squashed
//    arriving at the last item stands out of its region above and below, and
//    the spring arm says so. (`+ reach.width` -> `+ 0` breaks nothing at the
//    defaults: the bar's own growth leaves 3.5 px spare at the ends, more than
//    the stretch a spring launch reaches.)
//
// The mechanisms the cost arms lean on — the drop as a level of its own, and
// the watch over what the bar bears — are `GlassHost`'s, and their breaks are
// in `glass_stack_test.dart`. Two of this file's own were tried and broke
// nothing, and were removed rather than kept (D218): a repaint boundary around
// the drop's stage, and watching where the bar actually is.

import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart' show GlassProxyFrame;

const Size kScreen = Size(400, 400);

/// The bar's box on the screen: 300 wide is a phone's layout, icon over label.
const Rect kBar = Rect.fromLTWH(50, 300, 300, 60);

/// Item [i]'s centre on the screen, by the layout read off the phone: 7 in
/// from the ends, four items.
Offset _item(double i) => Offset(kBar.left + 7 + (300 - 14) / 4 * (i + 0.5), kBar.center.dy);

void main() {
  testWidgets('at rest the drop costs the capture nothing, and no level is stacked', (
    WidgetTester tester,
  ) async {
    await _mount(tester);
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame!.keys, hasLength(1), reason: 'only the bar reads the backdrop');
    expect(handle.upper.whereType<GlassProxyFrame>(), isEmpty, reason: 'a resting drop was stacked');
    expect(_drop(tester).materialize, 0);
  });

  testWidgets('held, the drop is glass on the bar; dragged within an item, nothing is retaken', (
    WidgetTester tester,
  ) async {
    final GlobalKey hostKey = GlobalKey();
    final selected = <int>[];
    await _mount(tester, hostKey: hostKey, onSelected: selected.add);
    final dynamic host = hostKey.currentState! as dynamic;

    final TestGesture gesture = await tester.startGesture(_item(0));
    // Every frame the bar under the drop changes size is a frame the drop
    // shows another bar, and has to be recorded — including the spring's
    // overshoot, after the capsule has gone and nothing else changes.
    final RenderGlassSurface bar = _bar(tester);
    Rect barWas = bar.globalRect;
    int recordedWas = host.recorded as int;
    var grew = 0;
    var unseen = 0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final int recorded = host.recorded as int;
      if (bar.globalRect != barWas && _drop(tester).materialize > 0) {
        grew++;
        if (recorded == recordedWas) {
          unseen++;
        }
      }
      barWas = bar.globalRect;
      recordedWas = recorded;
    }
    expect(grew, greaterThan(3), reason: 'the bar did not grow under the drop');
    expect(unseen, 0, reason: 'the bar changed size under the drop and the drop was not retaken');
    final RenderGlassSurface drop = _drop(tester);
    expect(drop.materialize, 1, reason: 'the drop never lifted');
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame!.keys, hasLength(1), reason: 'the drop was captured with the backdrop, under the bar');
    final GlassProxyFrame? upper = handle.upper.whereType<GlassProxyFrame>().firstOrNull;
    expect(upper, isNotNull, reason: 'the drop is not a level above the bar');
    expect(upper!.keys, contains(drop), reason: 'the stacked level is not the drop');
    expect(drop.size.width, closeTo((300 - 14) / 4 + 7 + 2 * kGlassTabDropGrow, 0.05));
    expect(drop.size.height, closeTo(53 + 2 * kGlassTabDropGrow, 0.05));

    // Within the first item: the drop moves, the highlight does not change,
    // and so nothing under any glass changes.
    // And it stretches and squashes as it goes — inside its region, so that
    // is not a capture either.
    final int lifted = host.recorded as int;
    final Size held = drop.size;
    var moved = 0;
    var deformed = 0;
    Rect where = drop.globalRect;
    for (final double dx in <double>[8, 6, 6, -4, -6, 5]) {
      await gesture.moveBy(Offset(dx, 0));
      await tester.pump(const Duration(milliseconds: 16));
      if (drop.globalRect != where) {
        moved++;
        where = drop.globalRect;
      }
      if (drop.size != held) {
        deformed++;
      }
    }
    expect(moved, 6, reason: 'the drop did not follow the finger');
    expect(deformed, greaterThan(0), reason: 'the drop did not stretch as it moved');
    expect((host.recorded as int) - lifted, 0, reason: 'moving the drop inside one item retook the proxy');
    expect(_iconColour(tester, Icons.home), const Color(0xFF007AFF));

    // Into the third: the highlight moves, which is a change under the drop.
    await gesture.moveTo(_item(2));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect((host.recorded as int) - lifted, greaterThan(0), reason: 'the highlight changed under the drop unseen');
    expect(_iconColour(tester, Icons.favorite), const Color(0xFF007AFF));
    expect(_iconColour(tester, Icons.home), isNot(const Color(0xFF007AFF)));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, <int>[2]);
    expect(_drop(tester).materialize, 0, reason: 'the drop did not settle');
    expect(_handle(tester).upper.whereType<GlassProxyFrame>(), isEmpty, reason: 'the settled drop is still stacked');
  });

  testWidgets('pressed on a far tab, the drop springs there: long setting off, short arriving, round on it', (
    WidgetTester tester,
  ) async {
    for (final GlassDropMotion? motion in <GlassDropMotion?>[null, GlassDropMotion.none]) {
      await _mount(tester, dropMotion: motion);
      final TestGesture gesture = await tester.startGesture(_item(3));
      final RenderGlassSurface drop = _drop(tester);
      final drawn = <double>[];
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final Rect region = drop.travel!.globalRect!;
        expect(
          region.expandToInclude(drop.globalRect) == region,
          isTrue,
          reason: '$motion, frame $i: the drop left its region: ${drop.globalRect} in $region',
        );
        drawn.add(_stretchOf(drop.size));
      }
      if (motion == null) {
        final double most = drawn.reduce(math.max);
        final double least = drawn.reduce(math.min);
        expect(most, greaterThan(0.02), reason: 'the drop did not stretch setting off');
        expect(least, lessThan(-0.02), reason: 'the drop did not squash arriving');
        expect(drawn.indexOf(most), lessThan(drawn.indexOf(least)));
        expect(most, lessThanOrEqualTo(const GlassDropMotion().maxStretch + 1e-6));
      } else {
        expect(drawn.map((double s) => s.abs()), everyElement(lessThan(1e-6)), reason: 'none, and deformed');
      }
      expect(drawn.last.abs(), lessThan(1e-6), reason: '$motion: arrived and held, the drop is not round');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '$motion: a drop held still keeps drawing');
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('custom icons and labels are built with the colour the bar resolved for them', (
    WidgetTester tester,
  ) async {
    final looks = <GlassTabItemLook>[];
    Widget swatch(BuildContext context, GlassTabItemLook look) {
      looks.add(look);
      return SizedBox.square(
        key: ValueKey<String>('swatch ${look.index}'),
        dimension: look.iconSize,
        child: ColoredBox(color: look.color),
      );
    }

    Widget badge(BuildContext context, GlassTabItemLook look) =>
        Text('${look.index} new', key: ValueKey<String>('badge ${look.index}'), style: look.labelStyle);

    final selected = <int>[];
    await _mount(
      tester,
      onSelected: selected.add,
      items: <GlassTabItem>[
        const GlassTabItem(icon: Icons.home, label: 'Home'),
        GlassTabItem(label: 'Search', iconBuilder: swatch, labelBuilder: badge),
        const GlassTabItem(icon: Icons.favorite, label: 'Saved'),
        GlassTabItem(label: 'Profile', iconBuilder: swatch),
      ],
    );
    // The colour an unhighlighted built-in icon takes: the bar's label colour.
    final Color? plain = _iconColour(tester, Icons.favorite);
    expect(plain, isNotNull);
    expect(plain, isNot(const Color(0xFF007AFF)));
    GlassTabItemLook last(int i) => looks.lastWhere((GlassTabItemLook l) => l.index == i);
    Color swatchColour(int i) => tester
        .widget<ColoredBox>(
          find.descendant(of: find.byKey(ValueKey<String>('swatch $i')), matching: find.byType(ColoredBox)),
        )
        .color;

    expect(last(1).color, plain);
    expect(last(1).highlighted, isFalse);
    expect(last(1).selected, isFalse);
    expect(last(1).labelStyle.color, plain);
    expect(last(1).iconSize, 26, reason: 'a phone-wide bar stacks icon over label');
    expect(last(1).inline, isFalse);
    expect(swatchColour(1), plain);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('badge 1'))).style?.color, plain);

    // Held on the custom item: it takes the accent, the one it left gives it up.
    final TestGesture gesture = await tester.startGesture(_item(0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(_item(1));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(last(1).highlighted, isTrue);
    expect(last(1).selected, isFalse, reason: 'not selected until let go');
    expect(last(1).color, const Color(0xFF007AFF));
    expect(last(1).labelStyle.color, const Color(0xFF007AFF));
    expect(swatchColour(1), const Color(0xFF007AFF));
    expect(_iconColour(tester, Icons.home), plain);
    expect(last(3).color, plain);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, <int>[1]);
    expect(last(1).selected, isTrue);
    expect(last(1).highlighted, isTrue);
    // The label is still what a screen reader says.
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.semantics.byLabel('Search'), findsOne);
    semantics.dispose();
  });

  testWidgets('let go after resting on an item, the drop settles there', (WidgetTester tester) async {
    // The device run's sequence: down, slide, rest a while, up.
    final selected = <int>[];
    await _mount(tester, onSelected: selected.add);
    final TestGesture gesture = await tester.startGesture(_item(0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i <= 30; i++) {
      await gesture.moveTo(Offset.lerp(_item(0), _item(2), i / 30)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(selected, <int>[2]);
    expect(_drop(tester).materialize, 0, reason: 'the drop stayed up after the finger left');
  });

  testWidgets('a tap on another item selects it; the semantics say which is selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final selected = <int>[];
    await _mount(tester, onSelected: selected.add);
    await tester.tapAt(_item(3));
    await tester.pumpAndSettle();
    expect(selected, <int>[3]);
    final SemanticsNode profile = tester.getSemantics(find.text('Profile'));
    expect(profile.label, 'Profile');
    expect(profile.flagsCollection.isSelected, Tristate.isTrue);
    final SemanticsNode home = tester.getSemantics(find.text('Home'));
    expect(home.flagsCollection.isSelected, Tristate.isFalse);
    tester.semantics.tap(find.semantics.byLabel('Saved'));
    await tester.pumpAndSettle();
    expect(selected, <int>[3, 2]);
    semantics.dispose();
  });
}

/// The stretch a tab drop of [size] shows: its unstretched size is the
/// capsule grown by the same amount on both axes (the lift), and the stretch
/// keeps the area — so both are solved from the size.
double _stretchOf(Size size) {
  const double pw = (300 - 14) / 4 + 7;
  const double ph = 53;
  // (pw + g)(ph + g) = w h, for the growth g.
  final double area = size.width * size.height;
  final double g = (-(pw + ph) + math.sqrt((pw + ph) * (pw + ph) - 4 * (pw * ph - area))) / 2;
  final double s = size.width / (pw + g) - 1;
  return s.abs() < 1e-9 ? 0 : s;
}

Color? _iconColour(WidgetTester tester, IconData icon) =>
    tester.widget<RichText>(find.descendant(of: find.byIcon(icon), matching: find.byType(RichText))).text.style?.color;

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

RenderGlassSurface _bar(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish == null);

RenderGlassSurface _drop(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);

Future<void> _mount(
  WidgetTester tester, {
  GlobalKey? hostKey,
  ValueChanged<int>? onSelected,
  List<GlassTabItem>? items,
  GlassDropMotion? dropMotion,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: hostKey ?? GlobalKey(),
            hardware: GlassHardware.appleMetal,
            child: SizedBox.fromSize(
              size: kScreen,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
                  ),
                  Positioned.fromRect(
                    rect: kBar,
                    child: _Tabs(onSelected: onSelected ?? (_) {}, items: items, dropMotion: dropMotion),
                  ),
                ],
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
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.onSelected, this.items, this.dropMotion});

  final ValueChanged<int> onSelected;
  final List<GlassTabItem>? items;
  final GlassDropMotion? dropMotion;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items:
        widget.items ??
        const <GlassTabItem>[
          GlassTabItem(icon: Icons.home, label: 'Home'),
          GlassTabItem(icon: Icons.search, label: 'Search'),
          GlassTabItem(icon: Icons.favorite, label: 'Saved'),
          GlassTabItem(icon: Icons.person, label: 'Profile'),
        ],
    dropMotion: widget.dropMotion,
    selectedIndex: _index,
    onSelected: (int i) {
      widget.onSelected(i);
      setState(() => _index = i);
    },
  );
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F1EA));
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), Paint()..color = const Color(0xFF1B1B1B));
    }
    for (var i = 0; i < 11; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 37.0, size.width, 5),
        Paint()..color = HSVColor.fromAHSV(1, (i * 47 % 360).toDouble(), 0.8, 0.9).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
