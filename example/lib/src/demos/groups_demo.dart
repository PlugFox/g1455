import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// Metaballs, compact: orbiting glass blobs drawn as one silhouette by a
/// [GlassGroup] or a [GlassUnion], and one more that follows the finger.
class GroupsDemo extends StatefulWidget {
  const GroupsDemo({super.key});

  @override
  State<GroupsDemo> createState() => _GroupsDemoState();
}

/// The most blobs that orbit; with the dragged one, 8 of [kMaxFusedShapes].
const int _kMaxBlobs = 7;

class _GroupsDemoState extends State<GroupsDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  double _spacing = 24;
  bool _union = false;
  int _count = 4;
  Offset? _drag;

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    knobs: <Widget>[
      KnobSwitch(label: 'GlassUnion', value: _union, onChanged: (bool v) => setState(() => _union = v)),
      KnobSlider(
        label: 'Spacing',
        value: _spacing,
        max: 60,
        format: (double v) => _union ? '—' : '${v.round()} px',
        onChanged: (double v) => setState(() => _spacing = v),
      ),
      KnobSlider(
        label: 'Blobs',
        value: _count.toDouble(),
        min: 1,
        max: _kMaxBlobs.toDouble(),
        width: 140,
        format: (double v) => '${v.round()}',
        onChanged: (double v) => setState(() => _count = v.round()),
      ),
    ],
    hint: 'Drag the blob into the others. More spacing fuses them from further away; a union joins them all.',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final Offset drag = _drag ?? Offset(size.width / 2, size.height * 0.78);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (DragDownDetails d) => setState(() => _drag = d.localPosition),
          onPanUpdate: (DragUpdateDetails d) => setState(() => _drag = d.localPosition),
          // The blobs move over a still backdrop: inside a travel region their
          // motion costs no capture.
          child: GlassTravel(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _orbit,
                builder: (BuildContext context, Widget? _) {
                  final Widget blobs = Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      for (var i = 0; i < _kMaxBlobs; i++) _blob(i, size),
                      _circle(drag, 34, 1),
                    ],
                  );
                  return _union
                      ? GlassUnion(labelled: false, child: blobs)
                      : GlassGroup(spacing: _spacing, labelled: false, child: blobs);
                },
              ),
            ),
          ),
        );
      },
    ),
  );

  /// Blob [i] on an ellipse of its own around the stage's centre.
  Widget _blob(int i, Size size) {
    final double t = _orbit.value * 2 * math.pi;
    final double speed = (i.isEven ? 1 : -1) * (1 + i % 3);
    final double a = t * speed + i * 2.4;
    final Offset centre = Offset(size.width / 2, size.height * 0.42);
    final double rx = math.min(size.width * (0.12 + 0.05 * (i % 4)), 90.0 + 30 * (i % 4));
    final double ry = size.height * (0.08 + 0.04 * ((i + 1) % 4));
    final double r = 20 + 7.0 * (i % 3);
    // A blob being added buds out of its neighbours as its presence grows.
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(i),
      tween: Tween<double>(end: i < _count ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double presence, Widget? _) =>
          _circle(centre + Offset(math.cos(a) * rx, math.sin(a) * ry), r, presence.clamp(0.0, 1.0)),
    );
  }

  Widget _circle(Offset centre, double radius, double presence) => Positioned(
    left: centre.dx - radius,
    top: centre.dy - radius,
    width: radius * 2,
    height: radius * 2,
    child: GlassSurface(borderRadius: kGlassCapsule, presence: presence, labelled: false),
  );
}
