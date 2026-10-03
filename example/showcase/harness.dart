import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'backdrop.dart';

/// Frames per second of every loop. The webp carries a whole-millisecond
/// delay, 33, so a loop plays 1% fast — which nobody sees, where 40 ms (an
/// exact 25 fps) is a stutter everybody does.
const int kFps = 30;

/// Screen density of the frames: 2 puts a tile at 800 x 400, about the
/// width a README column is drawn at. pub.dev's screenshots are shot at 1:
/// every file in them ships in the package.
const double kDpr = 0.0 + int.fromEnvironment('SHOWCASE_DPR', defaultValue: 2);

/// One finger on the glass, by frame of the loop.
///
/// [path] maps progress through the stroke, 0 at [down] and 1 at [up], to a
/// global position; it is handed a way to find a widget's rect, so a stroke
/// aims at a control rather than at a coordinate. A stroke does not wrap the
/// loop's end: [up] is before the last frame.
class Stroke {
  const Stroke({required this.down, required this.up, required this.path});

  /// A press that stays where it landed.
  factory Stroke.tap(double down, double up, Finder target, [Alignment at = Alignment.center]) =>
      Stroke(down: down, up: up, path: (double _, Rect Function(Finder) rectOf) => at.withinRect(rectOf(target)));

  /// A press on [target] at [from] that holds still for the first [hold] of
  /// the stroke, travels to [to], and holds again for the last [hold].
  factory Stroke.drag(double down, double up, Finder target, Alignment from, Alignment to, {double hold = 0.2}) =>
      Stroke(
        down: down,
        up: up,
        path: (double u, Rect Function(Finder) rectOf) => Alignment.lerp(
          from,
          to,
          Interval(hold, 1 - hold, curve: Curves.easeInOutCubic).transform(u),
        )!.withinRect(rectOf(target)),
      );

  /// Seconds into the loop.
  final double down;
  final double up;

  final Offset Function(double u, Rect Function(Finder target) rectOf) path;
}

/// A loop: what is on the tile, and the fingers that drive it.
class ShowcaseScene {
  const ShowcaseScene({
    required this.name,
    required this.word,
    required this.caption,
    required this.builder,
    this.strokes = const <Stroke>[],
    this.seconds = 4,
  });

  /// The file the loop is written to, `<name>.webp`.
  final String name;

  /// The anaglyph word in the backdrop.
  final String word;

  /// The component, written into the tile's corner so the grid reads
  /// without the text around it.
  final String caption;

  /// The glass, given the loop's phase, 0 to 1.
  final Widget Function(BuildContext context, ValueListenable<double> phase) builder;

  final List<Stroke> strokes;
  final double seconds;

  int get frames => (seconds * kFps).round();
}

/// The tile around the navigator: backdrop, caption, and one host over both
/// and over every route — the app's `builder:`, as the example's is, so a
/// dialog or a menu built in the navigator's overlay is glass the host sees.
class ShowcaseTile extends StatelessWidget {
  const ShowcaseTile({required this.scene, required this.index, required this.child, super.key});

  final ShowcaseScene scene;
  final int index;

  /// The navigator.
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassHost(
    // The frames are drawn by flutter_tester on the CPU; naming the
    // hardware only attaches prices, and these frames are not priced.
    hardware: GlassHardware.appleMetal,
    // The base colour, not `richBackdrop`: the fields are bright, but the
    // labels here are short and large, and a floor for the worst case would
    // dim every panel to grey — which is what the glass is not.
    backdrop: kShowcaseBase,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: ShowcaseBackdrop(index: index, word: scene.word),
        ),
        Positioned(
          left: 10,
          bottom: 7,
          // Replaces, not merges: the app's ambient style is the debug
          // "no Material here" one, underlined in yellow.
          child: DefaultTextStyle(
            style: const TextStyle(),
            child: Text(
              scene.caption,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: Color(0xB3FFFFFF),
              ),
            ),
          ),
        ),
        // A route that brings no `Material` — a dialog's — would otherwise
        // write in that underlined debug style too.
        Positioned.fill(
          child: DefaultTextStyle(style: Theme.of(context).textTheme.bodyMedium!, child: child),
        ),
      ],
    ),
  );
}

/// Loads Roboto and the Material icons out of the SDK's own cache.
///
/// `flutter_tester` ships no fonts and draws every glyph as a filled box; a
/// README of boxes is worse than none, so a missing directory throws.
Future<void> loadShowcaseFonts() async {
  final Directory dir = _materialFontsDir();
  Future<ByteData> read(String name) async => ByteData.sublistView(File('${dir.path}/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final String face in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    roboto.addFont(read(face));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

Directory _materialFontsDir() {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    // flutter_tester lives at bin/cache/artifacts/engine/<platform>/.
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  ];
  for (final String path in candidates) {
    if (File('$path/Roboto-Regular.ttf').existsSync()) {
      return Directory(path);
    }
  }
  throw StateError('no material_fonts directory (tried: ${candidates.join(', ')})');
}

/// What [recordScene] measured about the loop it wrote.
class LoopRecord {
  const LoopRecord({
    required this.frames,
    required this.repeatMax,
    required this.seamStep,
    required this.maxStep,
    required this.stillFrames,
  });

  final int frames;

  /// The frame after the last against the first, largest channel difference
  /// in code values: whether the state the loop ends in is the state it
  /// started from. Catches a stroke that leaves a control changed and an
  /// animation still running into the next loop — but not a phase function
  /// that is not periodic, which is equal here by construction (phase 0
  /// both times); that is [seamStep]'s.
  final int repeatMax;

  /// The jump a viewer sees where the loop wraps — the last frame to the
  /// first — as a mean channel difference, against [maxStep], the largest
  /// step between two neighbouring frames inside the loop. A seam no larger
  /// than the loop's own largest step is not a seam.
  final double seamStep;
  final double maxStep;

  /// Frames identical to the one before — a loop that hardly moves is a
  /// scene whose driver did not reach the glass.
  final int stillFrames;
}

double _meanStep(Uint8List a, Uint8List b) {
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

/// Plays [scene] for one loop to settle, then records the next one into
/// [outDir] as `0000.png`…, with `rects` naming, line by line, what changed
/// in each over the one before — and
/// renders one frame more, which is the first frame of the loop after, to
/// measure the seam against.
///
/// The settling loop is what makes a loop seamless rather than hopeful: every
/// animation that outlives a stroke — a spring's tail, a wave still
/// spreading — has carried over into the recorded loop exactly as it carries
/// out of it.
Future<LoopRecord> recordScene(WidgetTester tester, ShowcaseScene scene, int index, Directory? outDir) async {
  final phase = ValueNotifier<double>(0);
  final shot = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, fontFamily: 'Roboto'),
      color: kShowcaseBase,
      builder: (BuildContext context, Widget? navigator) => RepaintBoundary(
        key: shot,
        child: ShowcaseTile(scene: scene, index: index, child: navigator!),
      ),
      home: Material(
        type: MaterialType.transparency,
        child: Builder(builder: (BuildContext context) => scene.builder(context, phase)),
      ),
    ),
  );

  final int n = scene.frames;
  final gestures = <int, TestGesture>{};
  Rect rectOf(Finder target) => tester.getRect(target);
  Duration at(int frame) => Duration(microseconds: (frame * 1e6 / kFps).round());

  Uint8List? first;
  Uint8List? previous;
  var still = 0;
  var repeatMax = 0;
  var seamStep = 0.0;
  var maxStep = 0.0;
  final rects = StringBuffer();

  for (var frame = 0; frame <= 2 * n; frame++) {
    final int f = frame % n;
    phase.value = f / n;
    for (var s = 0; s < scene.strokes.length; s++) {
      final Stroke stroke = scene.strokes[s];
      final int down = (stroke.down * kFps).round();
      final int up = (stroke.up * kFps).round();
      assert(down < up && up < n, '${scene.name}: stroke $s does not fit in the loop');
      if (f < down || f > up) {
        continue;
      }
      final Offset p = stroke.path((f - down) / (up - down), rectOf);
      if (f == down) {
        final TestGesture g = await tester.createGesture(pointer: 10 + s);
        await g.down(p, timeStamp: at(frame));
        gestures[s] = g;
      } else {
        await gestures[s]!.moveTo(p, timeStamp: at(frame));
        if (f == up) {
          await gestures.remove(s)!.up(timeStamp: at(frame));
        }
      }
    }
    await tester.pump(at(frame + 1) - at(frame));
    expect(tester.takeException(), isNull, reason: '${scene.name}, frame $frame');

    if (frame < n) {
      continue;
    }
    final bool last = frame == 2 * n;
    final (Uint8List rgba, Uint8List? png) = await _grab(tester, shot, png: outDir != null && !last);
    if (frame == n) {
      first = rgba;
    }
    if (last) {
      seamStep = _meanStep(previous!, first!);
      for (var i = 0; i < rgba.length; i++) {
        final int d = (rgba[i] - first[i]).abs();
        if (d > repeatMax) {
          repeatMax = d;
        }
      }
    } else {
      if (previous != null) {
        final double step = _meanStep(previous, rgba);
        if (step == 0) {
          still++;
        }
        if (step > maxStep) {
          maxStep = step;
        }
      }
      if (outDir != null) {
        // The packer encodes only this rect over the frame before. Found
        // exactly, not within a tolerance: libwebp's own sub-frame search
        // skips pixels that moved less than ~4 code values at q80, so a
        // slow fade — a dialog's barrier — is never written, and the error
        // piles up frame after frame and stays after the fade has ended.
        final (int, int, int, int)? r = previous == null
            ? (0, 0, _width, rgba.length ~/ 4 ~/ _width)
            : _changedRect(previous, rgba);
        final String name = (frame - n).toString().padLeft(4, '0');
        rects.writeln(r == null ? '$name -' : '$name ${r.$1} ${r.$2} ${r.$3} ${r.$4}');
        // Every frame, still ones too: a video wants them all.
        File('${outDir.path}/$name.png').writeAsBytesSync(png!);
      }
      previous = rgba;
    }
  }
  phase.dispose();
  if (outDir != null) {
    File('${outDir.path}/rects').writeAsStringSync(rects.toString());
  }
  return LoopRecord(frames: n, repeatMax: repeatMax, seamStep: seamStep, maxStep: maxStep, stillFrames: still);
}

int get _width => (kTile.width * kDpr).round();

/// The smallest rect holding every pixel that differs between [a] and [b],
/// as x, y, width, height in physical pixels, or null if none does. The
/// origin is rounded down to even: a webp frame's offset is stored halved.
(int, int, int, int)? _changedRect(Uint8List a, Uint8List b) {
  final int w = _width;
  var x0 = w, y0 = -1, x1 = -1, y1 = -1;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) {
      final int p = i ~/ 4, x = p % w, y = p ~/ w;
      if (y0 < 0) {
        y0 = y;
      }
      y1 = y;
      if (x < x0) {
        x0 = x;
      }
      if (x > x1) {
        x1 = x;
      }
    }
  }
  if (y0 < 0) {
    return null;
  }
  x0 -= x0 % 2;
  y0 -= y0 % 2;
  return (x0, y0, x1 + 1 - x0, y1 + 1 - y0);
}

/// The painted frame as raw RGBA, and as a PNG when asked.
Future<(Uint8List, Uint8List?)> _grab(WidgetTester tester, GlobalKey shot, {required bool png}) async {
  final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // `layer.toImageSync` rather than `toImage`: the host publishes a proxy
  // after every frame that captured, which leaves the tree dirty, and
  // `toImage` asserts it is not. The layer holds the frame that was painted.
  // ignore: invalid_use_of_protected_member
  final ui.Image image = (boundary.layer! as OffsetLayer).toImageSync(Offset.zero & kTile, pixelRatio: kDpr);
  late Uint8List rgba;
  Uint8List? encoded;
  await tester.runAsync(() async {
    rgba = (await image.toByteData())!.buffer.asUint8List();
    if (png) {
      encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    }
  });
  image.dispose();
  return (rgba, encoded);
}
