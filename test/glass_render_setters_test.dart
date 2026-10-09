// The render objects' small surfaces: setters that must repaint and nothing
// more, counters a benchmark resets between repeats, what a group says in a
// diagnostics dump, a debug outline, and the drop's stretch model read from
// outside.
//
// `flutter test test/glass_render_setters_test.dart`
//
// Each of these is the kind of line a refactor moves without anyone noticing:
// a setter that stops calling `markNeedsPaint`, a counter left out of
// `resetCounters` (and a report that then sums two repeats), a warning that
// starts firing every frame instead of once. So each arm asserts the
// consequence, next to a control showing the consequence can be seen.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(300, 300);

void main() {
  testWidgets('RenderGlassAbove: a new lift repaints, the same one does not', (WidgetTester tester) async {
    await _mount(tester, const GlassAbove(child: GlassCard(child: SizedBox(width: 100, height: 60))));
    final RenderGlassAbove above = tester.renderObject(find.byType(GlassAbove));
    expect(above.lift, 1);
    above.lift = 1;
    expect(above.debugNeedsPaint, isFalse, reason: 'an unchanged lift cost a repaint');
    above.lift = 3;
    expect(above.debugNeedsPaint, isTrue, reason: 'a new lift gave the host no frame to capture on');
    await tester.pump();
    // And the widget carries a declaration through to the same object.
    await _mount(tester, const GlassAbove(lift: 2, child: GlassCard(child: SizedBox(width: 100, height: 60))));
    expect(tester.renderObject(find.byType(GlassAbove)), same(above));
    expect(above.lift, 2);
  });

  testWidgets('RenderGlassTravel: a region handed over answers for the new one and releases the old', (
    WidgetTester tester,
  ) async {
    final first = GlassTravelRegion();
    final second = GlassTravelRegion();
    expect(first.globalRect, isNull, reason: 'a region with no box declares nothing');
    await _mount(tester, _Travel(region: first));
    expect(first.globalRect, const Rect.fromLTWH(0, 0, 120, 40));
    expect(second.globalRect, isNull);

    await _mount(tester, _Travel(region: second));
    expect(first.globalRect, isNull, reason: 'the old region still answered for a box that left it');
    expect(second.globalRect, const Rect.fromLTWH(0, 0, 120, 40));

    // A region taken back while detached is claimed on the next attach, not
    // before: a detached box has no rect to answer with.
    final RenderGlassTravel box = tester.renderObject(find.byType(_Travel));
    await _mount(tester, const SizedBox());
    expect(box.attached, isFalse);
    box.region = first;
    expect(first.globalRect, isNull);
    expect(second.globalRect, isNull);
  });

  testWidgets('RenderGlassGroup: finish and density repaint; resetCounters zeroes what a paint counted', (
    WidgetTester tester,
  ) async {
    await _mount(tester, _pair(finish: null));
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    expect(group.fusedPaints, greaterThan(0), reason: 'the pair never fused, so nothing below is about a fuse');
    final GlassFinish hosts = group.effectiveFinish;

    await _mount(tester, _pair(finish: GlassFinish.frosted), frames: 0);
    expect(group.debugNeedsPaint, isTrue, reason: 'a new finish did not repaint the fused draw');
    await tester.pump();
    expect(group.effectiveFinish.name, GlassFinish.frosted.name, reason: 'the old legibility was kept');
    expect(group.effectiveFinish == hosts, isFalse);

    await _mount(tester, _pair(finish: GlassFinish.frosted), dpr: 3, frames: 0);
    expect(group.debugNeedsPaint, isTrue, reason: 'a new density did not repaint the fused quad');
    await tester.pump();

    group.resetCounters();
    final List<num> zeroed = <num>[
      group.fusedPaints,
      group.paintsIntoProxy,
      group.paintsWithDeclaredBackdrop,
      group.refusedPaints,
      group.paintsWithoutProxy,
      group.splitSlots,
      group.fusedQuadArea,
      group.fusedShapeArea,
      group.fusedFoldArea,
      group.fusedDraws,
      group.fusedTileRefusals,
      group.fusedDrawsAliased,
      group.lastCullDistance,
      group.lastBlendRadius,
    ];
    expect(zeroed.every((num n) => n == 0), isTrue, reason: '$zeroed');
    group.markNeedsPaint();
    await tester.pump();
    expect(group.fusedPaints, 1, reason: 'counting restarts from zero, not from where it was');
  });

  testWidgets('RenderGlassGroup describes its spacing and its members', (WidgetTester tester) async {
    await _mount(tester, _pair(finish: null));
    final String fixed = tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup)).toStringDeep();
    expect(fixed, contains('spacing: 20.0'));
    expect(fixed, contains('members: 2'));
    await _mount(tester, _pair(finish: null, union: true));
    final String union = tester.renderObject<RenderGlassGroup>(find.byType(GlassUnion)).toStringDeep();
    expect(union, contains('spacing: union'));
  });

  testWidgets('a member naming its own finish in a fused group is reported once, by count', (
    WidgetTester tester,
  ) async {
    await _mount(tester, _pair(finish: null, memberFinish: GlassFinish.clear));
    final Object? error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('1 of 2 surfaces in a GlassGroup name their own finish'));
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    group.markNeedsPaint();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'the warning repeats every frame');
  });

  testWidgets('RenderGlassSurface: the declarations read back, and resetCounters zeroes the paint counters', (
    WidgetTester tester,
  ) async {
    final fade = GlassFade.vertical(from: 0, extent: 30);
    await _mount(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: kScreen, disableAnimations: true),
        child: GlassSurface(fade: fade, ripple: const GlassRipple(), child: const SizedBox(width: 100, height: 60)),
      ),
    );
    final RenderGlassSurface surface = tester.renderObject(find.byType(GlassSurface));
    expect(surface.fade, fade);
    expect(surface.ripple, const GlassRipple());
    expect(surface.reduceMotion, isTrue);
    expect(surface.effectiveRipple, isNull, reason: 'reduced motion declared a ripple anyway');
    expect(surface.paintsWithProxy + surface.paintsWithoutProxy, greaterThan(0));

    surface.resetCounters();
    expect(
      <int>[
        surface.paintsWithoutProxy,
        surface.paintsWithProxy,
        surface.paintsWithDeclaredBackdrop,
        surface.paintsWithOptics,
        surface.paintsDeferredToGroup,
        surface.paintsCheap,
        surface.paintsOpaque,
        surface.opticsDrawsAliased,
        surface.paintsIntoProxy,
        surface.rippleTicks,
        surface.rippleDraws,
      ].every((int n) => n == 0),
      isTrue,
    );
  });

  testWidgets('debugPaintGlassSurfaces outlines every surface, and only while it is on', (
    WidgetTester tester,
  ) async {
    addTearDown(() => debugPaintGlassSurfaces = false);
    final GlobalKey shot = GlobalKey();
    Widget scene() => RepaintBoundary(
      key: shot,
      child: const SizedBox(
        width: 200,
        height: 120,
        child: Center(child: GlassCard(child: SizedBox(width: 120, height: 60))),
      ),
    );
    await _mount(tester, scene());
    final int off = await _outline(tester, shot);
    debugPaintGlassSurfaces = true;
    tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface)).markNeedsPaint();
    await tester.pump();
    final int on = await _outline(tester, shot);
    debugPaintGlassSurfaces = false;
    expect(off, 0, reason: 'the outline colour is already in the frame, so the arm cannot see it');
    // A 1 px antialiased stroke: only the pixels it covers most strongly pass
    // the colour test, so the floor is well under the 360 px perimeter.
    expect(on, greaterThan(60), reason: 'the outline did not reach the frame');
  });

  group('GlassDropStretch', () {
    test('speeding up stretches, braking squashes, and the readings say why', () {
      final model = GlassDropStretch();
      var x = 0.0;
      model.jump(x);
      // Accelerating to the right.
      for (var i = 1; i <= 6; i++) {
        x += 2.0 * i;
        model.step(1 / 60, x);
      }
      expect(model.velocity, greaterThan(0));
      expect(model.acceleration, greaterThan(0));
      expect(model.target, greaterThan(0), reason: 'speeding up is a stretch');
      expect(model.position, x);
      // Braking hard.
      for (var i = 0; i < 6; i++) {
        x += 1;
        model.step(1 / 60, x);
      }
      expect(model.acceleration, lessThan(0));
      expect(model.target, lessThan(0), reason: 'braking is a squash');
      expect(model.value.abs(), lessThanOrEqualTo(model.motion.maxStretch));
    });
  });

  testWidgets('GlassDropStretchDriver: wakes on motion, and a motion of none stops it and shows nothing', (
    WidgetTester tester,
  ) async {
    var x = 0.0;
    final driver = GlassDropStretchDriver(vsync: tester, position: () => x)..motion = const GlassDropMotion();
    addTearDown(driver.dispose);
    expect(driver.motion, const GlassDropMotion());
    expect(driver.isActive, isFalse);
    driver
      ..jump()
      ..wake();
    expect(driver.isActive, isTrue);
    for (var i = 1; i <= 8; i++) {
      x += 3.0 * i;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(driver.value, isNot(0), reason: 'a drop pushed along stayed round, so the arm below proves nothing');

    var notified = 0;
    driver
      ..addListener(() => notified++)
      ..motion = GlassDropMotion.none;
    expect(driver.isActive, isFalse);
    expect(driver.value, 0);
    expect(driver.motion.isNone, isTrue);
    driver.wake();
    expect(driver.isActive, isFalse, reason: 'a motion of none woke anyway');
    x += 50;
    await tester.pump(const Duration(milliseconds: 16));
    expect(notified, 0);
  });
}

Future<void> _mount(WidgetTester tester, Widget child, {double dpr = 2, int frames = 3}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: kScreen, devicePixelRatio: dpr),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: _host,
            hardware: GlassHardware.appleMetal,
            child: SizedBox.fromSize(
              size: kScreen,
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(child: ColoredBox(color: Color(0xFF406080))),
                  Align(alignment: Alignment.topLeft, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

final GlobalKey _host = GlobalKey();

/// Two surfaces 10 px apart: inside a spacing of 20, so they fuse.
Widget _pair({required GlassFinish? finish, GlassFinish? memberFinish, bool union = false}) {
  final Widget members = SizedBox(
    width: 230,
    height: 60,
    child: Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          width: 110,
          height: 60,
          child: GlassSurface(finish: memberFinish, child: const SizedBox.expand()),
        ),
        const Positioned(left: 120, top: 0, width: 110, height: 60, child: GlassSurface(child: SizedBox.expand())),
      ],
    ),
  );
  return union ? GlassUnion(finish: finish, child: members) : GlassGroup(spacing: 20, finish: finish, child: members);
}

class _Travel extends SingleChildRenderObjectWidget {
  const _Travel({required this.region}) : super(child: const SizedBox(width: 120, height: 40));

  final GlassTravelRegion region;

  @override
  RenderGlassTravel createRenderObject(BuildContext context) => RenderGlassTravel(region);

  @override
  void updateRenderObject(BuildContext context, RenderGlassTravel renderObject) => renderObject.region = region;
}

/// Pixels of the debug outline's colour in [key]'s boundary.
Future<int> _outline(WidgetTester tester, GlobalKey key) async {
  final RenderRepaintBoundary boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = boundary.toImageSync();
  var n = 0;
  await tester.runAsync(() async {
    final ByteData? data = await image.toByteData();
    final Uint8List px = data!.buffer.asUint8List();
    for (var i = 0; i < px.length; i += 4) {
      // Near the outline's 0xFF00E5FF: red low, green and blue high.
      if (px[i] < 60 && px[i + 1] > 180 && px[i + 2] > 200) {
        n++;
      }
    }
  });
  image.dispose();
  return n;
}
