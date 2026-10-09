// Concentric corners: the container's radius less the inset, never below a
// floor — and the package's own nested shapes, which were numbers before.
//
// `flutter test test/glass_concentric_test.dart`
//
// The segmented control's capsule moved from a number to the helper, and the
// claim is that it moved no pixel: its radius was `shortestSide / 2` and is
// now `min(16 - 2, shortestSide / 2)`, which is the same wherever the capsule
// is at most 28 tall — and it is exactly 28. So the arm is that arithmetic,
// run over every width a segment can have, with the control that the helper
// is the binding term somewhere (a 28 px capsule) and the half side elsewhere.

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  test('inner is outer less the inset, floored', () {
    expect(GlassConcentric.radius(24, 4), 20);
    expect(GlassConcentric.radius(24, 30), 0);
    expect(GlassConcentric.radius(24, 30, min: 6), 6);
    expect(GlassConcentric.radius(24, -3), 27, reason: 'outward is the same rule');
  });

  test('each corner loses the inset of the two sides that meet there', () {
    final BorderRadius inner = GlassConcentric.borderRadius(
      const BorderRadius.only(
        topLeft: Radius.elliptical(20, 10),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(8),
      ),
      const EdgeInsets.fromLTRB(1, 2, 3, 4),
      min: 1,
    );
    expect(inner.topLeft, const Radius.elliptical(19, 8));
    expect(inner.topRight, const Radius.elliptical(13, 14));
    expect(inner.bottomLeft, const Radius.elliptical(11, 8));
    expect(inner.bottomRight, const Radius.elliptical(5, 4));
    expect(
      GlassConcentric.outset(const BorderRadius.all(Radius.circular(12)), 3),
      const BorderRadius.all(Radius.circular(15)),
    );
  });

  test('a capsule nests as a capsule', () {
    // A 48 tall capsule, a shape 6 in: the engine's scaled corners of the
    // inset capsule are the inner box's own capsule.
    const outer = Rect.fromLTWH(0, 0, 160, 48);
    final Rect inner = outer.deflate(6);
    final RSuperellipse nested = GlassConcentric.borderRadius(
      kGlassCapsule,
      const EdgeInsets.all(6),
    ).toRSuperellipse(inner).scaleRadii();
    expect(nested.tlRadiusX, closeTo(inner.height / 2, 1e-6));
    expect(nested.brRadiusY, closeTo(inner.height / 2, 1e-6));
    expect(inner.height / 2, GlassConcentric.radius(outer.height / 2, 6));
  });

  test('the segmented control\'s capsule is the radius it always was', () {
    // Track 32 tall, capsule inset 2: 28 tall, at most (pitch - 3) wide.
    const double track = 32, inset = 2, capsule = track - 2 * inset;
    var helperBinds = 0;
    for (var width = 1.0; width <= 200; width += 0.5) {
      final double shortest = math.min(width, capsule);
      final double before = shortest / 2;
      final double now = math.min(GlassConcentric.radius(track / 2, inset), shortest / 2);
      expect(now, before, reason: 'at $width wide');
      if (GlassConcentric.radius(track / 2, inset) == before) {
        helperBinds++;
      }
    }
    expect(helperBinds, greaterThan(0), reason: 'the helper never decided the radius');
  });
}
