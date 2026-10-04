import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// A "+" button in the corner that flows into a panel of actions and back.
class MorphDemo extends StatefulWidget {
  const MorphDemo({super.key});

  @override
  State<MorphDemo> createState() => _MorphDemoState();
}

class _MorphDemoState extends State<MorphDemo> {
  bool _open = false;
  GlassMorphMotion _motion = GlassMorphMotion.fluid;
  double _spacing = kGlassMorphSpacing;
  String _last = 'nothing yet';

  void _choose(String what) => setState(() {
    _last = what;
    _open = false;
  });

  @override
  Widget build(BuildContext context) {
    final GlassThemeData theme = GlassTheme.of(context);
    final Color label = theme.legibility(theme.finish).label;
    return DemoStage(
      height: 380,
      knobs: <Widget>[
        KnobChoice<GlassMorphMotion>(
          label: 'Motion',
          values: const <GlassMorphMotion>[GlassMorphMotion.fluid, GlassMorphMotion.calm],
          selected: _motion,
          labelOf: (GlassMorphMotion m) => m == GlassMorphMotion.fluid ? 'Fluid' : 'Calm',
          onChanged: (GlassMorphMotion m) => setState(() => _motion = m),
        ),
        KnobSlider(
          width: 140,
          label: 'Spacing',
          value: _spacing,
          max: 24,
          format: (double v) => v.round().toString(),
          onChanged: (double v) => setState(() => _spacing = v),
        ),
      ],
      hint: 'Tap “+”: the button flows into the panel from the corner it is held by. Spacing 0 resizes with no neck.',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(
                'Chose: $_last',
                style: const TextStyle(color: Colors.white, fontSize: 15, shadows: <Shadow>[Shadow(blurRadius: 8)]),
              ),
            ),
            // The parent holds the top-right corner, and so does the morph.
            Align(
              alignment: Alignment.topRight,
              child: GlassMorph(
                alignment: Alignment.topRight,
                motion: _motion,
                spacing: _spacing,
                borderRadius: _open ? const BorderRadius.all(Radius.circular(28)) : kGlassCapsule,
                child: _open
                    ? _Panel(key: const ValueKey<String>('panel'), label: label, onChoose: _choose)
                    : _Plus(
                        key: const ValueKey<String>('plus'),
                        label: label,
                        onTap: () => setState(() => _open = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plus extends StatelessWidget {
  const _Plus({required this.label, required this.onTap, super.key});

  final Color label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'New',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.fromSize(
        size: kGlassMinTapTarget,
        child: Icon(Icons.add, color: label, size: 24),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.label, required this.onChoose, super.key});

  final Color label;
  final ValueChanged<String> onChoose;

  static const List<(IconData, String)> _kRows = <(IconData, String)>[
    (Icons.note_add_outlined, 'Note'),
    (Icons.checklist, 'List'),
    (Icons.photo_camera_outlined, 'Photo'),
    (Icons.mic_none, 'Voice memo'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (IconData icon, String name) in _kRows)
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChoose(name),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 18),
                      Icon(icon, color: label, size: 20),
                      const SizedBox(width: 12),
                      Text(name, style: TextStyle(color: label, fontSize: 17)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
