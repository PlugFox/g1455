// Moving glass: drawn where it is on the frame it moved, and — inside a
// declared travel region — drawn from the proxy it already holds.
//
// `flutter test test/glass/glass_travel_test.dart`
//
// Every arm renders an **identity glass** at dpr 1, so a surface sampling the
// right place is invisible and one sampling anywhere else is not. That is what
// makes motion testable at all: the obvious check — "the glass looks like
// glass after it moved" — passes on a surface drawing last frame's backdrop,
// which is also glass.
//
// The content the surface moves over sits behind a repaint boundary of its own.
// That is the condition `GlassTravel` states, and the arms rely on it: moving a
// `Positioned` repaints its parent's boundary, and a background painted in that
// boundary would mint a new picture under the glass — a real change as far as
// the layer watch can tell, and a retake.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 600);
const Rect kRegion = Rect.fromLTWH(20, 100, 360, 120);
const Size kKnob = Size(120, 80);
final GlobalKey _shotKey = GlobalKey();

void main() {
  testWidgets('a surface that moved samples where it now is, on the frame it moved', (
    WidgetTester tester,
  ) async {
    // Undeclared motion, so the proxy is retaken after every move and the frame
    // of the move is drawn from a capture of the *old* box. Two defects look the
    // same here and only one of them is structural. A surface drawing with the
    // previous position's map is wrong over its whole box (4538 px at 37 px of
    // motion, before `GlassDrawLayer`); a surface drawing with the right map
    // from a slot that stops at its old box is wrong only in the strip it moved
    // into, which is the one-frame lag every capture has and the reason
    // `GlassTravel` exists. So the arm asserts where the error is, not that
    // there is none — and that there is some, or it is not looking.
    final Uint8List bare = await _bare(tester);
    final x = ValueNotifier<double>(0);
    addTearDown(x.dispose);
    await _pump(tester, _Scene(x: x), hostKey: GlobalKey());
    expect((await _where(tester, bare)).count, 0, reason: 'the glass is visible before it moved');

    for (var step = 1; step <= 5; step++) {
      final double oldRight = kRegion.left + x.value + kKnob.width;
      x.value = step * 37.0;
      await tester.pump();
      final ({int count, double minX}) error = await _where(tester, bare);
      expect(error.count, greaterThan(0), reason: 'step $step: the lag is not visible at all');
      expect(
        error.minX,
        greaterThanOrEqualTo(oldRight),
        reason:
            'step $step: the surface is wrong inside the box it was captured at, so it drew '
            'with a stale map rather than from a stale slot ($error)',
      );
    }
  });

  testWidgets('inside its declared region it moves on the proxy it already holds', (
    WidgetTester tester,
  ) async {
    final Uint8List bare = await _bare(tester);
    final Map<bool, int> retakes = <bool, int>{};
    for (final bool travel in <bool>[false, true]) {
      final x = ValueNotifier<double>(0);
      addTearDown(x.dispose);
      final hostKey = GlobalKey();
      await _pump(
        tester,
        _Scene(x: x, travel: travel),
        hostKey: hostKey,
      );
      final dynamic host = hostKey.currentState! as dynamic;
      final int before = host.recorded as int;
      expect(before, greaterThan(0), reason: 'no proxy was ever taken');
      for (var step = 1; step <= 6; step++) {
        x.value = step * 38.0;
        await tester.pump();
        // Only the declared arm is exact on the frame of the move; the other is
        // the lag the first arm locates.
        if (travel) {
          expect(await _differing(tester, bare), 0, reason: 'step $step: the glass is visible');
        }
      }
      retakes[travel] = (host.recorded as int) - before;
      if (travel) {
        // And the pixels are right *because* the draw followed the surface, not
        // because something repainted it: nothing was published to repaint it.
        final RenderGlassSurface knob = tester.renderObject(find.byType(GlassSurface));
        expect(knob.drawRecordsOnMove, greaterThanOrEqualTo(6));
      }
    }
    // The control first: without a declaration every move is a retake, so the
    // held arm below is a saving and not a pipeline that stopped recording.
    expect(retakes[false], greaterThanOrEqualTo(6), reason: 'undeclared motion was held: $retakes');
    expect(retakes[true], 0, reason: 'motion inside the declared region was retaken: $retakes');
  });

  testWidgets('a fused member moves on the held proxy too, bridge and all', (
    WidgetTester tester,
  ) async {
    // The group computes the silhouette from where its members are, and a
    // member that moved behind its own boundary does not paint the group. So
    // this is the same two claims for the fused draw: the bridge follows the
    // member on the frame it moved, and no capture is taken for it. Steps run
    // from well apart to overlapping, so the bridge forms inside the arm.
    //
    // **Tinted, not the identity**, and the identity passed a broken group: a
    // stale silhouette drawn with a correct map shows the right backdrop
    // wherever it is, so it is invisible. With a tint the silhouette's place is
    // visible, and each held frame is compared with a fresh mount of the same
    // positions instead of with the bare screen.
    final x = ValueNotifier<double>(230);
    addTearDown(x.dispose);
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _Scene(x: x, travel: true, fused: true),
      hostKey: hostKey,
      finish: _tinted,
    );
    final dynamic host = hostKey.currentState! as dynamic;
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    expect(group.fusedPaints, greaterThan(0), reason: 'the pair never fused');
    final int before = host.recorded as int;
    final int movesBefore = group.drawRecordsOnMove;
    final positions = <double>[for (var step = 1; step <= 6; step++) 230 - step * 24.0];
    final held = <Uint8List>[];
    for (final double at in positions) {
      x.value = at;
      await tester.pump();
      held.add(await _pixels(tester, _frame()));
    }
    expect(
      (host.recorded as int) - before,
      0,
      reason: 'a member moving inside its region was retaken',
    );

    for (var i = 0; i < positions.length; i++) {
      final fresh = ValueNotifier<double>(positions[i]);
      addTearDown(fresh.dispose);
      await _pump(
        tester,
        _Scene(x: fresh, travel: true, fused: true),
        hostKey: GlobalKey(),
        finish: _tinted,
      );
      final Uint8List expected = await _pixels(tester, _frame());
      var differing = 0;
      for (var p = 0; p < expected.length; p++) {
        if (expected[p] != held[i][p]) {
          differing++;
        }
      }
      expect(differing, 0, reason: 'at ${positions[i]} the held group drew another silhouette');
    }
    // After the pixels, so a break shows in them first: a group repainted by
    // something else would pass them without this layer doing anything.
    expect(group.drawRecordsOnMove - movesBefore, greaterThanOrEqualTo(positions.length));
  });

  testWidgets('a union moves on the held proxy too, though its blend radius follows the members', (
    WidgetTester tester,
  ) async {
    // The same arm as the group's, for the one fused draw whose bridges depend
    // on where its members are: a union solves `k` from their distances, so the
    // reach its capture is inflated by followed the knob, the capture input
    // moved with every step, and the declared region bought nothing — six
    // retakes in six steps. The capture is now sized for the largest `k` the
    // members can reach inside their regions (`unionBlendRadiusBound`); the
    // picture keeps the solved one, which the fresh mounts check.
    final x = ValueNotifier<double>(230);
    addTearDown(x.dispose);
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _Scene(x: x, travel: true, fused: true, union: true),
      hostKey: hostKey,
      finish: _tinted,
    );
    final dynamic host = hostKey.currentState! as dynamic;
    final RenderGlassGroup group = tester.renderObject(
      find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_GlassGroupRenderWidget'),
    );
    expect(group.fusedPaints, greaterThan(0), reason: 'the pair never fused');
    final int before = host.recorded as int;
    final positions = <double>[for (var step = 1; step <= 6; step++) 230 - step * 24.0];
    final held = <Uint8List>[];
    final blends = <double>[];
    for (final double at in positions) {
      x.value = at;
      await tester.pump();
      held.add(await _pixels(tester, _frame()));
      blends.add(group.lastBlendRadius);
    }
    final int retakes = (host.recorded as int) - before;
    // ignore: avoid_print
    print('union in motion: retakes $retakes, solved k $blends');
    // The solved radius has to have moved, or this arm is the group's again.
    expect(blends.toSet().length, greaterThan(2), reason: 'k did not follow the members');
    expect(retakes, 0, reason: 'a union member moving inside its region was retaken');

    for (var i = 0; i < positions.length; i++) {
      final fresh = ValueNotifier<double>(positions[i]);
      addTearDown(fresh.dispose);
      await _pump(
        tester,
        _Scene(x: fresh, travel: true, fused: true, union: true),
        hostKey: GlobalKey(),
        finish: _tinted,
      );
      final Uint8List expected = await _pixels(tester, _frame());
      var differing = 0;
      for (var p = 0; p < expected.length; p++) {
        if (expected[p] != held[i][p]) {
          differing++;
        }
      }
      expect(differing, 0, reason: 'at ${positions[i]} the held union drew another silhouette');
    }
  });

  testWidgets('leaving the region, or the region moving, is a retake', (WidgetTester tester) async {
    final Uint8List bare = await _bare(tester);
    final x = ValueNotifier<double>(0);
    final top = ValueNotifier<double>(kRegion.top);
    addTearDown(x.dispose);
    addTearDown(top.dispose);
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _Scene(x: x, travel: true, regionTop: top),
      hostKey: hostKey,
    );
    final dynamic host = hostKey.currentState! as dynamic;

    // Past the region's right edge: the capture input grows to include it.
    var before = host.recorded as int;
    x.value = kRegion.width - kKnob.width + 40;
    await tester.pump();
    await tester.pump();
    expect(host.recorded, greaterThan(before), reason: 'a surface outside its region was held');
    expect(await _differing(tester, bare), 0, reason: 'outside the region the glass is visible');

    // Back inside, then the whole region moves: the slot no longer holds it.
    x.value = 40;
    await tester.pump();
    await tester.pump();
    before = host.recorded as int;
    top.value = kRegion.top + 90;
    await tester.pump();
    await tester.pump();
    expect(host.recorded, greaterThan(before), reason: 'a region that moved was held');
    expect(
      await _differing(tester, bare),
      0,
      reason: 'after the region moved the glass is visible',
    );
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

class _Scene extends StatelessWidget {
  const _Scene({
    this.x,
    this.travel = false,
    this.regionTop,
    this.fused = false,
    this.union = false,
  });

  /// A second, still surface beside the knob, both in one [GlassGroup].
  final bool fused;

  /// The pair in a [GlassUnion] rather than a group of declared spacing.
  final bool union;

  /// The knob's left edge inside the region. Null draws no glass at all.
  final ValueNotifier<double>? x;
  final bool travel;
  final ValueNotifier<double>? regionTop;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<double> top = regionTop ?? ValueNotifier<double>(kRegion.top);
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
            ),
            if (x case final ValueNotifier<double> left)
              ValueListenableBuilder<double>(
                valueListenable: top,
                builder: (BuildContext context, double t, Widget? _) => Positioned(
                  left: kRegion.left,
                  top: t,
                  width: kRegion.width,
                  height: kRegion.height,
                  child: _maybeTravel(
                    Stack(
                      // No clip, and it is load-bearing: a knob overflowing a
                      // clipping stack pushes a clip layer, and the layer watch
                      // retakes on that — so "leaving the region is a retake"
                      // passed with the region's own growth deleted.
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        if (fused)
                          const Positioned(
                            left: 0,
                            top: 20,
                            width: 100,
                            height: 80,
                            child: GlassSurface(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                          ),
                        _knob(left),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The moving surface. In the fused scene it sits behind a boundary of its
  /// own, so a move repaints that boundary and not the group — which is how a
  /// component isolates what it animates, and the only arrangement in which
  /// the group's draw has to follow a member it was not asked to repaint for.
  Widget _knob(ValueNotifier<double> left) {
    final Widget knob = ValueListenableBuilder<double>(
      valueListenable: left,
      builder: (BuildContext context, double l, Widget? _) => Positioned(
        left: l,
        top: 20,
        width: kKnob.width,
        height: kKnob.height,
        child: const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
    );
    if (!fused) {
      return knob;
    }
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(clipBehavior: Clip.none, children: <Widget>[knob]),
      ),
    );
  }

  Widget _maybeTravel(Widget child) {
    final Widget grouped = !fused
        ? child
        : union
        ? GlassUnion(child: child)
        : GlassGroup(spacing: 16, child: child);
    return travel ? GlassTravel(child: grouped) : grouped;
  }
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 13) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 6),
        Paint()..color = Color.fromARGB(255, 30 + (y.toInt() % 210), 120, 210 - (y.toInt() % 160)),
      );
    }
    for (var x = 0.0; x < size.width; x += 29) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 7, size.height),
        Paint()..color = const Color(0x55FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

/// The identity with a tint, so that where the glass is shows even where what
/// it shows is right.
const GlassFinish _tinted = GlassFinish(
  name: 'identity',
  blurSigmaLogical: 0,
  tint: Color.fromRGBO(255, 40, 0, 0.5),
  rim: Color.fromRGBO(0, 0, 0, 0),
  optics: GlassOptics.none,
);

Widget _mount(Widget child, {Key? hostKey, GlassFinish finish = GlassFinish.identity}) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        finish: finish,
        child: child,
      ),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Key? hostKey,
  int frames = 4,
  GlassFinish finish = GlassFinish.identity,
}) async {
  await tester.pumpWidget(_mount(child, hostKey: hostKey, finish: finish));
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

ui.Image _frame() {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

Future<Uint8List> _pixels(WidgetTester tester, ui.Image image) async {
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return out;
}

Future<Uint8List> _bare(WidgetTester tester) async {
  await _pump(tester, const _Scene(), hostKey: GlobalKey());
  return _pixels(tester, _frame());
}

/// How many pixels of the current frame differ from [bare], and the leftmost
/// column any of them is in.
Future<({int count, double minX})> _where(WidgetTester tester, Uint8List bare) async {
  final Uint8List now = await _pixels(tester, _frame());
  expect(now.length, kScreen.width * kScreen.height * 4);
  var count = 0;
  var minX = double.infinity;
  for (var i = 0; i < now.length; i += 4) {
    if (now[i] != bare[i] || now[i + 1] != bare[i + 1] || now[i + 2] != bare[i + 2]) {
      count++;
      final double column = ((i ~/ 4) % kScreen.width.toInt()).toDouble();
      if (column < minX) {
        minX = column;
      }
    }
  }
  return (count: count, minX: minX);
}

/// Pixels of the current frame that differ from [bare], and asserts that a
/// whole frame was compared.
Future<int> _differing(WidgetTester tester, Uint8List bare) async {
  final Uint8List now = await _pixels(tester, _frame());
  expect(now.length, bare.length);
  expect(now.length, kScreen.width * kScreen.height * 4);
  var differing = 0;
  for (var i = 0; i < now.length; i += 4) {
    if (now[i] != bare[i] || now[i + 1] != bare[i + 1] || now[i + 2] != bare[i + 2]) {
      differing++;
    }
  }
  return differing;
}
