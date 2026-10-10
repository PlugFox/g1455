// The pipeline, assembled and run on a real tree.
//
// `flutter test test/proxy_pipeline_test.dart`
//
// Every piece is tested on its own elsewhere; here they run in the same
// frame: the register decides the
// geometry, the policy decides the texel scale, the atlas decides the layout,
// the walk does the drawing and retention keeps all four from being recomputed
// — and the arms below are the questions that only exist once they are joined.
//
// The one that matters most is the **identity**: what a surface would sample,
// read back out of the atlas, has to be what is on the screen at that place. It
// is one number for five mechanisms at once — the register's coordinate space,
// the policy's scale, the atlas's map, the walk's drawing and the recording's
// clip — and the control it cannot do without is an arm that reads the *wrong*
// slot and must fail.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_atlas.dart';
import 'package:g1455/src/proxy/proxy_layer_watch.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart';
import 'package:g1455/src/proxy/proxy_retake.dart';
import 'package:g1455/src/proxy/proxy_retention.dart';

const Size kScreen = Size(400, 800);
final GlobalKey _rootKey = GlobalKey();

void main() {
  // -------------------------------------------------------------------------
  // 1. It runs.
  // -------------------------------------------------------------------------

  testWidgets('the register decides the geometry, and the frame comes back with a map', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    final GlassProxyFrame? frame = _capture(tester, pipeline, ledger);
    expect(frame, isNotNull);
    addTearDown(frame!.dispose);

    // The policy ran: on hardware that charges for area, `regular` at a device
    // pixel ratio of 2 is a quarter — which is where the cost budget assumed it
    // was and where the quality side puts it.
    expect(frame.resolution.resolution, const ProxyResolution.quarter());
    expect(frame.layout.pixelRatio, 0.5);

    // The walk ran and drew the tree rather than a hole.
    expect(frame.log.visited, greaterThan(4));
    expect(frame.log.unhandledLayers, isEmpty);
    expect(frame.log.layersMinted, 0, reason: 'the pass parked a layer in the live tree');

    // And the atlas holds both surfaces, with context around each.
    expect(frame.layout.slots, hasLength(2));
    final List<Rect> surfaces = _rects(ledger);
    for (var i = 0; i < surfaces.length; i++) {
      final AtlasSlot slot = frame.slotFor(i);
      expect(slot.source.left, lessThan(surfaces[i].left));
      expect(slot.source.top, lessThan(surfaces[i].top));
      expect(slot.rect.contains(slot.toAtlas(surfaces[i].topLeft)), isTrue);
    }
    expect(frame.image.width, frame.layout.size.width.ceil());
  });

  testWidgets('the region is asked against the strip the atlas really holds', (
    WidgetTester tester,
  ) async {
    // The damage hold's arithmetic, and the one place it can be checked exactly. The hold
    // asks whether a change reached any slot's `source`, and the answer has to
    // be about what `AtlasLayout.record` really copies: it clips in
    // *destination* space to `slot.rect`, whose size is
    // `ceil(source.size * pixelRatio)`. So the source range that reaches the
    // texture runs up to `1 / pixelRatio` logical pixels past `source.right`.
    // At the divisor the policy picks on a dpr-3 screen that is 2.7 logical
    // pixels — a strip wide enough for a change to hide in and a picture to go
    // stale over, and invisible to anything that compares against `source`.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    final GlassProxyFrame? frame = _capture(tester, pipeline, ledger);
    addTearDown(frame!.dispose);

    final AtlasSlot slot = frame.layout.slots.first;
    final double texel = 1 / frame.layout.pixelRatio;
    Rect at(double x) => Rect.fromLTWH(x, slot.source.top + 1, 0.5, 0.5);

    // Inside the strip: still in the texture, so it must record.
    expect(
      pipeline.capturedAreaTouchedBy(LayerChange.within(at(slot.source.right + texel * 0.5))),
      isTrue,
      reason: 'a change inside the rounding strip was called outside the capture',
    );
    // Well past it: genuinely outside, and the arm that says the slack is a
    // strip rather than a licence to record everything.
    expect(
      pipeline.capturedAreaTouchedBy(LayerChange.within(at(slot.source.right + texel * 4))),
      isFalse,
      reason: 'the slack swallowed a change four texels clear of the slot',
    );
    // And the two refusals, which are the whole of the safe direction.
    expect(pipeline.capturedAreaTouchedBy(LayerChange.everywhere), isTrue);
    expect(pipeline.capturedAreaTouchedBy(LayerChange.none), isFalse);
  });

  testWidgets('one budget, two axes: a capture tells the oracle what it spent', (
    WidgetTester tester,
  ) async {
    // Damage on two axes composes rather than adds, so the divisor and the
    // staleness ceiling are drawing on one allowance. The oracle had a
    // `spentDeltaE` parameter for exactly this and **no caller** — it cannot
    // have one, because what the divisor costs depends on the screen's density
    // and the density arrives with the frame. So the pipeline notes it, here.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.appleMetal,
      damageBudgetDeltaE: 0.70,
    );
    // A budget chosen so the composition is observable: `regular` tolerates two
    // stale frames at 0.675 ΔE, and 0.70 allows that — until the proxy has taken
    // its share of the same allowance. A budget
    // this generous reaches the **eighth** rather than the quarter (0.25
    // texels at dpr 2, 0.374 ΔE as the pipeline reads it), leaving
    // sqrt(0.70² − 0.374²) = 0.592. The
    // conclusion is the one this arm is about — one stale
    // frame costs 0.443 and fits, two cost 0.675 and do not — which is the point
    // of writing the budget rather than the divisor into the fixture.
    final oracle = RetakeOracle(finish: 'regularDark', budgetDeltaE: 0.70);
    expect(oracle.spentDeltaE, 0);
    expect(oracle.ceiling, 2);

    final ({GlassProxyFrame? frame, RetakeReason reason}) first = pipeline.captureIfNeeded(
      _root(),
      _rects(ledger),
      devicePixelRatio: 2,
      oracle: oracle,
    );
    addTearDown(pipeline.dispose);
    expect(first.reason, RetakeReason.first);
    expect(first.frame!.resolution.resolution, const ProxyResolution.divisor(8));
    expect(oracle.spentDeltaE, closeTo(0.374, 0.001));
    expect(
      oracle.ceiling,
      1,
      reason: 'the ceiling still spends the whole budget the divisor already drew on',
    );

    // The negative control in the same arm: a finish the divisor cannot shrink
    // spends nothing, and the ceiling is the one the budget alone gives. Without
    // it "the ceiling fell" is equally consistent with a ceiling that fell for
    // any reason at all.
    //
    // Not `clear`: at a budget of 0.70 the policy buys `clear` the first rung
    // for 0.646 ΔE, so that arm would spend almost the whole budget and the
    // control would be a second copy of the arm it controls. `identity` is
    // ungraded, so its refusal comes from the absent table rather than from a
    // ceiling the policy might move.
    final untouched = GlassProxyPipeline(
      finishSigmaLogical: 0,
      finish: 'identity',
      hardware: GlassHardware.appleMetal,
      damageBudgetDeltaE: 0.70,
    );
    addTearDown(untouched.dispose);
    final control = RetakeOracle(finish: 'regularDark', budgetDeltaE: 0.70);
    untouched.captureIfNeeded(_root(), _rects(ledger), devicePixelRatio: 2, oracle: control);
    expect(control.spentDeltaE, 0);
    expect(control.ceiling, 2);
  });

  testWidgets('no surfaces is no frame', (WidgetTester tester) async {
    final ledger = GlassLedger();
    await _mount(tester, ledger, const SizedBox.expand());
    final pipeline = GlassProxyPipeline(finishSigmaLogical: 2.6);
    expect(_capture(tester, pipeline, ledger), isNull);
  });

  // -------------------------------------------------------------------------
  // 2. The identity: the proxy is the screen.
  // -------------------------------------------------------------------------

  testWidgets('what a surface samples is what is on the screen there', (
    WidgetTester tester,
  ) async {
    // At full resolution, so the comparison is a comparison of content and not
    // of a resampling filter — the divisor's own cost in pixels is measured
    // elsewhere, with an instrument built for it.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      // Pinned to 1:1 by the host, because no hardware family gets full
      // resolution from the policy. The arm wants it for its own reason and
      // says so instead of borrowing a refusal.
      hardware: GlassHardware.unmeasured,
      pinnedResolution: const ProxyResolution.full(),
      // And unblurred, because this arm is about the *map*. The finish's blur
      // is measured elsewhere, with an instrument built for it; here it
      // would only stand between the comparison and the thing compared.
      blurPass: ProxyBlurPass.none,
    );
    final GlassProxyFrame frame = _capture(tester, pipeline, ledger)!;
    addTearDown(frame.dispose);
    // Texels per *logical* pixel, which at a device pixel ratio of 2 and a
    // divisor of 1 is 2 — the proxy is recorded at the screen's own density.
    expect(frame.layout.pixelRatio, 2.0);

    final List<Rect> surfaces = _rects(ledger);
    final Uint8List atlas = await _bytes(tester, frame.image);
    for (var i = 0; i < surfaces.length; i++) {
      final AtlasSlot slot = frame.slotFor(i);
      final ({int compared, int differing, int worst}) diff = await _compareSlot(
        tester,
        atlas: atlas,
        atlasWidth: frame.image.width,
        slot: slot,
        region: surfaces[i],
      );
      expect(
        diff.compared,
        greaterThan(1000),
        reason: 'surface $i: the comparison skipped every cell, so it checked nothing',
      );
      expect(
        diff.worst,
        lessThanOrEqualTo(1),
        reason: 'surface $i: the proxy is not the screen — ${diff.differing} px, worst ${diff.worst}',
      );
    }

    // The control, and the first version of it was worthless: reading surface 0
    // through surface 1's slot sends every sample off the texture, so the loop
    // skipped all of them and reported a difference of zero — a wrong map
    // passing because it was wrong enough to land nowhere. The control that
    // works is a map wrong by *four logical pixels*, which stays inside the
    // slot and has to miss. The guard that would have caught the first version
    // is in `_compareSlot` itself: it now says how many cells it compared, and
    // every arm asserts that number.
    final ({int compared, int differing, int worst}) shifted = await _compareSlot(
      tester,
      atlas: atlas,
      atlasWidth: frame.image.width,
      slot: frame.slotFor(0),
      region: surfaces[0],
      shift: const Offset(4, 0),
    );
    expect(shifted.compared, greaterThan(1000), reason: 'the control looked at nothing');
    expect(shifted.worst, greaterThan(8), reason: 'a map off by four pixels matched anyway');
  });

  // -------------------------------------------------------------------------
  // 3. Frame to frame.
  // -------------------------------------------------------------------------

  testWidgets('a surface that moves keeps its slot; one that grows does not', (
    WidgetTester tester,
  ) async {
    // The property retention exists for, and the reason it is worth having: a
    // repack moves every slot, and a moved slot invalidates a shader's uniforms
    // and its texels. A panel sliding across the screen must not do that — the
    // map is `source.topLeft -> rect.topLeft`, so a translation is free by
    // construction.
    final ledger = GlassLedger();
    final size = ValueNotifier<Size>(const Size(160, 90));
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(size.dispose);
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _movingPanel(size, offset));

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    final GlassProxyFrame first = _capture(tester, pipeline, ledger)!;
    expect(first.retention, RetentionOutcome.first);
    final Rect slotRect = first.slotFor(0).rect;
    first.dispose();

    offset.value = const Offset(180, 300);
    await tester.pump();
    final GlassProxyFrame moved = _capture(tester, pipeline, ledger)!;
    expect(moved.retention, RetentionOutcome.kept, reason: 'moving a panel repacked the atlas');
    expect(moved.slotFor(0).rect, slotRect);
    expect(
      moved.slotFor(0).source.topLeft,
      isNot(first.slotFor(0).source.topLeft),
      reason: 'the slot was kept and its source did not follow the panel',
    );
    moved.dispose();

    size.value = const Size(300, 200);
    await tester.pump();
    final GlassProxyFrame grew = _capture(tester, pipeline, ledger)!;
    expect(grew.retention, RetentionOutcome.grew);
    grew.dispose();
    expect(pipeline.repacks, 2, reason: 'the pipeline repacked on a frame that did not need it');
  });

  testWidgets('a change of resolution rebuilds the retained layout rather than keeping it', (
    WidgetTester tester,
  ) async {
    // The integration hazard the assembly created: the retained atlas holds its
    // pixel ratio as a constant, so a policy that changes its mind — a different
    // finish, a different screen, a host that declares its hardware late — would
    // otherwise be handed slots sized for a texel that no longer exists.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    // One pipeline, two screens — a window dragged to a display of another
    // density, which is the case that actually happens.
    final GlassProxyFrame dense = pipeline.capture(
      _root(),
      _rects(ledger),
      devicePixelRatio: 2,
    )!;
    final GlassProxyFrame coarse = pipeline.capture(
      _root(),
      _rects(ledger),
      devicePixelRatio: 1,
    )!;
    expect(dense.layout.pixelRatio, 0.5, reason: 'dpr 2 at a quarter is half a texel per px');
    expect(
      coarse.layout.pixelRatio,
      0.5,
      reason: 'dpr 1 keeps only a half — the policy refuses a quarter on a coarse screen',
    );
    // Same texel scale by coincidence, and the atlas is still the same size —
    // which is why the arm that matters is the one below: the *sources* have to
    // have been recomputed rather than re-pointed at slots sized for a texel
    // that no longer exists.
    expect(coarse.layout.slots.first.rect.size, dense.layout.slots.first.rect.size);
    final int denseWidth = dense.image.width;
    dense.dispose();
    coarse.dispose();

    // The negative half, and it is dpr **4** that provides it: the
    // policy reaches the eighth there and lands back on 0.5 texels per logical
    // pixel, which is the working point dpr 2 settled on at a quarter. Two
    // densities, two divisors, one scale — the policy's claim seen from inside the
    // assembled pipeline rather than from the chooser's unit test.
    final GlassProxyFrame same = pipeline.capture(
      _root(),
      _rects(ledger),
      devicePixelRatio: 4,
    )!;
    expect(same.layout.pixelRatio, 0.5);
    expect(same.image.width, denseWidth, reason: 'same texel scale, same atlas');
    same.dispose();

    // And the density that does change the scale: an eighth of three is 0.375,
    // which is on no other row of this arm.
    final GlassProxyFrame third = pipeline.capture(
      _root(),
      _rects(ledger),
      devicePixelRatio: 3,
    )!;
    expect(third.layout.pixelRatio, closeTo(0.375, 1e-9));
    expect(
      third.retention,
      RetentionOutcome.first,
      reason: 'the retained layout survived a change of scale, so its slots are the wrong size',
    );
    expect(third.image.width, isNot(denseWidth));
    third.dispose();
  });

  // -------------------------------------------------------------------------
  // 4. What the assembly refuses.
  // -------------------------------------------------------------------------

  testWidgets('the roles reach the pass, and a hidden subtree is not in the proxy', (
    WidgetTester tester,
  ) async {
    // The role declarations running inside the assembled pipeline rather
    // than in a bare walk: the pass has to see the marker, and what it drew has
    // to differ from what it draws without it.
    final ledger = GlassLedger();
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.appleMetal,
    );

    await _mount(tester, ledger, _panelOver(const ColoredBox(color: Color(0xFFCC2200))));
    final GlassProxyFrame shown = _capture(tester, pipeline, ledger)!;
    final Uint8List withMark = await _bytes(tester, shown.image);
    expect(shown.log.proxyRoles[GlassProxyRole.hidden], isNull);

    await _mount(
      tester,
      ledger,
      _panelOver(
        const GlassProxy.hidden(child: ColoredBox(color: Color(0xFFCC2200))),
      ),
    );
    final GlassProxyFrame hidden = _capture(tester, pipeline, ledger)!;
    final Uint8List withoutMark = await _bytes(tester, hidden.image);
    expect(hidden.log.proxyRoles[GlassProxyRole.hidden], 1, reason: 'the pass never saw the marker');
    expect(hidden.image.width, shown.image.width);
    expect(
      _worst(withMark, withoutMark),
      greaterThan(8),
      reason: 'the hidden subtree is still in the proxy',
    );
    shown.dispose();
    hidden.dispose();
  });

  // -------------------------------------------------------------------------
  // 7. A pinned divisor, which is how a divisor the policy would not pick gets measured.
  // -------------------------------------------------------------------------

  testWidgets('a pinned divisor reaches the texels, not just the report', (
    WidgetTester tester,
  ) async {
    // The arm that matters, and the reason it is here rather than beside the
    // policy's own unit tests: a pin that is accepted, recorded in
    // `ProxyResolutionChoice` and then *ignored* by the recorder would agree
    // with every headless assertion about the choice — including the report's
    // own `glass_proxy_divisor`, which reads the choice. What settles it is the
    // atlas's own pixel ratio and the size of the image that came back, because
    // those are downstream of the recording rather than of the decision.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      // A divisor the chooser never returns on this screen: at dpr 2 `regular`
      // fits inside the budget all the way to a quarter, on every family
      // including `unmeasured`. So an ignored pin reads the chooser's
      // 0.5 texels per logical pixel and a respected one reads 1.0: the
      // separation comes from pinning a rung the quality walk skips over.
      hardware: GlassHardware.unmeasured,
      pinnedResolution: const ProxyResolution.half(),
    );
    final GlassProxyFrame frame = _capture(tester, pipeline, ledger)!;
    addTearDown(frame.dispose);

    expect(frame.resolution.resolution, const ProxyResolution.half());
    expect(frame.resolution.reason, ProxyDivisorReason.pinnedByHost);
    expect(frame.layout.pixelRatio, 1.0, reason: 'dpr 2 over a divisor of 2');
    expect(frame.image.width, frame.layout.size.width.ceil());

    // The pair. Same tree, same finish, same hardware, no pin — and the chooser
    // returns the quarter the quality budget allows. Two images of different
    // sizes off one screen is what proves the pin moved texels, and the pinned
    // one is the *larger* now: a pin can go either way from the choice.
    final unpinned = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.unmeasured,
    );
    final GlassProxyFrame plain = _capture(tester, unpinned, ledger)!;
    addTearDown(plain.dispose);
    expect(plain.resolution.resolution, const ProxyResolution.quarter());
    expect(plain.resolution.reason, isNot(ProxyDivisorReason.pinnedByHost));
    expect(plain.layout.pixelRatio, 0.5);
    expect(plain.image.width, lessThan(frame.image.width));
  });

  // -------------------------------------------------------------------------
  // 8. The blur pass has two spellings, and they have to be one picture.
  // -------------------------------------------------------------------------

  testWidgets('the folded blur draws the split blur, and takes one snapshot instead of two', (
    WidgetTester tester,
  ) async {
    // The two spellings agree on a single picture; this is the same
    // comparison on the route, where the atlas is packed, the slots are clipped
    // and the sigma comes from the divisor rather than from a table. Both
    // halves are needed: the pixels say the fold is the same material, and the
    // snapshot count says it is a different amount of work. Neither implies the
    // other, and the second is the only thing a device report can see.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());

    final Map<ProxyBlurPass, GlassProxyFrame> frames = <ProxyBlurPass, GlassProxyFrame>{};
    final Map<ProxyBlurPass, int> snapshots = <ProxyBlurPass, int>{};
    for (final ProxyBlurPass pass in ProxyBlurPass.values) {
      final pipeline = GlassProxyPipeline(
        finishSigmaLogical: 2.6,
        hardware: GlassHardware.appleMetal,
        pinnedResolution: const ProxyResolution.quarter(),
        blurPass: pass,
      );
      frames[pass] = _capture(tester, pipeline, ledger)!;
      snapshots[pass] = pipeline.snapshots;
      addTearDown(frames[pass]!.dispose);
    }

    expect(snapshots[ProxyBlurPass.split], 2);
    expect(snapshots[ProxyBlurPass.folded], 1);
    // Not one because the pass is folded but because there is no pass at all,
    // which is a different reason for the same number — the pixels below are
    // what tell them apart.
    expect(snapshots[ProxyBlurPass.none], 1);

    final Uint8List split = await _bytes(tester, frames[ProxyBlurPass.split]!.image);
    final Uint8List folded = await _bytes(tester, frames[ProxyBlurPass.folded]!.image);
    final Uint8List bare = await _bytes(tester, frames[ProxyBlurPass.none]!.image);
    expect(split, hasLength(folded.length));
    expect(split, hasLength(bare.length));

    // One code value, which is the round trip through eight bits that the split
    // route takes between its two snapshots and the fold does not.
    expect(
      _worst(split, folded),
      lessThanOrEqualTo(1),
      reason: 'the fold is a different material, not a cheaper spelling',
    );
    // The control, and it is the whole arm: a comparison of two atlases that
    // were never blurred agrees perfectly and says nothing. The unblurred one
    // has to be far away from both.
    expect(_worst(split, bare), greaterThan(8));
    expect(_worst(folded, bare), greaterThan(8));
  });

  // -------------------------------------------------------------------------
  // The texture ceiling.
  // -------------------------------------------------------------------------

  testWidgets('an atlas over the texture limit is recorded coarser, never silently rescaled', (
    WidgetTester tester,
  ) async {
    // The defect this exists for is not ours and is not visible from Dart.
    // `Picture.toImageSync` on Impeller scales an oversized snapshot down to
    // fit the GPU and reports the size that was asked for
    // (`snapshot_controller_impeller.cc:32-50`, `GetSize()` at
    // `display_list_deferred_image_gpu_impeller.cc:88`), so the atlas the
    // shader is handed a map into would not be the atlas it samples: every
    // surface shows the wrong part of the screen, and nothing anywhere returns
    // an error. The only lever the package has is the texel scale.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());

    final generous = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
    );
    final GlassProxyFrame wide = _capture(tester, generous, ledger)!;
    addTearDown(wide.dispose);
    expect(generous.ceilingDeepenings, 0, reason: 'the ceiling fired on an ordinary screen');
    expect(wide.resolution.resolution, const ProxyResolution.quarter());

    // The control: the arm below is only a test of the ceiling if the layout it
    // is given really is over it.
    final int tight = (wide.layout.size.longestSide / 2).floor();
    expect(wide.layout.fitsTexture(tight), isFalse);

    final pinched = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
      maxTextureSide: tight,
    );
    final GlassProxyFrame frame = _capture(tester, pinched, ledger)!;
    addTearDown(frame.dispose);

    expect(frame.resolution.reason, ProxyDivisorReason.textureCeiling);
    expect(
      frame.resolution.resolution.divisor,
      greaterThan(wide.resolution.resolution.divisor),
      reason: 'the reason says the ceiling moved the divisor and the divisor did not move',
    );
    expect(frame.layout.fitsTexture(tight), isTrue);
    expect(frame.image.width, lessThanOrEqualTo(tight));
    expect(frame.image.height, lessThanOrEqualTo(tight));
    expect(pinched.ceilingDeepenings, 1);
    expect(pinched.ceilingSteps, greaterThan(0));
    expect(pinched.ceilingRefusals, 0);
    expect(pinched.ceilingOverruns, 0, reason: 'the search passed a layout the pack then failed');

    // What it cost is reported rather than hidden, and it is the damage at the
    // divisor that was forced — which may be worse than the budget allows,
    // because the budget is not what decided this.
    expect(
      frame.resolution.damage?.deltaE,
      anyOf(isNull, greaterThanOrEqualTo(wide.resolution.damage!.deltaE)),
    );
  });

  testWidgets('the ceiling holds no state: the frame after a big one is not still coarse', (
    WidgetTester tester,
  ) async {
    // The alternative design was to remember the deepened divisor so the search
    // could be skipped, and it buys a defect: a sheet that opens and closes
    // would leave the proxy permanently coarser than the budget allows, because
    // nothing would ever ask to go back. Re-derived from the policy every frame
    // instead, which is what makes this arm possible at all.
    final ledger = GlassLedger();
    final size = ValueNotifier<Size>(const Size(300, 200));
    final offset = ValueNotifier<Offset>(const Offset(20, 40));
    addTearDown(size.dispose);
    addTearDown(offset.dispose);
    await _mount(tester, ledger, _movingPanel(size, offset));

    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
      maxTextureSide: 100,
    );
    final GlassProxyFrame big = _capture(tester, pipeline, ledger)!;
    expect(big.resolution.reason, ProxyDivisorReason.textureCeiling);
    expect(big.resolution.resolution.divisor, greaterThan(4));
    big.dispose();

    size.value = const Size(160, 90);
    await tester.pump();
    final GlassProxyFrame small = _capture(tester, pipeline, ledger)!;
    expect(
      small.resolution.resolution.divisor,
      4,
      reason: 'the panel shrank and the proxy stayed at the divisor the ceiling forced',
    );
    expect(small.resolution.reason, isNot(ProxyDivisorReason.textureCeiling));
    small.dispose();
    expect(pipeline.ceilingDeepenings, 1, reason: 'the second frame deepened as well');
  });

  testWidgets('a ceiling nothing fits drops the frame rather than corrupting it', (
    WidgetTester tester,
  ) async {
    // The last resort, and it is loud by construction: every surface shows no
    // glass, which is a bug report, where an oversized atlas shows a plausible
    // refraction of the wrong backdrop, which is not.
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    final pipeline = GlassProxyPipeline(
      finishSigmaLogical: 2.6,
      hardware: GlassHardware.adrenoVulkan,
      maxTextureSide: 4,
    );
    expect(_capture(tester, pipeline, ledger), isNull);
    expect(pipeline.ceilingRefusals, 1);
    expect(pipeline.ceilingDeepenings, 0);
    // And it was the search that refused, not the check behind it. Both can
    // drop this frame, so without this line the arm distinguishes neither —
    // which is what the second counter exists to make visible.
    expect(pipeline.ceilingOverruns, 0);
  });

  testWidgets('the ceiling a host does not name is the one its hardware guarantees', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    await _mount(tester, ledger, _twoPanels());
    for (final GlassHardware hardware in GlassHardware.values) {
      final pipeline = GlassProxyPipeline(finishSigmaLogical: 2.6, hardware: hardware);
      expect(pipeline.maxTextureSide, hardware.maxTextureSide);
      final GlassProxyFrame frame = _capture(tester, pipeline, ledger)!;
      addTearDown(frame.dispose);
      expect(frame.layout.fitsTexture(pipeline.maxTextureSide), isTrue);
      expect(pipeline.ceilingDeepenings, 0);
    }
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

Widget _twoPanels() => Stack(
  children: <Widget>[
    Positioned.fill(child: CustomPaint(painter: _Bars())),
    const Positioned(
      left: 20,
      top: 40,
      width: 160,
      height: 90,
      child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    const Positioned(
      left: 220,
      top: 560,
      width: 140,
      height: 70,
      child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
  ],
);

Widget _panelOver(Widget background) => Stack(
  children: <Widget>[
    Positioned.fill(child: CustomPaint(painter: _Bars())),
    Positioned(left: 0, top: 200, width: 400, height: 200, child: background),
    const Positioned(
      left: 20,
      top: 220,
      width: 160,
      height: 90,
      child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
  ],
);

Widget _movingPanel(ValueListenable<Size> size, ValueListenable<Offset> offset) => Stack(
  children: <Widget>[
    Positioned.fill(child: CustomPaint(painter: _Bars())),
    ValueListenableBuilder<Size>(
      valueListenable: size,
      builder: (BuildContext context, Size s, Widget? child) => ValueListenableBuilder<Offset>(
        valueListenable: offset,
        builder: (BuildContext context, Offset o, Widget? child) => Positioned(
          left: o.dx,
          top: o.dy,
          width: s.width,
          height: s.height,
          child: const GlassSurface(),
        ),
      ),
    ),
  ],
);

/// Content with structure at every scale, so a comparison has signal and a
/// shifted read has somewhere to go wrong.
class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF101820));
    for (var y = 0.0; y < size.height; y += 17) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 8),
        Paint()..color = Color.fromARGB(255, 40 + (y.toInt() % 200), 90, 200 - (y.toInt() % 150)),
      );
    }
    for (var x = 0.0; x < size.width; x += 23) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 5, size.height),
        Paint()..color = const Color(0x66FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

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

List<Rect> _rects(GlassLedger ledger) => ledger.surfaces.map((GlassSurfaceRecord r) => r.rect).toList();

RenderRepaintBoundary _root() => _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

GlassProxyFrame? _capture(WidgetTester tester, GlassProxyPipeline pipeline, GlassLedger ledger) =>
    pipeline.capture(_root(), _rects(ledger), devicePixelRatio: 2);

Future<Uint8List> _bytes(WidgetTester tester, ui.Image image) async {
  late Uint8List out;
  await tester.runAsync(() async {
    out = (await image.toByteData())!.buffer.asUint8List();
  });
  return out;
}

int _worst(Uint8List a, Uint8List b) {
  var worst = 0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    final int d = (a[i] - b[i]).abs();
    if (d > worst) {
      worst = d;
    }
  }
  return worst;
}

/// Compares [region] of the screen against the same region read out of [slot].
///
/// The screen side is the engine's own capture of the live layer — the stock
/// route, which is what the walk is standing in for.
Future<({int compared, int differing, int worst})> _compareSlot(
  WidgetTester tester, {
  required Uint8List atlas,
  required int atlasWidth,
  required AtlasSlot slot,
  required Rect region,
  Offset shift = Offset.zero,
}) async {
  // ignore: invalid_use_of_protected_member
  final layer = _root().layer! as OffsetLayer;
  final ui.Image screen = layer.toImageSync(region, pixelRatio: slot.pixelRatio);
  final Uint8List want = await _bytes(tester, screen);
  var compared = 0;
  var differing = 0;
  var worst = 0;
  for (var y = 0; y < screen.height; y++) {
    for (var x = 0; x < screen.width; x++) {
      // The slot's own texel for this screen pixel, from the map a shader gets.
      final Offset texel = slot.toAtlas(
        Offset(region.left + x / slot.pixelRatio, region.top + y / slot.pixelRatio) + shift,
      );
      final int ai = ((texel.dy.floor() * atlasWidth) + texel.dx.floor()) * 4;
      final int wi = ((y * screen.width) + x) * 4;
      if (ai < 0 || ai + 3 >= atlas.length) {
        continue;
      }
      compared++;
      var cell = 0;
      for (var c = 0; c < 3; c++) {
        final int d = (atlas[ai + c] - want[wi + c]).abs();
        if (d > cell) {
          cell = d;
        }
      }
      if (cell > 0) {
        differing++;
        if (cell > worst) {
          worst = cell;
        }
      }
    }
  }
  screen.dispose();
  return (compared: compared, differing: differing, worst: worst);
}
