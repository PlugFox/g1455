import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// Hello, glass: a bar floating over a list that scrolls under it, and a
/// floating button to add as the second piece of glass.
class InstallationDemo extends StatefulWidget {
  const InstallationDemo({super.key});

  @override
  State<InstallationDemo> createState() => _InstallationDemoState();
}

class _InstallationDemoState extends State<InstallationDemo> {
  bool _bar = true;
  bool _button = true;
  int _added = 0;

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 380,
    background: const ColoredBox(color: Color(0xFF101014)),
    knobs: <Widget>[
      KnobSwitch(label: 'Bar', value: _bar, onChanged: (bool v) => setState(() => _bar = v)),
      KnobSwitch(label: 'Button', value: _button, onChanged: (bool v) => setState(() => _button = v)),
    ],
    hint: 'Scroll the list: the bar bends and blurs the rows passing under it.',
    child: Stack(
      children: <Widget>[
        // The content: what the glass refracts.
        Positioned.fill(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 76, bottom: 84),
            itemCount: 24,
            itemBuilder: (BuildContext context, int i) => GradientTile(index: i, height: 96),
          ),
        ),
        // The glass.
        if (_bar)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: GlassBar(
              child: Row(
                children: <Widget>[
                  Icon(Icons.photo_library_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.search),
                ],
              ),
            ),
          ),
        if (_button)
          Positioned(
            right: 16,
            bottom: 16,
            child: GlassButton(
              onPressed: () => setState(() => _added++),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.add, size: 20),
                  const SizedBox(width: 6),
                  Text(_added == 0 ? 'New album' : 'Added $_added'),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
