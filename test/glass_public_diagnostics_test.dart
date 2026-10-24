// What an application reaches through the public libraries alone: the shadow
// filter a host is given, and the walk's log on the frame it publishes,
// fallbacks included.
//
// `flutter test test/glass_public_diagnostics_test.dart`
//
// Nothing here imports `src/`. A type dropped from the `show` of
// `g1455.dart` or `glass_diagnostics.dart` fails to compile, and that is the
// test.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

void main() {
  testWidgets('a host given a ShadowFilter counts the shadow it drops, and its frame names a WalkLog', (
    WidgetTester tester,
  ) async {
    final filter = ShadowFilter();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 300)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            shadowFilter: filter,
            child: const Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: Color(0xFF406080))),
                // Not a `BoxShadow`: under `flutter test` shadows are drawn
                // without their blur (`debugDisableShadows`).
                Positioned(left: 40, top: 40, width: 120, height: 80, child: CustomPaint(painter: _Blurred())),
                Positioned(left: 20, top: 100, width: 360, height: 60, child: GlassBar(child: SizedBox.expand())),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    final WalkLog? log = handle.frame?.log;
    expect(log, isNotNull, reason: 'the host published no frame');
    expect(log!.visited, greaterThan(0));
    expect(filter.maskFilteredDraws, greaterThan(0), reason: 'the blurred draw was not dropped');
  });

  // The pass draws an opacity over a filter apart from the engine: the engine
  // folds the alpha into the filter's layer, and the region the filter
  // painted outside its content goes. The host's pipeline hands that subtree
  // to the engine, and its frame says so.
  testWidgets('a host hands an opacity over a filter to the engine, and its frame names it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 300)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            child: const Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: Color(0xFF406080))),
                Positioned(
                  left: 40,
                  top: 80,
                  width: 200,
                  height: 100,
                  child: Opacity(
                    opacity: 0.5,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(Color(0xFF00FFFF), BlendMode.srcOver),
                      child: Center(
                        child: SizedBox(width: 40, height: 40, child: ColoredBox(color: Color(0xFFE02020))),
                      ),
                    ),
                  ),
                ),
                Positioned(left: 20, top: 100, width: 360, height: 60, child: GlassBar(child: SizedBox.expand())),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    final WalkLog? log = handle.frame?.log;
    expect(log, isNotNull, reason: 'the host published no frame');
    expect(log!.fellBack, <String>['OpacityLayer']);
    expect(log.opacityFoldedIntoFilter, 0);
  });
}

/// A rect drawn through a blur mask filter: what the filter takes for a shadow.
class _Blurred extends CustomPainter {
  const _Blurred();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = const Color(0x80000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  @override
  bool shouldRepaint(_Blurred oldDelegate) => false;
}
