// Corners that are concentric with the corners around them.
//
// Apple's rule for iOS 26 (HIG, "Layout"; SwiftUI's `ConcentricRectangle`):
// a shape inside another shares its centre of curvature, so its radius is the
// container's radius less the inset between them, and a floor keeps a deep
// inset from squaring the corner off. It is arithmetic, not a measurement,
// which is why it lives in one place: the package's own nested shapes were
// written as numbers that happened to agree with it (the segmented control's
// capsule, 14 inside a 16 track inset 2), and a number that agrees by accident
// stops agreeing the first time one of its two inputs moves.
//
// A capsule nests as a capsule: [kGlassCapsule] less any inset is still a
// radius larger than any box, which the engine scales to half the shorter
// side — and half the inner box's shorter side is exactly the outer's less the
// inset.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Radii concentric with a container's: the container's radius less the inset
/// between the two, never below a floor.
///
/// ```dart
/// // A highlight inset 4 px inside a card of radius 24: radius 20.
/// final BorderRadius inner = GlassConcentric.borderRadius(
///   const BorderRadius.all(Radius.circular(24)),
///   const EdgeInsets.all(4),
/// );
/// ```
///
/// Outward is the same rule with a negative inset — a focus ring drawn
/// 3 px outside a radius of 12 is 15 round ([outset]).
///
/// {@category Foundations}
abstract final class GlassConcentric {
  /// The radius of a shape [inset] px inside a container of radius [outer]:
  /// `outer - inset`, never below [min].
  ///
  /// [min] is the floor: Apple's concentric shapes take one so that a shape
  /// inset as deep as the container is round keeps a corner.
  static double radius(double outer, double inset, {double min = 0}) => math.max(min, outer - inset);

  /// [outer]'s corners for a shape [inset] inside it: each corner less the
  /// inset of the two sides that meet there, never below [min].
  ///
  /// Elliptical corners stay elliptical: a corner's x radius loses the inset
  /// of its vertical side, its y radius that of its horizontal one.
  static BorderRadius borderRadius(BorderRadius outer, EdgeInsets inset, {double min = 0}) {
    Radius corner(Radius r, double x, double y) =>
        Radius.elliptical(radius(r.x, x, min: min), radius(r.y, y, min: min));
    return BorderRadius.only(
      topLeft: corner(outer.topLeft, inset.left, inset.top),
      topRight: corner(outer.topRight, inset.right, inset.top),
      bottomLeft: corner(outer.bottomLeft, inset.left, inset.bottom),
      bottomRight: corner(outer.bottomRight, inset.right, inset.bottom),
    );
  }

  /// [inner]'s corners for a shape drawn [distance] px outside it on every
  /// side — a ring, a halo: each corner grown by the distance.
  static BorderRadius outset(BorderRadius inner, double distance) => borderRadius(inner, EdgeInsets.all(-distance));
}
