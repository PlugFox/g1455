// The glass's draw, recorded when the frame is composited rather than when it
// is painted.
//
// A glass fragment samples the proxy at its place *on the screen*, and a
// fragment shader only knows its place in the layer it is drawn into — so
// every draw carries the surface's global origin as a uniform. Paint is the
// wrong time to read it: a surface is a repaint boundary, and a boundary that
// moves is not painted, its layer is re-offset (`PaintingContext._compositeChild`).
// So a glass that moved drew the backdrop of the place it had left, for one
// frame until the next publish repainted it — and for ever, once a declared
// travel region stopped the publish from happening (the arm in
// `glass_travel_test.dart` measured 4538 px of it at 37 px of motion).
//
// The framework's own answer to "this layer depends on where it ends up" is a
// layer that reads it at composite time — `FollowerLayer`. This is the same
// thing for a picture: the paint hands the layer everything that does not
// move, and `addToScene` reads where it is, which layout has settled by then,
// and re-records only when that changed.
//
// **The layer also owns the shaders its picture draws with, on the web.**
// CanvasKit hands a `FragmentShader`'s uniforms to Skia by pointer: the floats
// live in a buffer the shader mallocs, and `RuntimeEffect.makeShader` passes it
// as not-owned (`shouldOwnUniforms = !floats._ck`), so the `SkShader` recorded
// into the picture reads that buffer when the picture is *rasterized* — which
// is at the end of the frame, and again on every frame the picture is
// retained. A `dispose()` straight after the draw frees it first: the glass
// then drew from whatever reused the memory — a shape off by hundreds of
// pixels, a solid green or grey slab, a different picture each frame. Every
// Safari, which never gets Skwasm, drew that, and so does Chromium forced onto
// CanvasKit. [releaseGlassShader] is the one call a draw makes instead.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Releases [shader] once nothing drawn with it can be rasterized again.
///
/// Natively that is now: the engine copies the uniforms into the display list.
/// On the web it is when the picture the draw went into is disposed — the
/// [GlassDrawLayer]'s, when the draw is made while it records — or, for a draw
/// into any other picture (the capture of a level above), a frame after this
/// one, by which time that picture has been snapshotted and dropped.
void releaseGlassShader(ui.FragmentShader shader) {
  if (!kIsWeb) {
    shader.dispose();
    return;
  }
  final List<ui.FragmentShader>? recording = GlassDrawLayer._recording;
  if (recording != null) {
    recording.add(shader);
    return;
  }
  _releasedAfterFrame.add(shader);
  if (_releasedAfterFrame.length == 1) {
    _scheduleRelease(2);
  }
}

final List<ui.FragmentShader> _releasedAfterFrame = <ui.FragmentShader>[];

// Two frame ends rather than one: the frame that drew is not always rasterized
// by the time its own post-frame callbacks run.
void _scheduleRelease(int frames) {
  SchedulerBinding.instance.addPostFrameCallback((Duration _) {
    if (frames > 1) {
      _scheduleRelease(frames - 1);
      return;
    }
    final List<ui.FragmentShader> due = List<ui.FragmentShader>.of(_releasedAfterFrame);
    _releasedAfterFrame.clear();
    for (final ui.FragmentShader shader in due) {
      shader.dispose();
    }
  });
}

/// A leaf layer whose picture is a function of where its owner is on screen.
class GlassDrawLayer extends Layer {
  /// Returns what the picture depends on that paint cannot see — the owner's
  /// global geometry — as a list compared element-wise.
  List<Object?> Function()? probe;

  /// Draws the picture for the geometry [probe] just returned.
  void Function(Canvas canvas)? painter;

  ui.Picture? _picture;
  List<Object?>? _pictureAt;

  /// The shaders [_picture] was drawn with, released with it (web only; see
  /// [releaseGlassShader]).
  List<ui.FragmentShader> _shaders = <ui.FragmentShader>[];

  /// Where [releaseGlassShader] puts a shader while a layer records.
  static List<ui.FragmentShader>? _recording;

  /// How many times the picture was recorded, and how many of those were
  /// forced by the owner moving rather than by a paint.
  ///
  /// The trace the mechanism would otherwise not have: an arm that only checks
  /// the pixels passes as well on a surface that happened to be repainted by
  /// something else on the frame it moved.
  int records = 0;
  int recordsOnMove = 0;

  /// The paint changed what is drawn: the next composite records afresh.
  void invalidate() {
    _releasePicture();
    _pictureAt = null;
  }

  void _releasePicture() {
    _picture?.dispose();
    _picture = null;
    final List<ui.FragmentShader> shaders = _shaders;
    if (shaders.isNotEmpty) {
      _shaders = <ui.FragmentShader>[];
      for (final ui.FragmentShader shader in shaders) {
        shader.dispose();
      }
    }
  }

  // Every frame, because what the picture depends on is not a property of
  // this layer or of any layer above it that the framework would mark: a
  // re-offset ancestor re-adds its own layer and retains ours.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final List<Object?> at = probe?.call() ?? const <Object?>[];
    ui.Picture? picture = _picture;
    if (picture == null || !listEquals(at, _pictureAt)) {
      if (picture != null) {
        recordsOnMove++;
      }
      _releasePicture();
      final recorder = ui.PictureRecorder();
      final List<ui.FragmentShader>? outer = _recording;
      final shaders = <ui.FragmentShader>[];
      _recording = shaders;
      try {
        painter?.call(Canvas(recorder));
      } finally {
        _recording = outer;
      }
      picture = _picture = recorder.endRecording();
      _shaders = shaders;
      _pictureAt = at;
      records++;
    }
    builder.addPicture(Offset.zero, picture);
  }

  @override
  void dispose() {
    invalidate();
    super.dispose();
  }
}
