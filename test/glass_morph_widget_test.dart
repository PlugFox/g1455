// `GlassMorph`: one glass that flows to the size of the child it is given.
//
// `flutter test test/glass_morph_widget_test.dart`
//
// Not `glass_morph_test.dart`, which is about `presence` — the field offset a
// morph's bud is drawn with — and predates the widget.
//
// Most arms read geometry off the render tree: what the glass measured, where
// its body and buds are, whether a group exists. The pixel arms use the same
// tinted identity as the presence arms, at dpr 1, so the silhouette is the set
// of pixels that differ from the bare screen.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 400);
const Size kButton = Size(44, 44);
const Size kMenu = Size(240, 200);
const Duration kFrame = Duration(milliseconds: 16);
final GlobalKey _shotKey = GlobalKey();

/// One host for every pump that names none, so a pump updates the tree it
/// pumped before rather than mounting a new one.
final GlobalKey _host = GlobalKey();

void main() {
  testWidgets('the glass is the size of the child it measured, and flows to the next', (
    WidgetTester tester,
  ) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    await _pump(tester, _Toggle(open: open));
    expect(tester.getSize(find.byType(GlassMorph)), kButton);
    expect(_body(tester).size, kButton, reason: 'the glass is not the child\'s size');

    open.value = true;
    await tester.pump();
    // The frame of the swap measures the new child and draws the start.
    expect(tester.getSize(find.byType(GlassMorph)), kButton);
    final sizes = <Size>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(kFrame);
      sizes.add(tester.getSize(find.byType(GlassMorph)));
    }
    expect(sizes.first.width, greaterThan(kButton.width), reason: 'it did not start: $sizes');
    expect(sizes.first.width, lessThan(kMenu.width), reason: 'it did not flow: $sizes');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMorph)), kMenu);
    expect(_body(tester).size, kMenu);
  });

  testWidgets('alignment holds its corner: the top-right stays put, the bud grows from it', (
    WidgetTester tester,
  ) async {
    for (final Alignment alignment in <Alignment>[Alignment.topRight, Alignment.topLeft]) {
      final open = ValueNotifier<bool>(false);
      addTearDown(open.dispose);
      // The parent holds the top-right on screen; the morph's own alignment is
      // the variable.
      await _pump(
        tester,
        _Toggle(open: open, alignment: alignment, parent: Alignment.topRight),
        hostKey: GlobalKey(),
      );
      open.value = true;
      await tester.pump();
      var budsSeen = 0;
      final budRights = <double>[];
      for (var i = 0; i < 20; i++) {
        await tester.pump(kFrame);
        final Rect body = _body(tester).globalRect;
        expect(body.right, kScreen.width, reason: 'the parent stopped holding the right edge');
        expect(body.top, 0);
        for (final RenderGlassSurface bud in _buds(tester)) {
          budsSeen++;
          // Running ahead: never larger than the child, and larger than the
          // body until the spring overshoots.
          expect(bud.size.width, lessThanOrEqualTo(kMenu.width + 1e-6));
          if (body.width < kMenu.width) {
            expect(bud.size.width, greaterThanOrEqualTo(body.width - 1e-6));
          }
          budRights.add(bud.globalRect.right);
          expect(bud.globalRect.top, 0, reason: 'the bud left the held corner');
        }
      }
      expect(budsSeen, greaterThan(0), reason: 'no bud mid-morph');
      if (alignment == Alignment.topRight) {
        expect(budRights.every((double r) => r == kScreen.width), isTrue, reason: '$budRights');
      } else {
        // The control: aligned left in a box held right, the new shape hangs
        // off the screen's right edge — the mistake the dartdoc warns about —
        // by however far it runs ahead of the body.
        expect(budRights.first, greaterThan(kScreen.width + 4), reason: '$budRights');
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(GlassMorph)).topRight, Offset(kScreen.width, 0));
    }
  });

  testWidgets('width and height pin an axis and leave the other measured', (WidgetTester tester) async {
    BoxConstraints? seen;
    Widget probe() => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        seen = constraints;
        return const SizedBox(width: 120, height: 40);
      },
    );
    await _pump(tester, _Host(child: GlassMorph(width: 300, child: probe())));
    expect(tester.getSize(find.byType(GlassMorph)), const Size(300, 40));
    expect(seen!.minWidth, 300, reason: 'the child was not laid out at the pinned width');
    expect(seen!.maxWidth, 300);
    expect(seen!.minHeight, 0, reason: 'the free axis is not measured loosely');

    await _pump(tester, _Host(child: GlassMorph(height: 90, child: probe())));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMorph)), const Size(120, 90));
    expect(seen!.minHeight, 90);
    expect(seen!.maxHeight, 90);
    expect(seen!.minWidth, 0);

    // And a pin that changes on the same child morphs, with nothing to fade.
    await _pump(tester, _Host(child: GlassMorph(height: 160, child: probe())));
    expect(find.byType(GlassGroup), findsOneWidget, reason: 'a new pin did not morph');
    await tester.pump(kFrame);
    expect(tester.getSize(find.byType(GlassMorph)).height, inExclusiveRange(90, 160));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMorph)), const Size(120, 160));
  });

  testWidgets('identity is the key, as in AnimatedSwitcher; state survives the morph', (
    WidgetTester tester,
  ) async {
    // The same type and no key: updated in place — no morph, the new size at
    // once.
    await _pump(tester, const _Host(child: GlassMorph(child: SizedBox(width: 80, height: 40))));
    await _pump(tester, const _Host(child: GlassMorph(child: SizedBox(width: 160, height: 40))), frames: 1);
    expect(tester.hasRunningAnimations, isFalse, reason: 'an update in place morphed');
    expect(tester.getSize(find.byType(GlassMorph)), const Size(160, 40));

    // Another key: a morph.
    await _pump(
      tester,
      const _Host(
        child: GlassMorph(child: SizedBox(key: ValueKey<String>('other'), width: 200, height: 80)),
      ),
      frames: 1,
    );
    expect(tester.hasRunningAnimations, isTrue, reason: 'a new key did not morph');
    await tester.pump(kFrame);
    expect(find.byType(GlassGroup), findsOneWidget, reason: 'a growing morph drew no union');
    expect(tester.getSize(find.byType(GlassMorph)).width, inExclusiveRange(160, 200));
    await tester.pumpAndSettle();

    // State: the new child's State is the same object from the frame it
    // arrives, through the morph, to rest — the content never remounts.
    await _pump(
      tester,
      const _Host(
        child: GlassMorph(child: _Counter(key: ValueKey<int>(1))),
      ),
    );
    await _pump(
      tester,
      const _Host(
        child: GlassMorph(child: _Counter(key: ValueKey<int>(2), side: 120)),
      ),
      frames: 1,
    );
    final State<_Counter> arrived = tester.state(find.byKey(const ValueKey<int>(2)));
    await tester.pump(kFrame);
    expect(find.byType(GlassGroup), findsOneWidget);
    expect(tester.state(find.byKey(const ValueKey<int>(2))), same(arrived));
    await tester.pumpAndSettle();
    expect(find.byType(GlassGroup), findsNothing);
    expect(tester.state(find.byKey(const ValueKey<int>(2))), same(arrived), reason: 'remounted at rest');
    expect(find.byKey(const ValueKey<int>(1)), findsNothing, reason: 'the old child outlived the morph');

    // And a child swapped back while it is still fading out is revived, not
    // mounted again.
    await _pump(
      tester,
      const _Host(
        child: GlassMorph(child: _Counter(key: ValueKey<int>(1))),
      ),
      frames: 1,
    );
    final State<_Counter> leaving = tester.state(find.byKey(const ValueKey<int>(2)));
    await tester.pump(kFrame);
    await _pump(
      tester,
      const _Host(
        child: GlassMorph(child: _Counter(key: ValueKey<int>(2), side: 120)),
      ),
      frames: 1,
    );
    expect(tester.state(find.byKey(const ValueKey<int>(2))), same(leaving));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMorph)), const Size(120, 120));
  });

  testWidgets('content cross-fades: the old out over the first half, the new in over the second', (
    WidgetTester tester,
  ) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    await _pump(tester, _Toggle(open: open, motion: GlassMorphMotion.calm));
    open.value = true;
    await tester.pump();
    final olds = <double>[];
    final news = <double>[];
    while (find.byKey(const ValueKey<String>('button')).evaluate().isNotEmpty) {
      olds.add(_opacityOf(tester, const ValueKey<String>('button')));
      news.add(_opacityOf(tester, const ValueKey<String>('menu')));
      await tester.pump(kFrame);
    }
    expect(news.first, 0, reason: 'the new content was visible on the frame of the swap');
    expect(olds.first, 1);
    // Monotonic both ways: a cross-fade, not a flicker.
    for (var i = 1; i < olds.length; i++) {
      expect(olds[i], lessThanOrEqualTo(olds[i - 1]), reason: '$olds');
      expect(news[i], greaterThanOrEqualTo(news[i - 1]), reason: '$news');
    }
    // Never both at full strength, and the halves do not overlap: where the
    // old one is still there, the new one has not started.
    for (var i = 0; i < olds.length; i++) {
      expect(olds[i] > 0 && news[i] > 0, isFalse, reason: 'frame $i: ${olds[i]} / ${news[i]}');
    }
    expect(olds.where((double o) => o > 0 && o < 1), isNotEmpty, reason: 'the old content did not fade');
    expect(news.where((double o) => o > 0 && o < 1), isNotEmpty, reason: 'the new content did not fade');
    expect(find.byKey(const ValueKey<String>('button')), findsNothing);
    expect(_opacityOf(tester, const ValueKey<String>('menu')), 1);
  });

  testWidgets('a swap mid-morph starts from where the glass is', (WidgetTester tester) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    await _pump(tester, _Toggle(open: open));
    open.value = true;
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(kFrame);
    }
    final Size before = tester.getSize(find.byType(GlassMorph));
    final State<StatefulWidget> menu = tester.state(find.byType(GlassMorph));
    open.value = false;
    await tester.pump();
    expect(tester.getSize(find.byType(GlassMorph)), before, reason: 'the swap jumped');
    await tester.pump(kFrame);
    final Size next = tester.getSize(find.byType(GlassMorph));
    expect((next.width - before.width).abs(), lessThan(20), reason: '$before -> $next');
    expect(next.width, lessThan(before.width), reason: 'it did not turn back');
    expect(tester.state(find.byType(GlassMorph)), same(menu));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GlassMorph)), kButton);
    expect(find.byKey(const ValueKey<String>('menu')), findsNothing);
  });

  testWidgets('reduced motion: no neck and no motion — the new child arrives on its frame', (
    WidgetTester tester,
  ) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    var ended = 0;
    await _pump(tester, _Toggle(open: open, onEnd: () => ended++), reduceMotion: true);
    final RenderGlassSurface before = _body(tester);
    open.value = true;
    await tester.pump();
    expect(find.byType(GlassGroup), findsNothing, reason: 'a union under reduced motion');
    expect(find.byKey(const ValueKey<String>('button')), findsNothing, reason: 'the old child lingered');
    expect(tester.getSize(find.byType(GlassMorph)), kMenu, reason: 'the size moved under reduced motion');
    expect(_body(tester), same(before));
    expect(tester.hasRunningAnimations, isFalse);
    expect(ended, 0, reason: 'nothing was animated, so nothing ended');
  });

  testWidgets('at rest it is a lone surface: the union exists only while the glass moves', (
    WidgetTester tester,
  ) async {
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    var ended = 0;
    await _pump(tester, _Toggle(open: open, onEnd: () => ended++));
    void expectAtRest(String when) {
      expect(find.byType(GlassGroup), findsNothing, reason: '$when: a group at rest');
      expect(find.byType(GlassSurface), findsOneWidget, reason: '$when: more than one surface at rest');
      expect(_body(tester).fusedByGroup, isFalse, reason: when);
    }

    expectAtRest('before');
    final RenderGlassSurface body = _body(tester);
    final int blank = body.paintsWithoutProxy;
    open.value = true;
    await tester.pump();
    await tester.pump(kFrame);
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    expect(group.group.surfaces, hasLength(2), reason: 'mid-morph is the body and one bud');
    expect(group.group.surfaces, contains(same(body)), reason: 'the body was remounted into the group');
    await tester.pumpAndSettle();
    expectAtRest('after');
    expect(ended, 1);
    // One render object throughout, so it never had a frame without a slot:
    // a body remounted at the start or the end would blink out for one.
    expect(_body(tester), same(body));
    expect(body.paintsWithoutProxy, blank, reason: 'the body blinked out across the morph');

    // Spacing zero: no union even mid-morph.
    open.value = false;
    await tester.pumpAndSettle();
    await _pump(tester, _Toggle(open: open, spacing: 0));
    open.value = true;
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(kFrame);
      expect(find.byType(GlassGroup), findsNothing, reason: 'spacing zero folded a union');
    }
    await tester.pumpAndSettle();
  });

  testWidgets('mid-morph the glass leads the body; at rest it is exactly a plain surface', (
    WidgetTester tester,
  ) async {
    final Uint8List bare = await _grab(tester, const _Scene(), frames: 4);
    final open = ValueNotifier<bool>(false);
    addTearDown(open.dispose);
    await _pump(tester, _Scene(open: open), finish: _tinted);
    open.value = true;
    await tester.pump();
    var led = 0;
    var bridged = 0;
    for (var i = 0; i < 10; i++) {
      await tester.pump(kFrame);
      final Set<int> glass = _differing(await _image(tester), bare);
      // The held corner holds to the pixel: the bud never swells the edges it
      // shares with the body, because it stays `k` inside them.
      expect(
        glass.where((int p) => _at(p).dy < 40 || _at(p).dx > 360),
        isEmpty,
        reason: 'frame $i: glass past the held corner',
      );
      final Rect body = _body(tester).globalRect;
      final List<RenderGlassSurface> buds = _buds(tester);
      if (buds.isEmpty) {
        continue;
      }
      // Past the body: the destination arriving ahead of the size.
      // A pixel of slack on every side: mid-spring the body's edges are
      // fractional, and its own antialiased edge is not the bud.
      final Rect within = body.inflate(1);
      final int ahead = glass.where((int p) => !within.contains(_at(p))).length;
      led = ahead > led ? ahead : led;
      // The neck: glass outside the body that the bud alone, eroded by its
      // presence, cannot account for — the union's bridge between the two.
      final RenderGlassSurface bud = buds.last;
      final Rect eroded = bud.globalRect.deflate(bud.presenceInset(blend: 2 * kGlassMorphSpacing));
      // Inside the bud's own box, so the swell a fold puts where two edges
      // coincide — above and beside the body — is not counted as a neck.
      final Rect own = bud.globalRect.deflate(1);
      final int bridge = glass
          .where((int p) => own.contains(_at(p)) && !within.contains(_at(p)) && !eroded.inflate(1).contains(_at(p)))
          .length;
      bridged = bridge > bridged ? bridge : bridged;
    }
    debugPrint('glass past the body: $led px at most; neck: $bridged px at most');
    expect(led, greaterThan(500), reason: 'the glass never reached past the body');
    expect(bridged, greaterThan(50), reason: 'no bridge between the body and the bud');

    await tester.pumpAndSettle();
    await tester.pump();
    final Uint8List settled = await _image(tester);
    // On a host of its own: a surface swapped for another at the same rect
    // is not a change the host's oracle sees, so on the same host the plain
    // surface would wait for a capture that is held.
    await _pump(tester, const _Scene(plain: true), hostKey: GlobalKey());
    final Uint8List plain = await _image(tester);
    expect(_differing(plain, bare), isNotEmpty, reason: 'the plain surface drew nothing');
    expect(_differing(settled, plain), isEmpty, reason: 'a settled morph is not a plain surface');
  });

  testWidgets('the honest price: a capture per frame — unless a fixed region holds it', (
    WidgetTester tester,
  ) async {
    final retakes = <bool, int>{};
    for (final bool travel in <bool>[false, true]) {
      final open = ValueNotifier<bool>(false);
      addTearDown(open.dispose);
      final hostKey = GlobalKey();
      await _pump(
        tester,
        _Scene(open: open, travel: travel),
        finish: _tinted,
        hostKey: hostKey,
      );
      final dynamic host = hostKey.currentState! as dynamic;
      open.value = true;
      // The union forming is a few captures of its own, region or not: the
      // swap, the bud joining the register, and the layer watch settling on
      // the group that now holds the body — five frames, measured.
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(kFrame);
      }
      final int before = host.recorded as int;
      for (var i = 0; i < 10; i++) {
        await tester.pump(kFrame);
      }
      retakes[travel] = (host.recorded as int) - before;
      expect(find.byType(GlassGroup), findsOneWidget, reason: 'the morph ended inside the arm');
      await tester.pumpAndSettle();
    }
    expect(retakes[false], 10, reason: 'a resizing glass was held: $retakes');
    expect(retakes[true], 0, reason: 'inside a fixed region it was retaken: $retakes');
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

RenderGlassSurface _body(WidgetTester tester) {
  // The body is the surface that holds content; buds are childless.
  final Iterable<RenderGlassSurface> all = tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface));
  return all.firstWhere((RenderGlassSurface s) => s.child != null);
}

List<RenderGlassSurface> _buds(WidgetTester tester) => tester
    .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
    .where((RenderGlassSurface s) => s.child == null)
    .toList();

double _opacityOf(WidgetTester tester, Key key) {
  final Finder opacity = find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first;
  return tester.widget<Opacity>(opacity).opacity;
}

Offset _at(int pixel) => Offset((pixel % kScreen.width.toInt()) + 0.5, (pixel ~/ kScreen.width.toInt()) + 0.5);

class _Host extends StatelessWidget {
  const _Host({required this.child, this.alignment = Alignment.topLeft});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: kScreen,
    child: Align(alignment: alignment, child: child),
  );
}

/// A button that becomes a menu.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.open,
    this.alignment = Alignment.topLeft,
    this.parent = Alignment.topLeft,
    this.motion = GlassMorphMotion.fluid,
    this.spacing = kGlassMorphSpacing,
    this.onEnd,
  });

  final ValueNotifier<bool> open;
  final Alignment alignment;
  final Alignment parent;
  final GlassMorphMotion motion;
  final double spacing;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) => _Host(
    alignment: parent,
    child: ValueListenableBuilder<bool>(
      valueListenable: open,
      builder: (BuildContext context, bool isOpen, Widget? _) => GlassMorph(
        alignment: alignment,
        motion: motion,
        spacing: spacing,
        onEnd: onEnd,
        borderRadius: isOpen ? const BorderRadius.all(Radius.circular(24)) : kGlassCapsule,
        child: isOpen
            ? SizedBox.fromSize(key: const ValueKey<String>('menu'), size: kMenu)
            : SizedBox.fromSize(key: const ValueKey<String>('button'), size: kButton),
      ),
    ),
  );
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, this.side = 40});

  final double side;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: widget.side);
}

/// The pixel scene: a checkerboard behind its own boundary, and the morph —
/// or, for [plain], the surface it should rest as — in the top-right corner.
class _Scene extends StatelessWidget {
  const _Scene({this.open, this.plain = false, this.travel = false});

  final ValueNotifier<bool>? open;
  final bool plain;
  final bool travel;

  @override
  Widget build(BuildContext context) {
    Widget glass;
    if (plain) {
      glass = const GlassSurface(child: SizedBox(width: 240, height: 200));
    } else if (open == null) {
      glass = const SizedBox.shrink();
    } else {
      glass = ValueListenableBuilder<bool>(
        valueListenable: open!,
        builder: (BuildContext context, bool isOpen, Widget? _) => GlassMorph(
          alignment: Alignment.topRight,
          motion: GlassMorphMotion.calm,
          borderRadius: isOpen ? const BorderRadius.all(Radius.circular(24)) : kGlassCapsule,
          child: isOpen
              ? SizedBox.fromSize(key: const ValueKey<String>('menu'), size: kMenu)
              : SizedBox.fromSize(key: const ValueKey<String>('button'), size: kButton),
        ),
      );
    }
    // A slot of fixed size that holds every size the morph takes, bud and
    // overshoot included: the region `GlassTravel` needs to be still.
    Widget slot = SizedBox(
      width: 300,
      height: 280,
      child: Align(alignment: Alignment.topRight, child: glass),
    );
    if (travel) {
      slot = GlassTravel(child: slot);
    }
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _Checks())),
            ),
            Positioned(top: 40, right: 40, child: slot),
          ],
        ),
      ),
    );
  }
}

class _Checks extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A3A4A));
    final Paint light = Paint()..color = const Color(0xFFB0C4D8);
    for (var y = 0.0; y < size.height; y += 16) {
      for (var x = ((y ~/ 16).isEven ? 0.0 : 16.0); x < size.width; x += 32) {
        canvas.drawRect(Rect.fromLTWH(x, y, 16, 16), light);
      }
    }
  }

  @override
  bool shouldRepaint(_Checks oldDelegate) => false;
}

const GlassFinish _tinted = GlassFinish(
  name: 'identity',
  blurSigmaLogical: 0,
  tint: Color.fromRGBO(255, 40, 0, 0.5),
  rim: Color.fromRGBO(0, 0, 0, 0),
  optics: GlassOptics.none,
);

Widget _mount(Widget child, {Key? hostKey, GlassFinish? finish, bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(size: kScreen, devicePixelRatio: 1, disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        finish: finish ?? _tinted,
        child: child,
      ),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Key? hostKey,
  GlassFinish? finish,
  bool reduceMotion = false,
  int frames = 4,
}) async {
  await tester.pumpWidget(_mount(child, hostKey: hostKey ?? _host, finish: finish, reduceMotion: reduceMotion));
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Set<int> _differing(Uint8List now, Uint8List bare) {
  expect(now.length, kScreen.width * kScreen.height * 4, reason: 'a partial frame');
  final out = <int>{};
  for (var i = 0; i < now.length; i += 4) {
    if (now[i] != bare[i] || now[i + 1] != bare[i + 1] || now[i + 2] != bare[i + 2]) {
      out.add(i ~/ 4);
    }
  }
  return out;
}

Future<Uint8List> _grab(WidgetTester tester, Widget scene, {int frames = 4}) async {
  await _pump(tester, scene, frames: frames);
  return _image(tester);
}

Future<Uint8List> _image(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final ui.Image image = (boundary.layer! as OffsetLayer).toImageSync(Offset.zero & kScreen);
  late Uint8List out;
  await tester.runAsync(() async {
    out = Uint8List.fromList((await image.toByteData())!.buffer.asUint8List());
  });
  image.dispose();
  return out;
}
