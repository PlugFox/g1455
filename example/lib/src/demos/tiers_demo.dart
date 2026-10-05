import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// The ladder: what the app knows goes into a [GlassTierPolicy], and the
/// rung it chooses is applied to the stage alone, through a [GlassTheme]
/// below the site's host.
class TiersDemo extends StatefulWidget {
  const TiersDemo({super.key});

  @override
  State<TiersDemo> createState() => _TiersDemoState();
}

class _TiersDemoState extends State<TiersDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 10));

  bool _reduceTransparency = false;
  bool _lowEnd = false;
  GlassTier? _pinned;
  bool _playing = true;

  @override
  void dispose() {
    _drift.dispose();
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) => _stage(context, narrow: c.maxWidth < 400),
  );

  Widget _stage(BuildContext context, {required bool narrow}) {
    final GlassTierChoice choice = GlassTierPolicy(
      pinned: _pinned,
      reduceTransparency: _reduceTransparency,
      ceiling: _lowEnd ? GlassTier.cheap : null,
    ).choose();
    return DemoStage(
      height: 360,
      background: AnimatedBuilder(
        animation: _drift,
        builder: (BuildContext context, Widget? _) => GridBackdrop(hue: _drift.value * 360, phase: _drift.value),
      ),
      knobs: <Widget>[
        KnobSwitch(
          label: narrow ? 'Reduce transp.' : 'Reduce transparency',
          value: _reduceTransparency,
          onChanged: (bool v) => setState(() => _reduceTransparency = v),
        ),
        KnobSwitch(label: 'Low-end device', value: _lowEnd, onChanged: (bool v) => setState(() => _lowEnd = v)),
        KnobChoice<GlassTier?>(
          label: 'Pinned',
          values: const <GlassTier?>[null, GlassTier.full, GlassTier.cheap, GlassTier.opaque],
          selected: _pinned,
          labelOf: (GlassTier? t) => t?.name ?? 'none',
          onChanged: (GlassTier? t) => setState(() => _pinned = t),
        ),
        KnobSwitch(label: 'Drift backdrop', value: _drift.isAnimating, onChanged: _setDrift),
      ],
      hint:
          'Reduce transparency gives opaque, a low-end ceiling gives cheap, and a pin overrides both. '
          'Drift the backdrop: cheap still shows it moving, opaque hides it.',
      child: GlassTheme(
        data: GlassTheme.of(context).copyWith(tier: choice),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: GlassBar(
                child: Row(
                  children: <Widget>[
                    const SiteIcon(SFIcons.sf_stairs, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'GlassTier.${choice.tier.name}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        choice.reason.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 76,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: <Color>[Color(0xFFFF7A59), Color(0xFF8E44FF)],
                                  ),
                                ),
                                child: const SiteIcon(SFIcons.sf_music_note, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Glass Animals',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text('Heat Waves', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: GlassButtonGroup(
                              items: <GlassToolbarItem>[
                                GlassToolbarItem(
                                  icon: const SiteIcon(SFIcons.sf_backward_end_fill),
                                  label: 'Previous',
                                  onPressed: () {},
                                ),
                                GlassToolbarItem(
                                  icon: SiteIcon(_playing ? SFIcons.sf_pause_fill : SFIcons.sf_play_fill),
                                  label: _playing ? 'Pause' : 'Play',
                                  onPressed: () => setState(() => _playing = !_playing),
                                ),
                                GlassToolbarItem(
                                  icon: const SiteIcon(SFIcons.sf_forward_end_fill),
                                  label: 'Next',
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
