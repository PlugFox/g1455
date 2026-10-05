import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../platform/web_client.dart';
import 'toast.dart';
import 'site_icon.dart';

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

/// Whether the site has something to say about where it is open: reduced
/// settings ([reduced]), or a browser or a device it is not tuned for
/// ([client], null off the web).
bool needsSiteNotice({required bool reduced, required WebClient? client}) => reduced || !(client?.recommended ?? true);

/// Says where the site is not drawn as it is meant to be, why, and what to do
/// about it: a phone or a tablet, a browser that is not Blink, and the reduced
/// settings the site opened on where Flutter has no WebAssembly — in one
/// sheet, whichever of them apply.
///
/// Only its buttons close it: not the dim, not Escape, not a drag and not
/// the back button. Closed by a stray tap, it was missed more often than read.
///
/// [onFullGlass] puts the glass back; the sheet closes either way.
Future<void> showSiteNotice(
  BuildContext context, {
  required bool reduced,
  required WebClient? client,
  required VoidCallback onFullGlass,
}) => showGlassSheet<void>(
  context: context,
  barrierDismissible: false,
  // Nothing to drag it by: it does not go when dragged.
  showGrabber: false,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext sheet) => PopScope(
    canPop: false,
    child: _Notice(reduced: reduced, client: client, onFullGlass: onFullGlass),
  ),
);

/// iOS's orange and red: the warning badge and the button that goes on
/// regardless.
const Color _kWarning = Color(0xFFFF9F0A);
const Color _kDestructive = Color(0xFFFF3B30);

class _Notice extends StatelessWidget {
  const _Notice({required this.reduced, required this.client, required this.onFullGlass});

  final bool reduced;
  final WebClient? client;
  final VoidCallback onFullGlass;

  /// Off the recommended setup: a phone, a tablet or a browser not on Blink.
  bool get _elsewhere => !(client?.recommended ?? true);

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    // Shown from the navigator's own context, which is above every page's
    // Scaffold: there is no text style to inherit, so the label is the one
    // the host picks for the sheet's glass, as the package's own alert does.
    final GlassThemeData glass = GlassTheme.of(context);
    final Color label = glass.legibility(glass.finish).label;
    final TextStyle? body = text.bodyMedium?.copyWith(color: label.withValues(alpha: 0.82), height: 1.45);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: text.bodyMedium?.copyWith(color: label),
        child: IconTheme.merge(
          data: IconThemeData(color: label),
          // Scrolls: the sheet caps its content at what fits (a `Flexible`),
          // and a short landscape window or large text would otherwise push
          // the buttons out of reach under an overflow stripe.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(text, label),
                const SizedBox(height: 14),
                Text.rich(_lead(), style: body),
                const SizedBox(height: 12),
                ..._tips(body, label),
                const SizedBox(height: 20),
                _buttons(context, label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(TextTheme text, Color label) => Row(
    children: <Widget>[
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kWarning.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: _kWarning.withValues(alpha: 0.5)),
        ),
        child: const SiteIcon(SFIcons.sf_exclamationmark_triangle_fill, size: 22, color: _kWarning),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _elsewhere ? 'SLOWER HERE' : 'REDUCED SETTINGS',
              style: text.labelSmall?.copyWith(color: _kWarning, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            const SizedBox(height: 2),
            Semantics(
              header: true,
              child: Text(
                switch (client) {
                  WebClient(mobile: true) => 'Best on a desktop',
                  WebClient(blink: false) => 'Best in a Chromium browser',
                  _ => 'Opened on Medium settings',
                },
                style: text.titleLarge?.copyWith(color: label, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// What is wrong here, the words that matter in bold. Short: on a phone
  /// both reasons have to fit above the buttons.
  TextSpan _lead() {
    const TextStyle strong = TextStyle(fontWeight: FontWeight.w700);
    const TextStyle warn = TextStyle(fontWeight: FontWeight.w700, color: _kWarning);
    return TextSpan(
      children: <InlineSpan>[
        if (_elsewhere) ...<InlineSpan>[
          if (client!.mobile) ...const <InlineSpan>[
            TextSpan(text: 'This site is tuned for '),
            TextSpan(text: 'Chromium on a desktop', style: strong),
            TextSpan(text: '. On a phone or a tablet the glass can '),
          ] else ...const <InlineSpan>[
            TextSpan(text: 'This site is tuned for '),
            TextSpan(text: 'Blink', style: strong),
            TextSpan(text: ', the engine of Chrome, Edge and Brave. In this browser the glass can '),
          ],
          const TextSpan(text: 'draw slower, stutter or look different', style: warn),
          const TextSpan(text: '.'),
        ],
        if (reduced && _elsewhere) ...const <InlineSpan>[
          TextSpan(text: ' Without '),
          TextSpan(text: 'WebAssembly', style: strong),
          TextSpan(text: ' here, it opened on '),
          TextSpan(text: 'Medium', style: warn),
          TextSpan(text: ': a tint instead of refraction and blur.'),
        ] else if (reduced) ...const <InlineSpan>[
          TextSpan(text: 'Flutter runs here '),
          TextSpan(text: 'without WebAssembly', style: strong),
          TextSpan(text: ', where every capture of what is under the glass stalls the GPU, so the site opened on '),
          TextSpan(text: 'Medium', style: warn),
          TextSpan(text: ': a tint instead of refraction and blur.'),
        ],
      ],
    );
  }

  /// What to do about it, a line each.
  List<Widget> _tips(TextStyle? body, Color label) {
    const TextStyle strong = TextStyle(fontWeight: FontWeight.w700);
    Widget tip(IconData icon, List<InlineSpan> spans) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SiteIcon(icon, size: 18, color: label.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: spans), style: body),
          ),
        ],
      ),
    );
    return <Widget>[
      tip(SFIcons.sf_desktopcomputer, const <InlineSpan>[
        TextSpan(text: 'Best: ', style: strong),
        TextSpan(text: 'Chrome, Edge or Brave on a desktop — copy the link.'),
      ]),
      if (_elsewhere)
        tip(SFIcons.sf_hare_fill, const <InlineSpan>[
          TextSpan(text: 'Faster still: ', style: strong),
          TextSpan(text: 'a native app, with no browser between the glass and the GPU.'),
        ])
      else
        tip(SFIcons.sf_sparkles, const <InlineSpan>[
          TextSpan(text: 'Or here: ', style: strong),
          TextSpan(text: 'turn the glass on, now or later from the settings menu.'),
        ]),
    ];
  }

  Widget _buttons(BuildContext context, Color label) {
    void close() => Navigator.of(context).pop();
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The link button's label goes first when the row runs short, and the
        // buttons draw in closer: about what the labels take at this text
        // size, with the link's.
        final bool compact = constraints.maxWidth < scaler.scale(reduced ? 450 : 320);
        final EdgeInsets pad = EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: 10);
        // Each closes the sheet. Off the recommended setup the one that closes
        // and stays is red: it is the choice the sheet advises against.
        final List<Widget> actions = <Widget>[
          if (reduced) ...<Widget>[
            Tooltip(
              message: 'Refraction and blur, as on a desktop: may stutter here',
              child: GlassButton(
                padding: pad,
                onPressed: () {
                  onFullGlass();
                  close();
                },
                child: const Text('Turn the glass on'),
              ),
            ),
            _closeButton(
              'Keep Medium',
              tooltip: 'Keep the tint, which runs smoothly here',
              destructive: _elsewhere,
              padding: pad,
              onPressed: close,
            ),
          ] else
            _closeButton(
              'Continue anyway',
              tooltip: 'Stay in this browser: the glass may stutter',
              destructive: true,
              padding: pad,
              onPressed: close,
            ),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _copyButton(context, compact: compact),
            const SizedBox(width: 8),
            // Wraps: text larger still than that allows for puts the actions
            // on two lines rather than under an overflow stripe.
            Expanded(
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
            ),
          ],
        );
      },
    );
  }

  Widget _copyButton(BuildContext context, {required bool compact}) {
    const String tip = 'Copy the address, to open it in Chrome on a desktop';
    const SiteIcon icon = SiteIcon(SFIcons.sf_link, size: 18);
    return Tooltip(
      message: tip,
      child: GlassButton(
        semanticLabel: compact ? 'Copy link' : null,
        padding: compact ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: Uri.base.toString()));
          if (context.mounted) {
            showGlassToast(context, 'Link copied: paste it into Chrome', icon: SFIcons.sf_link);
            Navigator.of(context).pop();
          }
        },
        child: compact
            ? icon
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[icon, SizedBox(width: 8), Text('Copy link')],
              ),
      ),
    );
  }

  Widget _closeButton(
    String text, {
    required String tooltip,
    required bool destructive,
    required EdgeInsets padding,
    required VoidCallback onPressed,
  }) => Builder(
    builder: (BuildContext context) {
      final GlassFinish finish = GlassTheme.of(context).finish;
      return Tooltip(
        message: tooltip,
        child: GlassButton(
          padding: padding,
          onPressed: onPressed,
          // The theme's glass with iOS's red laid in it, rather than a red
          // label on clear glass: it has to be seen at a glance.
          finish: destructive ? finish.copyWith(tint: _kDestructive.withValues(alpha: 0.82)) : null,
          child: Text(
            text,
            style: destructive ? const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700) : null,
          ),
        ),
      );
    },
  );
}
