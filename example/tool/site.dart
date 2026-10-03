// The HTML around the app: one page per address of the site, the sitemap,
// robots.txt and the web manifest — all from the catalog the app draws.
//
//   dart run tool/site.dart [build/web]
//
// Run after `flutter build web` and before `sw:generate`. Each page is the
// app's shell — the same bootstrap, the same base — with the page's own
// title, description, canonical address, link preview and structured data,
// and the page's text as plain semantic HTML: what a crawler or a link
// preview reads, what shows without JavaScript, and what the app covers
// once its first frame is up.
//
// Firebase Hosting serves `components/slider.html` at `/components/slider`
// (`cleanUrls`), and an address with no page gets `404.html` with a real 404
// status — which is the app too, and draws its own "not found".

import 'dart:convert';
import 'dart:io';

import 'package:g1455_example/src/catalog/catalog.dart';
import 'package:markdown/markdown.dart' as md;

// ignore_for_file: avoid_print

/// The page's colour before the first frame; `kSiteBackground` in the app.
const String _kBackground = '#070a12';

void main(List<String> args) {
  final Directory out = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!File('${out.path}/flutter_bootstrap.js').existsSync() && !File('${out.path}/bootstrap.js').existsSync()) {
    stderr.writeln('${out.path} is not a web build: run `flutter build web` first');
    exit(64);
  }
  final String version = _version();

  _write(out, 'index.html', _home());
  for (final Entry entry in kEntries) {
    _write(out, '${entry.path.substring(1)}.html', _entry(entry));
  }
  _write(out, '404.html', _notFound());
  _write(out, 'sitemap.xml', _sitemap());
  _write(out, 'robots.txt', _robots());
  _write(out, 'manifest.json', _manifest());
  _write(out, 'version.json', '${jsonEncode(<String, String>{'version': version})}\n');
}

void _write(Directory out, String path, String content) {
  final file = File('${out.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  print('${file.path}  ${content.length} B');
}

String _version() {
  final ProcessResult r = Process.runSync('git', <String>['rev-parse', '--short=8', 'HEAD']);
  return r.exitCode == 0 ? (r.stdout as String).trim() : 'local';
}

String _esc(String s) => const HtmlEscape().convert(s);

String _attr(String s) => const HtmlEscape(HtmlEscapeMode.attribute).convert(s);

/// Markdown as HTML, GitHub's dialect: tables, fenced code, alerts.
String _html(String markdown) => md.markdownToHtml(
  markdown,
  extensionSet: md.ExtensionSet.gitHubWeb,
  blockSyntaxes: const <md.BlockSyntax>[md.AlertBlockSyntax()],
);

/// The image a page's link preview shows, written by `tool/brand_test.dart`.
String _og(String name) => '${Site.origin}/og/$name.png';

String _page({
  required String path,
  required String title,
  required String description,
  required String og,
  required String ogAlt,
  required String body,
  required List<Map<String, Object?>> jsonLd,
  String type = 'website',
  bool index = true,
}) {
  final String url = '${Site.origin}${path == '/' ? '/' : path}';
  final String ld = const JsonEncoder.withIndent('  ').convert(jsonLd.length == 1 ? jsonLd.single : jsonLd);
  return '''<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
  <base href="/">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${_esc(title)}</title>
  <meta name="description" content="${_attr(description)}">
  ${index ? '<link rel="canonical" href="${_attr(url)}">' : '<meta name="robots" content="noindex">'}
  <meta name="author" content="Mike Matiunin (PlugFox)">
  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="$_kBackground">
  <meta name="application-name" content="g1455">
  <meta name="apple-mobile-web-app-title" content="g1455">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="format-detection" content="telephone=no">
  <link rel="icon" href="favicon.ico" sizes="48x48">
  <link rel="icon" href="favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
  <link rel="manifest" href="manifest.json">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="preconnect" href="https://www.gstatic.com" crossorigin>
  <meta property="og:type" content="$type">
  <meta property="og:site_name" content="g1455">
  <meta property="og:locale" content="en_US">
  <meta property="og:title" content="${_attr(title)}">
  <meta property="og:description" content="${_attr(description)}">
  <meta property="og:url" content="${_attr(url)}">
  <meta property="og:image" content="${_attr(og)}">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${_attr(ogAlt)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${_attr(title)}">
  <meta name="twitter:description" content="${_attr(description)}">
  <meta name="twitter:image" content="${_attr(og)}">
  <meta name="twitter:image:alt" content="${_attr(ogAlt)}">
  <script type="application/ld+json">
$ld
  </script>
  <script>
    // With JavaScript the outline below is not shown at all: the loader is
    // the first thing on screen, then the app. It stays in the document for
    // crawlers and a screen reader until the app's first frame.
    document.documentElement.classList.add('js');
  </script>
  <style>$_kStyle</style>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <div id="static">
    <header>
      <a class="brand" href="/" aria-label="g1455 — home"><img src="favicon.svg" width="28" height="28" alt=""> g1455</a>
      <nav aria-label="Main">${_mainNav()}</nav>
    </header>
    <main id="main">
$body
    </main>
    <footer>
      <nav aria-label="Footer">
        <a href="${Site.repository}">GitHub</a> · <a href="${Site.pub}">pub.dev</a> ·
        <a href="${Site.pubApi}g1455-library.html">API reference</a> · <a href="${Site.changelog}">Changelog</a>
      </nav>
      <p>MIT licensed. This page is the static outline of a Flutter web app; with JavaScript on, the app draws it in
      live glass.</p>
    </footer>
  </div>
  <noscript><p class="noscript">The live demos are drawn by Flutter in your browser — they need JavaScript.</p></noscript>
  <script>
    // The outline above is for crawlers, link previews and no-JS readers.
    // Once the app has drawn its first frame it covers the page, and the
    // outline leaves the accessibility tree so a screen reader reads the
    // app's semantics once, not twice.
    window.addEventListener('flutter-first-frame', function () {
      var s = document.getElementById('static');
      if (s) { s.setAttribute('aria-hidden', 'true'); s.setAttribute('inert', ''); s.style.display = 'none'; }
    }, { once: true });
  </script>
  <script defer data-sw-bootstrap src="bootstrap.js" data-config='{"logo":"icons/Icon-192.png","title":"g1455","theme":"dark","color":"#8ab4ff"}'></script>
</body>
</html>
''';
}

/// The sections that have pages.
Iterable<Section> get _sections => Section.values.where((Section s) => entriesOf(s).isNotEmpty);

/// The first page of [section], which is where the section's link goes.
String _first(Section section) => entriesOf(section).firstOrNull?.path ?? '/';

String _mainNav() => <String>[
  for (final Section s in _sections) '<a href="${_first(s)}">${_esc(s.title)}</a>',
].join(' ');

/// Every page, by section: the home page's body, and the crawler's map.
String _index() {
  final b = StringBuffer();
  for (final Section s in _sections) {
    b
      ..writeln('      <section aria-labelledby="s-${s.id}">')
      ..writeln('        <h2 id="s-${s.id}">${_esc(s.title)}</h2>')
      ..writeln('        <ul class="cards">');
    for (final Entry e in entriesOf(s)) {
      b.writeln(
        '          <li><a href="${e.path}"><strong>${_esc(e.title)}</strong><span>${_esc(e.summary)}</span></a></li>',
      );
    }
    b
      ..writeln('        </ul>')
      ..writeln('      </section>');
  }
  return b.toString();
}

Map<String, Object?> get _webSite => <String, Object?>{
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  'name': 'g1455',
  'alternateName': Site.title,
  'url': '${Site.origin}/',
  'description': Site.description,
  'inLanguage': 'en',
};

Map<String, Object?> get _software => <String, Object?>{
  '@context': 'https://schema.org',
  '@type': 'SoftwareSourceCode',
  'name': 'g1455',
  'description': 'Liquid Glass for Flutter: refraction, blur, tint and a rim over the live backdrop.',
  'codeRepository': Site.repository,
  'programmingLanguage': 'Dart',
  'runtimePlatform': 'Flutter',
  'license': 'https://opensource.org/licenses/MIT',
  'url': Site.pub,
  'author': <String, Object?>{'@type': 'Person', 'name': 'Mike Matiunin', 'url': 'https://github.com/PlugFox'},
};

String _home() => _page(
  path: '/',
  title: Site.title,
  description: Site.description,
  og: _og('home'),
  ogAlt: 'g1455 — Liquid Glass for Flutter: glass blobs and a frosted card over a colour grid',
  jsonLd: <Map<String, Object?>>[_webSite, _software],
  body:
      '''
      <h1>Liquid Glass for Flutter</h1>
      <p class="lead">${_esc(Site.description)}</p>
      <pre><code class="language-bash">flutter pub add g1455</code></pre>
      <p><a href="${kEntries.first.path}">Get started</a> · <a href="${_first(Section.components)}">Components</a> ·
      <a href="${Site.repository}">GitHub</a> · <a href="${Site.pub}">pub.dev</a></p>
${_index()}''',
);

String _entry(Entry e) {
  final String title = '${e.title} · ${e.section.title} · g1455';
  final b = StringBuffer()
    ..writeln(
      '      <nav aria-label="Breadcrumb" class="crumbs"><a href="/">g1455</a> / '
      '<a href="${_first(e.section)}">${_esc(e.section.title)}</a> / '
      '<span aria-current="page">${_esc(e.title)}</span></nav>',
    )
    ..writeln('      <article>')
    ..writeln('        <h1>${_esc(e.title)}</h1>')
    ..writeln('        <p class="lead">${_esc(e.summary)}</p>');
  final links = <String>[
    for (final String symbol in e.api) '<a href="${_attr(Site.api(symbol))}"><code>${_esc(symbol)}</code></a>',
    if (e.source case final String source) '<a href="${_attr(Site.source(source))}">Source</a>',
  ];
  if (links.isNotEmpty) {
    b.writeln('        <p class="links">${links.join(' · ')}</p>');
  }
  if (e.section == Section.demos) {
    b.writeln('        <p>A full-screen demo of the example app. Open it with JavaScript on to play with it.</p>');
  }
  if (e.guide.isNotEmpty) {
    b.writeln('        <section aria-label="Guide">${_html(e.guide)}</section>');
  }
  if (e.code case final String code) {
    b
      ..writeln('        <section aria-labelledby="code"><h2 id="code">Code</h2>')
      ..writeln('<pre><code class="language-dart">${_esc(code.trimRight())}</code></pre></section>');
  }
  if (e.properties case final String properties) {
    b.writeln('        <section aria-labelledby="api"><h2 id="api">API</h2>${_html(properties)}</section>');
  }
  final (Entry? previous, Entry? next) = neighboursOf(e);
  b
    ..writeln('      </article>')
    ..writeln('      <nav aria-label="Pages" class="pager">')
    ..writeln(previous == null ? '' : '        <a rel="prev" href="${previous.path}">← ${_esc(previous.title)}</a>')
    ..writeln(next == null ? '' : '        <a rel="next" href="${next.path}">${_esc(next.title)} →</a>')
    ..writeln('      </nav>');
  return _page(
    path: e.path,
    title: title,
    description: e.summary,
    og: _og('${e.section.id}-${e.id}'),
    ogAlt: 'g1455 · ${e.title}: ${e.summary}',
    type: 'article',
    jsonLd: <Map<String, Object?>>[
      <String, Object?>{
        '@context': 'https://schema.org',
        '@type': 'TechArticle',
        'headline': e.title,
        'description': e.summary,
        'url': '${Site.origin}${e.path}',
        'image': _og('${e.section.id}-${e.id}'),
        'inLanguage': 'en',
        'isPartOf': <String, Object?>{'@type': 'WebSite', 'name': 'g1455', 'url': '${Site.origin}/'},
        'about': <String, Object?>{'@type': 'SoftwareSourceCode', 'name': 'g1455', 'codeRepository': Site.repository},
        'author': <String, Object?>{'@type': 'Person', 'name': 'Mike Matiunin', 'url': 'https://github.com/PlugFox'},
      },
      <String, Object?>{
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        'itemListElement': <Map<String, Object?>>[
          <String, Object?>{'@type': 'ListItem', 'position': 1, 'name': 'g1455', 'item': '${Site.origin}/'},
          <String, Object?>{
            '@type': 'ListItem',
            'position': 2,
            'name': e.section.title,
            'item': '${Site.origin}${_first(e.section)}',
          },
          <String, Object?>{'@type': 'ListItem', 'position': 3, 'name': e.title, 'item': '${Site.origin}${e.path}'},
        ],
      },
    ],
    body: b.toString(),
  );
}

String _notFound() => _page(
  path: '/404',
  title: 'Not found · g1455',
  description: 'There is no page at this address.',
  og: _og('home'),
  ogAlt: 'g1455 — Liquid Glass for Flutter',
  index: false,
  jsonLd: <Map<String, Object?>>[_webSite],
  body: '''
      <h1>Not found</h1>
      <p class="lead">There is no glass at this address.</p>
${_index()}''',
);

String _sitemap() {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    ..writeln('  <url><loc>${Site.origin}/</loc><priority>1.0</priority></url>');
  for (final Entry e in kEntries) {
    final String priority = switch (e.section) {
      Section.start || Section.components => '0.8',
      Section.foundations => '0.7',
      Section.demos => '0.5',
    };
    b.writeln('  <url><loc>${Site.origin}${e.path}</loc><priority>$priority</priority></url>');
  }
  b.writeln('</urlset>');
  return b.toString();
}

String _robots() =>
    '''
User-agent: *
Allow: /
Disallow: /404

Sitemap: ${Site.origin}/sitemap.xml
''';

String _manifest() =>
    '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'id': '/',
      'name': Site.title,
      'short_name': 'g1455',
      'description': Site.description,
      'start_url': '/?source=pwa',
      'scope': '/',
      'lang': 'en',
      'dir': 'ltr',
      'display': 'standalone',
      'background_color': _kBackground,
      'theme_color': _kBackground,
      'categories': <String>['developer', 'education', 'design'],
      'prefer_related_applications': false,
      'icons': <Map<String, String>>[
        <String, String>{'src': 'icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any'},
        <String, String>{'src': 'icons/Icon-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any'},
        <String, String>{'src': 'icons/Icon-maskable-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
        <String, String>{'src': 'icons/Icon-maskable-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'},
      ],
      'shortcuts': <Map<String, String>>[
        <String, String>{'name': 'Components', 'url': _first(Section.components)},
        <String, String>{'name': 'Installation', 'url': kEntries.first.path},
      ],
    })}\n';

/// The outline's style: readable, dark like the app, and gone once the app is
/// up.
const String _kStyle =
    '''
:root{color-scheme:dark}
html,body{margin:0;background:$_kBackground;color:#e8ecf5;overflow-x:hidden}
html,body{background:$_kBackground!important}
#sw-loading{background:$_kBackground!important;animation:g-fade .4s ease-in!important}
@keyframes g-fade{from{opacity:0}}
.js #static{position:absolute!important;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip-path:inset(50%);white-space:nowrap}
body{font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
#static{max-width:820px;margin:0 auto;padding:24px 20px 48px;overflow-wrap:anywhere}
table{display:block;overflow-x:auto}
header{display:flex;flex-wrap:wrap;gap:12px 24px;align-items:center;margin-bottom:32px}
header nav a,footer a,main a{color:#8ab4ff;text-decoration:none}
a:hover{text-decoration:underline}
article p a,article li a,.lead a{text-decoration:underline;text-underline-offset:2px}
.brand{display:flex;gap:10px;align-items:center;font-weight:800;font-size:20px;color:#fff;text-decoration:none}
h1{font-size:44px;line-height:1.1;letter-spacing:-1px;margin:8px 0 12px}
h2{margin-top:40px}
.lead{font-size:19px;color:#b8c0d4}
pre{background:#0d1324;border:1px solid #ffffff1f;border-radius:14px;padding:14px 16px;overflow:auto}
code{font-family:ui-monospace,"JetBrains Mono",Menlo,monospace;font-size:14px}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{border:1px solid #ffffff1f;padding:6px 10px;text-align:left;vertical-align:top}
.cards{list-style:none;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px}
.cards a{display:block;padding:16px;border:1px solid #ffffff1f;border-radius:16px;background:#ffffff0a;height:100%;box-sizing:border-box}
.cards strong{display:block;color:#fff}.cards span{color:#b8c0d4;font-size:14px}
.crumbs{font-size:14px;color:#b8c0d4}
.pager{display:flex;justify-content:space-between;margin-top:40px}
footer{margin-top:56px;font-size:14px;color:#8d96ab}
.skip{position:absolute;left:-9999px}.skip:focus{left:12px;top:12px}
.noscript{position:fixed;bottom:0;left:0;right:0;margin:0;padding:12px;background:#1b2236;text-align:center}
.markdown-alert{border-left:3px solid #8ab4ff;padding:4px 14px;margin:16px 0;background:#ffffff08}
''';
