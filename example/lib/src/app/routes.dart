import 'package:flutter/material.dart';
import 'package:squid/squid.dart';

import '../catalog/catalog.dart';
import '../pages/demo_screen.dart';
import '../pages/entry_page.dart';
import '../pages/home_page.dart';
import '../pages/not_found_page.dart';

/// A screen of the site, and the address it has in the browser.
///
/// The stack is what squid navigates; the address is what the browser
/// shows. [uri] goes one way and [stackFromUri] the other, so any stack the
/// app reaches can be opened again from its link.
sealed class AppRoute with NavigationRoute {
  const AppRoute();

  /// The address of this screen: path and query, no origin.
  Uri get uri;

  // A short fade, not a slide: every page carries the same bars and side
  // panel, so a cross-fade changes only what differs.
  @override
  Page<Object?> page(BuildContext context) => _FadePage(key: key, name: uri.toString(), child: build(context));
}

final class HomeRoute extends AppRoute {
  const HomeRoute();

  @override
  String get name => 'home';

  @override
  Uri get uri => Uri(path: '/');

  @override
  Widget build(BuildContext context) => const HomePage();
}

/// The tabs of an [EntryPage], as the `tab` query parameter names them.
enum EntryTab {
  guide('Guide'),
  code('Code'),
  api('API');

  const EntryTab(this.label);

  final String label;

  static EntryTab parse(String? value) => EntryTab.values.firstWhere(
    (EntryTab t) => t.name == value,
    orElse: () => EntryTab.guide,
  );
}

final class EntryRoute extends AppRoute {
  const EntryRoute(this.entry, {this.tab = EntryTab.guide});

  final Entry entry;
  final EntryTab tab;

  @override
  String get name => 'entry';

  // The tab is not in the key: switching it updates the page in place and
  // keeps the demo's state, rather than building a new page.
  @override
  LocalKey get key => ValueKey<String>('entry:${entry.path}');

  @override
  Map<String, Object?> get arguments => <String, Object?>{'path': entry.path, 'tab': tab.name};

  @override
  Uri get uri => Uri(
    path: entry.path,
    queryParameters: tab == EntryTab.guide ? null : <String, String>{'tab': tab.name},
  );

  @override
  Widget build(BuildContext context) => EntryPage(entry: entry, tab: tab);
}

/// One of the example app's full-screen pages, with its tab bar.
final class DemoRoute extends AppRoute {
  const DemoRoute(this.tab);

  /// The index into [kDemoEntries].
  final int tab;

  @override
  String get name => 'demo';

  @override
  LocalKey get key => const ValueKey<String>('demo');

  @override
  Uri get uri => Uri(path: kDemoEntries[tab].path);

  @override
  Widget build(BuildContext context) => DemoScreen(tab: tab);
}

final class NotFoundRoute extends AppRoute {
  const NotFoundRoute(this.path);

  final String path;

  @override
  String get name => 'not-found';

  @override
  LocalKey get key => ValueKey<String>('404:$path');

  @override
  Uri get uri => Uri(path: path);

  @override
  Widget build(BuildContext context) => NotFoundPage(path: path);
}

/// The stack an address opens: the home page under whatever it names, so
/// back from a deep link is home rather than out of the app.
NavigationStack stackFromUri(Uri uri) {
  final List<String> segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
  return switch (segments) {
    [] => const <NavigationRoute>[HomeRoute()],
    [final String section] when section == Section.demos.id => const <NavigationRoute>[HomeRoute(), DemoRoute(0)],
    // A section on its own opens its first page.
    [final String id] => <NavigationRoute>[
      const HomeRoute(),
      switch (Section.values.where((Section s) => s.id == id).firstOrNull) {
        final Section section => EntryRoute(entriesOf(section).first),
        null => NotFoundRoute(uri.path),
      },
    ],
    [final String section, final String id] when section == Section.demos.id => <NavigationRoute>[
      const HomeRoute(),
      switch (kDemoEntries.indexWhere((Entry e) => e.id == id)) {
        -1 => NotFoundRoute(uri.path),
        final int i => DemoRoute(i),
      },
    ],
    [final String section, final String id] => <NavigationRoute>[
      const HomeRoute(),
      switch (findEntry(section, id)) {
        final Entry entry => EntryRoute(entry, tab: EntryTab.parse(uri.queryParameters['tab'])),
        null => NotFoundRoute(uri.path),
      },
    ],
    _ => <NavigationRoute>[const HomeRoute(), NotFoundRoute(uri.path)],
  };
}

/// Opens [entry]: the home page under it, as a link to it would.
void openEntry(BuildContext context, Entry entry, {EntryTab tab = EntryTab.guide}) {
  context.navigation.stack = <NavigationRoute>[
    const HomeRoute(),
    if (entry.section == Section.demos) DemoRoute(kDemoEntries.indexOf(entry)) else EntryRoute(entry, tab: tab),
  ];
}

/// Opens the home page.
void openHome(BuildContext context) => context.navigation.stack = const <NavigationRoute>[HomeRoute()];

class _FadePage extends Page<Object?> {
  const _FadePage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<Object?> createRoute(BuildContext context) => PageRouteBuilder<Object?>(
    settings: this,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
        (ModalRoute.of(context)!.settings as _FadePage).child,
    transitionsBuilder:
        (BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) =>
            FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
  );
}
