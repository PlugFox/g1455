// Representative frames for a byte-identity gate: every program the package
// ships, driven through the widgets that write its uniforms, so that a change
// to the uniform block or to its writers that moves a single code value shows.
//
// Shared by `test/glass_pixels_identity_test.dart` (Skia, `flutter test`) and by
// a device run that imports it by path (Impeller), so both backends render the
// same scenes from one source.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart' show GlassProxyHandle, GlassProxyScope;

const Size kIdentityScreen = Size(400, 300);

/// Not 1: at 2 the shader's `uPixel` is half a logical px, and the edges and
/// the rim band are resolved on a grid finer than the layout's.
const double kIdentityDpr = 2;

final GlobalKey _shotKey = GlobalKey();

/// One frame per scene, as RGBA bytes at [kIdentityDpr].
///
/// [perturb] is the negative control: it moves the tint of the first surface
/// by one part in a thousand, which a gate that compared nothing would not see.
///
/// [surface] and [group] draw every scene with those programs in place of the
/// package's own, handed to each host once its own have arrived; the ripple
/// keeps the package's program, which a host loads once per process.
Future<List<(String, Uint8List)>> renderIdentityScenes(
  WidgetTester tester, {
  bool perturb = false,
  ui.FragmentProgram? surface,
  ui.FragmentProgram? group,
}) async {
  final out = <(String, Uint8List)>[];

  Future<void> shoot(String name, Widget scene, {bool highContrast = false, Future<void> Function()? drive}) async {
    await tester.pumpWidget(_shell(scene, highContrast: highContrast));
    if (surface != null || group != null) {
      final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
      // A program still loading would land after this one and replace it.
      expect(handle.program, isNotNull, reason: '$name: the package program had not arrived');
      expect(handle.groupProgram, isNotNull, reason: '$name: the package program had not arrived');
      handle
        ..program = surface ?? handle.program
        ..groupProgram = group ?? handle.groupProgram;
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    if (drive != null) {
      await drive();
    }
    out.add((name, await _pixels(tester)));
    // Each scene has to have run the program it is here for: a frame of flat
    // fallbacks would hash just as stably.
    final Iterable<RenderGlassSurface> surfaces = tester.renderObjectList<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    final Iterable<RenderGlassGroup> groups = tester.renderObjectList<RenderGlassGroup>(
      find.byWidgetPredicate((Widget w) => w is GlassGroup || w is GlassUnion),
    );
    if (groups.isEmpty) {
      expect(surfaces.where((RenderGlassSurface s) => s.paintsWithOptics == 0), isEmpty, reason: name);
    } else {
      expect(groups.where((RenderGlassGroup g) => g.fusedDraws == 0), isEmpty, reason: name);
    }
    if (drive != null) {
      expect(surfaces.single.rippleDraws, greaterThan(0), reason: name);
    }
  }

  final GlassFinish first = perturb
      ? GlassFinish.regularDark.copyWith(
          tint: GlassFinish.regularDark.tint.withValues(alpha: GlassFinish.regularDark.tint.a + 1e-3),
        )
      : GlassFinish.regularDark;

  // Every finish, four corner regimes (a small radius, a capsule, a radius
  // clamped by the short side, an ordinary one), a fractional layout, a
  // presence inset, a widened and zoomed optics, and a fade.
  await shoot(
    'finishes',
    _over(<Widget>[
      _at(const Rect.fromLTWH(12.25, 14.5, 170, 80), GlassSurface(finish: first)),
      _at(
        const Rect.fromLTWH(200, 14, 186, 64),
        const GlassSurface(borderRadius: kGlassCapsule, finish: GlassFinish.regularLight),
      ),
      _at(
        const Rect.fromLTWH(14, 110, 120, 90),
        const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(8)), finish: GlassFinish.clear),
      ),
      _at(
        const Rect.fromLTWH(150.5, 104.75, 110, 84),
        const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(80)), finish: GlassFinish.frosted),
      ),
      _at(const Rect.fromLTWH(276, 100, 110, 90), const GlassSurface(presence: 0.6)),
      _at(
        const Rect.fromLTWH(16, 214, 170, 74),
        GlassSurface(
          finish: GlassFinish.clear.copyWith(optics: GlassFinish.clear.optics.copyWith(widen: 4, zoom: 1.1)),
        ),
      ),
      _at(
        const Rect.fromLTWH(206, 210, 180, 80),
        GlassSurface(fade: GlassFade.vertical(from: 20, extent: 50)),
      ),
    ]),
  );

  // The increase-contrast rim: the uniform that mixes the band in rather than
  // adding it.
  await shoot(
    'contrast',
    _over(<Widget>[
      _at(const Rect.fromLTWH(20, 30, 170, 100), const GlassSurface()),
      _at(
        const Rect.fromLTWH(210, 40, 170, 60),
        const GlassSurface(borderRadius: kGlassCapsule, finish: GlassFinish.clear),
      ),
    ]),
    highContrast: true,
  );

  // The ripple program, mid-wave: a tap and a held finger, driven by the fake
  // clock so the waves are the same every run.
  await shoot(
    'ripple',
    _over(<Widget>[
      _at(const Rect.fromLTWH(60, 50, 280, 200), const GlassSurface(ripple: GlassRipple(), finish: GlassFinish.clear)),
    ]),
    drive: () async {
      final TestGesture tap = await tester.startGesture(const Offset(150, 120));
      await tester.pump(const Duration(milliseconds: 16));
      await tap.up();
      final TestGesture held = await tester.startGesture(const Offset(250, 180));
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      out.add(('ripple-held', await _pixels(tester)));
      await held.up();
      await tester.pump(const Duration(milliseconds: 16));
    },
  );

  // The group program: a blend group of three, one far enough to be culled
  // by the running distance, and a union of two.
  await shoot(
    'group',
    _over(<Widget>[
      Positioned.fill(
        child: GlassGroup(
          spacing: 24,
          child: Stack(
            children: <Widget>[
              _at(const Rect.fromLTWH(20, 30, 110, 70), const GlassSurface()),
              _at(const Rect.fromLTWH(140, 40, 90, 90), const GlassSurface(borderRadius: kGlassCapsule)),
              _at(
                const Rect.fromLTWH(60, 110, 120, 50),
                const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              _at(const Rect.fromLTWH(300, 20, 80, 60), const GlassSurface()),
            ],
          ),
        ),
      ),
      Positioned.fill(
        child: GlassUnion(
          finish: GlassFinish.clear,
          child: Stack(
            children: <Widget>[
              _at(const Rect.fromLTWH(40, 200, 120, 70), const GlassSurface()),
              _at(const Rect.fromLTWH(220, 190, 140, 80), const GlassSurface(borderRadius: kGlassCapsule)),
            ],
          ),
        ),
      ),
    ]),
  );
  return out;
}

Widget _at(Rect rect, Widget child) => Positioned.fromRect(rect: rect, child: child);

Widget _over(List<Widget> glass) => Stack(
  children: <Widget>[
    Positioned.fill(
      child: RepaintBoundary(child: CustomPaint(painter: _Backdrop())),
    ),
    ...glass,
  ],
);

Widget _shell(Widget child, {required bool highContrast}) => MediaQuery(
  data: MediaQueryData(size: kIdentityScreen, devicePixelRatio: kIdentityDpr, highContrast: highContrast),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        key: UniqueKey(),
        hardware: GlassHardware.appleMetal,
        resolution: const ProxyResolution.full(),
        child: RepaintBoundary(
          key: _shotKey,
          child: SizedBox.fromSize(size: kIdentityScreen, child: child),
        ),
      ),
    ),
  ),
);

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image image = layer.toImageSync(Offset.zero & kIdentityScreen, pixelRatio: kIdentityDpr);
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return out;
}

/// Stripes, a ramp and discs: content with every frequency the optics bend,
/// so a misplaced sample changes a code somewhere.
class _Backdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E2A44));
    for (var x = 0.0; x < size.width; x += 13) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 5, size.height),
        Paint()..color = Color.fromARGB(255, 200, (x * 0.6).toInt() % 256, 60),
      );
    }
    for (var y = 0.0; y < size.height; y += 17) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), Paint()..color = const Color(0xFF40C0E0));
    }
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(30.0 + i * 43, 40.0 + (i * 71) % 230),
        14,
        Paint()..color = Color.fromARGB(255, 255, 255 - i * 20, i * 25),
      );
    }
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => false;
}

/// 64-bit FNV-1a over [bytes]: what a device run prints, where the bytes
/// themselves cannot be diffed against a file.
String fnv64(Uint8List bytes) {
  var h = 0xcbf29ce484222325;
  for (final int b in bytes) {
    h ^= b;
    // Wraps at 64 bits on the VM, which is the arithmetic FNV wants.
    h *= 0x100000001b3;
  }
  String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return '${half(h >> 32)}${half(h)}';
}

/// Pixels with any non-zero channel: a frame of nothing hashes stably too.
int litPixels(Uint8List bytes) {
  var n = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] | bytes[i + 1] | bytes[i + 2] != 0) {
      n++;
    }
  }
  return n;
}
