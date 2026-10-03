import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// The primitive, every knob of it: the corner, the shape's presence, the
/// material's arrival, the finish and `labelled`, and a lens to drag.
class SurfaceDemo extends StatefulWidget {
  const SurfaceDemo({super.key});

  @override
  State<SurfaceDemo> createState() => _SurfaceDemoState();
}

enum _Finish {
  theme('Theme', null),
  clear('Clear', GlassFinish.clear),
  frosted('Frosted', GlassFinish.frosted);

  const _Finish(this.label, this.finish);

  final String label;
  final GlassFinish? finish;
}

const double _kLens = 92;

class _SurfaceDemoState extends State<SurfaceDemo> {
  double _radius = 28;
  double _presence = 1;
  double _materialize = 1;
  _Finish _finish = _Finish.theme;
  bool _labelled = true;
  double _zoom = 1.4;
  Offset? _lensAt;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (BuildContext context, BoxConstraints c) => _stage(_knobWidth(c.maxWidth)));

  Widget _stage(double knob) => DemoStage(
    height: 380,
    knobs: <Widget>[
      KnobSlider(
        label: 'Radius',
        width: knob,
        value: _radius,
        max: 80,
        format: (double v) => v.round().toString(),
        onChanged: (double v) => setState(() => _radius = v),
      ),
      KnobSlider(
        label: 'Presence',
        width: knob,
        value: _presence,
        onChanged: (double v) => setState(() => _presence = v),
      ),
      KnobSlider(
        label: 'Materialize',
        width: knob,
        value: _materialize,
        onChanged: (double v) => setState(() => _materialize = v),
      ),
      KnobChoice<_Finish>(
        label: 'Finish',
        values: _Finish.values,
        selected: _finish,
        labelOf: (_Finish f) => f.label,
        onChanged: (_Finish f) => setState(() => _finish = f),
      ),
      KnobSwitch(label: 'Labelled', value: _labelled, onChanged: (bool v) => setState(() => _labelled = v)),
      KnobSlider(
        label: 'Lens zoom',
        width: knob,
        value: _zoom,
        min: 0.6,
        max: 2,
        format: (double v) => '×${v.toStringAsFixed(1)}',
        onChanged: (double v) => setState(() => _zoom = v),
      ),
    ],
    hint:
        'Drag the lens. Materialize fades the material in, blur first and tint last; presence erodes the shape. '
        'Pick Clear and toggle Labelled to see the glass dimmed for its text.',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final double width = math.min(280, size.width - 64);
        const double height = 150;
        final Offset centre = Offset(size.width / 2, size.height * 0.6);
        final Offset lens = _lensAt ?? Offset(size.width - _kLens / 2 - 20, _kLens / 2 + 20);
        return Stack(
          children: <Widget>[
            Positioned(
              left: centre.dx - width / 2,
              top: centre.dy - height / 2,
              width: width,
              height: height,
              child: GlassSurface(
                borderRadius: BorderRadius.all(Radius.circular(_radius)),
                presence: _presence,
                materialize: _materialize,
                finish: _finish.finish,
                labelled: _labelled,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'GlassSurface',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'radius ${_radius.round()} · presence ${_presence.toStringAsFixed(2)}\n'
                          'materialize ${_materialize.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The lens floats above the panel (GlassAbove), so it bends the
            // panel too, and moves inside a travel region, so a drag costs no
            // capture.
            Positioned.fill(
              child: GlassAbove(
                child: GlassTravel(
                  child: RepaintBoundary(
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          left: lens.dx - _kLens / 2,
                          top: lens.dy - _kLens / 2,
                          width: _kLens,
                          height: _kLens,
                          child: Semantics(
                            label: 'Lens, draggable',
                            child: GestureDetector(
                              onPanUpdate: (DragUpdateDetails d) => setState(() {
                                final Offset next = lens + d.delta;
                                _lensAt = Offset(
                                  next.dx.clamp(_kLens / 2, size.width - _kLens / 2),
                                  next.dy.clamp(_kLens / 2, size.height - _kLens / 2),
                                );
                              }),
                              child: GlassSurface(
                                borderRadius: kGlassCapsule,
                                finish: GlassFinish.clear.copyWith(optics: GlassOptics(zoom: _zoom)),
                                labelled: false,
                                // A child to take the drag: an empty surface is not hit.
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// A knob slider's width that leaves room for its label and value on a phone.
double _knobWidth(double stage) => (stage - 36 - 44 - 150).clamp(72, 180);
