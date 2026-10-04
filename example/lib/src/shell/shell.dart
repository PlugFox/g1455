import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../catalog/catalog.dart';
import '../widgets/icons.dart';
import '../widgets/links.dart';
import 'aurora.dart';
import 'settings_button.dart';

/// Every page of the reference: the ground, a glass side panel with the
/// navigation on a wide window, a glass top bar, and the page scrolling under
/// the bar.
///
/// On a narrow window the side panel folds into a glass sheet behind the
/// menu button. The page is told what the bars cover through [builder]'s
/// insets, and pads its scroll view by them, so it scrolls under the glass
/// rather than stopping at it.
class SiteShell extends StatelessWidget {
  const SiteShell({required this.title, required this.builder, this.current, super.key});

  /// The tab's title, before the site's name.
  final String title;

  /// The page shown, highlighted in the navigation; null on the home page.
  final Entry? current;

  final Widget Function(BuildContext context, EdgeInsets insets) builder;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool wide = size.width >= kSidebarBreakpoint;
    final double barTop = safe.top + 12;
    const double barHeight = 56;
    final double left = wide ? kSidebarWidth + 24 : 0;
    final insets = EdgeInsets.only(top: barTop + barHeight + 12, bottom: safe.bottom + 24);
    return Title(
      title: current == null ? Site.title : '$title · ${Site.name}',
      color: kSiteBackground,
      child: Scaffold(
        backgroundColor: kSiteBackground,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: Aurora()),
            Positioned(
              left: left,
              top: 0,
              right: 0,
              bottom: 0,
              // No selection around the page: the text a reader copies has
              // its own (`SiteSelectionArea`), and a demo, a card or a button
              // is outside every one.
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: builder(context, insets),
              ),
            ),
            // The edge across the whole window, as the package asks, and the
            // bar inset from the side panel inside it: an edge that stopped
            // where the page column starts drew its blur and tint up to a hard
            // vertical line beside the panel.
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: GlassScrollEdge(
                side: GlassScrollEdgeSide.top,
                extent: barTop + barHeight + 4,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(wide ? left : 12, barTop, 12, 0),
                  child: _TopBar(title: title, current: current, wide: wide, height: barHeight),
                ),
              ),
            ),
            if (wide)
              Positioned(
                left: 12,
                top: safe.top + 12,
                bottom: safe.bottom + 12,
                width: kSidebarWidth,
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  child: _Sidebar(current: current),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.current, required this.wide, required this.height});

  final String title;
  final Entry? current;
  final bool wide;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassBar(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: height,
        child: Builder(
          builder: (BuildContext context) {
            final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
            final Entry? entry = current;
            return Row(
              children: <Widget>[
                if (!wide) ...<Widget>[
                  _BarIcon(icon: Icons.menu, tooltip: 'Navigation', onTap: () => _openNavigation(context)),
                  _HomeMark(colour: label),
                ] else
                  const SizedBox(width: 14),
                Expanded(
                  child: _Breadcrumbs(
                    title: wide || entry != null ? title : '',
                    section: wide ? entry?.section : null,
                    style: text.titleMedium?.copyWith(color: label, fontWeight: FontWeight.w600),
                  ),
                ),
                if (size(context) >= 560) ...<Widget>[
                  _BarIcon(
                    icon: Icons.code,
                    tooltip: 'Source on GitHub',
                    onTap: () => openLink(context, Site.repository),
                  ),
                  _BarIcon(
                    icon: Icons.inventory_2_outlined,
                    tooltip: 'Package on pub.dev',
                    onTap: () => openLink(context, Site.pub),
                  ),
                ],
                SettingsButton(compact: size(context) < 420),
              ],
            );
          },
        ),
      ),
    );
  }

  static double size(BuildContext context) => MediaQuery.sizeOf(context).width;

  void _openNavigation(BuildContext context) => showGlassSheet<void>(
    context: context,
    // Frosted: a list of links over a busy page reads only through a blur
    // that heavy.
    finish: GlassFinish.frosted,
    builder: (BuildContext sheet) => SizedBox(
      height: MediaQuery.sizeOf(sheet).height * 0.72,
      child: _NavigationList(
        current: current,
        onOpened: () => Navigator.of(sheet).pop(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      ),
    ),
  );
}

/// Where the page is: its section, a link to the section's first page, and
/// its own title.
class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.title, required this.section, required this.style});

  final String title;

  /// Null on the home page, and on a narrow bar, which has no room for it.
  final Section? section;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final Color colour = style?.color ?? kSiteText;
    final TextStyle? muted = style?.copyWith(color: colour.withValues(alpha: 0.6));
    return Row(
      children: <Widget>[
        if (section case final Section section) ...<Widget>[
          Flexible(
            child: LinkText(text: section.title, url: '/${section.id}', style: muted, maxLines: 1),
          ),
          Text('  /  ', style: muted),
        ],
        Flexible(
          child: Semantics(
            header: true,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        ),
      ],
    );
  }
}

/// The wordmark, which goes home.
class _HomeMark extends StatelessWidget {
  const _HomeMark({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: 'g1455 home',
    excludeSemantics: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openHome(context),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            'g1455',
            style: TextStyle(color: colour, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.4),
          ),
        ),
      ),
    ),
  );
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current});

  final Entry? current;

  @override
  Widget build(BuildContext context) {
    final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
    return Semantics(
      container: true,
      label: 'Navigation',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            link: true,
            label: 'g1455 — Liquid Glass for Flutter, home',
            excludeSemantics: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => openHome(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 16, 14),
                  child: Row(
                    children: <Widget>[
                      const SiteLogo(size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'g1455',
                              style: TextStyle(
                                color: label,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              '${Site.tagline} · v${Site.version}',
                              style: TextStyle(color: label.withValues(alpha: 0.65), fontSize: 12),
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
          Container(height: 1, color: label.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: _NavigationList(current: current, padding: const EdgeInsets.fromLTRB(10, 8, 10, 8)),
          ),
          Container(height: 1, color: label.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: <Widget>[
                LinkText(
                  text: 'GitHub',
                  url: Site.repository,
                  style: TextStyle(fontSize: 13, color: label),
                ),
                LinkText(
                  text: 'pub.dev',
                  url: Site.pub,
                  style: TextStyle(fontSize: 13, color: label),
                ),
                LinkText(
                  text: 'API',
                  url: '${Site.pubApi}g1455-library.html',
                  style: TextStyle(fontSize: 13, color: label),
                ),
                LinkText(
                  text: 'Changelog',
                  url: Site.changelog,
                  style: TextStyle(fontSize: 13, color: label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The site's mark: a drop of glass, as the favicon draws it.
class SiteLogo extends StatelessWidget {
  const SiteLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF6C8CFF), Color(0xFFB04BFF), Color(0xFFFF4F8B)],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x40FFFFFF),
            border: Border.all(color: const Color(0xCCFFFFFF), width: size * 0.05),
          ),
        ),
      ),
    ),
  );
}

/// The sections and their pages, the current one filled and scrolled into
/// view.
class _NavigationList extends StatefulWidget {
  const _NavigationList({required this.current, required this.padding, this.onOpened});

  final Entry? current;
  final EdgeInsets padding;

  /// Called after a page is opened: the sheet closes itself with it.
  final VoidCallback? onOpened;

  @override
  State<_NavigationList> createState() => _NavigationListState();
}

class _NavigationListState extends State<_NavigationList> {
  final GlobalKey _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A page far down the list — a component, on a short window — is shown
    // where it is rather than below the fold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? item = _selected.currentContext;
      if (item != null && item.mounted) {
        Scrollable.ensureVisible(item, alignment: 0.4);
      }
    });
  }

  void _open(VoidCallback navigate) {
    widget.onOpened?.call();
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
    final Entry? current = widget.current;
    return ListView(
      padding: widget.padding,
      children: <Widget>[
        _NavItem(
          key: current == null ? _selected : null,
          title: 'Overview',
          icon: Icons.home_outlined,
          selected: current == null,
          colour: label,
          onTap: () => _open(() => openHome(context)),
        ),
        for (final Section section in Section.values) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
            child: Semantics(
              header: true,
              child: Text(
                section.title.toUpperCase(),
                style: TextStyle(
                  color: label.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          for (final Entry entry in entriesOf(section))
            _NavItem(
              key: entry == current ? _selected : null,
              title: entry.title,
              icon: iconFor(entry.icon),
              selected: entry == current,
              colour: label,
              onTap: () => _open(() => openEntry(context, entry)),
            ),
        ],
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.title,
    super.key,
    required this.icon,
    required this.selected,
    required this.colour,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color colour = widget.colour;
    return Semantics(
      link: true,
      selected: widget.selected,
      label: widget.title,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colour.withValues(alpha: 0.16)
                  : _hover
                  ? colour.withValues(alpha: 0.07)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(widget.icon, size: 19, color: colour.withValues(alpha: widget.selected ? 1 : 0.75)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colour.withValues(alpha: widget.selected ? 1 : 0.85),
                      fontSize: 14,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
