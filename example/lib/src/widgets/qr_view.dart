import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

/// [data] as a QR code: dark modules on a white square with the quiet zone
/// the standard asks for (four modules), so a phone's camera reads it over
/// any page.
///
/// White and near-black whatever the theme: a camera reads contrast, and an
/// inverted or tinted code is one some readers refuse.
class QrView extends StatelessWidget {
  const QrView({required this.data, this.size = 200, this.semanticLabel, super.key});

  final String data;

  /// The side of the white square, quiet zone included.
  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel ?? 'QR code for $data',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QrPainter(QrImage(QrCode(payload: QrPayload.fromString(data))))),
    ),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  /// Modules of white around the code, on each side.
  static const int _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & Size.square(side), Radius.circular(side * 0.06)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final int n = image.moduleCount;
    final double module = side / (n + 2 * _quiet);
    // One path, filled once: modules drawn one by one leave hairline seams
    // between neighbours where antialiasing meets.
    final path = Path();
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        if (image.isDark(row, col)) {
          path.addRect(Rect.fromLTWH((col + _quiet) * module, (row + _quiet) * module, module, module));
        }
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF0B0D12));
  }

  @override
  bool shouldRepaint(_QrPainter old) => !identical(old.image, image);
}
