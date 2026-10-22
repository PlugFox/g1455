// Shadows are not drawn into the proxy: behind the glass's blur, dropping them
// measured **0.00 ΔE** (with real, blurred shadows drawn), the only content
// degradation that costs nothing visible.
//
// **A per-node policy cannot express it.** A shadow is not a node. It is a
// `drawShadow` call inside `RenderPhysicalModel.paint`, or a `drawRRect` with a
// blur `MaskFilter` inside whatever `BoxDecoration.boxShadow` lowers to. Both
// happen inside foreign `paint()`, several frames down somebody else's call
// stack, and [WalkAction.skip] would take the node they belong to with them.
//
// So the policy sits one level lower, on the canvas — and it can, because
// `PaintingContext.canvas` is a plain getter (`object.dart:351-357`) and
// `ClipContext` reads the same getter (`painting/clip.dart:13`). A subclass
// returning a filtering canvas intercepts every draw the subtree makes, with
// nothing private involved. `GlassProxy.verbatim` is the subtree-sized way out
// of it, which exists because [ShadowFilter.dropMaskFiltered] is a heuristic.
//
// The price of the technique is this file's shape: `ui.Canvas` has 38 methods
// and Dart cannot forward them generically (`noSuchMethod` has nothing to
// forward *to*), so every one is written out. A method added to `Canvas`
// upstream is a compile error here rather than a silently dropped draw, which
// is the right way round.
//
// **What it cannot see into.** A `Picture` is opaque to Dart and a `Paragraph`
// keeps its styles to itself, so `drawPicture` and `drawParagraph` are
// forwarded whole: a blurred rect or a `drawShadow` recorded into a cached
// picture, and a `TextStyle.shadows` or a mask-filtered text `foreground`, all
// reach the capture. Measured on Skia and Impeller, a picture's blurred rect
// changes 3428 / 3208 px. Text shadows are kept on purpose — they are part of
// the glyphs, not a drop shadow under a box — and both draws are counted
// instead, on the filter, for an application that reads it to see where the
// filter was blind (#30). Nothing in the package reports them.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// What a draw has to look like to be dropped.
///
/// Two switches rather than one, because they catch different things and it
/// matters which fired: `drawShadow` is the physical-model route (`Material`
/// elevation), a blur `MaskFilter` is the `BoxShadow` route.
class ShadowFilter {
  /// A filter with both switches on by default.
  ShadowFilter({this.dropShadowCalls = true, this.dropMaskFiltered = true});

  /// Every `Canvas.drawShadow`: the physical-model route, exact rather than
  /// heuristic.
  final bool dropShadowCalls;

  /// Every draw the engine blurs through a `MaskFilter`.
  ///
  /// That is every draw that takes a paint except four: the shapes (`drawRect`,
  /// `drawRRect`, `drawDRRect`, `drawRSuperellipse`, `drawOval`, `drawCircle`,
  /// `drawArc`, `drawPath`), `drawPaint`, `drawLine`, `drawPoints`,
  /// `drawRawPoints`, `drawImage` and `drawImageRect` are dropped when their
  /// paint carries a mask filter. `drawImageNine`, `drawVertices`, `drawAtlas`
  /// and `drawRawAtlas` are forwarded whatever their paint carries, because
  /// the engine ignores the mask filter on them: measured on Skia and on
  /// Impeller, the same draw with and without a blur differs by no pixel,
  /// while the draws above differ by thousands. Those four are therefore
  /// never a soft shadow-like smear, and dropping them would take sharp,
  /// visible content out of the capture.
  ///
  /// Heuristic, and it has to be named as one: a blurred draw is *usually* a
  /// shadow, and a design that blurs a highlight on purpose would lose it. The
  /// two counters below are what makes the difference visible to an
  /// application that reads them, instead of in a screenshot.
  final bool dropMaskFiltered;

  /// `drawShadow` calls dropped so far.
  ///
  /// This and the counters below run over the filter's life, across every
  /// pass that draws through it, not per pass: a filter given to a host counts
  /// every frame it records. Compare two readings for one pass's share.
  int shadowCalls = 0;

  /// Mask-filtered draws dropped so far.
  ///
  /// A forwarded draw is not counted even when its paint carries a mask
  /// filter: the counter is the report of what the capture lost, and the four
  /// draws [dropMaskFiltered] forwards lose nothing.
  int maskFilteredDraws = 0;

  /// Every draw dropped so far, of either kind.
  int get dropped => shadowCalls + maskFilteredDraws;

  /// `drawPicture` calls forwarded whole so far.
  ///
  /// A picture's content is not reachable from Dart, so a shadow recorded
  /// into a cached `Picture` is drawn into the capture whatever the switches
  /// say. Not part of [dropped]: the count is of draws the filter could not
  /// look into, not of draws it took out.
  int picturesForwarded = 0;

  /// `drawParagraph` calls forwarded whole so far.
  ///
  /// `TextStyle.shadows` and a mask-filtered text `foreground` are inside the
  /// paragraph, out of the filter's reach, and kept: text is drawn as laid
  /// out. Not part of [dropped], for the same reason as [picturesForwarded].
  int paragraphsForwarded = 0;

  bool _dropPaint(ui.Paint paint) {
    if (dropMaskFiltered && paint.maskFilter != null) {
      maskFilteredDraws++;
      return true;
    }
    return false;
  }
}

/// A `Canvas` that forwards everything and refuses the draws a [ShadowFilter]
/// names.
///
/// Shadows inside a `Picture` or a `Paragraph` are not filtered: both are
/// forwarded whole and counted in [ShadowFilter.picturesForwarded] and
/// [ShadowFilter.paragraphsForwarded].
class FilteringCanvas implements Canvas {
  /// Wraps [inner], dropping what [filter] names.
  FilteringCanvas(this.inner, this.filter);

  /// The canvas being wrapped. Exposed so a caller can tell whether its
  /// wrapper is still the right one after the context started a new recording.
  final Canvas inner;

  /// Which draws to drop, and where they are counted.
  final ShadowFilter filter;

  @override
  void drawShadow(Path path, Color color, double elevation, bool transparentOccluder) {
    if (filter.dropShadowCalls) {
      filter.shadowCalls++;
      return;
    }
    inner.drawShadow(path, color, elevation, transparentOccluder);
  }

  // --- the draws that carry a paint, and can therefore carry a mask filter ---

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawLine(p1, p2, paint);
  }

  @override
  void drawPaint(Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawPaint(paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawRect(rect, paint);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawRRect(rrect, paint);
  }

  @override
  void drawDRRect(RRect outer, RRect innerRRect, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawDRRect(outer, innerRRect, paint);
  }

  @override
  void drawRSuperellipse(RSuperellipse rsuperellipse, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawRSuperellipse(rsuperellipse, paint);
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawOval(rect, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawCircle(c, radius, paint);
  }

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawPath(Path path, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawPath(path, paint);
  }

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawImage(image, offset, paint);
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawPoints(pointMode, points, paint);
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    if (filter._dropPaint(paint)) {
      return;
    }
    inner.drawRawPoints(pointMode, points, paint);
  }

  // --- the draws that carry a paint and are forwarded whatever it holds ---
  //
  // The engine draws these four sharp through a mask filter, measured on Skia
  // and on Impeller, so there is no shadow in them to drop; see
  // [ShadowFilter.dropMaskFiltered].

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) =>
      inner.drawImageNine(image, center, dst, paint);

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      inner.drawVertices(vertices, blendMode, paint);

  @override
  void drawAtlas(
    ui.Image atlas,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => inner.drawAtlas(atlas, transforms, rects, colors, blendMode, cullRect, paint);

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => inner.drawRawAtlas(atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);

  // --- everything else, forwarded unchanged ---

  @override
  void save() => inner.save();

  @override
  void saveLayer(Rect? bounds, Paint paint) => inner.saveLayer(bounds, paint);

  @override
  void restore() => inner.restore();

  @override
  void restoreToCount(int count) => inner.restoreToCount(count);

  @override
  int getSaveCount() => inner.getSaveCount();

  @override
  void translate(double dx, double dy) => inner.translate(dx, dy);

  @override
  void scale(double sx, [double? sy]) => inner.scale(sx, sy);

  @override
  void rotate(double radians) => inner.rotate(radians);

  @override
  void skew(double sx, double sy) => inner.skew(sx, sy);

  @override
  void transform(Float64List matrix4) => inner.transform(matrix4);

  @override
  Float64List getTransform() => inner.getTransform();

  @override
  void clipRect(Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) =>
      inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) => inner.clipRRect(rrect, doAntiAlias: doAntiAlias);

  @override
  void clipRSuperellipse(RSuperellipse rsuperellipse, {bool doAntiAlias = true}) =>
      inner.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) => inner.clipPath(path, doAntiAlias: doAntiAlias);

  @override
  Rect getLocalClipBounds() => inner.getLocalClipBounds();

  @override
  Rect getDestinationClipBounds() => inner.getDestinationClipBounds();

  @override
  void drawColor(Color color, BlendMode blendMode) => inner.drawColor(color, blendMode);

  // --- the draws the filter cannot look into, forwarded whole and counted ---

  @override
  void drawPicture(ui.Picture picture) {
    filter.picturesForwarded++;
    inner.drawPicture(picture);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    filter.paragraphsForwarded++;
    inner.drawParagraph(paragraph, offset);
  }
}
