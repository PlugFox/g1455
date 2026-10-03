/// Whether a newer build of the site has been deployed than the one running,
/// and how to get onto it.
///
/// The service worker (package `sw`, `sw.yaml`) serves the app from its cache,
/// so a deploy reaches a tab only once a new worker has installed and taken
/// over — and a site that is one page and never navigates gives the browser no
/// occasion to look for one. The web side asks: the worker on a timer and when
/// the tab comes back, and `version.json` beside it, which is fetched past
/// every cache and names the build that is live.
///
/// Through `dart:js_interop` on the web (`site_update_web.dart`); null
/// everywhere else, where nothing is cached and nothing is deployed.
library;

import 'package:flutter/foundation.dart';

export 'site_update_stub.dart' if (dart.library.js_interop) 'site_update_web.dart' show watchSiteUpdates;

/// The build this is, as `tool/build_web.sh` names it; empty in a build that
/// script did not make, which then compares itself with nothing.
const String kSiteVersion = String.fromEnvironment('SITE_VERSION');

/// Watches for a newer build; notifies once, when one is found.
abstract interface class SiteUpdates implements Listenable {
  /// A newer build is deployed, or already installed and waiting.
  bool get available;

  /// Moves the tab onto the newer build: hands control to the waiting worker
  /// if there is one, and otherwise drops the worker and its caches. Then
  /// reloads. Does not return in a page that reloads.
  Future<void> apply();

  void dispose();
}
