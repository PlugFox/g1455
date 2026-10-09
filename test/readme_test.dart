// The README's code and numbers are the package's, checked rather than copied.
//
// `flutter test test/readme_test.dart`
//
//  1. **The quick start runs as pasted.** Its block is `test/readme/quick_start.dart`
//     byte for byte, and that file is pumped: the app mounts, the list
//     scrolls under the glass and a tab can be picked.
//  2. **Every common pattern is real code.** Each block of the section is a
//     verbatim piece of `test/readme/patterns.dart`, which the analyzer reads
//     with the rest of the package, and each widget there is pumped.
//  3. **The finish table is the constants.** Every row of it is parsed and
//     compared with the `GlassFinish` it names, so a calibration that moves a
//     number fails here until the README moves with it.
//
// Breaks, each undone by swapping the string back:
//  - in `README.md`, the `.frosted` row's `| 8 |` -> `| 6 |`: the table arm
//    fails;
//  - in `test/readme/quick_start.dart`, `itemCount: 40` -> `itemCount: 30`:
//    the quick-start arm fails, the README no longer showing the file.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'readme/patterns.dart';
import 'readme/quick_start.dart' as quick_start;

final String _readme = File('README.md').readAsStringSync();

/// The body of the `## [heading]` section, up to the next `## `.
String _section(String heading) {
  final int start = _readme.indexOf('\n## $heading\n');
  expect(start, isNot(-1), reason: 'README has no "## $heading" section');
  final int end = _readme.indexOf('\n## ', start + 1);
  return _readme.substring(start, end == -1 ? _readme.length : end);
}

/// The contents of every ```dart block in [text].
List<String> _dartBlocks(String text) =>
    RegExp(r'```dart\n(.*?)```', dotAll: true).allMatches(text).map((Match m) => m.group(1)!).toList();

/// Every number in [cell], minus signs included.
List<double> _numbers(String cell) =>
    RegExp(r'-?\d+(\.\d+)?').allMatches(cell).map((Match m) => double.parse(m.group(0)!)).toList();

Future<void> _frames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _hosted(Widget child) => MaterialApp(
  builder: (BuildContext context, Widget? navigator) => GlassHost(backdrop: Colors.white, child: navigator!),
  home: Scaffold(body: child),
);

void main() {
  group('quick start', () {
    test('the README shows test/readme/quick_start.dart verbatim', () {
      final List<String> blocks = _dartBlocks(_section('Quick start'));
      expect(blocks, isNotEmpty);
      expect(blocks.first, File('test/readme/quick_start.dart').readAsStringSync());
    });

    testWidgets('mounts, scrolls under the glass, and picks a tab', (WidgetTester tester) async {
      await tester.pumpWidget(const quick_start.App());
      await _frames(tester);
      expect(find.byType(GlassHost), findsOneWidget);
      expect(find.byType(GlassBar), findsWidgets); // the tab bar's is one
      expect(find.byType(GlassTabBar), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await _frames(tester);
      await tester.tap(find.text('Search'));
      await _frames(tester, 40);
      expect(tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex, 2);
    });
  });

  group('common patterns', () {
    test('every block is a verbatim piece of test/readme/patterns.dart', () {
      final String source = File('test/readme/patterns.dart').readAsStringSync();
      final List<String> blocks = _dartBlocks(_section('Common patterns'));
      expect(blocks, hasLength(7));
      for (final String block in blocks) {
        expect(source.contains(block.trim()), isTrue, reason: 'not in patterns.dart:\n$block');
      }
    });

    testWidgets('glass over a scrolling list', (WidgetTester tester) async {
      await tester.pumpWidget(_hosted(const Feed()));
      await _frames(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await _frames(tester);
      expect(find.byType(GlassBar), findsOneWidget);
    });

    testWidgets('moving glass in a GlassTravel', (WidgetTester tester) async {
      await tester.pumpWidget(_hosted(const Lens()));
      await _frames(tester);
      await tester.dragFrom(const Offset(100, 100), const Offset(120, 40));
      await _frames(tester);
      expect(find.byType(GlassTravel), findsOneWidget);
    });

    testWidgets('glass on glass', (WidgetTester tester) async {
      await tester.pumpWidget(_hosted(const Cards()));
      await _frames(tester);
      expect(find.byType(GlassAbove), findsOneWidget);
      expect(find.byType(GlassCard), findsWidgets);
    });

    testWidgets('a stand-in for a video under glass', (WidgetTester tester) async {
      await tester.pumpWidget(_hosted(const Player(video: ColoredBox(color: Color(0xFF000000)))));
      await _frames(tester);
      expect(tester.takeException(), isNull);
      final GlassProxy proxy = tester.widget(find.byType(GlassProxy));
      expect(proxy.role, GlassProxyRole.replace);
      expect(find.byType(GlassBar), findsOneWidget);
    });

    testWidgets('a backdrop that does not change', (WidgetTester tester) async {
      // A memory image decodes on an engine future, so the decode runs outside
      // the fake clock, and only then is the declaration sampled.
      late MemoryImage wallpaper;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = const Color(0xFF3060A0));
        final ui.Image image = await recorder.endRecording().toImage(4, 4);
        wallpaper = MemoryImage((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(
        _hosted(
          Lockscreen(
            wallpaper: wallpaper,
            feed: ListView(children: const <Widget>[]),
          ),
        ),
      );
      await tester.runAsync(() => precacheImage(wallpaper, tester.element(find.byType(Lockscreen))));
      await _frames(tester);
      final List<RenderGlassSurface> surfaces = tester
          .renderObjectList<RenderGlassSurface>(find.byType(GlassSurface))
          .toList();
      expect(surfaces, hasLength(3));
      expect(surfaces.where((RenderGlassSurface s) => s.readsDeclaredBackdrop), hasLength(2));
    });

    testWidgets('a menu and a dialog over a bar', (WidgetTester tester) async {
      await tester.pumpWidget(_hosted(const Align(alignment: Alignment.topCenter, child: NotesBar())));
      await _frames(tester);
      await tester.tap(find.bySemanticsLabel('More'));
      await _frames(tester, 40);
      await tester.tap(find.text('Delete all'));
      await _frames(tester, 40);
      expect(find.text('Delete all notes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _frames(tester, 40);
      expect(find.text('Delete all notes?'), findsNothing);
    });

    for (final (bool reduce, bool lowEnd, GlassTier tier) in <(bool, bool, GlassTier)>[
      (false, false, GlassTier.full),
      (false, true, GlassTier.cheap),
      (true, false, GlassTier.opaque),
    ]) {
      testWidgets('the cheap rung: reduceTransparency $reduce, lowEndDevice $lowEnd', (WidgetTester tester) async {
        await tester.pumpWidget(cheapApp(reduceTransparency: reduce, lowEndDevice: lowEnd));
        await _frames(tester);
        final BuildContext context = tester.element(find.byType(GlassBar));
        expect(GlassTheme.of(context).tier.tier, tier);
      });
    }
  });

  test('the GlassFinish table is the constants', () {
    const Map<String, GlassFinish> finishes = <String, GlassFinish>{
      'regularDark': GlassFinish.regularDark,
      'regularLight': GlassFinish.regularLight,
      'clear': GlassFinish.clear,
      'frosted': GlassFinish.frosted,
    };
    final rows = <String, List<String>>{};
    for (final String line in _section('Finishes').split('\n')) {
      final Match? m = RegExp(r'^\| `\.(\w+)` \|(.*)\|$').firstMatch(line);
      if (m != null) {
        rows[m.group(1)!] = m.group(2)!.split('|').map((String c) => c.trim()).toList();
      }
    }
    expect(rows.keys, unorderedEquals(finishes.keys));

    double code(double channel) => (channel * 255).roundToDouble();
    for (final MapEntry<String, GlassFinish>(key: String name, value: GlassFinish f) in finishes.entries) {
      final List<String> row = rows[name]!;
      final String why = '.$name in the README';
      expect(row, hasLength(7), reason: why);
      final GlassOptics o = f.optics;
      expect(_numbers(row[0]), <double>[f.blurSigmaLogical], reason: '$why: blur');
      expect(_numbers(row[1]), <double>[code(f.tint.r), code(f.tint.g), code(f.tint.b)], reason: '$why: tint');
      expect(_numbers(row[2]).single, closeTo(f.tint.a, 1e-9), reason: '$why: tint alpha');
      expect(
        <double>[code(f.rim.r), code(f.rim.g), code(f.rim.b)],
        <double>[255, 255, 255],
        reason: '$why: the rim is white',
      );
      expect(_numbers(row[3]).single, closeTo(f.rim.a * 255, 1e-6), reason: '$why: rim');
      expect(_numbers(row[4]), <double>[o.strength], reason: '$why: bend at the rim');
      expect(_numbers(row[5]), <double>[1, o.thickness, o.shoulder, o.edgePower], reason: '$why: falloff');
      expect(_numbers(row[6]), <double>[o.zoom], reason: '$why: magnification');
      expect(o.widen, 0, reason: '$why: the table has no column for widen');
    }
  });
}
