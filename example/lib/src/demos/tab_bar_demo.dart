import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A floating tab bar at the bottom of a small "app" whose page changes with
/// the tab and scrolls under it, one of its tabs drawn with a badge by
/// `iconBuilder`; the bar can collapse on a scroll down and carry an
/// accessory.
class TabBarDemo extends StatefulWidget {
  const TabBarDemo({super.key});

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

/// The tabs, and what each page says.
const List<(GlassTabItem, String)> _kTabs = <(GlassTabItem, String)>[
  (GlassTabItem(icon: SFIcons.sf_house_fill, label: 'Home'), 'Good morning'),
  (GlassTabItem(icon: SFIcons.sf_magnifyingglass, label: 'Search'), 'Find anything'),
  (GlassTabItem(icon: SFIcons.sf_music_note_list, label: 'Library'), '128 albums'),
  (GlassTabItem(icon: SFIcons.sf_heart_fill, label: 'Saved'), '42 songs you love'),
  (GlassTabItem(icon: SFIcons.sf_person_fill, label: 'Profile'), 'Signed in'),
];

/// The "Saved" tab with a badge: drawn by `iconBuilder`, in the colour and
/// size the bar resolved for the item.
Widget _savedWithBadge(BuildContext context, GlassTabItemLook look) => GlassBadge(
  count: 3,
  semanticLabel: '3 new',
  child: SiteIcon(SFIcons.sf_heart_fill, color: look.color, size: look.iconSize),
);

const GlassTabItem _kSavedWithBadge = GlassTabItem(label: 'Saved', iconBuilder: _savedWithBadge);

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
  bool _badge = true;
  bool _minimize = true;
  bool _accessory = true;

  void _setCount(int count) => setState(() {
    _count = count;
    _tab = _tab.clamp(0, count - 1);
  });

  @override
  Widget build(BuildContext context) {
    final (GlassTabItem item, String line) = _kTabs[_tab];
    return DemoStage(
      height: 440,
      background: GridBackdrop(hue: _tab * 70.0),
      hint: _minimize
          ? 'Scroll the page down: the bar collapses to the selected tab, and the accessory moves beside it. '
                'Scroll up, or tap the circle, to bring it back. Press and hold the selected tab to drag the drop.'
          : 'Tap a tab, or press and hold the selected one and drag the drop along the bar. '
                'The badge on Saved is a GlassBadge in an iconBuilder, drawn in the colour the bar gives the tab.',
      knobs: <Widget>[
        KnobChoice<int>(label: 'Tabs', values: const <int>[3, 4, 5], selected: _count, onChanged: _setCount),
        KnobChoice<String>(
          label: 'Active colour',
          values: _kAccents.keys.toList(),
          selected: _accent,
          onChanged: (String a) => setState(() => _accent = a),
        ),
        KnobSwitch(label: 'Badge', value: _badge, onChanged: (bool v) => setState(() => _badge = v)),
        KnobSwitch(label: 'Collapse on scroll', value: _minimize, onChanged: (bool v) => setState(() => _minimize = v)),
        KnobSwitch(label: 'Accessory', value: _accessory, onChanged: (bool v) => setState(() => _accessory = v)),
        KnobSlider(
          label: 'Zoom',
          value: _zoom,
          min: 1,
          max: 1.5,
          width: 140,
          onChanged: (double v) => setState(() => _zoom = v),
        ),
      ],
      // Above the page and the bar both: the page's scrolls reach it, and the
      // bar reads it.
      child: GlassTabBarMinimizer(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ListView(
                // Each tab its own page, from its top.
                key: ValueKey<int>(_tab),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 150),
                children: <Widget>[
                  SiteIcon(item.icon, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  for (var i = 1; i <= 12; i++) _Row('${item.label} $i'),
                ],
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
                      items: <GlassTabItem>[
                        for (final (GlassTabItem tab, _) in _kTabs.take(_count))
                          _badge && tab.label == 'Saved' ? _kSavedWithBadge : tab,
                      ],
                      selectedIndex: _tab,
                      activeColor: _kAccents[_accent]!,
                      dropZoom: _zoom,
                      onSelected: (int i) => setState(() => _tab = i),
                      minimizeBehavior: _minimize
                          ? GlassTabBarMinimizeBehavior.onScrollDown
                          : GlassTabBarMinimizeBehavior.never,
                      bottomAccessory: _accessory
                          ? const Row(
                              children: <Widget>[
                                SiteIcon(SFIcons.sf_music_note, size: 18),
                                SizedBox(width: 10),
                                Expanded(child: Text('Heat Waves', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                SiteIcon(SFIcons.sf_pause_fill, size: 18),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of the page: plain content under the glass, not glass.
class _Row extends StatelessWidget {
  const _Row(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.centerLeft,
    decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x66000000)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
  );
}
