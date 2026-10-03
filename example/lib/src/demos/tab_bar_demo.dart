import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A floating tab bar at the bottom of a small "app" whose page changes with
/// the tab.
class TabBarDemo extends StatefulWidget {
  const TabBarDemo({super.key});

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

/// The tabs, and what each page says.
const List<(GlassTabItem, String)> _kTabs = <(GlassTabItem, String)>[
  (GlassTabItem(icon: Icons.home_rounded, label: 'Home'), 'Good morning'),
  (GlassTabItem(icon: Icons.search_rounded, label: 'Search'), 'Find anything'),
  (GlassTabItem(icon: Icons.library_music_rounded, label: 'Library'), '128 albums'),
  (GlassTabItem(icon: Icons.favorite_rounded, label: 'Saved'), '42 songs you love'),
  (GlassTabItem(icon: Icons.person_rounded, label: 'Profile'), 'Signed in'),
];

const Map<String, Color> _kAccents = <String, Color>{
  'Blue': Color(0xFF0A84FF),
  'Pink': Color(0xFFFF375F),
  'Green': Color(0xFF30D158),
};

class _TabBarDemoState extends State<TabBarDemo> {
  int _count = 4;
  int _tab = 0;
  double _zoom = kGlassTabDropZoom;
  String _accent = 'Blue';

  void _setCount(int count) => setState(() {
    _count = count;
    _tab = _tab.clamp(0, count - 1);
  });

  @override
  Widget build(BuildContext context) {
    final (GlassTabItem item, String line) = _kTabs[_tab];
    return DemoStage(
      height: 400,
      background: GridBackdrop(hue: _tab * 70.0),
      hint: 'Tap a tab, or press and hold the selected one and drag the drop along the bar.',
      knobs: <Widget>[
        KnobChoice<int>(label: 'Tabs', values: const <int>[3, 4, 5], selected: _count, onChanged: _setCount),
        KnobChoice<String>(
          label: 'Active colour',
          values: _kAccents.keys.toList(),
          selected: _accent,
          onChanged: (String a) => setState(() => _accent = a),
        ),
        KnobSlider(
          label: 'Zoom',
          value: _zoom,
          min: 1,
          max: 1.5,
          width: 140,
          onChanged: (double v) => setState(() => _zoom = v),
        ),
      ],
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            bottom: 88,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(item.icon, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    item.label,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(line, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: GlassTabBar(
                    items: <GlassTabItem>[for (final (GlassTabItem tab, _) in _kTabs.take(_count)) tab],
                    selectedIndex: _tab,
                    activeColor: _kAccents[_accent]!,
                    dropZoom: _zoom,
                    onSelected: (int i) => setState(() => _tab = i),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
