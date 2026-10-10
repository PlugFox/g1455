// The scene the component tests mount their control on: a host, a backdrop
// that counts its own paints and can be told to repaint, and the control
// centred over it — plus the three counters the cost arms read.
//
// Shared because each arm of each file reads the same three things, and the
// one that matters most — that the capture counter *can* move on this mount —
// is the same control everywhere: `repaintBackdrop` and see `recorded` climb.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kSceneSize = Size(400, 300);

/// A mounted scene and its counters.
class ComponentScene {
  ComponentScene._(this.tester, this.hostKey, this.shotKey, this.backdrop, this.paints);

  final WidgetTester tester;
  final GlobalKey hostKey;
  final GlobalKey shotKey;
  final ValueNotifier<int> backdrop;
  final PaintCounter paints;

  /// Mounts [child] centred over a backdrop of bars, under a host on Metal.
  ///
  /// [wrap], when given, is put around the centred child inside the host —
  /// for a `Directionality`, a `PageView`, a `MediaQuery`.
  static Future<ComponentScene> mount(
    WidgetTester tester,
    Widget child, {
    Color? declaredBackdrop,
    bool reduceMotion = false,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final scene = ComponentScene._(tester, GlobalKey(), GlobalKey(), ValueNotifier<int>(0), PaintCounter());
    addTearDown(scene.backdrop.dispose);
    await scene.pump(
      child,
      declaredBackdrop: declaredBackdrop,
      reduceMotion: reduceMotion,
      textDirection: textDirection,
    );
    return scene;
  }

  /// Replaces the child on the same host and backdrop.
  Future<void> pump(
    Widget child, {
    Color? declaredBackdrop,
    bool reduceMotion = false,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: kSceneSize, devicePixelRatio: 1, disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: textDirection,
          child: Align(
            alignment: Alignment.topLeft,
            child: GlassHost(
              key: hostKey,
              hardware: GlassHardware.appleMetal,
              backdrop: declaredBackdrop,
              child: RepaintBoundary(
                key: shotKey,
                child: SizedBox.fromSize(
                  size: kSceneSize,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _Bars(paints, backdrop)),
                        ),
                      ),
                      Positioned.fill(child: Center(child: child)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await frames(6);
  }

  Future<void> frames(int count, [Duration step = const Duration(milliseconds: 16)]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  /// Captures the host has recorded so far.
  int get recorded => (hostKey.currentState! as dynamic).recorded as int;

  /// Surfaces registered on the host's ledger right now.
  int get surfaces => tester.widget<GlassScope>(find.byType(GlassScope)).ledger.registeredCount;

  /// What the ledger reads for the screen — the number an application sees.
  GlassLoad get load => tester
      .widget<GlassScope>(find.byType(GlassScope))
      .ledger
      .read(viewSize: kSceneSize, model: GlassSurfaceCostModel.adrenoCycles);

  /// The control for every "captures 0" arm: repaint what is under the glass
  /// and return how many captures that took. Without it a zero would read the
  /// same on a host that had stopped recording anything.
  Future<int> repaintBackdrop() async {
    final int before = recorded;
    backdrop.value++;
    await frames(2);
    return recorded - before;
  }

  /// The scene's pixels, RGBA, row-major, [kSceneSize] at dpr 1.
  Future<Uint8List> pixels() async {
    final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // ignore: invalid_use_of_protected_member
    final layer = boundary.layer! as OffsetLayer;
    final ui.Image image = layer.toImageSync(Offset.zero & kSceneSize);
    late Uint8List out;
    await tester.runAsync(() async {
      out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
    });
    image.dispose();
    return out;
  }
}

/// The RGB at a global logical point of [pixels].
List<int> rgbAt(Uint8List pixels, Offset p) {
  final int i = (p.dy.floor() * kSceneSize.width.toInt() + p.dx.floor()) * 4;
  return <int>[pixels[i], pixels[i + 1], pixels[i + 2]];
}

/// The mean of R, G and B over a square of side [side] around [p].
double meanAt(Uint8List pixels, Offset p, {int side = 5}) {
  var sum = 0;
  var n = 0;
  for (var dy = -(side ~/ 2); dy <= side ~/ 2; dy++) {
    for (var dx = -(side ~/ 2); dx <= side ~/ 2; dx++) {
      final List<int> c = rgbAt(pixels, p + Offset(dx.toDouble(), dy.toDouble()));
      sum += c[0] + c[1] + c[2];
      n += 3;
    }
  }
  return sum / n;
}

class PaintCounter {
  int value = 0;
}

/// Bars to refract, counting their own paints and repainting on demand.
class _Bars extends CustomPainter {
  _Bars(this.paints, Listenable repaint) : super(repaint: repaint);

  final PaintCounter paints;

  @override
  void paint(Canvas canvas, Size size) {
    paints.value++;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E2A44));
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), Paint()..color = const Color(0xFFE0B040));
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), Paint()..color = const Color(0xFF40C0E0));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
