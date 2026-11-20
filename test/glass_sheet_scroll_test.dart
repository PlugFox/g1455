// A sheet and a list in it share one drag, as UIKit's sheet and its scroll
// view do: down, the list until its top and then the sheet; up, the sheet
// until it is as high as it goes and then the list; a release flings
// whichever the finger last moved.
//
// `flutter test test/glass_sheet_scroll_test.dart`
//
// The content is a 40 px header over a list of forty 50 px rows, 360 tall at
// medium. Every arm that measures runs on Android's clamping physics, iOS's
// bouncing ones and macOS's (a desktop, where `PrimaryScrollController` is not
// inherited unless asked).
//
// Breaks, each undone by swapping the string back:
//  - in `_GlassSheet.build`, `controller: route._scroll,` ->
//    `controller: ScrollController(),`: no list hands over, and every arm but
//    the wheel, own-controller and reversed ones fails;
//  - `automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),`
//    dropped: the macOS variants fail, the others pass;
//  - in `_SheetScrollPosition.applyUserOffset`, `route._drag(delta - room);`
//    -> `super.applyUserOffset(delta - room);`: down at the top moves the
//    list, not the sheet — the close, the drop-to-medium, the pull and the
//    there-and-back arms fail;
//  - `final double rest = route._dragUpFromContent(delta);` -> `final double
//    rest = delta;`: up scrolls the list at medium, and the rise arms fail;
//  - in `goBallistic`, `route._release(-velocity);` -> `route._release(0);`:
//    a flick up from medium settles back, and the flick arms fail;
//  - in `_dragUpFromContent`, `var rest = _raise(dy);` -> `var rest = dy;`:
//    the sheet dragged down and back up keeps the drop under its rise and
//    never reaches large, and the there-and-back arm fails;
//  - `bool get _hands => axisDirection == AxisDirection.down;` -> `=> true;`:
//    the reversed list moves the sheet, and its arm fails;
//  - in `drag`, `route._touch();` dropped: nothing here fails — the content's
//    medium height is measured already; `glass_sheet_detent_test`'s
//    remeasure arm drags the sheet's own body.

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const Size kScreen = Size(400, 800);

/// The top of a sheet at large: the window has no safe area.
const double kLargeTop = kGlassSheetInset;

final TargetPlatformVariant kPlatforms = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
});

void main() {
  testWidgets('up from medium the sheet rises with the finger, and the list scrolls only once it is at large', (
    WidgetTester tester,
  ) async {
    final detents = <GlassSheetDetent>[];
    final _Rig rig = await _Rig.mount(tester, onDetentChanged: detents.add);
    final TestGesture finger = await rig.grab();
    for (final double dy in <double>[-30, -45, -25]) {
      final double top = rig.top;
      await finger.moveBy(Offset(0, dy));
      await tester.pump();
      expect(rig.top - top, closeTo(dy, 0.01), reason: 'the top did not follow the finger');
      expect(rig.pixels, 0, reason: 'the list scrolled before the sheet was at large');
    }
    final double room = rig.top - kLargeTop;
    await finger.moveBy(const Offset(0, -500));
    await tester.pump();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(rig.pixels, closeTo(500 - room, 0.01), reason: 'the list did not take what the sheet left');
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(detents, <GlassSheetDetent>[GlassSheetDetent.large]);
  }, variant: kPlatforms);

  testWidgets('down at large the list scrolls to its top, and the sheet follows the finger from there', (
    WidgetTester tester,
  ) async {
    final detents = <GlassSheetDetent>[];
    final _Rig rig = await _Rig.mount(
      tester,
      initialDetent: GlassSheetDetent.large,
      onDetentChanged: detents.add,
      scrolledTo: 300,
    );
    expect(rig.top, closeTo(kLargeTop, 0.01));
    final TestGesture finger = await rig.grab(down: true);
    final double scrolled = rig.pixels;
    expect(scrolled, greaterThan(150), reason: 'the slop took the scroll');
    await finger.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(rig.pixels, closeTo(scrolled - 100, 0.01));
    expect(rig.top, closeTo(kLargeTop, 0.01), reason: 'the sheet moved while the list could scroll');
    await finger.moveBy(Offset(0, scrolled - 100 + 60));
    await tester.pump();
    expect(rig.pixels, 0);
    expect(rig.top, closeTo(kLargeTop + 60, 0.01), reason: 'the sheet did not take what the list left');
    // Back up: the sheet first, to large, and then the list.
    await finger.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(rig.pixels, closeTo(40, 0.01));
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(detents, isEmpty);
  }, variant: kPlatforms);

  testWidgets('dragged down from large past half way through the list, the sheet settles at medium', (
    WidgetTester tester,
  ) async {
    final detents = <GlassSheetDetent>[];
    final _Rig medium = await _Rig.mount(tester);
    final double mediumTop = medium.top;
    final _Rig rig = await _Rig.mount(tester, initialDetent: GlassSheetDetent.large, onDetentChanged: detents.add);
    final TestGesture finger = await rig.grab(down: true);
    await finger.moveBy(Offset(0, (mediumTop - kLargeTop) * 0.7));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(mediumTop, 0.01));
    expect(rig.pixels, 0);
    expect(detents, <GlassSheetDetent>[GlassSheetDetent.medium]);
  }, variant: kPlatforms);

  testWidgets('down at medium through the list the sheet goes below it; past a third it closes, short of it not', (
    WidgetTester tester,
  ) async {
    _Rig rig = await _Rig.mount(tester);
    final double top = rig.top;
    TestGesture finger = await rig.grab(down: true);
    final double from = rig.top;
    await finger.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(rig.top - from, closeTo(40, 0.01), reason: 'the sheet did not follow the list down');
    expect(rig.pixels, 0);
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(top, 0.01), reason: 'a short drag closed the sheet or left it down');
    expect(rig.open, isTrue);

    rig = await _Rig.mount(tester);
    finger = await rig.grab(down: true);
    await finger.moveBy(const Offset(0, 200));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.open, isFalse, reason: 'dragged a third of its height down, the sheet stayed');
  }, variant: kPlatforms);

  testWidgets('a flick down on the list at its top closes the sheet', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester);
    await tester.fling(find.text('row 2'), const Offset(0, 80), 2500);
    await tester.pumpAndSettle();
    expect(rig.open, isFalse);
  }, variant: kPlatforms);

  testWidgets('a flick up on the list at medium carries the sheet to large, and leaves the list at its top', (
    WidgetTester tester,
  ) async {
    final detents = <GlassSheetDetent>[];
    final _Rig rig = await _Rig.mount(tester, onDetentChanged: detents.add);
    await tester.fling(find.text('row 2'), const Offset(0, -60), 1500);
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(rig.pixels, 0, reason: 'the list took the flick the sheet had');
    expect(detents, <GlassSheetDetent>[GlassSheetDetent.large]);
  }, variant: kPlatforms);

  testWidgets('a flick up on the list at large flings the list, and the sheet stays', (WidgetTester tester) async {
    final detents = <GlassSheetDetent>[];
    final _Rig rig = await _Rig.mount(tester, initialDetent: GlassSheetDetent.large, onDetentChanged: detents.add);
    await tester.fling(find.text('row 2'), const Offset(0, -60), 1500);
    await tester.pumpAndSettle();
    expect(rig.pixels, greaterThan(200), reason: 'the list did not carry on');
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(detents, isEmpty);
  }, variant: kPlatforms);

  testWidgets('dragged down and back up in one gesture, the sheet comes back before the list scrolls', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester);
    final TestGesture finger = await rig.grab(down: true);
    final double from = rig.top;
    await finger.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(rig.top - from, closeTo(40, 0.01));
    await finger.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(rig.top - from, closeTo(-20, 0.01), reason: 'the drop was not taken back first, then the rise');
    expect(rig.pixels, 0);
    // The rest of the way up: at large exactly, with nothing of the drop
    // left below it, and the list taking only what is past large.
    final double room = rig.top - kLargeTop;
    await finger.moveBy(Offset(0, -room - 30));
    await tester.pump();
    expect(rig.top, closeTo(kLargeTop, 0.01), reason: 'the drop down was kept under the rise');
    expect(rig.pixels, closeTo(30, 0.01));
    await finger.up();
    await tester.pumpAndSettle();
  }, variant: kPlatforms);

  testWidgets('a sheet the drag cannot close is pulled through the list, and springs back', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester, dismissible: false);
    final double top = rig.top;
    final TestGesture finger = await rig.grab(down: true);
    final double from = rig.top;
    await finger.moveBy(const Offset(0, 200));
    await tester.pump();
    final double pulled = rig.top - from;
    expect(pulled, inExclusiveRange(10, 100), reason: 'not a quarter of the way: $pulled');
    expect(rig.pixels, 0);
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.open, isTrue);
    expect(rig.top, closeTo(top, 0.01));
  }, variant: kPlatforms);

  testWidgets('with medium alone, up scrolls the list as it always did', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, detents: const <GlassSheetDetent>[GlassSheetDetent.medium]);
    final double top = rig.top;
    final TestGesture finger = await rig.grab();
    final double scrolled = rig.pixels;
    await finger.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(rig.pixels, closeTo(scrolled + 120, 0.01));
    expect(rig.top, closeTo(top, 0.01));
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(top, 0.01));
  }, variant: kPlatforms);

  testWidgets('a drag cancelled half way through the list still settles at a detent', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester);
    final double medium = rig.top;
    final TestGesture finger = await rig.grab();
    await finger.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(rig.top, inExclusiveRange(kLargeTop, medium));
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(rig.top, anyOf(closeTo(kLargeTop, 0.01), closeTo(medium, 0.01)));
  });

  testWidgets('two lists side by side in one sheet each hand over, from their own top', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, twoLists: true);
    final double medium = rig.top;
    for (final String row in <String>['left 2', 'right 2']) {
      final TestGesture finger = await tester.startGesture(tester.getCenter(find.text(row)));
      await finger.moveBy(const Offset(0, -20));
      await tester.pump();
      await finger.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(rig.top, lessThan(medium - 30), reason: '$row: the sheet did not rise');
      await finger.up();
      await tester.pumpAndSettle();
      expect(rig.top, closeTo(medium, 0.01), reason: '$row: a short rise did not settle back');
    }
    // At large, the right list scrolled and the left not: down on the left
    // moves the sheet at once, down on the right scrolls it first.
    final TestGesture up = await tester.startGesture(tester.getCenter(find.text('right 2')));
    await up.moveBy(const Offset(0, -20));
    await up.moveBy(const Offset(0, -900));
    await tester.pump();
    await up.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    final ScrollPosition right = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
    expect(right.pixels, greaterThan(100));
    final TestGesture left = await tester.startGesture(tester.getCenter(find.text('left 2')));
    await left.moveBy(const Offset(0, 20));
    await left.moveBy(const Offset(0, 50));
    await tester.pump();
    expect(rig.top, greaterThan(kLargeTop + 40), reason: 'the left list at its top did not hand over');
    await left.up();
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(kLargeTop, 0.01));
    final double scrolled = right.pixels;
    final TestGesture other = await tester.startGesture(
      tester.getCenter(find.text('right ${(scrolled / 50).ceil() + 2}')),
    );
    await other.moveBy(const Offset(0, 20));
    await other.moveBy(const Offset(0, 50));
    await tester.pump();
    expect(rig.top, closeTo(kLargeTop, 0.01), reason: 'the scrolled right list handed over before its top');
    expect(right.pixels, lessThan(scrolled));
    await other.up();
    await tester.pumpAndSettle();
  });

  testWidgets('closed by the app under a finger on its list, the sheet goes, and the rest of the drag is harmless', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _Rig.mount(tester);
    final TestGesture finger = await rig.grab(down: true);
    await finger.moveBy(const Offset(0, 30));
    await tester.pump();
    Navigator.of(tester.element(find.text('header'))).pop();
    await tester.pump();
    await finger.moveBy(const Offset(0, 60));
    await tester.pump();
    await finger.moveBy(const Offset(0, -200));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(rig.open, isFalse);
    expect(find.text('open sheet'), findsOneWidget, reason: 'the release popped the page under the sheet');
  });

  testWidgets('a list with a controller of its own keeps its drag to itself', (WidgetTester tester) async {
    final own = ScrollController();
    addTearDown(own.dispose);
    final _Rig rig = await _Rig.mount(tester, controller: own);
    final double top = rig.top;
    final TestGesture finger = await rig.grab(down: true);
    await finger.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(rig.top, closeTo(top, 0.01), reason: 'a list with its own controller moved the sheet');
    await finger.moveBy(const Offset(0, -400));
    await tester.pump();
    expect(rig.top, closeTo(top, 0.01));
    expect(own.offset, greaterThan(0));
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.open, isTrue);
  });

  testWidgets('a reversed list keeps its drag to itself', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester, reverse: true);
    final double top = rig.top;
    final TestGesture finger = await rig.grab(down: true);
    await finger.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(rig.top, closeTo(top, 0.01), reason: 'a reversed list moved the sheet');
    expect(rig.pixels, greaterThan(0));
    await finger.up();
    await tester.pumpAndSettle();
    expect(rig.open, isTrue);
    expect(rig.top, closeTo(top, 0.01));
  });

  testWidgets('a mouse wheel scrolls the list and never the sheet', (WidgetTester tester) async {
    final _Rig rig = await _Rig.mount(tester);
    final double top = rig.top;
    final Offset at = tester.getCenter(find.text('row 2'));
    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pumpAndSettle();
    expect(rig.top, closeTo(top, 0.01));
    expect(rig.pixels, 0);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await tester.pumpAndSettle();
    expect(rig.pixels, 100);
    expect(rig.top, closeTo(top, 0.01));
  });

  testWidgets('moved through the list the sheet declares where it travels, and the list scrolled is not retaken', (
    WidgetTester tester,
  ) async {
    // Translucent at large, so the sheet keeps a capture to retake.
    final _Rig rig = await _Rig.mount(tester, largeFinish: GlassFinish.regularDark);
    final int before = rig.recorded;
    final TestGesture finger = await rig.grab();
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();
    final int rising = rig.recorded - before;
    expect(rig.top, closeTo(kLargeTop, 0.01));
    expect(rising, lessThanOrEqualTo(3), reason: 'the rise through the list was retaken: $rising');
    // At large, the list scrolling over the sheet's glass changes nothing
    // under it.
    final int still = rig.recorded;
    final TestGesture again = await rig.grab();
    for (var i = 0; i < 12; i++) {
      await again.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await again.up();
    await tester.pumpAndSettle();
    expect(rig.pixels, greaterThan(200));
    expect(rig.recorded - still, 0, reason: 'the list scrolling in the sheet retook its capture');
  });
}

class _Rig {
  _Rig._(this.tester, this.hostKey);

  final WidgetTester tester;
  final GlobalKey hostKey;

  static Future<_Rig> mount(
    WidgetTester tester, {
    List<GlassSheetDetent> detents = const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
    GlassSheetDetent? initialDetent,
    ValueChanged<GlassSheetDetent>? onDetentChanged,
    bool dismissible = true,
    bool reverse = false,
    ScrollController? controller,
    GlassFinish? largeFinish,
    double scrolledTo = 0,
    bool twoLists = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view
      ..physicalSize = kScreen * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final hostKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => GlassHost(
          key: hostKey,
          hardware: GlassHardware.appleMetal,
          backdrop: const Color(0xFF406080),
          child: child!,
        ),
        home: Builder(
          builder: (BuildContext context) => Stack(
            children: <Widget>[
              const Positioned(left: 16, right: 16, top: 40, height: 56, child: GlassBar(child: Text('bar'))),
              Center(
                child: GestureDetector(
                  onTap: () => showGlassSheet<void>(
                    context: context,
                    detents: detents,
                    initialDetent: initialDetent,
                    onDetentChanged: onDetentChanged,
                    barrierDismissible: dismissible,
                    largeFinish: largeFinish,
                    builder: (BuildContext context) => SizedBox(
                      height: 360,
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 40, child: Center(child: Text('header'))),
                          if (twoLists)
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  for (final String side in <String>['left', 'right'])
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: 40,
                                        itemExtent: 50,
                                        itemBuilder: (BuildContext context, int i) => Text('$side $i'),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                controller: controller,
                                reverse: reverse,
                                itemCount: 40,
                                itemExtent: 50,
                                itemBuilder: (BuildContext context, int i) => Text('row $i'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('open sheet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    final rig = _Rig._(tester, hostKey);
    if (scrolledTo != 0) {
      rig.position.jumpTo(scrolledTo);
      await tester.pump();
    }
    return rig;
  }

  bool get open => find.text('header').evaluate().isNotEmpty;

  ScrollPosition get position => tester.state<ScrollableState>(find.byType(Scrollable).last).position;

  double get pixels => position.pixels;

  /// The top of the sheet's glass.
  double get top => tester
      .renderObject<RenderGlassSurface>(
        find.ancestor(of: find.text('header'), matching: find.byType(GlassSurface)).first,
      )
      .globalRect
      .top;

  int get recorded => (hostKey.currentState! as dynamic).recorded as int;

  /// A finger on the middle of the list, moved past the slop — up, or [down] — so the
  /// moves after it are the drag's own.
  Future<TestGesture> grab({bool down = false}) async {
    final TestGesture finger = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await finger.moveBy(Offset(0, down ? 20 : -20));
    await tester.pump();
    return finger;
  }
}
