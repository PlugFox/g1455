import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One tile of the README's strip, logical px. Every scene renders at this
/// size, and the backdrop is one canvas cut into tiles of it, so the tiles
/// stacked in order meet without a seam: the grid runs on, and a colour field
/// that straddles a boundary continues into the next tile.
const Size kTile = Size(400, 200);

/// The colour under everything, which is also what the host is told is
/// behind its labels.
const Color kShowcaseBase = Color(0xFF0B0F24);

/// The grid's pitch. The tile's height is a multiple of it, so every tile
/// starts on a grid line and the strip has one lattice.
const double kGridPitch = 20;

/// The strip a scene belongs to, painted for tile [index].
///
/// Three layers, each there for what the glass does to it: colour fields
/// that the blur and the tint act on, a grid whose straight lines show the
/// refraction bending at the rim, and a word in red and cyan printed apart —
/// an anaglyph — so the edges a lens displaces come out in two colours.
class ShowcaseBackdrop extends StatelessWidget {
  const ShowcaseBackdrop({required this.index, required this.word, super.key});

  /// Which tile of the strip this is.
  final int index;

  /// The anaglyph word, centred in the tile.
  final String word;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: kTile, painter: _StripPainter(index, word)),
  );
}

/// A colour field: a soft disc, in strip coordinates.
class _Field {
  const _Field(this.centre, this.radius, this.colour);

  final Offset centre;
  final double radius;
  final Color colour;
}

/// The fields of the whole strip, laid out once.
///
/// Fixed rather than drawn from a seed per tile: a field near a boundary has
/// to be the same disc in both tiles it shows in.
final List<_Field> _fields = () {
  const List<Color> palette = <Color>[
    Color(0xFFFF2D95), // pink
    Color(0xFF00D1FF), // cyan
    Color(0xFFFFB020), // amber
    Color(0xFF7C4DFF), // violet
    Color(0xFF00E676), // green
    Color(0xFFFF5A36), // orange
  ];
  final random = math.Random(26);
  return <_Field>[
    for (var i = 0; i < 64; i++)
      _Field(
        Offset(
          (i.isEven ? 0.18 : 0.82) * kTile.width + (random.nextDouble() - 0.5) * 180,
          i * kTile.height / 4 + random.nextDouble() * kTile.height / 4 - kTile.height / 2,
        ),
        70 + random.nextDouble() * 70,
        palette[(i * 5) % palette.length],
      ),
  ];
}();

class _StripPainter extends CustomPainter {
  _StripPainter(this.index, this.word);

  final int index;
  final String word;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect tile = Offset.zero & size;
    final double top = index * kTile.height;

    canvas.drawRect(tile, Paint()..color = kShowcaseBase);

    canvas.save();
    canvas.translate(0, -top);
    for (final _Field f in _fields) {
      if (f.centre.dy + f.radius < top || f.centre.dy - f.radius > top + size.height) {
        continue;
      }
      final Rect r = Rect.fromCircle(center: f.centre, radius: f.radius);
      canvas.drawCircle(
        f.centre,
        f.radius,
        Paint()
          ..shader = RadialGradient(colors: <Color>[f.colour.withValues(alpha: 0.85), f.colour.withValues(alpha: 0)])
              .createShader(r),
      );
    }
    canvas.restore();

    _word(canvas, size);

    final minor = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..strokeWidth = 1;
    // In strip coordinates, so the major lines run on across tiles whatever
    // the tile's height. Half a pixel in, so a one-pixel line lands on whole
    // device pixels; a tile's last line is the next tile's first.
    for (var i = 0; i * kGridPitch < size.width; i++) {
      final double x = i * kGridPitch + 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    final int first = (top / kGridPitch).ceil();
    for (var i = first; i * kGridPitch < top + size.height; i++) {
      final double y = i * kGridPitch - top + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  /// The word twice, red to the left and cyan to the right, added: where they
  /// overlap it is white.
  void _word(Canvas canvas, Size size) {
    TextPainter layout(Color colour, double fontSize) => TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: word,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: -2,
          height: 1,
          color: colour,
        ),
      ),
    )..layout();
    // Fitted to the tile's width, with a margin, so a long word is smaller
    // rather than cut.
    final TextPainter probe = layout(const Color(0xFFFFFFFF), 92);
    final double fontSize = 92 * math.min(1, (size.width - 40) / probe.width);
    probe.dispose();
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final (Color colour, double dx) in <(Color, double)>[
      (const Color(0xFFFF1E3C), -4),
      (const Color(0xFF00E5FF), 4),
    ]) {
      final TextPainter p = layout(colour, fontSize);
      final Offset at = size.center(Offset(-p.width / 2 + dx, -p.height / 2));
      canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
      p.paint(canvas, at);
      canvas.restore();
      p.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripPainter oldDelegate) => oldDelegate.index != index || oldDelegate.word != word;
}
