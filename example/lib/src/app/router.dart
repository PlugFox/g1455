import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:squid/squid.dart';

import 'routes.dart';

/// Squid's stack behind Flutter's [Router], so the stack and the address
/// bar are one thing.
///
/// Squid has no URL layer of its own: it is a list of routes. The router is
/// the part that talks to the browser — an address typed or opened from a
/// link becomes a stack through [stackFromUri], a change to the stack is
/// reported back as the top route's [AppRoute.uri] and becomes a history
/// entry, and the browser's back and forward come in as addresses again.
class AppRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  AppRouterDelegate(this.controller, {this.observers = const <NavigatorObserver>[]}) {
    controller.addListener(notifyListeners);
  }

  final NavigationController controller;

  /// Handed to the navigator: the app reaches it through one, to show a
  /// sheet over whatever page is open.
  final List<NavigatorObserver> observers;

  @override
  Uri get currentConfiguration => switch (controller.top) {
    final AppRoute route => route.uri,
    _ => Uri(path: '/'),
  };

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    controller.stack = stackFromUri(configuration);
    return SynchronousFuture<void>(null);
  }

  @override
  Future<bool> popRoute() => controller.maybePop();

  // Not reported by the view: it would report a route's name, not its path,
  // and in a single-entry history. The router reports the address instead.
  @override
  Widget build(BuildContext context) => NavigationView(controller: controller, observers: observers);

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    super.dispose();
  }
}

class AppRouteParser extends RouteInformationParser<Uri> {
  const AppRouteParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) => SynchronousFuture<Uri>(routeInformation.uri);

  @override
  RouteInformation restoreRouteInformation(Uri configuration) => RouteInformation(uri: configuration);
}

/// The router over [delegate], opening at [initial] — the address the
/// browser was opened at, unless a test names another.
RouterConfig<Uri> appRouterConfig(AppRouterDelegate delegate, {String? initial}) => RouterConfig<Uri>(
  routeInformationProvider: PlatformRouteInformationProvider(
    initialRouteInformation: RouteInformation(
      uri: Uri.parse(initial ?? WidgetsBinding.instance.platformDispatcher.defaultRouteName),
    ),
  ),
  routeInformationParser: const AppRouteParser(),
  routerDelegate: delegate,
  // None: the navigation view already answers the system's back button.
);
