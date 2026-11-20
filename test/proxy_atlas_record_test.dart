// The atlas recorded from a scene, and a grouping held from an earlier pack.
//
// `flutter test test/proxy_atlas_record_test.dart`
//
// `AtlasLayout.record` is the replay the atlas's pixel test runs against: one
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
//  4. **A slot past the screen's edge holds the edge** (#42): with `screen`,
//     what lies past it is the screen's last texel on that side, corners
//     included, and what lies inside is the replay it always was; without it
//     the same texels are empty, which is the dark rim the issue showed.

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

  for (final double dpr in <double>[1, 2, 0.5]) {
    test('at $dpr texels per px, a slot past the screen\'s edge holds the edge, not nothing (#42)', () async {
      // A page with a band of its own colour along the right and bottom edges,
      // wider than a texel at every ratio, and glass past the bottom-right
      // corner by half its size.
      const edge = Color(0xFF2080E0);
      const bottom = Color(0xFFE0A020);
      final recorder = ui.PictureRecorder();
      Canvas(recorder, Offset.zero & kScene)
        ..drawRect(Offset.zero & kScene, Paint()..color = kPage)
        ..drawRect(Rect.fromLTRB(kScene.width - 4, 0, kScene.width, kScene.height), Paint()..color = edge)
        ..drawRect(Rect.fromLTRB(0, kScene.height - 4, kScene.width - 4, kScene.height), Paint()..color = bottom);
      final ui.Picture page = recorder.endRecording();
      addTearDown(page.dispose);

      const glass = Rect.fromLTWH(270, 180, 60, 40);
      final AtlasLayout layout = AtlasLayout.pack(const <Rect>[glass], pixelRatio: dpr, bleed: 12, align: 8);
      final AtlasSlot slot = layout.slots.single;
      final _Atlas clamped = await _Atlas.of(layout, layout.record(page, screen: Offset.zero & kScene));
      final _Atlas bare = await _Atlas.of(layout, layout.record(page));

      // Past the right edge, past the bottom edge, past the corner, deep and
      // shallow, each against the texel the screen holds on that side.
      final cases = <(Offset, Color, String)>[
        (Offset(kScene.width + 1, 175), edge, 'just past the right edge'),
        (Offset(kScene.width + 25, 175), edge, 'deep past the right edge'),
        (Offset(275, kScene.height + 1), bottom, 'just past the bottom edge'),
        (Offset(275, kScene.height + 20), bottom, 'deep past the bottom edge'),
        (Offset(kScene.width + 20, kScene.height + 20), edge, 'past the corner'),
      ];
      for (final (Offset p, Color want, String where) in cases) {
        expect(slot.source.contains(p), isTrue, reason: '$where is not in the slot: the case tests nothing');
        expect(clamped.at(slot.toAtlas(p)), want, reason: '$where at $dpr: not the screen\'s edge');
        expect(bare.alphaAt(slot.toAtlas(p)), 0, reason: '$where at $dpr: the control drew something there');
      }
      // Inside the screen the replay is the one it always was.
      for (final p in const <Offset>[Offset(268, 175), Offset(290, 185), Offset(285, 194)]) {
        expect(clamped.at(slot.toAtlas(p)), bare.at(slot.toAtlas(p)), reason: '$p at $dpr moved inside the screen');
      }
    });
  }

  test('a slot cut on one axis only holds the edge past it, and its other axis as it was (#42)', () async {
    // Past the right edge alone: the vertical axis lies inside the screen and
    // is drawn at the slot's own map, so the marks above and below survive.
    const edge = Color(0xFF2080E0);
    final recorder = ui.PictureRecorder();
    Canvas(recorder, Offset.zero & kScene)
      ..drawRect(Offset.zero & kScene, Paint()..color = kPage)
      ..drawRect(Rect.fromLTRB(kScene.width - 4, 0, kScene.width, kScene.height), Paint()..color = edge)
      ..drawRect(const Rect.fromLTWH(280, 72, 3, 3), Paint()..color = kMark);
    final ui.Picture page = recorder.endRecording();
    addTearDown(page.dispose);

    const glass = Rect.fromLTWH(270, 80, 60, 40);
    final AtlasLayout layout = AtlasLayout.pack(const <Rect>[glass], pixelRatio: 2, bleed: 10, align: 8);
    final AtlasSlot slot = layout.slots.single;
    final _Atlas clamped = await _Atlas.of(layout, layout.record(page, screen: Offset.zero & kScene));
    final _Atlas bare = await _Atlas.of(layout, layout.record(page));
    for (final double y in <double>[71, 100, 129]) {
      final p = Offset(kScene.width + 15, y);
      expect(clamped.at(slot.toAtlas(p)), edge, reason: 'past the edge at y $y');
      expect(bare.alphaAt(slot.toAtlas(p)), 0, reason: 'the control drew past the edge at y $y');
    }
    expect(clamped.at(slot.toAtlas(const Offset(281.5, 73.5))), kMark, reason: 'the mark inside moved');
  });

  test('a slot inside the screen is recorded as it was, and one wholly past it too', () async {
    const inside = Rect.fromLTWH(100, 60, 50, 40);
    const beyond = Rect.fromLTWH(400, 60, 50, 40);
    for (final Rect glass in const <Rect>[inside, beyond]) {
      final AtlasLayout layout = AtlasLayout.pack(<Rect>[glass], pixelRatio: 2, bleed: 4, align: 8);
      final _Atlas clamped = await _Atlas.of(layout, layout.record(scene, screen: Offset.zero & kScene));
      final _Atlas bare = await _Atlas.of(layout, layout.record(scene));
      final AtlasSlot slot = layout.slots.single;
      for (var x = 0.0; x < slot.rect.width; x += 7) {
        for (var y = 0.0; y < slot.rect.height; y += 7) {
          final p = Offset(slot.rect.left + x, slot.rect.top + y);
          expect(clamped.at(p), bare.at(p), reason: '$glass at $p');
        }
      }
    }
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
