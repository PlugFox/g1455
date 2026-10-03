// Phase C, §7.3 — the union: N surfaces drawn as one piece of glass, however
// far apart they are.
//
// `flutter test test/glass/glass_union_test.dart`
//
// The roadmap's standing reason for not writing this type was that it is
// `GlassGroup(spacing: infinity)` and so has no behaviour of its own. It has,
// and the reason is that infinity is not a value this machine takes: the quad
// a fused draw shades is the members' union grown by `delta(n) * k`, and the
// fold's skip — a quarter of a twelve-shape group's addition on Adreno, 44% on
// Xclipse (D170, D171) — fires at `k`. So a union **solves** for the smallest
// `k` that connects the members instead of being told one, and that solver is
// what these arms are about.
//
//  1. **The solver is the minimum that connects, and both halves are exact.**
//     `k = 2 * g` is where a pair bridges; the set is connected once every edge
//     of a minimum bottleneck spanning tree bridges. Checked as arithmetic
//     against the fold itself — connected at the answer, disconnected just
//     below it — because a solver that returned a plausible constant would draw
//     a plausible blob and nothing here would notice.
//  2. **The gap between two rounded boxes is not the gap between their boxes.**
//     Diagonal neighbours are where that shows, and a solver that ignored the
//     radii would ask for a `k` too small to connect what it was given. The arm
//     computes both and requires the naive one to *fail*.
//  3. **A union is the group at the spacing it solved for, byte for byte.** The
//     one new thing is the number, so the picture has to be reachable the old
//     way — with the spacing computed in this file rather than read back out of
//     `lib/`, or the arm would agree with any solver.
//  4. **It is not `spacing = infinity`, and that is a number.** Against a
//     spacing somebody would declare to be safe, the solved one shades a
//     fraction of the fragments and hands the shader a cull distance that still
//     culls.
//  5. **Nesting partitions, which is the whole of what a `GlassId` would have
//     bought.** The ancestor is the namespace: an inner union takes the
//     surfaces below it and solves for them alone.
//  6. **Moving one member changes the shape of all of them.** The named cost of
//     solving rather than declaring, made observable: a far member puffs the
//     near pair.
//
// Six breaks, each failing its own arm and no other: `2 * bottleneck` ->
// `bottleneck` (1, 3); the MST bottleneck -> the largest pairwise gap (1, 4);
// -> the smallest pairwise gap (1); `_shapeGap`'s cores -> the raw boxes (2);
// a null spacing painted as zero (3, 6); an inner union that joins the outer
// group (5).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/surface/glass_group.dart' show unionBlendRadiusBound;

// The arms print the solved radii and the quads; a person reads them once.
// ignore_for_file: avoid_print

const Size kScreen = Size(420, 260);
const double kRadius = 20;
const double kSide = 90;
const double kTop = 70;

void main() {
  test('the bound a moving union is captured for holds wherever its members go', () {
    // `unionBlendRadiusBound` sizes the capture of a union whose members
    // declared travel regions; a bound under the solved `k` anywhere inside the
    // regions is a capture smaller than the bridges, the clamped band D201
    // found. Checked against the solved radius at random places, and the
    // control is the bound taken without the regions — the members' current
    // places — which must be beaten somewhere, or the regions bought nothing.
    final random = math.Random(29);
    var placements = 0;
    var tightest = double.infinity;
    var beatenWithoutRegions = 0;
    for (var config = 0; config < 200; config++) {
      final int n = 2 + random.nextInt(4);
      final regions = <Rect>[];
      final sizes = <Size>[];
      final radii = <double>[];
      for (var i = 0; i < n; i++) {
        final size = Size(20 + random.nextDouble() * 100, 20 + random.nextDouble() * 80);
        final region = Rect.fromLTWH(
          random.nextDouble() * 300,
          random.nextDouble() * 400,
          size.width + random.nextDouble() * 200,
          size.height + random.nextDouble() * 100,
        );
        regions.add(region);
        sizes.add(size);
        radii.add(random.nextDouble() * size.shortestSide / 2);
      }
      List<Rect> place() => <Rect>[
        for (var i = 0; i < n; i++)
          Rect.fromLTWH(
            regions[i].left + random.nextDouble() * (regions[i].width - sizes[i].width),
            regions[i].top + random.nextDouble() * (regions[i].height - sizes[i].height),
            sizes[i].width,
            sizes[i].height,
          ),
      ];
      final List<Rect> start = place();
      final double bound = unionBlendRadiusBound(start, radii, regions);
      final double unmoved = unionBlendRadiusBound(start, radii, List<Rect?>.filled(n, null));
      var beaten = false;
      for (var trial = 0; trial < 50; trial++) {
        final double k = unionBlendRadius(place(), radii);
        placements++;
        expect(k, lessThanOrEqualTo(bound + 1e-9), reason: 'config $config: k $k over bound $bound');
        if (k > 0) {
          tightest = math.min(tightest, bound / k);
        }
        beaten |= k > unmoved + 1e-9;
      }
      if (beaten) {
        beatenWithoutRegions++;
      }
    }
    print(
      'bound over $placements placements: tightest bound/k ${tightest.toStringAsFixed(3)}; '
      'without regions beaten in $beatenWithoutRegions of 200 configurations',
    );
    expect(beatenWithoutRegions, greaterThan(100));
  });

  // -------------------------------------------------------------------------
  // 1. The solver, as arithmetic.
  // -------------------------------------------------------------------------

  test('the solved radius is the smallest that connects, and one below it does not', () {
    // Side by side: the gap is the gap, and `k = 2 * g` is where the two fields
    // meet. Four gaps rather than one, because a solver that returned a
    // constant would pass at any single gap.
    for (final double gap in <double>[0, 12, 40, 150]) {
      final boxes = <Rect>[
        const Rect.fromLTWH(0, 0, kSide, kSide),
        Rect.fromLTWH(kSide + gap, 0, kSide, kSide),
      ];
      final double k = unionBlendRadius(boxes, const <double>[kRadius, kRadius]);
      expect(k, closeTo(2 * gap, 1e-9), reason: 'a pair $gap px apart wants k = ${2 * gap}');
      // And the fold agrees: at the midpoint both fields read `gap / 2`, which
      // is a tie, and a tie is where `smin` is deepest.
      expect(_fold(<double>[gap / 2, gap / 2], k), lessThanOrEqualTo(1e-9));
      if (gap > 0) {
        expect(
          _fold(<double>[gap / 2, gap / 2], k * 0.98),
          greaterThan(0),
          reason: 'a k 2% short still connected — the solver is not minimal',
        );
      }
    }

    // A chain. Connectivity does not need every pair to bridge, only a spanning
    // tree, so the answer is the *bottleneck* — and the control is the number a
    // solver that took the largest pairwise gap would return.
    const double near = 40;
    const double far = 70;
    final chain = <Rect>[
      const Rect.fromLTWH(0, 0, kSide, kSide),
      const Rect.fromLTWH(kSide + near, 0, kSide, kSide),
      const Rect.fromLTWH(2 * kSide + near + far, 0, kSide, kSide),
    ];
    const radii = <double>[kRadius, kRadius, kRadius];
    final double k = unionBlendRadius(chain, radii);
    final double widest = 2 * (near + far + kSide);
    print('chain of three: solved k = $k, largest pairwise would be $widest');
    expect(k, closeTo(2 * far, 1e-9));
    expect(
      widest / k,
      greaterThan(2.8),
      reason: 'the control has to be far enough away to be a control',
    );
    // Every tree edge bridges at the answer: the near pair with room to spare,
    // the bottleneck pair exactly.
    expect(_fold(<double>[near / 2, near / 2], k), lessThan(0));
    expect(_fold(<double>[far / 2, far / 2], k), lessThanOrEqualTo(1e-9));
    // And the smallest pairwise gap — the other way a solver can be wrong —
    // leaves the chain in two pieces.
    expect(_fold(<double>[far / 2, far / 2], 2 * near), greaterThan(0));

    // Overlapping members are already connected, so there is nothing to solve
    // and a union of them is a plain union.
    expect(
      unionBlendRadius(
        const <Rect>[Rect.fromLTWH(0, 0, kSide, kSide), Rect.fromLTWH(40, 0, kSide, kSide)],
        radii,
      ),
      0,
    );
    // One member has no gaps at all.
    expect(unionBlendRadius(const <Rect>[Rect.fromLTWH(0, 0, kSide, kSide)], radii), 0);
  });

  test('the gap between rounded boxes is not the gap between boxes', () {
    // Diagonal neighbours, which is the only arrangement where the radii
    // matter: the nearest points sit on the corner arcs. The box gap is the
    // hypotenuse of the two box offsets; the shape gap is the hypotenuse of the
    // *core* offsets less both radii, and a union solved off the first asks for
    // a k that does not reach.
    const double dx = 60;
    const double dy = 60;
    final boxes = <Rect>[
      const Rect.fromLTWH(0, 0, kSide, kSide),
      const Rect.fromLTWH(kSide + dx, kSide + dy, kSide, kSide),
    ];
    final double boxGap = math.sqrt(dx * dx + dy * dy);
    // Each core pulls in by its own radius on the facing side, so the cores are
    // `2r` further apart than the boxes and the disc gives `2r` back along the
    // diagonal rather than along each axis. Hence the shape gap is *larger*
    // than the box gap, and a solver that took the box gap asks for too little.
    final double shapeGap = math.sqrt(math.pow(dx + 2 * kRadius, 2) + math.pow(dy + 2 * kRadius, 2)) - 2 * kRadius;
    final double k = unionBlendRadius(boxes, const <double>[kRadius, kRadius]);
    print('diagonal pair: box gap $boxGap, shape gap $shapeGap, solved k $k');
    expect(k, closeTo(2 * shapeGap, 1e-9));
    expect(shapeGap, greaterThan(boxGap), reason: 'the arrangement does not exercise the radii');
    // The consequence, not the discrepancy: at the naive radius the two shapes
    // are still apart, so the union would have drawn two pieces of glass.
    expect(
      _fold(<double>[shapeGap / 2, shapeGap / 2], 2 * boxGap),
      greaterThan(0),
      reason: 'the box gap happened to be enough — the arm proves nothing',
    );
  });

  // -------------------------------------------------------------------------
  // 2. The union is the group at the spacing it solved for.
  // -------------------------------------------------------------------------

  testWidgets('a union draws the group at the solved spacing, and a bare group draws neither', (
    WidgetTester tester,
  ) async {
    const double gap = 40;
    final panels = <_P>[
      const _P(left: 60),
      const _P(left: 60 + kSide + gap),
    ];

    final ui.Image bare = await _shot(tester, panels);
    final ui.Image plainGroup = await _shot(tester, panels, fuse: _Fuse.group);
    final ui.Image union = await _shot(tester, panels, fuse: _Fuse.union);
    final double solved = _groupOf(tester, _Fuse.union).lastBlendRadius;

    // The spacing is computed here and not read back: an arm that mounted
    // `spacing: solved / 2` would reproduce whatever the solver did, including
    // being wrong.
    final ui.Image declared = await _shot(
      tester,
      panels,
      fuse: _Fuse.group,
      spacing: gap,
    );

    print('two panels $gap px apart: solved k = $solved');
    expect(solved, closeTo(2 * gap, 1e-9));
    expect(
      (await _compare(tester, union, declared)).differing,
      0,
      reason: 'the union is not the group at the spacing it solved for',
    );
    // A group with no spacing is the two panels and nothing between them, which
    // is what makes the bridge below attributable to the solving.
    expect(
      (await _compare(tester, plainGroup, bare)).differing,
      0,
      reason: 'spacing 0 is not a plain union',
    );

    // The bridge, along the centre line between the panels. Every pixel of it
    // has to differ from the bare frame: at the midpoint the fold is exactly
    // zero (coverage a half), and either side of it the tie breaks and the
    // field goes negative — so a k too small leaves a hole in the middle, which
    // is precisely where this reads.
    final int y = (kTop + kSide / 2).round();
    final int from = (60 + kSide).round();
    final int to = (60 + kSide + gap).round();
    final List<int> holes = await _differingAlong(tester, union, bare, y, from, to);
    print(
      'bridge at y=$y from x=$from to x=$to: ${to - from - holes.length} of ${to - from} px '
      'differ from bare',
    );
    expect(holes, isEmpty, reason: 'the fused silhouette has a hole at x=$holes');
    // The control: the same row of the plain group must differ nowhere, or the
    // arm above is reading the panels rather than the bridge.
    expect(
      (await _differingAlong(tester, plainGroup, bare, y, from, to)).length,
      to - from,
      reason: 'the plain group drew something between the panels',
    );

    for (final ui.Image image in <ui.Image>[bare, plainGroup, union, declared]) {
      image.dispose();
    }
  });

  // -------------------------------------------------------------------------
  // 3. Not `spacing = infinity`.
  // -------------------------------------------------------------------------

  testWidgets('solving for the radius shades a fraction of what declaring a safe one does', (
    WidgetTester tester,
  ) async {
    const double gap = 40;
    // Three rather than two, so that the bottleneck and the largest pairwise
    // gap are different numbers: with a pair they coincide, and an arm about
    // area could not tell a solver that over-solved from one that did not.
    final panels = <_P>[
      const _P(left: 60),
      const _P(left: 60 + kSide + gap),
      const _P(left: 60 + 2 * (kSide + gap)),
    ];
    // What somebody writes when they want "these are one piece" and have no
    // solver: a spacing larger than anything on the screen. It connects, and
    // that is the point — it is not wrong, it is expensive, and this is how
    // expensive.
    const double safe = 400;

    await _mount(tester, panels, fuse: _Fuse.union);
    final RenderGlassGroup solved = _groupOf(tester, _Fuse.union);
    final double solvedQuad = solved.fusedQuadArea / solved.fusedPaints;
    final double solvedCull = solved.lastCullDistance;

    // The quad in closed form, from a `k` this file computed: the members'
    // union grown by the deepest the fold can pull the field under the nearest
    // shape (D173's recurrence), half a device pixel for where coverage
    // reaches zero, and a logical pixel of slack against the rasterizer. An
    // area ratio alone would pass a solver that asked for four times too much
    // and still less than the over-declaration.
    expect(solved.lastBlendRadius, closeTo(2 * gap, 1e-9));
    final Rect members = Rect.fromLTRB(
      panels.first.left,
      kTop,
      panels.last.left + kSide,
      kTop + kSide,
    );
    final Rect predicted = members.inflate(_depression(panels.length) * 2 * gap + 1.5);
    print('quad: ${solved.lastFusedQuad} against a predicted $predicted');
    expect(solved.lastFusedQuad!.left, closeTo(predicted.left, 1e-6));
    expect(solved.lastFusedQuad!.top, closeTo(predicted.top, 1e-6));
    expect(solved.lastFusedQuad!.right, closeTo(predicted.right, 1e-6));
    expect(solved.lastFusedQuad!.bottom, closeTo(predicted.bottom, 1e-6));

    await _mount(tester, panels, fuse: _Fuse.group, spacing: safe);
    final RenderGlassGroup declared = _groupOf(tester, _Fuse.group);
    final double declaredQuad = declared.fusedQuadArea / declared.fusedPaints;

    print(
      'quad per fused draw: solved ${solvedQuad.round()} px^2 against '
      '${declaredQuad.round()} declared — x${(declaredQuad / solvedQuad).toStringAsFixed(2)}; '
      'cull distance $solvedCull against ${declared.lastCullDistance}',
    );
    expect(
      declaredQuad / solvedQuad,
      greaterThan(2),
      reason: 'the over-declaration costs nothing, so there is nothing to solve for',
    );
    // The cull is the other half of what an infinite spacing would have thrown
    // away: a shape farther than `k` contributes nothing and is skipped, and the
    // larger `k` is the less often that fires. At 400 the panels are 40 apart,
    // so nothing is ever skipped.
    expect(solvedCull, lessThan(declared.lastCullDistance));
    // And the pictures differ, which is the honest half: the over-declaration is
    // not the same union drawn dearer, it is a puffier one.
    final ui.Image a = await _shot(tester, panels, fuse: _Fuse.union);
    final ui.Image b = await _shot(tester, panels, fuse: _Fuse.group, spacing: safe);
    final _Diff diff = await _compare(tester, a, b);
    print('solved against over-declared: $diff');
    expect(diff.differing, greaterThan(1000));
    a.dispose();
    b.dispose();
  });

  // -------------------------------------------------------------------------
  // 4. A union of one, and a union of overlapping members.
  // -------------------------------------------------------------------------

  testWidgets('a union of one is the lone surface, and overlapping members are a plain union', (
    WidgetTester tester,
  ) async {
    const one = <_P>[_P(left: 60)];
    final ui.Image alone = await _shot(tester, one);
    final ui.Image united = await _shot(tester, one, fuse: _Fuse.union);
    expect(
      (await _compare(tester, alone, united)).differing,
      0,
      reason: 'a union of one is not the surface it holds',
    );
    // The control the group test's own arm needs for the same claim: the
    // comparison has to be able to fail.
    final ui.Image moved = await _shot(tester, const <_P>[_P(left: 64)]);
    expect((await _compare(tester, alone, moved)).differing, greaterThan(100));

    const pair = <_P>[_P(left: 60), _P(left: 120)];
    final ui.Image overlapping = await _shot(tester, pair, fuse: _Fuse.union);
    final ui.Image plain = await _shot(tester, pair, fuse: _Fuse.group);
    expect(_groupOf(tester, _Fuse.group).lastBlendRadius, 0);
    expect(
      (await _compare(tester, overlapping, plain)).differing,
      0,
      reason: 'overlapping members are already connected; the union invented a radius',
    );
    for (final ui.Image image in <ui.Image>[alone, united, moved, overlapping, plain]) {
      image.dispose();
    }
  });

  // -------------------------------------------------------------------------
  // 5. Nesting partitions — the whole of what an id would have bought.
  // -------------------------------------------------------------------------

  testWidgets('an inner union takes the surfaces below it and solves for them alone', (
    WidgetTester tester,
  ) async {
    // Four panels in one outer group; the middle two inside a union of their
    // own. Apple needs `glassEffectID` because its modifier is per-view with no
    // common ancestor; here position already says it, and the nearest scope
    // wins.
    const double innerGap = 24;
    const double outerGap = 130;
    final double innerLeft = 20 + kSide + outerGap;
    final outer = <_P>[
      const _P(left: 20),
      _P(left: innerLeft + 2 * kSide + innerGap + outerGap),
    ];
    final inner = <_P>[
      _P(left: innerLeft),
      _P(left: innerLeft + kSide + innerGap),
    ];

    await tester.pumpWidget(
      _shell(
        Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _Bars())),
            Positioned.fill(
              child: GlassGroup(
                child: Stack(
                  children: <Widget>[
                    for (final _P panel in outer) _positioned(panel),
                    Positioned.fill(
                      child: GlassUnion(
                        child: Stack(
                          children: <Widget>[for (final _P panel in inner) _positioned(panel)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    final RenderGlassGroup union = _groupOf(tester, _Fuse.union);
    final RenderGlassGroup group = _groupOf(tester, _Fuse.group);
    print(
      'outer group holds ${group.group.surfaces.length}, inner union '
      '${union.group.surfaces.length}, solved k ${union.lastBlendRadius}',
    );
    expect(group.group.surfaces, hasLength(2));
    expect(union.group.surfaces, hasLength(2));
    expect(group.fusedPaints, greaterThan(0));
    expect(union.fusedPaints, greaterThan(0));
    // Solved from its own pair. The outer gap is five times the inner one, so a
    // union that had swallowed the whole group would be unmistakable.
    expect(union.lastBlendRadius, closeTo(2 * innerGap, 1e-9));
    expect(group.lastBlendRadius, 0);
  });

  // -------------------------------------------------------------------------
  // 6. Solving is global: one member moves and every silhouette changes.
  // -------------------------------------------------------------------------

  testWidgets('a far member puffs the near pair, which is what declaring a spacing avoids', (
    WidgetTester tester,
  ) async {
    // The named cost of solving rather than declaring. `k` smooths the whole
    // fold, not only the bridge it was solved for, so a third member 200 px out
    // changes the shape of the two that did not move. A declared spacing is the
    // other trade: a member that drifts out of range breaks its own bridge and
    // leaves the rest alone.
    const near = <_P>[_P(left: 30), _P(left: 30 + kSide + 20)];
    final far = <_P>[...near, const _P(left: 30 + 2 * kSide + 20 + 100)];

    final ui.Image pairAlone = await _shot(tester, near, fuse: _Fuse.union);
    final double kNear = _groupOf(tester, _Fuse.union).lastBlendRadius;
    final ui.Image withFar = await _shot(tester, far, fuse: _Fuse.union);
    final RenderGlassGroup three = _groupOf(tester, _Fuse.union);
    print(
      'k with the near pair alone $kNear, with the far member ${three.lastBlendRadius}; '
      'quad ${(three.fusedQuadArea / three.fusedPaints / (kScreen.width * kScreen.height)).toStringAsFixed(2)} '
      'screens',
    );
    expect(three.lastBlendRadius, greaterThan(kNear * 4));

    // Read only over the near pair's own columns, so the third panel cannot be
    // what the count is seeing.
    final int right = (30 + 2 * kSide + 20).round();
    final int changed = await _differingWithin(tester, pairAlone, withFar, 0, right);
    print('$changed px of the near pair changed when the far member joined');
    expect(changed, greaterThan(500), reason: 'solving is supposed to be global; it was not');
    pairAlone.dispose();
    withFar.dispose();
  });
}

// ---------------------------------------------------------------------------
// The fold, on the CPU.
// ---------------------------------------------------------------------------

/// The deepest the sequential fold can pull the field below the nearest shape's
/// own distance, in units of `k` — D173's recurrence, recomputed here.
double _depression(int count) {
  var delta = 0.0;
  for (var i = 1; i < count; i++) {
    final double gap = 1 - delta;
    delta += gap * gap / 4;
  }
  return delta;
}

/// `shaders/glass_group.frag`'s fold, transliterated.
///
/// Recomputed here rather than called, for the reason the group test's own
/// bound is recomputed: a check that asked `lib/` for the arithmetic would
/// agree with any arithmetic.
double _fold(List<double> distances, double k) {
  final double radius = math.max(k, 1e-4);
  var d = 1.0e4;
  for (final double di in distances) {
    final double h = math.max(radius - (di - d).abs(), 0.0) / radius;
    d = math.min(di, d) - h * h * radius * 0.25;
  }
  return d;
}

// ---------------------------------------------------------------------------
// The fixture.
// ---------------------------------------------------------------------------

enum _Fuse { none, group, union }

class _P {
  const _P({required this.left});

  final double left;
}

final GlobalKey _shotKey = GlobalKey();

Widget _positioned(_P panel) => Positioned(
  left: panel.left,
  top: kTop,
  width: kSide,
  height: kSide,
  child: const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(kRadius))),
);

/// The host, the screen and the shot boundary, with nothing of its own inside.
Widget _shell(Widget child) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        hardware: GlassHardware.appleMetal,
        resolution: const ProxyResolution.full(),
        child: RepaintBoundary(
          key: _shotKey,
          child: SizedBox.fromSize(size: kScreen, child: child),
        ),
      ),
    ),
  ),
);

/// Mounts the panels over a barred backdrop, ungrouped, grouped or united.
///
/// The finish is the host's calibrated one rather than the identity: the
/// identity draws the backdrop back over itself, so a bridge would be invisible
/// and every arm here would pass on a shader that did nothing. The backdrop is
/// a sibling of the group and never a child — a group paints its fused shape
/// and *then* its subtree.
Future<void> _mount(
  WidgetTester tester,
  List<_P> panels, {
  _Fuse fuse = _Fuse.none,
  double spacing = 0,
}) async {
  Widget panelLayer() => Stack(children: <Widget>[for (final _P panel in panels) _positioned(panel)]);

  Widget glass() => switch (fuse) {
    _Fuse.none => panelLayer(),
    _Fuse.group => GlassGroup(spacing: spacing, child: panelLayer()),
    _Fuse.union => GlassUnion(child: panelLayer()),
  };

  await tester.pumpWidget(
    _shell(
      Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _Bars())),
          Positioned.fill(child: glass()),
        ],
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<ui.Image> _shot(
  WidgetTester tester,
  List<_P> panels, {
  _Fuse fuse = _Fuse.none,
  double spacing = 0,
}) async {
  await _mount(tester, panels, fuse: fuse, spacing: spacing);
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  return layer.toImageSync(Offset.zero & kScreen);
}

RenderGlassGroup _groupOf(WidgetTester tester, _Fuse fuse) => tester.renderObject<RenderGlassGroup>(
  fuse == _Fuse.union ? find.byType(GlassUnion) : find.byType(GlassGroup),
);

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E2A38));
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 4),
        Paint()..color = Color.fromARGB(255, 40 + (y % 160).toInt(), 170, 210 - (y % 160).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Reading the frames.
// ---------------------------------------------------------------------------

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

/// The x's on row [y] between [from] and [to] where the two frames **agree**.
///
/// Named for the holes rather than for the matches because that is what the arm
/// asserts about: a fused silhouette that reaches across the gap differs from
/// the bare frame at every column of it, and a blend radius too small leaves a
/// hole in the middle.
Future<List<int>> _differingAlong(
  WidgetTester tester,
  ui.Image a,
  ui.Image b,
  int y,
  int from,
  int to,
) async {
  final holes = <int>[];
  await tester.runAsync(() async {
    final Uint8List pa = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List pb = (await b.toByteData())!.buffer.asUint8List();
    final int stride = a.width * 4;
    for (var x = from; x < to; x++) {
      final int i = y * stride + x * 4;
      var worst = 0;
      for (var c = 0; c < 4; c++) {
        final int d = (pa[i + c] - pb[i + c]).abs();
        if (d > worst) {
          worst = d;
        }
      }
      // Two code values, not one: the tint is a mix and the backdrop has places
      // where it lands within rounding of itself.
      if (worst <= 2) {
        holes.add(x);
      }
    }
  });
  return holes;
}

/// Pixels differing between the two frames, in the columns `[from, to)`.
Future<int> _differingWithin(
  WidgetTester tester,
  ui.Image a,
  ui.Image b,
  int from,
  int to,
) async {
  var count = 0;
  await tester.runAsync(() async {
    final Uint8List pa = (await a.toByteData())!.buffer.asUint8List();
    final Uint8List pb = (await b.toByteData())!.buffer.asUint8List();
    final int stride = a.width * 4;
    for (var y = 0; y < a.height; y++) {
      for (var x = from; x < to; x++) {
        final int i = y * stride + x * 4;
        var worst = 0;
        for (var c = 0; c < 4; c++) {
          final int d = (pa[i + c] - pb[i + c]).abs();
          if (d > worst) {
            worst = d;
          }
        }
        if (worst > 2) {
          count++;
        }
      }
    }
  });
  return count;
}
