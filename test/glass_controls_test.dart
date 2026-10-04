// The switch and the slider: a drop that exists only while held, and what it
// costs the capture.
//
// `flutter test test/glass/glass_controls_test.dart`
//
// The claims are about the capture, because that is what a control on a glass
// screen can cost everyone else: at rest the drop is not captured at all and
// the divisor is the one the screen would have without it; held, it is
// captured once, in its own finish and its own slot; dragged, a switch's drop
// is drawn from the proxy it already holds.
//
// Disabled, a control is iOS's: drawn whole at half over its backdrop, as one
// group (D221), and with no drop in the tree, because it cannot be held. The
// pixel arm's break is the half spent per part instead of on the group — the
// track then shows through the knob, which Apple's does not.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

// The pixel arm prints what it compared; a person reads it once.
// ignore_for_file: avoid_print

const Size kScreen = Size(400, 400);

void main() {
  testWidgets('at rest the drop costs the capture nothing', (WidgetTester tester) async {
    final GlobalKey hostKey = GlobalKey();
    await _mount(tester, hostKey, const _Screen(control: _Control.none));
    final GlassProxyHandle bare = _handle(tester);
    final int bareDivisor = bare.frame!.resolution.resolution.divisor;
    expect(bare.frame!.keys, hasLength(1));

    await _mount(tester, GlobalKey(), const _Screen(control: _Control.toggle));
    final GlassProxyHandle withSwitch = _handle(tester);
    expect(withSwitch.frame!.keys, hasLength(1), reason: 'a resting drop was captured');
    expect(withSwitch.frame!.resolution.resolution.divisor, bareDivisor);
    final RenderGlassSurface drop = _drop(tester);
    expect(drop.materialize, 0);
    expect(drop.paintsWithProxy, 0, reason: 'a resting drop drew glass');
  });

  testWidgets('a screen whose only glass is a resting drop settles', (WidgetTester tester) async {
    // Nothing to capture, so the host publishes no frame and no levels on
    // every frame — and publishing the empty levels used to notify, which
    // repainted the drop, whose repaint was the next frame: an idle screen of
    // switches drew for ever. Break: drop the `listEquals` guard in
    // `GlassProxyHandle.publishUpper`.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(
          hardware: GlassHardware.appleMetal,
          child: Center(child: GlassSwitch(value: false, onChanged: (_) {})),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'an idle screen keeps drawing');
  });

  testWidgets('a tap toggles, and the semantics say so', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _mount(tester, GlobalKey(), const _Screen(control: _Control.toggle));
    expect(
      tester.getSemantics(find.byType(GlassSwitch)),
      matchesSemantics(
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(GlassSwitch));
    await tester.pumpAndSettle();
    expect(find.text('on'), findsOneWidget);
    expect(_drop(tester).materialize, 0, reason: 'the drop did not settle after the tap');
    semantics.dispose();
  });

  Future<void> heldAndDragged(WidgetTester tester, GlassDropMotion motion) async {
    final GlobalKey hostKey = GlobalKey();
    await _mount(
      tester,
      hostKey,
      _Screen(key: ValueKey<GlassDropMotion>(motion), control: _Control.toggle, dropMotion: motion),
    );
    final dynamic host = hostKey.currentState! as dynamic;
    final int atRest = host.recorded as int;

    final Offset knob = tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22);
    final TestGesture gesture = await tester.startGesture(knob);
    // Past the 18 px touch slop, so the drag recognizer wins.
    await gesture.moveBy(const Offset(20, 0));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final RenderGlassSurface drop = _drop(tester);
    expect(drop.materialize, 1, reason: 'the drop never lifted');
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame!.keys, hasLength(2), reason: 'the held drop is not in the capture');
    expect(
      handle.frame!.layout.slots,
      hasLength(2),
      reason: 'the clear drop shares a regular slot',
    );
    final int lifted = host.recorded as int;
    expect(lifted - atRest, greaterThan(0));
    expect(drop.paintsWithOptics, greaterThan(0), reason: 'the held drop drew no glass');

    // Small steps: the knob travels 22 px in all, and a step that pinned it at
    // the stop would move nothing.
    final int moves = drop.drawRecordsOnMove;
    final int records = drop.drawRecords;
    var moved = 0;
    var deformed = 0;
    Rect where = drop.globalRect;
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
      if (drop.globalRect != where) {
        moved++;
        if (drop.globalRect.size != where.size) {
          deformed++;
        }
        where = drop.globalRect;
      }
    }
    expect(moved, 6, reason: '$motion: the drop did not follow the finger');
    expect((host.recorded as int) - lifted, 0, reason: '$motion: dragging a held drop retook the proxy');
    if (motion.isNone) {
      expect(deformed, 0);
      expect(
        drop.drawRecordsOnMove - moves,
        moved,
        reason: 'the drop was redrawn by a paint, not by moving',
      );
    } else {
      // Deformed, it is drawn by a paint of its own layer instead — one draw
      // a frame all the same, and nothing captured.
      expect(deformed, greaterThan(0), reason: 'the drop did not stretch');
      expect(drop.drawRecords - records, moved, reason: 'a deformed drop is more than one draw a frame');
    }

    // Past the middle at release, so the value commits.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('on'), findsOneWidget, reason: 'a drag past the middle did not commit');
    expect(_handle(tester).frame!.keys, hasLength(1), reason: 'the settled drop is still captured');
  }

  testWidgets('held, the drop is captured once in its own finish; dragged, not again', (
    WidgetTester tester,
  ) async {
    // Twice: keeping its shape, where a drag is drawn by moving alone; and
    // stretching, the default.
    for (final GlassDropMotion motion in const <GlassDropMotion>[GlassDropMotion.none, GlassDropMotion()]) {
      await heldAndDragged(tester, motion);
    }
  });

  testWidgets('the drop stretches launching and squashes braking, inside its region', (
    WidgetTester tester,
  ) async {
    await _mount(tester, GlobalKey(), const _Screen(control: _Control.toggle));
    final TestGesture gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22),
    );
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(-20, 0));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final RenderGlassSurface drop = _drop(tester);
    final Size held = drop.size;
    expect(held, _kSwitchKnob * kGlassDropScale, reason: 'held still, the drop is not round');
    final RenderGlassTravel travel = tester.renderObject<RenderGlassTravel>(find.byType(GlassTravel));
    final Rect region = MatrixUtils.transformRect(travel.getTransformTo(null), Offset.zero & travel.size);
    // Across the track by hand, fast, then held still: launch, brake, settle.
    var most = 0.0;
    var least = 0.0;
    for (final double dx in <double>[6, 6, 6, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) {
      if (dx != 0) {
        await gesture.moveBy(Offset(dx, 0));
      }
      await tester.pump(const Duration(milliseconds: 16));
      final double s = _stretchOf(drop.size, held);
      most = math.max(most, s);
      least = math.min(least, s);
      expect(
        region.expandToInclude(drop.globalRect) == region,
        isTrue,
        reason: 'the deformed drop left its region: ${drop.globalRect} in $region',
      );
    }
    expect(most, greaterThan(0.005), reason: 'the drop did not stretch launching');
    expect(least, lessThan(-0.005), reason: 'the drop did not squash braking');
    expect(most, lessThanOrEqualTo(const GlassDropMotion().maxStretch));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(drop.size, held, reason: 'held still, the drop did not spring back');
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'a drop held still keeps drawing');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the slider\'s drop is round at rest and gliding, and long setting off', (
    WidgetTester tester,
  ) async {
    await _mount(tester, GlobalKey(), const _Screen(control: _Control.slider));
    final Rect slider = tester.getRect(find.byType(GlassSlider));
    final TestGesture gesture = await tester.startGesture(slider.centerLeft + const Offset(40, 0));
    // Past the slop, back, and held: the drop placed by the tap is round.
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(-20, 0));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final RenderGlassSurface drop = _drop(tester);
    final Size held = drop.size;
    expect(held, _kSliderKnob * kGlassDropScale, reason: 'at rest, the drop is not round');
    var most = 0.0;
    final glide = <double>[];
    for (var i = 0; i < 50; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final double s = _stretchOf(drop.size, held);
      most = math.max(most, s);
      if (i >= 40) {
        glide.add(s);
      }
    }
    expect(most, greaterThan(0.005), reason: 'the drop did not stretch setting off');
    for (final double s in glide) {
      expect(s.abs(), lessThan(0.002), reason: 'gliding at a constant speed, the drop is deformed');
    }
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('no stretch under reduced motion, or with none', (WidgetTester tester) async {
    for (final (GlassDropMotion? motion, bool reduced) in <(GlassDropMotion?, bool)>[
      (GlassDropMotion.none, false),
      (null, true),
    ]) {
      await _mount(
        tester,
        GlobalKey(),
        _Screen(control: _Control.toggle, dropMotion: motion),
        reducedMotion: reduced,
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final RenderGlassSurface drop = _drop(tester);
      final Size held = drop.size;
      for (final double dx in <double>[20, 6, 6, 0, 0, 0]) {
        await gesture.moveBy(Offset(dx, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(drop.size, held, reason: '$motion, reduced motion $reduced: the drop deformed');
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  test('the drop optics reproduce the two readings they were fitted to (D218)', () {
    // The shader's bend: `(1 - (u/t)^shoulder)^edgePower`, times the strength.
    double shift(double u) {
      const GlassOptics o = kGlassDropOptics;
      final double t = (u / o.thickness).clamp(0.0, 1.0);
      return o.strength * math.pow(1 - math.pow(t, o.shoulder), o.edgePower);
    }

    // iOS's slider drop: 2.48 and 2.13 device px at dpr 2, 3.0 and 2.7 pt in.
    expect(shift(3).abs(), closeTo((2.48 + 2.13) / 4, 0.05));
    expect(shift(10), 0, reason: 'iOS moves nothing from 10 pt in');
    // And the material's optics, for scale: an order of magnitude more.
    expect(
      -const GlassOptics().strength * math.pow(1 - math.pow(3 / 21, 0.6), 1.9),
      greaterThan(20),
    );
  });

  testWidgets('a held drop is the knob times its scale: 1.57 by default, any when asked', (
    WidgetTester tester,
  ) async {
    // 1.57 is iOS's, for both controls (D217); macOS's own differ per control
    // (1.4 the slider, 1.6 the switch, D210), which is what the parameter is for.
    expect(kGlassDropScale, 1.57);
    const knob = Size(38, 24);
    for (final _Control control in <_Control>[_Control.toggle, _Control.slider]) {
      for (final double? scale in <double?>[null, 1.4, 1.6]) {
        await _mount(tester, GlobalKey(), _Screen(control: control, dropScale: scale));
        final Offset at = control == _Control.toggle
            ? tester.getTopLeft(find.byType(GlassSwitch)) + const Offset(21, 22)
            : tester.getRect(find.byType(GlassSlider)).centerLeft + const Offset(40, 0);
        final TestGesture gesture = await tester.startGesture(at);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final RenderGlassSurface drop = _drop(tester);
        expect(drop.materialize, 1, reason: '$control: the drop never lifted');
        final Size want = knob * (scale ?? kGlassDropScale);
        expect(drop.size.width, closeTo(want.width, 1e-9), reason: '$control at $scale');
        expect(drop.size.height, closeTo(want.height, 1e-9), reason: '$control at $scale');
        await gesture.up();
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('the slider knob sits where the fill ends, held or not', (WidgetTester tester) async {
    await _mount(tester, GlobalKey(), const _Screen(control: _Control.slider));
    final Rect slider = tester.getRect(find.byType(GlassSlider));
    Future<void> check(String when) async {
      final double value = double.parse(
        (tester.widget<Text>(find.byKey(const ValueKey<String>('value'))).data)!,
      );
      final Rect knob = _drop(tester).globalRect;
      expect(
        knob.center.dx - slider.left,
        moreOrLessEquals(SliderGeometry.fillEnd(value, slider.width), epsilon: 0.01),
        reason: '$when: knob at ${knob.center.dx - slider.left} for value $value',
      );
    }

    await check('at rest');
    final TestGesture gesture = await tester.startGesture(slider.centerLeft + const Offset(40, 0));
    await gesture.moveBy(const Offset(60, 0));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_drop(tester).materialize, 1);
    await check('held');
    await gesture.up();
    await tester.pumpAndSettle();
    await check('released');
  });

  testWidgets('disabled, a control is drawn whole at half over its backdrop, with no drop', (
    WidgetTester tester,
  ) async {
    // iOS 26: 0.502 on every part of a disabled UISwitch and UISlider, the
    // colours unchanged, in both appearances (D221).
    expect(kGlassDisabledOpacity, 0.5);
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final (_Control control, bool on) in <(_Control, bool)>[
      (_Control.toggle, false),
      (_Control.toggle, true),
      (_Control.slider, false),
    ]) {
      final String arm = '$control${on ? ' on' : ''}';
      await _mount(tester, GlobalKey(), const _Screen(control: _Control.none));
      final Uint8List bare = await _shot(tester);
      await _mount(tester, GlobalKey(), _Screen(control: control, on: on));
      await tester.pumpAndSettle();
      final Uint8List enabled = await _shot(tester);
      final Rect box = tester.getRect(_finder(control)).inflate(4);
      await _mount(tester, GlobalKey(), _Screen(control: control, on: on, enabled: false));
      await tester.pumpAndSettle();
      final Uint8List disabled = await _shot(tester);

      expect(_drops(tester), isEmpty, reason: '$arm: a disabled control holds a drop');
      expect(
        tester.getSemantics(_finder(control)),
        isA<SemanticsNode>().having(
          (SemanticsNode n) => n.getSemanticsData().flagsCollection.isEnabled,
          'isEnabled',
          isNot(true),
        ),
      );

      // Every pixel of the box: disabled = (enabled + backdrop) / 2, to the
      // rounding of two 8-bit composites — except where a knob's edge is
      // antialiased inside the group's layer rather than on the screen, which
      // moves a couple of pixels by a few code values. Spent per part instead,
      // the half lets the track through the knob: ~50 code values on the green.
      var compared = 0, drawn = 0, outliers = 0;
      var worst = 0.0;
      final int stride = kScreen.width.toInt();
      for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
        for (var x = box.left.floor(); x < box.right.ceil(); x++) {
          final int i = (y * stride + x) * 4;
          var differs = false, off = false;
          for (var k = 0; k < 3; k++) {
            final double want = (enabled[i + k] + bare[i + k]) / 2;
            final double error = (disabled[i + k] - want).abs();
            worst = math.max(worst, error);
            off |= error > 1.5;
            differs |= (enabled[i + k] - bare[i + k]).abs() > 16;
          }
          compared++;
          if (differs) {
            drawn++;
          }
          if (off) {
            outliers++;
          }
        }
      }
      print(
        '$arm: $compared px compared, $drawn drawn by the control, '
        '$outliers off the law by > 1.5, worst ${worst.toStringAsFixed(1)}',
      );
      expect(drawn, greaterThan(300), reason: '$arm: the box does not hold the control');
      expect(outliers, lessThanOrEqualTo(drawn ~/ 100), reason: '$arm: not one group at half');
      expect(worst, lessThanOrEqualTo(8), reason: '$arm: not one group at half');
    }
    semantics.dispose();
  });

  testWidgets('disabled mid-drag, a control lets go', (WidgetTester tester) async {
    // Once the handlers are gone the drag's end never arrives, so a drop lifted
    // when the control was disabled would come back lifted when it is enabled
    // again. Only a drag: a finger held still is let go by the framework — the
    // tap recognizer, disposed, rejects its gesture and calls the
    // `onTapCancel` it was built with — and that half of the reset is the
    // break that failed to break (D221).
    for (final _Control control in <_Control>[_Control.toggle, _Control.slider]) {
      final GlobalKey hostKey = GlobalKey();
      await _mount(tester, hostKey, _Screen(control: control));
      final TestGesture gesture = await tester.startGesture(
        tester.getRect(_finder(control)).centerLeft + const Offset(21, 0),
      );
      // Past the 18 px touch slop, so the drag recognizer wins.
      await gesture.moveBy(const Offset(20, 0));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_drop(tester).materialize, 1, reason: '$control: the drop never lifted');
      await _mount(tester, hostKey, _Screen(control: control, enabled: false));
      await gesture.up();
      await tester.pumpAndSettle();
      await _mount(tester, hostKey, _Screen(control: control));
      await tester.pumpAndSettle();
      expect(_drop(tester).materialize, 0, reason: '$control: re-enabled with the drop still up');
    }
  });
}

enum _Control { none, toggle, slider }

const Size _kSwitchKnob = Size(38, 24);
const Size _kSliderKnob = Size(38, 24);

/// The stretch a drop of [size] shows against its round [held] size: its
/// aspect is `(1 + s)²` times the held one.
double _stretchOf(Size size, Size held) => math.sqrt(size.aspectRatio / held.aspectRatio) - 1;

Finder _finder(_Control control) => find.byType(control == _Control.toggle ? GlassSwitch : GlassSlider);

Iterable<RenderGlassSurface> _drops(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .where((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);

class _Screen extends StatefulWidget {
  const _Screen({
    required this.control,
    this.dropScale,
    this.dropMotion,
    this.enabled = true,
    this.on = false,
    super.key,
  });

  /// Passed to the control.
  final GlassDropMotion? dropMotion;

  /// Null `onChanged` when false.
  final bool enabled;

  /// The switch's starting value.
  final bool on;

  /// Passed to the control when set; its default otherwise.
  final double? dropScale;

  final _Control control;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  late bool _on = widget.on;
  double _value = 0.3;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: kScreen,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
        ),
        // A panel, so the screen has glass of its own finish to compare with.
        const Positioned(left: 20, top: 20, width: 200, height: 60, child: GlassSurface()),
        if (widget.control == _Control.toggle)
          Positioned(
            left: 100,
            top: 200,
            child: GlassSwitch(
              value: _on,
              onChanged: widget.enabled ? (bool v) => setState(() => _on = v) : null,
              dropScale: widget.dropScale ?? kGlassDropScale,
              dropMotion: widget.dropMotion,
            ),
          ),
        if (widget.control == _Control.slider)
          Positioned(
            left: 40,
            top: 200,
            width: 300,
            child: GlassSlider(
              value: _value,
              onChanged: widget.enabled ? (double v) => setState(() => _value = v) : null,
              dropScale: widget.dropScale ?? kGlassDropScale,
              dropMotion: widget.dropMotion,
            ),
          ),
        Positioned(
          left: 0,
          top: 300,
          child: Text(
            widget.control == _Control.slider ? '$_value' : (_on ? 'on' : 'off'),
            key: const ValueKey<String>('value'),
          ),
        ),
      ],
    ),
  );
}

Future<void> _mount(WidgetTester tester, GlobalKey hostKey, Widget screen, {bool reducedMotion = false}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: kScreen, devicePixelRatio: 2, disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: hostKey,
            hardware: GlassHardware.appleMetal,
            child: RepaintBoundary(key: _shotKey, child: screen),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

final GlobalKey _shotKey = GlobalKey();

/// The screen, logical px, RGBA.
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

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

/// The control's drop: the one surface wearing a clear finish — the switch's
/// widened, so by name.
RenderGlassSurface _drop(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);

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
