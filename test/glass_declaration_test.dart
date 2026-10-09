// What the declaration promises, and what an application can actually keep.
//
// `flutter test test/glass_declaration_test.dart`
//
// Holding the proxy removes 97.8% of what this package adds to a frame
// (measured on Adreno), which makes `GlassContentDeclaration.declared` the
// largest lever the route has — and the largest hole in it, a scroll, is an
// observation the host makes for itself. This file is the inventory that
// question deserves: for every ordinary way the pixels under the glass change,
// does the oracle see it, or is the application expected to say so?
//
// The reason it is a table in code rather than a paragraph is the shape of the
// failure. A change nobody declares is not an exception and not a dropped
// frame: the glass goes on showing the picture it was born with, on a screen
// that is visibly moving, and nothing anywhere reports it. So each row here is
// a scene that changes in one specific way, and the arm reads the host's own
// `recorded` counter — the same counter the device reports quote.
//
// Every arm runs the same scene twice — the default, and the same scene told
// to distrust the watch — because "held" means nothing without the arm that
// records. A scene that stopped changing for an unrelated reason would hold in
// both.
//
// **Holding is the default,** and the rows are mounted the way they ship: no
// `content:` at all, so each row is a claim about what an application gets
// without asking for anything. The control beside it names `undeclared`, which
// is what that value now means — the escape hatch, not the floor.
//
// **Six of these rows are seen only by `ProxyLayerWatch`.** The observations
// the host makes for itself all stop at a nested repaint boundary, and a
// realistic screen crosses 8 to 15 of them; the watch asks the composited layer
// tree instead of the render tree. The comments name which mechanism sees each
// row, because that is the whole content of the table — and a break that turns
// the watch off fails exactly those six.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_walk.dart';

const Size kScreen = Size(400, 600);

void main() {
  testWidgets('a still screen is held, and the same scene silent is not', (
    WidgetTester tester,
  ) async {
    // The baseline every other row is read against — and, since the watch
    // exists, the arm that says it does not feed on itself. Recording publishes
    // a proxy, publishing repaints every surface, and a surface repainting mints
    // a new picture in the layer tree the watch is reading. The watch skips the
    // surfaces for exactly that reason, and this is where the skipping is
    // measured: one capture, then four frames that record nothing.
    final _Rig declared = await _mount(tester);
    await _idle(tester, 4);
    expect(declared.host.recorded, 1);

    final _Rig silent = await _mount(
      tester,
      content: GlassContentDeclaration.undeclared,
    );
    await _idle(tester, 4);
    expect(silent.host.recorded, greaterThan(4));
  });

  testWidgets('content repainting in place is seen without being declared', (
    WidgetTester tester,
  ) async {
    // The commonest change after a scroll, and the one every chart, spinner and
    // video-shaped widget makes: a `CustomPaint` whose painter repaints against
    // a `Listenable`. Nothing rebuilds, nothing moves, no marker changes — the
    // two inputs the oracle owns both read "nothing happened".
    //
    // What sees it is the host's own repaint: the content is not behind a
    // repaint boundary of its own, so dirtying it dirties the host's boundary,
    // and the host is painted with it.
    final _Rig rig = await _mount(tester, content: GlassContentDeclaration.declared);
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;

    rig.tick.value++;
    await tester.pump();
    expect(
      rig.host.recorded,
      greaterThan(held),
      reason: 'the proxy is frozen over content that repainted under it',
    );

    // The control for the observation itself, and it is the arm that would
    // catch the obvious way of building it wrong: the capture pass paints this
    // same subtree every time it runs, so an observer that counted its own
    // pass's paints would declare a change on every frame and hold nothing at
    // all. A still screen still holds.
    final int after = rig.host.recorded as int;
    await _idle(tester, 4);
    expect(after, rig.host.recorded, reason: 'the observer is watching its own capture pass');
  });

  testWidgets('content behind a repaint boundary is seen, though not by the host', (
    WidgetTester tester,
  ) async {
    // A repaint boundary absorbs the dirt: its child repaints into its own layer
    // and the host is never painted, so nothing above it can observe the change.
    // Same mechanism as the sliver children of a scroll, and there is no
    // notification to lean on. What sees it is the layer the boundary
    // repainted into, which carries a new `ui.Picture` whatever the render tree
    // did.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.boundary,
    );
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;

    rig.tick.value++;
    await tester.pump();
    expect(
      rig.host.recorded,
      greaterThan(held),
      reason: 'the proxy is frozen over content that repainted behind a boundary',
    );

    // Still holds when nothing changes: the arm would also pass on a watch that
    // reported a change every frame, which is what the control below mounts on
    // purpose.
    final int after = rig.host.recorded as int;
    await _idle(tester, 4);
    expect(after, rig.host.recorded);

    // And the control: told to distrust the watch, the same scene records
    // regardless.
    final _Rig silent = await _mount(
      tester,
      content: GlassContentDeclaration.undeclared,
      wrap: _Wrap.boundary,
    );
    await _idle(tester, 4);
    expect(silent.host.recorded, greaterThan(4));
  });

  testWidgets('an Opacity is a repaint boundary too, and hides it from the host alone', (
    WidgetTester tester,
  ) async {
    // Worth its own row because nobody writes `Opacity` meaning "stop the
    // repaint here": `RenderOpacity.isRepaintBoundary` is `alwaysNeedsCompositing`,
    // which is true for any child at alpha > 0 (`proxy_box.dart:884-887`). So a
    // fade over changing content is the same hole as an explicit boundary, and
    // an `AnimatedOpacity` puts one there for the duration of the animation.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.opacity,
    );
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;

    rig.tick.value++;
    await tester.pump();
    expect(rig.host.recorded, greaterThan(held));
  });

  testWidgets('a fade changes the screen and paints nothing, and is seen anyway', (
    WidgetTester tester,
  ) async {
    // A different mechanism rather than a deeper case of the row above, and the
    // only one in this file where the pixels change with no `paint` anywhere.
    // `RenderOpacity.opacity=` and `RenderAnimatedOpacityMixin._updateOpacity`
    // are the framework's only two callers of `markNeedsCompositedLayerUpdate`
    // (`proxy_box.dart:913,1061`); for a boundary that already owns a layer
    // that call goes to `flushPaint`'s second branch, `updateLayerProperties`,
    // which calls `updateCompositedLayer` and nothing else
    // (`object.dart:1321-1328,199-219`). So a `FadeTransition` in flight — a
    // route transition, a fading card, any `AnimatedOpacity` mid-animation —
    // changes every pixel under it while the render tree is entirely still. Which
    // is why the watch reads layer *properties* and not only pictures: this row
    // is the one that no amount of paint counting can reach.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.fade,
    );
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;
    final int paints = rig.inner.framePaints;

    rig.fade.value = 0.4;
    await tester.pump();
    // The mechanism, asserted rather than argued: the composited alpha really
    // did move, so the screen really is showing something else. Without this
    // the two expectations below pass on a fixture that changed nothing —
    // which is the shape of a negative control that succeeds for the wrong
    // reason. `debugLayer` is readable because this runs under `flutter test`;
    // profile hard-wires the neighbouring debug fields, which is why the
    // package's own code may not do this.
    expect(_fadeAlpha(tester), isNot(255));
    expect(
      rig.inner.framePaints,
      paints,
      reason: 'the fade repainted its child, so this arm is about a repaint after all',
    );
    expect(
      rig.host.recorded,
      greaterThan(held),
      reason: 'the alpha moved, nothing painted, and the proxy stayed as it was',
    );

    // The control, and it is what separates "nobody painted" from "the fixture
    // stopped drawing": the same subtree still paints when its *content*
    // changes.
    final int seen = rig.host.recorded as int;
    rig.tick.value++;
    await tester.pump();
    expect(rig.inner.framePaints, greaterThan(paints));
    expect(rig.host.recorded, greaterThan(seen));
  });

  testWidgets('an animated filter is the same class, and it is the third of three', (
    WidgetTester tester,
  ) async {
    // The class is exactly three widgets wide, and this is the third: a
    // rebuilt `ImageFiltered` whose filter changed
    // (`widgets/image_filter.dart:88-95`). Worth its own row because it is the
    // one that changes the *most* pixels — an animating blur is a whole screen
    // going soft — and because it arrives through a **rebuild** rather than
    // through an animation ticking a render object, so a reader looking for
    // "animations are the hole" would place the boundary of the class wrongly.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.filter,
    );
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;
    final int paints = rig.inner.framePaints;
    final ImageFilter before = _layerFilter(tester);

    rig.fade.value = 0.4;
    await tester.pump();
    expect(_layerFilter(tester), isNot(before));
    expect(rig.inner.framePaints, paints, reason: 'the rebuild repainted, so this is not the class');
    expect(rig.host.recorded, greaterThan(held));
  });

  testWidgets('a backdrop group that re-keys is seen, and it paints nothing at all', (
    WidgetTester tester,
  ) async {
    // A layer property that changes with no new picture, found by auditing
    // the watch's table against `layer.dart` rather than by any scene.
    // `BackdropGroup` is an `InheritedWidget` that mints a fresh `BackdropKey`
    // on every build it is not handed one for, so the commonest use of grouped
    // backdrop filters changes `BackdropFilterLayer.backdropKey` — which
    // reaches the engine as `pushBackdropFilter(backdropId:)` and decides which
    // snapshot the filter reads — and changes nothing else at all.
    // `RenderBackdropFilter` keeps its layer (`layer ??=
    // BackdropFilterLayer()`) and assigns the property, and the repaint that
    // `markNeedsPaint` schedules stops at a boundary that records no picture,
    // so before the property was in the signature this frame read as "nothing
    // happened".
    //
    // The row is stronger than the three above it in one way: the filter's own
    // widget is never rebuilt by anything in the scene. It is notified because
    // it depends on the group.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.grouped,
    );
    await _idle(tester, 3);
    final int held = rig.host.recorded as int;
    final int paints = rig.inner.framePaints;
    final BackdropKey? before = _backdropKey(tester);
    expect(before, isNotNull, reason: 'the filter never joined a group, so the row tests nothing');

    rig.fade.value = 0.4;
    await tester.pump();
    expect(
      _backdropKey(tester),
      isNot(before),
      reason: 'the group did not re-key, so the row tests nothing',
    );
    expect(
      rig.inner.framePaints,
      paints,
      reason:
          'something under the filter repainted, so the watch could have seen this '
          'through a picture and the row is about a repaint after all',
    );
    expect(
      rig.host.recorded,
      greaterThan(held),
      reason: 'the group re-keyed, no picture moved, and the proxy stayed as it was',
    );
  });

  testWidgets('a layer type the table does not know is never held', (
    WidgetTester tester,
  ) async {
    // The safety valve, and the reason the watch's table is a whitelist. What it
    // cannot read, it must not hold through: a `TextureLayer` whose pixels
    // arrive from outside Dart, a platform view, a follower whose transform
    // belongs to a leader elsewhere — and, the case this arm actually stands
    // for, whatever the next SDK adds to `layer.dart`. A custom `ContainerLayer`
    // subclass is exactly that: a type the table has never seen.
    //
    // The scene is otherwise the one the first arm holds through, so the
    // difference between "records for ever" and "records once" is the strange
    // layer and nothing else.
    final _Rig rig = await _mount(
      tester,
      wrap: _Wrap.strange,
    );
    await _idle(tester, 4);
    expect(
      rig.host.recorded,
      greaterThan(3),
      reason: 'a layer nobody can read was held through, which is a wrong picture waiting',
    );
  });

  testWidgets('a published proxy repaints the surface and not the screen under it', (
    WidgetTester tester,
  ) async {
    // Not about the declaration at all, and it is what makes the row above
    // possible. `RenderGlassSurface` listens to the proxy handle with
    // `markNeedsPaint`, and `markNeedsPaint` walks up to the nearest repaint
    // boundary — which, if the surface is not one itself, is the host's own.
    // A host told to distrust the watch publishes a proxy on every frame, and
    // that is what this arm mounts, because the claim is about what a publish
    // costs the screen under it. Without the fix, the whole
    // screen under the host is repainted on every frame, and the host's
    // observation of that repaint would be an observation of itself.
    //
    // The counter ignores the capture pass on purpose: that pass paints
    // everything by construction, and counting it would measure the walk rather
    // than the frame.
    final _Rig rig = await _mount(
      tester,
      content: GlassContentDeclaration.undeclared,
    );
    await _idle(tester, 6);
    expect(
      rig.host.recorded,
      greaterThan(4),
      reason: 'the silent host stopped recording, so there is nothing to publish',
    );
    expect(
      rig.counter.framePaints,
      lessThan(3),
      reason:
          'the screen under the glass is repainted whenever a proxy is published '
          '(${rig.counter.framePaints} paints), so every frame pays for a full '
          'repaint of the host subtree',
    );
    expect(rig.counter.passPaints, greaterThan(3), reason: 'the capture pass never ran');
  });

  testWidgets("a nested host's captures are not the outer host's changes", (
    WidgetTester tester,
  ) async {
    // The outer host records every frame — it is mounted `undeclared` for
    // exactly that, since holding is the default — and every one of those
    // captures walks through the inner host. The inner host is left at the
    // default, its own screen never changes, and it must therefore record once.
    final innerKey = GlobalKey();
    final outerKey = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: GlassHost(
              key: outerKey,
              content: GlassContentDeclaration.undeclared,
              hardware: GlassHardware.appleMetal,
              finish: GlassFinish.identity,
              child: _NestedHosts(innerKey: innerKey),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dynamic inner = innerKey.currentState! as dynamic;
    // The control: without this the scene proves nothing, and the first version
    // of it proved nothing — an outer host whose ledger is empty never captures,
    // so nothing ever walked through the inner one.
    expect(
      (outerKey.currentState! as dynamic).recorded,
      greaterThan(4),
      reason: 'the outer host never captured, so no pass walked through the inner one',
    );
    expect(
      inner.recorded,
      1,
      reason: "the inner host heard the outer host's capture pass as a change",
    );
  });

  test('what the region is worth is what the two digests on disk still say', () {
    // The rule about constants: a number quoted in `lib/` needs its source in
    // the repository, and a test that reads that source is the right run. What
    // it asserts is deliberately narrower than what the run showed, because
    // the second seed refused the wider claim — see below.
    final Map<String, _Cell> a = _cells('provenance/digest/s22u-aside-a.json');
    final Map<String, _Cell> b = _cells('provenance/digest/s22u-aside-b.json');

    for (final Map<String, _Cell> seed in <Map<String, _Cell>>[a, b]) {
      // The mechanism, by counters, and this part is exact in both seeds: one
      // capture in a whole window against one per frame, on two scenes whose
      // trees differ by 500 logical pixels of placement.
      final _Cell aside = seed['change_aside/glass_declared']!;
      final _Cell behind = seed['change_behind/glass_declared']!;
      expect(aside.captures, 1);
      // As a ratio rather than as `frames - 1`: the two counters are read off
      // different objects and one of them can be a frame ahead, which is the
      // hazard of counters with different reset points. Nothing here turns on
      // the last frame.
      expect(aside.missed / aside.frames, greaterThan(0.99));
      expect(behind.captures, behind.frames);
      expect(behind.missed, 0);

      // The price, as the ratio of the two glass arms *within one scene* —
      // which is the only form of it that survived the second seed. As a share
      // of the route's addition over `plain` the same two runs say 94% and 56%,
      // because that share is a small difference of large numbers and the
      // per-arm spread on this device runs to 12.6%.
      double ratio(String scene) => seed['$scene/glass_declared']!.cycles / seed['$scene/glass_silent']!.cycles;
      expect(ratio('change_aside'), lessThan(0.95));
      // And the control that says the saving belongs to the placement: the same
      // two arms on the twin scene, where nothing is held, agree to well under
      // a percent — in both seeds, to six parts in ten thousand.
      expect(ratio('change_behind'), closeTo(1.006, 0.004));
    }
  });
}

typedef _Cell = ({double cycles, double captures, double missed, double frames});

/// One digest's cells, by `scene/variant`, refusing a run the harness itself
/// called into question.
Map<String, _Cell> _cells(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('the digest a constant came from is gone: $path');
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  for (final Object? c in report['caveats']! as List<Object?>) {
    final String caveat = c! as String;
    // The same whitelist `glass_group_test.dart` keeps, and for the same
    // reason: anything the harness says that is not one of these two sentences
    // disqualifies the run.
    final bool allowed =
        (caveat.contains('Thermal clamp engaged') && caveat.contains('bound on none')) ||
        caveat.contains('Exynos nodes');
    expect(allowed, isTrue, reason: '$path: a caveated run is not a measurement — $caveat');
  }
  return <String, _Cell>{
    for (final Object? c in report['cells']! as List<Object?>)
      if (c! as Map<String, Object?> case final Map<String, Object?> cell)
        '${cell['scene']}/${cell['variant']}': (
          cycles: (cell['gpu_cycles_per_frame']! as num).toDouble(),
          captures: ((cell['counters']! as Map<String, Object?>)['glass_proxy_generations']! as num).toDouble(),
          missed: ((cell['counters']! as Map<String, Object?>)['glass_changes_outside_capture']! as num).toDouble(),
          frames: ((cell['counters']! as Map<String, Object?>)['frames_driven']! as num).toDouble(),
        ),
  };
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

/// What sits between the changing content and the host.
enum _Wrap {
  /// Nothing: the dirt reaches the host's boundary.
  none,

  /// A `RepaintBoundary`, the residual case.
  boundary,

  /// An `Opacity`, which is a repaint boundary whether or not anyone wanted one.
  opacity,

  /// A `FadeTransition`, whose value changes without painting anything.
  fade,

  /// An `ImageFiltered` whose filter is rebuilt: the third layer-only change.
  filter,

  /// A layer type the watch's table has never seen.
  strange,

  /// A `BackdropGroup` that re-keys: the fourth layer-only change, and the one
  /// that arrives without even a rebuild of the widget that composites it.
  grouped,
}

class _Rig {
  _Rig(this.host, this.tick, this.handle, this.counter, this.inner, this.fade);

  final dynamic host;
  final ValueNotifier<int> tick;
  final GlassProxyHandle handle;

  /// Outside the wrap: what the screen under the glass pays for a publish.
  final _RenderPaintCounter counter;

  /// Inside the wrap: whether the framework painted the changing content at all.
  final _RenderPaintCounter inner;

  final AnimationController fade;
}

Future<_Rig> _mount(
  WidgetTester tester, {
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
  _Wrap wrap = _Wrap.none,
}) async {
  final tick = ValueNotifier<int>(0);
  addTearDown(tick.dispose);
  // Driven by hand rather than by a ticker: the arms need the alpha to change
  // on a frame of their choosing, and `value=` notifies exactly as a running
  // animation does.
  final fade = AnimationController(vsync: const TestVSync(), value: 1);
  addTearDown(fade.dispose);
  final hostKey = GlobalKey();
  final counterKey = GlobalKey();
  final innerKey = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: hostKey,
            content: content,
            hardware: GlassHardware.appleMetal,
            finish: GlassFinish.identity,
            child: _Scene(
              tick: tick,
              wrap: wrap,
              counterKey: counterKey,
              innerKey: innerKey,
              fade: fade,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
  return _Rig(
    hostKey.currentState! as dynamic,
    tick,
    handle,
    counterKey.currentContext!.findRenderObject()! as _RenderPaintCounter,
    innerKey.currentContext!.findRenderObject()! as _RenderPaintCounter,
    fade,
  );
}

/// The alpha the compositor is actually using for the fade.
///
/// Read off the layer rather than off the `Animation`, because the arm's claim
/// is about what the screen shows and not about what the controller holds.
int _fadeAlpha(WidgetTester tester) {
  final RenderObject box = tester.renderObject(find.byType(FadeTransition));
  return (box.debugLayer! as OpacityLayer).alpha!;
}

/// The group key the compositor is actually using, for the same reason.
BackdropKey? _backdropKey(WidgetTester tester) {
  final RenderObject box = tester.renderObject(find.byType(BackdropFilter));
  return (box.debugLayer! as BackdropFilterLayer).backdropKey;
}

/// The filter the compositor is actually using, for the same reason.
ImageFilter _layerFilter(WidgetTester tester) {
  final RenderObject box = tester.renderObject(find.byType(ImageFiltered));
  return (box.debugLayer! as ImageFilterLayer).imageFilter!;
}

/// Frames that nothing asked for.
///
/// A held proxy dirties nothing, so `pump` alone produces no frame at all and
/// an arm built on it would read "held" from a binding that never ran. The
/// frames are requested explicitly for the same reason the retake arms in
/// `glass_host_test.dart` request them.
Future<void> _idle(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _Scene extends StatelessWidget {
  const _Scene({
    required this.tick,
    required this.wrap,
    required this.counterKey,
    required this.innerKey,
    required this.fade,
  });

  final ValueNotifier<int> tick;
  final _Wrap wrap;
  final Key counterKey;
  final Key innerKey;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    // The counter sits inside whatever the wrap is, so an arm can tell "the
    // host did not hear it" from "the framework never painted it".
    Widget changing = _PaintCounter(
      key: innerKey,
      child: CustomPaint(painter: _Pulse(tick), size: const Size(400, 200)),
    );
    changing = switch (wrap) {
      _Wrap.none => changing,
      _Wrap.boundary => RepaintBoundary(child: changing),
      _Wrap.opacity => Opacity(opacity: 0.5, child: changing),
      _Wrap.fade => FadeTransition(opacity: fade, child: changing),
      // The child is handed to `AnimatedBuilder` rather than built inside it,
      // so the subtree under the filter is the same element across rebuilds and
      // nothing in it is marked for paint.
      _Wrap.strange => _StrangeLayerBox(child: changing),
      // The group is what rebuilds; everything below it is handed through as a
      // `child`, so the filter's element is notified as a dependent and its
      // subtree is not touched. The boundary above the filter is where the
      // repaint stops, and it draws nothing itself — which is the whole point of
      // the row: a frame where a composited property moved and no picture
      // anywhere was re-recorded.
      _Wrap.grouped => AnimatedBuilder(
        animation: fade,
        builder: (BuildContext context, Widget? child) => BackdropGroup(child: child!),
        child: RepaintBoundary(
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: RepaintBoundary(child: changing),
          ),
        ),
      ),
      _Wrap.filter => AnimatedBuilder(
        animation: fade,
        builder: (BuildContext context, Widget? child) => ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 1 + fade.value * 4, sigmaY: 1 + fade.value * 4),
          child: child,
        ),
        child: changing,
      ),
    };
    return SizedBox.fromSize(
      size: kScreen,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _PaintCounter(
              key: counterKey,
              child: const ColoredBox(color: Color(0xFF12202C)),
            ),
          ),
          Positioned(left: 0, top: 300, width: 400, height: 200, child: changing),
          // **Over the changing content, and that is load-bearing.** Every row
          // in this file asks whether a change *under the glass* is seen, and
          // the oracle answers with a region: with the surface at the top of
          // the screen and the content 300 logical pixels below it, the host
          // would correctly hold a proxy the change could not reach, and three
          // rows would pass for the wrong reason.
          const Positioned(left: 0, top: 320, width: 320, height: 64, child: GlassSurface()),
        ],
      ),
    );
  }
}

/// Content that repaints without rebuilding, moving or declaring anything.
class _Pulse extends CustomPainter {
  _Pulse(this.tick) : super(repaint: tick);

  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Color.fromARGB(255, 40 + (tick.value * 37) % 200, 90, 160),
    );
  }

  @override
  bool shouldRepaint(_Pulse oldDelegate) => true;
}

/// Pushes a `ContainerLayer` subclass nothing knows about.
class _StrangeLayerBox extends SingleChildRenderObjectWidget {
  const _StrangeLayerBox({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStrangeLayerBox();
}

class _RenderStrangeLayerBox extends RenderProxyBox {
  // Without this the framework is free to paint the child straight onto the
  // canvas and no layer of ours reaches the tree at all.
  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushLayer(_StrangeLayer(), super.paint, offset);
  }
}

class _StrangeLayer extends ContainerLayer {}

/// Counts paints, and separates the frame's from the capture pass's.
///
/// The pass paints the whole subtree by construction every time it records, so
/// a single counter would answer "did the screen repaint" with "yes, we
/// repainted it ourselves".
class _PaintCounter extends SingleChildRenderObjectWidget {
  const _PaintCounter({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintCounter();
}

class _RenderPaintCounter extends RenderProxyBox {
  int framePaints = 0;
  int passPaints = 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (context is ProxyWalkContext) {
      passPaints++;
    } else {
      framePaints++;
    }
    super.paint(context, offset);
  }
}

// ---------------------------------------------------------------------------
// The arm that separates the observation from the pass that triggers it.
// ---------------------------------------------------------------------------

/// Two hosts, one inside the other, and the outer one has a surface of its own.
///
/// The surface is what makes the arm an arm: a host whose ledger is empty never
/// captures at all, so the first version of this scene proved nothing and
/// passed. The outer host records every frame, and every one of those captures
/// walks through the inner host — including the inner host's own observer.
class _NestedHosts extends StatelessWidget {
  const _NestedHosts({required this.innerKey});

  final Key innerKey;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: kScreen,
    child: Stack(
      children: <Widget>[
        const Positioned.fill(child: ColoredBox(color: Color(0xFF12202C))),
        const Positioned(left: 0, top: 0, width: 320, height: 64, child: GlassSurface()),
        Positioned(
          left: 0,
          top: 200,
          width: 400,
          height: 300,
          child: GlassHost(
            key: innerKey,
            hardware: GlassHardware.appleMetal,
            finish: GlassFinish.identity,
            child: const Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: Color(0xFF203040))),
                Positioned(left: 0, top: 120, width: 320, height: 64, child: GlassSurface()),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
