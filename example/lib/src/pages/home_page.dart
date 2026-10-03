import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../backdrops.dart';
import '../catalog/catalog.dart';
import '../shell/shell.dart';
import '../widgets/code_view.dart';
import '../widgets/icons.dart';
import '../widgets/links.dart';
import 'entry_page.dart' show Pill;

/// The front page: what the package is, the glass itself moving, how to get
/// it, and every page of the reference as a card.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => SiteShell(
    title: 'Overview',
    builder: (BuildContext context, EdgeInsets insets) {
      final double width = MediaQuery.sizeOf(context).width;
      final double gutter = width < 600 ? 16 : 32;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, insets.top + 12, gutter, insets.bottom + 24),
        // Its own layer: a scroll moves it rather than repainting it.
        child: RepaintBoundary(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Hero(),
                  const SizedBox(height: 56),
                  const _Principles(),
                  for (final Section section in Section.values) ...<Widget>[
                    const SizedBox(height: 48),
                    _SectionGrid(section: section),
                  ],
                  const SizedBox(height: 56),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double width = MediaQuery.sizeOf(context).width;
    final bool narrow = width < 1100;
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'g1455 · DESIGN SYSTEM · v${Site.version}',
          style: TextStyle(color: kSiteAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6),
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
          'Refraction, blur, tint and a rim over the live backdrop — in the shape the engine already draws. '
          'One capture shared by every surface, and none at all while nothing under the glass moves.',
          style: text.bodyLarge?.copyWith(color: kSiteTextMuted, fontSize: 18),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            GlassButton(
              onPressed: () => openEntry(context, kEntries.first),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[Text('Get started'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
              ),
            ),
            GlassButton(
              onPressed: () => openEntry(context, entriesOf(Section.components).first),
              child: const Text('Components'),
            ),
            Pill(label: 'GitHub', icon: Icons.code, onTap: () => openLink(context, Site.repository)),
            Pill(label: 'pub.dev', icon: Icons.inventory_2_outlined, onTap: () => openLink(context, Site.pub)),
            Pill(
              label: 'v${Site.version}',
              icon: Icons.history,
              monospace: true,
              tooltip: 'Changelog',
              onTap: () => openLink(context, Site.changelog),
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
                              const Icon(Icons.blur_on, size: 20),
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

class _Principles extends StatelessWidget {
  const _Principles();

  static const List<(IconData, String, String)> _items = <(IconData, String, String)>[
    (
      Icons.layers_outlined,
      'One host, one capture',
      'A GlassHost records what is under all of its glass into one atlas. Every surface samples its own slot of it '
          '— no BackdropFilter per surface.',
    ),
    (
      Icons.pause_circle_outline,
      'A capture only when something changed',
      'Nothing under the glass moved? The host keeps the proxy it has. A still screen, or glass moving over still '
          'content, costs no capture at all.',
    ),
    (
      Icons.blur_on,
      'The blur is a downscale',
      'A 1/N proxy is a Gaussian of σ ≈ N/2 to within about 1%, at a fraction of the price of a real Gaussian.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
    return _Grid(
      columns: columns,
      children: <Widget>[
        for (final (IconData icon, String title, String body) in _items)
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Builder(
              builder: (BuildContext context) {
                final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icon, size: 26, color: label),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(color: label, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(body, style: TextStyle(color: label.withValues(alpha: 0.78), fontSize: 14.5, height: 1.5)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.section});

  final Section section;

  static const Map<Section, String> _blurbs = <Section, String>{
    Section.start: 'Install the package, put one host over the screen, and know what it is doing.',
    Section.foundations: 'The material, the host that captures for it, and the rules every surface follows.',
    Section.components: 'Bars, buttons, controls and modals, each live with its guide, its code and its API.',
    Section.demos: 'Whole screens of glass, full screen, with the settings menu in the corner.',
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 1300 ? 3 : (width >= 640 ? 2 : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(section.title, style: text.headlineMedium?.copyWith(color: kSiteText)),
        ),
        const SizedBox(height: 6),
        Text(_blurbs[section]!, style: text.bodyLarge?.copyWith(color: kSiteTextMuted)),
        const SizedBox(height: 18),
        _Grid(
          columns: columns,
          children: <Widget>[for (final Entry e in entriesOf(section)) _EntryCard(entry: e)],
        ),
      ],
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
                  child: Icon(iconFor(entry.icon), color: kSiteAccent, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  entry.title,
                  style: const TextStyle(color: kSiteText, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(entry.summary, style: const TextStyle(color: kSiteTextMuted, fontSize: 14, height: 1.5)),
              ],
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
          LinkText(text: 'GitHub', url: Site.repository, icon: Icons.code),
          LinkText(text: 'pub.dev', url: Site.pub, icon: Icons.inventory_2_outlined),
          LinkText(text: 'API reference', url: '${Site.pubApi}g1455-library.html', icon: Icons.menu_book_outlined),
          LinkText(text: 'Changelog', url: Site.changelog, icon: Icons.history),
          LinkText(text: 'Issues', url: Site.issues, icon: Icons.bug_report_outlined),
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
