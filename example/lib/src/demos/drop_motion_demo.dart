import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// The four controls with a held drop, all on one [GlassDropMotion] whose
/// stretch and spring the visitor sets.
class DropMotionDemo extends StatefulWidget {
  const DropMotionDemo({super.key});

  @override
  State<DropMotionDemo> createState() => _DropMotionDemoState();
}

const List<GlassTabItem> _kTabs = <GlassTabItem>[
  GlassTabItem(icon: Icons.home_rounded, label: 'Home'),
  GlassTabItem(icon: Icons.search_rounded, label: 'Search'),
  GlassTabItem(icon: Icons.library_music_rounded, label: 'Library'),
  GlassTabItem(icon: Icons.person_rounded, label: 'Profile'),
];

class _DropMotionDemoState extends State<DropMotionDemo> {
  double _stretch = 0.12;
  double _stiffness = 900;
  double _damping = 30;
  int _segment = 0;
  int _tab = 0;
  double _value = 0.3;
  bool _on = true;

  GlassDropMotion get _motion => _stretch == 0
      ? GlassDropMotion.none
      : GlassDropMotion(maxStretch: _stretch, stiffness: _stiffness, damping: _damping);

  @override
  Widget build(BuildContext context) {
    final GlassDropMotion motion = _motion;
    return DemoStage(
      height: 400,
      background: GridBackdrop(hue: _tab * 70.0 + _segment * 25.0),
      knobs: <Widget>[
        KnobSlider(
          label: 'Stretch',
          width: 140,
          value: _stretch,
          max: 0.5,
          format: (double v) => v == 0 ? 'none' : '${(v * 100).round()}%',
          onChanged: (double v) => setState(() => _stretch = v < 0.005 ? 0 : v),
        ),
        KnobSlider(
          label: 'Stiffness',
          width: 140,
          value: _stiffness,
          min: 200,
          max: 2000,
          format: (double v) => '${v.round()}',
          onChanged: (double v) => setState(() => _stiffness = v),
        ),
        KnobSlider(
          label: 'Damping',
          width: 140,
          value: _damping,
          min: 5,
          max: 80,
          format: (double v) => '${v.round()}',
          onChanged: (double v) => setState(() => _damping = v),
        ),
      ],
      hint:
          'Tap a far segment or tab: the drop stretches as it sets off and squashes as it lands, then springs back. '
          'Stretch at 0 is GlassDropMotion.none.',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            bottom: 88,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          child: GlassSegmentedControl(
                            segments: const <Widget>[Text('Day'), Text('Week'), Text('Month'), Text('Year')],
                            selectedIndex: _segment,
                            dropMotion: motion,
                            onSelected: (int i) => setState(() => _segment = i),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassSlider(
                          value: _value,
                          dropMotion: motion,
                          semanticLabel: 'Volume',
                          onChanged: (double v) => setState(() => _value = v),
                        ),
                        const SizedBox(height: 4),
                        MergeSemantics(
                          child: Row(
                            children: <Widget>[
                              const Expanded(child: Text('Wi-Fi', style: TextStyle(fontSize: 15))),
                              GlassSwitch(
                                value: _on,
                                dropMotion: motion,
                                onChanged: (bool v) => setState(() => _on = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  child: GlassTabBar(
                    items: _kTabs,
                    selectedIndex: _tab,
                    dropMotion: motion,
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
