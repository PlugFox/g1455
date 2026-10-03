// The site's pictures, drawn by the package itself, headless: the icons the
// browser and a phone's home screen show, and the link previews.
//
//   BRAND_OUT   the directory written into (`web` for the committed icons,
//               `build/web` in CI for the previews)
//   BRAND_ONLY  `icons` or `og`; both when unset
//
// `tool/brand.sh` runs this. The icons are committed under `web/`; the
// previews, one per page, are drawn at deploy time into the build.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455_example/src/backdrops.dart';
import 'package:g1455_example/src/catalog/catalog.dart';

import '../showcase/harness.dart' show loadShowcaseFonts;

// ignore_for_file: avoid_print

const String _out = String.fromEnvironment('BRAND_OUT');
const String _only = String.fromEnvironment('BRAND_ONLY');

/// The mark's colours, as `web/favicon.svg` draws them.
const List<Color> kMarkGradient = <Color>[Color(0xFF6C8CFF), Color(0xFFB04BFF), Color(0xFFFF4F8B)];

const Color _kGround = Color(0xFF070A12);

void main() {
  setUpAll(loadShowcaseFonts);

  if (_out.isEmpty) {
    test('BRAND_OUT names where the pictures go', () {}, skip: 'set --dart-define=BRAND_OUT=<dir>');
    return;
  }

  if (_only.isEmpty || _only == 'icons') {
    testWidgets('icons', (WidgetTester tester) async {
      final ui.Image rounded = await _render(tester, const Size.square(1024), const _Mark(bleed: false));
      final ui.Image bleed = await _render(tester, const Size.square(1024), const _Mark(bleed: true));
      Future<Uint8List> png(ui.Image master, int size) => _scaled(tester, master, size);
      // One at a time: `runAsync` does not nest.
      _write('icons/Icon-192.png', await png(rounded, 192));
      _write('icons/Icon-512.png', await png(rounded, 512));
      _write('icons/Icon-maskable-192.png', await png(bleed, 192));
      _write('icons/Icon-maskable-512.png', await png(bleed, 512));
      // iOS rounds the corners itself, and shows black where the icon leaves
      // them transparent.
      _write('icons/apple-touch-icon.png', await png(bleed, 180));
      _write('favicon.png', await png(rounded, 96));
      _write(
        'favicon.ico',
        _ico(<int, Uint8List>{
          16: await png(rounded, 16),
          32: await png(rounded, 32),
          48: await png(rounded, 48),
        }),
      );
      rounded.dispose();
      bleed.dispose();
    });
  }

  if (_only.isEmpty || _only == 'og') {
    testWidgets('link previews', (WidgetTester tester) async {
      Future<void> shoot(String name, String eyebrow, String title, String summary, double hue) async {
        final ui.Image image = await _render(
          tester,
          const Size(1200, 630),
          _Preview(eyebrow: eyebrow, title: title, summary: summary, hue: hue),
        );
        _write('og/$name.png', await _encode(tester, image));
        image.dispose();
      }

      await shoot('home', 'FLUTTER PACKAGE · DESIGN SYSTEM', 'Liquid Glass\nfor Flutter', Site.description, 0);
      for (final Entry e in kEntries) {
        await shoot(
          '${e.section.id}-${e.id}',
          'g1455 · ${e.section.title.toUpperCase()}',
          e.title,
          e.summary,
          const <double>[0, 330, 30, 300][e.section.index],
        );
      }
    });
  }
}

void _write(String path, List<int> bytes) {
  final file = File('$_out/$path');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  print('${file.path}  ${bytes.length} B');
}

/// Pumps [child] under a host at [size], lets the glass capture and settle,
/// and returns what was painted.
Future<ui.Image> _render(WidgetTester tester, Size size, Widget child) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shot = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
      home: RepaintBoundary(
        key: shot,
        child: GlassHost(
          // Drawn on the CPU; the hardware only attaches prices.
          hardware: GlassHardware.appleMetal,
          backdrop: _kGround,
          richBackdrop: true,
          minLabelContrast: kTextContrastAA,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
  // The first frame has no glass: the host captures after it is painted.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(tester.takeException(), isNull);
  final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // The layer, not `toImage`: the host leaves the tree dirty after a capture.
  // ignore: invalid_use_of_protected_member
  return (boundary.layer! as OffsetLayer).toImageSync(Offset.zero & size);
}

Future<Uint8List> _encode(WidgetTester tester, ui.Image image) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  });
  return bytes;
}

/// [master] drawn down to [size] square, as a PNG.
Future<Uint8List> _scaled(WidgetTester tester, ui.Image master, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    master,
    Offset.zero & Size(master.width.toDouble(), master.height.toDouble()),
    Offset.zero & Size.square(size.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final ui.Image image = recorder.endRecording().toImageSync(size, size);
  final Uint8List png = await _encode(tester, image);
  image.dispose();
  return png;
}

/// An ICO holding PNG images, which every browser that reads ICO reads.
Uint8List _ico(Map<int, Uint8List> images) {
  final header = BytesBuilder();
  final data = BytesBuilder();
  final dir = ByteData(6)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, images.length, Endian.little);
  header.add(dir.buffer.asUint8List());
  var offset = 6 + 16 * images.length;
  for (final MapEntry<int, Uint8List> e in images.entries) {
    final entry = ByteData(16)
      ..setUint8(0, e.key >= 256 ? 0 : e.key)
      ..setUint8(1, e.key >= 256 ? 0 : e.key)
      ..setUint16(4, 1, Endian.little)
      ..setUint16(6, 32, Endian.little)
      ..setUint32(8, e.value.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    header.add(entry.buffer.asUint8List());
    data.add(e.value);
    offset += e.value.length;
  }
  return (header..add(data.takeBytes())).takeBytes();
}

/// The mark: a lens of clear glass over the site's gradient, the gradient's
/// grid bent at its rim. [bleed] fills the square, for the icons a platform
/// masks or rounds itself, and keeps the lens inside the safe zone.
class _Mark extends StatelessWidget {
  const _Mark({required this.bleed});

  final bool bleed;

  @override
  Widget build(BuildContext context) {
    final double lens = bleed ? 420 : 560;
    final Widget art = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const CustomPaint(painter: _MarkGround()),
        Center(
          child: SizedBox.square(
            dimension: lens,
            child: GlassSurface(
              borderRadius: kGlassCapsule,
              labelled: false,
              finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.35)),
            ),
          ),
        ),
      ],
    );
    return bleed ? art : ClipRSuperellipse(borderRadius: BorderRadius.circular(232), child: art);
  }
}

class _MarkGround extends CustomPainter {
  const _MarkGround();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kMarkGradient,
        ).createShader(all),
    );
    final line = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 10;
    for (double v = 64; v < size.width; v += 128) {
      canvas
        ..drawLine(Offset(v, 0), Offset(v, size.height), line)
        ..drawLine(Offset(0, v), Offset(size.width, v), line);
    }
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.32),
      size.width * 0.16,
      Paint()..color = const Color(0xCCFFE066),
    );
  }

  @override
  bool shouldRepaint(_MarkGround oldDelegate) => false;
}

/// A link preview: the page's title on frosted glass over the colour grid,
/// blobs of clear glass beside it.
class _Preview extends StatelessWidget {
  const _Preview({required this.eyebrow, required this.title, required this.summary, required this.hue});

  final String eyebrow;
  final String title;
  final String summary;
  final double hue;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      GridBackdrop(hue: hue),
      Positioned(
        right: 70,
        top: 90,
        width: 380,
        height: 450,
        child: GlassGroup(
          spacing: 40,
          labelled: false,
          finish: GlassFinish.clear,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final (double x, double y, double r) in const <(double, double, double)>[
                (190, 140, 120),
                (90, 320, 80),
                (300, 330, 64),
              ])
                Positioned(
                  left: x - r,
                  top: y - r,
                  width: r * 2,
                  height: r * 2,
                  child: const GlassSurface(borderRadius: kGlassCapsule, labelled: false),
                ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 56,
        top: 56,
        bottom: 56,
        width: 700,
        child: GlassCard(
          finish: GlassFinish.frosted,
          borderRadius: const BorderRadius.all(Radius.circular(44)),
          padding: const EdgeInsets.fromLTRB(48, 44, 48, 40),
          child: Builder(
            builder: (BuildContext context) {
              final Color label = DefaultTextStyle.of(context).style.color ?? Colors.white;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: label.withValues(alpha: 0.75),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: label,
                      fontSize: title.contains('\n') ? 76 : 84,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: label.withValues(alpha: 0.85), fontSize: 27, height: 1.35),
                    ),
                  ),
                  Text(
                    'g1455.plugfox.dev',
                    style: TextStyle(
                      color: label.withValues(alpha: 0.75),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}
