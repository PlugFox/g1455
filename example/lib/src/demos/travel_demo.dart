import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// A magnifying lens dragged over a still backdrop, with and without the
/// [GlassTravel] that makes its motion free.
class TravelDemo extends StatefulWidget {
  const TravelDemo({super.key});

  @override
  State<TravelDemo> createState() => _TravelDemoState();
}

const double _kLens = 116;

class _TravelDemoState extends State<TravelDemo> {
  bool _travel = true;
  double _zoom = 1.4;
  Offset? _at;

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    knobs: <Widget>[
      KnobSwitch(label: 'GlassTravel', value: _travel, onChanged: (bool v) => setState(() => _travel = v)),
      KnobSlider(
        label: 'Zoom',
        value: _zoom,
        min: 1,
        max: 2,
        format: (double v) => '×${v.toStringAsFixed(1)}',
        onChanged: (double v) => setState(() => _zoom = v),
      ),
    ],
    hint: _travel
        ? 'Drag the lens. Inside GlassTravel it is redrawn from the capture the host already holds: no new capture.'
        : 'Travel is off: the lens looks the same, but every frame of the drag now re-captures the backdrop under it.',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final Offset at = _clamp(_at ?? Offset(size.width / 2, size.height / 2), size);
        // The lens's parent paints nothing of its own, and the backdrop sits
        // behind a boundary of its own (the stage's): moving the lens repaints
        // nothing else.
        final Widget layer = RepaintBoundary(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: at.dx - _kLens / 2,
                top: at.dy - _kLens / 2,
                width: _kLens,
                height: _kLens,
                child: GestureDetector(
                  onPanUpdate: (DragUpdateDetails d) => setState(() => _at = _clamp(at + d.delta, size)),
                  child: GlassSurface(
                    borderRadius: kGlassCapsule,
                    labelled: false,
                    finish: GlassFinish.clear.copyWith(optics: GlassOptics(zoom: _zoom)),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        );
        return _travel ? GlassTravel(child: layer) : layer;
      },
    ),
  );

  static Offset _clamp(Offset p, Size size) => Offset(
    p.dx.clamp(_kLens / 2, size.width - _kLens / 2),
    p.dy.clamp(_kLens / 2, size.height - _kLens / 2),
  );
}
