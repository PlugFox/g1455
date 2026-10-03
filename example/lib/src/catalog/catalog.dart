/// What the site is about, as data: every page, its words and its links.
///
/// Plain Dart, no Flutter: `tool/site.dart` reads the same list to write the
/// static pages crawlers and link previews see, the sitemap and the
/// redirects, so a page added here is added everywhere at once.
library;

import 'entries/components.dart';
import 'entries/foundations.dart';
import 'entries/start.dart';
import 'g1455.pubspec.yaml.g.dart';

/// Where the site lives, and where the package does.
abstract final class Site {
  static const String name = 'g1455';
  static const String title = 'g1455 · Liquid Glass for Flutter';
  static const String tagline = 'Liquid Glass for Flutter';
  static const String description =
      'The g1455 design system: Liquid Glass for Flutter — refraction, blur, tint and a rim over the live '
      'backdrop. Every component live, with its guide, its code and its API.';
  static const String origin = 'https://g1455.plugfox.dev';
  static const String repository = 'https://github.com/PlugFox/g1455';
  static const String pub = 'https://pub.dev/packages/g1455';
  static const String pubApi = 'https://pub.dev/documentation/g1455/latest/g1455/';
  static const String changelog = 'https://pub.dev/packages/g1455/changelog';
  static const String issues = 'https://github.com/PlugFox/g1455/issues';

  /// The version of the package this site documents — the package's, read
  /// from its `pubspec.yaml` by pubspec_generator, not the example app's.
  /// `tool/build_web.sh` generates it again on every build.
  static String get version => Pubspec.version.representation;

  /// A file of the repository on GitHub, at the default branch.
  static String source(String path) => '$repository/blob/master/$path';

  /// The dartdoc page of an exported name: `GlassSlider`, `showGlassDialog()`,
  /// `kGlassCapsule`, `debugPaintGlassSurfaces`, or a named constructor such as
  /// `GlassTextField.search`.
  static String api(String symbol) {
    if (symbol.endsWith('()')) {
      return '$pubApi${symbol.substring(0, symbol.length - 2)}.html';
    }
    if (symbol.contains('.')) {
      return '$pubApi${symbol.split('.').first}/$symbol.html';
    }
    if (symbol.startsWith('k') && symbol.length > 1 && symbol[1].toUpperCase() == symbol[1]) {
      return '$pubApi$symbol-constant.html';
    }
    // A top-level variable, such as `debugPaintGlassSurfaces`: no suffix.
    if (symbol[0].toLowerCase() == symbol[0]) {
      return '$pubApi$symbol.html';
    }
    // dartdoc names an enum's page without the `-class` suffix.
    return _enums.contains(symbol) ? '$pubApi$symbol.html' : '$pubApi$symbol-class.html';
  }

  static const Set<String> _enums = <String>{
    'GlassContentDeclaration',
    'GlassHardware',
    'GlassLoadVerdict',
    'GlassProxyRole',
    'GlassScrollEdgeAppearance',
    'GlassScrollEdgeSide',
    'GlassScrollEdgeStyle',
    'GlassSurfaceCostModel',
    'GlassThermalState',
    'GlassTier',
    'GlassTierReason',
    'ProxyBlurPass',
    'ProxyCostModel',
    'ProxyDivisorReason',
    'RetakeReason',
  };
}

/// A part of the navigation, and the first segment of its pages' paths.
enum Section {
  start('start', 'Getting started'),
  foundations('foundations', 'Foundations'),
  components('components', 'Components'),
  demos('demos', 'Demos');

  const Section(this.id, this.title);

  final String id;
  final String title;
}

/// One page of the reference: a component, a foundation or a guide.
final class Entry {
  const Entry({
    required this.section,
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.guide,
    this.api = const <String>[],
    this.source,
    this.code,
    this.properties,
  });

  final Section section;

  /// The last segment of the path: `/components/<id>`.
  final String id;

  final String title;

  /// One or two sentences: the card on the home page, the page's meta
  /// description and its link preview.
  final String summary;

  /// A Material icon, by the name `lib/src/widgets/icons.dart` maps.
  final String icon;

  /// The guide, in markdown. Fenced ```dart blocks are drawn as code views.
  final String guide;

  /// The exported names the page is about, each linked to its dartdoc:
  /// `GlassSlider`, `showGlassDialog()`, `kGlassCapsule`.
  final List<String> api;

  /// The package file the names are declared in, relative to the repository.
  final String? source;

  /// A complete example to copy, in Dart: the "Code" tab.
  final String? code;

  /// The constructor's parameters as a markdown table: the "API" tab.
  final String? properties;

  String get path => '/${section.id}/$id';

  /// The demo file of this page in the repository, if it has one.
  String get demoSource => 'example/lib/src/demos/${id.replaceAll('-', '_')}_demo.dart';
}

/// The full-screen demos: the example app's original pages.
const List<Entry> kDemoEntries = <Entry>[
  Entry(
    section: Section.demos,
    id: 'scroll',
    title: 'Scroll',
    icon: 'view_agenda',
    summary: 'A list scrolling under glass bars, a slider and a lens to drag across the content.',
    guide: '',
  ),
  Entry(
    section: Section.demos,
    id: 'controls',
    title: 'Controls',
    icon: 'toggle_on',
    summary: 'Switches, sliders and buttons on glass cards, over a backdrop they repaint.',
    guide: '',
  ),
  Entry(
    section: Section.demos,
    id: 'blobs',
    title: 'Blobs',
    icon: 'bubble_chart',
    summary: 'Metaballs: glass blobs that fuse into one silhouette as they orbit.',
    guide: '',
  ),
  Entry(
    section: Section.demos,
    id: 'cards',
    title: 'Cards',
    icon: 'photo',
    summary: 'A photo grid with a glass caption on every photo — many surfaces, one capture.',
    guide: '',
  ),
  Entry(
    section: Section.demos,
    id: 'kit',
    title: 'Kit',
    icon: 'widgets',
    summary: 'Segmented controls, search, toolbars, alerts, sheets and menus on glass cards.',
    guide: '',
  ),
];

/// Every page but the home page, in the order of the navigation.
const List<Entry> kEntries = <Entry>[...kStartEntries, ...kFoundationEntries, ...kComponentEntries, ...kDemoEntries];

/// The pages of [section], in order.
Iterable<Entry> entriesOf(Section section) => kEntries.where((Entry e) => e.section == section);

/// The page at `/<section>/<id>`, or null.
Entry? findEntry(String section, String id) {
  for (final Entry e in kEntries) {
    if (e.section.id == section && e.id == id) {
      return e;
    }
  }
  return null;
}

/// The page before and after [entry] in reading order, demos excluded.
(Entry?, Entry?) neighboursOf(Entry entry) {
  final List<Entry> docs = kEntries.where((Entry e) => e.section != Section.demos).toList();
  final int i = docs.indexOf(entry);
  if (i < 0) {
    return (null, null);
  }
  return (i > 0 ? docs[i - 1] : null, i < docs.length - 1 ? docs[i + 1] : null);
}
