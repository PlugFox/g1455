import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// The four calibrated finishes side by side over one backdrop, in a tint
/// of the visitor's choice.
class FinishesDemo extends StatefulWidget {
  const FinishesDemo({super.key});

  @override
  State<FinishesDemo> createState() => _FinishesDemoState();
}

enum _Tint {
  neutral('Neutral', null),
  indigo('Indigo', Color(0xFF28348C)),
  rose('Rose', Color(0xFF962850)),
  teal('Teal', Color(0xFF0F6E6E));

  const _Tint(this.label, this.colour);

  final String label;
  final Color? colour;
}

enum _Backdrop { grid, photo }

const List<(String, GlassFinish)> _kFinishes = <(String, GlassFinish)>[
  ('regularDark', GlassFinish.regularDark),
  ('regularLight', GlassFinish.regularLight),
  ('clear', GlassFinish.clear),
  ('frosted', GlassFinish.frosted),
];

class _FinishesDemoState extends State<FinishesDemo> {
  _Tint _tint = _Tint.neutral;
  _Backdrop _backdrop = _Backdrop.grid;
  bool _text = false;

  /// [finish] in the chosen tint, at the finish's own alpha and name, so the
  /// measured tables still apply.
  GlassFinish _tinted(GlassFinish finish) => switch (_tint.colour) {
    null => finish,
    final Color c => finish.copyWith(tint: c.withValues(alpha: finish.tint.a)),
  };

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    background: switch (_backdrop) {
      _Backdrop.grid => const GridBackdrop(),
      _Backdrop.photo => const PhotoBackdrop(seed: 11),
    },
    knobs: <Widget>[
      KnobChoice<_Tint>(
        label: 'Tint',
        values: _Tint.values,
        selected: _tint,
        labelOf: (_Tint t) => t.label,
        onChanged: (_Tint t) => setState(() => _tint = t),
      ),
      KnobChoice<_Backdrop>(
        label: 'Backdrop',
        values: _Backdrop.values,
        selected: _backdrop,
        labelOf: (_Backdrop b) => b == _Backdrop.grid ? 'Grid' : 'Photo',
        onChanged: (_Backdrop b) => setState(() => _backdrop = b),
      ),
      KnobSwitch(label: 'Text on glass', value: _text, onChanged: (bool v) => setState(() => _text = v)),
    ],
    hint:
        'One backdrop, four materials. Turn on text: each card picks black or white, and clear glass '
        'is dimmed until its label reads.',
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double pad = 16;
        const double gap = 12;
        const double caption = 24;
        final int columns = constraints.maxWidth >= 560 ? 4 : 2;
        final int rows = (_kFinishes.length / columns).ceil();
        final double width = (constraints.maxWidth - pad * 2 - gap * (columns - 1)) / columns;
        final double height = ((constraints.maxHeight - pad * 2 - gap * (rows - 1)) / rows - caption).clamp(60, 200);
        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final (String name, GlassFinish finish) in _kFinishes)
                SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(height: height, child: _panel(_tinted(finish))),
                      SizedBox(
                        height: caption,
                        child: Center(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              shadows: <Shadow>[Shadow(blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _panel(GlassFinish finish) {
    if (!_text) {
      // No text: keep the finish exactly as named.
      return GlassSurface(finish: finish, labelled: false);
    }
    return GlassCard(
      finish: finish,
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SiteIcon(SFIcons.sf_sun_max, size: 22),
          Spacer(),
          Text('21°', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          Text('Sunny', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
