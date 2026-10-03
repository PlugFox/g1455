# g1455_example

The g1455 design system: every component live, with its guide, its code and
its API. It is the package's example app, and the site at
**https://g1455.plugfox.dev**.

```bash
flutter run -d chrome            # the site
flutter run --profile -d <device> # on a device: profile, not debug, to judge cost
```

## What is in it

- **Getting started** — installation, how the host captures, what an app
  declares, platforms.
- **Foundations** — the host, the surface, finishes, legibility, tiers, ripple,
  groups, travel, glass on glass, the scroll edge, performance.
- **Components** — bar, button, card, switch, slider, segmented control, tab
  bar, text field, toolbar, alert, sheet, menu, popover.
- **Demos** — the example's original full-screen pages (`/demos/scroll`,
  `/demos/controls`, `/demos/blobs`, `/demos/cards`, `/demos/kit`), with the
  tab bar between them.

Every page is a live demo with knobs, then three tabs — Guide, Code, API —
whose state is in the address (`/components/slider?tab=code`). The API names
link to the package's documentation on pub.dev, and every page links to its
source and its demo's source on GitHub.

The settings menu (the tune icon in the top bar) works like a game's graphics
settings: the material, the tint, the rendering rung, the ripple and the
contrast, under the presets Ultra, High, Medium and Low. Change any setting and
the preset becomes Custom; set it back and the preset returns.

## How it is built

- `lib/src/catalog/` — the pages as plain Dart data: titles, summaries, the
  guides in markdown, the code, the API tables. No Flutter imports, so
  `tool/site.dart` reads the same list.
- `lib/src/app/` — navigation with [squid](https://pub.dev/packages/squid)
  behind Flutter's `Router`: an address becomes a stack, a stack change becomes
  a history entry, and the browser's back and forward work.
- `lib/src/shell/` — the adaptive frame: a glass side panel on a wide window,
  a glass sheet behind the menu button on a narrow one.
- `lib/src/demos/` — one live demo per page.
- `lib/src/widgets/` — the guide renderer ([flutter_md](https://pub.dev/packages/flutter_md),
  code highlighted and copyable), the demo stage, links.
- `lib/src/playground/` — the full-screen demos.

## Building the site

```bash
tool/build_web.sh   # → build/web
firebase deploy --only hosting:g1455
```

The script builds the app (`--wasm`: Skwasm with a CanvasKit fallback), draws
a link preview per page with the package itself (`tool/brand_test.dart`),
writes a page per address with its own title, description, preview and
structured data plus the sitemap and robots.txt (`tool/site.dart`), and
generates the service worker and bootstrap with the
[sw](https://pub.dev/packages/sw) package (`sw.yaml`).

The icons under `web/` are drawn the same way and committed:

```bash
flutter test tool/brand_test.dart --dart-define=BRAND_OUT=web --dart-define=BRAND_ONLY=icons
```

`.github/workflows/site.yml` deploys master to the live channel and every pull
request from this repository to a preview channel.
