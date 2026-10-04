// The README's animations: every scene in `scenes.dart` played headless under
// flutter_tester and written out as frames, one directory per scene — and the
// whole screens of `screen.dart` after them.
//
//   SHOWCASE_OUT     where the frames go; unset, the loops still play and the
//                    seam is still checked, and nothing is written
//   SHOWCASE_SCENES  comma-separated names, to re-shoot a few
//
// A screen is shot only when it is named: with SHOWCASE_OUT set and no names,
// the grid is re-shot and the screens are skipped, so the half-size run that
// writes pub's screenshots writes the ten the pubspec lists and nothing more.
// Unshot, a screen still plays, and its seam is still checked.
//
// `tool/showcase.sh` runs this and packs the frames into webp.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'scenes.dart';
import 'screen.dart';

// ignore_for_file: avoid_print

const String _out = String.fromEnvironment('SHOWCASE_OUT');
const String _only = String.fromEnvironment('SHOWCASE_SCENES');

/// The largest channel difference between the first frame of a loop and of
/// the next, in code values, that still reads as one loop: a spring's last
/// residue, not a jump.
const int kSeamTolerance = 3;

void main() {
  setUpAll(loadShowcaseFonts);

  final List<String> names = _only.isEmpty ? const <String>[] : _only.split(',');
  final scenes = <ShowcaseScene>[...kShowcaseScenes, ...kShowcaseScreens];
  for (var i = 0; i < scenes.length; i++) {
    final ShowcaseScene scene = scenes[i];
    final bool named = names.contains(scene.name);
    if (names.isNotEmpty && !named || !scene.onStage && _out.isNotEmpty && !named) {
      continue;
    }
    testWidgets(scene.name, (WidgetTester tester) async {
      tester.view
        ..physicalSize = scene.size * kDpr
        ..devicePixelRatio = kDpr;
      addTearDown(tester.view.reset);
      // Shadows are real here: the knob's is part of what a switch looks like.
      debugDisableShadows = false;
      try {
        Directory? dir;
        if (_out.isNotEmpty) {
          dir = Directory('$_out/${scene.name}');
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
          dir.createSync(recursive: true);
          // A frame's duration in the webp: kept
          // with the frames, so the two cannot disagree about the rate.
          File('${dir.path}/delay_ms').writeAsStringSync('${(1000 / kFps).round()}');
        }
        final LoopRecord r = await recordScene(tester, scene, i, dir);
        print(
          '${scene.name.padRight(12)} ${r.frames} frames, ${r.stillFrames} still, '
          'seam step ${r.seamStep.toStringAsFixed(3)} (largest inside ${r.maxStep.toStringAsFixed(3)}), '
          'repeat max ${r.repeatMax}',
        );
        expect(r.repeatMax, lessThanOrEqualTo(kSeamTolerance), reason: 'the loop does not end where it began');
        expect(r.seamStep, lessThanOrEqualTo(r.maxStep), reason: 'the loop jumps where it wraps');
        expect(r.frames - r.stillFrames, greaterThanOrEqualTo(kFps), reason: 'less than a second of the loop moves');
      } finally {
        debugDisableShadows = true;
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
