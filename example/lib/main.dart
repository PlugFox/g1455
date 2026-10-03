import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import 'src/pages/blobs_page.dart';
import 'src/pages/cards_page.dart';
import 'src/pages/controls_page.dart';
import 'src/pages/kit_page.dart';
import 'src/pages/scroll_page.dart';
import 'src/style.dart';
import 'src/settings_menu.dart';

export 'src/style.dart'
    show ContrastChoice, GlassPreset, GlassSettings, MaterialChoice, RenderingChoice, RippleChoice, TintChoice;

void main() => runApp(const GlassExampleApp());

/// The app, and the one place the host goes: above the navigator
/// (`builder:`), so that a dialog, a sheet or a menu — all built in the
/// navigator's overlay — is captured by it like any other glass.
class GlassExampleApp extends StatefulWidget {
  const GlassExampleApp({super.key});

  @override
  State<GlassExampleApp> createState() => _GlassExampleAppState();
}

class _GlassExampleAppState extends State<GlassExampleApp> {
  // The most the package draws, ripple included: an example is for looking
  // at, and the menu goes down from there.
  GlassSettings _settings = GlassPreset.ultra.settings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glass',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
    builder: (BuildContext context, Widget? child) => GlassHost(
      finish: _settings.finishIn(MediaQuery.platformBrightnessOf(context)),
      tier: _settings.tierChoice,
      highContrast: _settings.highContrast,
      // The opaque rung fills with the level over this, and reads nothing
      // that could tell it otherwise.
      backdrop: kExampleBackdrop,
      // What scrolls under the glass is an image as far as legibility goes:
      // there is no one colour behind a label, so the finish is dimmed until
      // the worst case still reads. Without these, `clear` over this list
      // reaches a contrast of 1.76 and the package says so in debug.
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      // Not Apple's: iOS answers a touch with light and a springy scale and
      // never deforms the glass. On in the Ultra preset only, which is where
      // the example opens.
      ripple: _settings.glassRipple,
      child: child!,
    ),
    home: GlassExampleScreen(
      settings: _settings,
      onSettings: (GlassSettings s) => setState(() => _settings = s),
    ),
  );
}

/// One host over the whole screen, a page under it, and the glass on top: an
/// app bar with a settings menu, and a tab bar between the pages.
///
/// The host is the only thing an application has to add. It captures what is
/// painted under its glass once per frame that changed it — and not at all
/// while nothing under the glass moves — so every surface below it shares one
/// capture instead of taking its own.
class GlassExampleScreen extends StatefulWidget {
  const GlassExampleScreen({required this.settings, required this.onSettings, super.key});

  final GlassSettings settings;
  final ValueChanged<GlassSettings> onSettings;

  @override
  State<GlassExampleScreen> createState() => _GlassExampleScreenState();
}

const List<GlassTabItem> _kTabs = <GlassTabItem>[
  GlassTabItem(icon: Icons.view_agenda, label: 'Scroll'),
  GlassTabItem(icon: Icons.toggle_on, label: 'Controls'),
  GlassTabItem(icon: Icons.bubble_chart, label: 'Blobs'),
  GlassTabItem(icon: Icons.photo, label: 'Cards'),
  GlassTabItem(icon: Icons.widgets, label: 'Kit'),
];

class _GlassExampleScreenState extends State<GlassExampleScreen> {
  // `--dart-define=GLASS_EXAMPLE_TAB=<n>` opens on another page: a screenshot
  // taken from the host needs no touch to get there.
  int _tab = const int.fromEnvironment('GLASS_EXAMPLE_TAB');
  GlassScrollEdgeStyle? _edge = GlassScrollEdgeStyle.soft;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final insets = EdgeInsets.only(top: safe.top + 72, bottom: safe.bottom + 92);
    final double top = safe.top + 64;
    final double bottom = safe.bottom + 76;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: switch (_tab) {
              0 => ScrollPage(insets: insets),
              1 => ControlsPage(insets: insets),
              2 => BlobsPage(insets: insets),
              3 => CardsPage(insets: insets),
              _ => KitPage(insets: insets, edge: _edge, onEdge: (GlassScrollEdgeStyle? e) => setState(() => _edge = e)),
            },
          ),
          // The bars ride on the scroll edge: lifted with it over whatever
          // glass scrolls under them, so they show the cards going under.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _edged(
              GlassScrollEdgeSide.top,
              top,
              Padding(
                padding: EdgeInsets.fromLTRB(16, safe.top + 8, 16, 4),
                child: _AppBar(
                  title: _kTabs[_tab].label,
                  settings: widget.settings,
                  onSettings: widget.onSettings,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _edged(
              GlassScrollEdgeSide.bottom,
              bottom,
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, safe.bottom + 16),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassTabBar(
                    items: _kTabs,
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

  /// The bar on the scroll edge in force, or on nothing — lifted either way,
  /// because the bar has to show the glass cards under it whether or not an
  /// edge effect is drawn there.
  Widget _edged(GlassScrollEdgeSide side, double extent, Widget bar) {
    final GlassScrollEdgeStyle? style = _edge;
    if (style == null) {
      return GlassAbove(
        child: SizedBox(height: extent, child: bar),
      );
    }
    return GlassScrollEdge(side: side, extent: extent, style: style, child: bar);
  }
}

/// The app bar's settings button, which shows the preset in force.
const Key kSettingsButtonKey = ValueKey<String>('settings');

class _AppBar extends StatelessWidget {
  const _AppBar({required this.title, required this.settings, required this.onSettings});

  final String title;
  final GlassSettings settings;
  final ValueChanged<GlassSettings> onSettings;

  @override
  Widget build(BuildContext context) => GlassBar(
    padding: const EdgeInsets.only(left: 16, right: 4),
    child: SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          const Icon(Icons.blur_on),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DefaultTextStyle.of(context).style.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // The settings grow out of the button and stay open while they are
          // changed, as a game's graphics menu does; a tap outside closes
          // them. The popover is in the navigator's overlay, so it stands
          // over the bars, lifted as a modal is.
          GlassPopoverAnchor(
            radius: 26,
            popoverBuilder: (BuildContext context) => GlassSettingsMenu(settings: settings, onChanged: onSettings),
            // Not a glass button: a control inside the bar is glass on
            // glass, and a second capture level for a tap target is a price
            // with nothing to show for it.
            builder: (BuildContext context, GlassMenuController menu) => Semantics(
              button: true,
              label: 'Settings',
              child: GestureDetector(
                key: kSettingsButtonKey,
                behavior: HitTestBehavior.opaque,
                onTap: menu.open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(settings.preset?.label ?? 'Custom'),
                      const SizedBox(width: 6),
                      const Icon(Icons.tune, size: 20),
                    ],
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
