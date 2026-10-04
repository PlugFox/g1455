// The README's "Common patterns", one declaration per snippet. The README
// carries each one verbatim, which `test/readme_test.dart` checks, and that
// test also pumps them: what the README shows compiles and runs.

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

class Feed extends StatelessWidget {
  const Feed({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      // A frame the list moves is one capture for every glass on the screen;
      // a frame it rests is none.
      ListView.builder(
        padding: const EdgeInsets.only(top: 96),
        itemCount: 100,
        itemBuilder: (BuildContext context, int i) => ListTile(title: Text('Message $i')),
      ),
      const Positioned(
        top: 0,
        left: 16,
        right: 16,
        child: SafeArea(
          child: GlassBar(child: Text('Inbox')),
        ),
      ),
    ],
  );
}

class Lens extends StatefulWidget {
  const Lens({super.key});

  @override
  State<Lens> createState() => _LensState();
}

class _LensState extends State<Lens> {
  Offset _at = const Offset(100, 100);

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      // What the lens moves over, behind its own boundary: the drag repaints
      // none of it.
      const Positioned.fill(
        child: RepaintBoundary(child: FlutterLogo(style: FlutterLogoStyle.stacked)),
      ),
      // The lens may go anywhere in here, and the host captures all of it
      // once: dragging the lens over still content takes no capture.
      Positioned.fill(
        child: GlassTravel(
          child: RepaintBoundary(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: _at.dx - 48,
                  top: _at.dy - 48,
                  width: 96,
                  height: 96,
                  child: GestureDetector(
                    onPanUpdate: (DragUpdateDetails d) => setState(() => _at += d.delta),
                    child: const GlassSurface(
                      borderRadius: kGlassCapsule,
                      finish: GlassFinish.clear,
                      labelled: false,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class Cards extends StatelessWidget {
  const Cards({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
        children: <Widget>[
          for (int i = 0; i < 20; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(child: Text('Card $i')),
            ),
        ],
      ),
      // The bar is the cards' sibling, not their parent. Without GlassAbove
      // it would show the page with the cards cut out of it; with it, the bar
      // is a level above them and refracts them.
      const Positioned(
        top: 0,
        left: 16,
        right: 16,
        child: SafeArea(
          child: GlassAbove(child: GlassBar(child: Text('Cards'))),
        ),
      ),
    ],
  );
}

// Under `MaterialApp(builder: (context, navigator) => GlassHost(child: navigator!))`:
// the menu and the dialog are built in the navigator's overlay, and only a
// host above the navigator sees the bar they open over.
class NotesBar extends StatelessWidget {
  const NotesBar({super.key});

  @override
  Widget build(BuildContext context) => GlassBar(
    child: Row(
      children: <Widget>[
        const Expanded(child: Text('Notes')),
        GlassMenuAnchor(
          items: <GlassMenuItem>[
            GlassMenuItem(label: 'Delete all', isDestructive: true, onPressed: () => _confirm(context)),
          ],
          builder: (BuildContext context, GlassMenuController menu) => GlassButton(
            onPressed: menu.open,
            semanticLabel: 'More',
            padding: EdgeInsets.zero,
            child: const Icon(Icons.more_horiz),
          ),
        ),
      ],
    ),
  );

  Future<void> _confirm(BuildContext context) => showGlassDialog<void>(
    context: context,
    builder: (BuildContext context) => GlassAlert(
      title: const Text('Delete all notes?'),
      actions: <GlassAlertAction>[
        GlassAlertAction(label: 'Cancel', isDefault: true, onPressed: () => Navigator.pop(context)),
        GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

Widget cheapApp({required bool reduceTransparency, required bool lowEndDevice}) => MaterialApp(
  builder: (BuildContext context, Widget? navigator) => GlassHost(
    backdrop: Colors.white, // what the opaque rung fills to match
    tier: GlassTierPolicy(
      reduceTransparency: reduceTransparency, // read natively by the app
      ceiling: lowEndDevice ? GlassTier.cheap : null, // the app's own benchmark or device table
    ).choose(),
    child: navigator!,
  ),
  home: const Scaffold(body: Feed()),
);
