// D219 — a label changing inside glass repaints the host and changes nothing
// the proxy holds.
//
// `flutter test test/glass_label_repaint_test.dart`
//
// The host asserts that a repaint of its boundary is visible to the layer
// watch, because a repaint mints new pictures and a watch that misses one has a
// hole in its table. The watch excludes the glass — a published proxy repaints
// it by construction — and so the assertion read "painted and nothing outside
// the glass changed" as a hole. It is not one when every new picture is inside
// glass: a bar's label changing with nothing of the boundary's own painted
// outside the bar. The example application did that on its first tap; no scene
// in the corpus ever had, because their glass carried no state.
//
// The assertion now reads a second walk that excludes only the glass *draws*,
// so glass content is watched and the pipeline's own output is not. Not a walk
// that excludes nothing: a draw layer is a type the table does not read, it
// reports a change on every frame, and an assertion reading that could never
// fire while glass was on the screen — the first version of this fix, caught
// by the arms below before it was kept.
//
// Three arms, because the fix is a claim about which of two walks the
// assertion reads, and only a scene where they disagree can say that:
//
//  1. **Inside glass.** The label in a bar changes: the content walk sees it,
//     inside the bar; the walk the oracle reads does not; and the host's
//     assertion — now reading the first — stays quiet. On an idle frame before
//     it the content walk sees nothing, which is what keeps the assertion's
//     teeth.
//  2. **Outside glass, the control.** The same label beside the bar: the
//     excluded walk sees it too, so the quiet of arm 1 is the exclusion and
//     not a blind walk.
//  3. **The old predicate**, painted and the excluded walk quiet, holds in arm
//     1 and not in arm 2 — which is the assertion that fired, and why.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_layer_watch.dart';

// ignore_for_file: avoid_print

class _Scene extends StatefulWidget {
  const _Scene({required this.insideGlass, super.key});

  /// Whether the changing label is inside the bar or painted beside it.
  final bool insideGlass;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  bool on = false;

  void flip() => setState(() => on = !on);

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(on ? 'clear' : 'regularDark');
    return MaterialApp(
      home: GlassHost(
        hardware: GlassHardware.appleMetal,
        backdrop: const Color(0xFF1E2A44),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ListView(
                children: <Widget>[
                  for (var i = 0; i < 12; i++) Container(height: 72, color: Color(0xFF203050 + i * 0x00080604)),
                ],
              ),
            ),
            // Its height left to the label, as a bar's is: a tight box would
            // make it a relayout boundary, the label's change would repaint the
            // bar and never the host's boundary, and no predicate about the
            // host's repaint would be asked at all. The first version of this
            // file had `Positioned.fromRect` here, and a deliberately restored
            // old predicate passed every arm.
            Positioned(
              left: 16,
              top: 24,
              right: 16,
              child: GlassBar(child: widget.insideGlass ? label : const Text('bar')),
            ),
            if (!widget.insideGlass) Positioned(left: 24, top: 300, child: label),
          ],
        ),
      ),
    );
  }
}

/// What the two walks and the host saw across one flip of the label, what the
/// content walk saw on an idle frame before it, and where the bar is.
typedef _Seen = ({
  LayerChange idle,
  LayerChange all,
  LayerChange excluded,
  Object? exception,
  Rect bar,
});

Future<_Seen> _flip(WidgetTester tester, {required bool insideGlass}) async {
  final key = GlobalKey<_SceneState>();
  await tester.pumpWidget(_Scene(key: key, insideGlass: insideGlass));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  // The host's boundary: the first one under it, which is the layer its own
  // watch is handed.
  final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: find.byType(GlassHost), matching: find.byType(RepaintBoundary)).first,
  );
  final RenderGlassSurface bar = tester.renderObject<RenderGlassSurface>(
    find.descendant(of: find.byType(GlassBar), matching: find.byType(GlassSurface)),
  );
  final all = ProxyLayerWatch();
  final excluded = ProxyLayerWatch();
  // ignore: invalid_use_of_protected_member
  ContainerLayer root() => boundary.layer!;
  Set<Layer> glass() => <Layer>{bar.compositedLayer!};
  Set<Layer> draws() => <Layer>{bar.drawLayer!};
  all.changeSince(root(), exclude: draws());
  excluded.changeSince(root(), exclude: glass());
  await tester.pump();
  final LayerChange idle = all.changeSince(root(), exclude: draws());
  excluded.changeSince(root(), exclude: glass());

  key.currentState!.flip();
  await tester.pump();
  final LayerChange content = all.changeSince(root(), exclude: draws());
  final LayerChange proxy = excluded.changeSince(root(), exclude: glass());
  // The host's own walk runs in a post-frame callback, and the first version of
  // this file read its exception after one pump — where a deliberately restored
  // old predicate passed all three arms. A few more frames and it fires.
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return (
    idle: idle,
    all: content,
    excluded: proxy,
    exception: tester.takeException(),
    bar: tester.getRect(find.byType(GlassBar)),
  );
}

void main() {
  testWidgets('a label changing inside glass is seen by the content walk alone, and is no hole', (
    WidgetTester tester,
  ) async {
    final _Seen seen = await _flip(tester, insideGlass: true);
    print(
      'inside glass: idle ${seen.idle}, content ${seen.all}, excluded ${seen.excluded}, '
      'host ${seen.exception}',
    );
    expect(seen.idle.changed, isFalse, reason: 'the content walk changes on its own; no teeth');
    expect(seen.all.changed, isTrue, reason: 'the label repainted and no walk saw it');
    expect(
      seen.bar.inflate(1).contains(seen.all.region!.topLeft) &&
          seen.bar.inflate(1).contains(seen.all.region!.bottomRight),
      isTrue,
      reason: 'the change is not confined to the bar: ${seen.all.region}',
    );
    expect(seen.excluded.changed, isFalse, reason: 'the change reached the proxy\'s walk');
    expect(seen.exception, isNull, reason: 'the host called a change inside glass a hole');
  });

  testWidgets('the control: beside the glass, the excluded walk sees it too', (
    WidgetTester tester,
  ) async {
    final _Seen seen = await _flip(tester, insideGlass: false);
    print(
      'outside glass: idle ${seen.idle}, content ${seen.all}, excluded ${seen.excluded}, '
      'host ${seen.exception}',
    );
    expect(seen.idle.changed, isFalse);
    expect(seen.all.changed, isTrue);
    expect(seen.excluded.changed, isTrue, reason: 'the excluded walk is blind, not excluding');
    expect(seen.exception, isNull);
  });

  testWidgets('and the old predicate fires on the first scene and not on the second', (
    WidgetTester tester,
  ) async {
    // "Painted, and the excluded walk saw nothing" — what the assertion read
    // before D219. Both scenes repaint the host's boundary (the label has no
    // boundary of its own), so the predicate is the excluded walk's silence.
    final bool inside = !(await _flip(tester, insideGlass: true)).excluded.changed;
    final bool outside = !(await _flip(tester, insideGlass: false)).excluded.changed;
    print('old predicate: inside glass $inside, outside glass $outside');
    expect(inside, isTrue, reason: 'the scene no longer separates the two predicates');
    expect(outside, isFalse);
  });
}
