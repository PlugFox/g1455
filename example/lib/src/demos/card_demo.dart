import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A weather widget on a glass card, over a photo.
class CardDemo extends StatefulWidget {
  const CardDemo({super.key});

  @override
  State<CardDemo> createState() => _CardDemoState();
}

/// The finishes the demo offers, by the name its knob shows. "Default" is the
/// host's own choice.
const Map<String, GlassFinish?> _kFinishes = <String, GlassFinish?>{
  'Default': null,
  'Clear': GlassFinish.clear,
  'Regular': GlassFinish.regularDark,
  'Frosted': GlassFinish.frosted,
};

const List<(String, IconData, int)> _kHours = <(String, IconData, int)>[
  ('Now', SFIcons.sf_sun_max_fill, 21),
  ('14', SFIcons.sf_sun_max_fill, 23),
  ('15', SFIcons.sf_cloud_fill, 24),
  ('16', SFIcons.sf_cloud_fill, 22),
  ('17', SFIcons.sf_drop_fill, 19),
];

class _CardDemoState extends State<CardDemo> {
  String _finish = 'Default';
  double _radius = 28;
  int _photo = 5;

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 380,
    background: PhotoBackdrop(seed: _photo),
    hint: 'Switch the finish: Clear shows the most of the photo, Frosted the least. Tap the photo for another one.',
    knobs: <Widget>[
      KnobChoice<String>(
        label: 'Finish',
        values: _kFinishes.keys.toList(),
        selected: _finish,
        onChanged: (String f) => setState(() => _finish = f),
      ),
      KnobSlider(
        label: 'Radius',
        value: _radius,
        max: 40,
        width: 140,
        format: (double v) => v.round().toString(),
        onChanged: (double v) => setState(() => _radius = v),
      ),
    ],
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _photo = (_photo + 1) % 12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: GlassCard(
              finish: _kFinishes[_finish],
              borderRadius: BorderRadius.all(Radius.circular(_radius)),
              padding: const EdgeInsets.all(20),
              child: const _Weather(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Weather extends StatelessWidget {
  const _Weather();

  @override
  Widget build(BuildContext context) {
    final Color? ink = DefaultTextStyle.of(context).style.color;
    final TextStyle muted = TextStyle(fontSize: 13, color: ink?.withValues(alpha: 0.7));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Lisbon',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 4),
                      SiteIcon(SFIcons.sf_location_fill, size: 14),
                    ],
                  ),
                  Text('21°', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300, height: 1.1)),
                ],
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const SiteIcon(SFIcons.sf_sun_max_fill, size: 28, color: Color(0xFFFFD60A)),
                  const SizedBox(height: 6),
                  const Text(
                    'Mostly sunny',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text('H:24°  L:16°', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(height: 0.5, color: ink?.withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (final (String hour, IconData icon, int temp) in _kHours)
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(hour, maxLines: 1, style: muted),
                    const SizedBox(height: 6),
                    SiteIcon(icon, size: 20),
                    const SizedBox(height: 6),
                    Text('$temp°', maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
