// `GlassHost.precache`: the programs compiled before the first frame.
//
// `flutter test test/glass_precache_test.dart`
//
// The caches are per process, and so per test file, so **the order of the
// arms below is the experiment**: the first runs with nothing loaded — the
// truth an application that does not precache ships — and each later one
// precaches a little more.
//
// What is read is what a host hands its surfaces *during its first build*,
// by a probe built under it. Not the handle after the first pump: in a widget
// test the asset arrives inside that pump, so after it a host that precached
// and one that did not look the same, and the arm would control nothing. A
// surface's first frame has no proxy in every arm, because a capture reads the
// frame just painted; what precaching buys is the frame after it.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

void main() {
  testWidgets('without it, a host builds without a program and shares the load', (WidgetTester tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_Scene(probe: probe));
    expect(probe.first, isNotNull);
    expect(probe.first!.program, isFalse, reason: 'the program was there on the first build without a precache');
    expect(probe.first!.group, isFalse);
    expect(probe.first!.ripple, isFalse);

    // Asked for while the host's own load is in flight: it waits for that one.
    final GlassProxyHandle handle = _handle(tester);
    await _settle(tester, GlassHost.precache(ripple: false));
    expect(handle.program, isNotNull);
    expect(handle.groupProgram, isNotNull);

    // A second host gets the very programs the first one loaded.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_Scene(probe: _Probe()));
    final GlassProxyHandle second = _handle(tester);
    expect(identical(second, handle), isFalse, reason: 'the host was not remounted');
    expect(identical(second.program, handle.program), isTrue, reason: 'the program was compiled twice');
    expect(identical(second.groupProgram, handle.groupProgram), isTrue, reason: 'the group program was compiled twice');
  });

  testWidgets('after it, a host has the programs it was asked for on its first build', (WidgetTester tester) async {
    await _settle(tester, GlassHost.precache(ripple: false));
    final probe = _Probe();
    await tester.pumpWidget(_Scene(probe: probe));
    expect(probe.first!.program, isTrue, reason: 'the program was not handed over before the first frame');
    expect(probe.first!.group, isTrue, reason: 'the group program was not handed over before the first frame');
    // Left out, and nothing in the scene asked for it.
    expect(probe.first!.ripple, isFalse, reason: '`ripple: false` loaded the ripple program anyway');
  });

  testWidgets('after it, the first frame with a proxy is drawn through the optics', (WidgetTester tester) async {
    await _settle(tester, GlassHost.precache());
    // Idempotent: the same loads, already complete.
    await _settle(tester, GlassHost.precache());

    final probe = _Probe();
    await tester.pumpWidget(_Scene(probe: probe));
    expect(probe.first!.program, isTrue);
    expect(probe.first!.group, isTrue);
    expect(probe.first!.ripple, isTrue, reason: 'the ripple program was not precached');

    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface));
    expect(surface.paintsWithoutProxy, 1, reason: 'the first frame is structurally without a proxy');
    expect(surface.paintsWithProxy, 0);

    // The capture of frame 1 is published, and frame 2 draws it.
    await tester.pump();
    expect(surface.paintsWithProxy, greaterThan(0), reason: 'no proxy was published after the first frame');
    expect(
      surface.paintsWithOptics,
      surface.paintsWithProxy,
      reason: 'a frame with a proxy was drawn without the optics',
    );
  });
}

/// Waits for [future] the way a widget test has to: the engine's half of a
/// load needs real time, which only `runAsync` gives, and a future chained in
/// the test's fake zone completes only when a pump flushes it. So both, in
/// turn — `runAsync(() => future)` alone deadlocks on the second.
Future<void> _settle(WidgetTester tester, Future<void> future) async {
  var done = false;
  future.then((_) => done = true);
  for (var i = 0; i < 200 && !done; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
  }
  expect(done, isTrue, reason: 'the precache never completed');
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

/// Which programs a host had handed over when something under it first built.
typedef _Programs = ({bool program, bool group, bool ripple});

class _Probe {
  _Programs? first;
}

class _ProbeView extends StatelessWidget {
  const _ProbeView(this.probe);

  final _Probe probe;

  @override
  Widget build(BuildContext context) {
    final GlassProxyHandle handle = GlassProxyScope.maybeOf(context)!;
    probe.first ??= (
      program: handle.program != null,
      group: handle.groupProgram != null,
      ripple: handle.rippleProgram != null,
    );
    return const SizedBox.shrink();
  }
}

/// A host over a coloured field, with one surface on it and the probe.
class _Scene extends StatelessWidget {
  const _Scene({required this.probe});

  final _Probe probe;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: GlassHost(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: Color(0xFF3366CC))),
          const Positioned(left: 40, top: 40, width: 200, height: 80, child: GlassSurface()),
          _ProbeView(probe),
        ],
      ),
    ),
  );
}
