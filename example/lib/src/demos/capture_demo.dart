import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';
import '../widgets/stage.dart';

/// A player under a glass bar, and what the glass is told the player is: the
/// player itself, a stand-in painted in its place, or nothing at all.
class CaptureDemo extends StatefulWidget {
  const CaptureDemo({super.key});

  @override
  State<CaptureDemo> createState() => _CaptureDemoState();
}

enum _Role {
  asIs('As is'),
  standIn('Gradient'),
  solid('Colour'),
  hidden('Hidden');

  const _Role(this.label);

  final String label;
}

class _CaptureDemoState extends State<CaptureDemo> {
  _Role _role = _Role.standIn;

  Widget _declared(Widget player) => switch (_role) {
    _Role.asIs => player,
    _Role.standIn => GlassProxy.replace(
      painter: const GradientProxyPainter(
        LinearGradient(colors: <Color>[Color(0xFF0A84FF), Color(0xFFBF5AF2), Color(0xFFFF375F)]),
      ),
      child: player,
    ),
    _Role.solid => GlassProxy.replace(painter: const SolidProxyPainter(Color(0xFF30D158)), child: player),
    _Role.hidden => GlassProxy.hidden(child: player),
  };

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    background: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const GridBackdrop(hue: 40),
        Center(
          child: FractionallySizedBox(widthFactor: 0.72, heightFactor: 0.62, child: _declared(const _Player())),
        ),
      ],
    ),
    knobs: <Widget>[
      KnobChoice<_Role>(
        label: 'The glass sees',
        values: _Role.values,
        selected: _role,
        labelOf: (_Role r) => r.label,
        onChanged: (_Role r) => setState(() => _role = r),
      ),
    ],
    hint: switch (_role) {
      _Role.asIs => 'The player as it paints. A video or a platform view would leave a hole here: they record nothing.',
      _Role.standIn =>
        'GlassProxy.replace: the glass sees a gradient in the player\'s place; the page still shows the player.',
      _Role.solid => 'SolidProxyPainter: one flat colour, the cheapest stand-in there is.',
      _Role.hidden => 'GlassProxy.hidden: the glass sees what is behind the player, as if it were not there.',
    },
    // Clear glass, which shows what it is told most plainly: a lens over the
    // player, and a bar across its foot.
    child: Stack(
      children: <Widget>[
        const Align(
          alignment: Alignment(0.42, -0.3),
          child: SizedBox.square(
            dimension: 110,
            child: GlassSurface(borderRadius: kGlassCapsule, finish: GlassFinish.clear, labelled: false),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.62),
          child: FractionallySizedBox(
            widthFactor: 0.86,
            child: GlassBar(
              finish: GlassFinish.clear,
              child: const Row(
                children: <Widget>[
                  SiteIcon(SFIcons.sf_play_rectangle_fill, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Glass over the player', overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Something that looks like a video frame: what a capture cannot read when
/// it really is one.
class _Player extends StatelessWidget {
  const _Player();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF1B1F2A), Color(0xFF3A2E5C), Color(0xFFFF9F0A)],
      ),
    ),
    child: Stack(
      children: <Widget>[
        const Positioned(
          left: 14,
          top: 12,
          child: Text(
            'LIVE',
            style: TextStyle(color: Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: const SiteIcon(SFIcons.sf_play_fill, size: 26, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
