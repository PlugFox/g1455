import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/capture_meter.dart';
import '../widgets/site_icon.dart';
import '../widgets/stage.dart';

/// An order on a glass card: two steppers with their values beside them, and
/// the host's capture count under the stage, which a press leaves where it is.
class StepperDemo extends StatefulWidget {
  const StepperDemo({super.key});

  @override
  State<StepperDemo> createState() => _StepperDemoState();
}

class _StepperDemoState extends State<StepperDemo> {
  int _copies = 1;
  double _size = 12;
  bool _wraps = false;
  bool _autorepeat = true;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DemoStage(
        height: 300,
        background: const PhotoBackdrop(seed: 31),
        knobs: <Widget>[
          KnobSwitch(label: 'Autorepeat', value: _autorepeat, onChanged: (bool v) => setState(() => _autorepeat = v)),
          KnobSwitch(label: 'Wraps', value: _wraps, onChanged: (bool v) => setState(() => _wraps = v)),
          KnobSwitch(label: 'Enabled', value: _enabled, onChanged: (bool v) => setState(() => _enabled = v)),
        ],
        hint:
            'Hold a half: it steps at once, then repeats. At a limit that half is disabled, unless it wraps. '
            'The values are on the card, so a press repaints only glass: the count under the stage stays put.',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Row(
                      icon: SFIcons.sf_printer,
                      label: 'Copies: $_copies',
                      stepper: GlassStepper(
                        value: _copies.toDouble(),
                        min: 1,
                        max: 10,
                        wraps: _wraps,
                        autorepeat: _autorepeat,
                        semanticLabel: 'Copies',
                        onChanged: _enabled ? (double v) => setState(() => _copies = v.round()) : null,
                      ),
                    ),
                    _Row(
                      icon: SFIcons.sf_textformat_size,
                      label: 'Text: ${_size.toStringAsFixed(1)} pt',
                      stepper: GlassStepper(
                        value: _size,
                        min: 9,
                        max: 24,
                        step: 0.5,
                        wraps: _wraps,
                        autorepeat: _autorepeat,
                        semanticLabel: 'Text size',
                        semanticFormatterCallback: (double v) => '${v.toStringAsFixed(1)} points',
                        onChanged: _enabled ? (double v) => setState(() => _size = v) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: CaptureMeter()),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.stepper});

  final IconData icon;
  final String label;
  final Widget stepper;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SiteIcon(icon, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
        ),
      ),
      stepper,
    ],
  );
}
