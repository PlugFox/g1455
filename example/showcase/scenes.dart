import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'backdrop.dart';
import 'harness.dart';

/// The README's grid, left to right and top to bottom, [kGridColumns] to a
/// row: each scene is cut from the backdrop at its own index, so reordering
/// moves the seams, and the count stays a multiple of the columns.
///
/// Ten at most: that is as many screenshots as pub.dev shows, and the
/// pubspec lists every one.
final List<ShowcaseScene> kShowcaseScenes = <ShowcaseScene>[
  const ShowcaseScene(name: 'group', word: 'GLASS', caption: 'GlassGroup', builder: _blobs),
  const ShowcaseScene(name: 'finishes', word: 'FINISH', caption: 'GlassFinish', builder: _finishes),
  ShowcaseScene(
    name: 'ripple',
    word: 'RIPPLE',
    caption: 'GlassRipple',
    builder: _ripple,
    strokes: <Stroke>[
      Stroke.tap(0.15, 0.45, _rippleTarget, const Alignment(-0.55, -0.2)),
      Stroke.tap(0.9, 1.15, _rippleTarget, const Alignment(0.6, 0.3)),
      Stroke.drag(1.6, 2.5, _rippleTarget, const Alignment(-0.7, 0.4), const Alignment(0.5, -0.4), hold: 0.1),
    ],
  ),
  const ShowcaseScene(name: 'materialize', word: 'APPEAR', caption: 'GlassSurface.materialize', builder: _materialize),
  ShowcaseScene(
    name: 'switch',
    word: 'SWITCH',
    caption: 'GlassSwitch',
    builder: (BuildContext context, ValueListenable<double> _) => const _Switches(),
    strokes: <Stroke>[
      // On to off by dragging the knob, past the track's end as a thumb does.
      Stroke.drag(0.2, 1.0, _switch(0), const Alignment(0.35, 0), const Alignment(-1.4, 0)),
      Stroke.tap(1.1, 1.45, _switch(1)),
      Stroke.drag(1.8, 2.6, _switch(0), const Alignment(-0.35, 0), const Alignment(1.4, 0)),
      Stroke.tap(2.75, 3.1, _switch(1)),
      Stroke.tap(1.5, 1.75, _switch(2)),
      Stroke.tap(3.2, 3.45, _switch(2)),
    ],
  ),
  ShowcaseScene(
    name: 'slider',
    word: 'SLIDER',
    caption: 'GlassSlider',
    builder: (BuildContext context, ValueListenable<double> _) => const _Sliders(),
    strokes: <Stroke>[
      _slide(0.15, 1.5, 0, 0.25, 0.85),
      _slide(1.25, 2.55, 1, 0.65, 0.2),
      _slide(2.45, 3.7, 0, 0.85, 0.25),
      _slide(2.6, 3.75, 1, 0.2, 0.65),
    ],
  ),
  ShowcaseScene(
    name: 'tab_bar',
    word: 'TABS',
    caption: 'GlassTabBar',
    builder: (BuildContext context, ValueListenable<double> _) => const _Tabs(),
    strokes: <Stroke>[
      Stroke.drag(0.2, 1.35, _tabs, _tab(0, 4), _tab(2, 4), hold: 0.25),
      Stroke.tap(1.75, 2.0, _tabs, _tab(3, 4)),
      Stroke.drag(2.35, 3.5, _tabs, _tab(3, 4), _tab(0, 4), hold: 0.25),
    ],
  ),
  ShowcaseScene(
    name: 'segmented',
    word: 'SEGMENTS',
    caption: 'GlassSegmentedControl',
    builder: (BuildContext context, ValueListenable<double> _) => const _Segments(),
    strokes: <Stroke>[
      Stroke.tap(0.2, 0.45, _segments, _tab(1, 3)),
      Stroke.drag(0.9, 2.0, _segments, _tab(1, 3), _tab(2, 3), hold: 0.25),
      Stroke.drag(2.4, 3.5, _segments, _tab(2, 3), _tab(0, 3), hold: 0.25),
    ],
  ),
  ShowcaseScene(
    name: 'menu',
    word: 'MENU',
    caption: 'GlassMenuAnchor · GlassButtonGroup',
    builder: (BuildContext context, ValueListenable<double> _) => const _MenuDemo(),
    strokes: <Stroke>[
      Stroke.tap(0.2, 0.4, find.byKey(_menuButton)),
      Stroke.tap(1.2, 1.4, find.text('Date')),
      Stroke.tap(1.7, 1.95, find.byKey(_toolbar), const Alignment(-2 / 3, 0)),
      Stroke.tap(2.2, 2.4, find.byKey(_menuButton)),
      Stroke.tap(3.1, 3.3, find.text('Name')),
      Stroke.tap(3.5, 3.75, find.byKey(_toolbar), const Alignment(2 / 3, 0)),
    ],
  ),
  ShowcaseScene(
    name: 'alert',
    word: 'ALERT',
    caption: 'showGlassDialog · GlassAlert',
    builder: (BuildContext context, ValueListenable<double> _) => const _AlertDemo(),
    seconds: 3,
    strokes: <Stroke>[Stroke.tap(0.2, 0.45, find.byKey(_alertButton)), Stroke.tap(1.8, 2.1, find.text('Cancel'))],
  ),
];

// ---------------------------------------------------------------------------
// Blend group.

/// Blobs on Lissajous orbits that fuse into one silhouette where they meet.
Widget _blobs(BuildContext context, ValueListenable<double> phase) => GlassTravel(
  child: RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: phase,
      builder: (BuildContext context, double t, Widget? _) {
        final double a = t * 2 * math.pi;
        final Offset centre = kTile.center(Offset.zero);
        return GlassGroup(
          spacing: 36,
          finish: GlassFinish.clear,
          labelled: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _disc(centre + Offset(math.cos(a) * 120, math.sin(2 * a) * 30), 44),
              _disc(centre + Offset(math.cos(a + math.pi) * 120, math.sin(2 * a + math.pi) * 30), 36),
              _disc(centre + Offset(math.sin(a) * 20, math.cos(a) * 36), 30),
            ],
          ),
        );
      },
    ),
  ),
);

Widget _disc(Offset c, double r) => Positioned(
  left: c.dx - r,
  top: c.dy - r,
  width: 2 * r,
  height: 2 * r,
  child: const GlassSurface(borderRadius: kGlassCapsule, labelled: false),
);

// ---------------------------------------------------------------------------
// Finishes.

/// The three finishes side by side, riding a wave over the word.
Widget _finishes(BuildContext context, ValueListenable<double> phase) {
  const List<(GlassFinish, String)> finishes = <(GlassFinish, String)>[
    (GlassFinish.regularDark, 'Regular'),
    (GlassFinish.clear, 'Clear'),
    (GlassFinish.frosted, 'Frosted'),
  ];
  return GlassTravel(
    child: RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: phase,
        builder: (BuildContext context, double t, Widget? _) => Stack(
          children: <Widget>[
            for (var i = 0; i < finishes.length; i++)
              Positioned(
                left: 22 + i * 122.0,
                top: 50 + math.sin(2 * math.pi * (t - i / 6)) * 10,
                width: 112,
                height: 112,
                child: GlassCard(
                  finish: finishes[i].$1,
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  // Under the word rather than over it: a clear glass over a
                  // white letter is the finish working, and no place for a label.
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(finishes[i].$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ripple.

final Finder _rippleTarget = find.byKey(const ValueKey<String>('ripple'));

Widget _ripple(BuildContext context, ValueListenable<double> phase) => const Center(
  child: SizedBox(
    key: ValueKey<String>('ripple'),
    width: 380,
    height: 160,
    child: GlassSurface(
      borderRadius: BorderRadius.all(Radius.circular(36)),
      finish: GlassFinish.clear,
      labelled: false,
      ripple: GlassRipple(viscosity: 0.3, amplitude: 14, width: 16, speed: 300, light: 0.2),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Materialize.

/// How far a panel has materialized at phase [t], if it starts [delay] into
/// the loop: in, held, out, and gone at the seam.
double _arrival(double t, double delay) {
  double ramp(double from, double to) => Curves.easeInOut.transform(((t - from) / (to - from)).clamp(0.0, 1.0));
  return ramp(delay, delay + 0.22) - ramp(delay + 0.5, delay + 0.72);
}

/// A bar and two buttons arriving one after another: the bend first, then
/// the blur, the tint last, and leaving in the reverse order.
Widget _materialize(BuildContext context, ValueListenable<double> phase) => ValueListenableBuilder<double>(
  valueListenable: phase,
  builder: (BuildContext context, double t, Widget? _) {
    Widget panel(double delay, double width, Widget child) => SizedBox(
      width: width,
      height: 48,
      child: GlassSurface(
        borderRadius: kGlassCapsule,
        materialize: _arrival(t, delay),
        child: Center(
          child: Opacity(opacity: _arrival(t, delay + 0.06).clamp(0.0, 1.0), child: child),
        ),
      ),
    );
    const TextStyle label = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          panel(
            0.04,
            300,
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.photo_library_outlined, size: 20),
                SizedBox(width: 8),
                Text('Library', style: label),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              panel(0.12, 143, const Text('Edit', style: label)),
              const SizedBox(width: 14),
              panel(0.2, 143, const Text('Share', style: label)),
            ],
          ),
        ],
      ),
    );
  },
);

// ---------------------------------------------------------------------------
// Switches.

Finder _switch(int i) => find.byKey(ValueKey<String>('switch $i'));

class _Switches extends StatefulWidget {
  const _Switches();

  @override
  State<_Switches> createState() => _SwitchesState();
}

class _SwitchesState extends State<_Switches> {
  final List<bool> _on = <bool>[true, false, true];

  static const List<(IconData, String)> _rows = <(IconData, String)>[
    (Icons.wifi, 'Wi-Fi'),
    (Icons.bluetooth, 'Bluetooth'),
    (Icons.dark_mode, 'Dark mode'),
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 250,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < _rows.length; i++)
              Row(
                children: <Widget>[
                  Icon(_rows[i].$1, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_rows[i].$2, style: const TextStyle(fontSize: 15))),
                  GlassSwitch(
                    key: ValueKey<String>('switch $i'),
                    value: _on[i],
                    onChanged: (bool v) => setState(() => _on[i] = v),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sliders.

Finder _slider(int i) => find.byKey(ValueKey<String>('slider $i'));

/// A drag on slider [i] from the knob at [from] to [to], both values: the
/// knob's centre is half a knob in from the ends, as the slider lays it out.
Stroke _slide(double down, double up, int i, double from, double to) => Stroke(
  down: down,
  up: up,
  path: (double u, Rect Function(Finder) rectOf) {
    final Rect r = rectOf(_slider(i));
    const double knob = 38;
    final double v = from + (to - from) * const Interval(0.15, 0.85, curve: Curves.easeInOutCubic).transform(u);
    return Offset(r.left + knob / 2 + v * (r.width - knob), r.center.dy);
  },
);

class _Sliders extends StatefulWidget {
  const _Sliders();

  @override
  State<_Sliders> createState() => _SlidersState();
}

class _SlidersState extends State<_Sliders> {
  final List<double> _value = <double>[0.25, 0.65];

  static const List<(IconData, IconData, Color)> _rows = <(IconData, IconData, Color)>[
    (Icons.volume_mute, Icons.volume_up, Color(0xFF0A84FF)),
    (Icons.brightness_low, Icons.brightness_high, Color(0xFFFF9F0A)),
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 320,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < _rows.length; i++)
              Row(
                children: <Widget>[
                  Icon(_rows[i].$1, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassSlider(
                      key: ValueKey<String>('slider $i'),
                      value: _value[i],
                      activeColor: _rows[i].$3,
                      onChanged: (double v) => setState(() => _value[i] = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(_rows[i].$2, size: 20),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tab bar and segmented control.

final Finder _tabs = find.byType(GlassTabBar);
final Finder _segments = find.byType(GlassSegmentedControl);

/// Item [i] of [count] spread evenly across a control — near enough for a
/// finger, which lands anywhere on an item.
Alignment _tab(int i, int count) => Alignment(-1 + (2 * i + 1) / count, 0);

class _Tabs extends StatefulWidget {
  const _Tabs();

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 340,
      child: GlassTabBar(
        items: const <GlassTabItem>[
          GlassTabItem(icon: Icons.home_rounded, label: 'Home'),
          GlassTabItem(icon: Icons.explore, label: 'Explore'),
          GlassTabItem(icon: Icons.favorite, label: 'Saved'),
          GlassTabItem(icon: Icons.person, label: 'Profile'),
        ],
        selectedIndex: _selected,
        onSelected: (int i) => setState(() => _selected = i),
      ),
    ),
  );
}

class _Segments extends StatefulWidget {
  const _Segments();

  @override
  State<_Segments> createState() => _SegmentsState();
}

class _SegmentsState extends State<_Segments> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 300,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: GlassSegmentedControl(
          segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
          selectedIndex: _selected,
          onSelected: (int i) => setState(() => _selected = i),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Menu and toolbar.

const Key _menuButton = ValueKey<String>('menu button');
const Key _toolbar = ValueKey<String>('toolbar');

class _MenuDemo extends StatelessWidget {
  const _MenuDemo();

  @override
  Widget build(BuildContext context) => Align(
    // High enough that the menu opens downward, over the button, as it does
    // from a toolbar at the top of a screen.
    alignment: const Alignment(0, -0.62),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GlassMenuAnchor(
          items: <GlassMenuItem>[
            GlassMenuItem(label: 'Name', icon: const Icon(Icons.sort_by_alpha, size: 20), onPressed: () {}),
            GlassMenuItem(label: 'Date', icon: const Icon(Icons.schedule, size: 20), onPressed: () {}),
            GlassMenuItem(label: 'Size', icon: const Icon(Icons.straighten, size: 20), onPressed: () {}),
          ],
          builder: (BuildContext context, GlassMenuController menu) => GlassButton(
            key: _menuButton,
            onPressed: menu.open,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(Icons.swap_vert, size: 20), SizedBox(width: 6), Text('Sort')],
            ),
          ),
        ),
        const SizedBox(width: 40),
        GlassButtonGroup(
          key: _toolbar,
          items: <GlassToolbarItem>[
            GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: () {}),
            GlassToolbarItem(icon: const Icon(Icons.favorite_border), label: 'Like', onPressed: () {}),
            GlassToolbarItem(icon: const Icon(Icons.delete_outline), label: 'Delete', onPressed: () {}),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Alert.

const Key _alertButton = ValueKey<String>('alert button');

class _AlertDemo extends StatelessWidget {
  const _AlertDemo();

  @override
  Widget build(BuildContext context) => Center(
    child: GlassButton(
      key: _alertButton,
      onPressed: () => showGlassDialog<void>(
        context: context,
        // Twice the default, so the materializing — blur first, tint last —
        // is frames rather than a cut.
        transitionDuration: const Duration(milliseconds: 500),
        builder: (BuildContext context) => GlassAlert(
          title: const Text('Delete photo?'),
          message: const Text('It stays in Recently Deleted.'),
          actions: <GlassAlertAction>[
            GlassAlertAction(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
            GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('Delete')],
      ),
    ),
  );
}
