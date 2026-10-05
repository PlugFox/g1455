import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:g1455/g1455.dart' show GlassHost;

import 'src/app/app.dart';

export 'src/app/app.dart' show GlassExampleApp, SettingsScope;
export 'src/shell/settings_button.dart' show kSettingsButtonKey;
export 'src/style.dart'
    show
        AppearanceChoice,
        ContrastChoice,
        GlassPreset,
        GlassSettings,
        MaterialChoice,
        RenderingChoice,
        RippleChoice,
        TintChoice;

/// The g1455 design system: every component live, with its guide, its code
/// and its API — the package's example app, and the site at
/// https://g1455.plugfox.dev.
Future<void> main() async {
  // `/components/slider`, not `/#/components/slider`: the hosting rewrites
  // every path to the app, and a link to a page is a link a crawler reads.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // A right click opens the app's own menu (copy for a selection, paste in a
  // field), not the browser's over it.
  if (kIsWeb) {
    unawaited(BrowserContextMenu.disableContextMenu());
  }
  // The shaders, compiled before the first frame: the first glass is drawn
  // through its optics rather than as the plain blurred backdrop. A load that
  // fails is reported, and the site starts anyway.
  try {
    await GlassHost.precache();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'g1455 example',
        context: ErrorDescription('while compiling the glass shaders before the first frame'),
      ),
    );
  }
  runApp(const GlassExampleApp());
}
