// Phase A, step 8 — the atlas moves into the package, and its bleed stops being
// a free parameter.
//
// `flutter test test/glass/proxy_atlas_test.dart`
//
// The atlas arrived from `spikes/13_own_walk/` with its own tests, and those
// stay there: they are corpus-wide, they compare a packed slot against a
// separate capture pixel for pixel, and nothing about them needed to move. What
// is here is the three things that are *new* because it is package code now.
//
//  1. **The bleed is measured.** A blur reads outside the surface, so a slot
//     has to capture more than the surface — and until now "3 sigma" was a
//     number the spike wrote down. Measured against the thing it stands in for:
//     the same blur of the whole screen. The instrument matters more than the
//     answer, because the answer is a constant somebody will want to shave.
//  2. **Merging is a lever wherever atlas area is charged, and the criterion
//     never read the constants it was gated on.** With one `toImageSync` for
//     the whole atlas the pass term is constant, so what a merge trades is
//     atlas area against nothing else. For one release that was read as "a
//     lever on Adreno alone", because the dead-area budget `C_pass / k` exists
//     for no other family — but the criterion prices every candidate with
//     `passes: 1`, so `C_pass` cancels and `k` scales both sides alike: the
//     decision is whether the packed area fell, and it is the same decision
//     under any constants at all. Area is charged on every family measured
//     (D28, D128, D134), and the gate was declining a saving on exactly the
//     family that cannot declare itself (D135, D136).
//  3. **The register is its input.** The roadmap's rule is that the capture's
//     geometry is a function of the surfaces and of nothing else (D115),
//     because Impeller's target pool is keyed by size; the surface register
//     (D121) is where those surfaces now come from.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_atlas.dart';

/// A screen with a full-contrast step just outside the surface under test, and
/// bars everywhere else so no crop has a uniform neighbourhood to be flattered
/// by.
const int kW = 400;
const int kH = 120;
const Rect kSurface = Rect.fromLTWH(150, 30, 100, 60);

ui.Image _screen() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, kW * 1.0, kH * 1.0),
    Paint()..color = const Color(0xFF000000),
  );
  // Four logical pixels beyond the surface's right edge: close enough to be
  // inside every blur under test, far enough that no arm captures it for free.
  canvas.drawRect(
    const Rect.fromLTWH(254, 0, kW * 1.0, kH * 1.0),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  for (var y = 0; y < kH; y += 8) {
    canvas.drawRect(
      Rect.fromLTWH(0, y.toDouble(), 254, 4),
      Paint()..color = const Color(0xFF909090),
    );
  }
  return recorder.endRecording().toImageSync(kW, kH);
}

ui.Image _blur(ui.Image source, double sigma, TileMode tile) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(
    source,
    Offset.zero,
    Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: tile),
  );
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

ui.Image _crop(ui.Image source, Rect rect) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(source, rect, Rect.fromLTWH(0, 0, rect.width, rect.height), Paint());
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(rect.width.toInt(), rect.height.toInt());
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _bytes(ui.Image image) async => (await image.toByteData())!.buffer.asUint8List();

int _worst(Uint8List a, Uint8List b) {
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final int d = (a[i] - b[i]).abs();
    if (d > worst) {
      worst = d;
    }
  }
  return worst;
}

/// Worst code value inside the surface, for a slot captured with [bleed] and
/// blurred, against the same blur of the whole screen.
Future<int> _errorAt(ui.Image screen, double sigmaLogical, double bleedLogical, TileMode tile) async {
  // Whole pixels, because a fractional crop resamples and the resampling is
  // larger than the effect: at sigma 2.6 the bleed is 6.5 and a bilinear crop
  // of half a pixel reads 13 code values out on its own. The atlas snaps its
  // sources outward for the same reason one storey down — `toImageSync` takes
  // `ceil(pixelRatio * height)` of a height that is `(top + h) - top`.
  final double sigma = sigmaLogical;
  final double bleed = bleedLogical.ceilToDouble();
  final ui.Image ideal = _blur(screen, sigma, TileMode.decal);
  final ui.Image reference = _crop(ideal, kSurface);
  final Rect region = kSurface.inflate(bleed);
  final ui.Image piece = _crop(screen, region);
  final ui.Image blurred = _blur(piece, sigma, tile);
  final ui.Image arm = _crop(blurred, Rect.fromLTWH(bleed, bleed, kSurface.width, kSurface.height));
  final int worst = _worst(await _bytes(reference), await _bytes(arm));
  for (final ui.Image image in <ui.Image>[ideal, reference, piece, blurred, arm]) {
    image.dispose();
  }
  return worst;
}

void main() {
  // -------------------------------------------------------------------------
  // 1. The bleed.
  // -------------------------------------------------------------------------

  test('the bleed a blurred edge needs is 2.5 sigma, and without it the edge is wrong', () async {
    final ui.Image screen = _screen();
    addTearDown(screen.dispose);
    for (final double sigma in <double>[2.6, 8.0]) {
      // The arm that says this is not a nicety: with no context at all a
      // frosted surface is wrong by a third of the range at its own edge,
      // because the blur is averaging in a step that is not there.
      expect(
        await _errorAt(screen, sigma, 0, TileMode.clamp),
        greaterThan(20),
        reason: 'sigma $sigma: no bleed cost nothing, so this measures nothing',
      );
      // And the answer. `clamp`, which is what the rig uses: a `decal` proxy
      // darkens its own border, and the border of a proxy is the screen edge.
      expect(
        await _errorAt(screen, sigma, AtlasLayout.bleedFor(sigma), TileMode.clamp),
        lessThanOrEqualTo(1),
        reason: 'sigma $sigma: the measured bleed does not actually hide the step',
      );
      // Monotone in between, which is what makes the constant a threshold
      // rather than one lucky point.
      var previous = 1 << 20;
      for (final double ratio in <double>[0.5, 1.0, 1.5, 2.0, 2.5]) {
        final int error = await _errorAt(screen, sigma, ratio * sigma, TileMode.clamp);
        expect(error, lessThanOrEqualTo(previous), reason: 'sigma $sigma at $ratio sigma');
        previous = error;
      }
    }
  });

  test('a decal proxy needs more context than a clamped one', () async {
    // Why the rig clamps, as a number rather than as a preference: extending
    // the edge is a better guess about the missing content than transparency
    // is, and it is worth about half a sigma of capture.
    final ui.Image screen = _screen();
    addTearDown(screen.dispose);
    const double sigma = 8;
    for (final double ratio in <double>[0.5, 1.0, 1.5]) {
      expect(
        await _errorAt(screen, sigma, ratio * sigma, TileMode.decal),
        greaterThan(await _errorAt(screen, sigma, ratio * sigma, TileMode.clamp)),
        reason: 'decal was not worse at $ratio sigma, so the tile mode is not doing anything',
      );
    }
  });

  test('a divisor widens the bleed, because it widens the blur', () {
    // The line that joins step 6 to this one. Recording at 1/k is itself a
    // low-pass of 0.30 logical px of sigma per texel (D117) and it composes in
    // quadrature, so the proxy carries more blur than the finish asked for and
    // needs more context to carry it.
    const double sigma = 2.6;
    expect(AtlasLayout.bleedForResolution(sigma, const ProxyResolution.full(), 2), 2.5 * sigma);
    final double quarter = AtlasLayout.bleedForResolution(
      sigma,
      const ProxyResolution.quarter(),
      2,
    );
    expect(quarter, greaterThan(2.5 * sigma));
    // At a divisor of 4 on a dpr-2 screen the divisor delivers 0.6 logical px,
    // which is a tenth of the total in quadrature — small, and not zero.
    expect(quarter / (2.5 * sigma), closeTo(1.026, 0.005));
    // And a coarser screen makes it larger still, because the texel is what
    // filters and a dpr-1 texel covers twice the ground.
    expect(
      AtlasLayout.bleedForResolution(sigma, const ProxyResolution.quarter(), 1),
      greaterThan(quarter),
    );
  });

  // -------------------------------------------------------------------------
  // 2. Merging, and whose measurement licenses it.
  // -------------------------------------------------------------------------

  test('merging is honoured, and it is taken exactly when the packed atlas shrinks', () {
    // Two surfaces of very different heights, one above the other. The shelf
    // packer puts them side by side on a shelf as tall as the taller one, so
    // it wastes the difference; the union is tall and narrow and wastes
    // nothing. Written this way because the obvious pair — two equal squares
    // side by side — is a case where merging *loses*, which is the point of the
    // next arm.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(0, 110, 100, 20),
    ];
    final AtlasLayout merged = AtlasLayout.pack(surfaces, merge: true);
    final AtlasLayout apart = AtlasLayout.pack(surfaces);
    expect(merged.slots, hasLength(1), reason: 'the merge criterion did not fire at all');
    expect(apart.slots, hasLength(2));
    expect(
      merged.size.width * merged.size.height,
      lessThan(apart.size.width * apart.size.height),
      reason: 'the merge was taken and it did not reduce the atlas',
    );
  });

  test('the texture ceiling makes the criterion lexicographic: fit first, area second', () {
    // The guard that lets the pipeline choose a divisor from an *unmerged*
    // packing without paying for the merge. Over the ceiling a candidate is
    // priced at infinity rather than declined, and the difference is visible in
    // both directions on one input.
    //
    // Two wide strips one above the other. Side by side on a shelf they are
    // 600 device pixels across; unioned they are 300 across and 110 tall, which
    // is *more* area — so the criterion declines the merge when area is all it
    // is looking at, and takes the same merge when only the union fits.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 300, 50),
      const Rect.fromLTWH(0, 60, 300, 50),
    ];
    final AtlasLayout unbounded = AtlasLayout.pack(surfaces, merge: true);
    expect(unbounded.slots, hasLength(2), reason: 'the merge was taken on area alone');
    expect(unbounded.size, const Size(600, 50));

    final AtlasLayout pinched = AtlasLayout.pack(surfaces, merge: true, maxTextureSide: 400);
    expect(
      pinched.slots,
      hasLength(1),
      reason: 'the ceiling did not outrank area: the atlas is still 600 across',
    );
    expect(pinched.size, const Size(300, 110));
    expect(
      pinched.size.width * pinched.size.height,
      greaterThan(unbounded.size.width * unbounded.size.height),
      reason: 'the arm is only a test of the ceiling if the merge it forced costs area',
    );
    expect(pinched.fitsTexture(400), isTrue);
    expect(unbounded.fitsTexture(400), isFalse);

    // And it is still area second: with room for both layouts the cheaper one
    // wins again, so the ceiling is not a standing preference for merging.
    expect(AtlasLayout.pack(surfaces, merge: true, maxTextureSide: 4096).slots, hasLength(2));
  });

  test('the probe the divisor search reads is the packing it will get', () {
    // Two implementations of one packing is the shape of defect this project
    // has already paid for once: `decompose.py` had two input paths and the
    // summary one quietly lost the device's refusals. `probeSize` exists so the
    // per-frame ceiling search does not allocate a layout it throws away, and
    // the moment it stops agreeing with `pack` the search is answering about a
    // different atlas than the one that gets rasterized.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(0, 110, 100, 20),
      const Rect.fromLTWH(220, 500, 140, 70),
    ];
    for (final double pixelRatio in <double>[0.25, 0.5, 1, 2]) {
      for (final double bleed in <double>[0, 6.67, 13]) {
        for (final int align in <int>[1, 4]) {
          for (final List<List<int>>? fused in <List<List<int>>?>[
            null,
            <List<int>>[
              <int>[0, 2],
            ],
          ]) {
            expect(
              AtlasLayout.probeSize(
                surfaces,
                pixelRatio: pixelRatio,
                bleed: bleed,
                align: align,
                fused: fused,
              ),
              AtlasLayout.pack(
                surfaces,
                pixelRatio: pixelRatio,
                bleed: bleed,
                align: align,
                fused: fused,
              ).size,
              reason: 'probe and pack disagree at $pixelRatio / $bleed / $align / $fused',
            );
          }
        }
      }
    }
  });

  test('a blend group keeps its slot, whatever the merge criterion would prefer', () {
    // The one-way invariant of SS4.4: a blend group must share a capture batch,
    // and the reverse does not follow. Two equal squares side by side are the
    // case the merge criterion declines — it is the pair the arm above calls out
    // as a merge that *loses* — so if they end up in one slot it is because they
    // were declared fused and not because the packer wanted it.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(140, 0, 100, 100),
    ];
    final AtlasLayout onPrice = AtlasLayout.pack(surfaces, merge: true);
    expect(
      onPrice.slots,
      hasLength(2),
      reason: 'the packer merged these on price, so this arm proves nothing',
    );

    final AtlasLayout declared = AtlasLayout.pack(
      surfaces,
      merge: true,
      fused: <List<int>>[
        <int>[0, 1],
      ],
    );
    expect(declared.slots, hasLength(1), reason: 'the blend group was taken apart');
    expect(declared.slots.single.members, <int>[0, 1]);
    expect(
      declared.size.width * declared.size.height,
      greaterThan(onPrice.size.width * onPrice.size.height),
      reason: 'the forced slot cost nothing, so the packer would have taken it anyway',
    );
  });

  test('a blend group may still be merged with a stranger', () {
    // The invariant runs one way and only one way. A third surface that pays for
    // itself must still be free to join the group's slot — the group is a floor
    // on what shares a batch, never a ceiling.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(0, 104, 100, 100),
      const Rect.fromLTWH(0, 208, 100, 12),
    ];
    final AtlasLayout packed = AtlasLayout.pack(
      surfaces,
      merge: true,
      fused: <List<int>>[
        <int>[0, 1],
      ],
    );
    expect(packed.slots, hasLength(1));
    expect(packed.slots.single.members, <int>[0, 1, 2]);
  });

  test('the seed does not depend on the order the groups were declared in', () {
    // The packer's tie-breaker reads `members.first`, and the host builds the
    // grouping out of a register whose order is mount order. Two declarations of
    // the same partition have to pack identically, or a surface remounting
    // somewhere else in the tree re-maps every texel in the atlas on a frame
    // where nothing moved.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 60, 40),
      const Rect.fromLTWH(200, 0, 60, 40),
      const Rect.fromLTWH(0, 80, 60, 40),
      const Rect.fromLTWH(200, 80, 60, 40),
    ];
    final AtlasLayout a = AtlasLayout.pack(
      surfaces,
      fused: <List<int>>[
        <int>[0, 2],
        <int>[1, 3],
      ],
    );
    final AtlasLayout b = AtlasLayout.pack(
      surfaces,
      fused: <List<int>>[
        <int>[3, 1],
        <int>[2, 0],
      ],
    );
    expect(a.size, b.size);
    expect(
      <String>[for (final AtlasSlot s in a.slots) '${s.members}${s.rect}'],
      <String>[for (final AtlasSlot s in b.slots) '${s.members}${s.rect}'],
    );
  });

  test('a surface in two blend groups is refused, not resolved', () {
    // Its fragments would belong to two silhouettes, which is a question with no
    // answer rather than a layout that came out worse. Debug-only, because the
    // grouping comes from the application's tree and the check costs a walk.
    expect(
      () => AtlasLayout.pack(
        <Rect>[const Rect.fromLTWH(0, 0, 10, 10), const Rect.fromLTWH(20, 0, 10, 10)],
        fused: <List<int>>[
          <int>[0, 1],
          <int>[1],
        ],
      ),
      throwsAssertionError,
    );
    expect(
      () => AtlasLayout.pack(
        <Rect>[const Rect.fromLTWH(0, 0, 10, 10)],
        fused: <List<int>>[
          <int>[0, 7],
        ],
      ),
      throwsAssertionError,
    );
  });

  test('the criterion is a strict reduction of the packed area, under any constants', () {
    // The criterion, stated as the invariant it is rather than as the cost
    // model it used to be dressed in: over a spread of geometries the merged
    // atlas is never larger than the unmerged one, and whenever a merge was
    // taken the atlas is strictly smaller. That is what "priced with one pass
    // on every candidate" reduces to, and it holds under any `C_pass` and any
    // positive `k` — which is why gating it on those constants being known for
    // the hardware was a gate on nothing. Violations are collected rather than
    // asserted one by one, so that a deliberate break reports how much of the
    // arm it broke rather than stopping at the first seed: inverting the price
    // (prefer the larger atlas) grows the atlas on 55 of these 60 layouts and
    // takes a merge for no reduction on the same 55 — measured, not estimated:
    // the first draft of this comment said 41 before the break had been run.
    var taken = 0;
    final violations = <String>[];
    for (var seed = 0; seed < 60; seed++) {
      final List<Rect> rects = _spread(seed, count: 2 + seed % 5);
      final AtlasLayout m = AtlasLayout.pack(rects, merge: true, bleed: 4);
      final AtlasLayout a = AtlasLayout.pack(rects, bleed: 4);
      final double mArea = m.size.width * m.size.height;
      final double aArea = a.size.width * a.size.height;
      if (mArea > aArea) {
        violations.add('seed $seed: merging grew the atlas ($mArea > $aArea)');
      }
      if (m.slots.length < a.slots.length) {
        taken++;
        if (mArea >= aArea) {
          violations.add('seed $seed: a merge was taken for no reduction');
        }
      } else if (m.size != a.size) {
        violations.add('seed $seed: nothing merged and the layout still changed');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // The arm has to have seen both outcomes, or it checked one branch.
    expect(taken, greaterThan(10));
    expect(taken, lessThan(50));
  });

  test('the merge is decided on the packed atlas, not on the rectangles', () {
    // The finding the spike recorded and the reason the criterion is a repack
    // rather than a pairwise rule: two surfaces far apart make a union whose
    // dead area is enormous, and the shelf packer was already wasting some of
    // it. Only a real reduction is taken.
    final far = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(1000, 700, 100, 100),
    ];
    expect(AtlasLayout.pack(far, merge: true).slots, hasLength(2));
    // And the near case that also declines, which is the sharper half: two
    // equal squares side by side pack with no waste at all, so the union's own
    // gap is a pure loss even though the surfaces are ten pixels apart.
    final near = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(110, 0, 100, 100),
    ];
    expect(AtlasLayout.pack(near, merge: true).slots, hasLength(2));
  });

  // -------------------------------------------------------------------------
  // 3. The register is the input.
  // -------------------------------------------------------------------------

  test('an atlas built from the surface register maps a screen point back', () {
    final ledger = GlassLedger()
      ..register(_At(const Rect.fromLTWH(20, 40, 200, 80)))
      ..register(_At(const Rect.fromLTWH(40, 600, 120, 60)));
    final List<Rect> surfaces = ledger.surfaces.map((GlassSurfaceRecord r) => r.rect).toList();
    final AtlasLayout atlas = AtlasLayout.pack(
      surfaces,
      pixelRatio: 2,
      bleed: AtlasLayout.bleedFor(2.6),
      align: 8,
    );
    expect(atlas.slots, hasLength(2));

    for (var i = 0; i < surfaces.length; i++) {
      final AtlasSlot slot = atlas.slots.firstWhere((AtlasSlot s) => s.members.contains(i));
      // The surface's own corner lands inside its slot, and the map is the
      // three numbers a shader gets rather than a search.
      final Offset texel = slot.toAtlas(surfaces[i].topLeft);
      expect(slot.rect.contains(texel), isTrue, reason: 'surface $i lands outside its own slot');
      expect(
        texel,
        (surfaces[i].topLeft - slot.uniforms.srcOrigin) * slot.uniforms.scale + slot.uniforms.atlasOrigin,
      );
      // And the bleed is really there: the slot holds context on every side.
      expect(slot.source.left, lessThan(surfaces[i].left));
      expect(slot.source.right, greaterThan(surfaces[i].right));
    }

    // Slots do not overlap and every origin is on the alignment grid — the two
    // properties that keep one slot's blur out of the next (D39).
    for (var i = 0; i < atlas.slots.length; i++) {
      final AtlasSlot a = atlas.slots[i];
      expect(a.rect.left % 8, 0);
      expect(a.rect.top % 8, 0);
      for (var j = i + 1; j < atlas.slots.length; j++) {
        expect(a.rect.intersect(atlas.slots[j].rect).isEmpty, isTrue, reason: 'slots $i and $j overlap');
      }
    }
  });

  test('the same surfaces pack the same way twice', () {
    // Determinism is not a nicety here: a layout that depended on iteration
    // order would re-map every surface's texture coordinates on a frame where
    // nothing moved, and the shader would sample a texture that had been
    // rewritten under it.
    final surfaces = <Rect>[
      const Rect.fromLTWH(0, 0, 100, 40),
      const Rect.fromLTWH(0, 0, 100, 40),
      const Rect.fromLTWH(200, 300, 60, 60),
    ];
    final AtlasLayout a = AtlasLayout.pack(surfaces, align: 4);
    final AtlasLayout b = AtlasLayout.pack(surfaces.reversed.toList().reversed.toList(), align: 4);
    expect(a.size, b.size);
    for (var i = 0; i < a.slots.length; i++) {
      expect(a.slots[i].rect, b.slots[i].rect);
      expect(a.slots[i].members, b.slots[i].members);
    }
  });

  test('one atlas against one bounding box, on surfaces in opposite corners', () {
    // The comparison D24 is about, on the geometry that makes it lopsided.
    final atlas = AtlasLayout.pack(<Rect>[
      const Rect.fromLTWH(0, 0, 100, 60),
      const Rect.fromLTWH(300, 700, 100, 60),
    ], pixelRatio: 3);
    expect(atlas.boundingBoxRoute.dead, greaterThan(atlas.waste * 10));
  });
}

/// A surface that is simply somewhere.
class _At implements GlassSurfaceGeometry {
  _At(this.rect);

  final Rect rect;

  // Never composited: this surface is arithmetic, not a render object.
  @override
  Layer? get compositedLayer => null;

  @override
  Layer? get drawLayer => null;

  // In the proxy's terms it is a full-rung surface: these arms are about the
  // arithmetic, and the rung has its own file.
  @override
  bool get excludedFromProxy => true;

  @override
  GlassSurfaceRecord? readGeometry() => GlassSurfaceRecord(
    rect: rect,
    shapeArea: GlassLedger.shapeAreaOf(
      RSuperellipse.fromRectAndRadius(rect, const Radius.circular(16)),
    ),
  );
}

/// [count] rectangles somewhere on a phone-sized screen, deterministic in
/// [seed] so a failing layout can be named by its seed and re-run.
///
/// A linear congruential generator rather than `Random(seed)`, because the
/// arm quotes how many of its layouts merge, and that count must not depend
/// on which Dart release's `Random` is under it.
List<Rect> _spread(int seed, {required int count}) {
  var state = 0x9E3779B9 ^ (seed * 0x85EBCA6B);
  int next(int bound) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    return (state >> 8) % bound;
  }

  return <Rect>[
    for (var i = 0; i < count; i++)
      Rect.fromLTWH(
        next(300).toDouble(),
        next(600).toDouble(),
        (20 + next(180)).toDouble(),
        (20 + next(180)).toDouble(),
      ),
  ];
}
