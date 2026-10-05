import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';

import '../app/theme.dart';
import 'code_view.dart';
import 'links.dart';
import 'selection.dart';

/// A guide in markdown: prose drawn by flutter_md, and every fenced code
/// block lifted out into a [CodeView] — highlighted, scrolled rather than
/// wrapped, and copyable.
///
/// Tables are lifted out too: a table of properties has four columns, and on
/// a phone four columns are wider than the page. Narrower than
/// [kTableMinColumnWidth] a column, the table scrolls sideways instead of
/// running off the edge.
///
/// The prose and the tables select as one document — a drag runs from a
/// paragraph into a table — through one flutter_md selection scope; each code
/// block selects on its own, as [CodeView] does everywhere.
class DocView extends StatefulWidget {
  const DocView({required this.markdown, super.key});

  final String markdown;

  @override
  State<DocView> createState() => _DocViewState();
}

/// The narrowest a column of a table is set before the table scrolls.
const double kTableMinColumnWidth = 150;

/// A run of prose, a table, or a fenced block of code.
sealed class _Block {
  const _Block();
}

final class _Prose extends _Block {
  _Prose(String source) : markdown = Markdown.fromString(source);

  final Markdown markdown;
}

final class _Table extends _Prose {
  _Table(super.source, this.columns);

  final int columns;
}

final class _Code extends _Block {
  const _Code(this.code, this.language);

  final String code;
  final String language;
}

final RegExp _kFence = RegExp(r'^```([\w-]*)[^\n]*\n(.*?)\n```[ \t]*$', multiLine: true, dotAll: true);

List<_Block> _split(String source) {
  final blocks = <_Block>[];
  var at = 0;
  for (final RegExpMatch m in _kFence.allMatches(source)) {
    _splitProse(source.substring(at, m.start), blocks);
    final String language = m.group(1)!;
    blocks.add(_Code(m.group(2)!, language.isEmpty ? 'dart' : language));
    at = m.end;
  }
  _splitProse(source.substring(at), blocks);
  return blocks;
}

/// Adds [source] to [blocks] as prose, every pipe table in it on its own.
void _splitProse(String source, List<_Block> blocks) {
  final prose = <String>[];
  final table = <String>[];
  void flush() {
    if (unwrapMarkdown(prose.join('\n')).trim() case final String text when text.isNotEmpty) {
      blocks.add(_Prose(text));
    }
    prose.clear();
    if (table.isNotEmpty) {
      // The header row's cells, less the empty ends of its outer pipes.
      final int columns = table.first.trim().split('|').length - 2;
      blocks.add(_Table(table.join('\n'), columns < 1 ? 1 : columns));
      table.clear();
    }
  }

  for (final String line in source.split('\n')) {
    if (line.trimLeft().startsWith('|')) {
      if (table.isEmpty) {
        flush();
      }
      table.add(line);
    } else {
      if (table.isNotEmpty) {
        flush();
      }
      prose.add(line);
    }
  }
  flush();
}

final RegExp _kBlockStart = RegExp(r'^(#{1,6}\s|[-*+]\s|\d+[.)]\s|>|\||```|<|!\[|---|\*\*\*|___)');
final RegExp _kCodeLink = RegExp(r'\[`([^`\]]+)`\]\(');
final RegExp _kListItem = RegExp(r'^\s*([-*+]|\d+[.)])\s');

/// [source] with each paragraph, list item and quote on one line, and a
/// link's text out of code spans.
///
/// The guides are written wrapped at 120 columns, and a newline inside a
/// paragraph is a soft break: a space. flutter_md keeps it as a line break,
/// so on a column narrower than the source the text broke twice — where the
/// column ended and again where the source line did, a short line in the
/// middle of every paragraph on a phone. A line is joined to the one before
/// when both are prose: neither blank, the new one starts no block of its
/// own (a heading, a list item, a quote, a table, a fence, a rule, HTML), and
/// the one before does not end in a hard break (two spaces or a backslash). A
/// list item's indented continuation joins its item; a quote's next `>` line
/// joins the quote, unless either is an alert's `[!NOTE]` marker.
String unwrapMarkdown(String source) {
  // flutter_md does not read code inside a link's text: "[`GlassHost`](…)"
  // drew its backticks. The name links on its own.
  source = source.replaceAllMapped(_kCodeLink, (Match m) => '[${m[1]}](');
  final out = <String>[];
  var fenced = false;
  for (final String line in source.split('\n')) {
    final String trimmed = line.trimLeft();
    if (trimmed.startsWith('```')) {
      fenced = !fenced;
      out.add(line);
      continue;
    }
    if (fenced || out.isEmpty || trimmed.isEmpty) {
      out.add(line);
      continue;
    }
    final String previous = out.last;
    final String before = previous.trimLeft();
    final bool hardBreak = previous.endsWith('  ') || previous.endsWith(r'\');
    if (before.isEmpty || hardBreak || before.startsWith('#') || before.startsWith('|') || before.startsWith('<')) {
      out.add(line);
      continue;
    }
    if (trimmed.startsWith('>')) {
      // A quote's next line: joined, unless either is an alert's marker.
      final String body = trimmed.substring(1).trimLeft();
      final bool marker = body.startsWith('[!') || before.replaceFirst('>', '').trimLeft().startsWith('[!');
      if (before.startsWith('>') && !marker && body.isNotEmpty && !_kBlockStart.hasMatch(body)) {
        out.last = '$previous $body';
      } else {
        out.add(line);
      }
      continue;
    }
    if (before.startsWith('>')) {
      out.add(line);
      continue;
    }
    // An indented line under a list item continues it; one that starts a
    // nested item does not.
    final bool indented = line.startsWith(' ') || line.startsWith('\t');
    if (indented && _kListItem.hasMatch(line)) {
      out.add(line);
      continue;
    }
    if (!indented && _kBlockStart.hasMatch(trimmed)) {
      out.add(line);
      continue;
    }
    out.last = '$previous $trimmed';
  }
  return out.join('\n');
}

class _DocViewState extends State<DocView> {
  // Parsed once per source, as flutter_md asks: a parse per build is the
  // one cost a markdown widget can avoid.
  late List<_Block> _blocks = _split(widget.markdown);
  final MarkdownSelectionController _selection = MarkdownSelectionController();

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(DocView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _blocks = _split(widget.markdown);
      _selection.clear();
      _register();
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _register() => _selection.setDocuments(<MarkdownDocumentRef>[
    for (final (int i, _Block block) in _blocks.indexed)
      if (block is _Prose) MarkdownDocumentRef(id: 'block-$i', model: block.markdown, order: i),
  ]);

  @override
  Widget build(BuildContext context) {
    final MarkdownThemeData theme = siteMarkdownTheme(context);
    return MarkdownSelectionScope(
      controller: _selection,
      selectionColor: kSiteAccent.withValues(alpha: 0.32),
      contextMenuBuilder: markdownSelectionMenu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (int i, _Block block) in _blocks.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: switch (block) {
                _Table(:final Markdown markdown, :final int columns) => _ScrollingTable(
                  minWidth: columns * kTableMinColumnWidth,
                  child: MarkdownWidget(
                    markdown: markdown,
                    theme: theme,
                    controller: _selection,
                    documentId: 'block-$i',
                  ),
                ),
                _Prose(:final Markdown markdown) => MarkdownWidget(
                  markdown: markdown,
                  theme: theme,
                  controller: _selection,
                  documentId: 'block-$i',
                ),
                _Code(:final String code, :final String language) => CodeView(code: code, language: language),
              },
            ),
        ],
      ),
    );
  }
}

/// A table at the width of the page, or at [minWidth] and scrolled sideways
/// when the page is narrower.
class _ScrollingTable extends StatefulWidget {
  const _ScrollingTable({required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  State<_ScrollingTable> createState() => _ScrollingTableState();
}

class _ScrollingTableState extends State<_ScrollingTable> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth >= widget.minWidth) {
        return widget.child;
      }
      return Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(width: widget.minWidth, child: widget.child),
        ),
      );
    },
  );
}

/// The markdown theme of the site: the text theme's sizes, set for reading
/// on glass-dark pages, with links that navigate inside the site or open a
/// new tab.
MarkdownThemeData siteMarkdownTheme(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final TextTheme text = theme.textTheme;
  final TextStyle body = text.bodyLarge!.copyWith(color: kSiteText, fontSize: 16, height: 1.6);
  return MarkdownThemeData.mergeTheme(
    theme,
    textStyle: body,
    textScaler: MediaQuery.textScalerOf(context),
    h1Style: text.headlineMedium?.copyWith(color: kSiteText),
    h2Style: text.headlineSmall?.copyWith(color: kSiteText, fontWeight: FontWeight.w600),
    h3Style: text.titleLarge?.copyWith(color: kSiteText),
    h4Style: text.titleMedium?.copyWith(color: kSiteText, fontWeight: FontWeight.w600),
    h5Style: text.titleSmall?.copyWith(color: kSiteText),
    h6Style: text.titleSmall?.copyWith(color: kSiteTextMuted),
    quoteStyle: body.copyWith(color: kSiteTextMuted, fontStyle: FontStyle.italic),
    linkColor: kSiteAccent,
    surfaceColor: const Color(0x99101626),
    monospaceBackgroundColor: const Color(0x268AB4FF),
    dividerColor: kSiteLine,
    highlighter: kSiteHighlighter,
    onLinkTap: (String title, String url) => openLink(context, url),
  );
}
