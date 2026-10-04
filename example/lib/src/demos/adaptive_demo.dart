import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/app.dart';
import '../widgets/stage.dart';

/// A bar over a bright sky, a card on the horizon and buttons over a dark
/// ground. With "Adaptive" on, the site's own host reads the backdrop under
/// each glass ([siteAdaptive]), and each one wears the branch of `.regular`
/// that what is under it asks for; the card says what it read.
///
/// Not a second [GlassHost] inside the stage: a host mounted at an offset
/// inside another one draws no glass. So the page turns reading on for the
/// whole site while it is open, and off when it closes.
class AdaptiveDemo extends StatefulWidget {
  const AdaptiveDemo({super.key});

  @override
  State<AdaptiveDemo> createState() => _AdaptiveDemoState();
}

class _AdaptiveDemoState extends State<AdaptiveDemo> {
  /// The demo that last turned the site's reading on or off. A tab of this
  /// page replaces the demo with a new one, whose `initState` runs before the
  /// old one's `dispose`: only the owner may turn it off again.
  static Object? _owner;

  bool _adaptive = true;
  double _horizon = 0.5;

  @override
  void initState() {
    super.initState();
    // Not during this build: the host above rebuilds on the change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _owner = this;
        _apply();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_owner, this)) {
        _owner = null;
        siteAdaptive.value = null;
      }
    });
    super.dispose();
  }

  void _apply() => siteAdaptive.value = _adaptive ? const GlassAdaptive() : null;

  void _toggle(bool on) {
    setState(() => _adaptive = on);
    if (identical(_owner, this)) {
      _apply();
    }
  }

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 380,
    background: CustomPaint(painter: _LandscapePainter(_horizon)),
    knobs: <Widget>[
      KnobSwitch(label: 'Adaptive', value: _adaptive, onChanged: _toggle),
      KnobSlider(
        label: 'Horizon',
        width: 160,
        value: _horizon,
        min: 0.2,
        max: 0.8,
        format: (double v) => '${(v * 100).round()}%',
        onChanged: (double v) => setState(() => _horizon = v),
      ),
    ],
    hint:
        'With Adaptive on, the bar over the sky turns light with a dark label, and the buttons over the ground stay '
        'dark. Drag the horizon past the card: it follows once the hold is over. Needs the High or Ultra setting, '
        'the default material and the Neutral tint.',
    // The site declares a rich backdrop, which keeps every label at its worst
    // case. The stage is one flat picture per glass, so here the label follows
    // the reading too.
    child: GlassTheme(
      data: GlassTheme.of(context).copyWith(richBackdrop: false),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GlassBar(
              child: Row(
                children: <Widget>[
                  Icon(Icons.arrow_back_ios_new, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Lake Tekapo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.ios_share, size: 20),
                ],
              ),
            ),
          ),
          const Center(
            child: SizedBox(width: 240, child: GlassCard(child: _ReadingReport())),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GlassButton(
                  onPressed: () {},
                  semanticLabel: 'Favourite',
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.favorite_border, size: 20),
                ),
                GlassButton(onPressed: () {}, child: const Text('Directions')),
                GlassButton(
                  onPressed: () {},
                  semanticLabel: 'More',
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.more_horiz, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// What the card it is on read of its backdrop: `GlassTheme.of(context)`
/// inside a component that reads one.
class _ReadingReport extends StatelessWidget {
  const _ReadingReport();

  @override
  Widget build(BuildContext context) {
    final GlassThemeData theme = GlassTheme.of(context);
    final GlassBackdropReading? reading = theme.reading;
    final String finish = theme.finish == GlassFinish.regularLight ? 'regularLight' : 'regularDark';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(finish, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          reading == null
              ? (theme.adaptive == null ? 'Reads nothing: adaptive is off' : 'No reading yet')
              : 'Under it: level ${reading.level.round()} of 255, ${reading.brightness.name}',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

/// A pale sky over a dark ground, the horizon at [horizon] of the height.
class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.horizon);

  final double horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height * horizon;
    final Rect sky = Rect.fromLTRB(0, 0, size.width, y);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF4F8FC), Color(0xFFC9DDF0)],
        ).createShader(sky),
    );
    canvas.drawCircle(Offset(size.width * 0.78, y * 0.55), 26, Paint()..color = const Color(0xFFFFF6D8));
    final ridge = Path()..moveTo(0, y + 18);
    for (var i = 1; i <= 8; i++) {
      ridge.lineTo(size.width * i / 8, y + (i.isEven ? 18 : -10));
    }
    ridge
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF2B3A2E), Color(0xFF0A110C)],
        ).createShader(Rect.fromLTRB(0, y - 10, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) => oldDelegate.horizon != horizon;
}
