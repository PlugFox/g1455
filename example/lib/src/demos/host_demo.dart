import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
// The host's counters: read here to show when it captures. An application has
// no reason to import this library.
import 'package:g1455/glass_diagnostics.dart' show GlassProxyHandle, GlassProxyScope;

import '../app/theme.dart';
import '../backdrops.dart';
import '../widgets/stage.dart';

/// What the host does: three cards and a lens share one capture of the
/// backdrop, and the host takes a new one only when something under the glass
/// changed. A meter counts its captures.
class HostDemo extends StatefulWidget {
  const HostDemo({super.key});

  @override
  State<HostDemo> createState() => _HostDemoState();
}

class _HostDemoState extends State<HostDemo> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  late final AnimationController _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void dispose() {
    _drift.dispose();
    _orbit.dispose();
    super.dispose();
  }

  void _run(AnimationController c, bool on) {
    if (on) {
      c.repeat();
    } else {
      c.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    background: AnimatedBuilder(
      animation: _drift,
      builder: (BuildContext context, Widget? _) => GridBackdrop(hue: _drift.value * 360, phase: _drift.value),
    ),
    knobs: <Widget>[
      KnobSwitch(label: 'Drift', value: _drift.isAnimating, onChanged: (bool v) => _run(_drift, v)),
      KnobSwitch(label: 'Move lens', value: _orbit.isAnimating, onChanged: (bool v) => _run(_orbit, v)),
      const _CaptureMeter(),
    ],
    hint:
        'Still, or with the lens moving, the host keeps the capture it has. '
        'Drift the backdrop and it captures every frame: once for all four surfaces.',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final double cardWidth = math.min(150, (size.width - 48) / 3);
        return Stack(
          children: <Widget>[
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _Tile(width: cardWidth, icon: Icons.wb_sunny_outlined, value: '21°', label: 'Sunny'),
                  const SizedBox(width: 12),
                  _Tile(width: cardWidth, icon: Icons.directions_walk, value: '8.2k', label: 'Steps'),
                  const SizedBox(width: 12),
                  _Tile(width: cardWidth, icon: Icons.battery_5_bar, value: '82%', label: 'Battery'),
                ],
              ),
            ),
            // The lens moves inside a travel region over still content: the
            // region is captured once and the motion costs nothing more.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 150,
              child: GlassTravel(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _orbit,
                    builder: (BuildContext context, Widget? lens) {
                      final double t = _orbit.value * 2 * math.pi;
                      final double x = size.width / 2 + math.sin(t) * (size.width / 2 - 70);
                      final double y = 75 + math.sin(t * 2) * 22;
                      return Stack(
                        children: <Widget>[Positioned(left: x - 44, top: y - 44, width: 88, height: 88, child: lens!)],
                      );
                    },
                    child: GlassSurface(
                      borderRadius: kGlassCapsule,
                      finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.35)),
                      labelled: false,
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

class _Tile extends StatelessWidget {
  const _Tile({required this.width, required this.icon, required this.value, required this.label});

  final double width;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 120,
    child: GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ),
          Text(label, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

/// How many captures the host took in the last second, and in all.
///
/// Read once a second rather than on every capture, and drawn under the stage
/// rather than on it, so that the meter itself does not feed the count.
class _CaptureMeter extends StatefulWidget {
  const _CaptureMeter();

  @override
  State<_CaptureMeter> createState() => _CaptureMeterState();
}

class _CaptureMeterState extends State<_CaptureMeter> {
  GlassProxyHandle? _handle;
  Timer? _timer;
  int _start = 0;
  int _last = 0;
  int _perSecond = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final GlassProxyHandle? handle = GlassProxyScope.maybeOf(context);
    if (!identical(handle, _handle)) {
      _handle = handle;
      _start = _last = handle?.generation ?? 0;
      _timer?.cancel();
      _timer = handle == null ? null : Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final int now = _handle?.generation ?? _last;
    setState(() {
      _perSecond = now - _last;
      _last = now;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_handle == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: false,
      label: 'Captures per second: $_perSecond',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.camera_outlined, size: 16, color: _perSecond > 0 ? kSiteAccent : kSiteTextMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'captures/s $_perSecond · total ${_last - _start}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kSiteText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
