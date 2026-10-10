// Materializing: the finish arriving, as Apple's `.materialize` does — blur
// first, level last, shape whole throughout (read off macOS).
//
// `flutter test test/glass_materialize_test.dart`
//
// Breaks, each undone by swapping the string back:
//  - `if (!listEquals(blurs, _lastBlurs))` -> `if (false)` in `GlassHost._capture`:
//    a still surface whose blur moved is held at the old one, and the animated
//    arm differs from the fresh mount;
//  - `record.materialize > 0` -> `true` in the same method: a surface at zero is
//    captured for nothing, and the counter arm fails.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

const Size kScreen = Size(400, 300);
final GlobalKey _shotKey = GlobalKey();

void main() {
  test('the ramp is the one read off Apple: blur and refraction with p, tint and rim with p cubed', () {
    const GlassFinish f = GlassFinish.regularDark;
    expect(identical(f.materializing(1), f), isTrue);
    final GlassFinish half = f.materializing(0.5);
    expect(half.name, f.name, reason: 'the damage tables are keyed by name');
    expect(half.blurSigmaLogical, closeTo(f.blurSigmaLogical * 0.5, 1e-12));
    expect(half.optics.strength, closeTo(f.optics.strength * 0.5, 1e-12));
    expect(half.tint.a, closeTo(f.tint.a * 0.125, 1e-6));
    expect(half.rim.a, closeTo(f.rim.a * 0.125, 1e-6));
    expect(half.tint.r, f.tint.r);
    final GlassFinish none = f.materializing(0);
    expect(none.blurSigmaLogical, 0);
    expect(none.tint.a, 0);
  });

  testWidgets('at one it is the surface without it, at zero it is nothing and costs nothing', (
    WidgetTester tester,
  ) async {
    final Uint8List plain = await _shot(tester, const _Scene());
    final Uint8List one = await _shot(tester, const _Scene(materialize: 1));
    expect(_differing(plain, one), 0);

    final Uint8List bare = await _shot(tester, const _Scene(glass: false));
    final Uint8List zero = await _shot(tester, const _Scene(materialize: 0));
    expect(_differing(bare, zero), 0, reason: 'a glass at zero drew something');
    final GlassProxyHandle handle = _handle(tester);
    expect(handle.frame, isNull, reason: 'a glass at zero was captured');
    expect(_differing(bare, plain), greaterThan(1000), reason: 'the glass is invisible anyway');
  });

  testWidgets('animated in place, each stage is the stage mounted fresh', (WidgetTester tester) async {
    // A still panel whose blur moves: nothing the oracle watches changes, so
    // the host has to notice the finish. Each stage is compared with a fresh
    // mount of a surface *wearing* `materializing(p)` as its finish, which
    // also says the parameter and the finish are one thing.
    final p = ValueNotifier<double>(0.2);
    addTearDown(p.dispose);
    await _pump(tester, _Scene(animated: p));
    final held = <double, Uint8List>{};
    for (final double at in <double>[0.35, 0.6, 0.85]) {
      p.value = at;
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      held[at] = await _pixels(tester);
    }
    final previous = <Uint8List>[];
    for (final MapEntry<double, Uint8List> stage in held.entries) {
      final Uint8List fresh = await _shot(
        tester,
        _Scene(finish: GlassFinish.regularDark.materializing(stage.key)),
      );
      final int differing = _differing(stage.value, fresh);
      // ignore: avoid_print
      print('materialize ${stage.key}: differing from a fresh mount $differing');
      expect(differing, 0, reason: 'at ${stage.key} the animated glass is another picture');
      previous.add(fresh);
    }
    // The stages are distinct pictures, or the arm compared one frame thrice.
    expect(_differing(previous[0], previous[1]), greaterThan(1000));
    expect(_differing(previous[1], previous[2]), greaterThan(1000));
  });
}

class _Scene extends StatelessWidget {
  const _Scene({this.glass = true, this.materialize, this.animated, this.finish});

  final bool glass;
  final double? materialize;
  final ValueNotifier<double>? animated;
  final GlassFinish? finish;

  @override
  Widget build(BuildContext context) {
    Widget surface(double m) => GlassSurface(
      finish: finish,
      materialize: m,
      borderRadius: const BorderRadius.all(Radius.circular(30)),
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
            if (glass)
              Positioned(
                left: 60,
                top: 90,
                width: 260,
                height: 110,
                child: animated == null
                    ? surface(materialize ?? 1)
                    : ValueListenableBuilder<double>(
                        valueListenable: animated!,
                        builder: (BuildContext context, double m, Widget? _) => surface(m),
                      ),
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
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF4F1EA));
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), Paint()..color = const Color(0xFF1B1B1B));
    }
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), Paint()..color = const Color(0xFF1B1B1B));
    }
    for (var i = 0; i < 9; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 37.0, size.width, 5),
        Paint()..color = HSVColor.fromAHSV(1, (i * 47 % 360).toDouble(), 0.8, 0.9).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

GlassProxyHandle _handle(WidgetTester tester) => tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;

Future<void> _pump(WidgetTester tester, Widget child) async {
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
            finish: GlassFinish.regularDark,
            // One divisor for every stage: the policy picks it per sigma, and a
            // stage at another divisor is another picture for a reason that is
            // not this arm's.
            resolution: ProxyResolution.divisor(1),
            child: child,
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<Uint8List> _shot(WidgetTester tester, Widget child) async {
  await _pump(tester, child);
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

int _differing(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) {
      n++;
    }
  }
  return n;
}
