import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/browser_report.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A number of glass tiles over a backdrop that drifts, so every frame
/// re-captures, with what the host's [GlassLedger] reports about them.
class PerformanceDemo extends StatefulWidget {
  const PerformanceDemo({super.key});

  @override
  State<PerformanceDemo> createState() => _PerformanceDemoState();
}

const List<IconData> _kIcons = <IconData>[
  SFIcons.sf_sun_max_fill,
  SFIcons.sf_music_note,
  SFIcons.sf_heart_fill,
  SFIcons.sf_map,
  SFIcons.sf_camera_fill,
  SFIcons.sf_envelope_fill,
  SFIcons.sf_bolt_fill,
  SFIcons.sf_cloud_fill,
  SFIcons.sf_timer,
  SFIcons.sf_star_fill,
  SFIcons.sf_wifi,
  SFIcons.sf_battery_100percent,
];

class _PerformanceDemoState extends State<PerformanceDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  int _count = 6;
  bool _outline = false;

  @override
  void dispose() {
    _drift.dispose();
    if (_outline) {
      debugPaintGlassSurfaces = false;
    }
    super.dispose();
  }

  void _setDrift(bool on) {
    if (on) {
      _drift.repeat();
    } else {
      _drift.stop();
    }
    setState(() {});
  }

  void _setOutline(bool on) {
    debugPaintGlassSurfaces = on;
    setState(() => _outline = on);
  }

  // The stage, then what this browser says about the GPU under it.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DemoStage(
        height: 380,
        background: AnimatedBuilder(
          animation: _drift,
          builder: (BuildContext context, Widget? _) => GridBackdrop(phase: _drift.value, hue: 40 * _drift.value),
        ),
        knobs: <Widget>[
          KnobSlider(
            label: 'Surfaces',
            value: _count.toDouble(),
            min: 1,
            max: _kIcons.length.toDouble(),
            format: (double v) => '${v.round()}',
            onChanged: (double v) => setState(() => _count = v.round()),
          ),
          KnobSwitch(label: 'Drift', value: _drift.isAnimating, onChanged: _setDrift),
          // The outline is drawn by debug builds only.
          if (kDebugMode) KnobSwitch(label: 'Outline surfaces', value: _outline, onChanged: _setOutline),
        ],
        hint:
            'Add tiles while the backdrop drifts: each one is another draw. Stop the drift and nothing is re-captured.',
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double side = math.min(84, (constraints.maxWidth - 64) / 4 - 12);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 36),
                      child: SizedBox(
                        width: (side + 12) * 4,
                        child: Wrap(
                          // A new key repaints every tile when the outline is switched.
                          key: ValueKey<bool>(_outline),
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            for (var i = 0; i < _count; i++)
                              SizedBox(
                                width: side,
                                height: side,
                                child: GlassSurface(
                                  borderRadius: BorderRadius.all(Radius.circular(side * 0.28)),
                                  labelled: false,
                                  child: SiteIcon(_kIcons[i], color: Colors.white, size: side * 0.4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              right: 12,
              // Read twice a second: its own layer, so that is all that repaints.
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(child: _Readout()),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const BrowserReport(),
    ],
  );
}

/// What the ledger says about the glass on this page, read twice a second.
///
/// Polled rather than listened to: the ledger notifies when a surface mounts,
/// which happens while the tree is being built.
class _Readout extends StatefulWidget {
  const _Readout();

  @override
  State<_Readout> createState() => _ReadoutState();
}

class _ReadoutState extends State<_Readout> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlassLedger? ledger = GlassScope.maybeOf(context);
    final String text;
    if (ledger == null) {
      text = 'No GlassHost above';
    } else {
      final GlassLoad load = ledger.read(
        viewSize: MediaQuery.sizeOf(context),
        model: GlassHardware.detect().surfaceCostModel,
      );
      text =
          '${load.surfaceCount} surfaces on this page · '
          '${load.screensOfGlass.toStringAsFixed(2)} screens of glass · ${load.verdict.name}';
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
