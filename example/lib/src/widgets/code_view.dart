import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/highlight.dart';
import 'package:flutter_md/highlight/bash.dart';
import 'package:flutter_md/highlight/dart.dart';
import 'package:flutter_md/highlight/yaml.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/theme.dart';
import 'selection.dart';
import 'toast.dart';
import 'site_icon.dart';

/// The site's code colours: a dark editor theme whose background lets the
/// page show through a little.
final class SiteCodeTheme implements CodeHighlightTheme {
  const SiteCodeTheme();

  @override
  Color? get background => const Color(0xB30A0E1A);

  @override
  Color? get foreground => const Color(0xFFD6DEEB);

  @override
  TextStyle? styleFor(String tokenType) => switch (tokenType) {
    'comment' || 'prolog' || 'doctype' => const TextStyle(color: Color(0xFF7E8AA6), fontStyle: FontStyle.italic),
    'keyword' || 'operator' || 'rule' || 'atrule' => const TextStyle(color: Color(0xFFC792EA)),
    'string' || 'string-literal' || 'char' || 'attr-value' || 'regex' => const TextStyle(color: Color(0xFFC3E88D)),
    'number' || 'boolean' || 'constant' || 'null' || 'symbol' => const TextStyle(color: Color(0xFFF78C6C)),
    'function' || 'function-name' => const TextStyle(color: Color(0xFF82AAFF)),
    'class-name' || 'builtin' || 'namespace' || 'tag' => const TextStyle(color: Color(0xFFFFCB6B)),
    'metadata' || 'annotation' => const TextStyle(color: Color(0xFF89DDFF)),
    'punctuation' => const TextStyle(color: Color(0xFF89DDFF)),
    _ => null,
  };
}

/// The one highlighter: Dart for the code, bash and yaml for the install
/// steps. Grammars not named here are tree-shaken.
final MarkdownHighlighter kSiteHighlighter = MarkdownHighlighter(
  languages: <String, Grammar>{
    'dart': HighlightDart.grammar,
    'bash': HighlightBash.grammar,
    'shell': HighlightBash.grammar,
    'yaml': HighlightYaml.grammar,
  },
  theme: const SiteCodeTheme(),
);

const TextStyle _kCodeStyle = TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.6);

/// A block of code: highlighted, selectable, scrolled sideways rather than
/// wrapped, with a button that copies it.
class CodeView extends StatelessWidget {
  const CodeView({required this.code, this.language = 'dart', this.title, super.key});

  final String code;
  final String language;

  /// A caption over the code, such as a file name.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final String source = code.trimRight();
    final TextStyle base = kSiteHighlighter.baseStyleFor(language, _kCodeStyle);
    final List<InlineSpan> spans = kSiteHighlighter.highlight(source, language, base);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSiteHighlighter.backgroundFor(language),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSiteLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title ?? language,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kSiteTextMuted),
                  ),
                ),
                _CopyButton(text: source),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            // The code selects, the caption and the button over it do not.
            child: SiteSelectionArea(
              child: Text.rich(TextSpan(style: base, children: spans)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) {
      return;
    }
    showGlassToast(context, 'Code copied', icon: SFIcons.sf_document_on_document);
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _copied ? 'Copied' : 'Copy',
    onPressed: _copy,
    iconSize: 18,
    color: _copied ? const Color(0xFFC3E88D) : kSiteTextMuted,
    icon: SiteIcon(_copied ? SFIcons.sf_checkmark : SFIcons.sf_document_on_document),
  );
}
