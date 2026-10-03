import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../backdrops.dart';

/// The site's ground: deep blue-black with soft fields of colour, so the
/// glass over it — the side panel, the bars — has something to bend and
/// tint, and the prose over it still reads.
///
/// Still: it repaints only when its size changes, behind a boundary of its
/// own, so the host holds what it captured of it.
class Aurora extends StatelessWidget {
  const Aurora({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(
    child: CustomPaint(painter: _AuroraPainter(), size: Size.infinite, isComplex: true),
  );
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter();

  static const List<(Alignment, double, Color)> _fields = <(Alignment, double, Color)>[
    (Alignment(-0.95, -0.9), 0.55, Color(0x803D5AFE)),
    (Alignment(0.9, -0.75), 0.45, Color(0x66B04BFF)),
    (Alignment(-0.6, 0.35), 0.5, Color(0x4D00B8D4)),
    (Alignment(0.85, 0.7), 0.55, Color(0x59FF4F8B)),
    (Alignment(0.1, 1.1), 0.4, Color(0x403D5AFE)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = kSiteBackground);
    final double r = math.max(size.width, size.height);
    for (final (Alignment at, double radius, Color colour) in _fields) {
      final Offset c = at.withinRect(all);
      final Rect field = Rect.fromCircle(center: c, radius: r * radius);
      canvas.drawRect(
        all,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[colour, colour.withValues(alpha: 0)],
          ).createShader(field),
      );
    }
    // A drafting grid, faint, so refraction has straight lines to bend and the
    // page reads as a sheet the glass is laid on.
    paintDraftingGrid(canvas, size, cell: 16, minor: const Color(0x07FFFFFF), major: const Color(0x10FFFFFF));
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}
