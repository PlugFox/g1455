// Phase A, step 7 — the surface type, and the register it feeds.
//
// `flutter test test/glass/glass_surface_test.dart`
//
// The surface draws no glass yet (the shader is 9% of the addition and is
// deliberately last, D63), so everything worth checking here is about the two
// things it *does* do, and each has a way of being silently wrong:
//
//  1. **It must change no pixel.** A declaration that quietly painted something
//     would be discovered by a person looking at a screenshot, which is the
//     slowest instrument in the project. Checked the way D115's markers were:
//     byte for byte against the same tree without it.
//  2. **It must report where it actually is.** A surface inside a scroll view
//     or a transform has a paint offset that is not a place on the screen, and
//     the playground's own rig — which reports `offset & size` and says so —
//     would pass every test that does not put a layer above the surface. The
//     capture works in scene coordinates, so a register in the wrong space is a
//     backdrop sampled from the wrong part of the screen, and that shows up as
//     glass that looks fine while showing the wrong thing.
//
// The lifecycle is the third thing, and it is where a register leaks: a surface
// that unmounts, moves, or loses its scope has to leave, or the ledger counts
// glass nobody can see and the tax it reports is fiction.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kArea = Size(400, 400);

void main() {
  // -------------------------------------------------------------------------
  // 1. It is invisible.
  // -------------------------------------------------------------------------

  testWidgets('declaring a surface changes no pixel', (WidgetTester tester) async {
    const Widget content = _Content();
    final ui.Image bare = await _frame(tester, const SizedBox(child: content));
    final ui.Image declared = await _frame(
      tester,
      const GlassSurface(borderRadius: BorderRadius.all(Radius.circular(24)), child: content),
    );
    final _Diff diff = await _compare(tester, bare, declared);
    expect(diff.differing, 0, reason: 'the declaration painted something: $diff');
    // The control that keeps the arm from being "two blank frames agree": the
    // same comparison against a deliberately different tree has to fail.
    final ui.Image other = await _frame(tester, const SizedBox(child: _Content(shift: 3)));
    expect((await _compare(tester, bare, other)).differing, greaterThan(0));
  });

  // -------------------------------------------------------------------------
  // 2. It reports where it is.
  // -------------------------------------------------------------------------

  testWidgets('the rect is global, not the paint offset', (WidgetTester tester) async {
    // A surface pushed down by a layer-bearing ancestor. `Transform` composites,
    // so the paint offset inside that layer is (0, 0) while the surface sits at
    // (40, 120) on the screen — the whole defect this getter exists to avoid.
    final ledger = GlassLedger();
    await _mount(
      tester,
      ledger,
      Transform.translate(
        offset: const Offset(40, 120),
        child: const SizedBox(
          width: 200,
          height: 80,
          child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
    );
    expect(ledger.registeredCount, 1);
    expect(ledger.surfaces.single.rect, const Rect.fromLTWH(40, 120, 200, 80));
  });

  testWidgets('a scale is in the rect, and so is the area it implies', (WidgetTester tester) async {
    final ledger = GlassLedger();
    await _mount(
      tester,
      ledger,
      Transform.scale(
        scale: 2,
        alignment: Alignment.topLeft,
        child: const SizedBox(
          width: 100,
          height: 50,
          child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
      ),
    );
    final GlassSurfaceRecord record = ledger.surfaces.single;
    expect(record.rect, const Rect.fromLTWH(0, 0, 200, 100));
    // The tax follows what is on the screen, so a surface drawn at twice the
    // size costs four times the area. The shape area is the *unscaled* shape's,
    // because that is what the render object knows — named as a gap rather than
    // papered over, and it is the only place the two areas disagree by
    // construction.
    expect(record.rectArea, 20000);
    expect(record.shapeArea, lessThan(100 * 50.0));
  });

  testWidgets('a surface scrolled out of the view is still glass, and off-screen', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _mount(
      tester,
      ledger,
      SizedBox.fromSize(
        size: kArea,
        child: ListView(
          controller: controller,
          children: <Widget>[
            const SizedBox(
              height: 100,
              child: GlassSurface(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    expect(ledger.surfaces.single.rect.top, 0);
    controller.jumpTo(60);
    await tester.pump();
    expect(
      ledger.surfaces.single.rect.top,
      -60,
      reason: 'the register did not follow the scroll — it is reporting a paint offset',
    );

    final GlassLoad load = ledger.read(
      viewSize: kArea,
      model: GlassSurfaceCostModel.adrenoCycles,
    );
    expect(load.rectAreaLogical, 400 * 100);
    expect(
      load.onScreenRectAreaLogical,
      400 * 40,
      reason: 'the part of the surface above the viewport was charged for',
    );
  });

  // -------------------------------------------------------------------------
  // 3. The lifecycle.
  // -------------------------------------------------------------------------

  testWidgets('a surface leaves the register when it goes', (WidgetTester tester) async {
    final ledger = GlassLedger();
    await _mount(tester, ledger, const SizedBox(width: 100, height: 100, child: GlassSurface()));
    expect(ledger.registeredCount, 1);
    await _mount(tester, ledger, const SizedBox(width: 100, height: 100));
    expect(ledger.registeredCount, 0, reason: 'the register kept a surface that no longer exists');
  });

  test('a surface that cannot say where it is is not counted', () {
    // The guard that carries the lifecycle, and the reason `detach` is belt and
    // braces rather than the mechanism: a surface outside a tree, or inside one
    // and not yet laid out, has no place to report — `size` throws before
    // layout and `getTransformTo` asserts while detached. So it answers null
    // and the register skips it, which keeps `read()` honest through every
    // frame in which a surface exists and is nowhere.
    //
    // The two conditions are not separated here, and saying so is cheaper than
    // implying otherwise: a freshly built render object is in both states at
    // once, and deleting either check on its own still passes this arm.
    // Standing a laid-out box up outside a pipeline, which is what would tell
    // them apart, is more rig than the distinction is worth.
    final surface = RenderGlassSurface(BorderRadius.circular(8), null);
    addTearDown(surface.dispose);
    final ledger = GlassLedger()..register(surface);
    expect(surface.readGeometry(), isNull);
    expect(ledger.registeredCount, 1);
    expect(ledger.surfaces, isEmpty);
    final GlassLoad load = ledger.read(
      viewSize: kArea,
      model: GlassSurfaceCostModel.adrenoCycles,
    );
    expect(load.surfaceCount, 0);
    expect(load.rectAreaLogical, 0);
    expect(load.bounds, isNull);
  });

  testWidgets('a surface moved across the tree is registered once', (WidgetTester tester) async {
    // A `GlobalKey` move detaches and re-attaches the same render object. The
    // register is keyed by that object, so the risk is not a duplicate — it is
    // the entry being dropped on detach and never coming back, because the
    // surface is repainted at its new place in the *same* frame.
    final ledger = GlassLedger();
    final key = GlobalKey();
    Widget tree({required bool second}) => Column(
      children: <Widget>[
        SizedBox(
          width: 100,
          height: 100,
          child: second ? null : GlassSurface(key: key),
        ),
        SizedBox(
          width: 200,
          height: 50,
          child: second ? GlassSurface(key: key) : null,
        ),
      ],
    );
    await _mount(tester, ledger, tree(second: false));
    expect(ledger.surfaces.single.rect.size, const Size(100, 100));
    await _mount(tester, ledger, tree(second: true));
    expect(ledger.registeredCount, 1, reason: 'the move left a ghost or lost the surface');
    expect(ledger.surfaces.single.rect.size, const Size(200, 50));
  });

  testWidgets('no scope above is not a crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 100, height: 100, child: GlassSurface()),
        ),
      ),
    );
    final RenderGlassSurface surface = tester.renderObject<RenderGlassSurface>(
      find.byType(GlassSurface),
    );
    expect(surface.globalRect.size, const Size(100, 100));
    expect(
      surface.toDiagnosticsNode().toStringDeep(),
      contains('no GlassScope above'),
      reason: 'a surface with nowhere to register should say so',
    );
  });

  testWidgets('the register notifies about the set, never about the geometry', (
    WidgetTester tester,
  ) async {
    // The contract, and it is the reason a scroll is not a problem: what is
    // stored is the surface, what is computed is where it is. So a panel that
    // moves every frame notifies nobody — a listener that rebuilt on that would
    // rebuild once per frame, which is what a `Listenable` here exists to avoid
    // — and the number it reports is still right the moment anybody asks.
    final ledger = GlassLedger();
    var notifications = 0;
    ledger.addListener(() => notifications++);
    await _mount(tester, ledger, const SizedBox(width: 100, height: 100, child: GlassSurface()));
    expect(notifications, 1);

    await _mount(tester, ledger, const SizedBox(width: 120, height: 100, child: GlassSurface()));
    expect(notifications, 1, reason: 'a resize notified, and the set did not change');
    expect(ledger.surfaces.single.rect.width, 120, reason: 'the geometry was read stale');

    await _mount(tester, ledger, const SizedBox(width: 120, height: 100));
    expect(notifications, 2, reason: 'a surface leaving the tree is a change to the set');
  });

  // -------------------------------------------------------------------------
  // 4. What the register adds up to.
  // -------------------------------------------------------------------------

  testWidgets('two surfaces: the count, the area, and what one capture would span', (
    WidgetTester tester,
  ) async {
    final ledger = GlassLedger();
    await _mount(
      tester,
      ledger,
      SizedBox.fromSize(
        size: kArea,
        child: const Stack(
          children: <Widget>[
            Positioned(left: 0, top: 0, width: 100, height: 100, child: GlassSurface()),
            Positioned(left: 300, top: 300, width: 100, height: 100, child: GlassSurface()),
          ],
        ),
      ),
    );
    final GlassLoad load = ledger.read(
      viewSize: kArea,
      model: GlassSurfaceCostModel.adrenoCycles,
    );
    expect(load.surfaceCount, 2);
    expect(load.rectAreaLogical, 20000);
    expect(load.screensOfGlass, closeTo(20000 / (400 * 400), 1e-9));
    expect(load.bounds, const Rect.fromLTWH(0, 0, 400, 400));
    // Phase B's question, in the units its budget is quoted in: two chips in
    // opposite corners make one shared capture pay for the whole screen.
    expect(load.deadAreaLogical, 160000 - 20000);
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

/// Content with something to see in it, so a pixel comparison has signal.
class _Content extends StatelessWidget {
  const _Content({this.shift = 0});

  final double shift;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _Bars(shift),
    size: kArea,
  );
}

class _Bars extends CustomPainter {
  const _Bars(this.shift);

  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3366CC);
    for (var y = 0.0; y < size.height; y += 20) {
      canvas.drawRect(Rect.fromLTWH(shift, y, size.width, 10), paint);
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => oldDelegate.shift != shift;
}

final GlobalKey _boundaryKey = GlobalKey();

Future<void> _mount(WidgetTester tester, GlassLedger ledger, Widget child) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kArea, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassScope(
          ledger: ledger,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _boundaryKey,
              // Loose inside the box: a `SizedBox` under tight constraints is
              // not a size, it is the parent's size wearing one, and every arm
              // below that asks where a 200x80 surface is would have been
              // asking about a 400x400 one.
              child: SizedBox.fromSize(
                size: kArea,
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<ui.Image> _frame(WidgetTester tester, Widget child) async {
  await _mount(tester, GlassLedger(), child);
  return (_boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImageSync();
}

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
  // one outside `runAsync`.
  await tester.runAsync(() async {
    final ByteData? da = await a.toByteData();
    final ByteData? db = await b.toByteData();
    final Uint8List pa = da!.buffer.asUint8List();
    final Uint8List pb = db!.buffer.asUint8List();
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
