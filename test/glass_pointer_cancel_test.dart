// A gesture the platform takes away: `PointerCancelEvent`, and the other ways a
// held control loses its finger.
//
// `flutter test test/glass_pointer_cancel_test.dart`
//
// Every control with a drop handles `up` and `cancel` separately, and the two
// are not interchangeable: `up` commits to the item under the drop, `cancel`
// must put the drop back where the selection is and select nothing. A cancel
// handled as an up selects whatever the finger was over when a scroll or a
// system gesture took it — which no test that only ever lifts a finger sees.
//
// Each arm drags the drop off the selection first, so that "back where it was"
// and "left where it got to" are different places.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 400);
const Rect kBar = Rect.fromLTWH(50, 300, 300, 60);

/// Item [i]'s centre for four items in [kBar], by the bar's own layout.
Offset _tab(double i) => Offset(kBar.left + 7 + (300 - 14) / 4 * (i + 0.5), kBar.center.dy);

void main() {
  testWidgets('tab bar: a cancelled drag selects nothing and puts the drop back on the selection', (
    WidgetTester tester,
  ) async {
    final selected = <int>[];
    await _mount(tester, _Tabs(onSelected: selected.add));
    final double rest = _centreOf(tester, _drop(tester)).dx;

    final TestGesture finger = await tester.startGesture(_tab(0));
    for (var i = 1; i <= 20; i++) {
      await finger.moveTo(Offset.lerp(_tab(0), _tab(2), i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final double dragged = _centreOf(tester, _drop(tester)).dx;
    expect(dragged, greaterThan(rest + 100), reason: 'the drag never moved the drop, so the arm cannot fail');
    expect(_drop(tester).materialize, greaterThan(0), reason: 'a held drop is lifted');

    await finger.cancel();
    await _settle(tester);
    expect(selected, isEmpty, reason: 'a cancel committed the item under the finger');
    expect(_centreOf(tester, _drop(tester)).dx, closeTo(rest, 0.5));
    expect(_drop(tester).materialize, 0, reason: 'the drop stayed lifted after its finger was taken');

    // The control: the same drag lifted rather than cancelled does select.
    final TestGesture again = await tester.startGesture(_tab(0));
    for (var i = 1; i <= 20; i++) {
      await again.moveTo(Offset.lerp(_tab(0), _tab(2), i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await again.up();
    await _settle(tester);
    expect(selected, <int>[2]);
  });

  testWidgets('segmented control: a cancelled drag selects nothing; disabling it mid-press drops the lift', (
    WidgetTester tester,
  ) async {
    final selected = <int>[];
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    await _mount(tester, _Segments(onSelected: selected.add, enabled: enabled));
    final double rest = _centreOf(tester, _drop(tester)).dx;

    final TestGesture finger = await tester.startGesture(_tab(0));
    for (var i = 1; i <= 20; i++) {
      await finger.moveTo(Offset.lerp(_tab(0), _tab(3), i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_centreOf(tester, _drop(tester)).dx, greaterThan(rest + 100));
    await finger.cancel();
    await _settle(tester);
    expect(selected, isEmpty);
    expect(_centreOf(tester, _drop(tester)).dx, closeTo(rest, 0.5));
    expect(_drop(tester).materialize, 0);

    // Held, then the control is disabled under the finger: the lift has to
    // come down by itself, and the eventual up must select nothing.
    final TestGesture held = await tester.startGesture(_tab(0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_drop(tester).materialize, greaterThan(0));
    enabled.value = false;
    await _settle(tester);
    expect(_drop(tester).materialize, 0, reason: 'a disabled control kept its drop lifted');
    await held.moveTo(_tab(2));
    await held.up();
    await _settle(tester);
    expect(selected, isEmpty, reason: 'a disabled control selected on release');
  });

  testWidgets('a rippling glass: a cancelled touch lets go, a held one does not', (WidgetTester tester) async {
    await _mount(
      tester,
      const GlassSurface(ripple: GlassRipple(), child: SizedBox.expand()),
    );
    final RenderGlassSurface glass = _surfaces(tester).single;
    final GlassRippleField field = glass.rippleField!;

    final TestGesture held = await tester.startGesture(kBar.center);
    await _settle(tester);
    expect(field.isEmpty, isFalse, reason: 'a held finger keeps its dimple');
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'a settled dimple should cost no frames');

    // A move that moves nothing drawn does not wake the field; one that does,
    // does. Without the second half the first is satisfied by a field that
    // ignores moves altogether.
    await held.moveBy(Offset.zero);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await held.moveBy(const Offset(6, 0));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await _settle(tester);
    expect(field.isEmpty, isFalse);

    await held.cancel();
    await _settle(tester);
    expect(field.isEmpty, isTrue, reason: 'a cancelled touch was never released');
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

// ---------------------------------------------------------------------------
// The scene.
// ---------------------------------------------------------------------------

Future<void> _mount(WidgetTester tester, Widget bar) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            child: SizedBox.fromSize(
              size: kScreen,
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(child: ColoredBox(color: Color(0xFFF4F1EA))),
                  Positioned.fromRect(rect: kBar, child: bar),
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

Future<void> _settle(WidgetTester tester) async {
  for (var frames = 0; tester.binding.hasScheduledFrame && frames < 600; frames++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Iterable<RenderGlassSurface> _surfaces(WidgetTester tester) =>
    tester.renderObjectList<RenderGlassSurface>(find.byType(GlassSurface));

/// The drop: the one surface that names the clear finish.
RenderGlassSurface _drop(WidgetTester tester) =>
    _surfaces(tester).singleWhere((RenderGlassSurface s) => s.declaredFinish?.name == GlassFinish.clear.name);

Offset _centreOf(WidgetTester tester, RenderBox box) => box.localToGlobal(box.size.center(Offset.zero));

class _Tabs extends StatefulWidget {
  const _Tabs({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: const <GlassTabItem>[
      GlassTabItem(icon: Icons.home, label: 'Home'),
      GlassTabItem(icon: Icons.search, label: 'Search'),
      GlassTabItem(icon: Icons.favorite, label: 'Saved'),
      GlassTabItem(icon: Icons.person, label: 'Profile'),
    ],
    selectedIndex: _index,
    onSelected: (int i) {
      widget.onSelected(i);
      setState(() => _index = i);
    },
  );
}

class _Segments extends StatefulWidget {
  const _Segments({required this.onSelected, required this.enabled});

  final ValueChanged<int> onSelected;
  final ValueListenable<bool> enabled;

  @override
  State<_Segments> createState() => _SegmentsState();
}

class _SegmentsState extends State<_Segments> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.enabled,
    builder: (BuildContext context, bool enabled, Widget? _) => GlassSegmentedControl(
      segments: const <Widget>[Text('Day'), Text('Week'), Text('Month'), Text('Year')],
      selectedIndex: _index,
      onSelected: enabled
          ? (int i) {
              widget.onSelected(i);
              setState(() => _index = i);
            }
          : null,
    ),
  );
}
