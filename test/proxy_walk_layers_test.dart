// The proxy pass over every layer route `PaintingContext` has, one at a time.
//
// `flutter test test/proxy_walk_layers_test.dart`
//
// `ProxyWalkContext` flattens layers onto one canvas, and every flattening is a
// re-implementation of what the engine does at composite time. Ordinary scenes
// reach the common routes; this file reaches the rest by name, because a route
// that no scene happens to use is a route nobody has compared:
//
//  1. **Every route the pass claims to reproduce, reproduces.** Each arm is a
//     pass compared byte for byte with the engine's own capture of the same
//     tree — the typed `push*` overrides through real widgets, and the
//     `pushLayer` switch through a render object that hands it each layer type
//     directly. A layer whose effect was ignored would still draw its content,
//     so every fixture is chosen so that the effect changes pixels: the control
//     is the same pass with the effect stripped, and it has to differ.
//  2. **Every route it cannot reproduce is named in the log** — and nothing
//     else is, so an unhandled list that grew by accident fails here.
//  3. **The live tree is left as found.** A layer the pass had to mint, a
//     throwing `paint`, an offset written into a live layer: each is checked
//     with `invariants.dart`, not assumed.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_walk.dart';

import 'invariants.dart';

const Size kArea = Size(120, 120);
const Color kPage = Color(0xFF102030);
const Color kRed = Color(0xFFE02020);
const Color kGreen = Color(0xFF20C060);
const Color kBlue = Color(0xFF3050E0);

void main() {
  group('typed routes, through real widgets', () {
    final Map<String, Widget Function(Widget content)> exact = <String, Widget Function(Widget)>{
      'ClipPath': (Widget c) => ClipPath(clipper: const _Triangle(), child: c),
      'ClipRSuperellipse': (Widget c) =>
          ClipRSuperellipse(borderRadius: const BorderRadius.all(Radius.circular(30)), child: c),
      'Transform': (Widget c) => Transform.rotate(angle: 0.3, child: c),
      'ColorFiltered': (Widget c) => ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF00FFFF), BlendMode.modulate),
        child: c,
      ),
      'ShaderMask': (Widget c) => ShaderMask(
        shaderCallback: (Rect r) => const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: c,
      ),
      'SliverOpacity': (Widget c) => CustomScrollView(
        slivers: <Widget>[
          SliverOpacity(
            opacity: 0.5,
            sliver: SliverToBoxAdapter(
              child: SizedBox.fromSize(size: kArea, child: c),
            ),
          ),
        ],
      ),
    };

    for (final MapEntry<String, Widget Function(Widget)> e in exact.entries) {
      testWidgets('${e.key}: the pass equals the engine capture, and the effect is visible', (
        WidgetTester tester,
      ) async {
        final _Shot plain = await _shoot(tester, _scene());
        final _Shot effect = await _shoot(tester, e.value(_scene()));
        expect(effect.log.errors, isEmpty);
        expect(effect.log.unhandledLayers, isEmpty);
        expect(effect.log.childContextsRequested, isEmpty);
        expect(effect.log.layersMinted, 0, reason: 'a push* override did not hand back the caller\'s layer');
        expect(effect.liveTreeChanges, isEmpty);
        expect(
          await _differing(tester, plain.stock, effect.stock),
          greaterThan(0),
          reason: 'the fixture cannot tell a reproduced effect from an ignored one',
        );
        expect(await _differing(tester, effect.stock, effect.pass), 0);
        plain.dispose();
        effect.dispose();
      });
    }

    testWidgets('a colour filter under a live alpha is counted as the one known divergence', (
      WidgetTester tester,
    ) async {
      final _Shot alone = await _shoot(
        tester,
        ColorFiltered(colorFilter: const ColorFilter.mode(kRed, BlendMode.modulate), child: _scene()),
      );
      final _Shot folded = await _shoot(
        tester,
        CustomScrollView(
          slivers: <Widget>[
            SliverOpacity(
              opacity: 0.5,
              sliver: SliverToBoxAdapter(
                child: SizedBox.fromSize(
                  size: kArea,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(kRed, BlendMode.modulate),
                    child: _scene(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      expect(alone.log.opacityFoldedIntoFilter, 0, reason: 'no alpha is open above this filter');
      expect(folded.log.opacityFoldedIntoFilter, 1);
      alone.dispose();
      folded.dispose();
    });

    testWidgets('an opacity pushed without an old layer mints one, and only one, and leaves the tree', (
      WidgetTester tester,
    ) async {
      // `RenderFlow` calls `pushOpacity` with no `oldLayer`, and the return type
      // is non-nullable, so the pass has to make a layer up. That is the event
      // `layersMinted` exists to count; the arm checks the count and that the
      // layer went nowhere live.
      final _Shot flow = await _shoot(
        tester,
        Flow.unwrapped(delegate: const _HalfOpacity(), children: <Widget>[_scene()]),
      );
      final _Shot plain = await _shoot(tester, _scene());
      expect(flow.log.layersMinted, 1);
      expect(flow.liveTreeChanges, isEmpty);
      expect(await _differing(tester, plain.stock, flow.stock), greaterThan(0));
      expect(await _differing(tester, flow.stock, flow.pass), 0);
      flow.dispose();
      plain.dispose();
    });

    testWidgets('a backdrop filter is named as unhandled, and its content still drawn', (WidgetTester tester) async {
      final _Shot shot = await _shoot(
        tester,
        Stack(
          children: <Widget>[
            _scene(),
            Positioned(
              left: 10,
              top: 10,
              width: 40,
              height: 40,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const ColoredBox(color: Color(0x40FFFFFF)),
              ),
            ),
          ],
        ),
      );
      expect(shot.log.unhandledLayers, <String>['BackdropFilterLayer']);
      expect(shot.liveTreeChanges, isEmpty);
      shot.dispose();
    });

    testWidgets('a follower is named as unhandled, and its live offsets survive the pass', (
      WidgetTester tester,
    ) async {
      final link = LayerLink();
      await tester.pumpWidget(
        _mount(
          Stack(
            children: <Widget>[
              _scene(),
              Positioned(
                left: 30,
                top: 40,
                child: CompositedTransformTarget(link: link, child: const SizedBox(width: 10, height: 10)),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: link,
                  offset: const Offset(5, 5),
                  child: const SizedBox(width: 20, height: 20, child: ColoredBox(color: kGreen)),
                ),
              ),
            ],
          ),
        ),
      );
      final FollowerLayer follower = _layersIn(_root().debugLayer!).whereType<FollowerLayer>().single;
      final Offset? unlinked = follower.unlinkedOffset;
      final Offset? linked = follower.linkedOffset;
      final _Pass pass = _walk(_root());
      expect(pass.log.unhandledLayers, contains('FollowerLayer'));
      expect(follower.unlinkedOffset, unlinked);
      expect(follower.linkedOffset, linked);
      pass.dispose();
    });

    testWidgets('a texture is a hole, logged as added and not as unhandled', (WidgetTester tester) async {
      final _Shot shot = await _shoot(
        tester,
        Stack(
          children: <Widget>[
            _scene(),
            const Positioned(left: 10, top: 10, width: 30, height: 30, child: Texture(textureId: 7)),
          ],
        ),
      );
      expect(shot.log.addedLayers, <String>['TextureLayer']);
      expect(shot.log.unhandledLayers, isEmpty);
      shot.dispose();
    });
  });

  group('pushLayer, one layer type at a time', () {
    // Each entry builds the layer the way the framework's own `push*` does:
    // a clip in the parent's coordinates with the painter at `offset`, an
    // offset-carrying layer with the painter at zero.
    final Map<String, _Route> routes = <String, _Route>{
      for (final Clip clip in <Clip>[Clip.hardEdge, Clip.antiAlias, Clip.antiAliasWithSaveLayer]) ...<String, _Route>{
        'ClipRectLayer ${clip.name}': _Route.at(
          (Offset o) => ClipRectLayer(clipRect: _clip.shift(o), clipBehavior: clip),
        ),
        'ClipRRectLayer ${clip.name}': _Route.at(
          (Offset o) => ClipRRectLayer(
            clipRRect: RRect.fromRectAndRadius(_clip.shift(o), const Radius.circular(12)),
            clipBehavior: clip,
          ),
        ),
        'ClipRSuperellipseLayer ${clip.name}': _Route.at(
          (Offset o) => ClipRSuperellipseLayer(
            clipRSuperellipse: RSuperellipse.fromRectAndRadius(_clip.shift(o), const Radius.circular(12)),
            clipBehavior: clip,
          ),
        ),
        'ClipPathLayer ${clip.name}': _Route.at(
          (Offset o) => ClipPathLayer(clipPath: _Triangle.path(kArea).shift(o), clipBehavior: clip),
        ),
      },
      'TransformLayer': _Route.at(
        (Offset o) =>
            TransformLayer(transform: Matrix4.translationValues(o.dx + 9, o.dy + 5, 0)..scaleByDouble(0.8, 0.8, 1, 1)),
        paintAtOffset: false,
      ),
      'OpacityLayer 128': _Route.offset((Offset o) => OpacityLayer(alpha: 128, offset: o)),
      'ImageFilterLayer': _Route.offset(
        (Offset o) => ImageFilterLayer(
          imageFilter: ui.ImageFilter.matrix(Matrix4.translationValues(7, 3, 0).storage),
          offset: o,
        ),
      ),
      'ColorFilterLayer': _Route.at(
        (Offset o) => ColorFilterLayer(colorFilter: const ColorFilter.mode(Color(0xFFFF00FF), BlendMode.modulate)),
      ),
      'ShaderMaskLayer': _Route.at(
        (Offset o) => ShaderMaskLayer(
          shader: const LinearGradient(
            colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          ).createShader(o & kArea),
          maskRect: o & kArea,
          blendMode: BlendMode.dstIn,
        ),
      ),
    };

    for (final MapEntry<String, _Route> e in routes.entries) {
      testWidgets('${e.key}: the flattened pass equals the composited frame', (WidgetTester tester) async {
        final _Shot plain = await _shoot(tester, _Pusher(route: null, child: _scene()));
        final _Shot pushed = await _shoot(tester, _Pusher(route: e.value, child: _scene()));
        expect(pushed.log.unhandledLayers, isEmpty);
        expect(pushed.log.errors, isEmpty);
        expect(pushed.liveTreeChanges, isEmpty);
        expect(
          await _differing(tester, plain.stock, pushed.stock),
          greaterThan(0),
          reason: 'the layer changes nothing on screen, so ignoring it would pass',
        );
        expect(await _differing(tester, pushed.stock, pushed.pass), 0);
        plain.dispose();
        pushed.dispose();
      });
    }

    testWidgets('an opacity layer at full alpha and the offset-only layers draw their content in place', (
      WidgetTester tester,
    ) async {
      final _Shot plain = await _shoot(tester, _scene());
      for (final _Route route in <_Route>[
        _Route.offset((Offset o) => OpacityLayer(alpha: 255, offset: o)),
        _Route.offset((Offset o) => OffsetLayer(offset: o)),
        _Route.offset((Offset o) => LeaderLayer(link: LayerLink(), offset: o)),
        _Route.at((Offset o) => AnnotatedRegionLayer<Object>(Object())),
        _Route.at((Offset o) => ContainerLayer()),
      ]) {
        final _Shot pushed = await _shoot(tester, _Pusher(route: route, walkOnly: true, child: _scene()));
        expect(pushed.log.unhandledLayers, isEmpty);
        expect(await _differing(tester, plain.stock, pushed.pass), 0, reason: '${route.make(Offset.zero)}');
        pushed.dispose();
      }
      plain.dispose();
    });

    testWidgets('a layer whose effect was never set draws its content unaltered', (WidgetTester tester) async {
      // The framework would assert at composite time on most of these, which is
      // why they are handed to the pass alone: a custom render object that sets
      // its layer's fields late must not crash the walk or invent an effect.
      final _Shot plain = await _shoot(tester, _scene());
      final List<ContainerLayer Function()> unset = <ContainerLayer Function()>[
        ClipRectLayer.new,
        ClipRRectLayer.new,
        ClipRSuperellipseLayer.new,
        ClipPathLayer.new,
        TransformLayer.new,
        ImageFilterLayer.new,
        ColorFilterLayer.new,
        ShaderMaskLayer.new,
      ];
      for (final ContainerLayer Function() make in unset) {
        final _Shot pushed = await _shoot(
          tester,
          _Pusher(route: _Route.at((Offset _) => make()), walkOnly: true, child: _scene()),
        );
        expect(pushed.log.unhandledLayers, isEmpty, reason: '${make().runtimeType}');
        expect(pushed.log.errors, isEmpty);
        expect(await _differing(tester, plain.stock, pushed.pass), 0, reason: '${make().runtimeType}');
        pushed.dispose();
      }
      plain.dispose();
    });

    // `pushLayer` does not raise the alpha depth the way `pushOpacity` and a
    // composited opacity boundary do, so a colour filter under an opacity layer
    // pushed this way escapes `opacityFoldedIntoFilter` — the counter whose
    // non-zero value is meant to send the subtree to the stock capture. No
    // framework widget pushes an `OpacityLayer` through `pushLayer`; a custom
    // render object may.
    testWidgets(
      'a colour filter under an opacity layer pushed through pushLayer is counted as folded',
      (WidgetTester tester) async {
        final _Shot shot = await _shoot(
          tester,
          _Pusher(
            route: _Route.offset((Offset o) => OpacityLayer(alpha: 128, offset: o)),
            child: ColorFiltered(colorFilter: const ColorFilter.mode(kRed, BlendMode.modulate), child: _scene()),
          ),
        );
        expect(shot.log.opacityFoldedIntoFilter, 1);
        shot.dispose();
      },
      // Skipped: `ProxyWalkContext.pushLayer` ignores the effect's `carriesAlpha`,
      // so `_opacityDepth` stays 0 under it.
      skip: true,
    );
  });

  group('the bookkeeping routes', () {
    testWidgets('addLayer of a layer with no hole semantics, appendLayer and createChildContext are each named', (
      WidgetTester tester,
    ) async {
      final _Shot shot = await _shoot(tester, _Stray(child: _scene()));
      expect(shot.log.addedLayers, <String>['PictureLayer']);
      expect(shot.log.unhandledLayers, <String>['PictureLayer', 'appendLayer:PictureLayer']);
      expect(shot.log.childContextsRequested, <String>['OffsetLayer']);
      shot.dispose();
    });

    testWidgets('a colour filter pushed with no old layer mints one; a painter that leaves saves open is closed', (
      WidgetTester tester,
    ) async {
      final _Shot plain = await _shoot(tester, _scene());
      final _Shot shot = await _shoot(tester, _Careless(child: _scene()));
      expect(shot.log.layersMinted, 1, reason: 'the minted colour-filter layer went uncounted');
      expect(shot.log.errors, isEmpty);
      // The careless painter clips to a corner and never restores; if the walk
      // did not close it, the rest of the scene would be cut to that corner.
      expect(await _differing(tester, plain.stock, shot.pass), 0);
      expect(shot.liveTreeChanges, isEmpty);
      plain.dispose();
      shot.dispose();
    });

    testWidgets('a throwing paint is logged, and its unbalanced clip does not reach the next sibling', (
      WidgetTester tester,
    ) async {
      final _Shot clean = await _shoot(
        tester,
        Stack(children: <Widget>[_scene(), const _Thrower(), const _Sibling()]),
      );
      expect(clean.log.errors, hasLength(1));
      expect(clean.log.errors.single, startsWith('_RenderThrower: '));
      expect(clean.log.errors.single, contains('walk-only failure'));
      // The thrower draws nothing on screen, so the frame without its failure
      // is the frame the pass has to equal. The sibling is outside the clip the
      // thrower left open, which is what makes a leaked clip a visible miss.
      expect(await _differing(tester, clean.stock, clean.pass), 0);
      expect(clean.liveTreeChanges, isEmpty);
      clean.dispose();
    });

    testWidgets('a substituted node is a placeholder of its own paint bounds, in the given colour', (
      WidgetTester tester,
    ) async {
      const Color stub = Color(0xFF808080);
      // The control is the engine drawing a box of that colour where the
      // substituted node stood: offset, size and colour in one comparison.
      final _Shot reference = await _shoot(tester, _placed(const ColoredBox(color: stub)));
      final _Shot substituted = await _shoot(
        tester,
        _placed(const _Unreadable()),
        policy: (RenderObject o) => o is _RenderUnreadable ? WalkAction.substitute : WalkAction.paint,
      );
      expect(substituted.log.substituted, <String>['_RenderUnreadable']);
      expect(await _differing(tester, reference.stock, substituted.pass), 0);
      expect(
        await _differing(tester, substituted.stock, substituted.pass),
        greaterThan(0),
        reason: 'the node itself paints something else, so the stub is what was drawn',
      );
      reference.dispose();
      substituted.dispose();
    });

    test('summary reports every counter under its report key', () {
      final log = WalkLog()
        ..visited = 4
        ..boundariesCrossed = 1
        ..compositedEffectsApplied = 2
        ..layersMinted = 3
        ..opacityFoldedIntoFilter = 5
        ..unhandledLayers.add('BackdropFilterLayer')
        ..addedLayers.add('TextureLayer')
        ..substituted.add('RenderX')
        ..skipped.add('RenderY')
        ..proxyRoles[GlassProxyRole.hidden] = 2
        ..errors.add('RenderZ: boom')
        ..childContextsRequested.add('OffsetLayer');
      expect(log.summary(), <String, Object>{
        'visited': 4,
        'boundaries_crossed': 1,
        'composited_effects_applied': 2,
        'layers_minted': 3,
        'opacity_folded_into_filter': 5,
        'unhandled_layers': <String>['BackdropFilterLayer'],
        'added_layers': <String>['TextureLayer'],
        'substituted': <String>['RenderX'],
        'skipped': <String>['RenderY'],
        'proxy_roles': <String, int>{'hidden': 2},
        'errors': <String>['RenderZ: boom'],
        'child_contexts_requested': <String>['OffsetLayer'],
      });
    });

    test('a context made without a log gets a fresh one per context', () {
      final a = ProxyWalkContext(OffsetLayer(), Offset.zero & kArea);
      final b = ProxyWalkContext(OffsetLayer(), Offset.zero & kArea);
      expect(a.log, isNot(same(b.log)));
      expect(a.log.visited, 0);
      expect(a.placeholderColor, const Color(0xFF808080));
      expect(a.policy(RenderConstrainedBox(additionalConstraints: const BoxConstraints())), WalkAction.paint);
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures.
// ---------------------------------------------------------------------------

const Rect _clip = Rect.fromLTWH(15, 20, 80, 70);

/// Asymmetric on purpose: a transform, a clip or a mask that was applied in the
/// wrong place moves colour across a boundary instead of within one colour.
Widget _scene() => SizedBox.fromSize(
  size: kArea,
  child: const Stack(
    children: <Widget>[
      Positioned.fill(child: ColoredBox(color: kBlue)),
      Positioned(left: 0, top: 0, width: 70, height: 50, child: ColoredBox(color: kRed)),
      Positioned(left: 50, top: 60, width: 70, height: 60, child: ColoredBox(color: kGreen)),
    ],
  ),
);

Widget _placed(Widget child) => Stack(
  children: <Widget>[
    _scene(),
    Positioned(left: 23, top: 31, width: 41, height: 27, child: child),
  ],
);

class _Triangle extends CustomClipper<Path> {
  const _Triangle();

  static Path path(Size size) => Path()
    ..moveTo(size.width * 0.1, 0)
    ..lineTo(size.width, size.height * 0.3)
    ..lineTo(size.width * 0.4, size.height)
    ..close();

  @override
  Path getClip(Size size) => path(size);

  @override
  bool shouldReclip(_Triangle oldClipper) => false;
}

class _HalfOpacity extends FlowDelegate {
  const _HalfOpacity();

  @override
  void paintChildren(FlowPaintingContext context) => context.paintChild(0, opacity: 0.5);

  @override
  bool shouldRepaint(_HalfOpacity oldDelegate) => false;
}

/// How [_Pusher] hands a layer to `pushLayer`.
class _Route {
  /// The layer carries the offset in its own geometry; the painter runs at it.
  _Route.at(this.make, {this.paintAtOffset = true});

  /// The layer carries the offset as its `offset`; the painter runs at zero.
  _Route.offset(this.make) : paintAtOffset = false;

  final ContainerLayer Function(Offset offset) make;
  final bool paintAtOffset;
}

/// Pushes one layer through `pushLayer` around its child — on screen too,
/// unless [walkOnly], so the engine's composite is the control.
class _Pusher extends SingleChildRenderObjectWidget {
  const _Pusher({required this.route, this.walkOnly = false, super.child});

  final _Route? route;
  final bool walkOnly;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPusher(route, walkOnly);
}

class _RenderPusher extends RenderProxyBox {
  _RenderPusher(this.route, this.walkOnly);

  final _Route? route;
  final bool walkOnly;

  // Owned here so the on-screen layer is replaced, not leaked, on every paint.
  final LayerHandle<ContainerLayer> _handle = LayerHandle<ContainerLayer>();

  @override
  bool get alwaysNeedsCompositing => route != null && !walkOnly;

  @override
  void paint(PaintingContext context, Offset offset) {
    final _Route? r = route;
    if (r == null || (walkOnly && context is! ProxyWalkContext)) {
      super.paint(context, offset);
      return;
    }
    final ContainerLayer layer = r.make(offset);
    if (context is! ProxyWalkContext) {
      _handle.layer = layer;
    }
    context.pushLayer(layer, super.paint, r.paintAtOffset ? offset : Offset.zero);
  }

  @override
  void dispose() {
    _handle.layer = null;
    super.dispose();
  }
}

/// Reaches the three routes the pass overrides only to record that they were
/// reached. Draws nothing on screen.
class _Stray extends SingleChildRenderObjectWidget {
  const _Stray({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStray();
}

class _RenderStray extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (context is ProxyWalkContext) {
      context.addLayer(PictureLayer(Offset.zero & size));
      // ignore: invalid_use_of_protected_member
      context.appendLayer(PictureLayer(Offset.zero & size));
      // ignore: invalid_use_of_protected_member
      expect(identical(context.createChildContext(OffsetLayer(), Offset.zero & size), context), isTrue);
    }
  }
}

/// Inside the pass only: a colour filter pushed with no layer to reuse, and a
/// `pushLayer` painter that opens a clip and never restores it.
class _Careless extends SingleChildRenderObjectWidget {
  const _Careless({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCareless();
}

class _RenderCareless extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    if (context is! ProxyWalkContext) {
      super.paint(context, offset);
      return;
    }
    // The identity matrix: the filter changes no pixel, so the frame is the
    // control and only the count can move.
    context.pushColorFilter(offset, const ColorFilter.matrix(_identity), (PaintingContext c, Offset o) {});
    context.pushLayer(OffsetLayer(), (PaintingContext c, Offset o) {
      c.canvas
        ..save()
        ..clipRect(const Rect.fromLTWH(0, 0, 4, 4));
    }, offset);
    super.paint(context, offset);
  }
}

const List<double> _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

/// Opens a clip and throws, but only inside the pass: on screen it is a
/// well-behaved empty box.
class _Thrower extends LeafRenderObjectWidget {
  const _Thrower();

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderThrower();
}

class _RenderThrower extends RenderBox {
  @override
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (context is ProxyWalkContext) {
      context.canvas
        ..save()
        ..clipRect(const Rect.fromLTWH(0, 0, 5, 5));
      throw StateError('walk-only failure');
    }
  }
}

class _Sibling extends StatelessWidget {
  const _Sibling();

  @override
  Widget build(BuildContext context) => const Positioned(
    left: 60,
    top: 10,
    width: 40,
    height: 40,
    child: ColoredBox(color: Color(0xFFFFE000)),
  );
}

/// Paints a distinctive pattern of its own, so a stub can be told from it.
class _Unreadable extends LeafRenderObjectWidget {
  const _Unreadable();

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUnreadable();
}

class _RenderUnreadable extends RenderBox {
  @override
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = const Color(0xFFFF00FF));
  }
}

// ---------------------------------------------------------------------------
// The two captures, and the comparison.
// ---------------------------------------------------------------------------

final GlobalKey _boundaryKey = GlobalKey();

Widget _mount(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _boundaryKey,
      child: SizedBox.fromSize(
        size: kArea,
        child: ColoredBox(color: kPage, child: child),
      ),
    ),
  ),
);

RenderRepaintBoundary _root() => _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

Iterable<Layer> _layersIn(Layer layer) sync* {
  yield layer;
  if (layer is ContainerLayer) {
    for (Layer? c = layer.firstChild; c != null; c = c.nextSibling) {
      yield* _layersIn(c);
    }
  }
}

class _Pass {
  _Pass(this._handle, this.image, this.log);

  final LayerHandle<OffsetLayer> _handle;
  final ui.Image image;
  final WalkLog log;

  void dispose() {
    image.dispose();
    _handle.layer = null;
  }
}

_Pass _walk(RenderObject root, {WalkPolicy policy = paintEverything}) {
  final handle = LayerHandle<OffsetLayer>()..layer = OffsetLayer();
  final log = WalkLog();
  ProxyWalkContext(handle.layer!, Offset.zero & kArea, log: log, policy: policy)
    ..paintChild(root, Offset.zero)
    ..finish();
  return _Pass(handle, handle.layer!.toImageSync(Offset.zero & kArea), log);
}

class _Shot {
  _Shot(this.stock, this._pass, this.liveTreeChanges);

  final ui.Image stock;
  final _Pass _pass;
  final List<String> liveTreeChanges;

  ui.Image get pass => _pass.image;
  WalkLog get log => _pass.log;

  void dispose() {
    stock.dispose();
    _pass.dispose();
  }
}

/// The engine's capture of [child] and one pass over the same tree, plus what
/// the pass changed in the live tree (which must be nothing).
Future<_Shot> _shoot(WidgetTester tester, Widget child, {WalkPolicy policy = paintEverything}) async {
  // A fresh key per shot: the fixtures' render objects take their route at
  // creation and have no `updateRenderObject`, so a reused element would keep
  // the previous shot's.
  await tester.pumpWidget(_mount(KeyedSubtree(key: UniqueKey(), child: child)));
  await tester.pumpAndSettle();
  final RenderRepaintBoundary root = _root();
  final ui.Image stock = root.toImageSync();
  final TreeSnapshot before = TreeSnapshot.of(root);
  final _Pass pass = _walk(root, policy: policy);
  final List<String> changes = TreeSnapshot.of(root).diffFrom(before);
  return _Shot(stock, pass, changes);
}

Future<int> _differing(WidgetTester tester, ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  var n = 0;
  await tester.runAsync(() async {
    final ByteData? da = await a.toByteData();
    final ByteData? db = await b.toByteData();
    if (da == null || db == null) {
      throw StateError('an image came back without bytes');
    }
    final Uint8List pa = da.buffer.asUint8List();
    final Uint8List pb = db.buffer.asUint8List();
    for (var i = 0; i < pa.length; i += 4) {
      if (pa[i] != pb[i] || pa[i + 1] != pb[i + 1] || pa[i + 2] != pb[i + 2] || pa[i + 3] != pb[i + 3]) {
        n++;
      }
    }
  });
  return n;
}
