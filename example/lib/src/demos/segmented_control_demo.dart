import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A calendar range picker: two to five segments on a glass card, the
/// selection tinting the backdrop.
class SegmentedControlDemo extends StatefulWidget {
  const SegmentedControlDemo({super.key});

  @override
  State<SegmentedControlDemo> createState() => _SegmentedControlDemoState();
}

const List<(String, int)> _kRanges = <(String, int)>[
  ('Day', 3),
  ('Week', 12),
  ('Month', 41),
  ('Year', 318),
  ('All', 1204),
];

const Map<String, Color> _kThumbs = <String, Color>{
  'White': Color(0xFFFFFFFF),
  'Graphite': Color(0xFF636366),
};

class _SegmentedControlDemoState extends State<SegmentedControlDemo> {
  int _count = 3;
  int _selected = 1;
  bool _enabled = true;
  String _thumb = 'White';
  TextDirection _direction = TextDirection.ltr;

  void _setCount(int count) => setState(() {
    _count = count;
    _selected = _selected.clamp(0, count - 1);
  });

  @override
  Widget build(BuildContext context) {
    final (String range, int events) = _kRanges[_selected];
    return DemoStage(
      height: 320,
      background: GridBackdrop(hue: _selected * 65.0),
      hint:
          'Press and hold the selected segment: it lifts into a clear drop. Slide it to another and let go. '
          'Right to left, the first segment is at the right.',
      knobs: <Widget>[
        KnobChoice<int>(
          label: 'Segments',
          values: const <int>[2, 3, 4, 5],
          selected: _count,
          onChanged: _setCount,
        ),
        KnobChoice<String>(
          label: 'Thumb',
          values: _kThumbs.keys.toList(),
          selected: _thumb,
          onChanged: (String t) => setState(() => _thumb = t),
        ),
        KnobSwitch(label: 'Enabled', value: _enabled, onChanged: (bool v) => setState(() => _enabled = v)),
        KnobChoice<TextDirection>(
          label: 'Direction',
          values: const <TextDirection>[TextDirection.ltr, TextDirection.rtl],
          selected: _direction,
          labelOf: (TextDirection d) => d == TextDirection.ltr ? 'LTR' : 'RTL',
          onChanged: (TextDirection d) => setState(() => _direction = d),
        ),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    child: Directionality(
                      textDirection: _direction,
                      child: GlassSegmentedControl(
                        segments: <Widget>[for (final (String label, _) in _kRanges.take(_count)) Text(label)],
                        selectedIndex: _selected,
                        thumbColor: _kThumbs[_thumb]!,
                        onSelected: _enabled ? (int i) => setState(() => _selected = i) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const SiteIcon(SFIcons.sf_calendar, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              range == 'All' ? 'All time' : 'This ${range.toLowerCase()}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                            Text('$events events', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
