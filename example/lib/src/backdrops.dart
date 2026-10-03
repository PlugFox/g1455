import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Something with colour and edges for the glass to bend.
class GradientTile extends StatelessWidget {
  const GradientTile({required this.index, this.height = 120, super.key});

  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color a = HSVColor.fromAHSV(1, (index * 37) % 360.0, 0.7, 0.9).toColor();
    final Color b = HSVColor.fromAHSV(1, (index * 37 + 60) % 360.0, 0.8, 0.5).toColor();
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: <Color>[a, b]),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(20),
      child: Text(
        'Row $index',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// A grid over coloured discs: straight lines show refraction, colour shows
/// the blur and the tint.
///
/// Behind a repaint boundary of its own wherever it is used, so glass moving
/// over it repaints nothing of it.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({this.hue = 0, this.phase = 0, super.key});

  /// Degrees added to every colour.
  final double hue;

  /// Moves the discs, 0 to 1 is one full cycle.
  final double phase;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _GridPainter(hue, phase), size: Size.infinite),
  );
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.hue, this.phase);

  final double hue;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_hsv(220, 0.6, 0.25), _hsv(280, 0.6, 0.2)],
        ).createShader(Offset.zero & size),
    );
    final random = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final double a = phase * 2 * math.pi + i;
      final Offset c = Offset(
        size.width * random.nextDouble() + math.cos(a) * 30,
        size.height * random.nextDouble() + math.sin(a) * 30,
      );
      final double r = 40 + random.nextDouble() * 90;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[_hsv(i * 47.0, 0.75, 0.95), _hsv(i * 47.0 + 40, 0.8, 0.55)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    final line = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  Color _hsv(double h, double s, double v) => HSVColor.fromAHSV(1, (h + hue) % 360, s, v).toColor();

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.hue != hue || oldDelegate.phase != phase;
}

/// A painted "photograph": a sky, a sun and hills, varied by [seed].
class PhotoBackdrop extends StatelessWidget {
  const PhotoBackdrop({required this.seed, super.key});

  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PhotoPainter(seed));
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final double h = random.nextDouble() * 360;
    Color c(double dh, double s, double v) => HSVColor.fromAHSV(1, (h + dh) % 360, s, v).toColor();
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[c(0, 0.5, 0.95), c(40, 0.7, 0.8)],
        ).createShader(all),
    );
    canvas.drawCircle(
      Offset(size.width * (0.2 + random.nextDouble() * 0.6), size.height * 0.35),
      size.shortestSide * 0.16,
      Paint()..color = c(180, 0.3, 1),
    );
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.height);
      final double base = size.height * (0.55 + layer * 0.13);
      for (double x = 0; x <= size.width; x += size.width / 6) {
        path.lineTo(x, base - random.nextDouble() * size.height * 0.18);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = c(120 + layer * 30, 0.6, 0.6 - layer * 0.15));
    }
  }

  @override
  bool shouldRepaint(_PhotoPainter oldDelegate) => oldDelegate.seed != seed;
}
