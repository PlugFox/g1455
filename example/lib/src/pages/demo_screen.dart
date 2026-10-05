import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../catalog/catalog.dart';
import '../playground/blobs_page.dart';
import '../playground/cards_page.dart';
import '../playground/controls_page.dart';
import '../playground/kit_page.dart';
import '../playground/scroll_page.dart';
import '../shell/settings_button.dart';
import '../widgets/icons.dart';
import '../widgets/site_icon.dart';

/// One screen of glass over a page, full screen: an app bar with the
/// settings menu, and a tab bar between the pages — the example app as it
/// was before it became a reference, at `/demos/<page>`.
class DemoScreen extends StatefulWidget {
  const DemoScreen({required this.tab, super.key});

  /// The index into [kDemoEntries].
  final int tab;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

final List<GlassTabItem> _kTabs = <GlassTabItem>[
  for (final Entry e in kDemoEntries) GlassTabItem(icon: iconFor(e.icon), label: e.title),
];

class _DemoScreenState extends State<DemoScreen> {
  GlassScrollEdgeStyle? _edge = GlassScrollEdgeStyle.soft;

  void _select(int i) {
    if (i != widget.tab) {
      // Replaced, not pushed: the tabs are one screen, and back leaves it.
      openEntry(context, kDemoEntries[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final insets = EdgeInsets.only(top: safe.top + 72, bottom: safe.bottom + 92);
    final double top = safe.top + 64;
    final double bottom = safe.bottom + 76;
    final Entry entry = kDemoEntries[widget.tab];
    return Title(
      title: '${entry.title} demo · ${Site.name}',
      color: kSiteBackground,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: switch (widget.tab) {
                0 => ScrollPage(insets: insets),
                1 => ControlsPage(insets: insets),
                2 => BlobsPage(insets: insets),
                3 => CardsPage(insets: insets),
                _ => KitPage(
                  insets: insets,
                  edge: _edge,
                  onEdge: (GlassScrollEdgeStyle? e) => setState(() => _edge = e),
                ),
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _AppBar(title: entry.title),
                    ),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: GlassTabBar(items: _kTabs, selectedIndex: widget.tab, onSelected: _select),
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

class _AppBar extends StatelessWidget {
  const _AppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => GlassBar(
    padding: const EdgeInsets.only(left: 4, right: 4),
    child: SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          Tooltip(
            message: 'Back to the docs',
            child: Semantics(
              button: true,
              label: 'Back to the docs',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openHome(context),
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: SiteIcon(SFIcons.sf_chevron_left),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DefaultTextStyle.of(context).style.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SettingsButton(),
        ],
      ),
    ),
  );
}
