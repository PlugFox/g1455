// The thermal policy.
//
// `flutter test test/glass_thermal_test.dart`
//
// Thermals act on the retake and not on the ladder, because a frame of
// staleness has a measured price per finish and the ladder's rungs do not
// (`glass_tier.dart`). So the policy is an allowance in ΔE, and what it buys is
// read off `ProxyStaleness` rather than chosen:
//
//  1. **The table the documentation quotes is the arithmetic's.** Two
//     allowances, four finishes; `clear` gets nothing at either, which is the
//     sentence "throttling under a transparent finish is forbidden" as a number.
//     Nominal, fair, unknown and [GlassThermalPolicy.never] buy nothing, and
//     what the resolution spent comes off first, in quadrature.
//  2. **A throttle holds across a change of content and never across a change
//     of the surfaces.** Driven on the oracle directly: with two frames bought,
//     a screen that changes every frame is recorded every third, and a panel
//     that moves is recorded on the frame it moved.
//  3. **The host spends it.** A screen scrolling under a `regular` panel at
//     `serious` records a third of its frames and counts the rest as throttled;
//     the same screen under `clear` records every frame; nominal records every
//     frame under both.
//
// Breaks, each failing its own arm: the policy's `serious` allowance applied at
// `fair` (1); the geometry condition dropped from `RetakeOracle.decide` (2);
// the host no longer setting `throttleFrames` (3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_retake.dart';

// ignore_for_file: avoid_print

const Size kScreen = Size(360, 400);

void main() {
  // -------------------------------------------------------------------------
  // 1. The table.
  // -------------------------------------------------------------------------

  test('what each allowance buys, per finish', () {
    const policy = GlassThermalPolicy();
    const expected = <String, (int, int)>{
      'regularDark': (2, 4),
      // The light branch buys what the dark one does: its stale frames are
      // cheaper, but not by a whole rung at either allowance.
      'regularLight': (2, 4),
      'frosted': (1, 2),
      'thinLight': (0, 1),
      'clear': (0, 0),
    };
    for (final MapEntry<String, (int, int)> row in expected.entries) {
      final int serious = policy.throttleFrames(row.key, GlassThermalState.serious);
      final int critical = policy.throttleFrames(row.key, GlassThermalState.critical);
      print('${row.key}: serious $serious, critical $critical');
      expect((serious, critical), row.value, reason: row.key);
      for (final GlassThermalState? calm in <GlassThermalState?>[
        null,
        GlassThermalState.nominal,
        GlassThermalState.fair,
      ]) {
        expect(policy.throttleFrames(row.key, calm), 0, reason: '${row.key} at $calm');
      }
      expect(GlassThermalPolicy.never.throttleFrames(row.key, GlassThermalState.critical), 0);
    }
    expect(policy.seriousDeltaE, closeTo(0.696, 0.0005));
    expect(policy.criticalDeltaE, closeTo(1.392, 0.0005));
    // A finish nobody graded buys nothing, whatever the device says.
    expect(policy.throttleFrames('identity', GlassThermalState.critical), 0);
    // What the resolution spent comes off first: 0.5 of 0.696 leaves 0.484,
    // which is one frame of `regular` and not two.
    expect(
      policy.throttleFrames('regularDark', GlassThermalState.serious, spentDeltaE: 0.5),
      1,
    );
  });

  // -------------------------------------------------------------------------
  // 2. Content, never geometry.
  // -------------------------------------------------------------------------

  test('a throttle holds across a change of content and never across a move', () {
    const panel = <Rect>[Rect.fromLTWH(20, 40, 200, 60)];
    final oracle = RetakeOracle(finish: 'regularDark')..throttleFrames = 2;
    addTearDown(oracle.dispose);

    RetakeReason step(List<Rect> surfaces, {bool contentChanged = true}) {
      if (contentChanged) {
        oracle.noteChange();
      }
      oracle.noteSurfaces(surfaces);
      final RetakeReason reason = oracle.decide();
      if (reason.holds) {
        oracle.noteFrame();
      } else {
        oracle.noteCapture(surfaces);
      }
      return reason;
    }

    // The first frame is never throttled: there is nothing to hold.
    expect(step(panel), RetakeReason.first);
    final List<RetakeReason> scrolling = <RetakeReason>[for (var i = 0; i < 6; i++) step(panel)];
    expect(scrolling, <RetakeReason>[
      RetakeReason.throttled,
      RetakeReason.throttled,
      RetakeReason.changed,
      RetakeReason.throttled,
      RetakeReason.throttled,
      RetakeReason.changed,
    ]);
    // Mid-throttle, the panel moves: recorded on that frame.
    expect(step(panel), RetakeReason.throttled);
    expect(step(const <Rect>[Rect.fromLTWH(24, 40, 200, 60)]), RetakeReason.changed);
    // And one that appears.
    expect(step(const <Rect>[Rect.fromLTWH(24, 40, 200, 60)]), RetakeReason.throttled);
    expect(
      step(const <Rect>[Rect.fromLTWH(24, 40, 200, 60), Rect.fromLTWH(24, 140, 200, 60)]),
      RetakeReason.changed,
    );
    // Nothing changed at all: the throttle does not turn a hold into anything.
    oracle.throttleFrames = 0;
    expect(
      step(const <Rect>[Rect.fromLTWH(24, 40, 200, 60), Rect.fromLTWH(24, 140, 200, 60)], contentChanged: false),
      RetakeReason.declared,
    );
  });

  // -------------------------------------------------------------------------
  // 3. The host.
  // -------------------------------------------------------------------------

  testWidgets('the host spends the allowance on a scrolling screen, per finish', (
    WidgetTester tester,
  ) async {
    final results = <String, ({int recorded, int held, int throttled})>{};
    for (final GlassFinish finish in <GlassFinish>[GlassFinish.regularDark, GlassFinish.clear]) {
      for (final GlassThermalState state in <GlassThermalState>[
        GlassThermalState.nominal,
        GlassThermalState.serious,
      ]) {
        final key = GlobalKey();
        final scroll = ValueNotifier<double>(0);
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GlassHost(
                key: key,
                hardware: GlassHardware.appleMetal,
                resolution: const ProxyResolution.full(),
                finish: finish,
                thermal: state,
                child: SizedBox.fromSize(
                  size: kScreen,
                  child: Stack(
                    children: <Widget>[
                      // A screen that changes under a still panel, every frame.
                      Positioned.fill(
                        child: ValueListenableBuilder<double>(
                          valueListenable: scroll,
                          builder: (BuildContext context, double y, Widget? _) => CustomPaint(painter: _Stripes(y)),
                        ),
                      ),
                      const Positioned(
                        left: 80,
                        top: 40,
                        width: 200,
                        height: 60,
                        child: GlassSurface(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final dynamic host = key.currentState! as dynamic;
        final int recorded0 = host.recorded as int;
        final int held0 = host.held as int;
        const frames = 30;
        for (var i = 0; i < frames; i++) {
          scroll.value += 3;
          await tester.pump();
        }
        results['${finish.name}/${state.name}'] = (
          recorded: (host.recorded as int) - recorded0,
          held: (host.held as int) - held0,
          throttled: host.throttled as int,
        );
      }
    }
    results.forEach((String k, ({int recorded, int held, int throttled}) v) => print('$k: $v'));
    // Nominal: every changed frame is recorded, under both finishes.
    expect(results['regularDark/nominal']!.throttled, 0);
    expect(results['clear/nominal']!.throttled, 0);
    expect(results['regularDark/nominal']!.recorded, greaterThanOrEqualTo(29));
    // Serious under regular: two frames bought, so one frame in three.
    expect(results['regularDark/serious']!.throttled, greaterThanOrEqualTo(18));
    expect(results['regularDark/serious']!.recorded, inInclusiveRange(9, 11));
    // Serious under clear: nothing bought, nothing held.
    expect(results['clear/serious']!.throttled, 0);
    expect(results['clear/serious']!.recorded, greaterThanOrEqualTo(29));
  });
}

/// Horizontal stripes moving with [y]: every frame paints a different picture
/// under the panel, which is the latency rungs' own shape of scene.
class _Stripes extends CustomPainter {
  const _Stripes(this.y);

  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF202030));
    final stripe = Paint()..color = const Color(0xFFE0C040);
    for (double top = -(y % 40); top < size.height; top += 40) {
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, 16), stripe);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => oldDelegate.y != y;
}
