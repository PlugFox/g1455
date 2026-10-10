// The finish ladder: one mechanism, and who is allowed to pull it.
//
// `flutter test test/glass_tier_test.dart`
//
// The ladder is glass, a cheap finish, an opaque fill. Why it has the rungs it
// has is argued at the top of `lib/src/surface/glass_tier.dart`; what is left
// for this file is a declaration and one structural claim:
//
//   **Below the top rung the backdrop is not read at all.** Not "cheaply", not
//   "less often" — not at all, because the rung's whole reason to exist is
//   Skia, where a `BackdropFilter` grows with the number of surfaces (0.37 M
//   cycles at 6 against 1.26 M at 36, on Adreno).
//
// That claim is easy to break silently: a screen where every surface is cheap
// draws a plausible picture whether or not the capture underneath it went
// quiet, and a screenshot cannot tell those apart. So the arms here are
// counters — captures taken, proxies published, which paint path ran — and
// every one of them is checked against a twin at the full rung that must move
// when this one does not.
//
// The ordering arms are the other half. "Pinned beats accessibility" is a
// decision with a consequence (a host that pins `full` has overridden the
// user's switch), and a policy whose order is wrong fails no picture anywhere.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 600);
final GlobalKey _shotKey = GlobalKey();

void main() {
  test('what the lower rungs cost on Adreno is what the tracked digests say', () {
    // The numbers in `GlassTierPolicy.ceiling`'s dartdoc. The share
    // of the full rung's addition the cheap rung keeps is read per scene and
    // per seed. Seed b's cheap cells carry repeats refused on a paint counter
    // (a scenario following itself was not remounted) — the frame drew them at
    // their other repeats' price to 0.23% — and its `over_text` cell a 44%
    // outlier that the median steps over; seed a has neither and agrees.
    Map<String, Object?> cell(Map<String, Object?> digest, String scene, String variant) {
      for (final Object? c in digest['cells']! as List<Object?>) {
        final m = c! as Map<String, Object?>;
        if (m['scene'] == scene && m['variant'] == variant) {
          return m;
        }
      }
      fail('$scene/$variant is not in the digest');
    }

    double cycles(Map<String, Object?> d, String scene, String variant) =>
        (cell(d, scene, variant)['gpu_cycles_per_frame']! as num).toDouble();

    for (final String label in <String>['s938-tier-a', 's938-tier-b']) {
      final d = json.decode(File('provenance/digest/$label.json').readAsStringSync()) as Map<String, Object?>;
      for (final (String scene, double keptLow, double keptHigh) in <(String, double, double)>[
        ('scroll_under_bar', 0.15, 0.24),
        ('over_text', 0.14, 0.16),
        ('over_photo', 0.20, 0.24),
        ('bank_home', 0.40, 0.42),
        ('many_cluster', 0.685, 0.715),
      ]) {
        final double floor = cycles(d, scene, 'plain');
        final double full = cycles(d, scene, 'glass');
        final double cheap = cycles(d, scene, 'glass_cheap');
        final double opaque = cycles(d, scene, 'glass_opaque');
        final counters = cell(d, scene, 'glass_cheap')['counters']! as Map<String, Object?>;
        expect(counters['glass_proxy_generations'], 0, reason: '$label $scene: cheap captured');
        expect(
          (cheap - floor) / (full - floor),
          inInclusiveRange(keptLow, keptHigh),
          reason: '$label $scene: share of the full addition the cheap rung keeps',
        );
        expect(opaque / cheap, inInclusiveRange(1.005, 1.03), reason: '$label $scene: opaque/cheap');
      }
    }
  });

  test('what the lower rungs cost on the iPad is what the tracked digests say', () {
    // The Metal half of `GlassTierPolicy.ceiling`'s dartdoc: GPU time off
    // the engine's tracer, two seeds. The two scenes are Adreno's two ends —
    // the cheap rung kept 15-24% of the full addition on two large surfaces and
    // 69-71% on twelve small ones there — and here both keep under a tenth,
    // because on this GPU the full rung's price is the capture and the
    // rung below takes none. Opaque against cheap is held as *indistinguishable*
    // rather than signed: it moved -4.1…+1.8% of the frame across scenes and
    // seeds, where Adreno's was positive ten times of ten.
    Map<String, Object?> cell(Map<String, Object?> digest, String scene, String variant) {
      for (final Object? c in digest['cells']! as List<Object?>) {
        final m = c! as Map<String, Object?>;
        if (m['scene'] == scene && m['variant'] == variant) {
          return m;
        }
      }
      fail('$scene/$variant is not in the digest');
    }

    double ms(Map<String, Object?> d, String scene, String variant) =>
        (cell(d, scene, variant)['frame_ms_per_frame']! as num).toDouble();

    for (final String label in <String>['ipad-tier-a', 'ipad-tier-b']) {
      final d = json.decode(File('provenance/digest/$label.json').readAsStringSync()) as Map<String, Object?>;
      for (final String scene in <String>['scroll_under_bar', 'many_cluster']) {
        final double floor = ms(d, scene, 'plain');
        final double material = ms(d, scene, 'material');
        final double full = ms(d, scene, 'glass');
        final double cheap = ms(d, scene, 'glass_cheap');
        final double opaque = ms(d, scene, 'glass_opaque');
        for (final String rung in <String>['glass_cheap', 'glass_opaque']) {
          final counters = cell(d, scene, rung)['counters']! as Map<String, Object?>;
          expect(counters['glass_proxy_generations'], 0, reason: '$label $scene: $rung captured');
        }
        expect(full / material, inInclusiveRange(1.75, 2.75), reason: '$label $scene: full rung');
        expect(cheap / material, inInclusiveRange(0.97, 1.09), reason: '$label $scene: cheap');
        expect(
          (cheap - floor) / (full - floor),
          inInclusiveRange(0.02, 0.08),
          reason: '$label $scene: share of the full addition the cheap rung keeps',
        );
        expect(opaque / cheap, inInclusiveRange(0.95, 1.02), reason: '$label $scene: opaque/cheap');
      }
    }
  });

  // -------------------------------------------------------------------------
  // 1. The policy: every input is a declaration, and the order between them is
  //    a decision.
  // -------------------------------------------------------------------------

  test('nothing declared is the top rung', () {
    const GlassTierChoice choice = GlassTierChoice.byDefault;
    expect(const GlassTierPolicy().choose(), choice);
    expect(choice.tier, GlassTier.full);
    expect(choice.reason, GlassTierReason.byDefault);
  });

  test('reduce transparency lands on opaque, not on cheap', () {
    // The rung matters and is not a detail of taste: the switch exists to
    // remove translucency, and a cheap rung is still translucent. It is also
    // what the platform it comes from does — a `UIVisualEffectView` under
    // Reduce Transparency fills rather than samples.
    final GlassTierChoice choice = const GlassTierPolicy(reduceTransparency: true).choose();
    expect(choice.tier, GlassTier.opaque);
    expect(choice.reason, GlassTierReason.reduceTransparency);
  });

  test('a device ceiling binds, and a ceiling of full is not a reason', () {
    expect(
      const GlassTierPolicy(ceiling: GlassTier.cheap).choose(),
      const GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
    );
    // A ceiling at the top rung changes nothing, so it must not claim to have
    // decided anything: a report that read `deviceCeiling` there would say a
    // device table had bound when the default had.
    expect(const GlassTierPolicy(ceiling: GlassTier.full).choose(), GlassTierChoice.byDefault);
  });

  test('a pin beats the accessibility switch, in both directions', () {
    // Downward: nothing surprising.
    expect(
      const GlassTierPolicy(pinned: GlassTier.opaque, reduceTransparency: false).choose().tier,
      GlassTier.opaque,
    );
    // Upward, and this is the arm that records the decision: the host has
    // overridden the user. It is deliberate — a package whose most expensive
    // path cannot be forced cannot be benchmarked on a device with the switch
    // on — and the reason says who did it.
    final GlassTierChoice forced = const GlassTierPolicy(
      pinned: GlassTier.full,
      reduceTransparency: true,
      ceiling: GlassTier.opaque,
    ).choose();
    expect(forced.tier, GlassTier.full);
    expect(forced.reason, GlassTierReason.pinnedByHost);
  });

  test('only the top rung reads a backdrop', () {
    expect(GlassTier.full.readsBackdrop, isTrue);
    expect(GlassTier.cheap.readsBackdrop, isFalse);
    expect(GlassTier.opaque.readsBackdrop, isFalse);
  });

  // -------------------------------------------------------------------------
  // 2. The structural claim: below the top rung nothing is captured.
  // -------------------------------------------------------------------------

  testWidgets('a cheap screen takes no capture, and the full twin takes several', (
    WidgetTester tester,
  ) async {
    final cheapKey = GlobalKey();
    await _pump(tester, tier: GlassTier.cheap, hostKey: cheapKey, frames: 6);
    final dynamic cheap = cheapKey.currentState! as dynamic;
    expect(
      cheap.recorded,
      0,
      reason: 'a rung that reads no backdrop recorded one: the capture is not gated by the tier',
    );
    // And not "held" either, which would be the oracle deciding rather than the
    // ladder: a held frame is a frame that *would* have been recorded.
    expect(cheap.held, 0);

    // The twin. Same tree, same host, one value different — without it this
    // arm passes on a host that captures nothing at all.
    final fullKey = GlobalKey();
    await _pump(tester, tier: GlassTier.full, hostKey: fullKey, frames: 6);
    expect(
      (fullKey.currentState! as dynamic).recorded,
      greaterThan(0),
      reason: 'the control captured nothing, so the arm above measured nothing',
    );
  });

  testWidgets('the cheap surface paints, and paints without a proxy path', (
    WidgetTester tester,
  ) async {
    await _pump(tester, tier: GlassTier.cheap, frames: 4);
    final RenderGlassSurface surface = _surface(tester);
    expect(surface.paintsCheap, greaterThan(0), reason: 'the cheap rung never drew');
    expect(surface.paintsOpaque, 0);
    // The three counters of the full path stay at zero — including
    // `paintsWithoutProxy`, which is the one that would quietly reclassify a
    // working cheap screen as a broken full one.
    expect(surface.paintsWithProxy, 0);
    expect(surface.paintsWithOptics, 0);
    expect(
      surface.paintsWithoutProxy,
      0,
      reason: 'a cheap surface counted itself as a full surface that missed its proxy',
    );

    await _pump(tester, tier: GlassTier.opaque, frames: 4);
    final RenderGlassSurface opaque = _surface(tester);
    expect(opaque.paintsOpaque, greaterThan(0));
    expect(opaque.paintsCheap, 0);
  });

  testWidgets('the register keeps the surface and the capture does not', (
    WidgetTester tester,
  ) async {
    // The two sets part company, and this is the arm that says so: the
    // translucency tax follows any translucent fill and the capture
    // follows the proxy. A ledger that dropped the cheap surface would report a
    // screen with no glass on it and a tax of zero.
    await _pump(tester, tier: GlassTier.cheap, frames: 4);
    final GlassLedger ledger = _ledger(tester);
    final GlassLoad load = ledger.read(
      viewSize: kScreen,
      model: GlassSurfaceCostModel.adrenoCycles,
    );
    expect(load.surfaceCount, 1);
    expect(load.capturedSurfaceCount, 0);
    expect(load.rectAreaLogical, greaterThan(0));
    expect(load.capturedRectAreaLogical, 0);
    expect(load.taxCycles, greaterThan(0), reason: 'the cheap rung stopped paying a tax it pays');
    expect(load.bounds, isNull, reason: 'a capture was described for a screen that takes none');
  });

  // -------------------------------------------------------------------------
  // 3. The picture. Two claims, and each has a twin that must differ.
  // -------------------------------------------------------------------------

  testWidgets('the cheap rung transmits exactly 1 - a of what is behind it', (
    WidgetTester tester,
  ) async {
    // No new constant is introduced by this rung: drawing a tint of alpha `a`
    // over the backdrop is `mix(backdrop, tint, a)`, which is the affine level
    // law fitted to Apple's own materials on four backdrops. So the level
    // is predictable in closed form from the finish alone, and that is what is
    // checked — against a value read off the pixels, not against itself.
    const GlassFinish finish = GlassFinish.regularDark;
    final ui.Image shot = await _shotOf(tester, tier: GlassTier.cheap, finish: finish);
    final int read = await _centrePixel(tester, shot);

    final double a = finish.tint.a;
    final int expected = ((1 - a) * _kBackdropLuma + a * (finish.tint.r * 255)).round();
    expect(
      read,
      closeTo(expected, 2),
      reason: 'the cheap rung is not mix(backdrop, tint, a): read $read, predicted $expected',
    );

    // The twin, and a stronger claim than it looks: the opaque
    // rung on the same backdrop must land on the **same level**, because it
    // paints the same law at the backdrop's declared mean and this backdrop is
    // flat — so its mean is the backdrop. Three rungs, one level, and the
    // prediction has no free parameter in it.
    final ui.Image opaque = await _shotOf(tester, tier: GlassTier.opaque, finish: finish);
    expect(
      await _centrePixel(tester, opaque),
      closeTo(expected, 2),
      reason:
          'the opaque rung is not mix(declared backdrop, tint, a): the level it '
          'stands in for is the one the glass shows, and over a flat backdrop '
          'those are the same number',
    );

    // And the break that must break, because "lands on the level" is also what a
    // rung that quietly kept reading the backdrop would do: with **nothing**
    // declared the rung falls back to the tint itself, which is a different
    // number — 29 against 69 here.
    final ui.Image silent = await _shotOf(
      tester,
      tier: GlassTier.opaque,
      finish: finish,
      declareBackdrop: false,
    );
    expect(
      await _centrePixel(tester, silent),
      closeTo((finish.tint.r * 255).round(), 2),
      reason: 'the undeclared fallback is not the finish tint',
    );
    // The rung complains, once, and complains **after** it has drawn — so this
    // has to be taken rather than being the failure. That the pixel above is the
    // fallback's and not a blank is the other half of the same claim: an assert
    // raised where the decision is taken would have left no panel to read.
    expect(
      tester.takeException(),
      isA<FlutterError>(),
      reason: 'the undeclared opaque rung painted a wrong level and said nothing',
    );
  });

  testWidgets('an identity finish is invisible at every rung, and a tinted one is not', (
    WidgetTester tester,
  ) async {
    // The control that keeps the arms above from being "a panel was drawn
    // somewhere": at `GlassFinish.identity` the tint and the rim are both fully
    // transparent, so a cheap surface has nothing to draw and the frame must be
    // the frame without it — byte for byte, the same number the full route is
    // held to.
    final ui.Image bare = await _shotOf(tester, tier: GlassTier.cheap, surface: false);
    final ui.Image identity = await _shotOf(
      tester,
      tier: GlassTier.cheap,
      finish: GlassFinish.identity,
    );
    expect(
      (await _compare(tester, bare, identity)).differing,
      0,
      reason: 'the cheap rung drew something at a finish that has nothing to draw',
    );

    // And the break that must break: the same rung with a real finish.
    final ui.Image tinted = await _shotOf(tester, tier: GlassTier.cheap);
    expect(
      (await _compare(tester, bare, tinted)).differing,
      greaterThan(0),
      reason: 'the comparison cannot see a panel at all, so the arm above compared two blanks',
    );
  });

  // -------------------------------------------------------------------------
  // 4. The group. A rung below the top one stops it fusing, and that is a
  //    stated loss rather than a silent one.
  // -------------------------------------------------------------------------

  testWidgets('a group below the top rung hands its members back, without reporting a refusal', (
    WidgetTester tester,
  ) async {
    await _pumpGroup(tester, tier: GlassTier.cheap, frames: 4);
    final RenderGlassGroup group = tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup));
    expect(
      group.refusedPaints,
      0,
      reason: 'turning the ladder down was reported as an over-capacity refusal',
    );
    for (final RenderGlassSurface surface in _surfaces(tester)) {
      expect(surface.paintsDeferredToGroup, 0, reason: 'the group kept a member it cannot draw');
      expect(surface.paintsCheap, greaterThan(0));
    }

    // The twin at the top rung: the members defer and draw nothing themselves,
    // which is what makes "they stopped deferring" above a reading rather than
    // a default.
    await _pumpGroup(tester, tier: GlassTier.full, frames: 4);
    for (final RenderGlassSurface surface in _surfaces(tester)) {
      expect(surface.paintsDeferredToGroup, greaterThan(0));
      expect(surface.paintsCheap, 0);
    }
  });

  // -------------------------------------------------------------------------
  // 4b. A rung that draws no proxy is *content*, and the two machines that keep
  //     glass out of the proxy have to agree about that.
  // -------------------------------------------------------------------------

  testWidgets('a cheap panel is inside the proxy its neighbour reads', (WidgetTester tester) async {
    // The strongest arm available, and it is the identity control re-used: an
    // identity glass reproduces whatever is behind it byte for byte, so a full
    // panel laid over a cheap one is invisible **iff the cheap one is in the
    // proxy**. If the walk skipped it — say, by keying the skip on the type
    // rather than on the draw — the identity
    // panel would show the scene with the cheap panel missing, exactly where
    // they overlap.
    final ui.Image without = await _shotOf(tester, tier: GlassTier.full, overlay: false);
    final ui.Image with_ = await _shotOf(tester, tier: GlassTier.full, overlay: true);
    final _Diff diff = await _compare(tester, without, with_);
    expect(
      diff.differing,
      0,
      reason: 'the identity panel is visible over a cheap one, so the proxy is missing it: $diff',
    );
  });

  testWidgets('a change inside a cheap panel re-records, and one inside a full panel does not', (
    WidgetTester tester,
  ) async {
    // The other half of the same predicate, on the other machine. The layer
    // watch excludes what the walk skips; a cheap panel is in the proxy, so a
    // change inside it must invalidate the proxy like any other content.
    final key = GlobalKey();
    await _pumpMixed(tester, hostKey: key, mark: Colors.red);
    final dynamic host = key.currentState! as dynamic;
    final int settled = host.recorded as int;
    await tester.pump();
    expect(host.recorded, settled, reason: 'a still mixed screen is still recording');

    await _pumpMixed(tester, hostKey: key, mark: Colors.green);
    await tester.pump();
    expect(
      host.recorded,
      greaterThan(settled),
      reason: 'a change inside a cheap panel did not reach the oracle',
    );

    // The twin: the same change inside the *full* panel, whose subtree is out
    // of the proxy by construction. Without it this arm would pass on a host
    // that records on every frame.
    final full = GlobalKey();
    await _pumpMixed(tester, hostKey: full, mark: Colors.red, markInFullPanel: true);
    final dynamic other = full.currentState! as dynamic;
    final int quiet = other.recorded as int;
    await _pumpMixed(tester, hostKey: full, mark: Colors.green, markInFullPanel: true);
    await tester.pump();
    expect(
      other.recorded,
      quiet,
      reason: 'a change above the glass invalidated the backdrop below it',
    );
  });

  // -------------------------------------------------------------------------
  // 5. Configuration is inherited, so it nests — which is how one screen mixes
  //    rungs (SS7.2, and the reason there is no per-surface argument).
  // -------------------------------------------------------------------------

  testWidgets('an inner theme scopes the rung, and the capture follows it', (
    WidgetTester tester,
  ) async {
    final hostKey = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          finish: GlassFinish.regularDark,
          child: Column(
            children: <Widget>[
              const SizedBox(width: 200, height: 100, child: GlassSurface()),
              GlassTheme(
                data: const GlassThemeData(
                  finish: GlassFinish.regularDark,
                  tier: GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
                ),
                child: const SizedBox(width: 200, height: 100, child: GlassSurface()),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    final List<RenderGlassSurface> surfaces = _surfaces(tester);
    expect(surfaces.length, 2);
    expect(surfaces.where((s) => s.effectiveTier == GlassTier.full).length, 1);
    expect(surfaces.where((s) => s.effectiveTier == GlassTier.cheap).length, 1);

    // One panel is captured and the other is not, so the capture is smaller
    // than the glass — which is the arithmetic the rung exists for.
    final GlassLoad load = _ledger(tester).read(viewSize: kScreen, model: GlassSurfaceCostModel.adrenoCycles);
    expect(load.surfaceCount, 2);
    expect(load.capturedSurfaceCount, 1);
    expect(load.capturedRectAreaLogical, lessThan(load.rectAreaLogical));
    expect((hostKey.currentState! as dynamic).recorded, greaterThan(0));
  });

  testWidgets('a cheap surface draws with no host anywhere above it', (WidgetTester tester) async {
    // The portability requirement said as a tree: the rung has no pipeline, so
    // it must not need one. Before the theme existed the finish travelled on
    // `GlassProxyHandle`, and this panel would have drawn `GlassFinish.regularDark`
    // by accident rather than by declaration — which is the same picture and a
    // different mechanism, so the arm pins the finish to one nobody defaults
    // to.
    const GlassFinish finish = GlassFinish.frosted;
    await tester.pumpWidget(
      _wrap(
        GlassTheme(
          data: const GlassThemeData(
            finish: finish,
            tier: GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
          ),
          child: const SizedBox(width: 200, height: 100, child: GlassSurface()),
        ),
      ),
    );
    await tester.pump();
    final RenderGlassSurface surface = _surface(tester);
    expect(surface.effectiveFinish, finish);
    expect(surface.paintsCheap, greaterThan(0));
  });
}

// ---------------------------------------------------------------------------
// The rig.
// ---------------------------------------------------------------------------

/// The backdrop every picture arm is read against: one flat, known grey.
///
/// Flat on purpose. The claim is about a *level* — `mix(backdrop, tint, a)` —
/// and a level read off a gradient would be a reading of where the sample
/// landed as much as of what the rung did.
const int _kBackdropLuma = 160;

const Color _kBackdrop = Color.fromARGB(255, _kBackdropLuma, _kBackdropLuma, _kBackdropLuma);

/// The backdrop, and everything laid over it, **inside** the host.
///
/// Inside, because the proxy is a capture of the host's own subtree: a backdrop
/// that is a sibling of the [GlassHost] is not in it, and every glass panel
/// then samples black. `Positioned.fill` for the same class of reason — a
/// childless `ColoredBox` under a `Stack`'s loose fit sizes to
/// `constraints.smallest`, which is nothing at all.
Widget _over(List<Widget> children) => Stack(
  children: <Widget>[
    const Positioned.fill(child: ColoredBox(color: _kBackdrop)),
    ...children,
  ],
);

Widget _wrap(Widget child) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _shotKey,
        child: SizedBox.fromSize(size: kScreen, child: child),
      ),
    ),
  ),
);

Widget _scene({
  required GlassTier tier,
  GlassFinish finish = GlassFinish.regularDark,
  bool surface = true,
  bool declareBackdrop = true,
  Key? hostKey,
}) => _wrap(
  GlassHost(
    key: hostKey,
    hardware: GlassHardware.appleMetal,
    finish: finish,
    // The rig's backdrop is one flat grey, so the declaration is *exact* here
    // rather than an estimate — which is what lets the opaque rung's level be
    // predicted in closed form below instead of measured against itself.
    backdrop: declareBackdrop ? _kBackdrop : null,
    tier: GlassTierChoice(tier, GlassTierReason.pinnedByHost),
    child: KeyedSubtree(
      // Keyed by the rung, so switching rungs inside one test builds a fresh
      // surface instead of handing back the previous one with its paint
      // counters still on it. Two arms of the same test sharing a render object
      // is how a twin quietly becomes a sum.
      key: ValueKey<GlassTier>(tier),
      child: _over(<Widget>[
        Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: surface ? const GlassSurface() : const SizedBox(),
          ),
        ),
      ]),
    ),
  ),
);

/// A cheap panel, and optionally an identity-glass panel laid over it.
///
/// The cheap panel is under its own [GlassTheme], so the two rungs sit in one
/// tree — which is the only place the walk's predicate can be wrong.
Widget _overlayScene({required bool overlay}) => _wrap(
  GlassHost(
    hardware: GlassHardware.appleMetal,
    finish: GlassFinish.identity,
    child: _over(<Widget>[
      Positioned(
        left: 60,
        top: 200,
        width: 200,
        height: 120,
        child: GlassTheme(
          data: const GlassThemeData(
            finish: GlassFinish.regularDark,
            tier: GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
          ),
          child: const GlassSurface(),
        ),
      ),
      if (overlay) const Positioned(left: 120, top: 240, width: 200, height: 120, child: GlassSurface()),
    ]),
  ),
);

/// A full panel with a cheap panel **under** it, one of them holding a mark.
///
/// Overlapping on purpose. The oracle answers with a *region*, and it compares
/// that region with the atlas slots: a change that misses every slot misses
/// every texel of the proxy, and holding over it is correct rather than a bug.
/// So a change that is meant to reach the proxy has to land inside the captured
/// region; a cheap panel 260 logical pixels away would read the region oracle
/// working as this rung failing.
///
/// [markInFullPanel] moves the mark between the two, which is the whole twin:
/// the same change, at the same place, in the subtree that is in the proxy and
/// in the one that is not.
Widget _mixed({required Color mark, required bool markInFullPanel, Key? hostKey}) => _wrap(
  GlassHost(
    key: hostKey,
    hardware: GlassHardware.appleMetal,
    finish: GlassFinish.regularDark,
    child: _over(<Widget>[
      Positioned(
        left: 40,
        top: 60,
        width: 200,
        height: 100,
        child: GlassTheme(
          data: const GlassThemeData(
            finish: GlassFinish.regularDark,
            tier: GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
          ),
          child: GlassSurface(
            child: markInFullPanel ? const SizedBox() : ColoredBox(color: mark),
          ),
        ),
      ),
      Positioned(
        left: 20,
        top: 40,
        width: 200,
        height: 100,
        child: GlassSurface(
          child: markInFullPanel ? ColoredBox(color: mark) : const SizedBox(),
        ),
      ),
    ]),
  ),
);

Future<void> _pumpMixed(
  WidgetTester tester, {
  required Color mark,
  required Key hostKey,
  bool markInFullPanel = false,
  int frames = 5,
}) async {
  await tester.pumpWidget(_mixed(mark: mark, markInFullPanel: markInFullPanel, hostKey: hostKey));
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required GlassTier tier,
  GlassFinish finish = GlassFinish.regularDark,
  Key? hostKey,
  int frames = 3,
}) async {
  await tester.pumpWidget(_scene(tier: tier, finish: finish, hostKey: hostKey));
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<void> _pumpGroup(WidgetTester tester, {required GlassTier tier, int frames = 3}) async {
  await tester.pumpWidget(
    _wrap(
      GlassHost(
        hardware: GlassHardware.appleMetal,
        finish: GlassFinish.regularDark,
        tier: GlassTierChoice(tier, GlassTierReason.pinnedByHost),
        child: GlassGroup(
          // See `_scene`: keyed by the rung so the twin below starts from zero.
          key: ValueKey<GlassTier>(tier),
          spacing: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              SizedBox(width: 160, height: 80, child: GlassSurface()),
              SizedBox(height: 20),
              SizedBox(width: 160, height: 80, child: GlassSurface()),
            ],
          ),
        ),
      ),
    ),
  );
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<ui.Image> _shotOf(
  WidgetTester tester, {
  required GlassTier tier,
  GlassFinish finish = GlassFinish.regularDark,
  bool surface = true,
  bool declareBackdrop = true,
  bool? overlay,
}) async {
  await tester.pumpWidget(
    overlay == null
        ? _scene(
            tier: tier,
            finish: finish,
            surface: surface,
            declareBackdrop: declareBackdrop,
          )
        : _overlayScene(overlay: overlay),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  // `layer.toImageSync` rather than the boundary's, which asserts
  // `!debugNeedsPaint`: under a host the tree is dirty by construction.
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

List<RenderGlassSurface> _surfaces(WidgetTester tester) =>
    tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface)).toList();

RenderGlassSurface _surface(WidgetTester tester) => _surfaces(tester).single;

GlassLedger _ledger(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(GlassSurface).first);
  return GlassScope.maybeOf(context)!;
}

/// The red channel at the middle of the panel, 0…255.
Future<int> _centrePixel(WidgetTester tester, ui.Image image) async {
  late int value;
  await tester.runAsync(() async {
    final ByteData data = (await image.toByteData())!;
    final Uint8List px = data.buffer.asUint8List();
    final int x = (kScreen.width / 2).round();
    final int y = (kScreen.height / 2).round();
    value = px[(y * image.width + x) * 4];
  });
  return value;
}

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.total);

  final int maxDelta;
  final int differing;
  final int total;

  @override
  String toString() => '$differing/$total px, worst $maxDelta';
}

Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  late _Diff diff;
  await tester.runAsync(() async {
    final Uint8List pa = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List pb = (await b.toByteData())!.buffer.asUint8List();
    var maxDelta = 0;
    var differing = 0;
    for (var i = 0; i < pa.length; i += 4) {
      var worst = 0;
      for (var c = 0; c < 4; c++) {
        final int d = (pa[i + c] - pb[i + c]).abs();
        if (d > worst) {
          worst = d;
        }
      }
      if (worst > 0) {
        differing++;
        if (worst > maxDelta) {
          maxDelta = worst;
        }
      }
    }
    diff = _Diff(maxDelta, differing, pa.length ~/ 4);
  });
  return diff;
}
