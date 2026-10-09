import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';
import '../widgets/stage.dart';

/// Badges where an app puts them: on a tab through `iconBuilder`, and on a
/// toolbar icon, with a stepper on the stage to change the count.
class BadgeDemo extends StatefulWidget {
  const BadgeDemo({super.key});

  @override
  State<BadgeDemo> createState() => _BadgeDemoState();
}

enum _Kind {
  count('Count'),
  dot('Dot'),
  label('Label');

  const _Kind(this.title);

  final String title;
}

class _BadgeDemoState extends State<BadgeDemo> {
  int _unread = 3;
  int _tab = 0;
  _Kind _kind = _Kind.count;

  /// The badge on [child], as the knob says.
  Widget _badge(Widget child) => switch (_kind) {
    _Kind.count => GlassBadge(count: _unread, semanticLabel: '$_unread unread', child: child),
    _Kind.dot => GlassBadge(isVisible: _unread > 0, semanticLabel: 'Unread', child: child),
    _Kind.label => GlassBadge(label: 'New', isVisible: _unread > 0, child: child),
  };

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 380,
    background: const GridBackdrop(hue: 200),
    knobs: <Widget>[
      KnobChoice<_Kind>(
        label: 'Badge',
        values: _Kind.values,
        selected: _kind,
        labelOf: (_Kind k) => k.title,
        onChanged: (_Kind k) => setState(() => _kind = k),
      ),
    ],
    hint:
        'Step the count: past 99 it reads "99+", and at 0 it is gone. The badge is an opaque capsule on the glass, '
        'not glass, so it costs no surface.',
    child: Stack(
      children: <Widget>[
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            children: <Widget>[
              GlassButtonGroup(
                items: <GlassToolbarItem>[
                  GlassToolbarItem(
                    icon: _badge(const SiteIcon(SFIcons.sf_bell)),
                    label: 'Notifications',
                    onPressed: () => setState(() => _unread = 0),
                  ),
                  GlassToolbarItem(
                    icon: const SiteIcon(SFIcons.sf_square_and_pencil),
                    label: 'Compose',
                    onPressed: () => setState(() => _unread++),
                  ),
                ],
              ),
              const Spacer(),
              GlassStepper(
                value: _unread.toDouble(),
                max: 120,
                semanticLabel: 'Unread',
                onChanged: (double v) => setState(() => _unread = v.round()),
              ),
            ],
          ),
        ),
        Center(
          child: Text(
            '$_unread unread',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              shadows: <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 12)],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SizedBox(
                width: double.infinity,
                child: GlassTabBar(
                  items: <GlassTabItem>[
                    GlassTabItem(
                      label: 'Mail',
                      iconBuilder: (BuildContext context, GlassTabItemLook look) =>
                          _badge(SiteIcon(SFIcons.sf_envelope_fill, color: look.color, size: look.iconSize)),
                    ),
                    const GlassTabItem(icon: SFIcons.sf_person_2_fill, label: 'Contacts'),
                    const GlassTabItem(icon: SFIcons.sf_gearshape_fill, label: 'Settings'),
                  ],
                  selectedIndex: _tab,
                  onSelected: (int i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
