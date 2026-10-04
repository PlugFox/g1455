import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';

import 'toast.dart';

/// Whether the site opens on the Medium preset rather than Ultra.
///
/// True where Flutter draws with CanvasKit, which is the dart2js build: a
/// browser the loader gives no WasmGC build to. CanvasKit makes
/// `Picture.toImageSync` a synchronous GPU readback (`readPixels`), and the
/// glass takes a capture whenever what is under it moves — so the full rung
/// costs 15 to 30 ms a frame there where Skwasm costs 4 to 10, on the same
/// machine (an M3 Max, WebKit and Chromium alike). Medium captures nothing,
/// and on it the two renderers are level.
const bool kOpensReduced = kIsWeb && !kIsWasm;

/// Says the site opened on reduced settings, why, and what to do about it.
///
/// [onFullGlass] puts the glass back; the sheet closes either way.
Future<void> showReducedQualityNotice(BuildContext context, {required VoidCallback onFullGlass}) =>
    showGlassSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext sheet) => _Notice(onFullGlass: onFullGlass),
    );

class _Notice extends StatelessWidget {
  const _Notice({required this.onFullGlass});

  final VoidCallback onFullGlass;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    // Shown from the navigator's own context, which is above every page's
    // Scaffold: there is no text style to inherit, so the label is the one
    // the host picks for the sheet's glass, as the package's own alert does.
    final GlassThemeData glass = GlassTheme.of(context);
    final Color label = glass.legibility(glass.finish).label;
    final TextStyle? body = text.bodyMedium?.copyWith(color: label.withValues(alpha: 0.82), height: 1.5);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: text.bodyMedium?.copyWith(color: label),
        child: IconTheme.merge(
          data: IconThemeData(color: label),
          child: _content(text, label, body, context),
        ),
      ),
    );
  }

  // Scrolls: the sheet caps its content at what fits (a `Flexible`), and a
  // short landscape window or large text would otherwise push the buttons out
  // of reach under an overflow stripe.
  Widget _content(TextTheme text, Color label, TextStyle? body, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.speed, color: label),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Opened on Medium settings',
                    style: text.titleLarge?.copyWith(color: label, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This browser runs Flutter without WebAssembly, and there every capture of what is under the glass '
            'stalls the GPU. So the site shows a tint over the page instead of refraction and blur.',
            style: body,
          ),
          const SizedBox(height: 10),
          Text(
            'For the glass as an app draws it on a phone or a desktop, open this page in Chrome on a desktop. '
            'The settings menu in the corner turns the glass back on here.',
            style: body,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              GlassButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: Uri.base.toString()));
                  if (context.mounted) {
                    showGlassToast(context, 'Link copied: paste it into Chrome', icon: Icons.link);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Copy link'),
              ),
              GlassButton(
                onPressed: () {
                  onFullGlass();
                  Navigator.of(context).pop();
                },
                child: const Text('Turn the glass on'),
              ),
              GlassButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep Medium')),
            ],
          ),
        ],
      ),
    );
  }
}
