import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// A big clear panel that answers a touch with a wave, its viscosity live.
class RippleDemo extends StatefulWidget {
  const RippleDemo({super.key});

  @override
  State<RippleDemo> createState() => _RippleDemoState();
}

/// Three named points on the water-to-honey scale.
enum _Liquid {
  water('Water', 0),
  jelly('Jelly', 0.5),
  honey('Honey', 1);

  const _Liquid(this.label, this.viscosity);

  final String label;
  final double viscosity;
}

class _RippleDemoState extends State<RippleDemo> {
  double _viscosity = _Liquid.jelly.viscosity;
  double _amplitude = 6;

  _Liquid? get _preset {
    for (final _Liquid l in _Liquid.values) {
      if ((l.viscosity - _viscosity).abs() < 0.005) {
        return l;
      }
    }
    return null;
  }

  /// The named point nearest the viscosity: the one the knob shows while the
  /// slider is between two.
  _Liquid get _nearest => _Liquid.values.reduce(
    (_Liquid a, _Liquid b) => (a.viscosity - _viscosity).abs() <= (b.viscosity - _viscosity).abs() ? a : b,
  );

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final _Liquid? preset = _preset;
    return DemoStage(
      height: 360,
      knobs: <Widget>[
        KnobChoice<_Liquid>(
          label: 'Liquid',
          values: _Liquid.values,
          selected: _nearest,
          labelOf: (_Liquid l) => l.label,
          onChanged: (_Liquid l) => setState(() => _viscosity = l.viscosity),
        ),
        KnobSlider(
          label: 'Viscosity',
          value: _viscosity,
          onChanged: (double v) => setState(() => _viscosity = v),
        ),
        KnobSlider(
          label: 'Amplitude',
          value: _amplitude,
          min: 2,
          max: 14,
          format: (double v) => '${v.round()} px',
          onChanged: (double v) => setState(() => _amplitude = v),
        ),
      ],
      hint: reduced
          ? 'Your system asks for reduced motion, so the glass does not ripple. Turn that off to see the wave.'
          : 'Tap, hold and drag across the panel. Water rings and overshoots; honey sends one slow bump.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = math.min(constraints.maxWidth - 40, 460);
          final double height = math.min(constraints.maxHeight - 60, 250);
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: GlassSurface(
                borderRadius: const BorderRadius.all(Radius.circular(36)),
                finish: GlassFinish.clear,
                // No text that must be read on it: keep the clear finish undimmed.
                labelled: false,
                ripple: GlassRipple(viscosity: _viscosity, amplitude: _amplitude),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.waves, color: Colors.white, size: 36, shadows: _kShadow),
                      const SizedBox(height: 8),
                      Text(
                        preset?.label ?? 'Viscosity ${_viscosity.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          shadows: _kShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const List<Shadow> _kShadow = <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 8)];
