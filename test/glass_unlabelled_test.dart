// Glass that carries no label keeps the finish it names under a label floor.
//
// `flutter test test/glass_unlabelled_test.dart`
//
// The theme's floor (`minLabelContrast`) dims every finish — a surface's own
// included — until a label over it reaches the floor. A control's drop carries
// no label, and dimmed for one it turned grey: the tab bar's clear drop, under
// the example's AA floor over a rich backdrop, showed the bar beneath it
// through a 0.682 dim, its margins past the bar dark where the backdrop should
// have been. `labelled: false` takes the floor off one surface or one group.
//
// Arms: a surface and a group with the flag keep `clear` exactly; the same
// two without it are dimmed by the arithmetic's dim (the control — a floor that
// had stopped dimming anything would pass the first arm too); and the package's
// own drops — the switch's and the tab bar's — are the unlabelled kind.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

Widget _screen({required bool labelled, Widget? extra}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(400, 400)),
    child: GlassHost(
      hardware: GlassHardware.appleMetal,
      finish: GlassFinish.clear,
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: Color(0xFF808080))),
          Positioned(
            left: 20,
            top: 20,
            width: 120,
            height: 60,
            child: GlassSurface(labelled: labelled),
          ),
          Positioned(
            left: 20,
            top: 120,
            width: 300,
            height: 80,
            child: GlassGroup(
              spacing: 12,
              labelled: labelled,
              child: const Stack(
                children: <Widget>[
                  Positioned(left: 0, top: 0, width: 120, height: 80, child: GlassSurface()),
                  Positioned(left: 140, top: 0, width: 120, height: 80, child: GlassSurface()),
                ],
              ),
            ),
          ),
          ?extra,
        ],
      ),
    ),
  ),
);

void main() {
  final GlassFinish dimmed = GlassFinish.clear.dimmed(
    GlassFinish.clear.dimmingFor(kTextContrastAA)!,
  );

  testWidgets('an unlabelled surface and group keep the finish they name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(labelled: false));
    await tester.pump();
    final RenderGlassSurface surface = tester.renderObject(find.byType(GlassSurface).first);
    final RenderGlassGroup group = tester.renderObject(
      find.descendant(
        of: find.byType(GlassGroup),
        matching: find.byWidgetPredicate(
          (Widget w) => w.runtimeType.toString() == '_GlassGroupRenderWidget',
        ),
      ),
    );
    expect(surface.effectiveFinish, GlassFinish.clear);
    expect(group.effectiveFinish, GlassFinish.clear);
  });

  testWidgets('the control: labelled, the same two are dimmed to the floor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(labelled: true));
    await tester.pump();
    final RenderGlassSurface surface = tester.renderObject(find.byType(GlassSurface).first);
    final RenderGlassGroup group = tester.renderObject(
      find.descendant(
        of: find.byType(GlassGroup),
        matching: find.byWidgetPredicate(
          (Widget w) => w.runtimeType.toString() == '_GlassGroupRenderWidget',
        ),
      ),
    );
    expect(surface.effectiveFinish, dimmed);
    expect(group.effectiveFinish, dimmed);
  });

  testWidgets('the package\'s own drops carry no label', (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(
        labelled: true,
        extra: Positioned(
          left: 20,
          top: 260,
          width: 360,
          child: GlassTabBar(
            items: const <GlassTabItem>[
              GlassTabItem(icon: IconData(0xe000), label: 'A'),
              GlassTabItem(icon: IconData(0xe001), label: 'B'),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    // Held up: at rest the drop is unmaterialized, its tint at alpha 0 whether
    // dimmed or not, and the tint would compare nothing.
    final Rect bar = tester.getRect(find.byType(GlassTabBar));
    final TestGesture finger = await tester.startGesture(bar.centerLeft + Offset(bar.width / 4, 0));
    await tester.pumpAndSettle();
    final Iterable<RenderGlassSurface> unlabelled = tester
        .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
        .where((RenderGlassSurface s) => !s.labelled);
    // The tab bar's drop, and only it: the bar itself carries labels.
    expect(unlabelled, hasLength(1));
    expect(unlabelled.single.materialize, 1, reason: 'the drop never lifted');
    expect(unlabelled.single.effectiveFinish.name, 'clear');
    expect(unlabelled.single.effectiveFinish.tint, GlassFinish.clear.tint);
    await finger.up();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _screen(
        labelled: true,
        extra: Positioned(
          left: 20,
          top: 260,
          child: GlassSwitch(value: false, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
          .where((RenderGlassSurface s) => !s.labelled),
      hasLength(1),
      reason: 'the switch\'s drop is dimmed for a label it does not have',
    );
  });
}
