// Where a pressed button's travel region lives: always, or only from
// touch-down until its spring settles — measured by three quantities, the
// one the choice was made for and the two it moves the other way.
//
// `flutter test test/glass_press_region_test.dart`
//
//  1. **Captured area at rest** — the quantity named: the sum of the atlas
//     slots' screen areas, for one button and for a row of five, with the
//     screen's own panel in both. The control is the same screen with
//     `GlassPress.none`, which builds no region at all: the on-demand arm must
//     land on it exactly, the always arm above it.
//  2. **Captures per press** — the quantity it moves the other way: the host's
//     `recorded` counter across touch-down, a hold, a drag, the release and
//     the settle. A region that appears and goes is a change of the capture
//     input each time.
//  3. **The first frames of the swell** — the other way it could move: the
//     capture for the new region is taken after the frame that declared it,
//     so a glass that grew on that frame would sample past the old slot. Each
//     frame after touch-down is compared, pixel by pixel, with the
//     always-declared arm at the same frame; and that arm with itself, which
//     must be zero, so a zero between the two is not a comparison that cannot
//     see.
//
// The numbers are printed as the table the default was chosen from.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/surface/glass_press.dart' show debugGlassPressRegionAtRest;

// The table is the point of the file.
// ignore_for_file: avoid_print

const Size kScreen = Size(400, 300);

void main() {
  tearDown(() => debugGlassPressRegionAtRest = false);

  testWidgets('at rest, on demand captures what no press captures; always, more', (WidgetTester tester) async {
    final area = <String, double>{};
    for (final int count in <int>[1, 5]) {
      for (final String arm in <String>['none', 'on demand', 'always']) {
        debugGlassPressRegionAtRest = arm == 'always';
        await _mount(tester, count: count, press: arm == 'none' ? GlassPress.none : null);
        area['$arm x$count'] = _capturedArea(tester);
      }
    }
    // The buttons' share: the total less the screen's panel, which is the
    // total of a screen with no button on it.
    await _mount(tester, count: 0);
    final double panel = _capturedArea(tester);
    String per(String key, int count) => ((area[key]! - panel) / count).toStringAsFixed(0);
    print(
      'captured area at rest, logical px², per button (panel ${panel.round()} taken off): '
      'x1 none ${per('none x1', 1)}, on demand ${per('on demand x1', 1)}, always ${per('always x1', 1)}; '
      'x5 none ${per('none x5', 5)}, on demand ${per('on demand x5', 5)}, always ${per('always x5', 5)}',
    );
    for (final int count in <int>[1, 5]) {
      expect(area['on demand x$count'], area['none x$count'], reason: 'x$count: on demand captured a region at rest');
      expect(
        area['always x$count']! - panel,
        greaterThan((area['none x$count']! - panel) * 1.5),
        reason: 'x$count: always is not larger: the arm cannot see a region',
      );
    }
  });

  testWidgets('captures per press: on demand, one at touch-down and one at the settle', (WidgetTester tester) async {
    final phases = <String, Map<String, int>>{};
    for (final String arm in <String>['always', 'on demand']) {
      debugGlassPressRegionAtRest = arm == 'always';
      final hostKey = GlobalKey();
      await _mount(tester, count: 1, hostKey: hostKey);
      final dynamic host = hostKey.currentState! as dynamic;
      final counts = <String, int>{};
      var last = host.recorded as int;
      void phase(String name) {
        counts[name] = (host.recorded as int) - last;
        last = host.recorded as int;
      }

      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      phase('down');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      phase('hold');
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      phase('drag');
      await gesture.up();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      phase('release');
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      phase('settle');
      phases[arm] = counts;
    }
    print('captures per press: $phases');
    final int always = phases['always']!.values.fold(0, (int a, int b) => a + b);
    final int onDemand = phases['on demand']!.values.fold(0, (int a, int b) => a + b);
    expect(always, 0, reason: 'the declared region retook: the comparison has no baseline');
    expect(phases['on demand']!['down'], 1, reason: 'the region appearing was not one capture');
    expect(phases['on demand']!['hold']! + phases['on demand']!['drag']!, 0, reason: 'held, on demand retook');
    expect(onDemand, lessThanOrEqualTo(2));
  });

  testWidgets('no frame of the swell is drawn from the old slot', (WidgetTester tester) async {
    // Each frame after touch-down: the pixels, and the glass's size.
    Future<({List<Uint8List> px, List<Size> size, Size rest})> frames(bool always) async {
      debugGlassPressRegionAtRest = always;
      await _mount(tester, count: 1);
      final Size rest = _glass(tester).size;
      final px = <Uint8List>[];
      final size = <Size>[];
      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        px.add(await _shot(tester));
        size.add(_glass(tester).size);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      return (px: px, size: size, rest: rest);
    }

    Set<int> differing(Uint8List a, Uint8List b) => <int>{
      for (var p = 0; p < a.length; p++)
        if ((a[p] - b[p]).abs() > 2) p,
    };

    final always = await frames(true);
    final again = await frames(true);
    final onDemand = await frames(false);
    debugGlassPressRegionAtRest = true;
    final Uint8List restAlways = await _restShot(tester);
    debugGlassPressRegionAtRest = false;
    final Uint8List restOnDemand = await _restShot(tester);
    final Set<int> atRest = differing(restAlways, restOnDemand);

    final self = <int>[for (var f = 0; f < 12; f++) differing(always.px[f], again.px[f]).length];
    final between = <Set<int>>[for (var f = 0; f < 12; f++) differing(always.px[f], onDemand.px[f])];
    final grown = <bool>[for (var f = 0; f < 12; f++) onDemand.size[f] != onDemand.rest];
    final swell = <int>[for (var f = 0; f < 12; f++) differing(onDemand.px[f], restOnDemand).length];
    print(
      'frames after touch-down — grown on demand: $grown; channels > 2 apart: always vs itself $self, '
      'always vs on demand ${between.map((Set<int> d) => d.length).toList()}, on demand vs its rest $swell; '
      'and the two arms at rest: ${atRest.length}',
    );
    expect(self.every((int n) => n == 0), isTrue, reason: 'the reference is not deterministic');
    expect(swell.last, greaterThan(1000), reason: 'the swell changed nothing visible');
    expect(grown.first, isFalse, reason: 'the glass grew on the frame that declared its region');
    expect(grown.last, isTrue, reason: 'the glass never grew');
    for (var f = 0; f < 12; f++) {
      expect(onDemand.size[f], always.size[f], reason: 'frame $f: the two arms are not the same press');
      if (grown[f]) {
        expect(between[f], isEmpty, reason: 'frame $f: a grown glass drawn from another slot');
      } else {
        // Ungrown, the only difference is the one the region makes at rest:
        // the rim reads past the box's bleed, and a larger slot clamps it
        // elsewhere — on demand, it is the picture a button without a press
        // has.
        expect(atRest.containsAll(between[f]), isTrue, reason: 'frame $f: differs where the rests do not');
      }
    }
  });
}

RenderGlassSurface _glass(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.globalRect.top > 100);

GlobalKey _shotKey = GlobalKey();

Future<void> _mount(WidgetTester tester, {required int count, GlobalKey? hostKey, GlassPress? press}) async {
  _shotKey = GlobalKey();
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
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
                    ),
                    const Positioned(left: 20, top: 20, width: 200, height: 60, child: GlassSurface()),
                    Positioned(
                      left: 20,
                      top: 160,
                      child: Row(
                        children: <Widget>[
                          for (var i = 0; i < count; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: GlassButton(
                                onPressed: () {},
                                press: press,
                                child: const SizedBox(width: 4, height: 24),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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

/// The screen area every slot of the published frame captures, logical px².
double _capturedArea(WidgetTester tester) {
  final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
  return handle.frame!.layout.slots.fold(0.0, (double a, s) => a + s.source.width * s.source.height);
}

Future<Uint8List> _restShot(WidgetTester tester) async {
  await _mount(tester, count: 1);
  return _shot(tester);
}

Future<Uint8List> _shot(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
  late Uint8List px;
  await tester.runAsync(() async {
    px = (await shot.toByteData())!.buffer.asUint8List();
  });
  shot.dispose();
  return px;
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 4),
        Paint()..color = Color.fromARGB(255, 30 + (y.toInt() * 3 % 210), 120, 210 - (y.toInt() % 160)),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
