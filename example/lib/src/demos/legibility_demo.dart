import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// A card over a flat backdrop whose level the visitor sets, under a
/// [GlassTheme] of its own that declares that level: the label colour, the
/// contrast it reaches and the dim a floor asks for, live.
class LegibilityDemo extends StatefulWidget {
  const LegibilityDemo({super.key});

  @override
  State<LegibilityDemo> createState() => _LegibilityDemoState();
}

enum _Finish { regular, clear, frosted }

const Color _kDark = Color(0xFF0B0E16);
const Color _kLight = Color(0xFFF4F5F8);

class _LegibilityDemoState extends State<LegibilityDemo> {
  double _level = 0.15;
  _Finish _finish = _Finish.regular;
  bool _floor = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) => _stage(context, (c.maxWidth - 36 - 44 - 150).clamp(72, 180)),
  );

  Widget _stage(BuildContext context, double knob) {
    final Color backdrop = Color.lerp(_kDark, _kLight, _level)!;
    final GlassFinish finish = switch (_finish) {
      // Apple's two-branch material, picked the way the host picks it.
      _Finish.regular => GlassFinish.regular(appearance: MediaQuery.platformBrightnessOf(context), backdrop: backdrop),
      _Finish.clear => GlassFinish.clear,
      _Finish.frosted => GlassFinish.frosted,
    };
    final GlassThemeData outer = GlassTheme.of(context);
    // A theme for the stage alone: what is behind the glass here is one flat
    // colour, and it is declared. Built fresh rather than by copyWith, which
    // cannot set the floor back to null.
    final data = GlassThemeData(
      finish: finish,
      tier: outer.tier,
      backdrop: backdrop,
      highContrast: outer.highContrast,
      minLabelContrast: _floor ? kTextContrastAA : null,
    );
    final GlassLegibility look = data.legibility();
    final double contrast = GlassFinish.contrastRatio(look.finish.opaqueFillOver(backdrop), look.label);
    final bool dimmed = look.finish.tint != finish.tint;
    final bool white = look.label.computeLuminance() > 0.5;
    return DemoStage(
      height: 340,
      background: _FlatBackdrop(colour: backdrop),
      knobs: <Widget>[
        KnobSlider(
          label: 'Backdrop',
          width: knob,
          value: _level,
          format: (double v) => '${(v * 100).round()}%',
          onChanged: (double v) => setState(() => _level = v),
        ),
        KnobChoice<_Finish>(
          label: 'Finish',
          values: _Finish.values,
          selected: _finish,
          labelOf: (_Finish f) => switch (f) {
            _Finish.regular => 'Regular',
            _Finish.clear => 'Clear',
            _Finish.frosted => 'Frosted',
          },
          onChanged: (_Finish f) => setState(() => _finish = f),
        ),
        KnobSwitch(label: 'AA floor (4.5)', value: _floor, onChanged: (bool v) => setState(() => _floor = v)),
      ],
      hint:
          'Drag the backdrop from dark to light: the label flips, and Regular turns to its light branch near white. '
          'Then pick Clear and switch the floor on.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Center(
          child: SizedBox(
            width: math.min(340, constraints.maxWidth - 40),
            child: GlassTheme(
              data: data,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.notifications_none, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${white ? 'White' : 'Black'} label',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: look.label,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x80808080)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${contrast.toStringAsFixed(2)} : 1 against the glass',
                      style: const TextStyle(fontSize: 15, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dimmed
                          ? 'Glass dimmed to reach ${kTextContrastAA.toStringAsFixed(1)} : 1'
                          : contrast < kTextContrastAA
                          ? 'Below AA: declare a floor'
                          : 'Meets AA as drawn',
                      style: const TextStyle(fontSize: 13),
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

/// One flat colour, with a faint pattern of the same average so the glass has
/// edges to bend.
class _FlatBackdrop extends StatelessWidget {
  const _FlatBackdrop({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FlatPainter(colour), size: Size.infinite);
}

class _FlatPainter extends CustomPainter {
  _FlatPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colour);
    final Color ink = colour.computeLuminance() > 0.4 ? const Color(0x14000000) : const Color(0x14FFFFFF);
    final line = Paint()
      ..color = ink
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_FlatPainter oldDelegate) => oldDelegate.colour != colour;
}
