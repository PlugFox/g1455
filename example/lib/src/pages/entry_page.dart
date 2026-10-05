import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:squid/squid.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../catalog/catalog.dart';
import '../demos/demos.dart';
import '../shell/shell.dart';
import '../widgets/code_view.dart';
import '../widgets/doc_view.dart';
import '../widgets/icons.dart';
import '../widgets/links.dart';
import '../widgets/selection.dart';
import '../widgets/side_scroller.dart';
import '../widgets/site_icon.dart';

/// A page of the reference: what the thing is, the thing itself, live, and
/// then the guide, the code and the API — one tab each, the tab in the
/// address (`?tab=code`), so a link can open on any of them.
class EntryPage extends StatelessWidget {
  const EntryPage({required this.entry, required this.tab, super.key});

  final Entry entry;
  final EntryTab tab;

  List<EntryTab> get _tabs => <EntryTab>[
    EntryTab.guide,
    if (entry.code != null) EntryTab.code,
    if (entry.properties != null || entry.api.isNotEmpty) EntryTab.api,
  ];

  @override
  Widget build(BuildContext context) {
    final List<EntryTab> tabs = _tabs;
    final EntryTab shown = tabs.contains(tab) ? tab : EntryTab.guide;
    final Widget? demo = demoFor(entry);
    final double width = MediaQuery.sizeOf(context).width;
    final double gutter = width < 600 ? 16 : 32;
    return SiteShell(
      title: entry.title,
      current: entry,
      builder: (BuildContext context, EdgeInsets insets) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, insets.top + 12, gutter, insets.bottom + 24),
        // Its own layer: a scroll moves it rather than repainting it.
        child: RepaintBoundary(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(entry: entry),
                  if (demo != null) ...<Widget>[const SizedBox(height: 28), demo],
                  const SizedBox(height: 32),
                  if (tabs.length > 1) ...<Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 120.0 * tabs.length),
                        child: GlassSegmentedControl(
                          segments: <Widget>[for (final EntryTab t in tabs) Text(t.label)],
                          selectedIndex: tabs.indexOf(shown),
                          onSelected: (int i) => context.navigation.replaceTop(EntryRoute(entry, tab: tabs[i])),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey<EntryTab>(shown),
                      child: switch (shown) {
                        EntryTab.guide => DocView(markdown: entry.guide),
                        EntryTab.code => _CodeTab(entry: entry),
                        EntryTab.api => _ApiTab(entry: entry),
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  _Neighbours(entry: entry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The words select; the pills under them are buttons.
        SiteSelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SiteIcon(iconFor(entry.icon), size: 18, color: kSiteAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LinkText(
                        text: entry.section.title.toUpperCase(),
                        url: '/${entry.section.id}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: kSiteAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SelectionContainer.disabled(child: _Actions(entry: entry)),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text(
                  entry.title,
                  style: (narrow ? text.headlineMedium : text.displaySmall)?.copyWith(color: kSiteText),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(entry.summary, style: text.bodyLarge?.copyWith(color: kSiteTextMuted, fontSize: 18)),
              ),
            ],
          ),
        ),
        if (entry.api.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          // Every name the page covers, on one line that scrolls: they are what
          // a reader looks up, and wrapped they took two or three lines.
          SizedBox(
            width: double.infinity,
            child: SideScroller(
              height: 34 * MediaQuery.textScalerOf(context).scale(1) + 2,
              spacing: 8,
              arrows: !narrow,
              itemCount: entry.api.length,
              itemBuilder: (BuildContext context, int i) => Center(
                child: Pill(
                  label: entry.api[i],
                  icon: SFIcons.sf_book,
                  monospace: true,
                  tooltip: 'API reference on pub.dev',
                  onTap: () => openLink(context, Site.api(entry.api[i])),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The page's own actions, an icon each: the source, the demo's source, and
/// the page's link.
class _Actions extends StatelessWidget {
  const _Actions({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (entry.source case final String source) ...<Widget>[
        Pill(
          label: 'Source',
          icon: SFIcons.sf_chevron_left_forwardslash_chevron_right,
          iconOnly: true,
          tooltip: 'Source: $source',
          onTap: () => openLink(context, Site.source(source)),
        ),
        const SizedBox(width: 6),
      ],
      if (hasDemo(entry)) ...<Widget>[
        Pill(
          label: 'Demo source',
          icon: SFIcons.sf_play_circle,
          iconOnly: true,
          tooltip: 'Demo source: ${entry.demoSource}',
          onTap: () => openLink(context, Site.source(entry.demoSource)),
        ),
        const SizedBox(width: 6),
      ],
      Pill(
        label: 'Copy link',
        icon: SFIcons.sf_link,
        iconOnly: true,
        tooltip: 'Copy a link to this page',
        onTap: () => copyLink(context, entry.path),
      ),
    ],
  );
}

/// A small outlined button: a link out, or a page action.
///
/// [iconOnly] draws [icon] alone in a round button, for an action whose icon
/// says it; [label] is then what a screen reader says, and the tooltip
/// ([tooltip], or [label] without one).
class Pill extends StatefulWidget {
  const Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.tooltip,
    this.monospace = false,
    this.iconOnly = false,
    super.key,
  }) : assert(!iconOnly || icon != null, 'an icon-only pill needs its icon');

  final String label;
  final IconData? icon;
  final String? tooltip;
  final bool monospace;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Widget pill = Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: SelectionContainer.disabled(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: widget.iconOnly
                  ? const EdgeInsets.all(9)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _hover ? const Color(0x1F8AB4FF) : kSiteFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _hover ? const Color(0x668AB4FF) : kSiteLine),
              ),
              child: widget.iconOnly
                  ? SiteIcon(widget.icon, size: 16, color: kSiteAccent)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          SiteIcon(widget.icon, size: 16, color: kSiteAccent),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kSiteText,
                              fontSize: 13,
                              fontFamily: widget.monospace ? 'monospace' : null,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    final String? tip = widget.tooltip ?? (widget.iconOnly ? widget.label : null);
    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}

class _CodeTab extends StatelessWidget {
  const _CodeTab({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      CodeView(code: entry.code!, title: '${entry.id.replaceAll('-', '_')}_example.dart'),
      const SizedBox(height: 12),
      if (hasDemo(entry))
        Align(
          alignment: Alignment.centerLeft,
          child: LinkText(
            text: 'The demo above, in full: ${entry.demoSource}',
            url: Site.source(entry.demoSource),
            icon: SFIcons.sf_arrow_up_right_square,
            style: const TextStyle(fontSize: 14),
          ),
        ),
    ],
  );
}

class _ApiTab extends StatelessWidget {
  const _ApiTab({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final buffer = StringBuffer();
    if (entry.properties case final String properties) {
      buffer
        ..writeln(properties.trim())
        ..writeln();
    }
    if (entry.api.isNotEmpty) {
      buffer
        ..writeln('## Reference')
        ..writeln()
        ..writeln('Every name on this page, in the package\'s API documentation on pub.dev:')
        ..writeln();
      for (final String symbol in entry.api) {
        buffer.writeln('- [`$symbol`](${Site.api(symbol)})');
      }
    }
    if (entry.source case final String source) {
      buffer
        ..writeln()
        ..writeln('Declared in [`$source`](${Site.source(source)}).');
    }
    return DocView(markdown: buffer.toString());
  }
}

/// The page before and the page after, in the order of the navigation.
class _Neighbours extends StatelessWidget {
  const _Neighbours({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final (Entry? previous, Entry? next) = neighboursOf(entry);
    final bool narrow = MediaQuery.sizeOf(context).width < 600;
    final List<Widget> cards = <Widget>[
      if (previous != null) Expanded(child: _NeighbourCard(entry: previous, forward: false)),
      if (previous != null && next != null) const SizedBox(width: 12, height: 12),
      if (next != null) Expanded(child: _NeighbourCard(entry: next, forward: true)),
    ];
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[for (final Widget c in cards) c is Expanded ? c.child : c],
      );
    }
    return Row(
      children: <Widget>[
        if (previous == null) const Spacer(),
        ...cards,
      ],
    );
  }
}

class _NeighbourCard extends StatefulWidget {
  const _NeighbourCard({required this.entry, required this.forward});

  final Entry entry;
  final bool forward;

  @override
  State<_NeighbourCard> createState() => _NeighbourCardState();
}

class _NeighbourCardState extends State<_NeighbourCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool forward = widget.forward;
    return Semantics(
      link: true,
      label: '${forward ? 'Next' : 'Previous'}: ${widget.entry.title}',
      excludeSemantics: true,
      child: SelectionContainer.disabled(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () => openEntry(context, widget.entry),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _hover ? const Color(0x148AB4FF) : kSiteFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _hover ? const Color(0x668AB4FF) : kSiteLine),
              ),
              child: Column(
                crossAxisAlignment: forward ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    forward ? 'Next' : 'Previous',
                    style: const TextStyle(color: kSiteTextMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (!forward) const SiteIcon(SFIcons.sf_chevron_left, size: 18, color: kSiteAccent),
                      if (!forward) const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.entry.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kSiteText, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (forward) const SizedBox(width: 8),
                      if (forward) const SiteIcon(SFIcons.sf_chevron_right, size: 18, color: kSiteAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
