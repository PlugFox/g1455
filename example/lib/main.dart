import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'src/app/app.dart';

export 'src/app/app.dart' show GlassExampleApp, SettingsScope;
export 'src/shell/settings_button.dart' show kSettingsButtonKey;
export 'src/style.dart'
    show ContrastChoice, GlassPreset, GlassSettings, MaterialChoice, RenderingChoice, RippleChoice, TintChoice;

/// The g1455 design system: every component live, with its guide, its code
/// and its API — the package's example app, and the site at
/// https://g1455.plugfox.dev.
void main() {
  // `/components/slider`, not `/#/components/slider`: the hosting rewrites
  // every path to the app, and a link to a page is a link a crawler reads.
  usePathUrlStrategy();
  runApp(const GlassExampleApp());
}
