import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A settings group on a glass card: four switches, the last one always
/// disabled.
class SwitchDemo extends StatefulWidget {
  const SwitchDemo({super.key});

  @override
  State<SwitchDemo> createState() => _SwitchDemoState();
}

const Map<String, Color> _kAccents = <String, Color>{
  'Green': Color(0xFF34C759),
  'Blue': Color(0xFF0A84FF),
  'Purple': Color(0xFFBF5AF2),
  'Orange': Color(0xFFFF9F0A),
};

class _SwitchDemoState extends State<SwitchDemo> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _airplane = false;
  bool _enabled = true;
  String _accent = 'Green';

  @override
  Widget build(BuildContext context) {
    final Color accent = _kAccents[_accent]!;
    ValueChanged<bool>? when(ValueChanged<bool> f) => _enabled ? (bool v) => setState(() => f(v)) : null;
    return DemoStage(
      height: 340,
      hint: 'Press and hold a knob: it lifts into a clear drop. Drag it across, or just tap the row.',
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
            constraints: const BoxConstraints(maxWidth: 360),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Row(
                    icon: SFIcons.sf_wifi,
                    label: 'Wi-Fi',
                    value: _wifi,
                    color: accent,
                    onChanged: when((bool v) => _wifi = v),
                  ),
                  _Row(
                    icon: SFIcons.sf_wave_3_right,
                    label: 'Bluetooth',
                    value: _bluetooth,
                    color: accent,
                    onChanged: when((bool v) => _bluetooth = v),
                  ),
                  _Row(
                    icon: SFIcons.sf_airplane,
                    label: 'Airplane mode',
                    value: _airplane,
                    color: accent,
                    onChanged: when((bool v) => _airplane = v),
                  ),
                  _Row(icon: SFIcons.sf_lock, label: 'Managed by your admin', value: true, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, required this.color, this.onChanged});

  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        height: 52,
        child: Row(
          children: <Widget>[
            SiteIcon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            GlassSwitch(value: value, activeColor: color, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}
