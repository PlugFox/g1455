// What the proxy says about the level under each glass.
//
// The host already holds the pixels under every surface: they are the atlas,
// captured for the glass to sample. A surface that wants to know whether it is
// over something dark or something light can be told from there, and the only
// question is the price of asking — a GPU texture has to come back to the CPU,
// and that is the one operation this package otherwise never performs on a
// shipping frame.
//
// So the question is asked of as few pixels as can answer it. Each surface's
// box in the atlas is drawn into a cell of [ProxyReading.cell] × `cell` pixels
// of one small picture, which the GPU rasterizes into a texture a few dozen
// pixels wide — a downscale it does with the sampler it already has — and only
// that texture is read back. A screen of twenty surfaces is 80 × 4 pixels,
// 1280 bytes, where the atlas it summarises is several hundred thousand.
//
// The cell is sampled bilinearly ([FilterQuality.low], as the surfaces draw
// it), so each of its 16 texels is the average of four atlas texels and the
// cell's mean is the mean of 64 points spread over the box. The atlas is
// already a low-pass of the screen — a 1/N capture blurred by the finish's
// residual sigma — so 64 points of it are a mean of the box rather than a
// sample of its texture: the levels the branch switches on are tens of code
// values apart (`GlassFinish.kRegularSwitchLight`), and the detail a 4 × 4 cell
// can miss is the detail the blur has already removed.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'proxy_atlas.dart';

/// One surface's box in one atlas: what [ProxyReading.record] draws a cell
/// from.
typedef ProxyReadingSource = ({ui.Image image, Rect source});

/// The downscale and the arithmetic of a backdrop read-back. Stateless: the
/// host's reader owns when it runs.
abstract final class ProxyReading {
  /// The side of each surface's cell, in pixels.
  static const int cell = 4;

  /// Cells to a row of the read-back texture. Wide enough that a screen with
  /// any realistic count of glass is one row, and bounded so a pathological one
  /// stays far inside every texture limit (64 × 4 = 256 pixels a row).
  static const int columns = 64;

  /// Where [AtlasSlot] puts the global logical [box] in its atlas texture,
  /// clipped to the slot — the rectangle of texels the surface samples.
  ///
  /// The same map `RenderGlassSurface` draws through (`slot.toAtlas`), so the
  /// cell reads exactly the texels the glass shows, and none of the bleed
  /// around them that the slot keeps for the blur.
  static Rect sourceIn(AtlasSlot slot, Rect box) =>
      Rect.fromPoints(slot.toAtlas(box.topLeft), slot.toAtlas(box.bottomRight)).intersect(slot.rect);

  /// The size of the texture [record] draws for [count] cells.
  static Size sizeFor(int count) {
    final int across = count < columns ? count : columns;
    final int rows = (count + columns - 1) ~/ columns;
    return Size((across * cell).toDouble(), (rows * cell).toDouble());
  }

  /// Draws each of [sources] into its own cell, in order, left to right and
  /// then down.
  ///
  /// The picture holds its own reference to every image it draws, so the
  /// frames may be released once this returns — which is what lets the host
  /// rasterize it later, off the frame that captured them.
  static ui.Picture record(List<ProxyReadingSource> sources) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (var i = 0; i < sources.length; i++) {
      final ProxyReadingSource s = sources[i];
      if (s.source.isEmpty) {
        continue;
      }
      final double x = (i % columns * cell).toDouble();
      final double y = (i ~/ columns * cell).toDouble();
      canvas.drawImageRect(s.image, s.source, Rect.fromLTWH(x, y, cell.toDouble(), cell.toDouble()), paint);
    }
    return recorder.endRecording();
  }

  /// The mean colour of each of [count] cells in [rgba] — premultiplied RGBA
  /// rows of a texture [sizeFor] wide — or null for a cell with nothing in it.
  ///
  /// Weighted by coverage and divided by it, so a cell over a box that is
  /// partly transparent reports the colour of what is there and not that
  /// colour darkened by what is not. A cell with no coverage at all is a box
  /// nothing was painted under — the glass is over whatever is behind the
  /// host, which the capture cannot see — and gets no reading rather than a
  /// guess.
  static List<Color?> decode(ByteData rgba, int count) {
    final int width = sizeFor(count).width.toInt();
    final out = <Color?>[];
    for (var i = 0; i < count; i++) {
      final int x0 = i % columns * cell;
      final int y0 = i ~/ columns * cell;
      var r = 0;
      var g = 0;
      var b = 0;
      var a = 0;
      for (var y = y0; y < y0 + cell; y++) {
        for (var x = x0; x < x0 + cell; x++) {
          final int o = (y * width + x) * 4;
          r += rgba.getUint8(o);
          g += rgba.getUint8(o + 1);
          b += rgba.getUint8(o + 2);
          a += rgba.getUint8(o + 3);
        }
      }
      // Less than one texel's worth of coverage over the whole cell: nothing.
      if (a < 255) {
        out.add(null);
        continue;
      }
      out.add(Color.from(alpha: 1, red: r / a, green: g / a, blue: b / a));
    }
    return out;
  }

  /// Rasterizes [picture] at [sizeFor] `count` and reads it back, without
  /// blocking the frame that asked: both halves are engine futures, the first
  /// completed by the raster thread and the second by the copy back.
  ///
  /// Disposes [picture], and every image it makes, whatever happens.
  static Future<List<Color?>> read(ui.Picture picture, int count) async {
    final Size size = sizeFor(count);
    ui.Image? image;
    try {
      image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final ByteData? data = await image.toByteData();
      return data == null ? List<Color?>.filled(count, null) : decode(data, count);
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}
