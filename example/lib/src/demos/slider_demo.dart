import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// Volume and brightness on a glass card. Brightness dims the backdrop, so
/// dragging it changes what is under the glass.
class SliderDemo extends StatefulWidget {
  const SliderDemo({super.key});

  @override
  State<SliderDemo> createState() => _SliderDemoState();
}

const Map<String, Color> _kAccents = <String, Color>{
  'Blue': Color(0xFF0A84FF),
  'White': Color(0xFFFFFFFF),
  'Pink': Color(0xFFFF375F),
  'Mint': Color(0xFF63E6E2),
};

class _SliderDemoState extends State<SliderDemo> {
  double _volume = 0.6;
  double _brightness = 0.8;
  bool _enabled = true;
  String _accent = 'Blue';

  @override
  Widget build(BuildContext context) {
    final Color accent = _kAccents[_accent]!;
    return DemoStage(
      height: 340,
      background: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const GridBackdrop(hue: 30),
          ColoredBox(color: Colors.black.withValues(alpha: (1 - _brightness) * 0.7)),
        ],
      ),
      hint: 'Press and hold a knob: it becomes a clear drop over the track. Brightness dims the picture behind.',
      knobs: <Widget>[
        KnobChoice<String>(
          label: 'Active colour',
          values: _kAccents.keys.toList(),
          selected: _accent,
          onChanged: (String a) => setState(() => _accent = a),
        ),
        KnobSwitch(label: 'Enabled', value: _enabled, onChanged: (bool v) => setState(() => _enabled = v)),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SliderRow(
                    label: 'Volume',
                    low: Icons.volume_mute_rounded,
                    high: Icons.volume_up_rounded,
                    value: _volume,
                    color: accent,
                    onChanged: _enabled ? (double v) => setState(() => _volume = v) : null,
                  ),
                  const SizedBox(height: 8),
                  _SliderRow(
                    label: 'Brightness',
                    low: Icons.brightness_low_rounded,
                    high: Icons.brightness_high_rounded,
                    value: _brightness,
                    color: accent,
                    onChanged: _enabled ? (double v) => setState(() => _brightness = v) : null,
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

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.low,
    required this.high,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final IconData low;
  final IconData high;
  final double value;
  final Color color;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(fontSize: 15, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
          ),
        ],
      ),
      Row(
        children: <Widget>[
          Icon(low, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: GlassSlider(
              value: value,
              activeColor: color,
              semanticLabel: label,
              semanticStep: 0.05,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 4),
          Icon(high, size: 20),
        ],
      ),
    ],
  );
}
