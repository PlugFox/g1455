import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'site_update.dart';

// The corners of the DOM this reads, as extension types: no package:web, and
// nothing typed that is not used.

@JS('navigator.serviceWorker')
external _Workers? get _workers;

@JS('Bootstrap')
external _Bootstrap? get _bootstrap;

@JS('document')
external _Document get _document;

@JS('caches')
external _Caches? get _caches;

@JS('location')
external _Location get _location;

@JS('fetch')
external JSPromise<_Response> _fetch(String url, JSAny init);

extension type _Workers._(JSObject _) implements JSObject {
  external _Worker? get controller;
  external JSPromise<_Registration?> getRegistration();
  external JSPromise<JSArray<_Registration>> getRegistrations();
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _Registration._(JSObject _) implements JSObject {
  external _Worker? get installing;
  external _Worker? get waiting;
  external JSPromise<JSAny?> update();
  external JSPromise<JSBoolean> unregister();
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _Worker._(JSObject _) implements JSObject {
  external String get state;
  external void postMessage(JSAny message);
  external void addEventListener(String type, JSFunction listener);
}

/// `bootstrap.js`'s own API (package `sw`): it hears a worker install while
/// the loader is still up, before this app exists to listen.
extension type _Bootstrap._(JSObject _) implements JSObject {
  external JSFunction onUpdateAvailable(JSFunction handler);
}

extension type _Document._(JSObject _) implements JSObject {
  external String get visibilityState;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _Caches._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSString>> keys();
  external JSPromise<JSBoolean> delete(String name);
}

extension type _Location._(JSObject _) implements JSObject {
  external void reload();
}

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSAny?> json();
}

/// How often a tab that stays open looks for a deploy, and how soon after the
/// last look a tab coming back to the front looks again.
const Duration _kEvery = Duration(minutes: 20);
const Duration _kAgainAfter = Duration(minutes: 2);

/// How long a waiting worker gets to take control before the tab reloads
/// anyway: the reload then goes through the old one, and the bootstrap hands
/// over to the waiting one on the way in.
const Duration _kHandover = Duration(seconds: 3);

SiteUpdates? watchSiteUpdates() => _WebSiteUpdates().._start();

final class _WebSiteUpdates extends ChangeNotifier implements SiteUpdates {
  @override
  bool available = false;

  _Registration? _registration;
  Timer? _timer;
  DateTime _checked = DateTime.now();
  bool _disposed = false;
  final List<void Function()> _off = <void Function()>[];

  Future<void> _start() async {
    final _Bootstrap? bootstrap = _bootstrap;
    if (bootstrap != null) {
      final JSFunction unsubscribe = bootstrap.onUpdateAvailable(_signal.toJS);
      _off.add(() => unsubscribe.callAsFunction());
    }

    final JSFunction visible = ((JSAny? _) {
      if (_document.visibilityState == 'visible' && DateTime.now().difference(_checked) > _kAgainAfter) {
        unawaited(_check());
      }
    }).toJS;
    _document.addEventListener('visibilitychange', visible);
    _off.add(() => _document.removeEventListener('visibilitychange', visible));
    _timer = Timer.periodic(_kEvery, (_) => unawaited(_check()));

    final _Workers? workers = _workers;
    if (workers != null) {
      try {
        _registration = await workers.getRegistration().toDart;
      } on Object {
        _registration = null;
      }
      final _Registration? registration = _registration;
      if (_disposed || registration == null) {
        return;
      }
      // Installed while the loader was up and before the handler above was
      // registered, or on a visit before this one and never let take over.
      if (registration.waiting != null && workers.controller != null) {
        _signal();
      }
      final JSFunction installing = ((JSAny? _) => _follow(registration.installing)).toJS;
      registration.addEventListener('updatefound', installing);
      _off.add(() => registration.removeEventListener('updatefound', installing));
      _follow(registration.installing);
    }
    // The first look at once: a tab opened from the cache is the case this
    // exists for, and the worker's own check may have nothing to compare yet.
    unawaited(_check());
  }

  /// A worker that becomes `installed` while another controls the page is a
  /// new build waiting; one that installs into a page nothing controls is the
  /// first visit's.
  void _follow(_Worker? worker) {
    if (worker == null) {
      return;
    }
    worker.addEventListener(
      'statechange',
      ((JSAny? _) {
        if (worker.state == 'installed' && _workers?.controller != null) {
          _signal();
        }
      }).toJS,
    );
  }

  /// A worker installed and waiting says a deploy happened, not that this tab
  /// is behind it: the bootstrap registers each build's worker under its own
  /// address, so the tab that has just reloaded into the new build finds the
  /// same build installed a second time and waiting. Where the build has a
  /// name, `version.json` decides; a waiting worker only makes it look now.
  void _signal() {
    if (kSiteVersion.isEmpty) {
      _found();
    } else {
      unawaited(_check(poke: false));
    }
  }

  /// [poke] asks the worker to look for a new script first, so that by the
  /// time the banner is answered the new build is usually installed already.
  Future<void> _check({bool poke = true}) async {
    _checked = DateTime.now();
    if (poke) {
      try {
        await _registration?.update().toDart;
      } on Object {
        // Offline, or the worker script failed to parse: `version.json` decides.
      }
    }
    if (kSiteVersion.isEmpty || available || _disposed) {
      return;
    }
    try {
      final _Response response = await _fetch(
        'version.json?t=${DateTime.now().millisecondsSinceEpoch}',
        <String, Object?>{'cache': 'no-store'}.jsify()!,
      ).toDart;
      if (!response.ok) {
        return;
      }
      final Object? body = (await response.json().toDart).dartify();
      final Object? live = body is Map ? body['version'] : null;
      if (live is String && live.isNotEmpty && live != kSiteVersion) {
        _found();
      }
    } on Object {
      // Offline: nothing to compare with.
    }
  }

  void _found() {
    if (available || _disposed) {
      return;
    }
    available = true;
    notifyListeners();
  }

  @override
  Future<void> apply() async {
    final _Workers? workers = _workers;
    final _Worker? waiting = _registration?.waiting;
    if (workers != null && waiting != null) {
      final taken = Completer<void>();
      final JSFunction done = ((JSAny? _) {
        if (!taken.isCompleted) {
          taken.complete();
        }
      }).toJS;
      workers.addEventListener('controllerchange', done);
      waiting.postMessage(<String, Object?>{'type': 'skipWaiting'}.jsify()!);
      await taken.future.timeout(_kHandover, onTimeout: () {});
      workers.removeEventListener('controllerchange', done);
    } else {
      // Nothing waiting — the deploy is newer than any worker this tab has
      // seen, or the worker is stuck — so the cache goes: the reload then
      // fetches everything from the network and installs the worker afresh.
      try {
        final _Caches? caches = _caches;
        if (caches != null) {
          for (final JSString name in (await caches.keys().toDart).toDart) {
            await caches.delete(name.toDart).toDart;
          }
        }
        if (workers != null) {
          for (final _Registration registration in (await workers.getRegistrations().toDart).toDart) {
            await registration.unregister().toDart;
          }
        }
      } on Object {
        // Reload regardless: at worst it is the same build again.
      }
    }
    _location.reload();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final void Function() off in _off) {
      off();
    }
    _off.clear();
    super.dispose();
  }
}
