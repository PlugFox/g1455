import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

/// Metaballs: glass blobs that fuse into one silhouette when they come close.
///
/// A [GlassGroup] draws its members as one piece of glass, folding their
/// shapes by a smooth minimum: two blobs nearer than `spacing` grow a bridge.
/// A [GlassUnion] solves the radius instead, so every blob is joined however
/// far apart. The blobs orbit inside a [GlassTravel] covering the stage, so the
/// motion samples the proxy already held and costs no capture while the
/// backdrop stays still. One blob follows the finger.
class BlobsPage extends StatefulWidget {
  const BlobsPage({required this.insets, super.key});

  final EdgeInsets insets;

  @override
  State<BlobsPage> createState() => _BlobsPageState();
}

/// How many blobs orbit at most. With the dragged one that is 9 of the
/// group's [kMaxFusedShapes].
const int _kMaxBlobs = 8;

class _BlobsPageState extends State<BlobsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  double _spacing = 0.45;
  bool _union = false;
  int _count = 5;
  Offset? _drag;

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  void _setOrbit(bool on) {
    if (on) {
      _orbit.repeat();
    } else {
      _orbit.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      const Positioned.fill(child: GridBackdrop()),
      Positioned.fill(
        top: widget.insets.top,
        bottom: widget.insets.bottom + 200,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => _stage(constraints.biggest),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: widget.insets.bottom + 8,
        child: _controls(context),
      ),
    ],
  );

  Widget _stage(Size size) {
    final Offset drag = _drag ?? Offset(size.width / 2, size.height * 0.75);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (DragDownDetails d) => setState(() => _drag = d.localPosition),
      onPanUpdate: (DragUpdateDetails d) => setState(() => _drag = d.localPosition),
      child: GlassTravel(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _orbit,
            builder: (BuildContext context, Widget? _) {
              final Widget blobs = Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  for (var i = 0; i < _kMaxBlobs; i++) _blob(i, size),
                  _circle(drag, 44, 1),
                ],
              );
              return _union
                  ? GlassUnion(labelled: false, child: blobs)
                  : GlassGroup(spacing: _spacing * 60, labelled: false, child: blobs);
            },
          ),
        ),
      ),
    );
  }

  /// Blob [i] on its own orbit: an ellipse around the stage's centre, each at
  /// its own speed, radius and phase.
  Widget _blob(int i, Size size) {
    final double t = _orbit.value * 2 * math.pi;
    final double speed = (i.isEven ? 1 : -1) * (1 + i % 3);
    final double a = t * speed + i * 2.4;
    final Offset centre = Offset(size.width / 2, size.height * 0.42);
    final double rx = size.width * (0.14 + 0.05 * (i % 4));
    final double ry = size.height * (0.10 + 0.04 * ((i + 1) % 4));
    final double r = 26 + 9.0 * (i % 3);
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(i),
      tween: Tween<double>(end: i < _count ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double presence, Widget? _) => _circle(
        centre + Offset(math.cos(a) * rx, math.sin(a) * ry),
        r,
        presence.clamp(0.0, 1.0),
      ),
    );
  }

  Widget _circle(Offset centre, double radius, double presence) => Positioned(
    left: centre.dx - radius,
    top: centre.dy - radius,
    width: radius * 2,
    height: radius * 2,
    child: GlassSurface(borderRadius: kGlassCapsule, presence: presence, labelled: false),
  );

  Widget _controls(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: Text('Union')),
            GlassSwitch(value: _union, onChanged: (bool v) => setState(() => _union = v)),
          ],
        ),
        Row(
          children: <Widget>[
            const Expanded(child: Text('Orbit')),
            GlassSwitch(value: _orbit.isAnimating, onChanged: _setOrbit),
          ],
        ),
        Row(
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(_union ? 'Spacing —' : 'Spacing ${(_spacing * 60).round()}'),
            ),
            Expanded(
              child: GlassSlider(
                value: _spacing,
                onChanged: _union ? null : (double v) => setState(() => _spacing = v),
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Expanded(child: Text('Blobs  $_count')),
            GlassButton(
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
              child: const SiteIcon(SFIcons.sf_minus),
            ),
            const SizedBox(width: 8),
            GlassButton(
              onPressed: _count < _kMaxBlobs ? () => setState(() => _count++) : null,
              child: const SiteIcon(SFIcons.sf_plus),
            ),
          ],
        ),
      ],
    ),
  );
}
