/// What kind of browser and device the site is open in: whether the browser
/// is built on Blink, and whether the device is a phone or a tablet — read
/// once, locally, and sent nowhere.
///
/// Through `dart:js_interop` on the web (`web_client_web.dart`); null
/// everywhere else, where the app is native and there is no browser to ask.
///
/// Also when the site's notice about them was last closed, kept in the
/// browser's `localStorage` and nowhere else.
library;

export 'web_client_stub.dart'
    if (dart.library.js_interop) 'web_client_web.dart'
    show readNoticeClosed, readWebClient, writeNoticeClosed;

/// How long a closed notice stays closed: it comes back the first load after.
const Duration kNoticeQuiet = Duration(days: 1);

/// The browser and the device, as far as the site cares about them.
final class WebClient {
  const WebClient({required this.blink, required this.mobile});

  /// Chrome, Edge, Opera, Brave, Arc and the rest of Chromium's family on a
  /// desktop or Android — the engine the glass is tuned on. Not Firefox, not
  /// Safari, and not Chrome on iOS, which is WebKit underneath.
  final bool blink;

  /// A phone or a tablet, an iPad that asks for the desktop site included.
  final bool mobile;

  /// A desktop Chromium: where the site is drawn as it is meant to be.
  bool get recommended => blink && !mobile;
}
