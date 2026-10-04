// A shader load that fails: `GlassHost.precache` completes with its error, and
// nothing after it is handed the same failure.
//
// `flutter test test/glass_precache_failure_test.dart`
//
// A file of its own: the programs are cached per process, and this one
// replaces the loader before anything has loaded.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';

void main() {
  testWidgets('a failed precache is caught, and the host loads again without an uncaught error', (
    WidgetTester tester,
  ) async {
    final List<String> asked = <String>[];
    var failing = true;
    debugGlassShaderLoader = (String asset) {
      asked.add(asset);
      return failing ? Future<ui.FragmentProgram>.error(StateError('no $asset')) : ui.FragmentProgram.fromAsset(asset);
    };
    addTearDown(() => debugGlassShaderLoader = ui.FragmentProgram.fromAsset);

    Object? caught;
    await tester.runAsync(() async {
      try {
        await GlassHost.precache(ripple: false);
      } on Object catch (error) {
        caught = error;
      }
    });
    expect(caught, isA<StateError>(), reason: 'the precache did not complete with the load error');
    expect(asked, unorderedEquals(<String>[kGlassShaderAsset, 'packages/g1455/shaders/glass_group.frag']));

    // The application started anyway, and the loads work again: the host
    // starts loads of its own rather than waiting on the failed ones.
    failing = false;
    asked.clear();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(child: SizedBox.expand()),
      ),
    );
    for (
      var i = 0;
      i < 200 && tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle.program == null;
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    expect(asked, contains(kGlassShaderAsset), reason: 'the host was handed the failed load');
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    expect(handle.program, isNotNull);
    expect(handle.groupProgram, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a host whose own load fails reports it, and draws without the program', (WidgetTester tester) async {
    // The first test filled the cache; this one needs a host that has to load.
    // So it waits on a ripple, which nothing loaded yet.
    debugGlassShaderLoader = (String asset) => Future<ui.FragmentProgram>.error(StateError('no $asset'));
    addTearDown(() => debugGlassShaderLoader = ui.FragmentProgram.fromAsset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(child: SizedBox.expand()),
      ),
    );
    final GlassProxyHandle handle = tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle;
    handle.wantRippleProgram();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
    final Object? reported = tester.takeException();
    expect(reported, isA<StateError>(), reason: 'the failed load was not reported');
    expect(handle.rippleProgram, isNull);
  });
}
