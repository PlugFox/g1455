// The host, and the first thing the package draws.
//
// `flutter test test/glass_host_test.dart`
//
// The pipeline produces a texture and a map. The host
// puts them on the screen, and what it draws is an **identity glass**: sample
// the captured backdrop at the fragment's own place in it and output that. If
// the register's coordinate space, the resolution policy's scale, the atlas's
// map and the recording's clip all line up, the frame with a surface is the
// frame without it — byte for byte. One number for four mechanisms, and it is
// the control this whole route rests on.
//
// The arm it cannot do without displaces the *sample*: a surface that painted
// nothing at all would pass the invisibility check perfectly, and so would one
// moved to the other side of the screen, because an identity glass is invisible
// wherever it is. Only a wrong sample is visible.
//
// Three integration facts are checked here and nowhere else, because none of
// them exists until the pieces are driven by a real frame:
//
//  1. **A surface is not in its own proxy.** It draws the proxy, so a surface
//     inside the proxy is last frame's proxy inside this frame's — and the
//     obvious test of that passes either way, because an identity glass
//     capturing itself is a fixed point. See the arm.
//  2. **The first frame has none.** A capture reads the tree that was just
//     painted, so the earliest a surface can show it is the frame after —
//     which is the staleness the ladder prices, arriving structurally.
//  3. **A surface that mounts between two captures has no slot**, and must draw
//     nothing rather than the slot of whoever used to be at its index.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart';
import 'package:g1455/src/proxy/proxy_retake.dart';

const Size kScreen = Size(400, 600);
final GlobalKey _shotKey = GlobalKey();

void main() {
  testWidgets('an identity glass is invisible, and a shifted sample is not', (
    WidgetTester tester,
  ) async {
    // Full resolution, so the proxy carries one texel per device pixel and the
    // identity is exact rather than approximate.
    final ui.Image bare = await _shot(tester, const _Scene(surface: false));
    final ui.Image glass = await _shot(tester, const _Scene(surface: true));
    final _Diff diff = await _compare(tester, bare, glass);
    expect(
      diff.differing,
      0,
      reason: 'the identity glass is visible, so something in the route is off: $diff',
    );

    // The control, and it has to displace the *sample* rather than the panel:
    // an identity glass is invisible wherever it is, so a surface moved to the
    // other side of the screen is another passing arm rather than a failing
    // one. Twelve logical pixels of shift is small enough to stay inside the
    // slot — the bleed is seven — and large enough that nothing about this
    // scene could match by accident.
    await _pump(tester, const _Scene(surface: true), frames: 4);
    tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface)).debugSampleShift = const Offset(12, 0);
    tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface)).markNeedsPaint();
    await tester.pump();
    final _Diff control = await _compare(tester, bare, _frame());
    expect(control.differing, greaterThan(1000), reason: 'a shifted sample changed nothing');
  });

  testWidgets('the identity holds at a fractional density', (WidgetTester tester) async {
    // Every arm above runs at dpr 1, where a whole logical pixel is a whole
    // device pixel and a slot snapped to the first is on the grid of the
    // second. A phone is often neither: the S908B is 1.875, and there a slot
    // starting at logical 100 started at device 187.5 — every texel straddling
    // two screen pixels, 9682 px of a still identity glass differing by up to
    // 72 code values on the device, and zero here because no arm asked.
    for (final double dpr in <double>[1.875, 2.625, 2.75]) {
      tester.view.devicePixelRatio = dpr;
      final ui.Image bare = await _shot(tester, const _Scene(surface: false), dpr: dpr);
      final ui.Image glass = await _shot(tester, const _Scene(surface: true, second: true), dpr: dpr);
      final _Diff diff = await _compare(tester, bare, glass);
      expect(diff.differing, 0, reason: 'identity visible at dpr $dpr: $diff');
    }
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('two surfaces are invisible, including the one whose slot is not at the origin', (
    WidgetTester tester,
  ) async {
    // The pair the landmark rule asks for. With one surface the atlas has one
    // slot and it starts at (0, 0), so the slot's own origin is zero and a map
    // that dropped it would pass every arm above — verified by dropping it.
    // The second surface's slot starts somewhere else, and that is the only
    // place the term is observable at all.
    final ui.Image bare = await _shot(tester, const _Scene());
    final ui.Image both = await _shot(tester, const _Scene(surface: true, second: true));
    final _Diff diff = await _compare(tester, bare, both);
    expect(diff.differing, 0, reason: 'a surface away from the atlas origin is visible: $diff');
    // And the slots really are in different places, or the arm is the same one
    // as before wearing two panels.
    final List<RenderGlassSurface> surfaces = tester
        .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
        .toList();
    expect(surfaces, hasLength(2));
  });

  testWidgets('a surface is not in its own proxy', (WidgetTester tester) async {
    // The self-capture rule, and it took two attempts to test, which is the
    // interesting part. The obvious arm — a still screen has to give the same
    // frame forever — **passes either way**: an identity glass that captured
    // itself would be drawing a copy of its own place into its own place, which
    // is a fixed point, so the picture converges immediately and nothing
    // drifts. Verified by deleting the rule and watching every arm still pass.
    //
    // What breaks the fixed point is a sample that is *not* the identity. With
    // the sample displaced, a surface inside its own proxy displaces the
    // previous displacement, and the picture walks across the screen one step
    // per frame. So the arm is: displace, let it settle, and check that two
    // frames seven apart are the same frame.
    await _pump(tester, const _Scene(surface: true), frames: 4);
    tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface)).debugSampleShift = const Offset(12, 0);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final ui.Image settled = _frame();
    for (var i = 0; i < 7; i++) {
      await tester.pump();
    }
    final _Diff drift = await _compare(tester, settled, _frame());
    expect(drift.differing, 0, reason: 'the proxy is feeding on itself: $drift');
  });

  testWidgets('the first frame has no proxy and the second does', (WidgetTester tester) async {
    await _pump(tester, const _Scene(surface: true), frames: 1);
    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(
      surface.paintsWithoutProxy,
      greaterThan(0),
      reason: 'a proxy existed before anything had been captured',
    );
    expect(surface.paintsWithProxy, 0);

    final int without = surface.paintsWithoutProxy;
    await tester.pump();
    await tester.pump();
    expect(surface.paintsWithProxy, greaterThan(0), reason: 'the proxy never arrived');
    expect(
      surface.paintsWithoutProxy,
      without,
      reason: 'the surface went back to having no proxy after having one',
    );
  });

  testWidgets('a surface that arrives between captures draws nothing rather than a stranger', (
    WidgetTester tester,
  ) async {
    // The hazard identity keys exist for. The register is a set; a surface that
    // mounts shifts every index after it, and a frame is by construction one
    // frame old — so an index-keyed lookup would hand the newcomer the slot of
    // whoever used to be there, which is a real backdrop from the wrong part of
    // the screen and looks like a plausible refraction.
    await _pump(tester, const _Scene(surface: true), frames: 4);
    final RenderGlassSurface first = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(first.paintsWithProxy, greaterThan(0));

    // A second surface appears, and the frame in hand knows nothing about it.
    await tester.pumpWidget(_mount(const _Scene(surface: true, second: true)));
    final RenderGlassSurface newcomer = tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface)).last;
    expect(
      newcomer.paintsWithProxy,
      0,
      reason: 'the newcomer sampled a slot that belongs to somebody else',
    );
    // And on the next capture it has one of its own.
    await tester.pump();
    await tester.pump();
    expect(newcomer.paintsWithProxy, greaterThan(0));
  });

  testWidgets('the host\'s budget reaches the divisor and not only the ceiling', (
    WidgetTester tester,
  ) async {
    // `GlassHost.budgetDeltaE` says it is the whole quality allowance and both
    // axes draw on it. If it reached the retake oracle and not the resolution
    // policy, a host that halved its budget would hold the proxy for fewer
    // frames and go on recording it just as small. Half an effect, and nothing
    // would say so.
    Future<ProxyResolution> divisorAt(double budget) async {
      await tester.pumpWidget(_budgeted(budget));
      await tester.pump();
      await tester.pump();
      final GlassProxyScope scope = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope));
      final GlassProxyFrame frame = scope.handle.frame!;
      return frame.resolution.resolution;
    }

    // The rungs either side of the answer, on a dpr-2 screen with the
    // Apple-calibrated finish: a quarter costs 0.221 ΔE and a half costs 0.143.
    expect(await divisorAt(0.348), const ProxyResolution.quarter());
    expect(await divisorAt(0.15), const ProxyResolution.half());
    expect(await divisorAt(0.10), const ProxyResolution.full());
  });

  testWidgets('no host above is not a crash, and the surface is still invisible', (
    WidgetTester tester,
  ) async {
    // A `GlassSurface` in a tree with no `GlassHost` has nowhere to get a proxy
    // from. It has to be inert rather than wrong: this is what a package looks
    // like when somebody forgets the host, and a red box or an exception would
    // both be worse than nothing.
    final ui.Image bare = await _shot(tester, const _Scene(surface: false), host: false);
    final ui.Image glass = await _shot(tester, const _Scene(surface: true), host: false);
    expect((await _compare(tester, bare, glass)).differing, 0);
  });

  testWidgets('what a surface holds is on top of the glass, not under it', (
    WidgetTester tester,
  ) async {
    // The claim `skipGlassSurfaces` makes in its own comment — "what sits *on* a
    // nav bar is on top of the glass, not behind it" — has a paint order
    // attached to it, and nothing above checks it: every arm so far puts an
    // *empty* panel over the scene, where the order is unobservable. A real
    // panel holds a title and icons, and the ladder's glass step is about to
    // hold the same content as every other step.
    //
    // So: the same content in the same place, once inside a surface and once on
    // its own. The proxy excludes the whole surface subtree, so the panel draws
    // the backdrop that was behind it and the content goes on top — which makes
    // the two frames the same frame, exactly as the empty arm does.
    final ui.Image bare = await _shot(tester, const _Scene(content: true));
    final ui.Image glass = await _shot(tester, const _Scene(surface: true, content: true));
    final _Diff diff = await _compare(tester, bare, glass);
    expect(diff.differing, 0, reason: 'the glass painted over its own content: $diff');
  });

  testWidgets('a capture limit stops the recording and nothing else', (WidgetTester tester) async {
    // The arm behind the capture-limit diagnostic. What it has to prove is not that the
    // count stops — that is one `if` — but that everything *downstream* of the
    // recording carries on: the surface still samples, still through the
    // shader, still from a texture of exactly the same size. An arm that
    // quietly stopped drawing would show the same fall in frame time on the
    // device and would mean nothing at all, which is precisely the failure this
    // seam is exposed to.
    //
    // It needs its own frame source, and that is a fact about the binding
    // rather than about the host. `addPostFrameCallback` does not request a
    // frame — it waits for one that happens anyway — so an unlimited host keeps
    // going only because each published proxy dirties the surface and schedules
    // the next frame. Hold the proxy and that chain stops: measured here, an
    // idle tree produces exactly one held frame and then nothing, however many
    // times `pump` is called. On a device every scene animates and the question
    // does not arise; headless the frames have to be asked for.
    final limited = GlobalKey();
    await _pump(tester, const _Scene(surface: true), frames: 3, hostKey: limited, maxCaptures: 1);
    for (var i = 0; i < 6; i++) {
      // The surface is a repaint boundary and nothing dirties it once the proxy
      // stops changing, so on a still tree it is served from its retained layer
      // and `paint` is never called again. That is correct engine behaviour and
      // it is also why the counters below need the paint asked for: on a device
      // a real screen moves, and the surface repaints because the
      // content under it does.
      tester.renderObject<RenderObject>(find.byType(GlassSurface)).markNeedsPaint();
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }

    final dynamic host = limited.currentState! as dynamic;
    expect(host.recorded, 1, reason: 'the limit did not stop the recording');
    expect(host.held, greaterThan(3), reason: 'the loop stopped re-arming instead of holding');

    // Downstream is untouched: the surface still painted with a proxy and still
    // ran the shader, on frames long past the limit.
    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(surface.paintsWithProxy, greaterThan(1), reason: 'the held proxy stopped being sampled');
    expect(surface.paintsWithOptics, greaterThan(1), reason: 'the shader stopped running');

    // The pair. Same tree, same frames, no limit — and it records every one of
    // them, so the arm is a difference in exactly one thing rather than a tree
    // that never captured. `undeclared` is what "no limit" has to mean:
    // the default holds a still screen on its own, and then the limit and
    // the default would be indistinguishable here.
    final free = GlobalKey();
    await _pump(
      tester,
      const _Scene(surface: true),
      frames: 3,
      hostKey: free,
      content: GlassContentDeclaration.undeclared,
    );
    for (var i = 0; i < 6; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect((free.currentState! as dynamic).recorded, greaterThan(4));
    expect((free.currentState! as dynamic).held, 0);
  });

  testWidgets('the oracle now watches the markers the application declared', (
    WidgetTester tester,
  ) async {
    // `RenderGlassProxy` publishes `proxyChanges` and `RetakeOracle.watch`
    // subscribes to it, both tested in isolation. What only this arm sees is
    // the host calling `watch` on the oracle it hands the pipeline; without
    // that, every marker in every application is inert.
    final hostKey = GlobalKey();
    await _pump(tester, const _Scene(surface: true, markers: 2), frames: 4, hostKey: hostKey);
    expect(
      (hostKey.currentState! as dynamic).watchedMarkers,
      2,
      reason: 'the host is not subscribed to the markers under it',
    );

    // The negative control, and it is what separates a walk that found nothing
    // from a walk that never ran. Without it the arm above passes on any tree
    // whose marker count happens to match.
    final bareKey = GlobalKey();
    await _pump(tester, const _Scene(surface: true), frames: 4, hostKey: bareKey);
    expect((bareKey.currentState! as dynamic).watchedMarkers, 0);

    // And the subscription survives the tree changing under it. The walk costs
    // 24 us so it does not run every frame; the ledger is the signal, and
    // it notifies exactly when a surface arrives or leaves.
    final growKey = GlobalKey();
    await _pump(tester, const _Scene(surface: true, markers: 1), frames: 4, hostKey: growKey);
    expect((growKey.currentState! as dynamic).watchedMarkers, 1);
    await _pump(
      tester,
      const _Scene(surface: true, second: true, markers: 2),
      frames: 4,
      hostKey: growKey,
    );
    expect(
      (growKey.currentState! as dynamic).watchedMarkers,
      2,
      reason: 'a surface arrived and the marker walk was not redone',
    );
  });

  test('the retake ceiling is zero on every finish, and that is the arithmetic', () {
    // Which is why the wiring above bought no frames on its own, and saying so
    // is the point of this arm. Before `GlassContentDeclaration` existed,
    // `decide()` read
    //
    //     if (dirty) changed; else framesSinceCapture >= ceiling ? ceiling : hold
    //
    // and with a ceiling of 0 the right-hand branch is `ceiling` on every frame,
    // so `hold` was unreachable — including on a screen where nothing moved at
    // all. The proxy was re-recorded every frame of every application. The arm
    // below is that branch made reachable, by declaration rather than by moving
    // this table.
    //
    // It is not a defect in the table. The default budget is 1% of the scale
    // between two of Apple's own materials, and every finish's *first*
    // stale frame already costs more than that.
    const double budget = ProxyResolutionPolicy.defaultDamageBudgetDeltaE;
    expect(budget, closeTo(0.348, 0.001));
    for (final String finish in ProxyStaleness.measuredFinishes.where((String f) => f != 'regularLight')) {
      final double? one = ProxyStaleness.damageAt(finish, 1);
      expect(one, isNotNull);
      expect(
        one,
        greaterThan(budget),
        reason: '$finish can afford a stale frame, so the ceiling is not zero for the stated reason',
      );
      expect(ProxyStaleness.maxStaleFrames(finish, budget), 0);
    }
    // Every finish but the light branch of `.regular`: its
    // first stale frame is 82% of the budget, so a still light screen may be
    // held one frame — the arithmetic, not an exception made for it.
    expect(ProxyStaleness.damageAt('regularLight', 1)! / budget, closeTo(0.82, 0.01));
    expect(ProxyStaleness.maxStaleFrames('regularLight', budget), 1);
    // Of the rest, the cheapest is the one that gets closest, and it misses by 10%.
    expect(ProxyStaleness.damageAt('regularDark', 1)! / budget, closeTo(1.10, 0.01));
    // Spending twice the budget on staleness alone buys two frames on
    // `regular`, one on `frosted` and none on `clear` — the ordering follows how
    // little of the backdrop each finish lets through, which is what makes
    // it a property of the material rather than of the number. That is the
    // decision the ceiling represents, and it is the host's to make rather than
    // this table's.
    expect(ProxyStaleness.maxStaleFrames('regularDark', 2 * budget), 2);
    expect(ProxyStaleness.maxStaleFrames('frosted', 2 * budget), 1);
    expect(ProxyStaleness.maxStaleFrames('clear', 2 * budget), 0);
  });

  testWidgets('a declaring host stops re-recording, and hears the change it is told about', (
    WidgetTester tester,
  ) async {
    // The decision the arm above ends on, made. `GlassContentDeclaration` is
    // what turns the unreachable branch into a reachable one, and the ceiling is
    // deliberately not consulted under it: the table it comes from prices a
    // *moving* scene going stale, and this branch has established the scene did
    // not move.
    //
    // The frames have to be asked for, and that is the same fact about the
    // binding the capture-limit arm records: a held proxy dirties nothing, so
    // nothing schedules the next frame and `pump` returns without producing
    // one. On a device every scene moves; headless a still screen is literally
    // still.
    final declaredKey = GlobalKey();
    await _pump(
      tester,
      const _Scene(surface: true),
      frames: 3,
      hostKey: declaredKey,
      content: GlassContentDeclaration.declared,
    );
    for (var i = 0; i < 6; i++) {
      tester.renderObject<RenderObject>(find.byType(GlassSurface)).markNeedsPaint();
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    final declared = declaredKey.currentState! as dynamic;
    expect(declared.recorded, 1, reason: 'a still screen was re-recorded under a declaration');
    expect(declared.held, greaterThan(3), reason: 'the capture loop stopped re-arming');

    // A held proxy *can* still be sampled — the frames above ask for the paint
    // explicitly. It is not sampled on a real screen, and that is the finding
    // rather than a caveat: `GlassSurface` is a repaint boundary, an unchanging
    // proxy does not dirty it, and on the device the held arms paint 4 times per
    // window against 6770. So the declaration is a lever over the whole route
    // at steady state and not only over the capture: holding removes both the
    // write and the sampling.
    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(surface.paintsWithProxy, greaterThan(1));

    // The escape hatch: content that changed without moving anything says so,
    // and the host has to be listening for it to matter. Both halves are in this
    // one expectation — the handle's notifier, and the host's subscription to
    // it.
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    final int before = declared.recorded as int;
    handle.noteChange();
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 16));
    expect(declared.recorded, before + 1, reason: 'the declared change did not reach the oracle');

    // The control, and it is the same scene over the same frames: with the watch
    // distrusted every one of them is recorded, because the ceiling is zero. A
    // number that exists in only one arm is a number about that arm.
    final silentKey = GlobalKey();
    await _pump(
      tester,
      const _Scene(surface: true),
      frames: 3,
      hostKey: silentKey,
      content: GlassContentDeclaration.undeclared,
    );
    for (var i = 0; i < 6; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    final silent = silentKey.currentState! as dynamic;
    expect(silent.recorded, greaterThan(4));
    expect(silent.held, 0);
  });

  testWidgets('a scroll under the glass is seen without the application declaring it', (
    WidgetTester tester,
  ) async {
    // The commonest change there is, and the one neither of the oracle's own
    // inputs can see: a sliver's children are repaint boundaries, so a scroll
    // re-adds their layers at a new offset without painting them, and the bar
    // did not move. Under a declaration that would freeze the proxy over a
    // scrolling list — which is most of the screens this package is for.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final hostKey = GlobalKey();
    await _pump(
      tester,
      _ScrollScene(controller: controller),
      frames: 3,
      hostKey: hostKey,
      content: GlassContentDeclaration.declared,
    );
    final dynamic host = hostKey.currentState! as dynamic;

    // Still: held, and the frames have to be asked for because a held proxy
    // dirties nothing.
    for (var i = 0; i < 4; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    final int still = host.recorded as int;
    expect(still, 1, reason: 'a still list was re-recorded under a declaration');

    // The control that says the scene is the shape the arm claims: scrolling it
    // paints nothing under the glass and moves no surface, so without the
    // observation the oracle has nothing at all to go on.
    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    final Rect before = surface.localToGlobal(Offset.zero) & surface.size;

    controller.jumpTo(240);
    await tester.pump();
    expect(
      surface.localToGlobal(Offset.zero) & surface.size,
      before,
      reason: 'the bar moved, so this arm is not about a scroll the oracle cannot see',
    );
    expect(
      host.recorded,
      greaterThan(still),
      reason: 'the scroll was not seen and the proxy is frozen over a moving list',
    );
  });

  testWidgets('a change that misses the glass is seen, and held through anyway', (
    WidgetTester tester,
  ) async {
    // Asked as a pair: "a shared texture is a shared dirty flag: a spinner
    // behind button A invalidates the whole cluster". With one flag for the
    // whole screen, a spinner anywhere would invalidate glass everywhere.
    //
    // Both arms mount the same widget, the same size, repainting the same way
    // behind its own boundary. The only difference is 300 logical pixels of
    // placement. Neither half alone is the measurement: an arm that only held
    // would pass on a watch that had stopped working, and an arm that only
    // recorded would pass on the mechanism being absent.
    final away = ValueNotifier<int>(0);
    addTearDown(away.dispose);
    final awayKey = GlobalKey();
    await _pump(tester, _Scene(surface: true, pulse: away), frames: 4, hostKey: awayKey);
    final dynamic host = awayKey.currentState! as dynamic;
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    final int held = host.recorded as int;
    final int missed = handle.changesOutsideCapture;

    away.value++;
    await tester.pump();
    expect(
      host.recorded,
      held,
      reason: 'a repaint 300 px below the glass re-recorded the proxy',
    );
    expect(
      handle.changesOutsideCapture,
      greaterThan(missed),
      reason: 'the proxy was held for some other reason, so this arm says nothing about the region',
    );

    // The twin, and the arm that could have separated it: the same repaint
    // inside the surface's own rectangle. A mechanism that answered "outside"
    // unconditionally — a region always empty, a slot list never consulted —
    // passes everything above and fails here.
    final under = ValueNotifier<int>(0);
    addTearDown(under.dispose);
    final underKey = GlobalKey();
    await _pump(
      tester,
      _Scene(surface: true, pulse: under, pulseUnder: true),
      frames: 4,
      hostKey: underKey,
    );
    final dynamic overlapped = underKey.currentState! as dynamic;
    final int before = overlapped.recorded as int;
    under.value++;
    await tester.pump();
    expect(
      overlapped.recorded,
      greaterThan(before),
      reason: 'a repaint inside the surface was treated as outside the capture',
    );
  });

  testWidgets('and the frame it held is the frame it would have recorded', (
    WidgetTester tester,
  ) async {
    // The half that makes the arm above a correctness claim rather than a
    // saving. Holding is only free if the pixels agree, so: the same scene, the
    // same repaint away from the glass, recorded on every frame against held
    // since the first — and the two frames have to be the same frame.
    //
    // **Every mount here carries its own host key, and that is not tidiness.**
    // `pumpWidget` reuses the element at the same position when the widget type
    // and key match, so four unkeyed `GlassHost`s in one test are *one* host
    // state wearing four configurations — and `recorded` is a field of that
    // state. The frozen arm then means something else than it says: with
    // `recorded` already past 1 from the arm before it, `maxCaptures: 1`
    // refuses the *first* capture rather than every capture after it, and
    // `didUpdateWidget` has just published `null`. So the arm rendered an
    // identity glass with **no proxy at all**, which draws the same frame as an
    // identity glass with a perfectly fresh one. The control read 0 differing
    // pixels and meant "there was nothing to be stale". Bisecting it named the
    // key on the *second* mount, not the fourth.
    final a = ValueNotifier<int>(0);
    addTearDown(a.dispose);
    await _pump(tester, _Scene(surface: true, pulse: a), frames: 4, hostKey: GlobalKey());
    a.value++;
    await tester.pump();
    await tester.pump();
    final Uint8List frugal = await _pixels(tester, _frame());

    final b = ValueNotifier<int>(0);
    addTearDown(b.dispose);
    await _pump(
      tester,
      _Scene(surface: true, pulse: b),
      frames: 4,
      hostKey: GlobalKey(),
      content: GlassContentDeclaration.undeclared,
    );
    b.value++;
    await tester.pump();
    await tester.pump();
    final Uint8List eager = await _pixels(tester, _frame());

    final _Diff same = _diff(frugal, eager);
    expect(
      same.differing,
      0,
      reason: 'the held proxy is not the one that would have been taken: $same',
    );

    // And the control on the instrument, because "identical" is what a
    // comparison of two blank screens also says. A proxy frozen over content
    // that really is under the glass has to come out *different* — otherwise
    // the arm above would pass on a route where the proxy reaches no pixel.
    final c = ValueNotifier<int>(0);
    addTearDown(c.dispose);
    final frozenKey = GlobalKey();
    await _pump(
      tester,
      _Scene(surface: true, pulse: c, pulseUnder: true),
      frames: 4,
      hostKey: frozenKey,
      maxCaptures: 1,
    );
    final Uint8List before = await _pixels(tester, _frame());
    c.value++;
    await tester.pump();
    await tester.pump();
    final Uint8List frozen = await _pixels(tester, _frame());
    // The instrument, checked before it is used: the proxy really is frozen —
    // one capture and nothing after it — and the frame really did move, because
    // the pulse shows through the surface's rounded corners even while the
    // glass over it is a picture from before the change.
    expect((frozenKey.currentState! as dynamic).recorded, 1);
    final _Diff corners = _diff(before, frozen);
    expect(
      corners.differing,
      greaterThan(0),
      reason: 'the scene did not change at all, so nothing below is about staleness: $corners',
    );

    final d = ValueNotifier<int>(0);
    addTearDown(d.dispose);
    await _pump(
      tester,
      _Scene(surface: true, pulse: d, pulseUnder: true),
      frames: 4,
      content: GlassContentDeclaration.undeclared,
    );
    d.value++;
    await tester.pump();
    await tester.pump();
    final _Diff stale = _diff(frozen, await _pixels(tester, _frame()));
    expect(
      stale.differing,
      greaterThan(0),
      reason:
          'a proxy frozen over changing content rendered the same frame, so the comparison '
          'above compares nothing: $stale',
    );
  });

  testWidgets('the residual blur pass runs out before the divisor does', (
    WidgetTester tester,
  ) async {
    // On a device the route's price has a knee no model accounts for: the addition
    // falls 0.94 and 0.65 ms across the first two intervals of the divisor and
    // 0.05 across the third. The only mechanism anyone has is that the two
    // things a divisor buys after a scale-free capture — this pass and
    // the texture's bandwidth — do not fall together, because the pass's sigma
    // is spent in *texels* and the texel grows with the divisor.
    //
    // The cost half needs a device and this arm is **not** it. What a blur costs
    // is its atlas area times its kernel radius; what it changes on screen is
    // its kernel radius times the magnification back, and at a divisor of 8 that
    // magnification is 8. So the two go in different directions and the numbers
    // below must never be read as a price: measured here, the pass's visible
    // effect at an eighth is 0.32 of its effect at 1:1, while the same
    // constants put its *work* at 0.0003 of it.
    //
    // What the arm does license is the mechanism's premise, which is checkable
    // and was not obvious: the pass's reach is spent in **texels**, not in
    // logical pixels. And it is what gives `blurPass` an observable trace — a
    // knob whose off arm drew the same picture would be the `targetFormat`
    // mistake again (an axis with no consequence, measured three times and
    // reported as a finding). The fold's trace is a different one and lives one
    // storey down, in the arm below: it draws the *same* picture on purpose, so
    // what a report can see about it is the snapshot count and nothing else.
    final Map<int, double> changed = <int, double>{};
    for (final int divisor in const <int>[1, 2, 4, 8]) {
      await _pump(tester, _pinned(divisor, blurPass: ProxyBlurPass.split), frames: 4, host: false);
      final ui.Image blurred = _frame();
      await _pump(tester, _pinned(divisor, blurPass: ProxyBlurPass.none), frames: 4, host: false);
      final _Diff diff = await _compare(tester, blurred, _frame());
      changed[divisor] = diff.meanDelta;
      blurred.dispose();
    }

    // The trace, at the divisor where the pass has the whole sigma to spend.
    expect(
      changed[1]!,
      greaterThan(1.0),
      reason: 'turning the blur off changed almost nothing at 1:1, so the knob is not an axis',
    );
    // And it shrinks with the divisor, monotonically: mean 1.197 / 1.105 / 0.760
    // / 0.388 code values over the frame, worst 33 / 30 / 22 / 13.
    //
    // That shrinking is the whole point, because `residualSigmaFor` at dpr 2 on
    // `regular` is 2.600 / 2.583 / 2.530 / 2.306 logical px — nearly flat, a
    // ratio of 1.13 end to end. A pass spending that in logical pixels would
    // change the picture by the same amount at every divisor. In texels the same
    // four numbers are 5.20 / 2.58 / 1.27 / 0.58, a ratio of 9.02, and Impeller
    // truncates the kernel at `(sigma - 0.5) * sqrt(3)` — 0.13 of a texel at the
    // last one.
    for (final int divisor in const <int>[2, 4, 8]) {
      expect(
        changed[divisor],
        lessThan(changed[divisor ~/ 2]!),
        reason: 'the blur pass did not shrink from ${divisor ~/ 2} to $divisor: $changed',
      );
    }
    expect(
      changed[8]! / changed[1]!,
      lessThan(0.5),
      reason: 'the pass is still doing most of its work at the deepest rung: $changed',
    );

    // The negative control the shrinking arm cannot do without: the *sigma* is
    // nearly the same at all four divisors, so nothing above is explained by the
    // finish being spent. What changes is the unit it is spent in.
    const GlassFinish regular = GlassFinish.regularDark;
    final List<double> logical = <double>[
      for (final int k in const <int>[1, 2, 4, 8])
        ProxyResolution.divisor(k).residualSigmaFor(regular.blurSigmaLogical, 2)!,
    ];
    expect(logical.first / logical.last, closeTo(1.13, 0.01));
    final List<double> texels = <double>[
      for (var i = 0; i < 4; i++) logical[i] * 2 / <int>[1, 2, 4, 8][i],
    ];
    expect(texels.first / texels.last, closeTo(9.02, 0.05));
  });

  testWidgets('the fold is invisible on screen and visible in the snapshot count', (
    WidgetTester tester,
  ) async {
    // The fold's whole claim is that it changes nothing but the amount of work,
    // so the arm has to check both halves — and the two halves want opposite
    // things from the instrument, which is why they are asserted together. The
    // pixels have to agree (to 1 code value on a picture; this
    // is the same on a mounted host, where the sigma comes from the divisor),
    // and the snapshot count has to disagree, because it is the only thing a
    // device report can see about which spelling ran.
    const int divisor = 4;
    final Map<ProxyBlurPass, int> snapshots = <ProxyBlurPass, int>{};
    final Map<ProxyBlurPass, int> generations = <ProxyBlurPass, int>{};
    final Map<ProxyBlurPass, ui.Image> shots = <ProxyBlurPass, ui.Image>{};
    for (final ProxyBlurPass pass in <ProxyBlurPass>[
      ProxyBlurPass.split,
      ProxyBlurPass.folded,
    ]) {
      // A key per arm, so the second mount builds a fresh host rather than
      // updating the first: `GlassProxyHandle` outlives a `didUpdateWidget`,
      // and both counters would then carry the previous arm's tally into this
      // one's ratio.
      await _pump(
        tester,
        _pinned(divisor, blurPass: pass, hostKey: GlobalKey()),
        frames: 4,
        host: false,
      );
      final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
      snapshots[pass] = handle.snapshots;
      generations[pass] = handle.generation;
      shots[pass] = _frame();
    }

    // Per published proxy, because the number of frames a widget test drives is
    // not the quantity under test — two runs of four pumps can publish
    // different counts and the ratio is what the report reads anyway.
    expect(generations[ProxyBlurPass.split], greaterThan(0));
    expect(generations[ProxyBlurPass.folded], greaterThan(0));
    expect(
      snapshots[ProxyBlurPass.split]! / generations[ProxyBlurPass.split]!,
      2.0,
      reason: 'the split pass is one rasterization of the atlas and one of its blur',
    );
    expect(
      snapshots[ProxyBlurPass.folded]! / generations[ProxyBlurPass.folded]!,
      1.0,
      reason: 'the fold still took a second snapshot, so it saved nothing',
    );

    final _Diff diff = await _compare(
      tester,
      shots[ProxyBlurPass.split]!,
      shots[ProxyBlurPass.folded]!,
    );
    for (final ui.Image shot in shots.values) {
      shot.dispose();
    }
    expect(diff.total, greaterThan(0), reason: 'nothing was compared');
    expect(
      diff.maxDelta,
      lessThanOrEqualTo(1),
      reason:
          'the fold moved the screen ($diff), so it is a different material '
          'rather than a cheaper one',
    );
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

/// A screen with structure at several scales, and optionally a panel over it.
/// A list under a glass bar: the shape the scroll observation exists for.
///
/// The scrollable is a sliver, so its children are repaint boundaries and a
/// scroll re-adds their layers at a new offset without painting anything. The
/// bar does not move either. Both of the oracle's own inputs therefore read
/// "nothing happened" while every pixel under the glass changed.
class _ScrollScene extends StatelessWidget {
  const _ScrollScene({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _shotKey,
    child: SizedBox.fromSize(
      size: kScreen,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView.builder(
              controller: controller,
              itemCount: 200,
              itemExtent: 40,
              itemBuilder: (BuildContext context, int i) => ColoredBox(
                color: i.isEven ? const Color(0xFF204060) : const Color(0xFF802040),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            width: 320,
            height: 64,
            child: GlassSurface(),
          ),
        ],
      ),
    ),
  );
}

class _Scene extends StatelessWidget {
  const _Scene({
    this.surface = false,
    this.second = false,
    this.content = false,
    this.markers = 0,
    this.pulse,
    this.pulseUnder = false,
  });

  final bool surface;
  final bool second;

  /// Content that repaints on demand, behind a repaint boundary of its own.
  ///
  /// The boundary is the mechanism and not a tidying: a repaint mints a
  /// `ui.Picture` inside the boundary that owns it, and the layer carries *that
  /// boundary's* bounds. Without one the dirt lands in the host's own picture,
  /// whose bounds are the whole screen, and the region the watch reports is the
  /// screen — which is the honest answer and the reason the lever is a property
  /// of the tree's shape rather than of the change.
  final ValueNotifier<int>? pulse;

  /// Whether [pulse] sits inside the surface's rectangle or well away from it.
  ///
  /// The only difference between the two arms of the shared-flag pair. Same widget, same
  /// size, same repaint, same boundary: what moves is whether the pixels it
  /// changes are pixels the proxy holds.
  final bool pulseUnder;

  /// How many [GlassProxy] markers the scene declares.
  ///
  /// Here for the arm about the retake oracle's subscription: a marker that is
  /// in the tree and one that is not are the only two states that tell a walk
  /// which found nothing from a walk that never ran.
  final int markers;

  /// Whether the panel's rectangle holds anything.
  ///
  /// Placed at the same rect whether or not there is a surface, so the pair
  /// differs in exactly one thing: whether the content is *inside* the glass.
  final bool content;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _shotKey,
    child: SizedBox.fromSize(
      size: kScreen,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _Bars())),
          // Before the surface in the stack, so the `under` arm really is under
          // the glass and not on top of it.
          if (pulse case final ValueNotifier<int> repaint)
            Positioned(
              left: 60,
              top: pulseUnder ? 80 : 380,
              width: 180,
              height: 120,
              child: RepaintBoundary(
                child: CustomPaint(painter: _Pulse(repaint), size: const Size(180, 120)),
              ),
            ),
          if (surface)
            Positioned(
              left: 60,
              top: 80,
              width: 180,
              height: 120,
              child: GlassSurface(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                child: content ? const _Label() : null,
              ),
            ),
          if (!surface && content) const Positioned(left: 60, top: 80, width: 180, height: 120, child: _Label()),
          if (second)
            const Positioned(
              left: 60,
              top: 380,
              width: 180,
              height: 120,
              child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(20))),
            ),
          for (var i = 0; i < markers; i++)
            Positioned(
              left: 260,
              top: 40.0 + i * 140,
              width: 120,
              height: 120,
              child: const GlassProxy.hidden(child: ColoredBox(color: Color(0xFFCC4400))),
            ),
        ],
      ),
    ),
  );
}

/// What a panel holds. Opaque marks rather than text: `flutter_tester` ships no
/// font, and a glyph drawn as a filled box would still work here but would make
/// the arm's failure read as a font problem.
class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LabelPainter());
}

class _LabelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xFFFFF3C4);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(16, 20 + i * 24, size.width - 32 - i * 30, 10), paint);
    }
    canvas.drawCircle(Offset(size.width - 32, size.height - 28), 12, paint);
  }

  @override
  bool shouldRepaint(_LabelPainter oldDelegate) => false;
}

/// Content that repaints without rebuilding, moving or declaring anything.
class _Pulse extends CustomPainter {
  _Pulse(this.tick) : super(repaint: tick);

  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromARGB(255, 40 + (tick.value * 37) % 200, 90, 160),
    );
  }

  @override
  bool shouldRepaint(_Pulse oldDelegate) => true;
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
      canvas.drawRect(Rect.fromLTWH(x, 0, 7, size.height), Paint()..color = const Color(0x55FFFFFF));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

Widget _mount(
  Widget child, {
  double dpr = 1,
  bool host = true,
  Key? hostKey,
  int? maxCaptures,
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
}) => MediaQuery(
  // A device pixel ratio of 1, and a finish the policy will not shrink: the
  // identity has no blur of its own, so any divisor would out-blur it and the
  // optics ceiling holds the proxy at full resolution — which is what makes the
  // identity exact instead of a resampling.
  data: MediaQueryData(size: kScreen, devicePixelRatio: dpr),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: host
          ? GlassHost(
              key: hostKey,
              maxCaptures: maxCaptures,
              content: content,
              hardware: GlassHardware.appleMetal,
              // The control finish: no blur, no tint, no outline, no
              // displacement. A surface wearing it must be invisible, which is
              // one number for the whole route.
              finish: GlassFinish.identity,
              child: child,
            )
          : child,
    ),
  ),
);

/// A host with a real finish on a dpr-2 screen, for the arms about the budget.
///
/// Separate from [_mount], which pins the identity finish at dpr 1 so the proxy
/// is recorded 1:1 — that is what the pixel arms need and it is also the one
/// configuration in which the divisor cannot move.
Widget _budgeted(double budget) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        hardware: GlassHardware.appleMetal,
        // Named: unnamed, a light screen gets the light branch, and
        // the rungs below are the dark one's.
        finish: GlassFinish.regularDark,
        budgetDeltaE: budget,
        child: const _Scene(surface: true),
      ),
    ),
  ),
);

/// A host at a pinned divisor on a dpr-2 screen, with the residual blur pass
/// switchable. The rig for the blur-knee mechanism arm.
///
/// `regular` rather than the identity, because the identity has no sigma and the
/// pass under test would do nothing at any divisor — the arm would pass without
/// the mechanism it is about existing.
Widget _pinned(int divisor, {required ProxyBlurPass blurPass, Key? hostKey}) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        resolution: ProxyResolution.divisor(divisor),
        blurPass: blurPass,
        child: const _Scene(surface: true),
      ),
    ),
  ),
);

RenderRepaintBoundary _boundary() => _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

/// The frame that was actually painted.
///
/// `layer.toImageSync`, not `RenderRepaintBoundary.toImageSync`, which asserts
/// `!debugNeedsPaint` (`proxy_box.dart:3619`). Under a host the tree is dirty
/// by construction on every frame: the post-frame capture publishes a proxy,
/// which marks every surface for repaint. The layer holds the frame that was
/// painted, which is the frame being compared.
ui.Image _frame({double dpr = 1}) {
  // ignore: invalid_use_of_protected_member
  final layer = _boundary().layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen, pixelRatio: dpr);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int frames = 3,
  double dpr = 1,
  bool host = true,
  Key? hostKey,
  int? maxCaptures,
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
}) async {
  await tester.pumpWidget(
    _mount(child, dpr: dpr, host: host, hostKey: hostKey, maxCaptures: maxCaptures, content: content),
  );
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

/// Mounts, lets the proxy arrive, and reads the frame back.
Future<ui.Image> _shot(WidgetTester tester, Widget child, {bool host = true, double dpr = 1}) async {
  await _pump(tester, child, frames: 4, host: host, dpr: dpr);
  return _frame(dpr: dpr);
}

/// The frame that was painted, as bytes read out on the spot.
///
/// [_compare] does the same thing at the end; this exists so that an arm
/// holding a frame across a later `pumpWidget` compares bytes rather than a
/// `ui.Image` whose raster has not happened yet. Whether `toImageSync` would
/// really drift across a remount was never established here — what actually
/// broke the arm this was written for was the host's *state* surviving the
/// remount — so this is caution and not a repaired defect.
Future<Uint8List> _pixels(WidgetTester tester, ui.Image image) async {
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  return out;
}

_Diff _diff(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var maxDelta = 0;
  var differing = 0;
  var sumDelta = 0;
  for (var i = 0; i < a.length; i += 4) {
    var worst = 0;
    for (var c = 0; c < 4; c++) {
      final int d = (a[i + c] - b[i + c]).abs();
      if (d > worst) {
        worst = d;
      }
    }
    if (worst > 0) {
      differing++;
      sumDelta += worst;
      if (worst > maxDelta) {
        maxDelta = worst;
      }
    }
  }
  return _Diff(maxDelta, differing, a.length ~/ 4, sumDelta);
}

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.total, this.sumDelta);

  final int maxDelta;
  final int differing;
  final int total;

  /// Sum of the per-pixel worst-channel differences.
  ///
  /// Here because a *count* of differing pixels saturates: a blur over a panel
  /// moves every pixel of it by at least a code value at every divisor, so the
  /// count reads 21235 / 21211 / 21240 / 20868 across four divisors whose
  /// kernels differ ninefold. How many pixels moved is the wrong question once
  /// the answer is "all of them"; how far they moved is the right one.
  final int sumDelta;

  double get meanDelta => sumDelta / total;

  @override
  String toString() => '$differing/$total px, worst $maxDelta, mean ${meanDelta.toStringAsFixed(3)}';
}

Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  late _Diff diff;
  await tester.runAsync(() async {
    final ByteData? da = await a.toByteData();
    final ByteData? db = await b.toByteData();
    final Uint8List pa = da!.buffer.asUint8List();
    final Uint8List pb = db!.buffer.asUint8List();
    var maxDelta = 0;
    var differing = 0;
    var sumDelta = 0;
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
        sumDelta += worst;
        if (worst > maxDelta) {
          maxDelta = worst;
        }
      }
    }
    diff = _Diff(maxDelta, differing, pa.length ~/ 4, sumDelta);
  });
  return diff;
}
