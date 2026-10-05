import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:squid/squid.dart';

import '../platform/web_client.dart';
import '../style.dart';
import '../widgets/quality_notice.dart';
import '../widgets/update_banner.dart';
import 'router.dart';
import 'routes.dart';
import 'theme.dart';

/// Whether the site's host reads the backdrop under its glass, and how: null,
/// the default, for glass that goes by what is declared.
///
/// Set only by the page that shows it (`/foundations/adaptive`), while that
/// page is open. Not a second host inside that page's demo: one mounted inside
/// this one, at an offset, drew its glass black and read nothing.
final ValueNotifier<GlassAdaptive?> siteAdaptive = ValueNotifier<GlassAdaptive?>(null);

/// The app, and the one place the host goes: above the navigator
/// (`builder:`), so that a dialog, a sheet or a menu — all built in the
/// navigator's overlay — is captured by it like any other glass.
class GlassExampleApp extends StatefulWidget {
  const GlassExampleApp({
    this.initialLocation,
    this.opensReduced = kOpensReduced,
    this.webClient = readWebClient,
    this.noticeClosed = readNoticeClosed,
    this.onNoticeClosed = writeNoticeClosed,
    super.key,
  });

  /// The address to open at; null for the one the platform was opened at.
  final String? initialLocation;

  /// Whether to open on Medium and say why — [kOpensReduced], which a test
  /// cannot reach otherwise: it is a constant, and false off the web.
  final bool opensReduced;

  /// Reads the browser and the device the site is open in — [readWebClient],
  /// which a test cannot steer: it answers null off the web.
  final WebClient? Function() webClient;

  /// When the site's notice was last closed, and how a close is kept —
  /// [readNoticeClosed] and [writeNoticeClosed], `localStorage` on the web.
  final DateTime? Function() noticeClosed;
  final ValueChanged<DateTime> onNoticeClosed;

  @override
  State<GlassExampleApp> createState() => _GlassExampleAppState();
}

class _GlassExampleAppState extends State<GlassExampleApp> {
  // The most the package draws, ripple included: an example is for looking
  // at, and the menu goes down from there. Medium where the browser draws
  // with CanvasKit, which pays for every capture with a GPU readback; a sheet
  // says so on the first frame (see [kOpensReduced]).
  late GlassSettings _settings = widget.opensReduced ? GlassPreset.medium.settings : GlassPreset.ultra.settings;

  final NavigatorObserver _navigator = NavigatorObserver();

  late final NavigationController _navigation = NavigationController(
    const <NavigationRoute>[HomeRoute()],
    // Home is always at the bottom: back from anything ends there.
    guards: <NavigationGuard>[RootGuard(() => const HomeRoute())],
    debugLabel: 'site',
  );

  late final AppRouterDelegate _delegate = AppRouterDelegate(_navigation, observers: <NavigatorObserver>[_navigator]);

  @override
  void initState() {
    super.initState();
    final WebClient? client = widget.webClient();
    // Once a day at most: closed less than [kNoticeQuiet] ago, it stays closed.
    // Only a close counts — a reload with the sheet still open shows it again.
    // A close dated in the future — a clock set ahead then, or a stored value
    // gone wrong — is not trusted: it would keep the notice away until then.
    final DateTime now = DateTime.now();
    final DateTime? closed = widget.noticeClosed();
    final bool quiet = closed != null && !closed.isAfter(now) && now.difference(closed) < kNoticeQuiet;
    if (!quiet && needsSiteNotice(reduced: widget.opensReduced, client: client)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_notice(client)));
    }
  }

  Future<void> _notice(WebClient? client) async {
    final BuildContext? context = _navigator.navigator?.context;
    if (context == null || !mounted) {
      return;
    }
    // Closed by any of its buttons, the barrier or a drag: the sheet's route
    // completes only when it is popped.
    await showSiteNotice(
      context,
      reduced: widget.opensReduced,
      client: client,
      onFullGlass: () => setState(() => _settings = _settings.withPreset(GlassPreset.high)),
    );
    widget.onNoticeClosed(DateTime.now());
  }

  late final RouterConfig<Uri> _router = appRouterConfig(_delegate, initial: widget.initialLocation);

  @override
  void dispose() {
    _delegate.dispose();
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'g1455 · Liquid Glass for Flutter',
    debugShowCheckedModeBanner: false,
    theme: buildSiteTheme(),
    color: kSiteBackground,
    routerConfig: _router,
    // The appearance in the settings stands in for the platform's below here:
    // the host's `.regular` and every demo that picks a branch of it read it.
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        platformBrightness: _settings.appearance.brightness ?? MediaQuery.platformBrightnessOf(context),
      ),
      child: SettingsScope(
        settings: _settings,
        onChanged: (GlassSettings s) => setState(() => _settings = s),
        child: ValueListenableBuilder<GlassAdaptive?>(
          valueListenable: siteAdaptive,
          builder: (BuildContext context, GlassAdaptive? adaptive, Widget? _) => GlassHost(
            adaptive: adaptive,
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
            // Over every route: a deploy since this tab loaded is offered here.
            child: SiteUpdateBanner(child: child!),
          ),
        ),
      ),
    ),
  );
}

/// The settings in force, and how to change them, for whatever below shows
/// the settings menu.
class SettingsScope extends InheritedWidget {
  const SettingsScope({required this.settings, required this.onChanged, required super.child, super.key});

  final GlassSettings settings;
  final ValueChanged<GlassSettings> onChanged;

  static SettingsScope of(BuildContext context) {
    final SettingsScope? scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'no SettingsScope above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) => oldWidget.settings != settings;
}
