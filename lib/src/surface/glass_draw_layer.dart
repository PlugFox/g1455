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

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// A leaf layer whose picture is a function of where its owner is on screen.
class GlassDrawLayer extends Layer {
  /// Returns what the picture depends on that paint cannot see — the owner's
  /// global geometry — as a list compared element-wise.
  List<Object?> Function()? probe;

  /// Draws the picture for the geometry [probe] just returned.
  void Function(Canvas canvas)? painter;

  ui.Picture? _picture;
  List<Object?>? _pictureAt;

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
    _picture?.dispose();
    _picture = null;
    _pictureAt = null;
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
      picture?.dispose();
      final recorder = ui.PictureRecorder();
      painter?.call(Canvas(recorder));
      picture = _picture = recorder.endRecording();
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
