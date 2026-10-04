// The segmented control: a selection that lifts into a clear drop over a track
// that is not glass (spike 32), and what that costs the capture.
//
// `flutter test test/glass_segmented_control_test.dart`
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassSegmentedControlState._onUp`, `: _pressed;` ->
//    `: _at.value.round();`: a quick tap lands where the drop has got to, not
//    on the segment pressed, and the tap arm selects the wrong one;
//  - in `_dropStage`, `GlassTravel(` -> `KeyedSubtree(`: the drop's capture
//    follows it, and the slide arm retakes on every frame of the slide;
//  - in `_DropLayout._rect`, `return inside.isEmpty ? drop : inside;` ->
//    `return drop;`: the drop stretched setting off from the first segment
//    stands out of its region, and the fling arm says so.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_pipeline.dart' show GlassProxyFrame;

const Size kScreen = Size(400, 300);

/// The control's box: 360 wide, as spike 32's was.
const Rect kControl = Rect.fromLTWH(20, 128, 360, 44);

/// Segment [i]'s centre on the screen: 2 in from the ends, four segments.
Offset _segment(double i) => Offset(kControl.left + 2 + (360 - 4) / 4 * (i + 0.5), kControl.center.dy);

void main() {
  testWidgets('at rest nothing reads the backdrop', (WidgetTester tester) async {
    await _mount(tester);
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame?.keys ?? const <Object>[], isEmpty, reason: 'a resting drop was captured');
    expect(_drop(tester).materialize, 0);
  });

  testWidgets('held, the drop is one level of glass; slid across every segment, nothing is retaken', (
    WidgetTester tester,
  ) async {
    final GlobalKey hostKey = GlobalKey();
    final selected = <int>[];
    await _mount(tester, hostKey: hostKey, onSelected: selected.add);
    final dynamic host = hostKey.currentState! as dynamic;
    final TestGesture gesture = await tester.startGesture(_segment(0));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final RenderGlassSurface drop = _drop(tester);
    expect(drop.materialize, 1, reason: 'the drop never lifted');
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame!.keys, <Object>[drop]);
    expect(handle.upper.whereType<GlassProxyFrame>(), isEmpty, reason: 'a drop over a plain track was stacked');
    // Spike 32: 86 x 28 at rest on a pitch of 89, 110 x 44 held.
    expect(drop.size.width, closeTo((360 - 4) / 4 - 3 + 2 * kGlassSegmentDropGrow.width, 0.05));
    expect(drop.size.height, closeTo(28 + 2 * kGlassSegmentDropGrow.height, 0.05));

    // Across all four: the labels under the drop do not change and the
    // capsule is gone, so nothing under the glass changes at all.
    final int lifted = host.recorded as int;
    var moved = 0;
    Rect where = drop.globalRect;
    for (var i = 1; i <= 30; i++) {
      await gesture.moveTo(Offset.lerp(_segment(0), _segment(3), i / 30)!);
      await tester.pump(const Duration(milliseconds: 16));
      if (drop.globalRect != where) {
        moved++;
        where = drop.globalRect;
      }
    }
    // ignore: avoid_print
    print('slide: moved $moved of 30 frames, recorded ${(host.recorded as int) - lifted}');
    expect(moved, greaterThan(25), reason: 'the drop did not follow the finger');
    expect((host.recorded as int) - lifted, 0, reason: 'sliding the drop retook the proxy');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, <int>[3]);
    expect(_drop(tester).materialize, 0, reason: 'the drop did not settle');
  });

  testWidgets('a tap on another segment selects it; the semantics say which is selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final selected = <int>[];
    await _mount(tester, onSelected: selected.add);
    await tester.tapAt(_segment(2));
    await tester.pumpAndSettle();
    expect(selected, <int>[2]);
    expect(tester.getSemantics(find.text('Month')).flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.getSemantics(find.text('Day')).flagsCollection.isSelected, Tristate.isFalse);
    tester.semantics.tap(find.semantics.byLabel('Year'));
    await tester.pumpAndSettle();
    expect(selected, <int>[2, 3]);
    semantics.dispose();
  });

  testWidgets('flung off the first segment, the drop deforms and never leaves its region', (
    WidgetTester tester,
  ) async {
    // Held on the first segment, thrown to the last and back. Across, the
    // region has no room to spare at its ends, so a drop that wobbles long
    // against one is pressed flat there instead — which the defaults barely
    // reach, and a strong spec does.
    const strong = GlassDropMotion(maxStretch: 0.4, saturation: 2000);
    final sizes = <GlassDropMotion?, List<Size>>{};
    for (final GlassDropMotion? motion in <GlassDropMotion?>[null, GlassDropMotion.none, strong]) {
      await _mount(tester, dropMotion: motion);
      final TestGesture gesture = await tester.startGesture(_segment(0));
      final RenderGlassSurface drop = _drop(tester);
      final List<Size> drawn = sizes[motion] = <Size>[];
      for (var i = 0; i < 130; i++) {
        if (i >= 30 && i < 40) {
          await gesture.moveBy(const Offset(30, 0));
        }
        if (i >= 60 && i < 70) {
          await gesture.moveBy(const Offset(-30, 0));
        }
        await tester.pump(const Duration(milliseconds: 16));
        final Rect region = drop.travel!.globalRect!;
        expect(
          region.expandToInclude(drop.globalRect) == region,
          isTrue,
          reason: '$motion, frame $i: the drop left its region: ${drop.globalRect} in $region',
        );
        drawn.add(drop.size);
      }
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '$motion: a drop held still keeps drawing');
      await gesture.up();
      await tester.pumpAndSettle();
    }
    // The same press: the same size once arrived, and not on the way.
    expect(sizes[null]!.last, sizes[GlassDropMotion.none]!.last, reason: 'arrived, the drop is not round');
    var differ = 0;
    for (var i = 0; i < 130; i++) {
      if ((sizes[null]![i].aspectRatio - sizes[GlassDropMotion.none]![i].aspectRatio).abs() > 0.01) {
        differ++;
      }
    }
    expect(differ, greaterThan(5), reason: 'the drop did not deform on its way');
  });

  testWidgets('a segment that is neither text nor icon reads its ink from the icon theme', (
    WidgetTester tester,
  ) async {
    // On the white capsule the selected segment is black, whatever the page's
    // icon colour; the others keep the page's.
    Widget glyph(String name) => Builder(
      builder: (BuildContext context) => SizedBox.square(
        key: ValueKey<String>(name),
        dimension: 12,
        child: ColoredBox(color: IconTheme.of(context).color!),
      ),
    );
    await _mount(
      tester,
      segments: <Widget>[glyph('a'), glyph('b'), glyph('c')],
      iconColour: const Color(0xFFFF0000),
    );
    Color colourOf(String name) => tester
        .widget<ColoredBox>(find.descendant(of: find.byKey(ValueKey<String>(name)), matching: find.byType(ColoredBox)))
        .color;
    expect(colourOf('a'), const Color(0xFF000000));
    expect(colourOf('b'), const Color(0xFFFF0000));
    expect(colourOf('c'), const Color(0xFFFF0000));
  });

  testWidgets('disabled, a press lifts nothing', (WidgetTester tester) async {
    await _mount(tester, enabled: false);
    final TestGesture gesture = await tester.startGesture(_segment(1));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_drop(tester).materialize, 0);
    await gesture.up();
  });
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

RenderGlassSurface _drop(WidgetTester tester) => tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface));

Future<void> _mount(
  WidgetTester tester, {
  GlobalKey? hostKey,
  ValueChanged<int>? onSelected,
  bool enabled = true,
  GlassDropMotion? dropMotion,
  List<Widget>? segments,
  Color? iconColour,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            key: hostKey ?? GlobalKey(),
            hardware: GlassHardware.appleMetal,
            child: SizedBox.fromSize(
              size: kScreen,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(child: CustomPaint(painter: _Bars())),
                  ),
                  Positioned.fromRect(
                    rect: kControl,
                    child: IconTheme(
                      data: IconThemeData(color: iconColour),
                      child: _Segments(
                        onSelected: enabled ? (onSelected ?? (_) {}) : null,
                        dropMotion: dropMotion,
                        segments: segments,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

class _Segments extends StatefulWidget {
  const _Segments({required this.onSelected, this.dropMotion, this.segments});

  final ValueChanged<int>? onSelected;
  final GlassDropMotion? dropMotion;
  final List<Widget>? segments;

  @override
  State<_Segments> createState() => _SegmentsState();
}

class _SegmentsState extends State<_Segments> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => GlassSegmentedControl(
    segments: widget.segments ?? const <Widget>[Text('Day'), Text('Week'), Text('Month'), Text('Year')],
    dropMotion: widget.dropMotion,
    selectedIndex: _index,
    onSelected: widget.onSelected == null
        ? null
        : (int i) {
            widget.onSelected!(i);
            setState(() => _index = i);
          },
  );
}

class _Bars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F1EA));
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), Paint()..color = const Color(0xFF1B1B1B));
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}
