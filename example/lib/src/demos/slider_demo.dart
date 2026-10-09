import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// Volume and brightness on a glass card. Brightness dims the backdrop, so
/// dragging it changes what is under the glass. Both can snap to steps, and
/// the card can be laid out right to left.
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
  int? _divisions;
  TextDirection _direction = TextDirection.ltr;

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
      hint:
          'Press and hold a knob: it becomes a clear drop over the track. Brightness dims the picture behind. '
          'With steps, every drag, tap and arrow key lands on a stop.',
      knobs: <Widget>[
        KnobChoice<String>(
          label: 'Active colour',
          values: _kAccents.keys.toList(),
          selected: _accent,
          onChanged: (String a) => setState(() => _accent = a),
        ),
        KnobSwitch(label: 'Enabled', value: _enabled, onChanged: (bool v) => setState(() => _enabled = v)),
        KnobChoice<int?>(
          label: 'Steps',
          values: const <int?>[null, 4, 10],
          selected: _divisions,
          labelOf: (int? d) => d == null ? 'Continuous' : '$d',
          onChanged: (int? d) => setState(() => _divisions = d),
        ),
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
            constraints: const BoxConstraints(maxWidth: 380),
            child: Directionality(
              textDirection: _direction,
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SliderRow(
                      label: 'Volume',
                      low: SFIcons.sf_speaker_fill,
                      high: SFIcons.sf_speaker_wave_2_fill,
                      value: _volume,
                      color: accent,
                      divisions: _divisions,
                      onChanged: _enabled ? (double v) => setState(() => _volume = v) : null,
                    ),
                    const SizedBox(height: 8),
                    _SliderRow(
                      label: 'Brightness',
                      low: SFIcons.sf_sun_min,
                      high: SFIcons.sf_sun_max_fill,
                      value: _brightness,
                      color: accent,
                      divisions: _divisions,
                      onChanged: _enabled ? (double v) => setState(() => _brightness = v) : null,
                    ),
                  ],
                ),
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
    this.divisions,
  });

  final String label;
  final IconData low;
  final IconData high;
  final double value;
  final Color color;
  final ValueChanged<double>? onChanged;
  final int? divisions;

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
          SiteIcon(low, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: GlassSlider(
              value: value,
              activeColor: color,
              semanticLabel: label,
              semanticStep: 0.05,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 4),
          SiteIcon(high, size: 20),
        ],
      ),
    ],
  );
}
