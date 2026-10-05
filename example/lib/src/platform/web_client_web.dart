import 'dart:js_interop';

import 'web_client.dart';

@JS('navigator')
external _Navigator get _navigator;

@JS('localStorage')
external _Storage get _localStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// When the notice was last closed, as an ISO 8601 instant: the date alone,
/// no flag, so that it comes back once a day.
const String _kNoticeClosedKey = 'g1455.notice.closed';

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
  external int get maxTouchPoints;

  /// User-Agent Client Hints: Chromium only, and only in a secure context.
  external _UserAgentData? get userAgentData;
}

extension type _UserAgentData._(JSObject _) implements JSObject {
  external JSArray<_Brand> get brands;
  external bool get mobile;
}

extension type _Brand._(JSObject _) implements JSObject {
  external String get brand;
}

final RegExp _mobileAgent = RegExp('Android|iPhone|iPad|iPod|Mobile|Silk|Kindle', caseSensitive: false);

WebClient? readWebClient() {
  try {
    final _Navigator nav = _navigator;
    final String agent = nav.userAgent;
    final _UserAgentData? hints = nav.userAgentData;
    // Every iOS browser is WebKit, and says so with its own token in place of
    // "Chrome/"; Firefox and Safari have no "Chrome/" at all.
    final bool blink =
        hints?.brands.toDart.any((_Brand b) => b.brand == 'Chromium') ??
        (agent.contains('Chrome/') && !agent.contains('Firefox/'));
    // An iPad asks for the desktop site by default, and says Macintosh: a Mac
    // has no touch screen, so the touch points give it away.
    final bool iPad = agent.contains('Macintosh') && nav.maxTouchPoints > 1;
    final bool mobile = (hints?.mobile ?? false) || _mobileAgent.hasMatch(agent) || iPad;
    return WebClient(blink: blink, mobile: mobile);
  } on Object {
    return null;
  }
}

// `localStorage` throws where the browser keeps nothing for the site (a
// private window in some browsers, storage blocked): the notice is then
// simply shown on every load.

DateTime? readNoticeClosed() {
  try {
    final String? value = _localStorage.getItem(_kNoticeClosedKey);
    return value == null ? null : DateTime.tryParse(value);
  } on Object {
    return null;
  }
}

void writeNoticeClosed(DateTime at) {
  try {
    _localStorage.setItem(_kNoticeClosedKey, at.toUtc().toIso8601String());
  } on Object {
    // Kept nowhere: shown again next load.
  }
}
