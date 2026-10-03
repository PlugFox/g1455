import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';

/// Switches, sliders and buttons on glass cards, over a backdrop they drive.
///
/// The hue slider repaints the backdrop under every glass on the page, which
/// is a capture per frame of the drag — the honest price of content changing
/// under glass. "Drift" does the same continuously. Everything else on the
/// page changes nothing under glass and is drawn from the proxy already held.
class ControlsPage extends StatefulWidget {
  const ControlsPage({required this.insets, super.key});

  final EdgeInsets insets;

  @override
  State<ControlsPage> createState() => _ControlsPageState();
}

class _ControlsPageState extends State<ControlsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  bool _wifi = true;
  bool _bluetooth = false;
  bool _focus = false;
  double _hue = 0;
  double _volume = 0.6;
  double _brightness = 0.8;
  int _taps = 0;

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _setDrift(bool on) {
    if (on) {
      _drift.repeat();
    } else {
      _drift.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (BuildContext context, Widget? _) => GridBackdrop(hue: _hue * 360, phase: _drift.value),
          ),
        ),
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.insets.top + 8,
              16,
              widget.insets.bottom + 16,
            ),
            children: <Widget>[
              _Section(
                title: 'Switches',
                children: <Widget>[
                  _Row(
                    icon: Icons.wifi,
                    label: 'Wi-Fi',
                    trailing: GlassSwitch(
                      value: _wifi,
                      onChanged: (bool v) => setState(() => _wifi = v),
                    ),
                  ),
                  _Row(
                    icon: Icons.bluetooth,
                    label: 'Bluetooth',
                    trailing: GlassSwitch(
                      value: _bluetooth,
                      activeColor: const Color(0xFF0A84FF),
                      onChanged: (bool v) => setState(() => _bluetooth = v),
                    ),
                  ),
                  _Row(
                    icon: Icons.nightlight_round,
                    label: 'Focus',
                    trailing: GlassSwitch(
                      value: _focus,
                      activeColor: const Color(0xFFBF5AF2),
                      onChanged: (bool v) => setState(() => _focus = v),
                    ),
                  ),
                  _Row(
                    icon: Icons.waves,
                    label: 'Drift backdrop',
                    trailing: GlassSwitch(value: _drift.isAnimating, onChanged: _setDrift),
                  ),
                  const _Row(
                    icon: Icons.block,
                    label: 'Disabled',
                    trailing: GlassSwitch(value: true, onChanged: null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Sliders',
                children: <Widget>[
                  _SliderRow(
                    icon: Icons.palette,
                    label: 'Backdrop hue',
                    value: _hue,
                    color: HSVColor.fromAHSV(1, _hue * 360, 0.8, 1).toColor(),
                    onChanged: (double v) => setState(() => _hue = v),
                  ),
                  _SliderRow(
                    icon: Icons.volume_up,
                    label: 'Volume',
                    value: _volume,
                    onChanged: (double v) => setState(() => _volume = v),
                  ),
                  _SliderRow(
                    icon: Icons.light_mode,
                    label: 'Brightness',
                    value: _brightness,
                    color: const Color(0xFFFFD60A),
                    onChanged: (double v) => setState(() => _brightness = v),
                  ),
                  const _SliderRow(
                    icon: Icons.block,
                    label: 'Disabled',
                    value: 0.4,
                    onChanged: null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Buttons',
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        GlassButton(
                          onPressed: () => setState(() => _taps++),
                          child: Text('Tapped $_taps'),
                        ),
                        GlassButton(onPressed: () {}, child: const Icon(Icons.play_arrow)),
                        GlassButton(onPressed: () {}, child: const Icon(Icons.share)),
                        const GlassButton(child: Text('Disabled')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Press and hold a knob: it lifts into a clear drop that bends what '
                'is under it.',
                style: text.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.trailing});

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        trailing,
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = const Color(0xFF0A84FF),
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text('${(value * 100).round()}'),
            const SizedBox(width: 4),
          ],
        ),
        GlassSlider(value: value, activeColor: color, onChanged: onChanged),
      ],
    ),
  );
}
