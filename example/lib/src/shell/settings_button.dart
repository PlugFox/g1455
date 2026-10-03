import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/app.dart';
import '../settings_menu.dart';
import '../style.dart';

/// The app bar's settings button, which shows the preset in force.
const Key kSettingsButtonKey = ValueKey<String>('settings');

/// The preset in force, and the settings menu growing out of it.
///
/// The settings grow out of the button and stay open while they are
/// changed, as a game's graphics menu does; a tap outside closes them. The
/// popover is in the navigator's overlay, so it stands over the bars, lifted
/// as a modal is.
class SettingsButton extends StatelessWidget {
  const SettingsButton({this.compact = false, super.key});

  /// The icon alone, without the preset's name.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final SettingsScope scope = SettingsScope.of(context);
    final GlassSettings settings = scope.settings;
    return GlassPopoverAnchor(
      radius: 26,
      popoverBuilder: (BuildContext context) => _LiveMenu(onChanged: scope.onChanged),
      // Not a glass button: a control inside the bar is glass on glass, and a
      // second capture level for a tap target is a price with nothing to
      // show for it.
      builder: (BuildContext context, GlassMenuController menu) => Tooltip(
        message: 'Glass settings',
        child: Semantics(
          button: true,
          label: 'Glass settings: ${settings.preset?.label ?? 'Custom'}',
          excludeSemantics: true,
          child: GestureDetector(
            key: kSettingsButtonKey,
            behavior: HitTestBehavior.opaque,
            onTap: menu.open,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!compact) ...<Widget>[Text(settings.preset?.label ?? 'Custom'), const SizedBox(width: 6)],
                    const Icon(Icons.tune, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu, reading the settings from the scope so that it follows a
/// change while it is open — the popover is built once, in the overlay.
class _LiveMenu extends StatelessWidget {
  const _LiveMenu({required this.onChanged});

  final ValueChanged<GlassSettings> onChanged;

  @override
  Widget build(BuildContext context) =>
      GlassSettingsMenu(settings: SettingsScope.of(context).settings, onChanged: onChanged);
}
