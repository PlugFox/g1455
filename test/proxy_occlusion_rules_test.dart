// The rules occlusion culling reads a cover by, one predicate at a time.
//
// `flutter test test/proxy_occlusion_rules_test.dart`
//
// `proxy_role_test.dart` proves that a cut is invisible on the fixtures it
// draws; this file pins the predicates under it, because every one of them
// errs in exactly one safe direction and a regression in any of them is a
// deleted pixel somewhere else:
//
//  1. **`opaqueLocalRect` accepts only what is provably opaque over its own
//     box.** Every disqualifier — translucency, a gradient, an image, a shape,
//     a radius, a blend mode, a foreground position, a non-box decoration — is
//     shown refusing next to the same node without it, which accepts.
//  2. **`paintClipOf` answers only where the answer is the true clip.** A
//     clipper that clips to half its box must not be read as the whole box,
//     and a clip with no public inner rectangle is refused, not approximated.
//  3. **`coverInRoot` refuses anything but a pure translation**, and a node
//     outside the root.
//  4. **`OcclusionPolicy` invalidates the pass on any order surprise.**

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/occlusion.dart';
import 'package:g1455/src/proxy/proxy_walk.dart';

const Size kArea = Size(200, 200);
const Color kOpaque = Color(0xFF336699);
const Color kTranslucent = Color(0x80336699);

final GlobalKey _rootKey = GlobalKey();
final GlobalKey _nodeKey = GlobalKey();

void main() {
  group('opaqueLocalRect', () {
    final Map<String, (Widget, bool)> decorated = <String, (Widget, bool)>{
      'opaque BoxDecoration': (const DecoratedBox(decoration: BoxDecoration(color: kOpaque)), true),
      'zero radius': (
        const DecoratedBox(
          decoration: BoxDecoration(color: kOpaque, borderRadius: BorderRadius.zero),
        ),
        true,
      ),
      'no colour': (const DecoratedBox(decoration: BoxDecoration()), false),
      'translucent': (const DecoratedBox(decoration: BoxDecoration(color: kTranslucent)), false),
      'gradient': (
        const DecoratedBox(
          decoration: BoxDecoration(
            color: kOpaque,
            gradient: LinearGradient(colors: <Color>[kOpaque, kOpaque]),
          ),
        ),
        false,
      ),
      'circle': (
        const DecoratedBox(
          decoration: BoxDecoration(color: kOpaque, shape: BoxShape.circle),
        ),
        false,
      ),
      'rounded': (
        const DecoratedBox(
          decoration: BoxDecoration(color: kOpaque, borderRadius: BorderRadius.all(Radius.circular(4))),
        ),
        false,
      ),
      'blend mode': (
        const DecoratedBox(
          decoration: BoxDecoration(color: kOpaque, backgroundBlendMode: BlendMode.multiply),
        ),
        false,
      ),
      'foreground': (
        const DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: kOpaque),
        ),
        false,
      ),
      'ShapeDecoration': (
        const DecoratedBox(
          decoration: ShapeDecoration(color: kOpaque, shape: Border()),
        ),
        false,
      ),
      'opaque PhysicalModel': (const PhysicalModel(color: kOpaque, child: SizedBox.expand()), true),
      'translucent PhysicalModel': (const PhysicalModel(color: kTranslucent, child: SizedBox.expand()), false),
      'circular PhysicalModel': (
        const PhysicalModel(color: kOpaque, shape: BoxShape.circle, child: SizedBox.expand()),
        false,
      ),
      'rounded PhysicalModel': (
        const PhysicalModel(
          color: kOpaque,
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SizedBox.expand(),
        ),
        false,
      ),
      'PhysicalModel with a zero radius': (
        const PhysicalModel(color: kOpaque, borderRadius: BorderRadius.zero, child: SizedBox.expand()),
        true,
      ),
      'GlassProxy.opaque': (const GlassProxy.opaque(child: SizedBox.expand()), true),
      'GlassProxy.replace, opaque stub': (
        const GlassProxy.replace(painter: SolidProxyPainter(kOpaque), child: SizedBox.expand()),
        true,
      ),
      'GlassProxy.replace, translucent stub': (
        const GlassProxy.replace(painter: SolidProxyPainter(kTranslucent), child: SizedBox.expand()),
        false,
      ),
      'GlassProxy.replace, gradient stub': (
        const GlassProxy.replace(
          painter: GradientProxyPainter(LinearGradient(colors: <Color>[kOpaque, kOpaque])),
          child: SizedBox.expand(),
        ),
        false,
      ),
      'GlassProxy.hidden': (const GlassProxy.hidden(child: ColoredBox(color: kOpaque)), false),
      'GlassProxy.verbatim': (const GlassProxy.verbatim(child: ColoredBox(color: kOpaque)), false),
      // The commonest opaque widget, and unreadable: its render object is
      // private. This is the row that justifies the declaration.
      'ColoredBox': (const ColoredBox(color: kOpaque), false),
    };

    for (final MapEntry<String, (Widget, bool)> e in decorated.entries) {
      testWidgets('${e.key}: ${e.value.$2 ? 'a cover of its own box' : 'refused'}', (WidgetTester tester) async {
        await tester.pumpWidget(_mount(_placed(KeyedSubtree(key: _nodeKey, child: e.value.$1))));
        final RenderObject node = _nodeOf(tester);
        expect(opaqueLocalRect(node), e.value.$2 ? node.paintBounds : isNull);
      });
    }

    test('an image refuses even with an opaque colour under it', () {
      // Unmounted: the refusal happens before `paintBounds` is read, and an
      // image that never has to decode keeps the fixture free of engine
      // futures.
      final node = RenderDecoratedBox(
        decoration: BoxDecoration(
          color: kOpaque,
          image: DecorationImage(image: MemoryImage(Uint8List(0))),
        ),
      );
      expect(opaqueLocalRect(node), isNull);
    });

    testWidgets('a declaration accepts a node no rule recognises, and still goes through the geometry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _mount(
          ClipRect(
            clipper: const _Half(),
            child: _placed(
              KeyedSubtree(
                key: _nodeKey,
                child: const ColoredBox(color: kOpaque),
              ),
            ),
          ),
        ),
      );
      final RenderObject node = _nodeOf(tester);
      bool declared(RenderObject n) => identical(n, node);
      expect(opaqueLocalRect(node), isNull);
      expect(opaqueLocalRect(node, declared: declared), node.paintBounds);
      // The placed box spans x 20…180 and the clipper keeps x < 100: a
      // declaration that skipped the geometry would report the whole box.
      expect(coverInRoot(node, _root(), declared: declared), const Rect.fromLTRB(20, 30, 100, 170));
    });
  });

  group('paintClipOf', () {
    testWidgets('a ClipRect is asked exactly, through its clipper', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          ClipRect(
            clipper: const _Half(),
            child: KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
          ),
        ),
      );
      final RenderObject child = _nodeOf(tester);
      final RenderClipRect clip = _ancestor<RenderClipRect>(child);
      // `describeApproximatePaintClip` says the whole box here, which is the
      // superset this function exists to refuse.
      expect(clip.describeApproximatePaintClip(child), Offset.zero & kArea);
      expect(paintClipOf(clip, child), (known: true, clip: const Rect.fromLTWH(0, 0, 100, 200)));
    });

    testWidgets('a ClipRect without a clipper clips to its box', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          ClipRect(
            child: KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
          ),
        ),
      );
      final RenderObject child = _nodeOf(tester);
      expect(paintClipOf(_ancestor<RenderClipRect>(child), child), (known: true, clip: Offset.zero & kArea));
    });

    testWidgets('a ClipRect with Clip.none clips nothing', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          ClipRect(
            clipBehavior: Clip.none,
            child: KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
          ),
        ),
      );
      final RenderObject child = _nodeOf(tester);
      expect(paintClipOf(_ancestor<RenderClipRect>(child), child), (known: true, clip: null));
    });

    final Map<String, Widget Function(Widget)> refused = <String, Widget Function(Widget)>{
      'ClipRRect': (Widget c) => ClipRRect(borderRadius: BorderRadius.circular(8), child: c),
      'ClipOval': (Widget c) => ClipOval(child: c),
      'ClipPath': (Widget c) => ClipPath(child: c),
      'PhysicalModel': (Widget c) => PhysicalModel(color: kOpaque, clipBehavior: Clip.antiAlias, child: c),
      'PhysicalShape': (Widget c) => PhysicalShape(
        clipper: const ShapeBorderClipper(shape: RoundedRectangleBorder()),
        color: kOpaque,
        clipBehavior: Clip.antiAlias,
        child: c,
      ),
    };
    for (final MapEntry<String, Widget Function(Widget)> e in refused.entries) {
      testWidgets('${e.key}: refused, because no inner rectangle is public', (WidgetTester tester) async {
        await tester.pumpWidget(_mount(e.value(KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()))));
        final RenderObject child = _nodeOf(tester);
        expect(paintClipOf(child.parent!, child), (known: false, clip: null));
      });
    }

    testWidgets('a clip-to-self parent is taken at its word, and one reporting less is refused', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _mount(
          Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
              // A stack reports its clip only when something overflows it.
              const Positioned(left: 150, top: 0, width: 100, height: 10, child: SizedBox()),
            ],
          ),
        ),
      );
      RenderObject child = _nodeOf(tester);
      expect(paintClipOf(child.parent!, child), (known: true, clip: Offset.zero & kArea));

      await tester.pumpWidget(
        _mount(
          _ClipsLess(
            child: KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
          ),
        ),
      );
      child = _nodeOf(tester);
      expect(child.parent!.describeApproximatePaintClip(child), const Rect.fromLTWH(10, 10, 50, 50));
      expect(paintClipOf(child.parent!, child), (known: false, clip: null));
    });

    testWidgets('a parent that does not clip is known to clip nothing', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          Padding(
            padding: const EdgeInsets.all(4),
            child: KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
          ),
        ),
      );
      final RenderObject child = _nodeOf(tester);
      expect(paintClipOf(child.parent!, child), (known: true, clip: null));
    });
  });

  group('coverInRoot', () {
    const Widget cover = DecoratedBox(decoration: BoxDecoration(color: kOpaque));

    testWidgets('a translation is followed and a clip intersected', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 20),
            child: ClipRect(
              clipper: const _Half(),
              child: KeyedSubtree(key: _nodeKey, child: cover),
            ),
          ),
        ),
      );
      // The child is 190 x 180 at (10, 20); the clipper keeps its left half.
      expect(coverInRoot(_nodeOf(tester), _root()), const Rect.fromLTWH(10, 20, 95, 180));
    });

    testWidgets('a rotation is refused rather than bounded', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          Transform.rotate(
            angle: 0.1,
            child: KeyedSubtree(key: _nodeKey, child: cover),
          ),
        ),
      );
      final RenderObject node = _nodeOf(tester);
      expect(opaqueLocalRect(node), isNotNull, reason: 'the refusal has to come from the transform');
      expect(coverInRoot(node, _root()), isNull);
    });

    testWidgets('a clip that removes the whole cover leaves no cover', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          ClipRect(
            clipper: const _Half(),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 120,
                  top: 0,
                  width: 60,
                  height: 60,
                  child: KeyedSubtree(key: _nodeKey, child: cover),
                ),
              ],
            ),
          ),
        ),
      );
      expect(coverInRoot(_nodeOf(tester), _root()), isNull);
    });

    testWidgets('a node that is not under the root has no cover in it', (WidgetTester tester) async {
      await tester.pumpWidget(_mount(KeyedSubtree(key: _nodeKey, child: cover)));
      final RenderObject node = _nodeOf(tester);
      final unrelated = RenderConstrainedBox(additionalConstraints: const BoxConstraints());
      expect(coverInRoot(node, unrelated), isNull);
    });
  });

  group('OcclusionPlan and OcclusionPolicy', () {
    testWidgets('the plan counts every opaque node and keeps the largest, cover or not', (WidgetTester tester) async {
      await tester.pumpWidget(
        _mount(
          Stack(
            children: <Widget>[
              const Positioned(
                left: 0,
                top: 0,
                width: 50,
                height: 50,
                child: DecoratedBox(decoration: BoxDecoration(color: kOpaque)),
              ),
              const Positioned(
                left: 60,
                top: 60,
                width: 120,
                height: 80,
                child: DecoratedBox(decoration: BoxDecoration(color: kOpaque)),
              ),
              const Positioned(
                left: 10,
                top: 150,
                width: 30,
                height: 30,
                child: DecoratedBox(decoration: BoxDecoration(color: kOpaque)),
              ),
            ],
          ),
        ),
      );
      final plan = OcclusionPlan.of(_root(), Offset.zero & kArea);
      expect(plan.opaqueNodes, 3);
      expect(plan.largestOpaque, const Rect.fromLTWH(60, 60, 120, 80));
      expect(plan.hasCover, isFalse, reason: 'none of them spans the region');
      expect(plan.occludedNodes, 0);
      expect(plan.isOccluded(_root()), isFalse);
    });

    testWidgets('the policy flags a node out of order and a node it never planned, and only culls when enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _mount(
          Stack(
            children: <Widget>[
              KeyedSubtree(key: _nodeKey, child: const SizedBox.expand()),
              const DecoratedBox(
                decoration: BoxDecoration(color: kOpaque),
                child: SizedBox.expand(),
              ),
            ],
          ),
        ),
      );
      final RenderObject root = _root();
      final RenderObject under = _nodeOf(tester);
      final plan = OcclusionPlan.of(root, Offset.zero & kArea);
      expect(plan.hasCover, isTrue);
      expect(plan.isOccluded(under), isTrue);
      final RenderObject cover = plan.cover!;

      final inOrder = OcclusionPolicy(plan);
      expect(inOrder(root), WalkAction.paint);
      expect(inOrder(under), WalkAction.skip);
      expect(inOrder(cover), WalkAction.paint);
      expect(inOrder.valid, isTrue);
      expect(inOrder.occludedNodes, 1);

      final backwards = OcclusionPolicy(plan);
      backwards(cover);
      backwards(under);
      expect(backwards.orderViolations, 1);
      expect(backwards.valid, isFalse);

      final stranger = OcclusionPolicy(plan);
      expect(stranger(RenderConstrainedBox(additionalConstraints: const BoxConstraints())), WalkAction.paint);
      expect(stranger.orderViolations, 1);

      // The negative control lives in the same policy: off, it checks the
      // order and culls nothing, and defers to its inner policy.
      final off = OcclusionPolicy(plan, enabled: false, inner: (RenderObject _) => WalkAction.substitute);
      expect(off(root), WalkAction.substitute);
      expect(off(under), WalkAction.substitute);
      expect(off.occludedNodes, 0);
      expect(off.valid, isTrue);
    });
  });
}

Widget _mount(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _rootKey,
      child: SizedBox.fromSize(size: kArea, child: child),
    ),
  ),
);

Widget _placed(Widget child) => Stack(
  children: <Widget>[Positioned(left: 20, top: 30, width: 160, height: 140, child: child)],
);

RenderObject _root() => _rootKey.currentContext!.findRenderObject()!;

RenderObject _nodeOf(WidgetTester tester) => _nodeKey.currentContext!.findRenderObject()!;

T _ancestor<T extends RenderObject>(RenderObject node) {
  RenderObject? n = node.parent;
  while (n != null && n is! T) {
    n = n.parent;
  }
  return n! as T;
}

/// Keeps the left half: the clipper that once read as a full-screen cover.
class _Half extends CustomClipper<Rect> {
  const _Half();

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_Half oldClipper) => false;
}

/// A parent outside the clip family that reports a clip smaller than its box:
/// legal by the contract, and the residual risk the predicate refuses.
class _ClipsLess extends SingleChildRenderObjectWidget {
  const _ClipsLess({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderClipsLess();
}

class _RenderClipsLess extends RenderProxyBox {
  @override
  Rect? describeApproximatePaintClip(RenderObject child) => const Rect.fromLTWH(10, 10, 50, 50);
}
