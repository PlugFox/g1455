// A sheet's two detents, the drag between them, and what an opaque large
// sheet stops costing.
//
// `flutter test test/glass_sheet_detent_test.dart`
//
// The page under every sheet carries a glass bar of its own, so the host has
// a capture to take whatever the sheet does: a sheet that stops reading its
// backdrop shows as a smaller capture, not as no capture, and a host that
// stopped recording altogether cannot pass for the saving.
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassSheet.build`, `extent >= 1 && large.tint.a >= 1` ->
//    `extent >= 2 && large.tint.a >= 1`: the opaque large sheet keeps its
//    capture, and the saving arm fails on the captured count, the area and the
//    atlas; the picture arm fails only on the rung it asserts — its pixels
//    agree either way, which is the point of that arm;
//  - in `_RenderSheetFrame.performLayout`, `final double inset =
//    kGlassSheetInset * (1 - p);` -> `final double inset = kGlassSheetInset;`:
//    the large sheet keeps its margins, and every arm that reaches large fails;
//  - in `_GlassSheetRoute._drag`, `_moving.value = true;` -> `_moving.value =
//    false;`: the travel arm's declared run retakes every frame of the drag,
//    as its undeclared control does (and the saving arm's rise is no longer
//    the one retake the rung's step costs); and in `_settleTo`'s status
//    listener, `_moving.value = false;` -> `_moving.value = true;`: the
//    travel arm finds a resting sheet still declaring the whole area.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart' show GlassProxyFrame;
import 'package:g1455/src/surface/glass_modal.dart' show debugGlassSheetTravel;

const Size kScreen = Size(400, 800);
const Color kBackdrop = Color(0xFF406080);

void main() {
  testWidgets('dragged up, the top follows the finger to large, where the sheet is edge to edge', (
    WidgetTester tester,
  ) async {
    final detents = <GlassSheetDetent>[];
    final _Rig rig = await _Rig.mount(tester, onDetentChanged: detents.add);
    await rig.open();
    final Rect medium = rig.sheet.globalRect;
    expect(medium.left, closeTo(kGlassSheetInset, 0.01));
    expect(medium.bottom, closeTo(kScreen.height - kGlassSheetInset, 0.01));
    final double mediumRoom = rig.maxHeight;

    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    await finger.moveBy(const Offset(0, -20));
    await tester.pump();
    for (final double dy in <double>[-40, -60, -30]) {
      final double before = rig.sheet.globalRect.top;
      await finger.moveBy(Offset(0, dy));
      await tester.pump();
      expect(rig.sheet.globalRect.top - before, closeTo(dy, 0.01), reason: 'the top did not follow the finger');
    }
    // Part of the way up, part of the way out to the edges.
    final Rect between = rig.sheet.globalRect;
    expect(between.left, inExclusiveRange(0, kGlassSheetInset));
    expect(between.bottom, inExclusiveRange(kScreen.height - kGlassSheetInset, kScreen.height));
    await finger.moveBy(const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 200));
    await finger.up();
    await tester.pumpAndSettle();

    final Rect large = rig.sheet.globalRect;
    expect(large.left, 0);
    expect(large.right, kScreen.width);
    expect(large.bottom, kScreen.height);
    expect(large.top, closeTo(kGlassSheetInset, 0.01), reason: 'the top safe area is 0 here');
    expect(rig.maxHeight, greaterThan(mediumRoom), reason: 'the content was not offered the large room');
    expect(detents, <GlassSheetDetent>[GlassSheetDetent.large]);

    // And back down: the inset comes back with the medium detent.
    await tester.timedDrag(find.text('sheet body'), const Offset(0, 400), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rig.sheet.globalRect, medium);
    expect(detents, <GlassSheetDetent>[GlassSheetDetent.large, GlassSheetDetent.medium]);

    // A short flick goes on to the detent it was heading for; a short slow
    // drag goes back to the nearer one.
    await tester.fling(find.text('sheet body'), const Offset(0, -60), 1500);
    await tester.pumpAndSettle();
    expect(rig.sheet.globalRect, large, reason: 'a flick up did not reach large');
    await tester.timedDrag(find.text('sheet body'), const Offset(0, 60), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rig.sheet.globalRect, large, reason: 'a short slow drag left large');
  });

  testWidgets('a sheet with the default detent is the sheet it always was', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, detents: const <GlassSheetDetent>[GlassSheetDetent.medium]);
    await rig.open();
    final Rect medium = rig.sheet.globalRect;
    expect(rig.sheet.declaredFinish, isNull, reason: 'the sheet named a finish nobody gave it');
    await tester.timedDrag(find.text('sheet body'), const Offset(0, -300), const Duration(seconds: 1));
    await tester.pump();
    expect(rig.sheet.globalRect, medium, reason: 'a sheet with one detent grew');
    await tester.pumpAndSettle();
    expect(rig.sheet.globalRect, medium);
    expect(rig.sheet.effectiveTier, GlassTier.full);
  });

  testWidgets('opening at large, under reduced motion, a release settles on the next frame', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, initialDetent: GlassSheetDetent.large, reduceMotion: true);
    await rig.open();
    expect(rig.sheet.globalRect.left, 0);
    await tester.timedDrag(find.text('sheet body'), const Offset(0, 500), const Duration(seconds: 1));
    await tester.pump();
    expect(rig.sheet.globalRect.left, closeTo(kGlassSheetInset, 0.01), reason: 'the settle was animated');
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('all the way up an opaque sheet reads no backdrop; a translucent one keeps its capture', (
    WidgetTester tester,
  ) async {
    final results = <bool, _Cost>{};
    for (final bool opaque in <bool>[true, false]) {
      final _Rig rig = await _Rig.mount(tester, largeFinish: opaque ? null : GlassFinish.regularDark);
      await rig.open();
      final _Cost atMedium = rig.cost();
      expect(atMedium.captured, 2, reason: 'the bar and the sheet are both glass at medium');

      final int beforeRise = rig.recorded;
      await tester.timedDrag(find.text('sheet body'), const Offset(0, -500), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final int rise = rig.recorded - beforeRise;
      expect(rig.sheet.globalRect.left, 0, reason: 'never reached large');

      // The capture a change under the glass now takes.
      final int snapshots = rig.handle.snapshots;
      rig.page.value++;
      await tester.pump();
      await tester.pump();
      final _Cost atLarge = rig.cost();
      // And what a change inside the sheet's own content costs.
      final int beforeLabel = rig.recorded;
      rig.label.value = 'changed';
      await tester.pump();
      await tester.pump();
      results[opaque] = atLarge.copyWith(
        tier: rig.sheet.effectiveTier,
        cheapPaints: rig.sheet.paintsCheap,
        snapshotsPerRetake: atLarge.snapshots - snapshots,
        rise: rise,
        labelRetakes: rig.recorded - beforeLabel,
      );
      await tester.pumpWidget(const SizedBox());
    }
    final _Cost opaque = results[true]!;
    final _Cost glass = results[false]!;
    debugPrint('opaque $opaque\ntranslucent $glass');
    // The control: a translucent large sheet is still glass, still captured.
    expect(glass.tier, GlassTier.full);
    expect(glass.captured, 2);
    expect(glass.cheapPaints, 0);
    // What it saves, by the quantity named: one surface fewer in the capture,
    // and its area out of the atlas.
    expect(opaque.tier, GlassTier.cheap);
    expect(opaque.cheapPaints, greaterThan(0), reason: 'the sheet never drew on the rung that reads nothing');
    expect(opaque.captured, 1, reason: 'the opaque sheet is still in the capture');
    expect(opaque.capturedArea, lessThan(glass.capturedArea / 10));
    expect(opaque.atlas, lessThan(glass.atlas / 10), reason: 'the atlas did not shrink: $opaque against $glass');
    // By the quantity it moves: a level fewer to snapshot on every retake.
    expect(opaque.snapshotsPerRetake, greaterThan(0));
    expect(opaque.snapshotsPerRetake, lessThan(glass.snapshotsPerRetake));
    // And the other way: crossing the threshold is a retake, and the sheet is
    // ordinary content once it reads nothing, so a change inside it is one too.
    expect(opaque.rise, greaterThan(glass.rise), reason: 'the step to the cheap rung cost no retake');
    expect(glass.labelRetakes, 0);
    expect(opaque.labelRetakes, 1);
  });

  testWidgets('the step to the rung that reads nothing changes no picture', (WidgetTester tester) async {
    // A tint of full alpha against one a hair under it: the second stays on the
    // top rung and draws `mix(blurred, tint, 0.999)`, the first steps down and
    // draws the tint. And a translucent one, which must differ, or the
    // comparison is not looking at the sheet.
    final centre = <double, List<int>>{};
    for (final double alpha in <double>[1, 0.999, 0.693]) {
      final _Rig rig = await _Rig.mount(
        tester,
        initialDetent: GlassSheetDetent.large,
        largeFinish: GlassFinish.regularDark.copyWith(tint: Color.fromRGBO(29, 29, 32, alpha)),
      );
      await rig.open();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(rig.sheet.effectiveTier, alpha == 1 ? GlassTier.cheap : GlassTier.full);
      centre[alpha] = await rig.pixel(const Offset(200, 200));
      await tester.pumpWidget(const SizedBox());
    }
    debugPrint('centre $centre');
    for (var c = 0; c < 3; c++) {
      expect((centre[1]![c] - centre[0.999]![c]).abs(), lessThanOrEqualTo(1), reason: '$centre');
    }
    expect(centre[1]!.take(3), <int>[29, 29, 32]);
    var apart = 0;
    for (var c = 0; c < 3; c++) {
      apart += (centre[1]![c] - centre[0.693]![c]).abs();
    }
    expect(apart, greaterThan(15), reason: 'a translucent sheet looked opaque: $centre');
  });

  testWidgets('moving between detents it declares where it travels, and the drag is not retaken', (
    WidgetTester tester,
  ) async {
    final retakes = <bool, int>{};
    final atlas = <bool, int>{};
    addTearDown(() => debugGlassSheetTravel = true);
    for (final bool travel in <bool>[false, true]) {
      debugGlassSheetTravel = travel;
      // Translucent at large, so the step down a rung is not one of the
      // retakes counted.
      final _Rig rig = await _Rig.mount(tester, largeFinish: GlassFinish.regularDark);
      await rig.open();
      final int resting = rig.atlasPixels;
      final int before = rig.recorded;
      final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
      await finger.moveBy(const Offset(0, -20));
      await tester.pump();
      await tester.pump();
      atlas[travel] = rig.atlasPixels - resting;
      expect(rig.sheet.travel?.globalRect, travel ? isNotNull : isNull, reason: 'travel $travel, moving');
      var moved = 0;
      for (var i = 0; i < 12; i++) {
        final double top = rig.sheet.globalRect.top;
        await finger.moveBy(const Offset(0, -25));
        await tester.pump(const Duration(milliseconds: 16));
        if (rig.sheet.globalRect.top != top) {
          moved++;
        }
      }
      await finger.up();
      await tester.pumpAndSettle();
      expect(moved, 12, reason: 'the sheet did not move on every frame');
      // At rest it declares nothing: the region is the whole area, and a
      // resting sheet captured at that size would pay for screen it does not
      // cover.
      expect(rig.sheet.travel?.globalRect, isNull, reason: 'a resting sheet still declares where it travels');
      retakes[travel] = rig.recorded - before;
      await tester.pumpWidget(const SizedBox());
    }
    debugPrint('retakes $retakes, atlas growth on the first frame $atlas');
    // The control: undeclared, every frame the sheet changed size retook.
    expect(retakes[false], greaterThanOrEqualTo(12), reason: '$retakes');
    // Declared: the declaration itself, and nothing for the motion.
    expect(retakes[true], lessThanOrEqualTo(2), reason: '$retakes');
    // The price: while it moves the sheet's slot is the whole area it can
    // stand in, not its box.
    expect(atlas[true], greaterThan(0), reason: 'the declared region cost the atlas nothing: $atlas');
  });

  // A tap is not a drag. The sheet's recognizer is the only one under a tap
  // on its body, so it wins the arena and ends with no velocity; under a tap
  // on a button inside, it loses and is cancelled. Either used to re-pick the
  // nearer detent and restart the settle, sending a sheet flicked to large
  // back to medium.
  testWidgets('a tap on a settling sheet, on its body or a button in it, leaves the settle alone', (
    WidgetTester tester,
  ) async {
    for (final String target in <String>['sheet body', 'sheet button']) {
      final detents = <GlassSheetDetent>[];
      var pressed = 0;
      final _Rig rig = await _Rig.mount(
        tester,
        onDetentChanged: detents.add,
        content: (BuildContext context) => SizedBox(
          height: 300,
          child: Column(
            children: <Widget>[
              const Expanded(child: Center(child: Text('sheet body'))),
              GestureDetector(onTap: () => pressed++, child: const Text('sheet button')),
            ],
          ),
        ),
      );
      await rig.open();
      await tester.fling(find.text('sheet body'), const Offset(0, -60), 1500);
      await tester.pump();
      expect(rig.sheet.globalRect.left, greaterThan(0), reason: '$target: the settle was over before the tap');
      await tester.tap(find.text(target));
      await tester.pumpAndSettle();
      expect(rig.sheet.globalRect.left, 0, reason: '$target: the tap sent the sheet back');
      expect(detents, <GlassSheetDetent>[GlassSheetDetent.large], reason: target);
      expect(pressed, target == 'sheet button' ? 1 : 0);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a drag whose pointer is cancelled half way still settles at a detent', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester);
    await rig.open();
    final double medium = rig.sheet.globalRect.left;
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
    await finger.moveBy(const Offset(0, -20));
    await tester.pump();
    await finger.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(rig.sheet.globalRect.left, inExclusiveRange(0, medium), reason: 'the drag never left medium');
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(rig.sheet.globalRect.left, anyOf(0, medium), reason: 'a cancelled drag left the sheet between detents');
  });

  // Resting at large, the sheet does not re-measure its content's medium
  // height on every change — but a drag down from there moves the top by that
  // height's distance from large, so it must be current when the drag begins.
  // The content here is as tall as the window when narrow, so at large there is
  // no distance at all to medium; widened, or shortened, it has 300 px of it.
  testWidgets('dragged down from large after the content or the window changed, the top follows the finger', (
    WidgetTester tester,
  ) async {
    for (final String change in <String>['window', 'content']) {
      final tall = ValueNotifier<bool>(true);
      addTearDown(tall.dispose);
      final _Rig rig = await _Rig.mount(
        tester,
        initialDetent: GlassSheetDetent.large,
        content: (BuildContext context) => LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => ValueListenableBuilder<bool>(
            valueListenable: tall,
            builder: (BuildContext context, bool tall, Widget? _) => SizedBox(
              height: tall && constraints.maxWidth < 500 ? 2000 : 300,
              child: const Center(child: Text('sheet body')),
            ),
          ),
        ),
      );
      await rig.open();
      expect(rig.sheet.globalRect.left, 0);
      if (change == 'window') {
        tester.view.physicalSize = const Size(800, 800) * 2;
      } else {
        tall.value = false;
      }
      await tester.pumpAndSettle();
      expect(rig.sheet.globalRect.top, closeTo(kGlassSheetInset, 0.01), reason: '$change: not at large');

      final TestGesture finger = await tester.startGesture(tester.getCenter(find.text('sheet body')));
      await tester.pump();
      final double start = rig.sheet.globalRect.top;
      // Past the slop, so the drag is accepted; what it delivers of these 20 px
      // is the recognizer's business, and is bounded rather than assumed.
      await finger.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(rig.sheet.globalRect.top - start, inInclusiveRange(0, 20.01), reason: '$change: the top jumped');
      for (final double dy in <double>[30, 30]) {
        final double before = rig.sheet.globalRect.top;
        await finger.moveBy(Offset(0, dy));
        await tester.pump();
        expect(rig.sheet.globalRect.top - before, closeTo(dy, 0.01), reason: '$change: the top jumped');
      }
      await finger.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });
}

class _Cost {
  const _Cost({
    required this.captured,
    required this.capturedArea,
    required this.atlas,
    required this.snapshots,
    this.tier,
    this.cheapPaints = 0,
    this.snapshotsPerRetake = 0,
    this.rise = 0,
    this.labelRetakes = 0,
  });

  final int captured;
  final double capturedArea;
  final int atlas;
  final int snapshots;
  final GlassTier? tier;
  final int cheapPaints;
  final int snapshotsPerRetake;
  final int rise;
  final int labelRetakes;

  _Cost copyWith({GlassTier? tier, int? cheapPaints, int? snapshotsPerRetake, int? rise, int? labelRetakes}) => _Cost(
    captured: captured,
    capturedArea: capturedArea,
    atlas: atlas,
    snapshots: snapshots,
    tier: tier ?? this.tier,
    cheapPaints: cheapPaints ?? this.cheapPaints,
    snapshotsPerRetake: snapshotsPerRetake ?? this.snapshotsPerRetake,
    rise: rise ?? this.rise,
    labelRetakes: labelRetakes ?? this.labelRetakes,
  );

  @override
  String toString() =>
      '${tier?.name}: captured $captured, area ${capturedArea.round()} px², atlas $atlas px, '
      '$snapshotsPerRetake snapshots a retake, $rise retakes rising, $labelRetakes for a label, '
      '$cheapPaints cheap paints';
}

final GlobalKey _shotKey = GlobalKey();

class _Rig {
  _Rig._(this.tester, this.hostKey, this.label, this.page, this.heights);

  final WidgetTester tester;
  final GlobalKey hostKey;
  final ValueNotifier<String> label;
  final ValueNotifier<int> page;
  final List<double> heights;

  static Future<_Rig> mount(
    WidgetTester tester, {
    GlassFinish? largeFinish,
    List<GlassSheetDetent> detents = const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
    GlassSheetDetent? initialDetent,
    ValueChanged<GlassSheetDetent>? onDetentChanged,
    bool reduceMotion = false,
    WidgetBuilder? content,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view
      ..physicalSize = kScreen * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final hostKey = GlobalKey();
    final label = ValueNotifier<String>('label');
    final page = ValueNotifier<int>(0);
    final heights = <double>[];
    addTearDown(label.dispose);
    addTearDown(page.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => RepaintBoundary(
          key: _shotKey,
          child: GlassHost(
            key: hostKey,
            hardware: GlassHardware.appleMetal,
            backdrop: kBackdrop,
            child: reduceMotion
                ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
                : child!,
          ),
        ),
        home: Builder(
          builder: (BuildContext context) => Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: page,
                    builder: (BuildContext context, int v, Widget? _) => CustomPaint(painter: _Stripes(v)),
                  ),
                ),
              ),
              const Positioned(left: 16, right: 16, top: 40, height: 56, child: GlassBar(child: Text('bar'))),
              Center(
                child: GestureDetector(
                  onTap: () => showGlassSheet<void>(
                    context: context,
                    detents: detents,
                    initialDetent: initialDetent,
                    largeFinish: largeFinish,
                    onDetentChanged: onDetentChanged,
                    builder: (BuildContext context) => LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        heights.add(constraints.maxHeight);
                        if (content != null) {
                          return content(context);
                        }
                        return SizedBox(
                          height: 300,
                          child: Column(
                            children: <Widget>[
                              const Expanded(child: Center(child: Text('sheet body'))),
                              RepaintBoundary(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: label,
                                  builder: (BuildContext context, String v, Widget? _) => Text(v),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  child: const Text('open sheet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _Rig._(tester, hostKey, label, page, heights);
  }

  Future<void> open() async {
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
  }

  /// The most height the sheet last offered its content.
  double get maxHeight => heights.last;

  int get recorded => (hostKey.currentState! as dynamic).recorded as int;

  GlassProxyHandle get handle => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

  RenderGlassSurface get sheet => tester.renderObject<RenderGlassSurface>(
    find.ancestor(of: find.text('sheet body'), matching: find.byType(GlassSurface)).first,
  );

  /// The published capture's pixels, every level.
  int get atlasPixels {
    var n = 0;
    for (final GlassProxyFrame? f in <GlassProxyFrame?>[handle.frame, ...handle.upper]) {
      if (f != null) {
        n += f.image.width * f.image.height;
      }
    }
    return n;
  }

  _Cost cost() {
    final GlassLoad load = GlassScope.maybeOf(
      tester.element(find.text('sheet body')),
    )!.read(viewSize: kScreen, model: GlassSurfaceCostModel.metalThroughput);
    return _Cost(
      captured: load.capturedSurfaceCount,
      capturedArea: load.capturedRectAreaLogical,
      atlas: atlasPixels,
      snapshots: handle.snapshots,
    );
  }

  Future<List<int>> pixel(Offset at) async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer! as OffsetLayer;
    final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
    late Uint8List px;
    await tester.runAsync(() async {
      px = (await shot.toByteData())!.buffer.asUint8List();
    });
    shot.dispose();
    final int i = (at.dy.round() * kScreen.width.round() + at.dx.round()) * 4;
    return px.sublist(i, i + 4);
  }
}

class _Stripes extends CustomPainter {
  _Stripes(this.v);

  final int v;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kBackdrop);
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawRect(
        Rect.fromLTWH(0, y + v, size.width, 12),
        Paint()..color = HSVColor.fromAHSV(1, (y * 3 + v * 40) % 360, 0.7, 0.9).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => oldDelegate.v != v;
}
