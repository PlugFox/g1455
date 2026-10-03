import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// Text, icon and icon-only buttons with a tap counter, and a disabled one.
class ButtonDemo extends StatefulWidget {
  const ButtonDemo({super.key});

  @override
  State<ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<ButtonDemo> {
  bool _enabled = true;
  bool _capsule = true;
  bool _liked = false;
  int _taps = 0;

  BorderRadius get _radius => _capsule ? kGlassCapsule : const BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final VoidCallback? tap = _enabled ? () => setState(() => _taps++) : null;
    return DemoStage(
      height: 320,
      hint: 'Press and hold a button: the whole glass brightens. Turn "Enabled" off to see the disabled labels.',
      knobs: <Widget>[
        KnobSwitch(label: 'Enabled', value: _enabled, onChanged: (bool v) => setState(() => _enabled = v)),
        KnobChoice<bool>(
          label: 'Corners',
          values: const <bool>[true, false],
          selected: _capsule,
          labelOf: (bool c) => c ? 'Capsule' : '14 px',
          onChanged: (bool c) => setState(() => _capsule = c),
        ),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _taps == 1 ? '1 tap' : '$_taps taps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  shadows: <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  GlassButton(onPressed: tap, borderRadius: _radius, child: const Text('Count')),
                  GlassButton(
                    onPressed: tap,
                    borderRadius: _radius,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[Icon(Icons.ios_share, size: 18), SizedBox(width: 6), Text('Share')],
                    ),
                  ),
                  GlassButton(
                    onPressed: _enabled ? () => setState(() => _liked = !_liked) : null,
                    borderRadius: _radius,
                    padding: EdgeInsets.zero,
                    semanticLabel: _liked ? 'Unlike' : 'Like',
                    child: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                  ),
                  GlassButton(
                    onPressed: tap,
                    borderRadius: _radius,
                    padding: EdgeInsets.zero,
                    semanticLabel: 'Add',
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassButton(borderRadius: _radius, child: const Text('Always disabled')),
            ],
          ),
        ),
      ),
    );
  }
}
