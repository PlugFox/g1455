// The atlas recorded from a scene, and a grouping held from an earlier pack.
//
// `flutter test test/proxy_atlas_record_test.dart`
//
// `AtlasLayout.record` is the replay the pixel test of D24 runs against: one
// clipped, translated, scaled replay of the scene per slot. The way it is
// silently wrong is a map that is self-consistent and not correct, so each arm
// reads a landmark through `AtlasSlot.toAtlas` and has a negative control:
//
//  1. **Every slot holds its own region of the scene**, read at a landmark
//     small enough that a one-texel shift misses it — and `jitter`, which
//     displaces one slot's content, makes exactly that slot miss.
//  2. **`clipToSource` stops the replay at the source's texels**, where the
//     slot's aligned rectangle is wider: the padding stays empty with it and
//     carries scene without it.
//  3. **A held grouping is honoured as given**, slot for slot, with each
//     slot's source the union of its members — and `usefulArea` counts those
//     sources and not the slots' padding.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_atlas.dart';
import 'package:g1455/src/proxy/proxy_retention.dart';

const Size kScene = Size(300, 200);
const Color kPage = Color(0xFF203040);
const Color kMark = Color(0xFFE02020);
const Color kOther = Color(0xFF20E060);

/// One small mark per surface, offset from the surface's centre so that a
/// map that swapped axes or dropped an origin lands on page.
const List<Rect> kSurfaces = <Rect>[Rect.fromLTWH(20, 30, 80, 50), Rect.fromLTWH(170, 110, 100, 60)];
Rect _markIn(Rect surface) => Rect.fromLTWH(surface.left + 13, surface.top + 9, 3, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Picture scene;
  setUp(() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & kScene)..drawRect(Offset.zero & kScene, Paint()..color = kPage);
    for (final Rect s in kSurfaces) {
      canvas
        ..drawRect(s, Paint()..color = kOther)
        ..drawRect(_markIn(s), Paint()..color = kMark);
    }
    scene = recorder.endRecording();
  });
  tearDown(() => scene.dispose());

  for (final double dpr in <double>[1, 2, 0.5]) {
    test('at $dpr texels per px, each slot holds its own surface, and a jittered slot does not', () async {
      final AtlasLayout layout = AtlasLayout.pack(kSurfaces, pixelRatio: dpr, align: 8);
      final _Atlas exact = await _Atlas.of(layout, layout.record(scene));
      final _Atlas jittered = await _Atlas.of(
        layout,
        layout.record(scene, jitter: (AtlasSlot s) => s.index == 1 ? Offset(6 * dpr, 0) : Offset.zero),
      );
      for (final AtlasSlot slot in layout.slots) {
        final Rect surface = kSurfaces[slot.members.single];
        final Offset mark = _markIn(surface).center;
        expect(exact.at(slot.toAtlas(mark)), kMark, reason: 'slot ${slot.index} at $dpr: the map is off');
        expect(exact.at(slot.toAtlas(surface.center)), kOther);
        expect(
          jittered.at(slot.toAtlas(mark)) == kMark,
          slot.index != 1,
          reason: 'jitter moved slot ${slot.index} at $dpr, or failed to move slot 1',
        );
      }
    });
  }

  test('clipToSource leaves a slot\'s aligned padding empty, where the plain replay fills it', () async {
    // An awkward width so the slot, aligned to 32 texels, is wider than its
    // source by a visible margin.
    const surfaces = <Rect>[Rect.fromLTWH(20, 30, 70, 50)];
    final AtlasLayout layout = AtlasLayout.pack(surfaces, align: 32);
    final AtlasSlot slot = layout.slots.single;
    final int span = texelSpan(slot.source.width, layout.pixelRatio);
    expect(slot.rect.width, greaterThan(span + 4), reason: 'no padding to test');
    final Offset padding = Offset(slot.rect.left + span + 2, slot.rect.top + 10);

    final _Atlas plain = await _Atlas.of(layout, layout.record(scene));
    final _Atlas clipped = await _Atlas.of(layout, layout.record(scene, clipToSource: true));
    expect(plain.alphaAt(padding), 255, reason: 'the plain replay draws the scene past the source');
    expect(clipped.alphaAt(padding), 0, reason: 'clipToSource replayed past the source');
    final Offset inside = slot.toAtlas(surfaces.single.center);
    expect(clipped.at(inside), plain.at(inside), reason: 'the clip cut into the source itself');
  });

  test('a held grouping is packed slot for slot, each source the union of its members', () {
    const surfaces = <Rect>[
      Rect.fromLTWH(10, 10, 40, 30),
      Rect.fromLTWH(200, 150, 50, 20),
      Rect.fromLTWH(60, 20, 30, 30),
    ];
    final AtlasLayout layout = AtlasLayout.pack(
      surfaces,
      pixelRatio: 2,
      bleed: 2,
      grouping: const <List<int>>[
        <int>[0, 2],
        <int>[1],
      ],
    );
    expect(layout.slots, hasLength(2));
    final AtlasSlot pair = layout.slots.firstWhere((AtlasSlot s) => s.members.length == 2);
    final AtlasSlot single = layout.slots.firstWhere((AtlasSlot s) => s.members.length == 1);
    expect(pair.members, <int>[0, 2]);
    expect(
      pair.source,
      snapToTexels(surfaces[0].inflate(2), 2).expandToInclude(snapToTexels(surfaces[2].inflate(2), 2)),
    );
    expect(single.members, <int>[1]);
    expect(single.source, snapToTexels(surfaces[1].inflate(2), 2));

    // What the slots' sources need, in device pixels — never more than what
    // the slots allocate, and exactly the sum of the two sources here.
    final double useful = usefulArea(layout);
    expect(
      useful,
      texelSpan(pair.source.width, 2) * texelSpan(pair.source.height, 2) +
          texelSpan(single.source.width, 2) * texelSpan(single.source.height, 2),
    );
    expect(useful, lessThanOrEqualTo(layout.slotArea));
  });
}

/// An atlas image's bytes, read by device-pixel position.
class _Atlas {
  _Atlas._(this._px, this._width, this._height);

  static Future<_Atlas> of(AtlasLayout layout, ui.Picture picture) async {
    final int w = layout.size.width.ceil();
    final int h = layout.size.height.ceil();
    final ui.Image image = picture.toImageSync(w, h);
    picture.dispose();
    final ByteData? data = await image.toByteData();
    image.dispose();
    return _Atlas._(data!.buffer.asUint8List(), w, h);
  }

  final Uint8List _px;
  final int _width;
  final int _height;

  int _index(Offset p) {
    final int x = p.dx.floor();
    final int y = p.dy.floor();
    // Refuse rather than clamp: a clamped read of an off-texture point returns
    // the edge, and an edge that happens to match is a pass for the wrong map.
    if (x < 0 || y < 0 || x >= _width || y >= _height) {
      throw RangeError('($x, $y) is outside the ${_width}x$_height atlas');
    }
    return (y * _width + x) * 4;
  }

  Color at(Offset p) {
    final int i = _index(p);
    return Color.fromARGB(_px[i + 3], _px[i], _px[i + 1], _px[i + 2]);
  }

  int alphaAt(Offset p) => _px[_index(p) + 3];
}
