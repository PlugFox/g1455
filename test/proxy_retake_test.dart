// When the proxy is re-recorded, and what a frame of staleness actually costs.
//
// `flutter test test/proxy_retake_test.dart`
//
// The natural shape for this piece is "re-take on a dirty rect, with a
// threshold and a frequency ceiling assigned by the finish rather than by
// taste". The ceiling is measured here, from the ladder's own latency rungs,
// and the answer is not the one that shape assumes: **at the budget that picks a
// quarter-resolution proxy, no finish may be stale at all.** A frame behind
// costs more than a quarter of the resolution does, on every finish.
//
// Two things follow and both are checked below. The lever is "retake when
// something changed", not "retake every N frames" — so what the oracle can
// *see* matters more than what it may hold. And the two axes draw on one
// budget, which needed a rule: damage does not add.
//
// The composition rule is the other half of this file, and it needed a rung
// built for it. The ladder's `mix` combines three parts of which one is four to
// seven times the others, so every model predicts about the same number there;
// `res8lag2` puts resolution and staleness within a factor of two, which is
// what lets the models separate.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart';
import 'package:g1455/src/proxy/proxy_retake.dart';

const Size kScreen = Size(400, 800);
final GlobalKey _rootKey = GlobalKey();

/// Arms of a ladder report, keyed by (scene, finish, step).
Map<(String, String, String), double> _armsOf(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('the report a constant came from is gone: $path');
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return <(String, String, String), double>{
    for (final Object? a in report['arms']! as List<Object?>)
      if ((a! as Map<String, Object?>)['delta_e_mean'] != null)
        (
          (a as Map<String, Object?>)['scene']! as String,
          packageName(a['finish']! as String),
          a['step']! as String,
        ): a['delta_e_mean']! as double,
  };
}

String _composeReport() {
  final List<FileSystemEntity> found =
      Directory('provenance/quality')
          .listSync()
          .where((FileSystemEntity e) => e.path.contains(ProxyStaleness.compositionSource))
          .toList()
        ..sort((FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));
  if (found.isEmpty) {
    throw StateError('the composition run is gone: ${ProxyStaleness.compositionSource}*');
  }
  return found.last.path;
}

double _mean(Iterable<double> xs) {
  final List<double> list = xs.toList();
  return list.reduce((double a, double b) => a + b) / list.length;
}

double _median(List<double> xs) {
  final List<double> s = List<double>.of(xs)..sort();
  final int n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// The package's name for a finish the ladder graded: the ladder has called
/// the dark branch of `.regular` `regular`, and every report keeps the name it
/// was taken under.
String packageName(String ladder) => ladder == 'regular' ? 'regularDark' : ladder;

/// The finishes every ladder run before the light branch's graded, by the package's names:
/// the cross-run claims below are claims about these four. The light branch
/// has a run of its own, and its own arm.
const List<String> kRecordedFinishes = <String>['clear', 'thinLight', 'frosted', 'regularDark'];

void main() {
  // -------------------------------------------------------------------------
  // 1. What staleness costs, from the ladder it was measured on.
  // -------------------------------------------------------------------------

  test('the light branch\'s staleness row is what its own run says', () {
    // The light branch's run, whose `regular` lag arms are the control: they reproduce
    // the table's `regularDark` row, which is what licenses a row from another
    // afternoon in the same table.
    final arms = _armsOf(ProxyResolution.lightDamageSource);
    final Set<String> scenes = <String>{for (final (String s, _, _) in arms.keys) s};
    expect(scenes, hasLength(7));
    for (final String finish in const <String>['regularDark', 'regularLight']) {
      for (final (int frames, String step) in const <(int, String)>[(1, 'lag1'), (2, 'lag2'), (4, 'lag4')]) {
        final double measured = _mean(scenes.map((String scene) => arms[(scene, finish, step)]!));
        expect(ProxyStaleness.damageAt(finish, frames)!, closeTo(measured, 0.001), reason: '$finish at $frames');
      }
    }
  });

  test('the staleness table is what the ladder on disk says', () {
    final arms = _armsOf(ProxyStaleness.source);
    final Set<String> scenes = <String>{for (final (String s, _, _) in arms.keys) s};
    expect(scenes, hasLength(7));
    for (final String finish in kRecordedFinishes) {
      for (final (int frames, String step) in const <(int, String)>[
        (1, 'lag1'),
        (2, 'lag2'),
        (4, 'lag4'),
      ]) {
        final double measured = _mean(
          scenes.map((String scene) => arms[(scene, finish, step)]!),
        );
        expect(
          ProxyStaleness.damageAt(finish, frames)!,
          closeTo(measured, 0.001),
          reason: '$finish at $frames frames behind',
        );
      }
    }
  });

  test('one frame behind costs at least what a quarter of the resolution does', () {
    // The comparison that turns the ceiling from a schedule into a finding.
    // Both numbers are damage against the same finish at full quality, from the
    // same run, so they are directly comparable — which is exactly the thing a
    // ladder number usually is not.
    //
    // The claim is "at least", and the qualifier is the result: staleness is
    // 1.17x a quarter on `clear`, 1.77x on `thinLight`, **0.98x on `frosted`**
    // and 1.73x on `regular`. So on the finish with the heaviest blur the two
    // axes cost the same, and everywhere else the frame is dearer. A blur is a
    // low-pass in space and staleness is not — what it hides is lost detail,
    // not a picture from a moment ago.
    for (final String finish in ProxyStaleness.measuredFinishes) {
      final double stale = ProxyStaleness.damageAt(finish, 1)!;
      final double quarter = const ProxyResolution.quarter().meanDamage(finish)!;
      expect(
        stale / quarter,
        greaterThan(0.97),
        reason: '$finish: one frame behind ($stale) is cheaper than a quarter ($quarter)',
      );
    }
    expect(
      ProxyStaleness.damageAt('regularDark', 1)! / const ProxyResolution.quarter().meanDamage('regularDark')!,
      closeTo(1.73, 0.02),
    );
    // And the consequence: at the default budget the ceiling is zero for every
    // finish but one. Not a degenerate case — the finding. The light branch
    // of `.regular` is the exception: its first stale frame is 0.284,
    // 82% of the budget.
    for (final String finish in ProxyStaleness.measuredFinishes) {
      expect(
        ProxyStaleness.maxStaleFrames(finish, ProxyResolutionPolicy.defaultDamageBudgetDeltaE),
        finish == 'regularLight' ? 1 : 0,
        reason: '$finish: the ceiling inside a 1% budget',
      );
    }
    // A caller who spends more gets something, which is what makes the zero
    // above a measurement of the budget rather than of the table.
    expect(ProxyStaleness.maxStaleFrames('regularDark', 0.8), 2);
    expect(ProxyStaleness.maxStaleFrames('regularDark', 1.2), 4);
    expect(ProxyStaleness.maxStaleFrames('frosted', 1.5), 4);
    expect(ProxyStaleness.maxStaleFrames('clear', 1.5), 1);
    // And an unmeasured point refuses rather than interpolating.
    expect(ProxyStaleness.damageAt('regularDark', 3), isNull);
    expect(ProxyStaleness.damageAt('nosuchfinish', 1), isNull);
  });

  // -------------------------------------------------------------------------
  // 2. How two degradations add up.
  // -------------------------------------------------------------------------

  test('damage does not add, and the rung that says so had to be built for it', () {
    final ladder = _armsOf(ProxyStaleness.source);
    final compose = _armsOf(_composeReport());
    final Set<String> scenes = <String>{for (final (String s, _, _) in ladder.keys) s};

    final errors = <String, List<double>>{'sum': <double>[], 'max': <double>[], 'quad': <double>[]};
    var comparable = 0;
    for (final String finish in kRecordedFinishes) {
      for (final String scene in scenes) {
        for (final (List<double> parts, double measured) in <(List<double>, double)>[
          (
            <double>[
              ladder[(scene, finish, 'res2')]!,
              ladder[(scene, finish, 'blocktext')]!,
              ladder[(scene, finish, 'lag1')]!,
            ],
            ladder[(scene, finish, 'mix')]!,
          ),
          (
            <double>[
              compose[(scene, finish, 'res8')]!,
              compose[(scene, finish, 'lag2')]!,
            ],
            compose[(scene, finish, 'res8lag2')]!,
          ),
        ]) {
          errors['sum']!.add((parts.reduce((double a, double b) => a + b) - measured) / measured);
          errors['max']!.add((parts.reduce(math.max) - measured) / measured);
          errors['quad']!.add((GlassDamage.compose(parts) - measured) / measured);
        }
        // How comparable the parts of the new rung are — the property that lets
        // the models be told apart at all.
        final double a = compose[(scene, finish, 'res8')]!;
        final double b = compose[(scene, finish, 'lag2')]!;
        if (math.max(a, b) / math.min(a, b) < 2.5) {
          comparable++;
        }
      }
    }
    expect(errors['sum'], hasLength(56));
    expect(
      comparable,
      greaterThanOrEqualTo(20),
      reason: 'the new rung is as lopsided as `mix`, so it separates nothing either',
    );

    double medianAbs(String key) => _median(errors[key]!.map((double e) => e.abs()).toList());
    // The sum is refuted, and by a margin nothing could mistake for noise.
    expect(medianAbs('sum'), greaterThan(0.30));
    // The two that survive bracket the truth: the largest part under, the
    // quadrature over.
    expect(_median(errors['max']!), lessThan(0));
    expect(_median(errors['quad']!), greaterThan(0));
    expect(medianAbs('max'), lessThan(0.06));
    expect(medianAbs('quad'), lessThan(0.09));
    // And the package's rule is the conservative one of the pair — a budget
    // that over-estimates damage spends too little, which is the failure that
    // shows up as a picture nobody complains about.
    expect(GlassDamage.compose(<double>[3, 4]), 5);
  });

  test('the budget is one allowance, and the axes draw on it together', () {
    // The consequence of the rule for the API: a proxy already recorded at a
    // quarter has spent part of what the staleness would draw on, so the
    // remaining allowance is smaller than the budget and not equal to it.
    const double budget = ProxyResolutionPolicy.defaultDamageBudgetDeltaE;
    final double spent = const ProxyResolution.quarter().meanDamage('regularDark')!;
    final double left = GlassDamage.remaining(budget, spent);
    expect(left, lessThan(budget));
    expect(GlassDamage.compose(<double>[spent, left]), closeTo(budget, 1e-9));
    // Spending everything leaves nothing, and over-spending does not go
    // negative under a square root.
    expect(GlassDamage.remaining(budget, budget), 0);
    expect(GlassDamage.remaining(budget, budget * 2), 0);
  });

  // -------------------------------------------------------------------------
  // 3. The oracle, on a tree.
  // -------------------------------------------------------------------------

  testWidgets('the oracle holds a still screen and re-records a moved one', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _panel(offset));

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);
    // A budget loose enough to allow holding at all, so that "held" and "the
    // ceiling arrived" are different events in this arm. 0.8 ΔE is 2.3% of the
    // distance between two of Apple's materials — more than this package would
    // spend, and named here rather than hidden behind a default.
    //
    // `undeclared` is named for the same reason, and every oracle in this file
    // that studies the ceiling names it: the default holds outright
    // and never consults the table, so the branch this file is about is only
    // reachable on the other side of that switch.
    final oracle = RetakeOracle(
      finish: 'regularDark',
      budgetDeltaE: 0.8,
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(oracle.dispose);
    expect(oracle.ceiling, 2);

    final first = _run(pipeline, ledger, oracle);
    expect(first.reason, RetakeReason.first);
    expect(first.frame, isNotNull);

    // Nothing moved: held, and the held frame is the same object rather than a
    // new one that happens to look alike.
    final second = _run(pipeline, ledger, oracle);
    expect(second.reason, RetakeReason.hold);
    expect(identical(second.frame, first.frame), isTrue);

    // The panel moves: re-recorded, and the map follows it.
    offset.value = const Offset(200, 300);
    await tester.pump();
    final moved = _run(pipeline, ledger, oracle);
    expect(moved.reason, RetakeReason.changed);
    expect(identical(moved.frame, first.frame), isFalse);
    expect(moved.frame!.slotFor(0).source.left, lessThan(200));
    expect(moved.frame!.slotFor(0).source.left, greaterThan(150));
  });

  testWidgets('the ceiling fires on a screen where nothing changes at all', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _panel(offset));
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);
    final oracle = RetakeOracle(
      finish: 'regularDark',
      budgetDeltaE: 0.8,
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(oracle.dispose);

    _run(pipeline, ledger, oracle);
    final List<RetakeReason> reasons = <RetakeReason>[
      for (var i = 0; i < 5; i++) _run(pipeline, ledger, oracle).reason,
    ];
    // Held for the ceiling, then re-recorded, then held again: a backstop, not
    // a schedule. With a ceiling of two that is hold, hold, ceiling, hold, hold.
    expect(reasons, <RetakeReason>[
      RetakeReason.hold,
      RetakeReason.hold,
      RetakeReason.ceiling,
      RetakeReason.hold,
      RetakeReason.hold,
    ]);
  });

  testWidgets('at the default budget nothing is ever held', (WidgetTester tester) async {
    // The finding, as behaviour rather than as a table: the package's own
    // budget re-records every frame, whatever the oracle can see.
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _panel(offset));
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);
    final oracle = RetakeOracle(
      finish: 'regularDark',
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(oracle.dispose);
    expect(oracle.ceiling, 0);
    _run(pipeline, ledger, oracle);
    for (var i = 0; i < 3; i++) {
      expect(_run(pipeline, ledger, oracle).reason, RetakeReason.ceiling);
    }
  });

  testWidgets('a marker that changes is a change the oracle can see', (
    WidgetTester tester,
  ) async {
    // `proxyChanges` is a `Listenable` rather than a comment so that something
    // can listen to it. This is the listener.
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    final role = ValueNotifier<GlassProxyRole>(GlassProxyRole.verbatim);
    addTearDown(offset.dispose);
    addTearDown(role.dispose);
    await _mount(tester, ledger, _panelWithMarker(offset, role));

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);
    final oracle = RetakeOracle(
      finish: 'regularDark',
      budgetDeltaE: 0.8,
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(oracle.dispose);
    oracle.watch(_root());
    expect(oracle.watchedMarkers, 1, reason: 'the oracle found no marker to watch');

    _run(pipeline, ledger, oracle);
    expect(_run(pipeline, ledger, oracle).reason, RetakeReason.hold);

    // The marker's role changes without anything moving.
    role.value = GlassProxyRole.hidden;
    await tester.pump();
    expect(oracle.dirty, isTrue, reason: 'the marker fired and the oracle did not hear it');
    expect(_run(pipeline, ledger, oracle).reason, RetakeReason.changed);

    // And the control: after unwatching, the same change is invisible.
    oracle.unwatch();
    expect(oracle.watchedMarkers, 0);
    _run(pipeline, ledger, oracle);
    role.value = GlassProxyRole.verbatim;
    await tester.pump();
    expect(
      _run(pipeline, ledger, oracle).reason,
      RetakeReason.hold,
      reason: 'the oracle heard a marker it is not watching',
    );
  });

  testWidgets('content that changes without moving has to say so', (WidgetTester tester) async {
    // The escape hatch, and the reason it exists: no Dart API reports that a
    // subtree repainted, so a chart animating in place is invisible to
    // everything above. Fifth on the same list as occlusion, reduced
    // transparency, the roles and the hardware.
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _panel(offset));
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);
    final oracle = RetakeOracle(
      finish: 'regularDark',
      budgetDeltaE: 0.8,
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(oracle.dispose);

    _run(pipeline, ledger, oracle);
    expect(_run(pipeline, ledger, oracle).reason, RetakeReason.hold);
    oracle.noteChange();
    expect(_run(pipeline, ledger, oracle).reason, RetakeReason.changed);
  });

  testWidgets('the declaration is what makes the hold branch reachable at all', (
    WidgetTester tester,
  ) async {
    // The ceiling is zero on every measured finish at the default budget,
    // so `hold` is unreachable and the proxy is re-recorded on every frame of
    // every application — a still screen included. The arm above says that on
    // its own; this one runs the silent oracle **beside** the declaring one, on
    // one scene through one pipeline over the same frames, because the claim is
    // a difference between them and a difference measured across two arms is a
    // difference between two arms.
    final ledger = GlassLedger();
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _panel(offset));
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    addTearDown(pipeline.dispose);

    final silent = RetakeOracle(
      finish: 'regularDark',
      content: GlassContentDeclaration.undeclared,
    );
    addTearDown(silent.dispose);
    expect(silent.ceiling, 0, reason: 'the default budget bought a frame of staleness');
    _run(pipeline, ledger, silent);
    // Five frames on a screen where literally nothing happens.
    expect(
      <RetakeReason>[for (var i = 0; i < 5; i++) _run(pipeline, ledger, silent).reason],
      List<RetakeReason>.filled(5, RetakeReason.ceiling),
    );

    final declared = RetakeOracle(
      finish: 'regularDark',
      content: GlassContentDeclaration.declared,
    );
    addTearDown(declared.dispose);
    expect(declared.ceiling, 0, reason: 'the declaration must not move the measured table');
    final first = _run(pipeline, ledger, declared);
    expect(first.reason, RetakeReason.first);
    final List<({GlassProxyFrame? frame, RetakeReason reason})> held =
        <({GlassProxyFrame? frame, RetakeReason reason})>[for (var i = 0; i < 5; i++) _run(pipeline, ledger, declared)];
    expect(
      held.map((({GlassProxyFrame? frame, RetakeReason reason}) r) => r.reason),
      List<RetakeReason>.filled(5, RetakeReason.declared),
      reason: 'the ceiling was consulted and it is zero',
    );
    // The same object, not one that looks alike: a held frame is the frame that
    // was recorded, and five frames later it is still that one.
    expect(held.every((({GlassProxyFrame? frame, RetakeReason reason}) r) => identical(r.frame, first.frame)), isTrue);

    // Two controls in the same arm, because a declaration that holds through a
    // real change is worse than one that never holds. The surface moves:
    offset.value = const Offset(200, 300);
    await tester.pump();
    expect(_run(pipeline, ledger, declared).reason, RetakeReason.changed);
    expect(_run(pipeline, ledger, declared).reason, RetakeReason.declared);
    // And the application declares something the pass cannot see:
    declared.noteChange();
    expect(_run(pipeline, ledger, declared).reason, RetakeReason.changed);
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

({GlassProxyFrame? frame, RetakeReason reason}) _run(
  GlassProxyPipeline pipeline,
  GlassLedger ledger,
  RetakeOracle oracle,
) => pipeline.captureIfNeeded(
  _root(),
  ledger.surfaces.map((GlassSurfaceRecord r) => r.rect).toList(),
  devicePixelRatio: 2,
  oracle: oracle,
);

Widget _panel(ValueListenable<Offset> offset) => Stack(
  children: <Widget>[
    Positioned.fill(child: ColoredBox(color: const Color(0xFF204060))),
    ValueListenableBuilder<Offset>(
      valueListenable: offset,
      builder: (BuildContext context, Offset o, Widget? child) => Positioned(
        left: o.dx,
        top: o.dy,
        width: 160,
        height: 90,
        child: const GlassSurface(),
      ),
    ),
  ],
);

Widget _panelWithMarker(
  ValueListenable<Offset> offset,
  ValueListenable<GlassProxyRole> role,
) => Stack(
  children: <Widget>[
    Positioned.fill(child: ColoredBox(color: const Color(0xFF204060))),
    Positioned(
      left: 0,
      top: 400,
      width: 400,
      height: 200,
      child: ValueListenableBuilder<GlassProxyRole>(
        valueListenable: role,
        builder: (BuildContext context, GlassProxyRole r, Widget? child) => switch (r) {
          GlassProxyRole.hidden => GlassProxy.hidden(child: child!),
          GlassProxyRole.opaque => GlassProxy.opaque(child: child!),
          GlassProxyRole.verbatim => GlassProxy.verbatim(child: child!),
          GlassProxyRole.replace => GlassProxy.replace(
            painter: const SolidProxyPainter(Color(0xFF000000)),
            child: child!,
          ),
        },
        child: const ColoredBox(color: Color(0xFFCC4400)),
      ),
    ),
    ValueListenableBuilder<Offset>(
      valueListenable: offset,
      builder: (BuildContext context, Offset o, Widget? child) => Positioned(
        left: o.dx,
        top: o.dy,
        width: 160,
        height: 90,
        child: const GlassSurface(),
      ),
    ),
  ],
);

Future<void> _mount(WidgetTester tester, GlassLedger ledger, Widget child) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassScope(
          ledger: ledger,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _rootKey,
              child: SizedBox.fromSize(size: kScreen, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RenderRepaintBoundary _root() => _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
