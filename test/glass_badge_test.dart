// GlassBadge: what it says, where it sits, that it is not glass, and what a
// count changing costs on a glass bar.
//
// `flutter test test/glass_badge_test.dart`
//
//  1. **The text:** the count, "99+" past the cap, nothing at 0, the label,
//     or a dot.
//  2. **Its centre sits on the child's top trailing corner,** in either
//     direction.
//  3. **It is opaque red over glass** — the pixel under it is `systemRed`
//     exactly, where the glass beside it is not — **and it is no surface:** a
//     bar with a badge is one surface. The control: a `GlassButton` in the
//     same place makes it two, so the ledger can see a second one.
//  4. **A count changing on a glass bar is no capture** and repaints nothing
//     under the glass; the host's own control.
//  5. **Semantics:** the text, or the label given; a dot says nothing.
//
// Break, undone by swapping the string back: in `glass_badge.dart`,
// `translation: Offset(rtl ? -0.5 : 0.5, -0.5)` -> `translation: Offset.zero`:
// arm 2's centre is half a badge off the corner.

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'component_scene.dart';

const Key _icon = ValueKey<String>('icon');
const Key _badge = ValueKey<String>('badge');

Widget _marked({int? count, String? label}) => GlassBadge(
  key: _badge,
  count: count,
  label: label,
  child: const SizedBox(key: _icon, width: 28, height: 28),
);

void main() {
  test('the text: the count, the cap, the label, or none', () {
    expect(const GlassBadge(count: 5).text, '5');
    expect(const GlassBadge(count: 99).text, '99');
    expect(const GlassBadge(count: 120).text, '99+');
    expect(const GlassBadge(count: 12, maxCount: 9).text, '9+');
    expect(const GlassBadge(label: 'New').text, 'New');
    expect(const GlassBadge().text, isNull);
  });

  testWidgets('a count, nothing at 0, a dot; centred on the trailing corner in either direction', (
    WidgetTester tester,
  ) async {
    final ComponentScene scene = await ComponentScene.mount(tester, _marked(count: 3));
    expect(find.text('3'), findsOneWidget);
    final Rect icon = tester.getRect(find.byKey(_icon));
    Rect badge() => tester.getRect(
      find.descendant(of: find.byKey(_badge), matching: find.byType(DecoratedBox)).first,
    );
    // ignore: avoid_print
    print('icon $icon, badge ${badge()}');
    expect(badge().center.dx, closeTo(icon.right, 0.5), reason: 'not on the trailing edge');
    expect(badge().center.dy, closeTo(icon.top, 0.5), reason: 'not on the top edge');
    expect(badge().height, kGlassBadgeHeight);
    expect(badge().width, greaterThanOrEqualTo(kGlassBadgeHeight), reason: 'one digit is narrower than a circle');
    // The badge does not move what it marks.
    expect(tester.getSize(find.byKey(_badge)), const Size(28, 28));

    await scene.pump(_marked(count: 3), textDirection: TextDirection.rtl);
    expect(badge().center.dx, closeTo(tester.getRect(find.byKey(_icon)).left, 0.5), reason: 'RTL: not on the left');

    await scene.pump(_marked(count: 0));
    expect(find.byType(DecoratedBox), findsNothing, reason: 'a badge at 0');
    expect(find.byKey(_icon), findsOneWidget);

    await scene.pump(_marked());
    expect(badge().size, const Size.square(kGlassBadgeDot));
    expect(find.byType(Text), findsNothing);

    await scene.pump(const GlassBadge(count: 1, isVisible: false, child: SizedBox(key: _icon)));
    expect(find.byType(DecoratedBox), findsNothing, reason: 'a hidden badge was drawn');
  });

  testWidgets('opaque red over glass, and no surface: a bar with a badge is one, with a button two', (
    WidgetTester tester,
  ) async {
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      SizedBox(
        width: 200,
        child: GlassBar(
          child: Center(child: _marked(label: '•')),
        ),
      ),
    );
    expect(scene.surfaces, 1, reason: 'the badge is glass');
    expect(scene.load.surfaceCount, 1);
    final Rect badge = tester.getRect(
      find.descendant(of: find.byKey(_badge), matching: find.byType(DecoratedBox)).first,
    );
    final Uint8List px = await scene.pixels();
    final List<int> on = rgbAt(px, badge.centerLeft + const Offset(3, 0));
    final List<int> beside = rgbAt(px, badge.centerLeft - const Offset(6, 0));
    // ignore: avoid_print
    print('under the badge $on, the glass beside it $beside');
    expect(on, <int>[0xFF, 0x3B, 0x30], reason: 'the badge is not opaque systemRed');
    expect(beside, isNot(<int>[0xFF, 0x3B, 0x30]), reason: 'the probe beside the badge is on the badge');

    // The control: the same place holding glass is counted.
    await scene.pump(
      SizedBox(
        width: 200,
        child: GlassBar(
          child: Center(
            child: GlassButton(onPressed: () {}, child: const SizedBox(width: 12, height: 12)),
          ),
        ),
      ),
    );
    expect(scene.surfaces, 2, reason: 'the ledger cannot see a second surface');
  });

  testWidgets('a count changing on a glass bar captures nothing and repaints nothing under the glass', (
    WidgetTester tester,
  ) async {
    var count = 1;
    late StateSetter set;
    final ComponentScene scene = await ComponentScene.mount(
      tester,
      SizedBox(
        width: 200,
        child: GlassBar(
          child: Center(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                set = setState;
                return _marked(count: count);
              },
            ),
          ),
        ),
      ),
    );
    final int recorded = scene.recorded;
    final int painted = scene.paints.value;
    for (var i = 0; i < 5; i++) {
      set(() => count++);
      await scene.frames(3);
    }
    set(() => count = 0);
    await scene.frames(3);
    final int captures = scene.recorded - recorded;
    final int paints = scene.paints.value - painted;
    // ignore: avoid_print
    print('six count changes on a bar: $captures captures, $paints backdrop paints');
    expect(find.byType(Text), findsNothing, reason: 'the count never reached 0, so the arm moved nothing');
    expect(captures, 0, reason: 'a count change took a capture');
    expect(paints, 0, reason: 'a count change repainted what is under the glass');
    expect(await scene.repaintBackdrop(), greaterThan(0), reason: 'the capture counter cannot move on this mount');
  });

  testWidgets('semantics: the text, or the label given; a dot says nothing', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ComponentScene scene = await ComponentScene.mount(tester, _marked(count: 120));
    expect(find.bySemanticsLabel('99+'), findsOneWidget);
    await scene.pump(const GlassBadge(count: 3, semanticLabel: '3 unread'));
    expect(find.bySemanticsLabel('3 unread'), findsOneWidget);
    expect(find.bySemanticsLabel('3'), findsNothing, reason: 'the text was said as well as the label');
    await scene.pump(const GlassBadge(key: _badge));
    expect(tester.getSemantics(find.byKey(_badge)).label, isEmpty);
    handle.dispose();
  });

  testWidgets('mounts without ambient Directionality', (WidgetTester tester) async {
    await tester.pumpWidget(const GlassBadge(count: 3, child: SizedBox(width: 28, height: 28)));
    expect(find.byType(GlassBadge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsOneWidget);

    await tester.pumpWidget(const GlassBadge(child: SizedBox(width: 28, height: 28)));
    expect(find.byType(GlassBadge), findsOneWidget);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });

  test('debugFillProperties', () {
    final builder = DiagnosticPropertiesBuilder();
    const GlassBadge(count: 7, isVisible: false).debugFillProperties(builder);
    final List<String> said = builder.properties
        .where((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info))
        .map((DiagnosticsNode n) => n.toString())
        .toList();
    expect(said, containsAll(<String>['count: 7', 'hidden']));
    expect(said.where((String s) => s.startsWith('color')), isEmpty, reason: 'a default was reported');
  });
}
