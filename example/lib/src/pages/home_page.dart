import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../backdrops.dart';
import '../catalog/catalog.dart';
import '../shell/shell.dart';
import '../widgets/code_view.dart';
import '../widgets/icons.dart';
import '../widgets/links.dart';
import '../widgets/side_scroller.dart';
import 'home_showcase.dart';
import '../widgets/site_icon.dart';

/// The front page: what the package is, the glass itself moving, a gallery
/// of glass in app-like scenes, and every page of the reference as a card.
///
/// One sliver list, and every run of cards in it a builder: only what is on
/// screen, and a little past it, is built — a scene scrolled away is
/// disposed with its glass, and the host stops capturing for it.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// The widest the page's column is set.
  static const double maxWidth = 1100;

  @override
  Widget build(BuildContext context) => SiteShell(
    title: 'Overview',
    builder: (BuildContext context, EdgeInsets insets) => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double gutter = width < 600 ? 16 : 32;
        final double side = math.max(gutter, (width - maxWidth) / 2);
        final double column = width - side * 2;
        EdgeInsets band(double top) => EdgeInsets.fromLTRB(side, top, side, 0);
        return CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: band(insets.top + 12),
              sliver: SliverToBoxAdapter(child: _Hero(width: column)),
            ),
            SliverPadding(
              padding: band(48),
              sliver: const SliverToBoxAdapter(child: _WhatsNew()),
            ),
            SliverPadding(
              padding: band(56),
              sliver: const SliverToBoxAdapter(
                child: _Heading(
                  title: 'Made of glass',
                  blurb: 'Real screens, live. Tap, drag and scroll them — every scene opens its component.',
                ),
              ),
            ),
            SliverPadding(padding: band(18), sliver: const _Gallery()),
            SliverPadding(
              padding: band(56),
              sliver: SliverToBoxAdapter(child: _Principles(width: column)),
            ),
            for (final Section section in Section.values) ...<Widget>[
              SliverPadding(
                padding: band(56),
                sliver: SliverToBoxAdapter(
                  child: _Heading(title: section.title, blurb: _SectionGrid.blurbs[section]!),
                ),
              ),
              SliverPadding(
                padding: band(18),
                sliver: _SectionGrid(section: section, width: column),
              ),
            ],
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 56, side, insets.bottom + 24),
              sliver: const SliverToBoxAdapter(child: _Footer()),
            ),
          ],
        );
      },
    ),
  );
}

/// A section's title and the line under it.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.blurb});

  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: text.headlineMedium?.copyWith(color: kSiteText)),
        ),
        const SizedBox(height: 6),
        Text(blurb, style: text.bodyLarge?.copyWith(color: kSiteTextMuted)),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.width});

  /// The page's column.
  final double width;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool narrow = width < 900;
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The version is the changelog's link: one line, where a pill of its
        // own made the row of buttons under it wrap.
        Row(
          children: <Widget>[
            const Flexible(
              child: Text(
                'g1455 · DESIGN SYSTEM · ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kSiteAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6),
              ),
            ),
            Tooltip(
              message: 'What is new: the changelog',
              child: LinkText(
                text: 'v${Site.version}',
                url: Site.changelog,
                style: const TextStyle(
                  color: kSiteAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            'Liquid Glass\nfor Flutter',
            style: (width < 600 ? text.displaySmall : text.displayMedium)?.copyWith(
              color: kSiteText,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Glass that bends, blurs and glows over whatever is behind it: photos, maps, video, your own UI. '
          'Bars, buttons, sliders, tab bars, sheets and menus, as in iOS 26 — and fast enough to scroll.',
          style: text.bodyLarge?.copyWith(color: kSiteTextMuted, fontSize: 18),
        ),
        const SizedBox(height: 24),
        // Two words and two icons: one line on a phone of 360 points. The
        // links out are icons the reader knows, named by their tooltips.
        Wrap(
          spacing: width < 600 ? 6 : 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            GlassButton(
              padding: EdgeInsets.symmetric(horizontal: width < 600 ? 14 : 20, vertical: 10),
              onPressed: () => openEntry(context, kEntries.first),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Get started'),
                  SizedBox(width: 6),
                  SiteIcon(SFIcons.sf_chevron_right, size: 16),
                ],
              ),
            ),
            GlassButton(
              padding: EdgeInsets.symmetric(horizontal: width < 600 ? 14 : 20, vertical: 10),
              onPressed: () => openEntry(context, entriesOf(Section.components).first),
              child: const Text('Components'),
            ),
            Tooltip(
              message: 'GitHub: the source',
              child: GlassButton(
                semanticLabel: 'GitHub',
                padding: const EdgeInsets.all(10),
                onPressed: () => openLink(context, Site.repository),
                child: const SiteIcon(SFIcons.sf_chevron_left_forwardslash_chevron_right, size: 18),
              ),
            ),
            Tooltip(
              message: 'pub.dev: the package',
              child: GlassButton(
                semanticLabel: 'pub.dev',
                padding: const EdgeInsets.all(10),
                onPressed: () => openLink(context, Site.pub),
                child: const SiteIcon(SFIcons.sf_shippingbox, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const CodeView(code: 'flutter pub add g1455', language: 'bash', title: 'install'),
      ],
    );
    // Moving every frame: on a layer of its own, off the page's.
    const Widget stage = RepaintBoundary(child: _HeroStage());
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          copy,
          const SizedBox(height: 32),
          const SizedBox(height: 340, child: stage),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(flex: 5, child: copy),
        const SizedBox(width: 40),
        const Expanded(flex: 5, child: SizedBox(height: 480, child: stage)),
      ],
    );
  }
}

/// Glass that moves: blobs orbiting and fusing over a grid, a bar across
/// them, and one blob that follows the pointer.
class _HeroStage extends StatefulWidget {
  const _HeroStage();

  @override
  State<_HeroStage> createState() => _HeroStageState();
}

class _HeroStageState extends State<_HeroStage> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 18))
    ..repeat();
  Offset? _pointer;

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  // Out of the page's selection, as a demo stage is: a drag here moves a blob.
  Widget build(BuildContext context) => Semantics(
    label: 'Live glass: blobs that fuse as they orbit over a grid. Move the pointer over them.',
    child: SelectionContainer.disabled(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            return MouseRegion(
              onHover: (PointerHoverEvent e) => setState(() => _pointer = e.localPosition),
              onExit: (_) => setState(() => _pointer = null),
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails d) => setState(() => _pointer = d.localPosition),
                onPanEnd: (_) => setState(() => _pointer = null),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const RepaintBoundary(child: GridBackdrop(hue: 200)),
                    GlassTravel(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _orbit,
                          builder: (BuildContext context, Widget? _) => GlassGroup(
                            spacing: 36,
                            labelled: false,
                            finish: GlassFinish.clear,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                for (var i = 0; i < 4; i++) _blob(i, size),
                                _circle(_pointer ?? _rest(size), 52),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: GlassBar(
                        child: SizedBox(
                          height: 40,
                          child: Row(
                            children: <Widget>[
                              const SiteIcon(SFIcons.sf_circle_hexagongrid, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('GlassBar over a live backdrop', overflow: TextOverflow.ellipsis),
                              ),
                              Text('g1455', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Offset _rest(Size size) {
    final double t = _orbit.value * 2 * math.pi;
    return Offset(size.width * (0.5 + 0.22 * math.cos(t * 2)), size.height * (0.42 + 0.12 * math.sin(t * 3)));
  }

  Widget _blob(int i, Size size) {
    final double t = _orbit.value * 2 * math.pi;
    final double speed = (i.isEven ? 1 : -1) * (1 + i % 2);
    final double a = t * speed + i * 1.7;
    final Offset centre = Offset(size.width / 2, size.height * 0.42);
    final Offset at = centre + Offset(math.cos(a) * size.width * 0.24, math.sin(a) * size.height * 0.2);
    return _circle(at, 44 + 12.0 * (i % 3));
  }

  Widget _circle(Offset centre, double radius) => Positioned(
    left: centre.dx - radius,
    top: centre.dy - radius,
    width: radius * 2,
    height: radius * 2,
    child: const GlassSurface(borderRadius: kGlassCapsule, labelled: false),
  );
}

/// What is new in this release, as a row of links that scrolls sideways.
class _WhatsNew extends StatelessWidget {
  const _WhatsNew();

  static const List<(String, String, String, IconData, List<Color>)> _items =
      <(String, String, String, IconData, List<Color>)>[
        (
          'components',
          'morph',
          'A button that flows into a menu',
          SFIcons.sf_wand_and_sparkles,
          <Color>[
            Color(0xFFFF375F),
            Color(0xFFFF9F0A),
          ],
        ),
        (
          'foundations',
          'adaptive',
          'Glass that reads what is under it',
          SFIcons.sf_circle_lefthalf_filled,
          <Color>[
            Color(0xFF5E5CE6),
            Color(0xFF64D2FF),
          ],
        ),
        (
          'foundations',
          'drop-motion',
          'Drops that stretch and squash',
          SFIcons.sf_drop,
          <Color>[
            Color(0xFF30D158),
            Color(0xFF64D2FF),
          ],
        ),
        (
          'components',
          'scaffold',
          'A whole glass screen in one widget',
          SFIcons.sf_rectangle_3_group,
          <Color>[
            Color(0xFFBF5AF2),
            Color(0xFFFF375F),
          ],
        ),
        (
          'components',
          'tab-bar',
          'Tab icons and badges of your own',
          SFIcons.sf_menubar_dock_rectangle,
          <Color>[
            Color(0xFF0A84FF),
            Color(0xFF5E5CE6),
          ],
        ),
        (
          'start',
          'installation',
          'Shaders ready before the first frame',
          SFIcons.sf_bolt_fill,
          <Color>[
            Color(0xFFFFD60A),
            Color(0xFFFF9F0A),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // A page the catalog does not have is left out rather than linked dead.
    final List<(Entry, String, IconData, List<Color>)> items = <(Entry, String, IconData, List<Color>)>[
      for (final (String section, String id, String line, IconData icon, List<Color> colours) in _items)
        if (findEntry(section, id) case final Entry entry) (entry, line, icon, colours),
    ];
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'NEW IN THIS RELEASE',
          style: TextStyle(color: kSiteAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6),
        ),
        const SizedBox(height: 12),
        SideScroller(
          height: 36 + 72 * scale,
          arrows: MediaQuery.sizeOf(context).width >= 600,
          itemCount: items.length,
          itemBuilder: (BuildContext context, int i) {
            final (Entry entry, String line, IconData icon, List<Color> colours) = items[i];
            return _NewCard(entry: entry, line: line, icon: icon, colours: colours);
          },
        ),
      ],
    );
  }
}

class _NewCard extends StatefulWidget {
  const _NewCard({required this.entry, required this.line, required this.icon, required this.colours});

  final Entry entry;
  final String line;
  final IconData icon;
  final List<Color> colours;

  @override
  State<_NewCard> createState() => _NewCardState();
}

class _NewCardState extends State<_NewCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: '${widget.entry.title}: ${widget.line}',
    excludeSemantics: true,
    child: SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => openEntry(context, widget.entry),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 250,
            padding: const EdgeInsets.all(16),
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  for (final Color c in widget.colours) c.withValues(alpha: _hover ? 0.32 : 0.2),
                ],
              ),
              border: Border.all(color: widget.colours.first.withValues(alpha: _hover ? 0.8 : 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: widget.colours),
                  ),
                  child: SiteIcon(widget.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kSiteText, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kSiteTextMuted, fontSize: 13, height: 1.35),
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
  );
}

/// The gallery: a grid of live scenes, built as they scroll into view.
class _Gallery extends StatelessWidget {
  const _Gallery();

  static const double _stage = 360;

  @override
  Widget build(BuildContext context) {
    final double caption = MediaQuery.textScalerOf(context).scale(1) * 64 + 20;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 560,
        mainAxisSpacing: 28,
        crossAxisSpacing: 20,
        mainAxisExtent: _stage + caption,
      ),
      itemCount: kShowcases.length,
      itemBuilder: (BuildContext context, int i) => _ShowcaseTile(showcase: kShowcases[i], stage: _stage),
    );
  }
}

class _ShowcaseTile extends StatelessWidget {
  const _ShowcaseTile({required this.showcase, required this.stage});

  final Showcase showcase;
  final double stage;

  @override
  Widget build(BuildContext context) {
    final Entry? entry = findEntry(showcase.section, showcase.page);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: stage,
          child: Semantics(
            container: true,
            label: showcase.semantics,
            explicitChildNodes: true,
            // Out of the page's selection, as a demo stage is: a drag here
            // moves a slider or scrolls a chat.
            child: SelectionContainer.disabled(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: kSiteLine),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  // A scene repaints its own layer, not the page's.
                  child: RepaintBoundary(
                    child: Material(type: MaterialType.transparency, child: showcase.builder(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Caption(showcase: showcase, entry: entry),
      ],
    );
  }
}

class _Caption extends StatefulWidget {
  const _Caption({required this.showcase, required this.entry});

  final Showcase showcase;
  final Entry? entry;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Entry? entry = widget.entry;
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                widget.showcase.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _hover ? kSiteAccent : kSiteText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (entry != null) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· ${entry.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kSiteTextMuted, fontSize: 14),
                ),
              ),
              const SizedBox(width: 4),
              SiteIcon(SFIcons.sf_chevron_right, size: 16, color: _hover ? kSiteAccent : kSiteTextMuted),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.showcase.blurb,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kSiteTextMuted, fontSize: 14, height: 1.4),
        ),
      ],
    );
    if (entry == null) {
      return text;
    }
    return Semantics(
      link: true,
      label: '${widget.showcase.title}: open ${entry.title}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => openEntry(context, entry), child: text),
      ),
    );
  }
}

/// Why it is fast, in three cards on glass.
class _Principles extends StatelessWidget {
  const _Principles({required this.width});

  final double width;

  static const List<(IconData, String, String, Color)> _items = <(IconData, String, String, Color)>[
    (
      SFIcons.sf_square_3_layers_3d,
      'One look for the whole screen',
      'Every piece of glass shares one snapshot of what is behind it. Ten panels cost about what one does.',
      Color(0xFF64D2FF),
    ),
    (
      SFIcons.sf_pause_circle,
      'Free while nothing moves',
      'A still screen takes no new snapshot at all, and glass gliding over still content does not either.',
      Color(0xFF30D158),
    ),
    (
      SFIcons.sf_slider_horizontal_3,
      'Turn it down, not off',
      'Thermal state, low-end GPUs and reduce transparency get a cheaper rung of the same look.',
      Color(0xFFFF9F0A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final int columns = width >= 900 ? 3 : (width >= 600 ? 2 : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Heading(
          title: 'Fast by design',
          blurb: 'Glass is expensive when done naively. Here is what this package does instead.',
        ),
        const SizedBox(height: 18),
        _Grid(
          columns: columns,
          children: <Widget>[
            for (final (IconData icon, String title, String body, Color colour) in _items)
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Builder(
                  builder: (BuildContext context) {
                    final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colour.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SiteIcon(icon, size: 24, color: colour),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: TextStyle(color: label, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: TextStyle(color: label.withValues(alpha: 0.78), fontSize: 14.5, height: 1.5),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A section's pages as cards, built as they scroll into view.
class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.section, required this.width});

  final Section section;
  final double width;

  static const Map<Section, String> blurbs = <Section, String>{
    Section.start: 'Install the package, put one host over the screen, and know what it is doing.',
    Section.foundations: 'The material, the host that captures for it, and the rules every surface follows.',
    Section.components: 'Bars, buttons, controls and modals, each live with its guide, its code and its API.',
    Section.demos: 'Whole screens of glass, full screen, with the settings menu in the corner.',
  };

  @override
  Widget build(BuildContext context) {
    final List<Entry> entries = entriesOf(section).toList();
    final int columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
    // The cards are one height, set for three lines of summary at the
    // reader's text size: a sliver grid lays out cells it has not built.
    final double extent = 112 + MediaQuery.textScalerOf(context).scale(1) * 84;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: extent,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int i) => _EntryCard(entry: entries[i]),
    );
  }
}

/// Rows of [columns] equal cells, each row as tall as its tallest card.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var row = 0; row < children.length; row += columns)
        Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var c = 0; c < columns; c++) ...<Widget>[
                  if (c > 0) const SizedBox(width: 14),
                  Expanded(child: row + c < children.length ? children[row + c] : const SizedBox()),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

class _EntryCard extends StatefulWidget {
  const _EntryCard({required this.entry});

  final Entry entry;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Entry entry = widget.entry;
    return Semantics(
      link: true,
      label: '${entry.title}. ${entry.summary}',
      excludeSemantics: true,
      child: SelectionContainer.disabled(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () => openEntry(context, entry),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(20),
              transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
              decoration: BoxDecoration(
                color: _hover ? const Color(0x1A8AB4FF) : const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _hover ? const Color(0x668AB4FF) : kSiteLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x268AB4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SiteIcon(iconFor(entry.icon), color: kSiteAccent, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kSiteText, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  // Loose: a card one line short ends its summary early rather
                  // than overflowing.
                  Flexible(
                    child: Text(
                      entry.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kSiteTextMuted, fontSize: 14, height: 1.5),
                    ),
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Container(height: 1, color: kSiteLine),
      const SizedBox(height: 20),
      Wrap(
        spacing: 20,
        runSpacing: 8,
        children: <Widget>[
          LinkText(text: 'GitHub', url: Site.repository, icon: SFIcons.sf_chevron_left_forwardslash_chevron_right),
          LinkText(text: 'pub.dev', url: Site.pub, icon: SFIcons.sf_shippingbox),
          LinkText(text: 'API reference', url: '${Site.pubApi}g1455-library.html', icon: SFIcons.sf_book),
          LinkText(
            text: 'Changelog',
            url: Site.changelog,
            icon: SFIcons.sf_clock_arrow_trianglehead_counterclockwise_rotate_90,
          ),
          LinkText(text: 'Issues', url: Site.issues, icon: SFIcons.sf_ladybug),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'MIT licensed. This site is the package\'s example app, built with Flutter for the web: '
        'navigation by squid, the guides by flutter_md.',
        style: TextStyle(color: kSiteTextMuted, fontSize: 13),
      ),
    ],
  );
}
