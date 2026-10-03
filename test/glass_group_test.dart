// Phase B, step 1 — the blend group: N surfaces drawn as one silhouette.
//
// `flutter test test/glass/glass_group_test.dart`
//
// Four things have to hold, and each of them is a different way of being wrong:
//
//  1. **A group of one is the lone surface.** Two binaries draw glass in this
//     package now, and a second one that drifted would ship optics the M13
//     ladder never graded. So the fused program at `uCount = 1` is required to
//     reproduce `glass_surface.frag` byte for byte — not "closely", because
//     every expression in the two is meant to be the same expression and a
//     tolerance would hide the day one of them stops being.
//  2. **Shapes that do not touch do not fuse.** M3's warning about `smin` was
//     that a bad distance invents bridges between shapes that are far apart —
//     up to 81 px of them — and it is the failure this arm exists to catch: a
//     group of two far-apart surfaces must be the same frame as two ungrouped
//     ones.
//  3. **Shapes that do touch fuse, and at the declared distance.** The knob is
//     `spacing`, and it is not a mood: the bridge appears when the edge-to-edge
//     gap falls below it, which is arithmetic with a known answer, so the arm
//     sweeps the gap and reads where the picture changes.
//  4. **A blend group shares one atlas slot.** The one-way invariant of SS4.4.
//     Counted rather than asserted after the fact, and the counter is on the
//     mechanism (`splitSlots`) so that a caller who packs without the grouping
//     is caught by a number rather than by somebody looking at a screenshot.
//  5. **The quad is the members, not the box.** Where a group is laid out is a
//     fact about the page; what it shades must not be. The arm is the same
//     members inside a full-screen group and inside one shrunk to hug them,
//     and it exists because the first pair of arms put both halves in a
//     full-screen group and neither was wrong relative to the other.
//  6. **Skipping a far shape is bit-identical.** The fold is 94% of the
//     fragment at twelve shapes (D169), and a shape at least `k` farther than
//     the field so far cannot move it. "Cannot" is arithmetic — `h` is exactly
//     zero and `mix(x, y, 0)` is exactly `x` — so the arm renders the same
//     fragment twice with the branch compiled into both and the threshold out
//     of reach in one, and a threshold four times too small is the control
//     that says the branch is reached at all.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_atlas.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart';
import 'package:g1455/src/proxy/proxy_retention.dart';

// The arms print the measured bridge widths; a person reads them once.
// ignore_for_file: avoid_print

const Size kScreen = Size(420, 220);
const double kRadius = 20;
const Size kPanel = Size(90, 90);
const double kTop = 60;

/// The floats the group shader's uniform block holds, counted by hand off the
/// declaration order in `shaders/glass_group.frag`:
///
///     vec2 + vec2 + float + vec2 + vec2 + float + float  = 11
///     vec4[12] + float[12]                               = 60
///     4 floats of optics + vec4 tint + float + vec4 + float = 14
///     uCullK                                             = 1
///     uRimMix (D203)                                     = 1
///
/// Checked rather than trusted, because it is the one constant in `lib/` that
/// nothing else would notice going wrong: a shifted uniform block draws a
/// plausible picture out of the wrong numbers.
const int kGroupUniformFloats = 87;

/// The lone surface's block, probed against the program in
/// `glass_ripple_test.dart`. Here it bounds the hand-written probes below: a
/// probe that stops short leaves the tail to the allocator, which is zero on
/// macOS and not on Linux.
const int kSurfaceUniformFloats = 34;

void main() {
  // -------------------------------------------------------------------------
  // 0. The uniform block is where the writer thinks it is.
  // -------------------------------------------------------------------------

  testWidgets('the group program takes exactly the floats the writer sets', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        kGlassGroupShaderAsset,
      );
      final ui.FragmentShader shader = program.fragmentShader();
      var count = 0;
      while (count < 4096) {
        try {
          shader.setFloat(count, 0);
        } on Object {
          break;
        }
        count++;
      }
      shader.dispose();
      expect(
        count,
        kGroupUniformFloats,
        reason: 'the uniform block moved; every index in RenderGlassGroup is now off',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 1. A group of one is the lone surface, byte for byte.
  // -------------------------------------------------------------------------

  testWidgets('the two programs agree at uCount = 1, uniform for uniform', (
    WidgetTester tester,
  ) async {
    // The same question as the arm below and asked one layer down, because the
    // two answers separate. When the end-to-end arm first failed — 7804 pixels,
    // worst 39 — this one passed at zero, and that is what said the shader was
    // innocent: the walk was drawing the group's own glass into the proxy, so
    // the group was sampling last frame's output. Without an arm that skips the
    // plumbing, "the group draws something else" and "the group is fed
    // something else" look identical.
    late ui.Image backdrop;
    late ui.Image a;
    late ui.Image b;
    await tester.runAsync(() async {
      backdrop = _plainBackdrop();
      final ui.FragmentProgram single = await ui.FragmentProgram.fromAsset(kGlassShaderAsset);
      final ui.FragmentProgram fused = await ui.FragmentProgram.fromAsset(kGlassGroupShaderAsset);
      a = _renderSingle(single, backdrop);
      b = _renderFused(fused, backdrop);
    });
    final _Diff diff = await _compare(tester, a, b);
    print('programs at uCount = 1: $diff');
    expect(diff.differing, 0, reason: 'the fused program is not the single one at N = 1 — $diff');
    for (final ui.Image image in <ui.Image>[backdrop, a, b]) {
      image.dispose();
    }
  });

  testWidgets('a group of one draws what the surface alone draws', (WidgetTester tester) async {
    final ui.Image alone = await _shot(tester, const <_Panel>[_Panel(left: 60)]);
    final ui.Image grouped = await _shot(
      tester,
      const <_Panel>[_Panel(left: 60)],
      spacing: 0,
    );
    final _Diff diff = await _compare(tester, alone, grouped);
    print('group of one vs lone surface: $diff');
    expect(
      diff.differing,
      0,
      reason: 'the two programs disagree at uCount = 1 — $diff',
    );

    // The control, or the arm above is "two pictures of the same thing agree".
    // The same comparison against a panel four pixels along must fail.
    final ui.Image moved = await _shot(tester, const <_Panel>[_Panel(left: 64)]);
    expect((await _compare(tester, alone, moved)).differing, greaterThan(100));
    for (final ui.Image image in <ui.Image>[alone, grouped, moved]) {
      image.dispose();
    }
  });

  // -------------------------------------------------------------------------
  // 2. Shapes that do not touch do not fuse.
  // -------------------------------------------------------------------------

  testWidgets('two surfaces far apart are the same grouped and ungrouped', (
    WidgetTester tester,
  ) async {
    // 150 logical pixels of clear air between the panels, and a spacing of 8.
    // `smin` reaches `k = 16`, so the fields never meet; an estimator that
    // understated distance far from its own contour would put a bridge here,
    // which is exactly what M3 measured the single-Newton form doing.
    const panels = <_Panel>[_Panel(left: 30), _Panel(left: 270)];
    final ui.Image apart = await _shot(tester, panels);
    final ui.Image grouped = await _shot(tester, panels, spacing: 8);
    final _Diff diff = await _compare(tester, apart, grouped);
    print('two far surfaces, grouped vs not: $diff');
    expect(
      diff.differing,
      0,
      reason: 'the group invented a bridge, or moved the atlas under the samples — $diff',
    );
    apart.dispose();
    grouped.dispose();
  });

  // -------------------------------------------------------------------------
  // 3. Shapes that touch fuse, at the declared distance.
  // -------------------------------------------------------------------------

  testWidgets('the bridge appears at the declared distance and is the width the field says', (
    WidgetTester tester,
  ) async {
    // One gap, four spacings, and a closed form for each. The quantity that
    // moves is the *declaration* — the panels never budge — so the table is
    // keyed by what was turned rather than by what happened to change with it.
    //
    // At the midpoint of the gap both fields read the same distance `d`, so the
    // smooth minimum there is `d - k/4` and the silhouette reaches exactly as
    // far as `d = k/4`. With `k = 2 * spacing` that is `d = spacing / 2`: a
    // bridge appears when the edge-to-edge gap falls below the spacing, which is
    // what the knob is documented to mean.
    const double gap = 24;
    const panels = <_Panel>[_Panel(left: 120), _Panel(left: 120 + kPanelWidth + gap)];
    const double midpoint = 120 + kPanelWidth + gap / 2;

    final measured = <double, double>{};
    final predicted = <double, double>{};
    for (final double spacing in <double>[0, gap / 2, gap * 1.5, gap * 2]) {
      final ui.Image shot = await _shot(tester, panels, spacing: spacing);
      measured[spacing] = await _bridgeHalfWidth(tester, shot, midpoint.round());
      predicted[spacing] = _predictedHalfWidth(gap: gap, spacing: spacing);
      shot.dispose();
    }
    print('bridge half-width, measured $measured against predicted $predicted');

    expect(
      measured[0],
      0,
      reason: 'spacing 0 fused two panels $gap px apart; the union is not a union',
    );
    expect(
      measured[gap / 2],
      0,
      reason: 'a spacing below the gap fused them anyway — the factor of two is wrong',
    );
    for (final double spacing in <double>[gap * 1.5, gap * 2]) {
      expect(
        measured[spacing]!,
        closeTo(predicted[spacing]!, 1.5),
        reason:
            'at spacing $spacing the bridge is ${measured[spacing]} px where the field '
            'puts it at ${predicted[spacing]}',
      );
    }
    // The two widths must differ, or the arm is reading a constant and the
    // agreement above is about the panels rather than about the blend.
    expect(
      (measured[gap * 2]! - measured[gap * 1.5]!).abs(),
      greaterThan(5),
      reason: 'the bridge did not widen with the spacing',
    );
  });

  // -------------------------------------------------------------------------
  // 4. The one-way invariant.
  // -------------------------------------------------------------------------

  testWidgets('a blend group shares one atlas slot', (WidgetTester tester) async {
    // Two panels far enough apart that the packer would keep them in separate
    // slots on price — and it does, when they are not declared a group. That is
    // the control: without it, "one slot" would be a statement about the merge
    // criterion rather than about the invariant.
    const panels = <_Panel>[_Panel(left: 20), _Panel(left: 300)];

    await _mount(tester, panels);
    final int loose = _slotsOf(tester).length;

    await _mount(tester, panels, spacing: 0);
    final List<AtlasSlot> tight = _slotsOf(tester);
    final RenderGlassGroup group = tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup));
    print('slots: $loose ungrouped, ${tight.length} grouped; splitSlots ${group.splitSlots}');

    expect(loose, 2, reason: 'the packer merged them anyway, so this arm proves nothing');
    expect(tight.length, 1, reason: 'the blend group did not force a shared slot');
    expect(tight.single.members.length, 2);
    expect(group.splitSlots, 0);
    expect(group.fusedPaints, greaterThan(0), reason: 'the group never drew');
  });

  testWidgets('members of a fused group draw no glass of their own', (WidgetTester tester) async {
    await _mount(tester, const <_Panel>[_Panel(left: 60), _Panel(left: 200)], spacing: 12);
    final List<RenderGlassSurface> surfaces = tester
        .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
        .toList();
    expect(surfaces.length, 2);
    for (final RenderGlassSurface surface in surfaces) {
      expect(surface.paintsDeferredToGroup, greaterThan(0));
      expect(
        surface.paintsWithProxy,
        0,
        reason: 'a member drew its own glass under the group\'s, so the panel is drawn twice',
      );
    }
  });

  // -------------------------------------------------------------------------
  // 4b. The quad is the members' union, not the box the group was laid out in.
  // -------------------------------------------------------------------------

  testWidgets('where the group is laid out does not change what it draws', (
    WidgetTester tester,
  ) async {
    // A group is laid out by whatever holds its children, so the same set of
    // panels can arrive inside a box that covers the screen or inside one that
    // hugs them. The picture must not know the difference — and the *price*
    // must, which is the point: everything outside the members' union has
    // coverage exactly zero and is pure shading of nothing.
    const panels = <_Panel>[_Panel(left: 60), _Panel(left: 200)];
    late _Diff diff;
    late Rect looseQuad;
    late Rect tightQuad;
    late ui.Image loose;
    late ui.Image close;
    await tester.runAsync(() async {
      loose = await _shot(tester, panels, spacing: 12);
      looseQuad = _groupOf(tester).lastFusedQuad!;
      close = await _shot(tester, panels, spacing: 12, tight: true);
      tightQuad = _groupOf(tester).lastFusedQuad!;
    });
    diff = await _compare(tester, loose, close);
    print(
      'full-screen group vs tight group: $diff; quad ${looseQuad.size} vs '
      '${tightQuad.size}',
    );
    expect(diff.differing, 0, reason: 'the group\'s own box reached the picture');
    expect(diff.total, kScreen.width * kScreen.height);
    // And the quad itself is the same in both, which is what makes the arm
    // above a statement about the mechanism rather than about two screens that
    // happen to agree.
    expect(tightQuad.size, looseQuad.size);
  });

  testWidgets('the quad is the union of the members plus the reach of the bridges', (
    WidgetTester tester,
  ) async {
    const panels = <_Panel>[_Panel(left: 60), _Panel(left: 200)];
    const double spacing = 12;
    // The bound this arm is about is the *one* quad's, so it is priced with the
    // split off — which is where it ships on Metal (D190) and not on Adreno
    // (D192), so it is named: this arm has to say the same thing on every host.
    final bool wasSplit = debugGlassFusedSplit;
    debugGlassFusedSplit = false;
    addTearDown(() => debugGlassFusedSplit = wasSplit);
    await _mount(tester, panels, spacing: spacing);
    final RenderGlassGroup group = _groupOf(tester);

    // Written out rather than recomputed from the same expression the code
    // uses: the bound being asserted is `delta(n) * k` with `k = spacing * 2`,
    // and a check that called the implementation would agree with any bound.
    // Two shapes, so the bound is `k / 4` and not `k`: the fold has had one
    // step, and one step can only take `k / 4`.
    const double reach = 0.25 * 2 * spacing + 0.5 / 1 + 1;
    final Rect expected = const Rect.fromLTRB(60, kTop, 290, kTop + 90).inflate(reach);
    print('quad ${group.lastFusedQuad}, expected $expected');

    expect(group.lastFusedQuad, expected);
    expect(group.fusedPaints, greaterThan(0));
    // Two panels of 90x90, every frame the group fused. The denominator is
    // named because these are running totals, not per-frame readings.
    expect(group.fusedShapeArea / group.fusedPaints, 2 * 90.0 * 90.0);
    expect(
      group.fusedQuadArea / group.fusedPaints,
      expected.width * expected.height,
    );
    // The reading the whole change is about: the quad against the screen it
    // would otherwise have been.
    print(
      'dead area ${(1 - group.fusedShapeArea / group.fusedQuadArea) * 100}% of the quad; '
      'the group\'s own box is ${kScreen.width * kScreen.height} px^2',
    );
  });

  testWidgets('skipping a far shape changes no pixel, and the threshold is why', (
    WidgetTester tester,
  ) async {
    // The fold evaluates every declared shape at every fragment, and at twelve
    // shapes that is 94% of the fragment (D169). A shape at least `k` farther
    // than the field so far cannot move the result — `h` is exactly zero, so
    // the fold keeps `d` and `mix(n, ni, 0)` is exactly `n` — so it is skipped.
    // "Exactly" is the claim, and this is the only arm that can see it: the
    // branch is compiled into both renders and only the threshold differs.
    late _Diff same;
    late _Diff wrong;
    await tester.runAsync(() async {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        kGlassGroupShaderAsset,
      );
      final ui.Image backdrop = _plainBackdrop();
      const double blend = 24;
      ui.Image at(double cullK) => _renderFusedShapes(
        program,
        backdrop,
        kLopsided,
        blend: blend,
        cullK: cullK,
      );
      // `k` is what the package passes; 1e9 is out of reach of any distance a
      // probe this size produces, so nothing is ever skipped.
      final ui.Image culled = at(blend);
      final ui.Image whole = at(1e9);
      // And a threshold that skips shapes which *do* contribute, which is what
      // says the branch is reached at all. Without it "no pixel changed" is
      // equally consistent with a cull that never fires.
      final ui.Image early = at(blend * 0.25);
      same = await _bytes(culled, whole);
      wrong = await _bytes(early, whole);
      backdrop.dispose();
    });
    print('cull at k vs no cull: $same; cull at k/4 vs no cull: $wrong');
    expect(same.differing, 0, reason: 'the skip is not exact');
    expect(
      wrong.differing,
      greaterThan(0),
      reason:
          'a threshold four times too small changed nothing, so nothing is ever skipped '
          'and the arm above is vacuous',
    );
  });

  testWidgets('the benchmark switch reaches the shader, and it changes no pixel', (
    WidgetTester tester,
  ) async {
    // `debugGlassFoldCull` is what a run turns off to price the skip. The skip
    // is bit-identical, so the arm that says the switch *worked* cannot be a
    // picture — an axis with no observable trace is not an axis, and an `off`
    // arm that silently culled anyway would report as "the branch is free".
    // So: the distance the draw handed the shader, read off the render object,
    // and the picture beside it.
    const panels = <_Panel>[_Panel(left: 60), _Panel(left: 200)];
    late ui.Image on;
    late ui.Image off;
    late double onDistance;
    late double offDistance;
    await tester.runAsync(() async {
      on = await _shot(tester, panels, spacing: 12);
      onDistance = _groupOf(tester).lastCullDistance;
      debugGlassFoldCull = false;
      off = await _shot(tester, panels, spacing: 12);
      offDistance = _groupOf(tester).lastCullDistance;
    });
    debugGlassFoldCull = true;
    final _Diff diff = await _compare(tester, on, off);
    print('fold cull on -> $onDistance, off -> $offDistance; picture $diff');

    expect(onDistance, 24, reason: 'the shipping draw did not pass k');
    expect(offDistance, greaterThan(1e8), reason: 'the switch never reached the draw');
    expect(diff.differing, 0, reason: 'turning the skip off changed the picture');
  });

  testWidgets('a group split into tiles is the one quad, pixel for pixel', (
    WidgetTester tester,
  ) async {
    // The lever phase B left open: the fused draw covers the *bounding box* of
    // its members grown by the bridges' reach, and on a scattered layout that
    // is the screen. The same bound applied per member is a union of small
    // rectangles instead, and each of them only has to fold the shapes that can
    // reach it. Both halves are meant to be exact, and exact is the only claim
    // worth making: a split that were merely close would ship either a seam
    // down the middle of the glass or a bridge that comes and goes with the
    // layout.
    //
    // Two fixtures, because the two halves fail differently. `kBridged` puts
    // three shapes close enough to fuse, so its tiles touch — that is where a
    // seam would be. `kScattered` puts them far apart, so its tiles carry one
    // shape each — that is where dropping the other two has to be free.
    late _Diff bridged;
    late _Diff scattered;
    late _Diff overlapped;
    late _Diff dropped;
    late List<GlassFusedTile> bridgedTiles;
    late List<GlassFusedTile> scatteredTiles;
    await tester.runAsync(() async {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        kGlassGroupShaderAsset,
      );
      final ui.Image backdrop = _plainBackdrop();

      Future<_Diff> run(
        List<_Shape> shapes,
        double blend, {
        void Function(List<GlassFusedTile>)? keep,
        List<GlassFusedTile> Function(List<GlassFusedTile>)? spoil,
      }) async {
        final List<GlassFusedTile> tiles = _tilesFor(shapes, blend);
        keep?.call(tiles);
        final ui.Image whole = _renderFusedShapes(
          program,
          backdrop,
          shapes,
          blend: blend,
          cullK: blend,
        );
        final ui.Image split = _renderFusedTiled(
          program,
          backdrop,
          shapes,
          blend: blend,
          cullK: blend,
          tiles: spoil == null ? tiles : spoil(tiles),
        );
        final _Diff diff = await _bytes(whole, split);
        whole.dispose();
        split.dispose();
        return diff;
      }

      bridged = await run(kBridged, 40, keep: (List<GlassFusedTile> t) => bridgedTiles = t);
      scattered = await run(kScattered, 8, keep: (List<GlassFusedTile> t) => scatteredTiles = t);

      // Break one: the tiles overlap. The draw is premultiplied and
      // translucent, so a pixel handed to two of them composites twice — the
      // arm above is a statement about the partition and not only about the
      // shader, and without this it would pass just as well for a split that
      // covered everything twice.
      overlapped = await run(
        kBridged,
        40,
        spoil: (List<GlassFusedTile> t) => <GlassFusedTile>[
          for (final GlassFusedTile tile in t) GlassFusedTile(tile.rect.inflate(2), tile.shapes),
        ],
      );
      // Break two: a tile forgets a shape the margin kept. On the scattered
      // fixture every tile carries exactly one shape, so this is a panel that
      // stops being drawn — the arm that says the subsets are read at all.
      dropped = await run(
        kScattered,
        8,
        spoil: (List<GlassFusedTile> t) => <GlassFusedTile>[
          for (final GlassFusedTile tile in t)
            GlassFusedTile(tile.rect, <int>[
              for (final int i in tile.shapes)
                if (i != 1) i,
            ]),
        ],
      );
      backdrop.dispose();
    });

    // The denominator is the one quad the split replaces, at the same reach —
    // not the probe, which is a fixture rather than a screen.
    final double bridgedQuad = _quadArea(kBridged, 40);
    final double scatteredQuad = _quadArea(kScattered, 8);
    for (final (String name, List<GlassFusedTile> tiles, double quad, int count, _Diff diff)
        in <(String, List<GlassFusedTile>, double, int, _Diff)>[
          ('bridged', bridgedTiles, bridgedQuad, kBridged.length, bridged),
          ('scattered', scatteredTiles, scatteredQuad, kScattered.length, scattered),
        ]) {
      final double area = tiles.fold<double>(
        0,
        (double a, GlassFusedTile t) => a + t.rect.width * t.rect.height,
      );
      final double fold = tiles.fold<double>(
        0,
        (double a, GlassFusedTile t) => a + t.rect.width * t.rect.height * t.shapes.length,
      );
      print(
        '$name: ${tiles.length} tiles, shaded x${(area / quad).toStringAsFixed(3)} of the quad, '
        'folded x${(fold / (quad * count)).toStringAsFixed(3)}; picture $diff',
      );
    }
    print('overlapping tiles: $overlapped; a tile missing a shape: $dropped');

    expect(bridged.differing, 0, reason: 'tiles that touch left a seam');
    expect(scattered.differing, 0, reason: 'a tile dropped a shape that mattered');
    expect(
      bridgedTiles.length,
      greaterThan(1),
      reason: 'the bridged fixture came back as one rectangle, so it tests no seam',
    );
    expect(
      scatteredTiles.every((GlassFusedTile t) => t.shapes.length < kScattered.length),
      isTrue,
      reason: 'every tile carried every shape, so the arm above proves nothing about subsets',
    );
    expect(
      overlapped.differing,
      greaterThan(0),
      reason:
          'tiles overlapping by two pixels changed nothing, so the draw is not what '
          'composites and the partition is not what keeps the picture right',
    );
    expect(
      dropped.differing,
      greaterThan(0),
      reason: 'a tile that forgot a shape drew the same picture, so the subsets are not read',
    );
  });

  testWidgets('the split changes no pixel through the render object either', (
    WidgetTester tester,
  ) async {
    // The arm above renders the tiles by hand, which is what lets it break them
    // on purpose. This one goes through `RenderGlassGroup` — the tiling, the
    // subsets, the one shader reused across draws, the antialiasing decision —
    // because that is the code that ships and none of it is exercised by the
    // suite on this host: the tests declare Metal, where the split is off, so without this
    // arm the whole mechanism would be dead code as far as `flutter test` is
    // concerned.
    const panels = <_Panel>[_Panel(left: 40), _Panel(left: 150), _Panel(left: 260)];
    final bool wasSplit = debugGlassFusedSplit;
    addTearDown(() => debugGlassFusedSplit = wasSplit);

    late ui.Image whole;
    late ui.Image split;
    late int wholeDraws;
    late int splitDraws;
    late double wholeArea;
    late double splitArea;
    await tester.runAsync(() async {
      debugGlassFusedSplit = false;
      whole = await _shot(tester, panels, spacing: 10);
      final RenderGlassGroup off = _groupOf(tester);
      wholeDraws = off.fusedDraws;
      wholeArea = off.fusedQuadArea / off.fusedPaints;
      debugGlassFusedSplit = true;
      split = await _shot(tester, panels, spacing: 10);
      final RenderGlassGroup on = _groupOf(tester);
      splitDraws = on.fusedDraws;
      splitArea = on.fusedQuadArea / on.fusedPaints;
      expect(on.fusedTileRefusals, 0);
    });
    final _Diff diff = await _compare(tester, whole, split);
    print(
      'through the render object: $wholeDraws draw over ${wholeArea.round()} px^2 against '
      '$splitDraws over ${splitArea.round()}; picture $diff',
    );

    expect(diff.differing, 0, reason: 'the shipping path drew a different picture when split');
    expect(
      splitDraws,
      greaterThan(wholeDraws),
      reason: 'the flag never reached the paint, so the comparison is one arm against itself',
    );
    expect(
      splitArea,
      lessThan(wholeArea),
      reason: 'the split shaded at least as much as the single quad',
    );
  });

  testWidgets('a group splits by default, whatever hardware the host declares', (
    WidgetTester tester,
  ) async {
    // D194. Both GPUs timed charge for fragments, so the split ships on and
    // reads no declaration. The loop over every declaration is what says the
    // group does not: between D192 and D194 the quad went to `appleMetal`
    // through the host's handle, and a key that came back that way would fail
    // here on one row. The desktop exception D199 added is gone (D200); the
    // platforms are crossed in the arm below.
    const panels = <_Panel>[_Panel(left: 40), _Panel(left: 150), _Panel(left: 260)];
    final bool wasSplit = debugGlassFusedSplit;
    addTearDown(() => debugGlassFusedSplit = wasSplit);
    debugGlassFusedSplit = null;
    expect(debugGlassFusedSplit, isTrue, reason: 'the package ships the split');
    final drawsPerPaint = <GlassHardware, double>{};
    await tester.runAsync(() async {
      for (final GlassHardware hardware in GlassHardware.values) {
        // A different host each time, so a group cannot carry the last
        // declaration over: the tree is torn down between them.
        await tester.pumpWidget(const SizedBox());
        await _shot(tester, panels, spacing: 10, hardware: hardware);
        final RenderGlassGroup group = _groupOf(tester);
        drawsPerPaint[hardware] = group.fusedDraws / group.fusedPaints;
      }
    });
    print('draws per fused paint as shipped: $drawsPerPaint');
    for (final GlassHardware hardware in GlassHardware.values) {
      expect(
        drawsPerPaint[hardware]!,
        greaterThan(1),
        reason: '$hardware drew ${drawsPerPaint[hardware]} rectangles per paint',
      );
    }
  });

  testWidgets('the split on every platform, desktop included, and every tile aliased', (
    WidgetTester tester,
  ) async {
    // D200: D199 keyed the quad to the desktop because a tile there cost three
    // offscreen passes, and it did because the tiles' `isAntiAlias = false`
    // never reached Impeller. Primed, the split is cheaper there too, so the
    // key went. Every platform is crossed with every declaration, because a
    // key that came back through either would fail here on one row; and every
    // tile must be counted aliased, because an antialiased tile is exactly the
    // draw that made the desktop dear.
    const panels = <_Panel>[_Panel(left: 40), _Panel(left: 150), _Panel(left: 260)];
    final bool wasSplit = debugGlassFusedSplit;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      debugGlassFusedSplit = wasSplit;
    });
    debugGlassFusedSplit = null;
    final drawsPerPaint = <String, double>{};
    final aliased = <String, double>{};
    await tester.runAsync(() async {
      for (final TargetPlatform platform in TargetPlatform.values) {
        for (final GlassHardware hardware in GlassHardware.values) {
          debugDefaultTargetPlatformOverride = platform;
          await tester.pumpWidget(const SizedBox());
          await _shot(tester, panels, spacing: 10, hardware: hardware);
          final RenderGlassGroup group = _groupOf(tester);
          final String key = '${platform.name}/${hardware.name}';
          drawsPerPaint[key] = group.fusedDraws / group.fusedPaints;
          aliased[key] = group.fusedDrawsAliased / group.fusedDraws;
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });
    print('draws per fused paint by platform: $drawsPerPaint');
    expect(drawsPerPaint, hasLength(TargetPlatform.values.length * GlassHardware.values.length));
    for (final String key in drawsPerPaint.keys) {
      expect(drawsPerPaint[key], greaterThan(1), reason: '$key lost the split');
      expect(aliased[key], 1, reason: '$key drew an antialiased tile');
    }
    // A named arm still wins, and `null` gives the default back.
    debugGlassFusedSplit = false;
    expect(debugGlassFusedSplit, isFalse);
    debugGlassFusedSplit = null;
    expect(debugGlassFusedSplit, debugGlassFusedSplitDefault);
  });

  testWidgets('a bridge past the members\' boxes samples captured pixels, not a clamped edge', (
    WidgetTester tester,
  ) async {
    // D200's A2 found it on four backends alike: the identity finish over a
    // fused pair differed from the bare backdrop in the rows just outside the
    // panels, by up to 132 code values. The bridge bulges past the members'
    // boxes by up to `delta(n) * k`, and the shared slot was their union grown
    // only by the blur's bleed — zero for the identity — so the shader's clamp
    // to the slot sampled the slot's edge row there instead of the backdrop.
    // The identity is the right probe exactly because it is blind to
    // everything else: whatever it draws must be the backdrop.
    const panels = <_Panel>[_Panel(left: 60), _Panel(left: 180)];
    late final ui.Image bare;
    late final ui.Image fused;
    late final ui.Image apart;
    await tester.runAsync(() async {
      bare = await _shot(tester, const <_Panel>[], finish: GlassFinish.identity);
      apart = await _shot(tester, panels, finish: GlassFinish.identity);
      // Last, so the group and its slot below are the ones that drew it.
      fused = await _shot(tester, panels, spacing: 40, finish: GlassFinish.identity);
    });
    final RenderGlassGroup group = _groupOf(tester);
    expect(group.fusedDraws, greaterThan(0), reason: 'the group never drew');
    final Rect quad = group.lastFusedQuad!;
    // The bridge has to reach past the panels for the arm to test anything:
    // a quad no taller than the panels would pass on the old slot too.
    expect(quad.top, lessThan(kTop - 5), reason: 'the fused quad does not reach past the panels');
    final _Diff unfused = await _compare(tester, bare, apart);
    final _Diff diff = await _compare(tester, bare, fused);
    print('identity against the bare backdrop: apart $unfused, fused $diff');
    expect(unfused.differing, 0, reason: 'the identity is not the identity even without a bridge');
    expect(diff.differing, 0, reason: 'the bridge sampled pixels the proxy never captured');
    final AtlasSlot slot = _slotsOf(tester).single;
    print('quad $quad, slot source ${slot.source}');
    expect(
      slot.source.inflate(0.001).contains(quad.topLeft) && slot.source.inflate(0.001).contains(quad.bottomRight),
      isTrue,
      reason: 'the slot ${slot.source} does not cover the quad $quad the group draws',
    );
    bare.dispose();
    fused.dispose();
    apart.dispose();
  });

  testWidgets('the cull margin is the bound, and a smaller one breaks', (
    WidgetTester tester,
  ) async {
    // What the margin is for, measured rather than asserted. A shape farther
    // than `(1 + 2 * delta(n)) * k` from a tile cannot change a bit inside it;
    // the derivation is in [fusedDrawTiles], and this is the scan that says the
    // number is neither wrong nor decorative — below it the picture moves, at
    // it and above it the picture is the same bits.
    const double blend = 40;
    const margins = <double>[0, 0.5, 1.0, 1.5, 1.78, 2.5];
    final readings = <double, _Diff>{};
    await tester.runAsync(() async {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        kGlassGroupShaderAsset,
      );
      final ui.Image backdrop = _plainBackdrop();
      final ui.Image whole = _renderFusedShapes(
        program,
        backdrop,
        kBridged,
        blend: blend,
        cullK: blend,
      );
      for (final double m in margins) {
        final List<GlassFusedTile>? tiles = fusedDrawTiles(
          boxes: <Rect>[for (final _Shape s in kBridged) _boxOf(s)],
          reach: _reach(kBridged.length, blend),
          cullMargin: m * blend,
        );
        final ui.Image split = _renderFusedTiled(
          program,
          backdrop,
          kBridged,
          blend: blend,
          cullK: blend,
          tiles: tiles!,
        );
        readings[m] = await _bytes(whole, split);
        split.dispose();
      }
      whole.dispose();
      backdrop.dispose();
    });
    for (final double m in margins) {
      print('margin ${m.toStringAsFixed(2)}k: ${readings[m]}');
    }

    // 1.78 is `1 + 2 * delta(3)` to two places — written out rather than asked
    // of `lib/`, so a bound that moved would fail here instead of agreeing with
    // itself.
    expect(readings[1.78]!.differing, 0, reason: 'the derived margin is not conservative enough');
    expect(readings[2.5]!.differing, 0);
    expect(
      readings[0]!.differing,
      greaterThan(0),
      reason:
          'a tile that keeps only the shapes whose own box touches it drew the same picture, '
          'so this fixture has no bridges and the scan measures nothing',
    );
  });

  test('the tiles are a partition, and their union is the boxes they came from', () {
    // The geometry on its own, at a scale no rendering arm can reach: two
    // thousand arrangements, each checked for the two properties a picture can
    // only sample. Disjoint, because an overlap composites twice; covering,
    // because a gap is a hole in the glass.
    //
    // The union is measured by two roads — the tiles' own areas summed, which
    // is the union only because they are disjoint, and an independent sweep
    // over the boxes. One road would agree with itself.
    final random = math.Random(90210);
    var worstTiles = 0;
    var refusals = 0;
    for (var trial = 0; trial < 2000; trial++) {
      final int n = 1 + random.nextInt(kMaxFusedShapes);
      final boxes = <Rect>[
        for (var i = 0; i < n; i++)
          Rect.fromLTWH(
            random.nextDouble() * 300,
            random.nextDouble() * 300,
            8 + random.nextDouble() * 90,
            8 + random.nextDouble() * 90,
          ),
      ];
      const double reach = 7;
      final List<GlassFusedTile>? tiles = fusedDrawTiles(
        boxes: boxes,
        reach: reach,
        cullMargin: 30,
      );
      if (tiles == null) {
        refusals++;
        continue;
      }
      worstTiles = math.max(worstTiles, tiles.length);
      for (var i = 0; i < tiles.length; i++) {
        for (var j = i + 1; j < tiles.length; j++) {
          final Rect a = tiles[i].rect;
          final Rect b = tiles[j].rect;
          final double w = math.min(a.right, b.right) - math.max(a.left, b.left);
          final double h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
          expect(
            w > 1e-9 && h > 1e-9,
            isFalse,
            reason: 'trial $trial: tiles $i and $j overlap by ${w * h} px^2',
          );
        }
        // And nobody was left out: a shape whose own box touches the tile is in
        // it, whatever the margin does with the farther ones.
        for (var s = 0; s < n; s++) {
          if (boxes[s].overlaps(tiles[i].rect)) {
            expect(
              tiles[i].shapes,
              contains(s),
              reason: 'trial $trial: tile $i sits on shape $s and does not carry it',
            );
          }
        }
      }
      final double summed = tiles.fold<double>(
        0,
        (double a, GlassFusedTile t) => a + t.rect.width * t.rect.height,
      );
      final double swept = _unionArea(<Rect>[for (final Rect b in boxes) b.inflate(reach)]);
      expect(
        (summed - swept).abs(),
        lessThan(1e-6 * math.max(1, swept)),
        reason: 'trial $trial: the tiles cover $summed of a union of $swept',
      );
    }
    print('2000 arrangements: worst $worstTiles tiles, $refusals refused past $kMaxFusedTiles');
    expect(
      worstTiles,
      greaterThan(1),
      reason: 'every arrangement came back as one rectangle, so nothing above was exercised',
    );
  });

  test('what the split saves on Adreno is what the tracked digests say', () {
    // D192, and the Adreno half of `debugGlassFusedSplit`'s dartdoc. Read
    // glass against glass inside one scene first — the same rule as the Metal
    // arm below — and the addition over the floor second, because seed b's
    // scattered floor carried a 42% spread across repeats while its median
    // agreed with seed a's to 0.5%.
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
    double draws(Map<String, Object?> d, String scene, String variant) {
      final counters = cell(d, scene, variant)['counters']! as Map<String, Object?>;
      return (counters['glass_fused_draws']! as num) / (counters['glass_fused_paints']! as num);
    }

    for (final (String scene, double frameLow, double frameHigh, double addLow, double addHigh)
        in <(String, double, double, double, double)>[
          ('many_cluster_fused', 0.88, 0.93, 0.80, 0.86),
          ('many_scattered_fused', 0.50, 0.54, 0.33, 0.37),
        ]) {
      for (final String label in <String>['s938-split-a', 's938-split-b']) {
        final d = json.decode(File('provenance/digest/$label.json').readAsStringSync()) as Map<String, Object?>;
        final double floor = cycles(d, scene, 'plain');
        final double tile = cycles(d, scene, 'glass_tile');
        final double quad = cycles(d, scene, 'glass_notile');
        print(
          '$label $scene: ${draws(d, scene, 'glass_tile').round()} draws ${tile.round()} '
          'against 1 draw ${quad.round()} — frame x${(tile / quad).toStringAsFixed(3)}, '
          'addition x${((tile - floor) / (quad - floor)).toStringAsFixed(3)}',
        );
        expect(draws(d, scene, 'glass_notile'), 1);
        expect(draws(d, scene, 'glass_tile'), greaterThan(1));
        expect(tile / quad, inInclusiveRange(frameLow, frameHigh));
        expect((tile - floor) / (quad - floor), inInclusiveRange(addLow, addHigh));
      }
    }
  });

  test('what the split costs on the raster thread of a Mac is what the tracked digests say', () {
    // Same rule as the arm below: `GlassGroup`'s dartdoc and
    // `debugGlassFusedSplit`'s now quote a desktop-Metal number, so the run it
    // came from is in the repository and this re-reads it. Three digests, two
    // seeds, and the ratios are taken **glass against glass inside one scene** —
    // never against the floor, because on the second seed the floor arms carried
    // spreads up to 67% while every glass arm stayed under 6%. An addition over
    // a floor that moved by two thirds is not a reading.
    double raster(Map<String, Object?> digest, String scene, String variant) {
      for (final Object? cell in digest['cells']! as List<Object?>) {
        final c = cell! as Map<String, Object?>;
        if (c['scene'] == scene && c['variant'] == variant) {
          return (c['raster_micros_p50']! as num).toDouble();
        }
      }
      fail('$scene/$variant is not in the digest');
    }

    double draws(Map<String, Object?> digest, String scene, String variant) {
      for (final Object? cell in digest['cells']! as List<Object?>) {
        final c = cell! as Map<String, Object?>;
        if (c['scene'] == scene && c['variant'] == variant) {
          final counters = c['counters']! as Map<String, Object?>;
          final num paints = counters['glass_fused_paints']! as num;
          if (paints == 0) {
            return 0;
          }
          return (counters['glass_fused_draws']! as num) / paints;
        }
      }
      fail('$scene/$variant is not in the digest');
    }

    final a = json.decode(File('provenance/digest/mac-fusesplit-a.json').readAsStringSync()) as Map<String, Object?>;
    final b = json.decode(File('provenance/digest/mac-fusesplit-b.json').readAsStringSync()) as Map<String, Object?>;
    final c = json.decode(File('provenance/digest/mac-drawcost-a.json').readAsStringSync()) as Map<String, Object?>;

    // The split against the one quad, inside one scene: same shader, same
    // capture, same members — the draws are the only thing that moved, and the
    // counter says so rather than the label.
    for (final (String scene, double low, double high) in <(String, double, double)>[
      ('many_cluster_fused', 3.0, 3.5),
      ('many_scattered_fused', 5.5, 6.6),
    ]) {
      for (final Map<String, Object?> seed in <Map<String, Object?>>[a, b]) {
        final double split = raster(seed, scene, 'glass');
        final double quad = raster(seed, scene, 'glass_notile');
        print(
          '$scene: ${draws(seed, scene, 'glass').round()} draws ${split.round()} us against '
          '1 draw ${quad.round()} us — x${(split / quad).toStringAsFixed(2)}',
        );
        expect(draws(seed, scene, 'glass_notile'), 1);
        expect(split / quad, inInclusiveRange(low, high));
      }
    }

    // And the finding the split arm turned up on the way: on this backend the
    // *group* is the cheap one, by the article the mobile numbers do not
    // contain. Twelve ungrouped surfaces are twelve runtime-effect draws.
    for (final (String scene, String fusedScene) in <(String, String)>[
      ('many_cluster', 'many_cluster_fused'),
      ('many_scattered', 'many_scattered_fused'),
    ]) {
      final double ungrouped = raster(b, scene, 'glass');
      final double fused = raster(b, fusedScene, 'glass_notile');
      print(
        '$scene: 12 surface draws ${ungrouped.round()} us against one fused '
        '${fused.round()} us — x${(ungrouped / fused).toStringAsFixed(2)}',
      );
      expect(ungrouped / fused, inInclusiveRange(4.5, 6.0));
    }

    // And the same comparison on Adreno, out of the digest that has been in this
    // repository since D169 — because the claim `GlassGroup`'s dartdoc now makes
    // is that the **sign** flips, and a sign asserted on one backend is not a
    // sign. There the fused arm is the dearer one, by more than three times.
    final adreno = json.decode(File('provenance/digest/s938-fuse-a.json').readAsStringSync()) as Map<String, Object?>;
    double cycles(String scene, String variant) {
      for (final Object? cell in adreno['cells']! as List<Object?>) {
        final c = cell! as Map<String, Object?>;
        if (c['scene'] == scene && c['variant'] == variant) {
          return (c['gpu_cycles_per_frame']! as num).toDouble();
        }
      }
      fail('$scene/$variant is not in the Adreno digest');
    }

    for (final (String scene, String fusedScene) in <(String, String)>[
      ('many_cluster', 'many_cluster_fused'),
      ('many_scattered', 'many_scattered_fused'),
    ]) {
      final double ungrouped = cycles(scene, 'glass');
      final double fused = cycles(fusedScene, 'glass');
      print(
        'Adreno $scene: ungrouped ${ungrouped.round()} cycles against fused '
        '${fused.round()} — x${(fused / ungrouped).toStringAsFixed(2)} the other way',
      );
      expect(
        fused / ungrouped,
        greaterThan(1.5),
        reason:
            'on Adreno the group is supposed to be the dearer arm; if it is not, the dartdoc '
            'is telling an application two things that are the same thing',
      );
    }

    // The control that makes the two paragraphs above statements about *draws*
    // and not about area: with the draw count held fixed, two layouts whose
    // shaded areas differ by 2.5x cost the same. Both halves of it — twelve
    // draws each, and one draw each.
    for (final (String label, double left, double right) in <(String, double, double)>[
      (
        '12 draws',
        raster(c, 'many_cluster', 'glass'),
        raster(c, 'many_scattered', 'glass'),
      ),
      (
        '1 draw',
        raster(a, 'many_cluster_fused', 'glass_notile'),
        raster(a, 'many_scattered_fused', 'glass_notile'),
      ),
    ]) {
      print('$label, cluster against scattered: ${left.round()} vs ${right.round()} us');
      expect(
        (left - right).abs() / left,
        lessThan(0.05),
        reason:
            'the same number of draws over very different areas cost different amounts, so '
            'area is in the price after all and the reading above is not about draws',
      );
    }
  });

  test('what the split saves on the iPad is what the tracked digests say', () {
    // D194, and the reason the split ships on everywhere rather than keyed
    // on `appleMetal`. The same arms read by two instruments: the engine's GPU
    // tracer (`ipad-fs-*`) and the raster thread's wall time
    // (`ipad-fs-*-raster`, the only instrument D190 had). They disagree in
    // sign, and the test holds both halves — a GPU saving alone would not say
    // why the Mac read the other way.
    Map<String, Object?> cell(String label, String scene, String variant) {
      final d = json.decode(File('provenance/digest/$label.json').readAsStringSync()) as Map<String, Object?>;
      for (final Object? c in d['cells']! as List<Object?>) {
        final m = c! as Map<String, Object?>;
        if (m['scene'] == scene && m['variant'] == variant) {
          return m;
        }
      }
      fail('$scene/$variant is not in $label');
    }

    double gpu(String seed, String scene, String variant) =>
        (cell('ipad-fs-$seed', scene, variant)['frame_ms_per_frame']! as num).toDouble();
    double raster(String seed, String scene, String variant) =>
        (cell('ipad-fs-$seed-raster', scene, variant)['raster_micros_p50']! as num).toDouble();
    double draws(String seed, String scene, String variant) {
      final counters = cell('ipad-fs-$seed', scene, variant)['counters']! as Map<String, Object?>;
      return (counters['glass_fused_draws']! as num) / (counters['glass_fused_paints']! as num);
    }

    for (final (String scene, double frameLow, double frameHigh, double addLow, double addHigh)
        in <(String, double, double, double, double)>[
          ('many_cluster_fused', 0.69, 0.78, 0.58, 0.70),
          ('many_scattered_fused', 0.38, 0.44, 0.28, 0.33),
        ]) {
      for (final String seed in <String>['a', 'b']) {
        final double floor = gpu(seed, scene, 'plain');
        final double tile = gpu(seed, scene, 'glass_tile');
        final double quad = gpu(seed, scene, 'glass_notile');
        final double rasterRatio = raster(seed, scene, 'glass_tile') / raster(seed, scene, 'glass_notile');
        print(
          'iPad $seed $scene: ${draws(seed, scene, 'glass_tile').round()} draws '
          'GPU x${(tile / quad).toStringAsFixed(3)} the quad, addition '
          'x${((tile - floor) / (quad - floor)).toStringAsFixed(3)}; raster thread '
          'x${rasterRatio.toStringAsFixed(3)}',
        );
        expect(draws(seed, scene, 'glass_notile'), 1);
        expect(draws(seed, scene, 'glass_tile'), greaterThan(1));
        expect(tile / quad, inInclusiveRange(frameLow, frameHigh));
        expect((tile - floor) / (quad - floor), inInclusiveRange(addLow, addHigh));
        expect(
          rasterRatio,
          inInclusiveRange(1.05, 1.30),
          reason:
              'the raster thread is supposed to read the split as dearer here, which is '
              "the Mac's sign; if it does not, D190 is not explained by the instrument",
        );
      }

      // The group against its ungrouped twin, same two instruments.
      for (final String seed in <String>['a', 'b']) {
        final double ungrouped = gpu(seed, 'many_cluster', 'glass');
        expect(
          gpu(seed, 'many_cluster_fused', 'glass_notile') / ungrouped,
          inInclusiveRange(1.55, 1.70),
        );
        expect(
          gpu(seed, 'many_cluster_fused', 'glass_tile') / ungrouped,
          inInclusiveRange(1.15, 1.25),
        );
        expect(
          raster(seed, 'many_cluster_fused', 'glass_notile') / raster(seed, 'many_cluster', 'glass'),
          inInclusiveRange(0.84, 0.92),
        );
      }
    }
  });

  test('the fragment cost quoted in GlassGroup is what the digests still say', () {
    // The rule that puts this here: a constant baked into `lib/` needs its
    // source tracked in the repository, and a test that checks the source is
    // the right run. `GlassGroup`'s dartdoc tells an application what a shape
    // costs it, and the three digests below are where that came from.
    //
    // The arithmetic is the second implementation of `bench/tool/fuse.py`'s,
    // deliberately: writing the addition as `R + c(n) * A` and subtracting two
    // scenes that place the same members behind quads of very different size
    // removes `R` without ever knowing it. Two independent spellings agreeing
    // on the tracked bytes is the control the tool's own synthetic one is not.
    final before = <({double c1, double c12})>[];
    late ({double c1, double c12}) after;
    for (final String path in kFusionDigests) {
      final ({double c1, double c12}) fit = _solveFusion(path);
      print(
        '${path.split('/').last}: 1 shape ${fit.c1.toStringAsFixed(4)}, '
        '12 shapes ${fit.c12.toStringAsFixed(4)}, '
        'per shape ${((fit.c12 - fit.c1) / 11).toStringAsFixed(4)}',
      );
      if (path.contains('cull')) {
        after = fit;
      } else {
        before.add(fit);
      }
    }

    // The two seeds are the instrument: an effect that belongs to a scenario
    // and one that belongs to its place in the running order look the same from
    // one ordering.
    expect(before.length, 2);
    expect(
      (before[0].c12 - before[1].c12).abs() / before[0].c12,
      lessThan(0.02),
      reason: 'the two seeds disagree about the fused fragment, so neither is a measurement',
    );

    // What ships, and what the dartdoc says: about 0.030 cycles per device
    // pixel per declared shape, and about six times a lone fragment at twelve.
    final double perShape = (after.c12 - after.c1) / 11;
    expect(perShape, closeTo(0.030, 0.003));
    expect(after.c12 / after.c1, closeTo(5.8, 0.6));

    // And the cull's own claim, which is a difference rather than a level: the
    // two pre-cull seeds against the run after it, on the same device, with the
    // ungrouped arms unchanged in the same reports.
    final double was = (before[0].c12 + before[1].c12) / 2;
    print('fused fragment ${was.toStringAsFixed(4)} -> ${after.c12.toStringAsFixed(4)}');
    expect(
      1 - after.c12 / was,
      greaterThan(0.25),
      reason: 'the cull no longer pays for the branch it added',
    );
  });

  test('the bridges are area, and the model predicts a saving it was not fitted on', () {
    // Two claims from two tracked digests, and the second is the only
    // out-of-sample check this cost model has. `c12` is fitted on the quad
    // difference *between two scenes*; the reach bound then shrank the quad
    // *inside* each scene, and the same coefficient has to predict what that
    // saved. A model that only ever answers about what it was fitted on is a
    // restatement of the fit.
    final ({double c1, double c12}) atZero = _solveFusion(
      'provenance/digest/s938-fuse-spacing.json',
      arm: 'glass_s0',
    );
    final ({double c1, double c12}) atEight = _solveFusion(
      'provenance/digest/s938-fuse-spacing.json',
      arm: 'glass_s8',
    );
    print(
      'fragment at spacing 0 ${atZero.c12.toStringAsFixed(4)}, '
      'at spacing 8 ${atEight.c12.toStringAsFixed(4)}',
    );
    expect(
      (atEight.c12 - atZero.c12).abs() / atZero.c12,
      lessThan(0.02),
      reason: 'a blend spacing changed the cost of a fragment, so the bridges are not just area',
    );

    // And the prediction. Same device, same scenes, one change: the quad's
    // inflation fell from `k` to `delta(12) * k`.
    final Map<String, ({double quad, double add})> before = _fusedArms(
      'provenance/digest/s938-fuse-spacing.json',
      arm: 'glass_s8',
    );
    final Map<String, ({double quad, double add})> after = _fusedArms(
      'provenance/digest/s938-fuse-reach.json',
      arm: 'glass',
    );
    for (final String scene in before.keys) {
      final double shrank = (before[scene]!.quad - after[scene]!.quad) * 9;
      final double predicted = atEight.c12 * shrank;
      final double measured = before[scene]!.add - after[scene]!.add;
      print(
        '$scene: quad -${shrank.round()} device px, predicted ${predicted.round()}, '
        'measured ${measured.round()} cycles',
      );
      expect(
        measured / predicted,
        closeTo(1, 0.2),
        reason: '$scene: the fragment cost does not describe a quad it was not fitted on',
      );
    }
  });

  test('the fold cull pays on a second GPU too, and within one run', () {
    // A dynamic branch is not free everywhere, so the saving has to survive a
    // different architecture before it is a property of the code rather than of
    // one driver. Xclipse 920 carried both arms in one binary under one
    // shuffle, which also makes this the only place the claim is immune to the
    // floor drift the twin control reports on that device: the two arms are the
    // same scene and share a floor.
    //
    // Read as a ratio and not as a level on purpose — this device's counter is
    // the governor's occupancy window, a share of time, and is comparable to
    // nothing but itself.
    final report = _digest('provenance/digest/s22u-fuse-a.json');
    final cycles = <String, double>{};
    for (final Object? c in report['cells']! as List<Object?>) {
      final cell = c! as Map<String, Object?>;
      cycles['${cell['scene']}/${cell['variant']}'] = _medianOf(
        (cell['values']! as List<Object?>).cast<num>().map((num v) => v.toDouble()).toList(),
      );
    }
    for (final String scene in <String>['many_cluster_fused', 'many_scattered_fused']) {
      final double floor = cycles['$scene/plain']!;
      final double culled = cycles['$scene/glass']! - floor;
      final double whole = cycles['$scene/glass_nocull']! - floor;
      final double saved = 1 - culled / whole;
      print('$scene on Xclipse: the skip saves ${(saved * 100).toStringAsFixed(1)}% of the addition');
      expect(saved, greaterThan(0.25), reason: '$scene: the branch stopped paying on Xclipse');
    }
  });

  test('the fold depresses the field by less than k, at any count', () {
    // The bound the quad is sized by, checked as arithmetic rather than as a
    // paragraph. `smin` folds sequentially and each step can pull the running
    // field down by up to k/4, so the naive bound over twelve shapes is 11k/4 —
    // and the true one is k, because each step widens the gap the next step is
    // measured against. Eleven times the inflation is the difference, so this
    // is the one place the claim gets to be wrong.
    const double k = 24;
    double fold(List<double> distances) {
      var d = 1.0e4;
      for (final double di in distances) {
        final double h = math.max(k - (di - d).abs(), 0.0) / k;
        d = math.min(di, d) - h * h * k * 0.25;
      }
      return d;
    }

    // The recurrence the quad is sized by, recomputed here rather than called:
    // a check that asked `lib/` for the bound would agree with any bound.
    double predicted(int count) {
      var delta = 0.0;
      for (var i = 1; i < count; i++) {
        final double gap = 1 - delta;
        delta += gap * gap / 4;
      }
      return delta;
    }

    // Tight on the arrangement the derivation names: every shape at the same
    // distance, so every step ties and h is as large as it can be.
    for (final int n in <int>[2, 4, 12]) {
      final equidistant = <double>[for (var i = 0; i < n; i++) 40.0];
      final double converged = (40.0 - fold(equidistant)) / k;
      print(
        '$n equidistant shapes depress the field by ${converged}k '
        '(bound ${predicted(n)}k)',
      );
      expect(converged, closeTo(predicted(n), 1e-9));
    }
    // And it converges rather than accumulating, which is the whole claim: the
    // naive bound at twelve is 2.75k.
    expect(predicted(12), closeTo(0.7582, 0.0001));
    expect(predicted(2), closeTo(0.25, 1e-12));

    // Over arrangements nobody derived, at every count the shader serves. The
    // seed is fixed so a failure is reproducible; the spread straddles k, which
    // is where h stops being zero. The bound must hold **per count**, not only
    // at twelve — that is what makes it usable for a two-shape group, where it
    // is four times tighter than `k`.
    final random = math.Random(20260913);
    final worst = List<double>.filled(kMaxFusedShapes + 1, 0);
    for (var trial = 0; trial < 20000; trial++) {
      final int n = 1 + random.nextInt(kMaxFusedShapes);
      final distances = <double>[
        for (var i = 0; i < n; i++) 40 + random.nextDouble() * 3 * k,
      ];
      final double depression = distances.reduce(math.min) - fold(distances);
      worst[n] = math.max(worst[n], depression / k);
    }
    for (var n = 1; n <= kMaxFusedShapes; n++) {
      expect(
        worst[n],
        lessThanOrEqualTo(predicted(n) + 1e-12),
        reason: 'n=$n: the quad is sized by this bound and an arrangement beat it',
      );
    }
    print(
      'worst over 20000 arrangements, as a fraction of the bound: '
      '${[for (var n = 2; n <= kMaxFusedShapes; n++) (worst[n] / predicted(n)).toStringAsFixed(2)]}',
    );
  });

  // -------------------------------------------------------------------------
  // 5. The ceiling refuses rather than truncates.
  // -------------------------------------------------------------------------

  testWidgets('a group past twelve surfaces refuses, loudly, and the members draw', (
    WidgetTester tester,
  ) async {
    final panels = <_Panel>[
      for (var i = 0; i < kMaxFusedShapes + 1; i++) _Panel(left: 6 + i * 30.0, width: 24),
    ];
    await _mount(tester, panels, spacing: 4);
    final RenderGlassGroup group = tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup));
    expect(group.group.fuses, isFalse);
    expect(group.refusedPaints, greaterThan(0));
    expect(group.fusedPaints, 0);
    // The members are back to drawing themselves: the picture loses its bridges
    // and keeps its panels, which is the degradation this chose over a crash.
    final RenderGlassSurface first = tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface)).first;
    expect(first.paintsWithProxy, greaterThan(0));
    expect(
      tester.takeException(),
      isFlutterError,
      reason: 'an over-capacity group degraded in silence',
    );
  });

  // -------------------------------------------------------------------------
  // 6. Retention sees a blend grouping change.
  // -------------------------------------------------------------------------

  test('a changed blend grouping repacks, and an unchanged one does not', () {
    final rects = <Rect>[
      const Rect.fromLTWH(0, 0, 40, 40),
      const Rect.fromLTWH(300, 0, 40, 40),
    ];
    final retained = RetainedAtlas(pixelRatio: 1, bleed: 0, align: 1);
    expect(
      retained
          .update(
            rects,
            fused: <List<int>>[
              <int>[0, 1],
            ],
          )
          .outcome,
      RetentionOutcome.first,
    );
    // A fresh list with the same contents: the host builds one every frame, so
    // comparing by identity would repack for ever and the retention would be a
    // counter that never fires.
    expect(
      retained
          .update(
            rects,
            fused: <List<int>>[
              <int>[0, 1],
            ],
          )
          .outcome,
      RetentionOutcome.kept,
    );
    final ({AtlasLayout layout, RetentionOutcome outcome}) dropped = retained.update(rects);
    expect(dropped.outcome, RetentionOutcome.blend);
    expect(dropped.layout.slots.length, 2, reason: 'the group survived its own removal');
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

const double kPanelWidth = 90;

/// One declared panel.
class _Panel {
  const _Panel({required this.left, this.width = kPanelWidth});

  final double left;
  final double width;
}

final GlobalKey _shotKey = GlobalKey();

/// Mounts the panels over a structured backdrop, with or without a group.
///
/// `spacing == null` means no group at all, which is what every arm compares
/// against. The finish is the calibrated one rather than the identity: the
/// identity draws the backdrop back over itself, so a bridge drawn by a group
/// would be invisible and every arm here would pass on a shader that did
/// nothing.
Future<void> _mount(
  WidgetTester tester,
  List<_Panel> panels, {
  double? spacing,
  bool tight = false,
  GlassHardware hardware = GlassHardware.appleMetal,
  GlassFinish? finish,
}) async {
  // The panels and nothing else. A group paints its fused shape and *then* its
  // subtree, so whatever is inside it ends up on top of the glass — which is
  // what a panel's own title wants and what the page behind it does not. So the
  // backdrop is a sibling before the group, never a child of it.
  Widget panelLayer() => Stack(
    children: <Widget>[
      for (final _Panel panel in panels)
        Positioned(
          left: panel.left,
          top: kTop,
          width: panel.width,
          height: kPanel.height,
          child: const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(kRadius))),
        ),
    ],
  );

  // The same panels in the same places, with the group's own box shrunk to
  // exactly the panels' union instead of the whole screen. What the group is
  // laid out as is a fact about the page, never about the glass, so the two
  // have to draw the same frame.
  Widget tightLayer(double spacing) {
    final double left = panels.map((_Panel p) => p.left).reduce(math.min);
    final double right = panels.map((_Panel p) => p.left + p.width).reduce(math.max);
    return Positioned(
      left: left,
      top: kTop,
      width: right - left,
      height: kPanel.height,
      child: GlassGroup(
        spacing: spacing,
        child: Stack(
          children: <Widget>[
            for (final _Panel panel in panels)
              Positioned(
                left: panel.left - left,
                top: 0,
                width: panel.width,
                height: kPanel.height,
                child: const GlassSurface(
                  borderRadius: BorderRadius.all(Radius.circular(kRadius)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget stack() => SizedBox.fromSize(
    size: kScreen,
    child: Stack(
      children: <Widget>[
        Positioned.fill(child: CustomPaint(painter: _Bars())),
        if (tight)
          tightLayer(spacing!)
        else
          Positioned.fill(
            child: spacing == null ? panelLayer() : GlassGroup(spacing: spacing, child: panelLayer()),
          ),
      ],
    ),
  );

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            hardware: hardware,
            finish: finish ?? GlassFinish.regularDark,
            resolution: const ProxyResolution.full(),
            child: RepaintBoundary(key: _shotKey, child: stack()),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<ui.Image> _shot(
  WidgetTester tester,
  List<_Panel> panels, {
  double? spacing,
  bool tight = false,
  GlassHardware hardware = GlassHardware.appleMetal,
  GlassFinish? finish,
}) async {
  await _mount(
    tester,
    panels,
    spacing: spacing,
    tight: tight,
    hardware: hardware,
    finish: finish,
  );
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

RenderGlassGroup _groupOf(WidgetTester tester) => tester.renderObject<RenderGlassGroup>(find.byType(GlassGroup));

List<AtlasSlot> _slotsOf(WidgetTester tester) {
  final GlassProxyFrame frame = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle.frame!;
  return frame.layout.slots;
}

/// Half the vertical extent of the fused shape on the midline between two
/// panels, in logical pixels, read off the drawn frame.
///
/// Read off the *picture* rather than off the field, because the field is what
/// is under test. The panels sit on a backdrop with a horizontal bar pattern,
/// and the glass is the only thing that writes the refracted, tinted colour —
/// so "is there a shape here" is "does this column differ from the same column
/// with no glass at all".
Future<double> _bridgeHalfWidth(WidgetTester tester, ui.Image shot, int x) async {
  final ui.Image bare = await _shot(tester, const <_Panel>[]);
  late double half;
  await tester.runAsync(() async {
    final Uint8List a = (await shot.toByteData())!.buffer.asUint8List();
    final Uint8List b = (await bare.toByteData())!.buffer.asUint8List();
    final int centre = (kTop + kPanel.height / 2).round();
    var span = 0;
    for (var y = centre; y < kScreen.height; y++) {
      final int i = (y * kScreen.width.toInt() + x) * 4;
      final int worst = <int>[
        (a[i] - b[i]).abs(),
        (a[i + 1] - b[i + 1]).abs(),
        (a[i + 2] - b[i + 2]).abs(),
        (a[i + 3] - b[i + 3]).abs(),
      ].reduce((int p, int q) => p > q ? p : q);
      // Two code values, not one: the tint is a mix and the backdrop has places
      // where it lands within rounding of itself.
      if (worst <= 2) {
        break;
      }
      span++;
    }
    half = span.toDouble();
  });
  bare.dispose();
  return half;
}

/// Half the fused silhouette's vertical extent at the midpoint of the gap,
/// from the field rather than from the picture.
///
/// The rounded box's distance at the midpoint is `|q| - r` with
/// `q = (dx - W/2 + r, |dy| - H/2 + r)` clamped at zero, and both panels read
/// the same there, so the fused field is `d - k/4`. Solving `d = k/4` for `dy`
/// is the whole prediction. Half a device pixel is added because coverage is a
/// box filter over one: the silhouette's zero is where the shape ends, and the
/// last fragment that shows anything is half a pixel past it.
double _predictedHalfWidth({required double gap, required double spacing}) {
  final double k = spacing * 2;
  final double qx = gap / 2 + kRadius;
  final double reach = k / 4 + 0.5 + kRadius;
  if (reach <= qx) {
    return 0;
  }
  final double qy = math.sqrt(reach * reach - qx * qx);
  return qy + kPanel.height / 2 - kRadius;
}

// ---------------------------------------------------------------------------
// The two programs, driven directly.
// ---------------------------------------------------------------------------

const Size kProbe = Size(160, 120);

ui.Image _plainBackdrop() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & kProbe, Paint()..color = const Color(0xFF203040));
  for (var y = 0.0; y < kProbe.height; y += 7) {
    canvas.drawRect(
      Rect.fromLTWH(0, y, kProbe.width, 3),
      Paint()..color = Color.fromARGB(255, 30 + y.toInt(), 150, 200 - y.toInt()),
    );
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(kProbe.width.toInt(), kProbe.height.toInt());
  picture.dispose();
  return image;
}

ui.Image _drawProbe(ui.FragmentShader shader, ui.Image backdrop) {
  shader.setImageSampler(0, backdrop, filterQuality: FilterQuality.low);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Offset.zero & kProbe, Paint()..shader = shader);
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(kProbe.width.toInt(), kProbe.height.toInt());
  } finally {
    picture.dispose();
    shader.dispose();
  }
}

/// The optics tail both programs end with, written in the order both declare.
void _writeTail(void Function(double) w, GlassFinish finish) {
  final GlassOptics optics = finish.optics;
  w(optics.thickness);
  w(optics.strength);
  w(optics.edgePower);
  w(optics.shoulder);
  w(finish.tint.r);
  w(finish.tint.g);
  w(finish.tint.b);
  w(finish.tint.a);
  w(finish.rim.a <= 0 ? 0 : kRimWidthLogical);
  w(finish.rim.r);
  w(finish.rim.g);
  w(finish.rim.b);
  w(finish.rim.a);
  w(1); // one device pixel, at a ratio of 1
}

ui.Image _renderSingle(ui.FragmentProgram program, ui.Image backdrop) {
  final ui.FragmentShader shader = program.fragmentShader();
  var i = 0;
  void w(double v) => shader.setFloat(i++, v);
  w(kProbe.width);
  w(kProbe.height);
  w(0);
  w(0);
  w(1);
  w(0.5);
  w(0.5);
  w(kProbe.width - 0.5);
  w(kProbe.height - 0.5);
  w(kProbe.width / 2);
  w(kProbe.height / 2);
  w(kProbe.width / 2);
  w(kProbe.height / 2);
  w(kRadius);
  _writeTail(w, GlassFinish.regularDark);
  // uRimMix, uWiden, uFade: zero, as the surface writes them for this finish.
  // Unwritten, they are whatever the allocator had there — zero on macOS,
  // anything on Linux, where this arm failed with half its pixels off by 255.
  for (var k = 0; k < 6; k++) {
    w(0);
  }
  expect(i, kSurfaceUniformFloats, reason: 'the probe does not write the whole block');
  return _drawProbe(shader, backdrop);
}

ui.Image _renderFused(ui.FragmentProgram program, ui.Image backdrop) {
  final ui.FragmentShader shader = program.fragmentShader();
  var i = 0;
  void w(double v) => shader.setFloat(i++, v);
  w(kProbe.width);
  w(kProbe.height);
  w(0);
  w(0);
  w(1);
  w(0.5);
  w(0.5);
  w(kProbe.width - 0.5);
  w(kProbe.height - 0.5);
  w(1); // uCount
  w(0); // uBlend
  for (var k = 0; k < kMaxFusedShapes; k++) {
    w(k == 0 ? kProbe.width / 2 : 0);
    w(k == 0 ? kProbe.height / 2 : 0);
    w(k == 0 ? kProbe.width / 2 : 0);
    w(k == 0 ? kProbe.height / 2 : 0);
  }
  for (var k = 0; k < kMaxFusedShapes; k++) {
    w(k == 0 ? kRadius : 0);
  }
  _writeTail(w, GlassFinish.regularDark);
  // Out of reach at one shape either way; written because the block is one
  // float longer than the single program's and a short write leaves whatever
  // the allocator had there.
  w(1e9);
  w(0); // uRimMix
  expect(i, kGroupUniformFloats, reason: 'the probe does not write the whole block');
  return _drawProbe(shader, backdrop);
}

/// One rounded box of a fused probe.
class _Shape {
  const _Shape(this.centre, this.half, this.radius);

  final Offset centre;
  final Size half;
  final double radius;
}

/// Renders an arbitrary set of shapes through the group program, at a named
/// cull distance.
///
/// The cull distance is the whole point of the signature: the skip inside the
/// fold is supposed to be *bit-identical*, and the only way to see that from
/// outside the shader is to render the same fragment twice with the branch
/// compiled in and the threshold out of reach in one of them.
ui.Image _renderFusedShapes(
  ui.FragmentProgram program,
  ui.Image backdrop,
  List<_Shape> shapes, {
  required double blend,
  required double cullK,
}) {
  final ui.FragmentShader shader = program.fragmentShader();
  var i = 0;
  void w(double v) => shader.setFloat(i++, v);
  w(kProbe.width);
  w(kProbe.height);
  w(0);
  w(0);
  w(1);
  w(0.5);
  w(0.5);
  w(kProbe.width - 0.5);
  w(kProbe.height - 0.5);
  w(shapes.length.toDouble());
  w(blend);
  for (var k = 0; k < kMaxFusedShapes; k++) {
    final _Shape? shape = k < shapes.length ? shapes[k] : null;
    w(shape?.centre.dx ?? 0);
    w(shape?.centre.dy ?? 0);
    w(shape?.half.width ?? 0);
    w(shape?.half.height ?? 0);
  }
  for (var k = 0; k < kMaxFusedShapes; k++) {
    w(k < shapes.length ? shapes[k].radius : 0);
  }
  _writeTail(w, GlassFinish.regularDark);
  w(cullK);
  w(0); // uRimMix
  expect(i, kGroupUniformFloats, reason: 'the probe does not write the whole block');
  return _drawProbe(shader, backdrop);
}

/// The recurrence [fusedDrawTiles] sizes its rectangles by, recomputed here
/// rather than called: a helper that asked `lib/` for the bound would agree
/// with any bound.
double _depression(int count) {
  var delta = 0.0;
  for (var i = 1; i < count; i++) {
    final double gap = 1 - delta;
    delta += gap * gap / 4;
  }
  return delta;
}

/// The probe renders at dpr 1, so the half device pixel is half a unit.
double _reach(int count, double blend) => _depression(count) * blend + 0.5 + 1;

double _cullMargin(int count, double blend) => (1 + 2 * _depression(count)) * blend + 0.5 + 1;

Rect _boxOf(_Shape shape) => Rect.fromCenter(
  center: shape.centre,
  width: shape.half.width * 2,
  height: shape.half.height * 2,
);

/// The single rectangle the split replaces: the members' bounding box grown by
/// the bridges' reach.
double _quadArea(List<_Shape> shapes, double blend) {
  Rect union = _boxOf(shapes.first);
  for (final _Shape shape in shapes.skip(1)) {
    union = union.expandToInclude(_boxOf(shape));
  }
  final Rect quad = union.inflate(_reach(shapes.length, blend));
  return quad.width * quad.height;
}

List<GlassFusedTile> _tilesFor(List<_Shape> shapes, double blend) => fusedDrawTiles(
  boxes: <Rect>[for (final _Shape shape in shapes) _boxOf(shape)],
  reach: _reach(shapes.length, blend),
  cullMargin: _cullMargin(shapes.length, blend),
)!;

/// The area of a union of rectangles, by a grid over every coordinate either of
/// them names.
///
/// Deliberately not the decomposition under test: this one keeps every cell of
/// the full grid and asks each whether any rectangle contains it, where
/// [fusedDrawTiles] merges cells into runs along both axes. Two roads to one
/// number.
double _unionArea(List<Rect> rects) {
  final xs = <double>{
    for (final Rect r in rects) ...<double>[r.left, r.right],
  }.toList()..sort();
  final ys = <double>{
    for (final Rect r in rects) ...<double>[r.top, r.bottom],
  }.toList()..sort();
  var area = 0.0;
  for (var i = 0; i + 1 < xs.length; i++) {
    for (var j = 0; j + 1 < ys.length; j++) {
      final double cx = (xs[i] + xs[i + 1]) / 2;
      final double cy = (ys[j] + ys[j + 1]) / 2;
      for (final Rect r in rects) {
        if (cx > r.left && cx < r.right && cy > r.top && cy < r.bottom) {
          area += (xs[i + 1] - xs[i]) * (ys[j + 1] - ys[j]);
          break;
        }
      }
    }
  }
  return area;
}

/// Renders a set of shapes as several draws instead of one, through the same
/// program and with the same optics as [_renderFusedShapes].
///
/// One shader object for all of the tiles, and that is not a saving — it is the
/// engine fact `lib/` leans on. `ReusableFragmentShader::shader()` copies the
/// uniform buffer every time a paint is converted for a draw
/// (`fragment_shader.cc:110-120`), so the second tile's members can be written
/// over the first's. A helper that allocated a shader per tile would render the
/// same picture while testing a mechanism the package does not use.
ui.Image _renderFusedTiled(
  ui.FragmentProgram program,
  ui.Image backdrop,
  List<_Shape> shapes, {
  required double blend,
  required double cullK,
  required List<GlassFusedTile> tiles,
}) {
  final ui.FragmentShader shader = program.fragmentShader();
  // Before the paint, not after: `Paint.shader =` refuses a runtime effect
  // whose samplers are not all set.
  shader.setImageSampler(0, backdrop, filterQuality: FilterQuality.low);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..shader = shader
    ..isAntiAlias = false;
  for (final GlassFusedTile tile in tiles) {
    var i = 0;
    void w(double v) => shader.setFloat(i++, v);
    w(kProbe.width);
    w(kProbe.height);
    w(0);
    w(0);
    w(1);
    w(0.5);
    w(0.5);
    w(kProbe.width - 0.5);
    w(kProbe.height - 0.5);
    w(tile.shapes.length.toDouble());
    w(blend);
    for (var k = 0; k < kMaxFusedShapes; k++) {
      final _Shape? shape = k < tile.shapes.length ? shapes[tile.shapes[k]] : null;
      w(shape?.centre.dx ?? 0);
      w(shape?.centre.dy ?? 0);
      w(shape?.half.width ?? 0);
      w(shape?.half.height ?? 0);
    }
    for (var k = 0; k < kMaxFusedShapes; k++) {
      w(k < tile.shapes.length ? shapes[tile.shapes[k]].radius : 0);
    }
    _writeTail(w, GlassFinish.regularDark);
    w(cullK);
    w(0); // uRimMix
    expect(i, kGroupUniformFloats, reason: 'the probe does not write the whole block');
    canvas.drawRect(tile.rect, paint);
  }
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(kProbe.width.toInt(), kProbe.height.toInt());
  } finally {
    picture.dispose();
    shader.dispose();
  }
}

/// Three shapes close enough to fuse at `k = 40`, in a row: the tiles they
/// decompose into **touch**, which is where a seam would be.
// ignore: library_private_types_in_public_api
const List<_Shape> kBridged = <_Shape>[
  _Shape(Offset(34, 60), Size(24, 22), 10),
  _Shape(Offset(80, 60), Size(14, 20), 8),
  _Shape(Offset(124, 60), Size(16, 18), 12),
];

/// Three shapes far enough apart that at `k = 8` each tile carries exactly one
/// of them: the fixture where dropping the other two has to be free.
// ignore: library_private_types_in_public_api
const List<_Shape> kScattered = <_Shape>[
  _Shape(Offset(34, 30), Size(24, 18), 10),
  _Shape(Offset(126, 32), Size(22, 16), 9),
  _Shape(Offset(70, 96), Size(26, 14), 7),
];

/// Deliberately lopsided: the arms that draw a bridge read the midline between
/// two equal panels, where the two fields are equal by symmetry and the cull
/// can never fire. A set where no two shapes are the same size, the same
/// distance apart, or in a row is what exercises it.
// ignore: library_private_types_in_public_api
const List<_Shape> kLopsided = <_Shape>[
  _Shape(Offset(40, 38), Size(26, 20), 12),
  _Shape(Offset(104, 44), Size(22, 17), 9),
  _Shape(Offset(68, 92), Size(31, 15), 7),
];

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 11) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 5),
        Paint()..color = Color.fromARGB(255, 40 + (y.toInt() % 200), 130, 220 - (y.toInt() % 170)),
      );
    }
    for (var x = 0.0; x < size.width; x += 19) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), Paint()..color = const Color(0x66FFFFFF));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.total);

  final int maxDelta;
  final int differing;
  final int total;

  @override
  String toString() => '$differing/$total px, worst $maxDelta';
}

/// The pixel comparison [_compare] does, without the `runAsync` around it.
///
/// Split out because `runAsync` refuses to nest, and the arms that render and
/// compare in one asynchronous stretch need the inner half on its own.
Future<_Diff> _bytes(ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  final Uint8List x = (await a.toByteData())!.buffer.asUint8List();
  final Uint8List y = (await b.toByteData())!.buffer.asUint8List();
  var worst = 0;
  var differing = 0;
  for (var i = 0; i < x.length; i += 4) {
    var delta = 0;
    for (var c = 0; c < 4; c++) {
      final int d = (x[i + c] - y[i + c]).abs();
      if (d > delta) {
        delta = d;
      }
    }
    if (delta > 0) {
      differing++;
      if (delta > worst) {
        worst = delta;
      }
    }
  }
  return _Diff(worst, differing, x.length ~/ 4);
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

// ---------------------------------------------------------------------------
// The digests the dartdoc's numbers came from.
// ---------------------------------------------------------------------------

/// Two seeds before the fold learned to skip a far shape, and the run after.
///
/// Digests rather than reports: a device report is 15 MB and is not in the
/// repository, so a number quoted in `lib/` would have no source a fresh clone
/// could check.
const List<String> kFusionDigests = <String>[
  'provenance/digest/s938-fuse-a.json',
  'provenance/digest/s938-fuse-b.json',
  'provenance/digest/s938-fuse-cull.json',
];

double _medianOf(List<double> xs) {
  final List<double> sorted = List<double>.of(xs)..sort();
  // Upper median, which is what `digest.py` and the device's own analysis take.
  return sorted[sorted.length ~/ 2];
}

/// Cycles per device pixel of a fused fragment at one shape and at twelve.
/// Reads one digest, refusing a run the harness itself called into question.
Map<String, Object?> _digest(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('the digest a constant came from is gone: $path');
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  // A whitelist rather than a count, and in the conservative direction:
  // anything the harness says that is not one of these two sentences
  // disqualifies the run. The first is the governor staying *below* a ceiling
  // it was never bound by, which the harness spells "these scenarios are
  // comparable"; the second is the Exynos instrument naming its own units.
  for (final Object? c in report['caveats']! as List<Object?>) {
    final String caveat = c! as String;
    final bool allowed =
        (caveat.contains('Thermal clamp engaged') && caveat.contains('bound on none')) ||
        caveat.contains('Exynos nodes');
    expect(allowed, isTrue, reason: '$path: a caveated run is not a measurement — $caveat');
  }
  return report;
}

/// The fused scenes' quad and addition over the floor, for one glass arm.
Map<String, ({double quad, double add})> _fusedArms(String path, {required String arm}) {
  final Map<String, Object?> report = _digest(path);
  final cycles = <String, double>{};
  final quad = <String, double>{};
  for (final Object? c in report['cells']! as List<Object?>) {
    final cell = c! as Map<String, Object?>;
    cycles['${cell['scene']}/${cell['variant']}'] = _medianOf(
      (cell['values']! as List<Object?>).cast<num>().map((num v) => v.toDouble()).toList(),
    );
    final counters = cell['counters']! as Map<String, Object?>;
    final num paints = counters['glass_fused_paints'] as num? ?? 0;
    if (paints > 0) {
      // Keyed by arm and not by scene: a run with an axis on it has one fused
      // cell per arm and they have different quads, so a scene-keyed map
      // silently returns whichever cell came last. Two implementations of this
      // solve disagreeing by 12% is how that was found.
      quad['${cell['scene']}/${cell['variant']}'] =
          (counters['glass_fused_quad_area_logical']! as num).toDouble() / paints;
    }
  }
  return <String, ({double quad, double add})>{
    for (final String key in quad.keys)
      if (key.endsWith('/$arm'))
        key.split('/').first: (
          quad: quad[key]!,
          add: cycles[key]! - cycles['${key.split('/').first}/plain']!,
        ),
  };
}

({double c1, double c12}) _solveFusion(String path, {String arm = 'glass'}) {
  final Map<String, Object?> report = _digest(path);
  final double dpr = ((report['environment']! as Map<String, Object?>)['device_pixel_ratio']! as num).toDouble();

  final cycles = <String, double>{};
  final quad = <String, double>{};
  final members = <String, double>{};
  for (final Object? c in report['cells']! as List<Object?>) {
    final cell = c! as Map<String, Object?>;
    final String key = '${cell['scene']}/${cell['variant']}';
    cycles[key] = _medianOf(
      (cell['values']! as List<Object?>).cast<num>().map((num v) => v.toDouble()).toList(),
    );
    final counters = cell['counters']! as Map<String, Object?>;
    final num paints = counters['glass_fused_paints'] as num? ?? 0;
    if (paints > 0) {
      // See [_fusedArms]: per arm, because one scene can carry several.
      quad['${cell['scene']}/${cell['variant']}'] =
          (counters['glass_fused_quad_area_logical']! as num).toDouble() / paints;
    }
    members['${cell['scene']}'] = (counters['surface_area_logical']! as num).toDouble();
  }

  // The arm is named per scene rather than once: only a *fused* scene carries
  // the axes that suffix the variant, so its twin is always the bare `glass`.
  double addition(String scene, String variant) => cycles['$scene/$variant']! - cycles['$scene/plain']!;
  double devicePx(double logical) => logical * dpr * dpr;

  // The same member area behind two very different quads: that is what lets the
  // two equations be subtracted.
  final double memberArea = devicePx(members['many_cluster_fused']!);
  expect(
    members['many_scattered_fused'],
    closeTo(members['many_cluster_fused']!, 1),
    reason: '$path: the two scenes do not place the same member area',
  );
  final double quadA = devicePx(quad['many_cluster_fused/$arm']!);
  final double quadB = devicePx(quad['many_scattered_fused/$arm']!);
  final double left = addition('many_cluster_fused', arm) - addition('many_cluster', 'glass');
  final double right = addition('many_scattered_fused', arm) - addition('many_scattered', 'glass');
  final double c12 = (right - left) / (quadB - quadA);
  return (c1: (c12 * quadA - left) / memberArea, c12: c12);
}
