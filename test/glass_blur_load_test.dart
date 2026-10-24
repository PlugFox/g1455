// The atlas's Gaussian arriving: a host loads it on Impeller, captures through
// the engine's blur until it lands, and captures again when it does.
//
// `flutter test --enable-impeller test/glass_blur_load_test.dart`
//
// A file of its own, as `glass_precache_failure_test.dart` is: the program is
// cached per process, `flutter_test_config.dart` loads it before any test, and
// these take it away and replace the loader.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_blur.dart';

final bool _impeller = ui.ImageFilter.isShaderFilterSupported;

void main() {
  late ui.FragmentProgram? loaded;
  final asked = <String>[];
  setUp(() {
    loaded = glassBlurProgram;
    asked.clear();
    addTearDown(() {
      debugGlassShaderLoader = ui.FragmentProgram.fromAsset;
      glassBlurProgram ??= loaded;
    });
  });

  testWidgets('on Skia nothing loads it', (WidgetTester tester) async {
    debugGlassShaderLoader = (String asset) {
      asked.add(asset);
      return ui.FragmentProgram.fromAsset(asset);
    };
    final _Rig rig = await _mount(tester);
    await tester.runAsync(GlassHost.precache);
    await _idle(tester, 2);
    expect(asked, isNot(contains(kGlassBlurShaderAsset)));
    expect(glassBlurProgram, isNull);
    expect(rig.recorded, greaterThan(0), reason: 'nothing was captured, so nothing was blurred either');
  }, skip: _impeller);

  testWidgets('a load that fails is reported, and the atlas is blurred by the engine', (WidgetTester tester) async {
    glassBlurProgram = null;
    debugGlassShaderLoader = (String asset) {
      asked.add(asset);
      return asset == kGlassBlurShaderAsset
          ? Future<ui.FragmentProgram>.error(StateError('no $asset'))
          : ui.FragmentProgram.fromAsset(asset);
    };
    final _Rig rig = await _mount(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await _idle(tester, 2);
    expect(asked, contains(kGlassBlurShaderAsset));
    expect(tester.takeException(), isA<StateError>(), reason: 'the failed load was not reported');
    expect(glassBlurProgram, isNull);
    expect(rig.recorded, greaterThan(0), reason: 'the host stopped capturing without the program');
  }, skip: !_impeller);

  testWidgets('one load is shared, and its arrival is a change the host captures for', (WidgetTester tester) async {
    // After the failure above, which was forgotten: this host loads again. A
    // still screen whose proxy is held would keep the engine's blur forever if
    // the arrival were not declared; and `GlassHost.precache`, called while
    // the host's load is in flight, waits on it rather than asking again.
    glassBlurProgram = null;
    final arrived = Completer<ui.FragmentProgram>();
    debugGlassShaderLoader = (String asset) {
      asked.add(asset);
      return asset == kGlassBlurShaderAsset ? arrived.future : ui.FragmentProgram.fromAsset(asset);
    };
    final _Rig rig = await _mount(tester);
    await _idle(tester, 4);
    final int held = rig.recorded;
    await _idle(tester, 3);
    expect(rig.recorded, held, reason: 'the screen is not held, so this cannot see a recapture');
    expect(glassBlurProgram, isNull);

    var precached = false;
    unawaited(GlassHost.precache().then((_) => precached = true));
    final ui.FragmentProgram program = (await tester.runAsync(
      () => ui.FragmentProgram.fromAsset(kGlassBlurShaderAsset),
    ))!;
    arrived.complete(program);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await _idle(tester, 2);

    expect(asked.where((String a) => a == kGlassBlurShaderAsset), hasLength(1), reason: 'loaded twice');
    expect(precached, isTrue);
    expect(glassBlurProgram, same(program));
    expect(rig.recorded, greaterThan(held), reason: 'the proxy blurred by the engine was held');
    final int after = rig.recorded;
    await _idle(tester, 3);
    expect(rig.recorded, after, reason: 'the arrival is declared on every frame');
  }, skip: !_impeller);
}

class _Rig {
  _Rig(this._host);
  final dynamic _host;
  int get recorded => _host.recorded as int;
}

Future<_Rig> _mount(WidgetTester tester) async {
  final hostKey = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(400, 300), devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(
          key: hostKey,
          content: GlassContentDeclaration.declared,
          hardware: GlassHardware.appleMetal,
          child: const Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: Color(0xFF3060A0))),
              Positioned(left: 40, top: 40, width: 200, height: 80, child: GlassSurface()),
            ],
          ),
        ),
      ),
    ),
  );
  return _Rig(hostKey.currentState! as dynamic);
}

Future<void> _idle(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
