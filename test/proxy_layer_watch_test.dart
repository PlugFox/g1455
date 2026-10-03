// The whitelist, audited against the SDK it is a whitelist of.
//
// `flutter test test/glass/proxy_layer_watch_test.dart`
//
// `ProxyLayerWatch` is the only thing standing between a held proxy and a
// stale picture, and D160 made it the thing a decision rests on: the cost of
// walking the layer tree is below what a device run can resolve, so the retention
// default stops being a question about price and becomes a question about this
// table. The lever is 79.4% and 66.3% of the addition on Adreno and 97.8% on
// Metal (D146); the cost of the error is the whole frame being wrong, silently,
// for as long as the screen keeps moving. So the error's probability is the
// probability of a hole in this table, and that is what this file measures.
//
// It measures it twice over, because the two halves fail differently.
//
// **The source half** reads `layer.dart` out of the SDK the test is running
// against and asserts two things the watch cannot assert about itself: that every
// concrete layer class in it is named — either as a type the table reads, or as
// one it deliberately refuses to read — and that every property a class hands to
// the `SceneBuilder` is either in the signature or listed below with the reason
// it is not. This is the half that fires on an SDK bump, which is the failure the
// whitelist rule was written for and the one no scene in this repository can
// produce. Its own control is a known wrong answer: the same check, run against a
// table with one entry removed, must name exactly that entry.
//
// **The behavioural half** builds each layer by hand, mutates one property and
// asserts the watch reports it — with, in the same arm, the frame where nothing
// was mutated at all. That control is not decoration: an oracle that answered
// "changed" unconditionally would pass every mutation arm here and would also
// destroy the whole mechanism, and it is exactly what a mistake in the guard
// produces.
//
// What the audit found when it was first run (D162): `BackdropFilterLayer`
// handed `backdropKey` to the engine and the signature did not read it, and the
// whitelist was matching subtypes where it meant to match types. Both are fixed
// in `lib/src/proxy/proxy_layer_watch.dart`; this file is what keeps them fixed.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_layer_watch.dart';

/// What the signature reads, per exact layer type, as the table claims it.
///
/// Keyed by the branch, not by the class that declares the property: a branch
/// answers for everything its class hands to the engine, inherited included, so
/// `TransformLayer` owing the `offset` it got from `OffsetLayer` is the point and
/// not an accident. An entry that is empty is a claim too — that the class
/// composites as a plain container.
const Map<String, Set<String>> _read = <String, Set<String>>{
  'PictureLayer': <String>{'picture'},
  'ContainerLayer': <String>{},
  'OffsetLayer': <String>{'offset'},
  'OpacityLayer': <String>{'alpha', 'offset'},
  'ImageFilterLayer': <String>{'imageFilter', 'offset'},
  'TransformLayer': <String>{'transform', 'offset'},
  'ClipRectLayer': <String>{'clipRect', 'clipBehavior'},
  'ClipRRectLayer': <String>{'clipRRect', 'clipBehavior'},
  'ClipRSuperellipseLayer': <String>{'clipRSuperellipse', 'clipBehavior'},
  'ClipPathLayer': <String>{'clipPath', 'clipBehavior'},
  'ColorFilterLayer': <String>{'colorFilter'},
  'ShaderMaskLayer': <String>{'shader', 'maskRect', 'blendMode'},
  'BackdropFilterLayer': <String>{'filter', 'blendMode', 'backdropKey'},
  'LeaderLayer': <String>{'link', 'offset'},
  'AnnotatedRegionLayer': <String>{},
};

/// Types the table refuses to read, and why each one cannot be read.
///
/// These are not gaps: a type here reports a change on every frame it is
/// present, which costs retention and never costs correctness.
const Map<String, String> _unknown = <String, String>{
  'TextureLayer': 'its pixels arrive from outside Dart and change with nothing in the tree',
  'PlatformViewLayer': 'the same, by way of the platform',
  'PerformanceOverlayLayer': 'it animates on its own, and it is a debugging overlay',
  'FollowerLayer': 'its transform belongs to a leader somewhere else in the tree',
};

/// Properties that reach `addToScene` and are deliberately not in the signature.
///
/// Keyed by the class that declares the setter. Each one is a claim that the
/// property changes no pixel, and each is the reason the audit below is not
/// simply "every setter must be read".
const Map<String, String> _ignored = <String, String>{
  'Layer.engineLayer': 'the handle `addToScene` writes for itself; it holds the last frame, not this one',
  'PictureLayer.isComplexHint': 'a raster-cache hint — it changes what the engine caches, never what it draws',
  'PictureLayer.willChangeHint': 'the same hint, in the other direction',
};

void main() {
  group('the table against the SDK it is a table of', () {
    // Parsed inside the arms rather than in the group body, because reading the
    // SDK is itself a thing that can fail and a failure out here is a file that
    // does not load.
    test('the parse read layer.dart and not an empty string', () {
      final Map<String, _SdkClass> classes = _classes;
      final Map<String, _SdkClass> concrete = _concrete;
      // The control the source half needs first. Every assertion below is of the
      // form "everything found is accounted for", and a parse that found nothing
      // satisfies all of them — the same way a negative control whose samples all
      // fall off the texture compares nothing and reports that everything
      // matched. So the parse states its own counts, and one property it must
      // have seen, before anything is concluded from it.
      expect(
        concrete.length,
        greaterThanOrEqualTo(16),
        reason:
            'layer.dart had 16 concrete layer classes at 3.47 and does not shrink; '
            'the parse found ${concrete.length}, so the parse is what broke',
      );
      expect(
        classes.values.fold<int>(0, (int n, _SdkClass c) => n + c.setters.length),
        greaterThanOrEqualTo(25),
        reason: 'there were 27 setters at 3.47',
      );
      expect(
        classes.values.where((_SdkClass c) => c.addToScene != null).length,
        greaterThanOrEqualTo(13),
        reason: 'every class that composites anything of its own overrides addToScene',
      );
      expect(
        classes['BackdropFilterLayer']?.setters,
        contains('backdropKey'),
        reason: 'the property whose absence from the signature this audit was written to find',
      );
      expect(
        classes['BackdropFilterLayer']?.addToScene,
        contains('backdropId'),
        reason: 'and the line that proves it reaches the engine',
      );
      expect(
        classes['AnnotatedRegionLayer']?.addToScene,
        isNull,
        reason:
            'the one type matched by subtype rather than by identity is safe to match that way '
            'only while it composites as a plain container, which is this',
      );
    });

    test('every layer class in the SDK is named, one way or the other', () {
      final Map<String, _SdkClass> concrete = _concrete;
      // The arm that fires on the next SDK. A class it adds is a class this
      // package has never read: it belongs in `_unknown` until somebody reads it,
      // and the point of failing here is that nothing else in the repository can
      // tell the difference — a type nobody wrote a scene for is a type no scene
      // exercises.
      expect(
        concrete.keys.toSet().difference(<String>{..._read.keys, ..._unknown.keys}),
        isEmpty,
        reason: 'layer.dart has a type the whitelist has never seen',
      );
      expect(
        <String>{..._read.keys, ..._unknown.keys}.difference(concrete.keys.toSet()),
        isEmpty,
        reason:
            'the whitelist has a branch for a type the SDK no longer has, which is a branch '
            'nothing can reach and a rename nobody noticed',
      );
    });

    test('every property a layer hands to the engine is read or refused in writing', () {
      expect(_violations(_classes, _read), isEmpty);
    });

    test('and the same check, given a known wrong answer, finds it', () {
      // The control for the check itself, and the record of what the first run of
      // it found. Drop the property D162 added and the audit must name it — an
      // audit that passes a table with a hole in it is prose with a test around
      // it.
      final Map<String, Set<String>> holed = <String, Set<String>>{
        ..._read,
        'BackdropFilterLayer': <String>{'filter', 'blendMode'},
      };
      expect(_violations(_classes, holed), <String>['BackdropFilterLayer.backdropKey']);
    });
  });

  group('what the table claims to read, read back off a layer', () {
    for (final _Case arm in _cases) {
      test(arm.name, () {
        final ContainerLayer root = ContainerLayer();
        final Layer layer = arm.build();
        root.append(layer);
        final ProxyLayerWatch watch = ProxyLayerWatch();

        expect(
          watch.changeSince(root).changed,
          isTrue,
          reason: 'the first frame has nothing to compare against',
        );
        expect(
          watch.changeSince(root).changed,
          isFalse,
          reason:
              'nothing was touched, and an oracle that answers "changed" here passes every '
              'mutation arm in this file for the wrong reason — and holds nothing, ever',
        );

        arm.mutate(layer);
        expect(
          watch.changeSince(root).changed,
          isTrue,
          reason: '${arm.name} reaches the engine, and the signature did not see it move',
        );
      });
    }

    test('a subtree that moved between parents is seen, though no layer changed', () {
      // What the end-of-subtree marker is for: the signature is flat, so two
      // different shapes can hold the same layers in the same order.
      final ContainerLayer root = ContainerLayer();
      final ContainerLayer first = ContainerLayer();
      final ContainerLayer second = ContainerLayer();
      // Held by a handle across the move: `remove()` drops the parent's handle,
      // and a layer whose last handle goes is disposed on the spot.
      final LayerHandle<OffsetLayer> moving = LayerHandle<OffsetLayer>(
        OffsetLayer(offset: const Offset(3, 4)),
      );
      root
        ..append(first)
        ..append(second);
      first.append(moving.layer!);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      expect(watch.changeSince(root).changed, isFalse);

      moving.layer!.remove();
      second.append(moving.layer!);
      expect(
        watch.changeSince(root).changed,
        isTrue,
        reason:
            'the same three layers with the same properties in the same order, '
            'and a different screen',
      );
    });
  });

  group('where it changed, and not only that it did', () {
    // D174. §4.2 of the research document is one sentence — "a shared texture
    // is a shared dirty flag: a spinner behind button A invalidates the whole
    // cluster" — and every term of it is about regions. Until this group the
    // watch answered with a bit, so the package had one dirty flag for the whole
    // screen and a spinner in a corner re-recorded a proxy of the other corner.
    //
    // What the region has to be is *conservative and tight enough to be worth
    // having*, and those pull opposite ways. So each arm below names the rect it
    // expects rather than asserting a property of it: a bound that is merely
    // "somewhere" passes every property test and buys nothing.

    /// Builds `root -> OffsetLayer(offset) -> PictureLayer(bounds)` and returns
    /// the picture layer, so an arm can replace what it holds.
    PictureLayer pictureAt(ContainerLayer root, Offset offset, Rect bounds) {
      final OffsetLayer holder = OffsetLayer(offset: offset);
      final leaf = PictureLayer(bounds);
      leaf.picture = _picture(bounds);
      holder.append(leaf);
      root.append(holder);
      return leaf;
    }

    test('a repaint is bounded by the layer that holds it, mapped into root space', () {
      final ContainerLayer root = ContainerLayer();
      final PictureLayer leaf = pictureAt(root, const Offset(100, 200), const Rect.fromLTWH(10, 10, 40, 30));
      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      expect(watch.changeSince(root).changed, isFalse);

      leaf.picture = _picture(const Rect.fromLTWH(10, 10, 40, 30));
      final LayerChange change = watch.changeSince(root);
      expect(change.changed, isTrue);
      expect(change.bounded, isTrue);
      expect(change.region, const Rect.fromLTRB(110, 210, 150, 240));
      // And the two questions the pipeline actually asks it.
      expect(change.touches(const Rect.fromLTWH(140, 230, 20, 20)), isTrue);
      expect(change.touches(const Rect.fromLTWH(0, 0, 100, 100)), isFalse);
    });

    test('a subtree that moved is dirty where it was and where it went', () {
      // The arm that says the bound is not simply "the new bounds". A panel
      // sliding 60 px leaves the pixels it vacated as wrong as the ones it took,
      // and a region that only covered the arrival would hold a proxy with a
      // ghost in it.
      final ContainerLayer root = ContainerLayer();
      final OffsetLayer holder = OffsetLayer(offset: const Offset(0, 0));
      final leaf = PictureLayer(const Rect.fromLTWH(0, 0, 50, 20));
      leaf.picture = _picture(const Rect.fromLTWH(0, 0, 50, 20));
      holder.append(leaf);
      root.append(holder);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      holder.offset = const Offset(0, 60);
      final LayerChange change = watch.changeSince(root);
      expect(change.region, const Rect.fromLTRB(0, 0, 50, 80));
    });

    test('a clip above it narrows the region, and can empty it', () {
      final ContainerLayer root = ContainerLayer();
      final clip = ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 120, 120));
      root.append(clip);
      final leaf = PictureLayer(const Rect.fromLTWH(100, 100, 80, 80));
      leaf.picture = _picture(const Rect.fromLTWH(100, 100, 80, 80));
      clip.append(leaf);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      leaf.picture = _picture(const Rect.fromLTWH(100, 100, 80, 80));
      expect(watch.changeSince(root).region, const Rect.fromLTRB(100, 100, 120, 120));

      // The same repaint under a clip that excludes it entirely: seen, and
      // reaching nothing. Held rather than recorded, and this is the one case
      // where "changed" and "touches anything" genuinely disagree.
      clip.clipRect = const Rect.fromLTWH(0, 0, 20, 20);
      expect(watch.changeSince(root).changed, isTrue);
      leaf.picture = _picture(const Rect.fromLTWH(100, 100, 80, 80));
      final LayerChange change = watch.changeSince(root);
      expect(change.changed, isTrue);
      expect(change.bounded, isTrue);
      expect(change.region, isNull);
      expect(change.touches(const Rect.fromLTWH(100, 100, 80, 80)), isFalse);
    });

    test('a clip outside the clip above it empties the subtree rather than freeing it', () {
      // `null` in this walk means *unclipped*, so a clip that falls entirely
      // outside its parent's must not be reported as "no clip" — that widens
      // the region instead of emptying it, in the safe direction and silently
      // wrong. The arm renders the two clips nested and the picture inside the
      // inner one, which is visible to nobody.
      final ContainerLayer root = ContainerLayer();
      final outer = ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 50, 50));
      final inner = ClipRectLayer(clipRect: const Rect.fromLTWH(200, 200, 50, 50));
      root.append(outer);
      outer.append(inner);
      final leaf = PictureLayer(const Rect.fromLTWH(200, 200, 50, 50));
      leaf.picture = _picture(const Rect.fromLTWH(200, 200, 50, 50));
      inner.append(leaf);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      leaf.picture = _picture(const Rect.fromLTWH(200, 200, 50, 50));
      final LayerChange change = watch.changeSince(root);
      expect(change.changed, isTrue);
      expect(change.bounded, isTrue);
      expect(change.region, isNull);
      expect(change.touches(const Rect.fromLTWH(0, 0, 1000, 1000)), isFalse);

      // And the same shape with a filter in it, because the filter's branch
      // reads the clip directly and is the one place `Rect.zero` could be
      // unioned into a region as a dirty pixel at the origin.
      final ContainerLayer filteredRoot = ContainerLayer();
      final far = ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 50, 50));
      final away = ClipRectLayer(clipRect: const Rect.fromLTWH(200, 200, 50, 50));
      filteredRoot.append(far);
      far.append(away);
      final blurred = ImageFilterLayer(imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
      away.append(blurred);
      final hidden = PictureLayer(const Rect.fromLTWH(200, 200, 50, 50));
      hidden.picture = _picture(const Rect.fromLTWH(200, 200, 50, 50));
      blurred.append(hidden);

      final ProxyLayerWatch second = ProxyLayerWatch();
      expect(second.changeSince(filteredRoot).changed, isTrue);
      hidden.picture = _picture(const Rect.fromLTWH(200, 200, 50, 50));
      final LayerChange filtered = second.changeSince(filteredRoot);
      expect(filtered.region, isNull);
      expect(filtered.touches(const Rect.fromLTWH(0, 0, 1, 1)), isFalse);
    });

    test('a transform is applied the way the engine applies it', () {
      // `translate(offset) * transform`, not the other order. The arm exists
      // because the two agree whenever one of them is the identity, which is
      // most trees — and disagree by `offset` scaled, which is exactly the size
      // of a region that would then miss the glass.
      final ContainerLayer root = ContainerLayer();
      final scaled = TransformLayer(
        offset: const Offset(10, 0),
        transform: Matrix4.diagonal3Values(2, 2, 1),
      );
      root.append(scaled);
      final leaf = PictureLayer(const Rect.fromLTWH(5, 5, 10, 10));
      leaf.picture = _picture(const Rect.fromLTWH(5, 5, 10, 10));
      scaled.append(leaf);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      leaf.picture = _picture(const Rect.fromLTWH(5, 5, 10, 10));
      expect(watch.changeSince(root).region, const Rect.fromLTRB(20, 10, 40, 30));
    });

    test('a filter has no bound in Dart, so the region is the clip above it', () {
      // The honest refusal. `ui.ImageFilter` will not say how far it moves a
      // pixel, so a blurred subtree is dirty everywhere its clip allows — and
      // with no clip at all, everywhere.
      final ContainerLayer root = ContainerLayer();
      final filtered = ImageFilterLayer(imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4));
      root.append(filtered);
      final leaf = PictureLayer(const Rect.fromLTWH(10, 10, 20, 20));
      leaf.picture = _picture(const Rect.fromLTWH(10, 10, 20, 20));
      filtered.append(leaf);

      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      leaf.picture = _picture(const Rect.fromLTWH(10, 10, 20, 20));
      final LayerChange change = watch.changeSince(root);
      expect(change.bounded, isFalse);
      expect(change.touches(const Rect.fromLTWH(900, 900, 10, 10)), isTrue);

      // Under a clip it is the clip, which is a real bound and a useful one:
      // a `BackdropFilter` inside a card is dirty over the card.
      final ContainerLayer clipped = ContainerLayer();
      final bound = ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 60, 60));
      clipped.append(bound);
      final ImageFilterLayer inner = ImageFilterLayer(
        imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      );
      bound.append(inner);
      final deep = PictureLayer(const Rect.fromLTWH(10, 10, 20, 20));
      deep.picture = _picture(const Rect.fromLTWH(10, 10, 20, 20));
      inner.append(deep);
      final ProxyLayerWatch second = ProxyLayerWatch();
      expect(second.changeSince(clipped).changed, isTrue);
      deep.picture = _picture(const Rect.fromLTWH(10, 10, 20, 20));
      final LayerChange narrow = second.changeSince(clipped);
      expect(narrow.bounded, isTrue);
      expect(narrow.region, const Rect.fromLTRB(0, 0, 60, 60));
    });

    test('a layer type the table cannot read is dirty everywhere, as it is unheld', () {
      // The whitelist rule, restated for the region: not knowing what a layer
      // draws is not knowing where it draws either, and the two refusals have to
      // agree or the second one silently undoes the first.
      final ContainerLayer root = ContainerLayer();
      root.append(TextureLayer(rect: const Rect.fromLTWH(0, 0, 8, 8), textureId: 1));
      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      final LayerChange change = watch.changeSince(root);
      expect(change.changed, isTrue);
      expect(change.bounded, isFalse, reason: 'an unreadable layer was given a bound');
    });

    test('nothing changed is not a region at all', () {
      final ContainerLayer root = ContainerLayer();
      pictureAt(root, Offset.zero, const Rect.fromLTWH(0, 0, 10, 10));
      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      final LayerChange still = watch.changeSince(root);
      expect(still.changed, isFalse);
      expect(still.touches(const Rect.fromLTWH(0, 0, 1000, 1000)), isFalse);
    });
  });

  group('what the table refuses to read is never held through', () {
    final Map<String, Layer Function()> valves = <String, Layer Function()>{
      'TextureLayer': () => TextureLayer(rect: const Rect.fromLTWH(0, 0, 8, 8), textureId: 1),
      'PlatformViewLayer': () => PlatformViewLayer(rect: const Rect.fromLTWH(0, 0, 8, 8), viewId: 1),
      'PerformanceOverlayLayer': () =>
          PerformanceOverlayLayer(overlayRect: const Rect.fromLTWH(0, 0, 8, 8), optionsMask: 0),
      'FollowerLayer': () => FollowerLayer(link: LayerLink()),
      'a ContainerLayer subclass nobody has read': _StrangeContainerLayer.new,
      // The arm the exactness guard exists for. Before D162 this landed on the
      // `OpacityLayer` branch, was described by an alpha and an offset, and was
      // held through whatever else it composited.
      'an OpacityLayer subclass nobody has read': () => _StrangeOpacityLayer(alpha: 128),
    };

    for (final MapEntry<String, Layer Function()> valve in valves.entries) {
      test('${valve.key} reports a change on every frame', () {
        final ContainerLayer root = ContainerLayer();
        root.append(valve.value());
        final ProxyLayerWatch watch = ProxyLayerWatch();
        expect(watch.changeSince(root).changed, isTrue);
        expect(
          watch.changeSince(root).changed,
          isTrue,
          reason: 'a layer nobody can read was held through, which is a wrong picture waiting',
        );
      });
    }

    test('an AnnotatedRegionLayer is held through, because it composites nothing', () {
      // The one type in the table matched by subtype, and the arm that says it is
      // in the table at all: an annotation is how the framework carries an
      // overlay style, so refusing to hold through it would cost every `Scaffold`
      // its retention. What makes that safe is asserted off the SDK source above
      // — the class does not override `addToScene`.
      final ContainerLayer root = ContainerLayer();
      root.append(AnnotatedRegionLayer<Object>(Object(), size: const Size(8, 8)));
      final ProxyLayerWatch watch = ProxyLayerWatch();
      expect(watch.changeSince(root).changed, isTrue);
      expect(watch.changeSince(root).changed, isFalse);
    });
  });
}

/// One property of one layer type, mutated the way the framework mutates it.
class _Case {
  const _Case(this.name, {required this.build, required this.mutate});

  final String name;
  final Layer Function() build;
  final void Function(Layer layer) mutate;
}

final List<_Case> _cases = <_Case>[
  _Case(
    'PictureLayer.picture',
    build: () => PictureLayer(const Rect.fromLTWH(0, 0, 8, 8))..picture = _picture(),
    // A repaint mints a new picture rather than editing the old one, so identity
    // is the whole of this arm: the two pictures here draw the same rectangle.
    mutate: (Layer l) => (l as PictureLayer).picture = _picture(),
  ),
  _Case(
    'OffsetLayer.offset',
    build: () => OffsetLayer(offset: const Offset(1, 2)),
    mutate: (Layer l) => (l as OffsetLayer).offset = const Offset(1, 3),
  ),
  _Case(
    'OpacityLayer.alpha',
    build: () => OpacityLayer(alpha: 255),
    mutate: (Layer l) => (l as OpacityLayer).alpha = 128,
  ),
  _Case(
    'OpacityLayer.offset',
    build: () => OpacityLayer(alpha: 255),
    mutate: (Layer l) => (l as OpacityLayer).offset = const Offset(0, 5),
  ),
  _Case(
    'ImageFilterLayer.imageFilter',
    build: () => ImageFilterLayer(imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1)),
    mutate: (Layer l) => (l as ImageFilterLayer).imageFilter = ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
  ),
  _Case(
    'ImageFilterLayer.offset',
    build: () => ImageFilterLayer(imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1)),
    mutate: (Layer l) => (l as ImageFilterLayer).offset = const Offset(0, 5),
  ),
  _Case(
    'TransformLayer.transform',
    build: () => TransformLayer(transform: Matrix4.identity()),
    mutate: (Layer l) => (l as TransformLayer).transform = Matrix4.translationValues(1, 0, 0),
  ),
  _Case(
    'TransformLayer.offset',
    build: () => TransformLayer(transform: Matrix4.identity()),
    mutate: (Layer l) => (l as TransformLayer).offset = const Offset(0, 5),
  ),
  _Case(
    'ClipRectLayer.clipRect',
    build: () => ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 8, 8)),
    mutate: (Layer l) => (l as ClipRectLayer).clipRect = const Rect.fromLTWH(0, 0, 8, 9),
  ),
  _Case(
    'ClipRectLayer.clipBehavior',
    build: () => ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 8, 8)),
    mutate: (Layer l) => (l as ClipRectLayer).clipBehavior = ui.Clip.antiAliasWithSaveLayer,
  ),
  _Case(
    'ClipRRectLayer.clipRRect',
    build: () => ClipRRectLayer(clipRRect: _rrect(4)),
    mutate: (Layer l) => (l as ClipRRectLayer).clipRRect = _rrect(6),
  ),
  _Case(
    'ClipRRectLayer.clipBehavior',
    build: () => ClipRRectLayer(clipRRect: _rrect(4)),
    mutate: (Layer l) => (l as ClipRRectLayer).clipBehavior = ui.Clip.antiAliasWithSaveLayer,
  ),
  _Case(
    'ClipRSuperellipseLayer.clipRSuperellipse',
    build: () => ClipRSuperellipseLayer(clipRSuperellipse: _superellipse(4)),
    mutate: (Layer l) => (l as ClipRSuperellipseLayer).clipRSuperellipse = _superellipse(6),
  ),
  _Case(
    'ClipRSuperellipseLayer.clipBehavior',
    build: () => ClipRSuperellipseLayer(clipRSuperellipse: _superellipse(4)),
    mutate: (Layer l) => (l as ClipRSuperellipseLayer).clipBehavior = ui.Clip.antiAliasWithSaveLayer,
  ),
  _Case(
    'ClipPathLayer.clipPath',
    build: () => ClipPathLayer(clipPath: _path()),
    // By identity, like the picture: `Path` has no equality, and the two paths
    // here enclose the same square.
    mutate: (Layer l) => (l as ClipPathLayer).clipPath = _path(),
  ),
  _Case(
    'ClipPathLayer.clipBehavior',
    build: () => ClipPathLayer(clipPath: _path()),
    mutate: (Layer l) => (l as ClipPathLayer).clipBehavior = ui.Clip.antiAliasWithSaveLayer,
  ),
  _Case(
    'ColorFilterLayer.colorFilter',
    build: () => ColorFilterLayer(
      colorFilter: const ui.ColorFilter.mode(ui.Color(0xFF00FF00), ui.BlendMode.srcIn),
    ),
    mutate: (Layer l) =>
        (l as ColorFilterLayer).colorFilter = const ui.ColorFilter.mode(ui.Color(0xFFFF0000), ui.BlendMode.srcIn),
  ),
  _Case(
    'ShaderMaskLayer.shader',
    build: () => ShaderMaskLayer(
      shader: _shader(),
      maskRect: const Rect.fromLTWH(0, 0, 8, 8),
      blendMode: ui.BlendMode.modulate,
    ),
    mutate: (Layer l) => (l as ShaderMaskLayer).shader = _shader(),
  ),
  _Case(
    'ShaderMaskLayer.maskRect',
    build: () => ShaderMaskLayer(
      shader: _shader(),
      maskRect: const Rect.fromLTWH(0, 0, 8, 8),
      blendMode: ui.BlendMode.modulate,
    ),
    mutate: (Layer l) => (l as ShaderMaskLayer).maskRect = const Rect.fromLTWH(0, 0, 8, 9),
  ),
  _Case(
    'ShaderMaskLayer.blendMode',
    build: () => ShaderMaskLayer(
      shader: _shader(),
      maskRect: const Rect.fromLTWH(0, 0, 8, 8),
      blendMode: ui.BlendMode.modulate,
    ),
    mutate: (Layer l) => (l as ShaderMaskLayer).blendMode = ui.BlendMode.srcOver,
  ),
  _Case(
    'BackdropFilterLayer.filter',
    build: () => BackdropFilterLayer(filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1)),
    mutate: (Layer l) => (l as BackdropFilterLayer).filter = ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
  ),
  _Case(
    'BackdropFilterLayer.blendMode',
    build: () => BackdropFilterLayer(filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1)),
    mutate: (Layer l) => (l as BackdropFilterLayer).blendMode = ui.BlendMode.plus,
  ),
  _Case(
    // D162: the property the audit found missing. `RenderBackdropFilter` keeps
    // its layer and assigns this, so the whole change is one field of one
    // retained layer — which is the class of change this oracle exists for.
    'BackdropFilterLayer.backdropKey',
    build: () => BackdropFilterLayer(filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1))..backdropKey = BackdropKey(),
    mutate: (Layer l) => (l as BackdropFilterLayer).backdropKey = BackdropKey(),
  ),
  _Case(
    'LeaderLayer.link',
    build: () => LeaderLayer(link: LayerLink()),
    mutate: (Layer l) => (l as LeaderLayer).link = LayerLink(),
  ),
  _Case(
    'LeaderLayer.offset',
    build: () => LeaderLayer(link: LayerLink(), offset: const Offset(1, 2)),
    mutate: (Layer l) => (l as LeaderLayer).offset = const Offset(1, 3),
  ),
];

/// A fresh picture every call, which is what a repaint mints and what the
/// signature compares by identity.
ui.Picture _picture([Rect bounds = const Rect.fromLTWH(0, 0, 4, 4)]) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder, bounds).drawRect(bounds, ui.Paint());
  return recorder.endRecording();
}

ui.Path _path() => ui.Path()..addRect(const Rect.fromLTWH(0, 0, 8, 8));

ui.Shader _shader() => ui.Gradient.linear(Offset.zero, const Offset(8, 8), const <ui.Color>[
  ui.Color(0xFF000000),
  ui.Color(0xFFFFFFFF),
]);

RRect _rrect(double radius) => RRect.fromRectXY(const Rect.fromLTWH(0, 0, 8, 8), radius, radius);

RSuperellipse _superellipse(double radius) => RSuperellipse.fromRectXY(const Rect.fromLTWH(0, 0, 8, 8), radius, radius);

class _StrangeContainerLayer extends ContainerLayer {}

class _StrangeOpacityLayer extends OpacityLayer {
  _StrangeOpacityLayer({super.alpha});
}

// ---------------------------------------------------------------------------
// The SDK half: `layer.dart` as the test's input.
// ---------------------------------------------------------------------------

/// One class as `layer.dart` declares it.
class _SdkClass {
  _SdkClass(this.name, this.superclass);

  final String name;
  final String? superclass;
  final Set<String> setters = <String>{};

  /// The body of its own `addToScene`, or null when it inherits one.
  String? addToScene;
}

/// `layer.dart` out of the SDK this test is running against.
///
/// Resolved through `package_config.json` rather than an environment variable,
/// so that the file read is the one the test was compiled against — a different
/// SDK would move both together.
String _layerDartSource() {
  final File config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    throw StateError(
      'no .dart_tool/package_config.json: run from the package root, '
      'which is where `flutter test` runs',
    );
  }
  final Map<String, Object?> decoded = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> flutter = (decoded['packages']! as List<Object?>).cast<Map<String, Object?>>().firstWhere(
    (Map<String, Object?> p) => p['name'] == 'flutter',
  );
  final Uri root = config.absolute.parent.uri.resolve('${flutter['rootUri']!}/');
  final File source = File.fromUri(root.resolve('lib/src/rendering/layer.dart'));
  if (!source.existsSync()) {
    throw StateError('no layer.dart at ${source.path}');
  }
  return source.readAsStringSync();
}

/// `layer.dart` parsed once, on first use.
final Map<String, _SdkClass> _classes = _parseLayerDart();

/// The concrete layer classes in it — what the whitelist must account for.
final Map<String, _SdkClass> _concrete = <String, _SdkClass>{
  for (final MapEntry<String, _SdkClass> e in _classes.entries)
    if (e.key != 'Layer' && e.key.endsWith('Layer') && _descendsFromLayer(e.key, _classes)) e.key: e.value,
};

// Every class declaration, extending something or not: `LayerHandle` extends
// nothing and declares `set layer(T?)`, and a parse that skipped its header
// attributed that setter to `Layer` — where it was inherited by the whole tree
// and reported as two violations that were the parser's own.
final RegExp _classHeader = RegExp(
  r'^(?:abstract |final |base |sealed |interface )*class (\w+)(?:<[^>]*>)?(?:\s+extends\s+(\w+))?',
);
final RegExp _setter = RegExp(r'^  set (\w+)\(');
final RegExp _addToScene = RegExp(r'^  void addToScene\(ui\.SceneBuilder \w+\) \{');
// A body is read for the properties it names, so its prose cannot be in it: the
// comment inside `OffsetLayer.addToScene` says "changing an offset layer", and
// `layer` was a property name until this line existed.
final RegExp _comment = RegExp(r'//.*$', multiLine: true);

Map<String, _SdkClass> _parseLayerDart() {
  final Map<String, _SdkClass> classes = <String, _SdkClass>{};
  _SdkClass? current;
  StringBuffer? body;
  for (final String line in const LineSplitter().convert(_layerDartSource())) {
    if (body != null) {
      if (line == '  }') {
        current!.addToScene = body.toString().replaceAll(_comment, '');
        body = null;
      } else {
        body.writeln(line);
      }
      continue;
    }
    final RegExpMatch? header = _classHeader.firstMatch(line);
    if (header != null) {
      current = _SdkClass(header.group(1)!, header.group(2));
      classes[current.name] = current;
      continue;
    }
    if (current == null) {
      continue;
    }
    final RegExpMatch? setter = _setter.firstMatch(line);
    if (setter != null) {
      current.setters.add(setter.group(1)!);
    } else if (_addToScene.hasMatch(line)) {
      body = StringBuffer();
    }
  }
  return classes;
}

bool _descendsFromLayer(String name, Map<String, _SdkClass> classes) {
  for (String? c = name; c != null; c = classes[c]?.superclass) {
    if (c == 'Layer') {
      return true;
    }
    if (!classes.containsKey(c)) {
      return false;
    }
  }
  return false;
}

/// Every property a whitelisted class hands to the `SceneBuilder` that [read]
/// does not read and [_ignored] does not excuse, as `Class.property`.
///
/// One-directional on purpose: reading more than a class composites costs
/// retention, and this is a hunt for the other kind of mistake.
List<String> _violations(Map<String, _SdkClass> classes, Map<String, Set<String>> read) {
  final List<String> out = <String>[];
  for (final String name in read.keys) {
    final String body = _effectiveAddToScene(name, classes);
    for (String? c = name; c != null; c = classes[c]?.superclass) {
      for (final String property in classes[c]?.setters ?? const <String>{}) {
        if (_ignored.containsKey('$c.$property')) {
          continue;
        }
        // The private field is what `addToScene` usually names — the setter is
        // for everybody else.
        if (!RegExp('\\b_?$property\\b').hasMatch(body)) {
          continue;
        }
        if (!read[name]!.contains(property)) {
          out.add('$name.$property');
        }
      }
    }
  }
  out.sort();
  return out;
}

String _effectiveAddToScene(String name, Map<String, _SdkClass> classes) {
  for (String? c = name; c != null; c = classes[c]?.superclass) {
    final String? body = classes[c]?.addToScene;
    if (body != null) {
      return body;
    }
  }
  return '';
}
