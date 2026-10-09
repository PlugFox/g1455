// Glass appearing and leaving inside a blend group: `presence`, and why it is
// a field offset rather than a size.
//
// `flutter test test/glass_morph_test.dart`
//
// Every arm is a tinted identity at dpr 1: no refraction and no blur, so the
// backdrop reads straight through, and a tint so that *where* the glass is
// shows even though what it shows is right. The silhouette is then the set of
// pixels that differ from the bare screen, and each arm is a statement about
// that set.
//
// The pair: a bar-like panel A and a droplet B coming out of its end — B
// overlaps A by 10 px, its centre 12 px past A's edge — fused at spacing 16
// (k = 32). That is where growing a box from zero pops: a point 12 px from A
// is already a shape to `smin`, and it pulls a bud 3 px deep out of A at once.
// At 30 px (B beside A rather than out of it) the same point pulls 0.03 px and
// the pop is 30 pixels — measured, and the reason the arm sits here: the
// pop is a property of drops that emerge, not of every appearance.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 400);
const Rect kA = Rect.fromLTWH(60, 160, 160, 80);
const Offset kBCentre = Offset(232, 200);
const double kBSide = 44;
const double kSpacing = 16;
final GlobalKey _shotKey = GlobalKey();

void main() {
  testWidgets('at presence zero a member changes no pixel', (WidgetTester tester) async {
    final Set<int> bare = await _silhouette(tester, const _Scene(a: false, b: false));
    final Set<int> aOnly = await _silhouette(tester, const _Scene(b: false, a: true));
    final Set<int> absent = await _silhouette(tester, const _Scene(presence: 0));
    final Set<int> present = await _silhouette(tester, const _Scene());
    expect(bare, isEmpty, reason: 'the bare screen differs from itself');
    expect(aOnly, isNotEmpty, reason: 'the tint shows nothing, so no arm below can see a shape');
    expect(absent.length, aOnly.length, reason: 'a member at presence zero moved the silhouette');
    expect(absent.difference(aOnly), isEmpty);
    // And the member is really there when present, with a bridge: more than its
    // own box was added.
    expect(present.length - aOnly.length, greaterThan(kBSide * kBSide * 0.5));
  });

  testWidgets('growing a box from zero pops; presence grows a bud out of the neighbour', (
    WidgetTester tester,
  ) async {
    final Set<int> aOnly = await _silhouette(tester, const _Scene(b: false, a: true));

    // The control: B as a box a pixel wide at its own centre. To `smin` that is
    // already a shape 30 px from A's edge, inside k, so A grows a bud towards it
    // on the frame it appears — the pop the field offset removes.
    final Set<int> point = await _silhouette(tester, const _Scene(side: 1));
    final int pop = point.difference(aOnly).length;
    expect(pop, greaterThan(60), reason: 'a size-zero member did not pop, so the control is void');

    var previous = aOnly;
    final areas = <int>[];
    int? firstGrowth;
    for (var step = 1; step <= 20; step++) {
      final double p = step / 20;
      final Set<int> now = await _silhouette(tester, _Scene(presence: p));
      final Set<int> added = now.difference(previous);
      final Set<int> lost = previous.difference(now);
      expect(lost, isEmpty, reason: 'at presence $p the silhouette shrank somewhere');
      areas.add(now.length - aOnly.length);
      if (firstGrowth == null && added.isNotEmpty) {
        firstGrowth = step;
        // The bud is attached to A and grows out of its end: every new pixel is
        // past A's edge and inside B's box, and the first column is A's edge.
        final List<int> xs = <int>[for (final int i in added) i % kScreen.width.toInt()];
        expect(
          xs.reduce((int a, int b) => a < b ? a : b),
          inInclusiveRange(kA.right - 1, kA.right + 1),
        );
        expect(xs.reduce((int a, int b) => a > b ? a : b), lessThan(kBCentre.dx + kBSide / 2));
      }
      previous = now;
    }
    expect(firstGrowth, isNotNull, reason: 'presence one added nothing');
    debugPrint('added area by presence step: $areas; pop of a size-zero box: $pop');
    // Continuity is the claim, and it is stated against the control: the
    // first frame on which the member shows at all adds a small fraction of
    // what a box of one pixel adds at once, however slow its animation.
    expect(areas[firstGrowth! - 1], lessThan(pop / 4), reason: 'presence steps: $areas, pop $pop');
    // And the member is not idle for most of its animation: the offset starts
    // at the bound that makes presence zero exact, which is far past where the
    // member first reaches its neighbour.
    expect(firstGrowth, lessThanOrEqualTo(8), reason: 'nothing shows until step $firstGrowth');
  });

  testWidgets('a lone surface erodes to nothing and back', (WidgetTester tester) async {
    final areas = <double, int>{};
    for (final double p in <double>[0, 0.5, 0.8, 1]) {
      areas[p] = (await _silhouette(tester, _Scene(a: false, presence: p, grouped: false))).length;
    }
    expect(areas[0], 0, reason: 'a lone surface at presence zero is visible: $areas');
    expect(areas[1], greaterThan(kBSide * kBSide * 0.8), reason: '$areas');
    expect(areas[0.5]!, lessThan(areas[0.8]!), reason: '$areas');
    expect(areas[0.8]!, lessThan(areas[1]!), reason: '$areas');
  });

  testWidgets('presence is a paint, not a capture — past the frame it appears', (
    WidgetTester tester,
  ) async {
    // A member at presence zero draws nothing and is not captured at all, so a
    // drop that exists only while a control is held costs the atlas nothing at
    // rest. The price is one capture on the frame it appears — at a presence
    // the quadratic offset keeps invisible, so the frame it misses shows
    // nothing it should have — and none after it.
    final hostKey = GlobalKey();
    final presence = ValueNotifier<double>(0);
    addTearDown(presence.dispose);
    await _pump(tester, _Scene(animated: presence), hostKey: hostKey);
    final dynamic host = hostKey.currentState! as dynamic;
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    expect(handle.frame!.keys, hasLength(1), reason: 'a member at presence zero was captured');
    final int before = host.recorded as int;
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    final int records = group.drawRecords;
    for (var step = 1; step <= 5; step++) {
      presence.value = step / 5;
      await tester.pump();
    }
    expect(handle.frame!.keys, hasLength(2));
    expect((host.recorded as int) - before, 1, reason: 'animating presence retook the proxy');
    expect(group.drawRecords - records, greaterThanOrEqualTo(5), reason: 'the group never redrew');
  });
}

// ---------------------------------------------------------------------------
// Harness.
// ---------------------------------------------------------------------------

class _Scene extends StatelessWidget {
  const _Scene({
    this.a = true,
    this.b = true,
    this.presence = 1,
    this.side = kBSide,
    this.animated,
    this.grouped = true,
  });

  final bool grouped;
  final bool a;
  final bool b;
  final double presence;
  final double side;
  final ValueNotifier<double>? animated;

  Widget _group(Widget child) => grouped ? GlassGroup(spacing: kSpacing, child: child) : child;

  @override
  Widget build(BuildContext context) {
    Widget droplet(double p) => GlassSurface(borderRadius: kGlassCapsule, presence: p);
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _Checks())),
            ),
            if (a || b)
              Positioned.fill(
                child: _group(
                  Stack(
                    children: <Widget>[
                      if (a)
                        Positioned.fromRect(
                          rect: kA,
                          child: const GlassSurface(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                        ),
                      if (b)
                        Positioned.fromRect(
                          rect: Rect.fromCenter(center: kBCentre, width: side, height: side),
                          child: animated == null
                              ? droplet(presence)
                              : ValueListenableBuilder<double>(
                                  valueListenable: animated!,
                                  builder: (BuildContext context, double p, Widget? _) => droplet(p),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
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

Widget _mount(Widget child, {Key? hostKey}) => MediaQuery(
  data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: GlassHost(
        key: hostKey,
        hardware: GlassHardware.appleMetal,
        finish: _tinted,
        child: child,
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget child, {Key? hostKey, int frames = 4}) async {
  await tester.pumpWidget(_mount(child, hostKey: hostKey ?? GlobalKey()));
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Uint8List? _bareCache;

/// The pixels that differ from the bare screen: where the glass is.
Future<Set<int>> _silhouette(WidgetTester tester, Widget scene) async {
  final Uint8List bare = _bareCache ??= await _grab(tester, const _Scene(a: false, b: false));
  final Uint8List now = await _grab(tester, scene);
  expect(now.length, kScreen.width * kScreen.height * 4, reason: 'a partial frame');
  final out = <int>{};
  for (var i = 0; i < now.length; i += 4) {
    if (now[i] != bare[i] || now[i + 1] != bare[i + 1] || now[i + 2] != bare[i + 2]) {
      out.add(i ~/ 4);
    }
  }
  return out;
}

Future<Uint8List> _grab(WidgetTester tester, Widget scene) async {
  await _pump(tester, scene);
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
