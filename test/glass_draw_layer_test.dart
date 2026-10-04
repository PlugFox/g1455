// How long a glass draw's shader lives: with the picture it was recorded into.
//
// `flutter test test/glass_draw_layer_test.dart`
//
// Natively a shader is disposed straight after its draw. On the web CanvasKit
// reads the uniforms by pointer when the picture is rasterized, so a shader
// drawn into a [GlassDrawLayer]'s picture lives as long as that picture, and
// one drawn into any other picture lives two frame ends. `kIsWeb` is a
// constant, so the web arms run through [debugReleaseGlassShadersAsOnWeb].

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/surface/glass_draw_layer.dart';
import 'package:g1455/src/surface/glass_host.dart' show kGlassShaderAsset;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.FragmentProgram program;

  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset(kGlassShaderAsset);
  });

  tearDown(() {
    debugReleaseGlassShadersAsOnWeb = false;
  });

  testWidgets('natively a shader is disposed at once', (WidgetTester tester) async {
    final ui.FragmentShader shader = program.fragmentShader();
    releaseGlassShader(shader);
    expect(shader.debugDisposed, isTrue);
    expect(debugGlassShadersAwaitingRelease, 0);
  });

  group('on the web, outside a recording', () {
    setUp(() => debugReleaseGlassShadersAsOnWeb = true);

    testWidgets('a shader lives two frame ends, and asks for the frames itself', (WidgetTester tester) async {
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      final ui.FragmentShader shader = program.fragmentShader();
      releaseGlassShader(shader);
      expect(shader.debugDisposed, isFalse);
      // Nothing else is dirty: without the frame it asks for, an idle scene
      // would hold the shader until something repainted.
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump();
      expect(shader.debugDisposed, isFalse, reason: 'released at the first frame end');
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump();
      expect(shader.debugDisposed, isTrue);
      expect(debugGlassShadersAwaitingRelease, 0);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing left to release');
    });

    testWidgets('a shader queued while the countdown runs gets two frame ends of its own', (
      WidgetTester tester,
    ) async {
      final ui.FragmentShader first = program.fragmentShader();
      releaseGlassShader(first);
      await tester.pump();

      final ui.FragmentShader second = program.fragmentShader();
      releaseGlassShader(second);
      await tester.pump();
      expect(first.debugDisposed, isTrue);
      expect(second.debugDisposed, isFalse, reason: 'released with the shader queued a frame before it');

      await tester.pump();
      expect(second.debugDisposed, isTrue);
      expect(debugGlassShadersAwaitingRelease, 0);
    });

    testWidgets('a shader queued in a post-frame callback outlives the frame end under way', (
      WidgetTester tester,
    ) async {
      // The capture's callback runs before the countdown's in the same batch:
      // that frame end is the one the shader was drawn in, and does not count.
      late final ui.FragmentShader captured;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        captured = program.fragmentShader();
        releaseGlassShader(captured);
      });
      releaseGlassShader(program.fragmentShader());

      await tester.pump();
      expect(captured.debugDisposed, isFalse);
      await tester.pump();
      expect(captured.debugDisposed, isFalse, reason: 'released one frame end after the one that drew it');
      await tester.pump();
      expect(captured.debugDisposed, isTrue);
      expect(debugGlassShadersAwaitingRelease, 0);
    });
  });

  group('on the web, a GlassDrawLayer', () {
    setUp(() => debugReleaseGlassShadersAsOnWeb = true);

    late List<ui.FragmentShader> drawn;
    late List<Object?> at;
    late GlassDrawLayer layer;
    late LayerHandle<OffsetLayer> root;

    void composite() {
      root.layer!.buildScene(ui.SceneBuilder()).dispose();
    }

    setUp(() {
      drawn = <ui.FragmentShader>[];
      at = <Object?>[Offset.zero];
      layer = GlassDrawLayer()
        ..probe = (() => at)
        ..painter = (Canvas canvas) {
          final ui.FragmentShader shader = program.fragmentShader();
          drawn.add(shader);
          // The draw itself is beside the point (and would want a sampler):
          // what is checked is where the release goes while the layer records.
          canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), Paint());
          releaseGlassShader(shader);
        };
      root = LayerHandle<OffsetLayer>(OffsetLayer()..append(layer));
    });

    tearDown(() => root.layer = null);

    test('keeps its shaders with the picture, and records only when the probe changes', () {
      composite();
      composite();
      expect(layer.records, 1);
      expect(drawn, hasLength(1));
      expect(drawn.single.debugDisposed, isFalse);
      expect(debugGlassShadersAwaitingRelease, 0, reason: 'held by the layer, not the frame queue');

      at = <Object?>[const Offset(5, 0)];
      composite();
      expect(layer.records, 2);
      expect(layer.recordsOnMove, 1);
      expect(drawn.first.debugDisposed, isTrue, reason: 'its picture was re-recorded');
      expect(drawn.last.debugDisposed, isFalse);
    });

    test('releases them on invalidate and on dispose', () {
      composite();
      layer.invalidate();
      expect(drawn.single.debugDisposed, isTrue);

      composite();
      expect(layer.records, 2);
      expect(layer.recordsOnMove, 0, reason: 'invalidated, not moved');
      layer.remove();
      expect(drawn.last.debugDisposed, isTrue);
    });

    testWidgets('a painter that throws leaves no recording behind', (WidgetTester tester) async {
      layer.painter = (Canvas canvas) {
        releaseGlassShader(program.fragmentShader());
        throw StateError('painter');
      };
      expect(composite, throwsStateError);

      // Outside the layer again: a release goes to the frame queue.
      final ui.FragmentShader after = program.fragmentShader();
      releaseGlassShader(after);
      expect(debugGlassShadersAwaitingRelease, 1);
      await tester.pump();
      await tester.pump();
      expect(after.debugDisposed, isTrue);
    });
  });
}
