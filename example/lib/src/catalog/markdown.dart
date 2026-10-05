/// The catalog as markdown, for readers that are not browsers: the agent
/// skill's references (`skills/g1455/references/`, written by
/// `tool/skill.dart`) and the site's `.md` pages and `llms.txt`
/// (`tool/site.dart`).
///
/// Plain Dart, like the catalog. One page renders the same in both places
/// except for its links, which [entryMarkdown] takes as a function: a skill
/// links its own files, the site its own addresses.
library;

import 'catalog.dart';

/// Where a link to the page at [path] (`/components/slider`) goes, from the
/// page at [from].
typedef PageLink = String Function(String path, Entry from);

/// A link from page to page inside the skill: a relative path to the other
/// reference file, `../components/slider.md`.
String skillLink(String path, Entry from) => '..$path.md';

/// A link to the site's markdown copy of a page.
String siteLink(String path, Entry from) => '${Site.origin}$path.md';

/// Every page that has words of its own: the demos are only to be played.
Iterable<Entry> get documentedEntries => kEntries.where((Entry e) => e.section != Section.demos);

/// The page about the skill itself, which the skill has no use for.
const String kAgentsPage = '/start/agents';

/// The skill's reference files, by their path under `references/`:
/// `components/slider.md`.
Map<String, String> skillReferences() => <String, String>{
  for (final Entry e in documentedEntries)
    if (e.path != kAgentsPage) '${e.path.substring(1)}.md': entryMarkdown(e, link: skillLink),
};

/// The page [e] as one markdown document: its title, summary, links, guide,
/// complete example and API table.
String entryMarkdown(Entry e, {required PageLink link}) {
  final b = StringBuffer()
    ..writeln('# ${e.title}')
    ..writeln()
    ..writeln('> ${e.summary}')
    ..writeln();
  final refs = <String>[
    'Live: ${Site.origin}${e.path}',
    if (e.api.isNotEmpty) 'API: ${e.api.map((String s) => '[`$s`](${Site.api(s)})').join(', ')}',
    if (e.source case final String source) 'Source: [`$source`](${Site.source(source)})',
  ];
  for (final String r in refs) {
    b.writeln('- $r');
  }
  b
    ..writeln()
    ..writeln(_relink(e.guide.trim(), e, link));
  if (e.code case final String code) {
    b
      ..writeln()
      ..writeln('## Complete example')
      ..writeln()
      ..writeln('```dart')
      ..writeln(code.trim())
      ..writeln('```');
  }
  if (e.properties case final String properties) {
    b
      ..writeln()
      ..writeln('## API')
      ..writeln()
      ..writeln(_relink(_demote(properties.trim()), e, link));
  }
  return b.toString();
}

/// The API's own headings (`## GlassFade`, `## Constants`) go one level under
/// the page's `## API`.
String _demote(String markdown) {
  final out = StringBuffer();
  var fenced = false;
  for (final String line in markdown.split('\n')) {
    if (line.startsWith('```')) {
      fenced = !fenced;
    }
    out.writeln(!fenced && line.startsWith('## ') ? '#$line' : line);
  }
  return out.toString().trimRight();
}

/// Turns the site's own links, `](/components/card)` and
/// `](/components/card#x)`, into [link]'s.
String _relink(String markdown, Entry from, PageLink link) => markdown.replaceAllMapped(
  RegExp(r'\]\((/[a-z0-9-]+/[a-z0-9-]+)(#[^)\s]*)?\)'),
  (Match m) => '](${link(m.group(1)!, from)}${m.group(2) ?? ''})',
);
