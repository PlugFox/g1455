// Phase A — the roles an application declares over its own subtrees, and the
// controls that make each of them a claim rather than a hope.
//
// `flutter test test/glass/proxy_role_test.dart`
//
// The delivery mechanism is the thing under test here, not the pass: M12
// already established that the pass reproduces `toImageSync`. What is new is a
// marker in somebody's widget tree, and every way it can be wrong is silent —
// a stub drawn at the wrong offset, a subtraction that leaves a hole, a
// declaration that never reached the pass, a `shouldRepaint` nobody calls.
//
// So each role is checked against a tree that does not need it:
//
//  1. **The real frame is untouched.** All four markers in place, rendered
//     through the stock capture, byte for byte against the same tree with none.
//     If this fails, nothing else here matters.
//  2. **The mechanism is transparent.** `opaque` and `verbatim` subtract
//     nothing from the pass itself, so a pass carrying them has to equal a pass
//     without them exactly.
//  3. **`replace` is a positive control, with its own negative.** A subtree
//     that is exactly one flat rectangle, replaced by a stub of the same
//     colour, must come back byte-identical — that is offset, size and colour
//     at once — and a stub of a *different* colour must not, or "the painter
//     never ran" would pass the first half.
//  4. **`hidden` is a subtraction, not a hole.** Equal to the tree with that
//     subtree absent; different from the tree with it present.
//  5. **`verbatim` keeps exactly what the canvas policy would have dropped.**
//  6. **`opaque` becomes a cover where a `ColoredBox` cannot (D42)** — and the
//     cut it licenses is invisible.
//  7. **`shouldRepaint` has an observable trace.** An axis with no consequence
//     is not an axis, and this one's consequence is `proxyChanges`.
//  8. **Alternating the policy between passes leaves the live tree alone.** The
//     question that raises is a fair one — a pass that subtracts a subtree
//     could plausibly drop somebody's retained layer, and the next real frame
//     has no reason to rebuild it. It cannot here, and the reason is
//     structural rather than hopeful (`push*` returns its `oldLayer`,
//     `super.pushLayer` is never called, `paint()` leaves `_needsPaint` as it
//     found it) — so what the arm does is *check* it under the knobs a caller
//     would actually alternate.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/occlusion.dart';
import 'package:g1455/src/proxy/proxy_walk.dart';
import 'package:g1455/src/proxy/shadow_filter.dart';

import 'invariants.dart';

const Size kArea = Size(200, 200);
const Color kPage = Color(0xFF102030);
const Color kBox = Color(0xFF80C0A0);
const Color kOther = Color(0xFFC08040);

void main() {
  // -------------------------------------------------------------------------
  // 1. Nothing here changes the frame the user sees.
  // -------------------------------------------------------------------------

  testWidgets('all four roles leave the real frame byte for byte', (WidgetTester tester) async {
    final ui.Image bare = await _stock(tester, _page(_content(marked: false)));
    final ui.Image marked = await _stock(tester, _page(_content(marked: true)));
    final _Diff diff = await _compare(tester, bare, marked);
    bare.dispose();
    marked.dispose();
    expect(diff.differing, 0, reason: 'a marker changed the live frame: $diff');
  });

  // -------------------------------------------------------------------------
  // 2. The two roles that subtract nothing from the pass subtract nothing.
  // -------------------------------------------------------------------------

  testWidgets('opaque and verbatim are transparent to the pass', (WidgetTester tester) async {
    final _Pass bare = await _walk(tester, _page(_boxes()));
    final _Pass marked = await _walk(
      tester,
      _page(
        Stack(
          children: <Widget>[
            Positioned.fromRect(
              rect: _first,
              child: const GlassProxy.opaque(child: ColoredBox(color: kBox)),
            ),
            Positioned.fromRect(
              rect: _second,
              child: const GlassProxy.verbatim(child: ColoredBox(color: kOther)),
            ),
          ],
        ),
      ),
    );
    final _Diff diff = await _compare(tester, bare.image, marked.image);
    expect(marked.log.proxyRoles[GlassProxyRole.opaque], 1);
    expect(marked.log.proxyRoles[GlassProxyRole.verbatim], 1);
    expect(marked.log.layersMinted, 0);
    expect(marked.log.errors, isEmpty);
    bare.dispose();
    marked.dispose();
    expect(diff.differing, 0, reason: 'a declaration that draws nothing changed the proxy: $diff');
  });

  // -------------------------------------------------------------------------
  // 3. `replace`: the stub lands where the subtree was, and the arm can fail.
  // -------------------------------------------------------------------------

  testWidgets('a stub of the same colour is exact, and of another colour is not', (
    WidgetTester tester,
  ) async {
    final _Pass plain = await _walk(tester, _page(_boxes()));
    final _Pass same = await _walk(tester, _page(_replaced(const SolidProxyPainter(kBox))));
    final _Pass other = await _walk(tester, _page(_replaced(const SolidProxyPainter(kOther))));

    final _Diff exact = await _compare(tester, plain.image, same.image);
    final _Diff wrong = await _compare(tester, plain.image, other.image);
    debugPrint('replace: same=$exact other=$wrong');

    expect(same.log.proxyRoles[GlassProxyRole.replace], 1);
    expect(same.log.substituted, contains('GlassProxy.replace'));
    plain.dispose();
    same.dispose();
    other.dispose();

    expect(exact.differing, 0, reason: 'the stub is not where the subtree was: $exact');
    // The negative control, and it is the whole reason the first line means
    // anything: a stub that never ran would satisfy it too.
    expect(
      wrong.differing,
      _first.width * _first.height,
      reason: 'the stub did not paint the colour it was given: $wrong',
    );
  });

  testWidgets('a stub cannot paint outside the box it stands for', (WidgetTester tester) async {
    final _Pass bounded = await _walk(tester, _page(_replaced(const _OverdrawPainter())));
    final _Pass reference = await _walk(tester, _page(_replaced(const SolidProxyPainter(kOther))));
    final _Diff diff = await _compare(tester, bounded.image, reference.image);
    bounded.dispose();
    reference.dispose();
    // Clipped to the marker's own box, so a painter reaching a thousand pixels
    // in every direction is indistinguishable from one that filled its box.
    // Unlike `CustomPainter`, where overdrawing is merely discouraged: here it
    // would corrupt the backdrop of surfaces elsewhere with nothing to see.
    expect(diff.differing, 0, reason: 'the stub escaped its bounds: $diff');
  });

  // -------------------------------------------------------------------------
  // 4. `hidden`: painter's order, not a hole.
  // -------------------------------------------------------------------------

  testWidgets('hidden equals the tree without that subtree, and not the one with it', (
    WidgetTester tester,
  ) async {
    final _Pass absent = await _walk(tester, _page(_boxes(first: false)));
    final _Pass hidden = await _walk(
      tester,
      _page(
        Stack(
          children: <Widget>[
            Positioned.fromRect(
              rect: _first,
              child: const GlassProxy.hidden(child: ColoredBox(color: kBox)),
            ),
            Positioned.fromRect(
              rect: _second,
              child: const ColoredBox(color: kOther),
            ),
          ],
        ),
      ),
    );
    final _Pass present = await _walk(tester, _page(_boxes()));

    final _Diff subtraction = await _compare(tester, absent.image, hidden.image);
    final _Diff control = await _compare(tester, present.image, hidden.image);
    debugPrint('hidden: vs-absent=$subtraction vs-present=$control');

    expect(hidden.log.proxyRoles[GlassProxyRole.hidden], 1);
    expect(hidden.log.skipped, contains('RenderGlassProxy'));
    absent.dispose();
    hidden.dispose();
    present.dispose();

    // What is left is the page underneath, because the page painted first —
    // a subtraction in painter's order, not transparent black.
    expect(subtraction.differing, 0, reason: 'hiding left something behind: $subtraction');
    expect(control.differing, greaterThan(0), reason: 'nothing was hidden at all');
  });

  testWidgets('a marker under a hidden one is counted in the tree and never reached', (
    WidgetTester tester,
  ) async {
    final _Pass pass = await _walk(
      tester,
      _page(
        Stack(
          children: <Widget>[
            Positioned.fromRect(
              rect: _first,
              child: GlassProxy.hidden(
                child: GlassProxy.replace(
                  painter: const SolidProxyPainter(kOther),
                  child: const ColoredBox(color: kBox),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final Map<GlassProxyRole, int> inTree = RenderGlassProxy.countIn(pass.root);
    pass.dispose();

    // The outermost wins and the inner one is unreachable. Without the two
    // counters this is indistinguishable from a marker that fired.
    expect(inTree[GlassProxyRole.replace], 1, reason: 'the inner marker is in the tree');
    expect(pass.log.proxyRoles[GlassProxyRole.replace], isNull, reason: 'and was never reached');
    expect(pass.log.proxyRoles[GlassProxyRole.hidden], 1);
  });

  // -------------------------------------------------------------------------
  // 5. `verbatim`: the subtree-sized hole in the canvas policy.
  // -------------------------------------------------------------------------

  testWidgets('verbatim keeps a blurred draw the shadow filter drops', (WidgetTester tester) async {
    const Widget blurred = CustomPaint(painter: _BlurredDot());

    final _Pass unfiltered = await _walk(tester, _page(_over(blurred)));

    final filterOutside = ShadowFilter();
    final _Pass filtered = await _walk(tester, _page(_over(blurred)), shadowFilter: filterOutside);

    final filterInside = ShadowFilter();
    final _Pass exempt = await _walk(
      tester,
      _page(_over(const GlassProxy.verbatim(child: blurred))),
      shadowFilter: filterInside,
    );

    final _Diff dropped = await _compare(tester, unfiltered.image, filtered.image);
    final _Diff kept = await _compare(tester, unfiltered.image, exempt.image);
    debugPrint(
      'verbatim: outside dropped=${filterOutside.maskFilteredDraws} diff=$dropped, '
      'inside dropped=${filterInside.maskFilteredDraws} diff=$kept',
    );
    unfiltered.dispose();
    filtered.dispose();
    exempt.dispose();

    expect(filterOutside.maskFilteredDraws, 1, reason: 'the filter did not fire at all');
    expect(dropped.differing, greaterThan(0), reason: 'dropping the draw changed nothing');
    expect(filterInside.maskFilteredDraws, 0, reason: 'verbatim did not lift the filter');
    expect(kept.differing, 0, reason: 'the exempted draw came out different: $kept');
  });

  // -------------------------------------------------------------------------
  // 6. `opaque`: the cover a render tree cannot report by itself.
  // -------------------------------------------------------------------------

  testWidgets('opaque declares a cover a ColoredBox cannot, and the cut is invisible', (
    WidgetTester tester,
  ) async {
    const Widget cover = ColoredBox(color: Color(0xFF404040));
    final Rect region = Offset.zero & kArea;

    final _Pass undeclared = await _walk(tester, _page(_over(cover)));
    final OcclusionPlan without = OcclusionPlan.of(undeclared.root, region);

    final _Pass declared = await _walk(tester, _page(_over(const GlassProxy.opaque(child: cover))));
    final OcclusionPlan with_ = OcclusionPlan.of(declared.root, region);
    final policy = OcclusionPolicy(with_);
    final _Pass cut = await _walk(
      tester,
      _page(_over(const GlassProxy.opaque(child: cover))),
      plan: (RenderObject root) => OcclusionPolicy(OcclusionPlan.of(root, region)),
    );

    final _Diff diff = await _compare(tester, declared.image, cut.image);
    debugPrint(
      'occlusion: declared cover=${with_.cover?.runtimeType} occluded=${with_.occludedNodes} '
      'undeclared cover=${without.cover?.runtimeType}, cut diff=$diff',
    );
    undeclared.dispose();
    declared.dispose();
    cut.dispose();

    // D42: `ColoredBox` lowers to a private render object, so nothing public
    // can read its colour. That is the whole reason the declaration exists.
    expect(without.hasCover, isFalse, reason: 'a ColoredBox became readable — check D42');
    expect(with_.hasCover, isTrue, reason: 'the declaration did not reach the planner');
    expect(with_.occludedNodes, greaterThan(0));
    expect(cut.policy!.valid, isTrue, reason: 'paint order disagreed with visit order');
    expect(cut.policy!.occludedNodes, greaterThan(0), reason: 'the cut removed nothing');
    expect(diff.differing, 0, reason: 'the cut was visible: $diff');
    expect(policy.orderViolations, 0);
  });

  // -------------------------------------------------------------------------
  // 7. `shouldRepaint`, and the trace that makes it an axis.
  // -------------------------------------------------------------------------

  testWidgets('proxyChanges fires exactly when shouldRepaint says so', (WidgetTester tester) async {
    final key = GlobalKey();
    var fired = 0;

    Future<void> pump(Widget marker) => tester.pumpWidget(
      _mount(
        _page(
          Stack(
            children: <Widget>[Positioned.fromRect(rect: _first, child: marker)],
          ),
        ),
      ),
    );

    await pump(
      GlassProxy.replace(
        key: key,
        painter: const SolidProxyPainter(kBox),
        child: const ColoredBox(color: kBox),
      ),
    );
    final render = key.currentContext!.findRenderObject()! as RenderGlassProxy;
    render.proxyChanges.addListener(() => fired++);

    // A new instance that answers false. Equality of the *instance* would have
    // hidden this: the widget is rebuilt every pump, so the painter always
    // arrives as a different object.
    await pump(
      GlassProxy.replace(
        key: key,
        painter: const SolidProxyPainter(kBox),
        child: const ColoredBox(color: kBox),
      ),
    );
    expect(fired, 0, reason: 'an unchanged painter dirtied the proxy');

    await pump(
      GlassProxy.replace(
        key: key,
        painter: const SolidProxyPainter(kOther),
        child: const ColoredBox(color: kBox),
      ),
    );
    expect(fired, 1, reason: 'a changed painter did not dirty the proxy');

    // A different implementation is a repaint whatever it says about itself:
    // `shouldRepaint` may only compare against its own kind.
    await pump(
      GlassProxy.replace(
        key: key,
        painter: const GradientProxyPainter(
          LinearGradient(colors: <Color>[kBox, kOther]),
        ),
        child: const ColoredBox(color: kBox),
      ),
    );
    expect(fired, 2, reason: 'a painter of another type was compared by value');

    // Dropping the painter and the role together is two changes and reports as
    // two: the role setter and the painter setter each own their own answer.
    await pump(
      GlassProxy.hidden(
        key: key,
        child: const ColoredBox(color: kBox),
      ),
    );
    expect(fired, 4);
  });

  // -------------------------------------------------------------------------
  // 8. Alternating the policy between passes.
  // -------------------------------------------------------------------------

  testWidgets('four passes under alternating policies move no layer of the live tree', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_mount(_page(_alternating())));
    await tester.pumpAndSettle();
    final RenderRepaintBoundary root = _boundaryOf();

    final ui.Image before = root.toImageSync();
    final TreeSnapshot start = TreeSnapshot.of(root);

    // Both knobs a caller could plausibly alternate: which nodes the policy
    // keeps, and whether the canvas filter is installed. Four passes, because
    // two would not distinguish "the first pass broke it" from "the pass after
    // a different one breaks it".
    for (var i = 0; i < 4; i++) {
      final _Pass pass = _passOver(
        root,
        shadowFilter: i.isEven ? null : ShadowFilter(),
        policy: i.isEven ? paintEverything : _skipBoundaries,
      );
      final List<String> drift = TreeSnapshot.of(root).diffFrom(start);
      expect(drift, isEmpty, reason: 'pass $i changed the live tree: $drift');
      expect(pass.log.layersMinted, 0, reason: 'pass $i minted a layer');
      expect(pass.log.errors, isEmpty, reason: 'pass $i: ${pass.log.errors}');
      // Without these the arm would pass on a fixture with nothing in it to
      // disturb: no boundary crossed is no retained layer touched, and no node
      // skipped is not an alternating policy.
      if (i.isEven) {
        expect(pass.log.boundariesCrossed, greaterThan(0), reason: 'pass $i crossed no boundary');
        expect(
          pass.log.compositedEffectsApplied,
          greaterThan(0),
          reason: 'pass $i probed no updateCompositedLayer',
        );
      } else {
        expect(pass.log.skipped, isNotEmpty, reason: 'pass $i skipped nothing');
      }
      pass.dispose();
    }

    // The end-to-end version of the same claim, and the one that would catch a
    // violation the snapshot has no field for: the engine's own frame, taken
    // through the stock capture, before and after four passes.
    final ui.Image after = root.toImageSync();
    final _Diff diff = await _compare(tester, before, after);
    before.dispose();
    after.dispose();
    expect(diff.differing, 0, reason: 'the live frame changed under the passes: $diff');
  });
}

/// A policy that composes differently from `paintEverything` on every branch
/// this fixture has — repaint boundaries are exactly where a retained layer
/// lives, so it is also the policy most likely to disturb one.
WalkAction _skipBoundaries(RenderObject child) => child.isRepaintBoundary ? WalkAction.skip : WalkAction.paint;

// ---------------------------------------------------------------------------
// Fixtures.
// ---------------------------------------------------------------------------

const Rect _first = Rect.fromLTWH(40, 40, 80, 60);
const Rect _second = Rect.fromLTWH(40, 120, 80, 40);

/// An opaque page, so a subtraction has something to fall back to.
Widget _page(Widget body) => ColoredBox(color: kPage, child: body);

Widget _boxes({bool first = true}) => Stack(
  children: <Widget>[
    if (first)
      Positioned.fromRect(
        rect: _first,
        child: const ColoredBox(color: kBox),
      ),
    Positioned.fromRect(
      rect: _second,
      child: const ColoredBox(color: kOther),
    ),
  ],
);

Widget _replaced(GlassProxyPainter painter) => Stack(
  children: <Widget>[
    Positioned.fromRect(
      rect: _first,
      child: GlassProxy.replace(
        painter: painter,
        child: const ColoredBox(color: kOther),
      ),
    ),
    Positioned.fromRect(
      rect: _second,
      child: const ColoredBox(color: kOther),
    ),
  ],
);

/// Content first, then [top] over all of it — the shape an occlusion cut needs.
Widget _over(Widget top) => Stack(
  children: <Widget>[
    Positioned.fromRect(
      rect: _first,
      child: const ColoredBox(color: kBox),
    ),
    Positioned.fromRect(
      rect: _second,
      child: const ColoredBox(color: kOther),
    ),
    Positioned.fill(child: top),
  ],
);

/// One of each role, so the live-frame control covers all four at once.
Widget _content({required bool marked}) => Stack(
  children: <Widget>[
    Positioned.fromRect(
      rect: _first,
      child: marked
          ? GlassProxy.replace(
              painter: const SolidProxyPainter(kOther),
              child: const ColoredBox(color: kBox),
            )
          : const ColoredBox(color: kBox),
    ),
    Positioned.fromRect(
      rect: _second,
      child: marked ? const GlassProxy.hidden(child: ColoredBox(color: kOther)) : const ColoredBox(color: kOther),
    ),
    Positioned.fromRect(
      rect: const Rect.fromLTWH(130, 40, 40, 40),
      child: marked ? const GlassProxy.opaque(child: ColoredBox(color: kBox)) : const ColoredBox(color: kBox),
    ),
    Positioned.fromRect(
      rect: const Rect.fromLTWH(130, 100, 40, 40),
      child: marked
          ? const GlassProxy.verbatim(child: CustomPaint(painter: _BlurredDot()))
          : const CustomPaint(painter: _BlurredDot()),
    ),
  ],
);

/// The constructs that make the invariant non-trivial: repaint boundaries, which
/// is where `updateCompositedLayer` gets probed for an effect a direct `paint()`
/// cannot see; an opacity, whose whole effect lives in a layer; and a clip, which
/// is a layer only when something below it composites.
Widget _alternating() => Stack(
  children: <Widget>[
    Positioned.fromRect(
      rect: _first,
      child: RepaintBoundary(
        child: Opacity(
          opacity: 0.5,
          child: GlassProxy.replace(
            painter: const SolidProxyPainter(kOther),
            child: const ColoredBox(color: kBox),
          ),
        ),
      ),
    ),
    Positioned.fromRect(
      rect: _second,
      child: const RepaintBoundary(
        child: GlassProxy.hidden(child: ColoredBox(color: kOther)),
      ),
    ),
    Positioned.fromRect(
      rect: const Rect.fromLTWH(130, 40, 50, 50),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const GlassProxy.verbatim(child: CustomPaint(painter: _BlurredDot())),
      ),
    ),
  ],
);

/// A blurred draw that is not a shadow — the false positive
/// `ShadowFilter.dropMaskFiltered` is documented to have, and the one thing
/// `GlassProxy.verbatim` exists to rescue.
class _BlurredDot extends CustomPainter {
  const _BlurredDot();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 4,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );

  @override
  bool shouldRepaint(_BlurredDot oldDelegate) => false;
}

/// Paints far outside the box it was given. Must be indistinguishable from one
/// that filled the box exactly.
class _OverdrawPainter extends GlassProxyPainter {
  const _OverdrawPainter();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Rect.fromLTWH(-1000, -1000, size.width + 2000, size.height + 2000),
    Paint()..color = kOther,
  );

  @override
  bool shouldRepaint(_OverdrawPainter oldPainter) => false;
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

Widget _mount(Widget child) => MediaQuery(
  data: const MediaQueryData(size: kArea, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox.fromSize(size: kArea, child: child),
      ),
    ),
  ),
);

final GlobalKey _boundaryKey = GlobalKey();

RenderRepaintBoundary _boundaryOf() => _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

/// The frame the engine itself produced, for the control that says the markers
/// are invisible to it.
Future<ui.Image> _stock(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_mount(child));
  await tester.pumpAndSettle();
  return _boundaryOf().toImageSync();
}

class _Pass {
  _Pass(this._handle, this.image, this.log, this.root, this.policy);

  final LayerHandle<OffsetLayer> _handle;
  final ui.Image image;
  final WalkLog log;
  final RenderObject root;
  final OcclusionPolicy? policy;

  void dispose() {
    image.dispose();
    _handle.layer = null;
  }
}

/// Mounts [child] and records one proxy pass over it.
Future<_Pass> _walk(
  WidgetTester tester,
  Widget child, {
  ShadowFilter? shadowFilter,
  OcclusionPolicy Function(RenderObject root)? plan,
}) async {
  await tester.pumpWidget(_mount(child));
  await tester.pumpAndSettle();
  final RenderRepaintBoundary root = _boundaryOf();
  final OcclusionPolicy? occlusion = plan?.call(root);
  return _passOver(
    root,
    shadowFilter: shadowFilter,
    policy: occlusion?.call ?? paintEverything,
    occlusion: occlusion,
  );
}

/// One pass over an already-mounted tree.
_Pass _passOver(
  RenderRepaintBoundary root, {
  ShadowFilter? shadowFilter,
  WalkPolicy policy = paintEverything,
  OcclusionPolicy? occlusion,
}) {
  final handle = LayerHandle<OffsetLayer>()..layer = OffsetLayer();
  final log = WalkLog();
  final context = ProxyWalkContext(
    handle.layer!,
    Offset.zero & kArea,
    log: log,
    policy: policy,
    shadowFilter: shadowFilter,
  )..paintChild(root, Offset.zero);
  context.finish();
  return _Pass(handle, handle.layer!.toImageSync(Offset.zero & kArea), log, root, occlusion);
}

// ---------------------------------------------------------------------------
// Pixel comparison. Same shape as M12's, because the numbers have to compare.
// ---------------------------------------------------------------------------

class _Diff {
  const _Diff(this.maxDelta, this.differing, this.total);

  final int maxDelta;
  final int differing;
  final int total;

  @override
  String toString() => '$differing/$total px, worst $maxDelta';
}

Future<_Diff> _compare(WidgetTester tester, ui.Image a, ui.Image b) async {
  expect(a.width, b.width);
  expect(a.height, b.height);
  late _Diff diff;
  // `toByteData` is an engine future: a widget test's fake clock never completes
  // one outside `runAsync`, and the failure is a ten-minute timeout naming the
  // timeout rather than the call.
  await tester.runAsync(() async {
    final ByteData? da = await a.toByteData();
    final ByteData? db = await b.toByteData();
    if (da == null || db == null) {
      throw StateError('an image came back without bytes');
    }
    final Uint8List pa = da.buffer.asUint8List();
    final Uint8List pb = db.buffer.asUint8List();
    var maxDelta = 0;
    var differing = 0;
    for (var i = 0; i < pa.length; i += 4) {
      var worst = 0;
      for (var c = 0; c < 4; c++) {
        final int d = (pa[i + c] - pb[i + c]).abs();
        if (d > worst) {
          worst = d;
        }
      }
      if (worst > 0) {
        differing++;
        if (worst > maxDelta) {
          maxDelta = worst;
        }
      }
    }
    diff = _Diff(maxDelta, differing, pa.length ~/ 4);
  });
  return diff;
}
