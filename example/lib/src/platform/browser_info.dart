/// What the browser the site runs in says about itself: its WebGL2 limits,
/// its GPU, its screen and its cores — read once, locally, and sent nowhere.
///
/// Through `dart:js_interop` extension types on the web
/// (`browser_info_web.dart`); null everywhere else, where there is no browser
/// to ask.
library;

export 'browser_info_stub.dart' if (dart.library.js_interop) 'browser_info_web.dart' show readBrowserInfo;

/// One group of facts: "WebGL2", "Display".
final class BrowserFacts {
  const BrowserFacts(this.title, this.facts);

  final String title;

  /// Name and value, in the order they are shown.
  final List<(String, String)> facts;
}

/// Everything read, or null where the browser has no WebGL2 at all.
final class BrowserInfo {
  const BrowserInfo({required this.groups, required this.maxTextureSize});

  final List<BrowserFacts> groups;

  /// `MAX_TEXTURE_SIZE`: the widest texture the GPU takes, which bounds the
  /// host's capture atlas. Null without WebGL2.
  final int? maxTextureSize;
}
