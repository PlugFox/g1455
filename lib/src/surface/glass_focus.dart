// The keyboard's focus ring, drawn around a control without being glass.
//
// Where it is drawn is the whole design, because a ring is content and
// content near glass is what the host captures:
//
//  - **on a glass control** ([GlassButton], a [GlassButtonGroup]'s cell) it is
//    painted from inside the surface's own subtree, past the surface's box —
//    which the capture skips and the layer watch excludes (the self-capture
//    rule), so focusing a button retakes nothing;
//  - **on a control that is not glass** (the switch's track, the segmented
//    control's track) it is painted behind a repaint boundary of its own,
//    sized to the ring rather than the control: the watch bounds a change by
//    the boundary that owns it, and a ring drawn past a smaller boundary would
//    be a change it located in the wrong place. The painter is always there,
//    ring or not, so the boundary always holds a picture: a picture layer that
//    came and went would change the signature's length, which the watch reads
//    as a change everywhere;
//  - **on the slider** it rings the knob, which is the drop's content and so
//    inside the drop's surface, for the first reason.
//
// Shown only while the platform's focus highlight is (`FocusHighlightMode`,
// through [FocusableActionDetector.onShowFocusHighlight]): a keyboard, not a
// finger.

import 'package:flutter/widgets.dart';

import 'glass_concentric.dart';

/// The focus ring's colour: iOS's system blue in dark, which is also the
/// slider's default fill.
///
/// {@category Panels and controls}
const Color kGlassFocusRingColor = Color(0xFF0A84FF);

/// The focus ring's stroke, logical px.
///
/// {@category Panels and controls}
const double kGlassFocusRingWidth = 3;

/// The gap between a control's edge and its focus ring, logical px.
///
/// {@category Panels and controls}
const double kGlassFocusRingGap = 2;

/// How far past a control's edge its focus ring reaches.
const double kGlassFocusRingReach = kGlassFocusRingGap + kGlassFocusRingWidth;

/// Strokes the focus ring around [box], whose corners are [radius]: outside it
/// by [kGlassFocusRingGap], concentric with it.
void paintGlassFocusRing(Canvas canvas, Rect box, BorderRadius radius) {
  const double d = kGlassFocusRingGap + kGlassFocusRingWidth / 2;
  canvas.drawRSuperellipse(
    // Scaled, as every shape here is drawn: a capsule is declared as a radius
    // larger than the box.
    GlassConcentric.outset(radius, d).toRSuperellipse(box.inflate(d)).scaleRadii(),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kGlassFocusRingWidth
      ..color = kGlassFocusRingColor,
  );
}

/// A focus ring around a control that is not glass, behind a boundary of its
/// own sized to the ring. Lay it over the control's box, in a `Stack` that
/// does not clip; [visible] false draws nothing but keeps the picture.
class GlassFocusRing extends StatelessWidget {
  /// A ring around the box this is laid over, whose corners are [radius].
  const GlassFocusRing({required this.visible, required this.radius, super.key});

  /// Whether the ring is drawn.
  final bool visible;

  /// The corners of the box ringed.
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => Positioned(
    left: -kGlassFocusRingReach,
    top: -kGlassFocusRingReach,
    right: -kGlassFocusRingReach,
    bottom: -kGlassFocusRingReach,
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _RingPainter(visible, radius)),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.visible, this.radius);

  final bool visible;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (visible) {
      paintGlassFocusRing(canvas, (Offset.zero & size).deflate(kGlassFocusRingReach), radius);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.visible != visible || oldDelegate.radius != radius;
}
