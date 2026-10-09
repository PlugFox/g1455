// Glass over its siblings: a bar over glass cards (GlassAbove).
//
// `flutter test test/glass_above_test.dart`
//
// Levels are counted by the tree, so a bar beside the cards it covers is one
// level with them, and the capture — which skips every glass subtree —
// shows the page with the cards cut out. A lifted bar is a level above them,
// and its walk draws them through their own frames.
//
// The arm is the identity once more: an identity bar lifted over a tinted card
// with a label must be invisible. Unlifted, the same bar shows the backdrop
// where the card is — the defect, kept as the arm that says the scene can
// tell the two apart.
//
// Breaks, each undone by swapping the string back:
//  - `level += node.lift;` -> `level += 0;` in `_Levels.of`: the lifted arm
//    fails as the unlifted one does;
//  - `if (lifted && top > 0)` -> `if (false)`: the card's label changed under
//    the bar is held over (the card's subtree is excluded from the watch, and
//    nothing else in the scene changes);
//  - `context.addLayer(kept);` -> `context.pushLayer(kept, (c, o) =>
//    c.paintChild(child, o), offset);` in `RenderGlassSurface._paintContent`
//    (repaint the content on every publish): the still-screen arm records on
//    every frame — the label's picture re-minted by each publish is a change
//    in the bar's capture, which publishes again;
//  - the occupancy ranking (`rank[...]`) -> identity: a lifted bar with no
//    glass under it records an empty base and a level of its own — two
//    snapshots a frame for nothing, which the plain arm counts.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 300);
final GlobalKey _shotKey = GlobalKey();

const GlassFinish _tinted = GlassFinish(
  name: 'identity',
  blurSigmaLogical: 0,
  tint: Color.fromRGBO(255, 40, 0, 0.5),
  rim: Color.fromRGBO(0, 0, 0, 0),
  optics: GlassOptics.none,
);

void main() {
  testWidgets('an identity bar lifted over a glass card shows the card and its label', (
    WidgetTester tester,
  ) async {
    final Uint8List without = await _shot(tester, const _Scene(bar: false));
    final Uint8List lifted = await _shot(tester, const _Scene(bar: true));
    final GlassProxyHandle handle = _handle(tester);
    final RenderGlassSurface bar = _surface(tester, 'bar');
    final RenderGlassSurface card = _surface(tester, 'card');
    final (:int differing, :int worst) = _diff(without, lifted);
    // ignore: avoid_print
    print(
      'lifted: differing $differing, worst $worst; upper ${handle.upper.length}, '
      'card drawn into the proxy ${card.paintsIntoProxy}',
    );
    expect(handle.upper, hasLength(1));
    expect(handle.upper.single!.keys, contains(bar));
    expect(handle.frame!.keys, contains(card));
    expect(card.paintsIntoProxy, greaterThan(0), reason: 'the card never drew into the capture');
    expect(bar.paintsWithProxy, greaterThan(0), reason: 'the bar never drew');
    expect(differing, 0, reason: 'the lifted bar shows something other than the card');

    bar
      ..debugSampleShift = const Offset(12, 0)
      ..markNeedsPaint();
    await tester.pump();
    final ({int differing, int worst}) shifted = _diff(without, await _pixels(tester));
    expect(shifted.differing, greaterThan(500), reason: 'a shifted bar changed nothing');
  });

  testWidgets('unlifted, the same bar cuts the card out — the defect', (WidgetTester tester) async {
    final Uint8List without = await _shot(tester, const _Scene(bar: false));
    final Uint8List flat = await _shot(tester, const _Scene(bar: true, lift: false));
    final (:int differing, :int worst) = _diff(without, flat);
    // ignore: avoid_print
    print('unlifted: differing $differing, worst $worst');
    expect(_handle(tester).upper, isEmpty);
    // The card's whole overlap with the bar, label included.
    expect(differing, greaterThan(2000));
  });

  testWidgets('a lifted bar over plain content is one level and one snapshot', (
    WidgetTester tester,
  ) async {
    // Over the host's whole life, against the same count on the screen with
    // the card: there a recorded frame is two snapshots, here it must be one.
    await _pump(tester, const _Scene(bar: true, card: false), frames: 5);
    final GlassProxyHandle plain = _handle(tester);
    final (int, int) plainCount = (plain.generation, plain.snapshots);
    final bool plainUpper = plain.upper.isEmpty;
    final bool barInBase = plain.frame!.keys.contains(_surface(tester, 'bar'));
    await _pump(tester, const _Scene(bar: true), frames: 5);
    final GlassProxyHandle stacked = _handle(tester);
    final (int, int) stackedCount = (stacked.generation, stacked.snapshots);
    // ignore: avoid_print
    print('plain: (records, snapshots) $plainCount; with the card $stackedCount');
    expect(plainUpper, isTrue);
    expect(barInBase, isTrue);
    expect(plainCount.$1, greaterThan(0), reason: 'nothing recorded, so nothing was counted');
    expect(plainCount.$2, plainCount.$1, reason: 'more than one snapshot per recorded frame');
    expect(stackedCount.$2, 2 * stackedCount.$1, reason: 'the control: a level is one more snapshot');
  });

  testWidgets('a still screen with a plain label under a lifted bar records nothing', (
    WidgetTester tester,
  ) async {
    // The label is a plain Text — not behind a boundary, unlike every other
    // arm's — so a publish that repainted the card's content re-minted it.
    final GlobalKey hostKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          child: const Stack(
            children: <Widget>[
              Positioned(left: 20, right: 20, top: 140, height: 200, child: GlassCard(child: Text('card'))),
              Positioned(
                left: 20,
                right: 20,
                top: 120,
                height: 60,
                child: GlassAbove(child: GlassBar(child: Text('bar'))),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dynamic host = hostKey.currentState;
    final int before = host.recorded as int;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('still: recorded ${(host.recorded as int) - before} over 30 frames, upper ${_handle(tester).upper.length}');
    expect(_handle(tester).upper, hasLength(1), reason: 'the arm is not glass on glass');
    expect((host.recorded as int) - before, 0, reason: 'a still screen kept recording');
  });

  testWidgets('a label changed inside the card under the lifted bar is seen', (
    WidgetTester tester,
  ) async {
    final colour = ValueNotifier<Color>(const Color(0xFF00C853));
    await _pump(tester, _Scene(bar: true, label: colour), frames: 6);
    final GlassProxyHandle handle = _handle(tester);
    final int before = handle.generation;
    colour.value = const Color(0xFF2962FF);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final Uint8List live = await _pixels(tester);
    final Uint8List fresh = await _shot(
      tester,
      _Scene(bar: true, label: ValueNotifier<Color>(const Color(0xFF2962FF))),
    );
    final (:int differing, :int worst) = _diff(live, fresh);
    // ignore: avoid_print
    print('label changed: generations ${handle.generation - before}, differing $differing');
    expect(handle.generation - before, greaterThan(0), reason: 'the change was held over');
    expect(differing, 0, reason: 'the bar still shows the old label');
    colour.dispose();
  });
}

class _Scene extends StatelessWidget {
  const _Scene({required this.bar, this.lift = true, this.card = true, this.label});

  final bool bar;
  final bool lift;
  final bool card;
  final ValueNotifier<Color>? label;

  @override
  Widget build(BuildContext context) {
    final Widget labelBox = RepaintBoundary(
      child: label == null
          ? const ColoredBox(color: Color(0xFF00C853))
          : ValueListenableBuilder<Color>(
              valueListenable: label!,
              builder: (BuildContext context, Color c, Widget? _) => ColoredBox(color: c),
            ),
    );
    const Widget barSurface = GlassSurface(
      key: ValueKey<String>('bar'),
      borderRadius: BorderRadius.all(Radius.circular(24)),
    );
    return RepaintBoundary(
      key: _shotKey,
      child: SizedBox.fromSize(
        size: kScreen,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
            ),
            if (card)
              Positioned(
                left: 20,
                top: 60,
                width: 360,
                height: 160,
                child: GlassSurface(
                  key: const ValueKey<String>('card'),
                  finish: _tinted,
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  child: Stack(
                    children: <Widget>[
                      Positioned(left: 60, top: 20, width: 60, height: 30, child: labelBox),
                    ],
                  ),
                ),
              ),
            // A sibling of the card, over its top edge and its label.
            if (bar)
              Positioned(
                left: 40,
                top: 30,
                width: 300,
                height: 60,
                child: lift ? const GlassAbove(child: barSurface) : barSurface,
              ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12202C));
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 4),
        Paint()..color = Color.fromARGB(255, 30 + (y.toInt() * 3 % 210), 120, 210 - (y.toInt() % 160)),
      );
    }
    for (var x = 0.0; x < size.width; x += 17) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, size.height), Paint()..color = const Color(0x66FFFFFF));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

RenderGlassSurface _surface(WidgetTester tester, String key) => tester.renderObject(find.byKey(ValueKey<String>(key)));

Future<void> _pump(WidgetTester tester, Widget child, {int frames = 4}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: UniqueKey(),
            hardware: GlassHardware.appleMetal,
            finish: GlassFinish.identity,
            child: child,
          ),
        ),
      ),
    ),
  );
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

Future<Uint8List> _shot(WidgetTester tester, Widget child) async {
  await _pump(tester, child, frames: 5);
  return _pixels(tester);
}

Future<Uint8List> _pixels(WidgetTester tester) async {
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

({int differing, int worst}) _diff(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  expect(a.length, greaterThan(1000));
  var differing = 0;
  var worst = 0;
  for (var i = 0; i < a.length; i += 4) {
    var d = 0;
    for (var c = 0; c < 4; c++) {
      final int e = (a[i + c] - b[i + c]).abs();
      if (e > d) {
        d = e;
      }
    }
    if (d > 0) {
      differing++;
      if (d > worst) {
        worst = d;
      }
    }
  }
  return (differing: differing, worst: worst);
}
