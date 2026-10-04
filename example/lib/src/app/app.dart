import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:squid/squid.dart';

import '../style.dart';
import '../widgets/quality_notice.dart';
import '../widgets/update_banner.dart';
import 'router.dart';
import 'routes.dart';
import 'theme.dart';

/// The app, and the one place the host goes: above the navigator
/// (`builder:`), so that a dialog, a sheet or a menu — all built in the
/// navigator's overlay — is captured by it like any other glass.
class GlassExampleApp extends StatefulWidget {
  const GlassExampleApp({this.initialLocation, this.opensReduced = kOpensReduced, super.key});

  /// The address to open at; null for the one the platform was opened at.
  final String? initialLocation;

  /// Whether to open on Medium and say why — [kOpensReduced], which a test
  /// cannot reach otherwise: it is a constant, and false off the web.
  final bool opensReduced;

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
    if (widget.opensReduced) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _noticeReduced());
    }
  }

  void _noticeReduced() {
    final BuildContext? context = _navigator.navigator?.context;
    if (context == null || !mounted) {
      return;
    }
    showReducedQualityNotice(
      context,
      onFullGlass: () => setState(() => _settings = GlassPreset.high.settings),
    );
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
    builder: (BuildContext context, Widget? child) => SettingsScope(
      settings: _settings,
      onChanged: (GlassSettings s) => setState(() => _settings = s),
      child: GlassHost(
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
