import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A small screen built with [GlassScaffold]: a list scrolling under a top
/// bar in a scroll edge, a tab bar and a floating "+" — each part on a knob.
///
/// The site's host is above, so the scaffold mounts none of its own.
class ScaffoldDemo extends StatefulWidget {
  const ScaffoldDemo({super.key});

  @override
  State<ScaffoldDemo> createState() => _ScaffoldDemoState();
}

/// The scroll edge under the top bar, or none.
enum _Edge { soft, hard, none }

const List<GlassTabItem> _kTabs = <GlassTabItem>[
  GlassTabItem(icon: Icons.photo_library_rounded, label: 'Library'),
  GlassTabItem(icon: Icons.favorite_rounded, label: 'Saved'),
  GlassTabItem(icon: Icons.search_rounded, label: 'Search'),
];

class _ScaffoldDemoState extends State<ScaffoldDemo> {
  _Edge _edge = _Edge.soft;
  bool _bottomBar = true;
  bool _action = true;
  int _tab = 0;
  int _rows = 24;

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 460,
    background: const ColoredBox(color: Color(0xFF0B0E16)),
    knobs: <Widget>[
      KnobChoice<_Edge>(
        label: 'Scroll edge',
        values: _Edge.values,
        selected: _edge,
        labelOf: (_Edge e) => e.name,
        onChanged: (_Edge e) => setState(() => _edge = e),
      ),
      KnobSwitch(label: 'Bottom bar', value: _bottomBar, onChanged: (bool v) => setState(() => _bottomBar = v)),
      KnobSwitch(label: 'Floating action', value: _action, onChanged: (bool v) => setState(() => _action = v)),
    ],
    hint:
        'Scroll the list: it starts below the top bar, ends above the tab bar and scrolls under both. '
        'The “+” adds a row.',
    // The stage is not a screen: no status bar or home indicator to keep
    // clear of, whatever the page around it has.
    child: MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: GlassScaffold(
        scrollEdge: switch (_edge) {
          _Edge.soft => GlassScrollEdgeStyle.soft,
          _Edge.hard => GlassScrollEdgeStyle.hard,
          _Edge.none => null,
        },
        topBar: GlassBar(
          child: Row(
            children: <Widget>[
              Icon(_kTabs[_tab].icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _kTabs[_tab].label,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              Text('$_rows', style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
        bottomBar: _bottomBar
            ? GlassTabBar(items: _kTabs, selectedIndex: _tab, onSelected: (int i) => setState(() => _tab = i))
            : null,
        floatingAction: _action
            ? GlassButton(
                onPressed: () => setState(() => _rows++),
                semanticLabel: 'Add a row',
                padding: const EdgeInsets.all(14),
                child: const Icon(Icons.add, size: 24),
              )
            : null,
        // No padding of its own: the list takes the bars' extents from the
        // media query the scaffold sets.
        body: ListView.builder(
          itemCount: _rows,
          itemBuilder: (BuildContext context, int i) => GradientTile(index: i + _tab * 7, height: 84),
        ),
      ),
    ),
  );
}
