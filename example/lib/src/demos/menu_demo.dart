import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A note's "…" button opening a glass menu, a second button opening the same
/// menu through its controller, and the row last chosen.
class MenuDemo extends StatefulWidget {
  const MenuDemo({super.key});

  @override
  State<MenuDemo> createState() => _MenuDemoState();
}

class _MenuDemoState extends State<MenuDemo> {
  final GlassMenuController _menu = GlassMenuController();
  bool _icons = true;
  bool _pinEnabled = false;
  double _width = kGlassMenuWidth;
  String _last = 'nothing yet';

  void _say(String what) => setState(() => _last = what);

  Widget? _icon(IconData icon) => _icons ? SiteIcon(icon, size: 20) : null;

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    knobs: <Widget>[
      KnobSwitch(label: 'Icons', value: _icons, onChanged: (bool v) => setState(() => _icons = v)),
      KnobSwitch(label: '“Pin” enabled', value: _pinEnabled, onChanged: (bool v) => setState(() => _pinEnabled = v)),
      KnobSlider(
        width: 140,
        label: 'Width',
        value: _width,
        min: 200,
        max: 300,
        format: (double v) => v.round().toString(),
        onChanged: (double v) => setState(() => _width = v),
      ),
    ],
    hint: 'Tap “…”: the menu grows out of the button, over it. Tap outside, or choose a row, to close it.',
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Trip to Lisbon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    shadows: <Shadow>[Shadow(blurRadius: 8)],
                  ),
                ),
              ),
              GlassMenuAnchor(
                controller: _menu,
                width: _width,
                items: <GlassMenuItem>[
                  GlassMenuItem(label: 'Rename', icon: _icon(SFIcons.sf_pencil), onPressed: () => _say('rename')),
                  GlassMenuItem(
                    label: 'Duplicate',
                    icon: _icon(SFIcons.sf_document_on_document),
                    onPressed: () => _say('duplicate'),
                  ),
                  GlassMenuItem(
                    label: 'Pin',
                    icon: _icon(SFIcons.sf_pin),
                    // Null disables the row.
                    onPressed: _pinEnabled ? () => _say('pin') : null,
                  ),
                  GlassMenuItem(
                    label: 'Share',
                    icon: _icon(SFIcons.sf_square_and_arrow_up),
                    onPressed: () => _say('share'),
                  ),
                  GlassMenuItem(
                    label: 'Delete',
                    icon: _icon(SFIcons.sf_trash),
                    isDestructive: true,
                    onPressed: () => _say('delete'),
                  ),
                ],
                builder: (BuildContext context, GlassMenuController menu) => GlassButton(
                  onPressed: menu.open,
                  semanticLabel: 'More actions',
                  padding: EdgeInsets.zero,
                  child: const SiteIcon(SFIcons.sf_ellipsis),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: DecoratedBox(
              decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x99000000)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Chosen: $_last',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const Spacer(),
          Center(
            // The same menu, opened from outside its builder.
            child: GlassButton(onPressed: _menu.open, child: const Text('Open with the controller')),
          ),
        ],
      ),
    ),
  );
}
