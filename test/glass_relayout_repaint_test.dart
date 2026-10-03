// A relayout that lands on the same geometry repaints the host's boundary, and
// when that boundary draws nothing of its own it mints no picture: a still
// screen, not a hole in the layer watch.
//
// `flutter test test/glass_relayout_repaint_test.dart`
//
// `RenderObject.layout` marks paint unconditionally (`object.dart:2939`), so an
// application's `setState` above a `Scaffold` that re-runs its layout repaints
// whatever boundary the laid-out nodes paint into — the host's. The host
// asserted that every repaint of its boundary is visible to the layer watch,
// because a repaint mints a `ui.Picture`. That holds only for a boundary that
// draws something itself; when every pixel under it belongs to a nested
// boundary (list items, a control's track, the glass), the repaint re-appends
// retained layers and the watch is right to see nothing. The example
// application's slider tripped it on its first press.
//
// Two arms, because the guard is a claim about whose pictures a repaint mints:
//
//  1. **Nothing of its own.** Every pixel under the host is inside a nested
//     boundary; a forced relayout repaints the host (the capture it causes is
//     the trace), the content walk is quiet, and the host does not throw.
//  2. **A picture of its own, the control.** The same relayout over a host that
//     paints a strip itself: the repaint mints a picture, the watch sees it —
//     so the guard in arm 1 is not hiding a frame the watch would have read.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/proxy/proxy_layer_watch.dart';

// ignore_for_file: avoid_print

/// Lays its child out again whenever it is rebuilt, at the same geometry.
class _Relayout extends SingleChildRenderObjectWidget {
  const _Relayout({required this.generation, required Widget super.child});

  final int generation;

  @override
  _RenderRelayout createRenderObject(BuildContext context) => _RenderRelayout(generation);

  @override
  void updateRenderObject(BuildContext context, _RenderRelayout renderObject) {
    renderObject.generation = generation;
  }
}

class _RenderRelayout extends RenderProxyBox {
  _RenderRelayout(this._generation);

  int _generation;
  set generation(int value) {
    if (value != _generation) {
      _generation = value;
      markNeedsLayout();
    }
  }
}

class _Scene extends StatefulWidget {
  const _Scene({required this.ownPicture, required this.hostKey, super.key});

  final bool ownPicture;
  final GlobalKey hostKey;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  int generation = 0;

  void poke() => setState(() => generation++);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: GlassHost(
      key: widget.hostKey,
      hardware: GlassHardware.appleMetal,
      backdrop: const Color(0xFF1E2A44),
      child: _Relayout(
        generation: generation,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ListView(
                children: <Widget>[
                  for (var i = 0; i < 12; i++) Container(height: 72, color: Color(0xFF203050 + i * 0x00080604)),
                ],
              ),
            ),
            if (widget.ownPicture)
              const Positioned(
                left: 0,
                right: 0,
                top: 200,
                height: 40,
                child: ColoredBox(color: Color(0xFF805020)),
              ),
            const Positioned(left: 16, top: 24, right: 16, child: GlassBar(child: Text('bar'))),
          ],
        ),
      ),
    ),
  );
}

typedef _Seen = ({int idleRecorded, int pokeRecorded, LayerChange content, Object? exception});

Future<_Seen> _poke(WidgetTester tester, {required bool ownPicture}) async {
  final scene = GlobalKey<_SceneState>();
  final host = GlobalKey();
  await tester.pumpWidget(_Scene(key: scene, hostKey: host, ownPicture: ownPicture));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: find.byType(GlassHost), matching: find.byType(RepaintBoundary)).first,
  );
  final RenderGlassSurface bar = tester.renderObject<RenderGlassSurface>(
    find.descendant(of: find.byType(GlassBar), matching: find.byType(GlassSurface)),
  );
  final watch = ProxyLayerWatch();
  // ignore: invalid_use_of_protected_member
  ContainerLayer root() => boundary.layer!;
  watch.changeSince(root(), exclude: <Layer>{bar.drawLayer!});
  int recorded() => (host.currentState! as dynamic).recorded as int;

  final int before = recorded();
  await tester.pump();
  final int idle = recorded() - before;

  scene.currentState!.poke();
  await tester.pump();
  final LayerChange content = watch.changeSince(root(), exclude: <Layer>{bar.drawLayer!});
  final int poked = recorded() - before - idle;
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return (
    idleRecorded: idle,
    pokeRecorded: poked,
    content: content,
    exception: tester.takeException(),
  );
}

void main() {
  testWidgets('a relayout over a host that draws nothing itself is a still screen, not a hole', (
    WidgetTester tester,
  ) async {
    final _Seen seen = await _poke(tester, ownPicture: false);
    print('nothing of its own: $seen');
    expect(seen.idleRecorded, 0, reason: 'an idle frame was recorded; nothing is held');
    expect(seen.pokeRecorded, 1, reason: 'the relayout did not repaint the host');
    expect(seen.content.changed, isFalse, reason: 'the repaint minted something after all');
    expect(seen.exception, isNull, reason: 'the host called a picture-less repaint a hole');
  });

  testWidgets('the control: with a picture of its own, the same relayout is seen', (
    WidgetTester tester,
  ) async {
    final _Seen seen = await _poke(tester, ownPicture: true);
    print('a picture of its own: $seen');
    expect(seen.idleRecorded, 0);
    expect(seen.pokeRecorded, 1);
    expect(seen.content.changed, isTrue, reason: 'the watch missed a minted picture');
    expect(seen.exception, isNull);
  });
}
