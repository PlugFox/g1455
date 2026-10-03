import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One tile of the README's grid, logical px. Every scene renders at this
/// size, and the backdrop is one canvas cut into tiles of it, [kGridColumns]
/// to a row, so the tiles laid out in order meet without a seam: the grid
/// runs on, and a colour field that straddles a boundary continues into the
/// next tile, across as well as down.
const Size kTile = Size(400, 200);

/// Tiles to a row of the README's grid: two, at half pub.dev's 776-px README
/// column each. A narrower screen wraps them into one column, and only there
/// do the seams show.
const int kGridColumns = 2;

/// Where tile [index] sits on the backdrop canvas.
Offset tileOrigin(int index) => Offset(index % kGridColumns * kTile.width, index ~/ kGridColumns * kTile.height);

/// The colour under everything, which is also what the host is told is
/// behind its labels.
const Color kShowcaseBase = Color(0xFF0B0F24);

/// The grid's pitch. The tile's sides are multiples of it, so every tile
/// starts on a grid line and the canvas has one lattice.
const double kGridPitch = 20;

/// The part of the canvas a scene belongs to, painted for tile [index].
///
/// Three layers, each there for what the glass does to it: colour fields
/// that the blur and the tint act on, a grid whose straight lines show the
/// refraction bending at the rim, and a word in red and cyan printed apart —
/// an anaglyph — so the edges a lens displaces come out in two colours.
class ShowcaseBackdrop extends StatelessWidget {
  const ShowcaseBackdrop({required this.index, required this.word, super.key});

  /// Which tile of the grid this is.
  final int index;

  /// The anaglyph word, centred in the tile.
  final String word;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: kTile, painter: _CanvasPainter(index, word)),
  );
}

/// A colour field: a soft disc, in canvas coordinates.
class _Field {
  const _Field(this.centre, this.radius, this.colour);

  final Offset centre;
  final double radius;
  final Color colour;
}

/// The fields of the whole canvas, laid out once: a jittered lattice, four
/// to a tile, so every tile gets about the same colour.
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
  const int across = 2 * kGridColumns;
  return <_Field>[
    for (var i = 0; i < 64; i++)
      _Field(
        Offset(
          (i % across + 0.5) * kTile.width / 2 + (random.nextDouble() - 0.5) * 140,
          (i ~/ across + 0.5) * kTile.height / 2 + (random.nextDouble() - 0.5) * 120,
        ),
        70 + random.nextDouble() * 70,
        palette[(i * 5 + i ~/ across) % palette.length],
      ),
  ];
}();

class _CanvasPainter extends CustomPainter {
  _CanvasPainter(this.index, this.word);

  final int index;
  final String word;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect tile = Offset.zero & size;
    final Offset origin = tileOrigin(index);
    final Rect onCanvas = origin & size;

    canvas.drawRect(tile, Paint()..color = kShowcaseBase);

    canvas.save();
    canvas.translate(-origin.dx, -origin.dy);
    for (final _Field f in _fields) {
      if (!onCanvas.overlaps(Rect.fromCircle(center: f.centre, radius: f.radius))) {
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
    // In canvas coordinates, so the major lines run on across tiles whatever
    // the tile's size. Half a pixel in, so a one-pixel line lands on whole
    // device pixels; a tile's last line is the next tile's first.
    for (var i = (origin.dx / kGridPitch).ceil(); i * kGridPitch < origin.dx + size.width; i++) {
      final double x = i * kGridPitch - origin.dx + 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    for (var i = (origin.dy / kGridPitch).ceil(); i * kGridPitch < origin.dy + size.height; i++) {
      final double y = i * kGridPitch - origin.dy + 0.5;
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
  bool shouldRepaint(_CanvasPainter oldDelegate) => oldDelegate.index != index || oldDelegate.word != word;
}
