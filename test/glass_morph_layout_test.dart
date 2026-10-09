// GlassMorph as a box among boxes: intrinsics, dry layout and hit testing, at
// rest and mid-morph, and the cap on the buds a burst of changes leaves.
//
// `flutter test test/glass_morph_layout_test.dart`
//
// `glass_morph_widget_test.dart` is about what the morph draws. This file is
// about what its parent sees, which is a different contract: an `IntrinsicWidth`
// or a dry-layout pass (a `Wrap`, a menu measuring itself) asks the morph for a
// size without laying it out, and an answer that ignores the pin or the current
// child is a layout that jumps on the next real pass. Each arm compares the
// answer with the size the same morph then actually takes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 400);
const Duration kFrame = Duration(milliseconds: 16);

void main() {
  testWidgets('intrinsics follow the child, and a pinned axis answers with the pin', (WidgetTester tester) async {
    await _pump(tester, const GlassMorph(child: SizedBox(width: 80, height: 40)));
    RenderBox morph = _morph(tester);
    expect(morph.getMinIntrinsicWidth(double.infinity), 80);
    expect(morph.getMaxIntrinsicWidth(double.infinity), 80);
    expect(morph.getMinIntrinsicHeight(double.infinity), 40);
    expect(morph.getMaxIntrinsicHeight(double.infinity), 40);

    await _pump(tester, const GlassMorph(width: 150, height: 60, child: SizedBox(width: 80, height: 40)));
    await tester.pumpAndSettle();
    morph = _morph(tester);
    expect(morph.getMinIntrinsicWidth(double.infinity), 150);
    expect(morph.getMaxIntrinsicWidth(double.infinity), 150);
    expect(morph.getMinIntrinsicHeight(double.infinity), 60);
    expect(morph.getMaxIntrinsicHeight(double.infinity), 60);
    expect(morph.size, const Size(150, 60), reason: 'the intrinsic answer is not the size the morph takes');

    // And an `IntrinsicWidth` parent, which is how a caller meets the answer.
    await _pump(
      tester,
      const IntrinsicWidth(child: GlassMorph(child: SizedBox(width: 90, height: 30))),
    );
    expect(tester.getSize(find.byType(GlassMorph)), const Size(90, 30));
  });

  testWidgets('dry layout agrees with layout, at rest and mid-morph', (WidgetTester tester) async {
    const loose = BoxConstraints(maxWidth: 400, maxHeight: 400);
    await _pump(tester, const GlassMorph(child: SizedBox(key: ValueKey<int>(1), width: 80, height: 40)));
    expect(_morph(tester).getDryLayout(loose), const Size(80, 40));
    expect(_morph(tester).getDryLayout(const BoxConstraints(maxWidth: 50, maxHeight: 400)), const Size(50, 40));

    // A child of another identity starts a morph; part way through, the dry
    // answer is the size being drawn, not the destination.
    await _pump(tester, const GlassMorph(child: SizedBox(key: ValueKey<int>(2), width: 200, height: 120)), frames: 1);
    await tester.pump(kFrame);
    await tester.pump(kFrame);
    final Size mid = _morph(tester).size;
    expect(mid.width, inExclusiveRange(80, 200), reason: 'the arm has to run while the morph is in flight');
    expect(_morph(tester).getDryLayout(loose), mid);
    for (final RenderBox box in _all(tester)) {
      if (box.hasSize && box.constraints == loose) {
        expect(box.getDryLayout(loose), box.size, reason: '${box.runtimeType}');
      }
    }
    await tester.pumpAndSettle();
    expect(_morph(tester).getDryLayout(loose), const Size(200, 120));
  });

  testWidgets('hits land inside the glass and not beside it, at rest and mid-morph', (WidgetTester tester) async {
    var taps = 0;
    Widget button(int key, double width) => GlassMorph(
      child: GestureDetector(
        key: ValueKey<int>(key),
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: SizedBox(width: width, height: 40),
      ),
    );
    await _pump(tester, button(1, 100));
    await tester.tapAt(const Offset(50, 20));
    expect(taps, 1);
    await tester.tapAt(const Offset(150, 20));
    expect(taps, 1, reason: 'a tap beside the glass reached its child');

    await _pump(tester, button(2, 300), frames: 1);
    await tester.pump(kFrame);
    await tester.pump(kFrame);
    final double width = _morph(tester).size.width;
    expect(width, inExclusiveRange(100, 300));
    // Inside the body as it is drawn now: the incoming child takes it.
    await tester.tapAt(Offset(width / 2, 20));
    // Past the body's edge, where only the finished child will reach.
    await tester.tapAt(Offset(width + 20, 20));
    await tester.pumpAndSettle();
    expect(taps, 2, reason: 'mid-morph, a tap inside should land once and one outside not at all');
  });

  testWidgets('a burst of changes leaves no more buds than one fused draw can fold', (WidgetTester tester) async {
    var most = 0;
    for (var i = 0; i < kMaxFusedShapes + 6; i++) {
      await _pump(
        tester,
        GlassMorph(
          child: SizedBox(key: ValueKey<int>(i), width: 60.0 + 10 * i, height: 40),
        ),
        frames: 1,
      );
      await tester.pump(const Duration(milliseconds: 4));
      final int surfaces = find.byType(GlassSurface).evaluate().length;
      if (surfaces > most) {
        most = surfaces;
      }
    }
    expect(most, kMaxFusedShapes, reason: 'the burst never reached the cap, so the cap was never tested');
    final RenderGlassGroup group = tester.renderObject(find.byType(GlassGroup));
    expect(group.refusedPaints, 0, reason: 'an over-capacity group refused to fuse');
    await tester.pumpAndSettle();
    expect(find.byType(GlassGroup), findsNothing, reason: 'the morph never settled');
  });
}

RenderBox _morph(WidgetTester tester) => tester.renderObject<RenderBox>(find.byType(GlassMorph));

Iterable<RenderBox> _all(WidgetTester tester) => tester
    .renderObjectList<RenderObject>(find.descendant(of: find.byType(GlassMorph), matching: find.byType(Widget)))
    .whereType<RenderBox>();

Future<void> _pump(WidgetTester tester, Widget morph, {int frames = 4}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: _host,
            hardware: GlassHardware.appleMetal,
            child: SizedBox.fromSize(
              size: kScreen,
              child: Align(alignment: Alignment.topLeft, child: morph),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 1; i < frames; i++) {
    await tester.pump();
  }
}

final GlobalKey _host = GlobalKey();
