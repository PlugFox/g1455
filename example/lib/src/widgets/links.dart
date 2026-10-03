import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:squid/squid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../catalog/catalog.dart';
import 'toast.dart';

/// Follows [url]: a path of the site is navigated to, anything else opens in
/// a new tab (or the platform's browser).
Future<void> openLink(BuildContext context, String url) async {
  if (url.startsWith('/')) {
    context.navigation.stack = stackFromUri(Uri.parse(url));
    return;
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}

/// Copies the absolute address of [path] and says so.
Future<void> copyLink(BuildContext context, String path) async {
  await Clipboard.setData(ClipboardData(text: '${Site.origin}$path'));
  if (context.mounted) {
    showGlassToast(context, 'Link copied', icon: Icons.link);
  }
}

/// A link that reads as one: the pointer, an underline on hover, and the
/// semantics of a link for a screen reader.
class LinkText extends StatefulWidget {
  const LinkText({required this.text, required this.url, this.style, this.icon, this.maxLines, super.key});

  final String text;
  final String url;
  final TextStyle? style;

  /// Drawn before the text.
  final IconData? icon;

  /// Lines before the text is cut with an ellipsis; as many as it takes when
  /// null.
  final int? maxLines;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      color: widget.style?.color ?? kSiteAccent,
      decoration: _hover ? TextDecoration.underline : TextDecoration.none,
      decorationColor: widget.style?.color ?? kSiteAccent,
    );
    return Semantics(
      link: true,
      linkUrl: Uri.tryParse(widget.url.startsWith('/') ? '${Site.origin}${widget.url}' : widget.url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => openLink(context, widget.url),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: (style.fontSize ?? 14) + 2, color: style.color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  style: style,
                  maxLines: widget.maxLines,
                  overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
