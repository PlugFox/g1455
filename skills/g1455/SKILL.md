---
name: g1455
description: >-
  Build Flutter UI with g1455, the Liquid Glass package (iOS 26 style glass:
  refraction, blur, tint, rim). Use when a Flutter project depends on g1455 or
  imports package:g1455, when code uses GlassHost, GlassSurface, GlassBar,
  GlassCard, GlassButton, GlassTabBar, GlassSwitch, GlassSlider,
  showGlassDialog, showGlassSheet, GlassMenuAnchor or another Glass* name, or
  when the user asks for liquid glass, glassmorphism, frosted or iOS 26 glass
  in a Flutter app.
license: MIT
metadata:
  package: g1455
  version: 0.1.x
  homepage: https://g1455.plugfox.dev
  repository: https://github.com/PlugFox/g1455
---

# g1455: Liquid Glass for Flutter

One `GlassHost` captures what is painted under all of its glass into one shared
image, only when something under the glass changed; every glass surface samples
its slot of that capture. Most rules below follow from that.

Package 0.x: the API changes between minor versions. If the project's
`pubspec.lock` resolves g1455 to something other than 0.1.x, check the
[changelog](https://pub.dev/packages/g1455/changelog) before relying on this
file. Requires Flutter >= 3.47. Pure Dart and shaders: no platform setup.

## Setup

```bash
flutter pub add g1455
```

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlassHost.precache(); // compile shaders before the first frame
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Above the navigator: dialogs, sheets, menus and popovers need it too.
    builder: (BuildContext context, Widget? child) => GlassHost(
      backdrop: const Color(0xFF101014), // average colour behind the glass
      richBackdrop: true, // content is images / a feed
      minLabelContrast: kTextContrastAA, // keep labels at WCAG AA
      child: child!,
    ),
    home: const HomePage(),
  );
}
```

Glass goes over content, in a `Stack`:

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: content), // what the glass refracts
    Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: const GlassBar(child: Text('Library')),
    ),
  ],
)
```

For a whole screen (top bar + list + optional tab bar and floating button) use
`GlassScaffold` instead of building the `Stack` by hand:
[references/components/scaffold.md](references/components/scaffold.md).

## Rules

Break one of these and the result is wrong, slow or invisible.

1. **Exactly one `GlassHost`, in `MaterialApp.builder` / `WidgetsApp.builder`.**
   No host above: a surface draws only its child, no glass. Host below the
   `Navigator`: modals throw a debug error. Never one host per widget. Never a
   `GlassTheme` above the host (the host overrides it); nest it below.
2. **Glass needs something behind it.** Put it over content in a `Stack`. Over
   one flat colour it is a grey box: use a plain `Container`/`Card` there.
3. **Declare the backdrop on the host.** Flat page: `backdrop: Color`. Images,
   video, maps, feeds: `richBackdrop: true` plus `minLabelContrast:
   kTextContrastAA`. Glass over photos whose brightness varies across the
   screen: `adaptive: const GlassAdaptive()`.
4. **Let components colour their labels.** `GlassBar`, `GlassCard`,
   `GlassButton`, alert, menu, popover and text field set `DefaultTextStyle`
   and `IconTheme` to black or white. Do not hard-code text/icon colours inside
   them. Material `IconButton` ignores the theme: use plain `Icon` in a
   `GestureDetector`, or pass `IconTheme.of(context).color`.
5. **Glass is for the navigation and controls layer.** Bars, tab bars,
   toolbars, floating buttons, modals, a few panels. Not every card of a feed:
   each surface is one more draw and cost grows faster than the count.
6. **A row of icon actions is one `GlassButtonGroup`**, not N `GlassButton`s.
   Inside a `GlassBar`, plain icons are cheaper than `GlassButton`s (glass on
   glass).
7. **Sibling glass over glass needs `GlassAbove`.** A bar floating over a list
   of `GlassCard`s shows the page with the cards cut out unless wrapped in
   `GlassAbove`. Nested glass (a button inside a bar), `GlassScrollEdge`,
   `GlassScaffold` and all modals already handle this.
8. **Glass that moves over still content goes in a `GlassTravel`**, with a
   `RepaintBoundary` around the content under it and around the moving glass.
   Otherwise every frame of motion is a capture. The built-in switch, slider,
   segmented control and tab bar already do this.
9. **Platform views, `Texture`, video, camera, maps record nothing** into the
   capture: the glass shows a hole. Wrap them in
   `GlassProxy.replace(painter: ..., child: ...)` with a stand-in
   (`SolidProxyPainter`, `GradientProxyPainter`, or a custom
   `GlassProxyPainter`).
10. **Shapes are `BorderRadius` only**, drawn as `RSuperellipse`, one radius per
    surface. `kGlassCapsule` = pill/circle at any size. No paths, stars, or
    different corners. No chromatic aberration/dispersion: not supported, do
    not emulate it.
11. **Finishes:** `GlassFinish.regularDark`, `.regularLight`, `.clear`,
    `.frosted`, or `GlassFinish.regular(appearance:, backdrop:)`. Customise with
    `copyWith(...)` and keep the preset's `name`: an unknown name loses the
    measured tables and captures at full resolution (slower). Default (null) is
    Apple's `.regular`, branch picked from `backdrop` and platform brightness.
    Text on `.clear` needs `minLabelContrast`.
12. **Text-free glass** (lenses, blobs, drops) passes `labelled: false`, so it
    is not dimmed for a label floor.
13. **No `SafeArea` is applied by bars.** Add `MediaQuery.paddingOf(context)`
    to offsets yourself (or use `GlassScaffold`).
14. **Controlled widgets.** `GlassSwitch(value:, onChanged:)`,
    `GlassSlider(value: 0..1, onChanged:)` (needs bounded width: `Expanded` in a
    `Row`; no snapping), `GlassSegmentedControl(segments:, selectedIndex:,
    onSelected:)` and `GlassTabBar(items:, selectedIndex:, onSelected:)` take
    2 to 5 items. `onChanged`/`onSelected: null` disables.
15. **Appearing/leaving:** animate `GlassSurface.materialize` (0..1; blur and
    bend first, tint last; captures every frame while it runs). `presence`
    erodes the shape and is for budding inside a `GlassGroup`; alone it
    narrows to a line.
16. **Tiers are never automatic.** Flutter does not expose Reduce
    Transparency, macOS increase-contrast, or thermal state: read them natively
    and declare them: `tier: GlassTierPolicy(reduceTransparency: ..., ceiling:
    lowEnd ? GlassTier.cheap : null).choose()`, `highContrast:`, `thermal:`.
    Declare `backdrop:` whenever the opaque tier may be used (it fills with it).
    Never ship `GlassTierPolicy(pinned: ...)`: it overrides the user's setting.
17. **Web:** works on CanvasKit and Skwasm; CanvasKit is slow (each capture is a
    GPU readback). Build with `flutter build web --wasm`; where the app runs on
    CanvasKit (`kIsWeb && !kIsWasm`) use `ceiling: GlassTier.cheap`.
18. **Never ship diagnostics:** `content: GlassContentDeclaration.undeclared`,
    `maxCaptures`, `resolution`, `blurPass`, or
    `package:g1455/glass_diagnostics.dart`.
19. **`GlassGroup` / `GlassUnion` are a look, not an optimisation.** They cost
    more than separate surfaces. Members' own finishes are ignored; at most
    `kMaxFusedShapes` (12) fuse. Never wrap the page background in one.
20. **Ripple (`GlassRipple`) is opt-in and not Apple's.** Leave it off for an
    iOS-faithful app. A rippling surface is hit-testable over its whole shape.
21. **Never put glass inside an `Opacity`, `FadeTransition`, `ColorFilter` or
    `ImageFiltered`.** The layer it opens drops the glass. Fade glass with
    `materialize`; hide it with `Visibility`.
22. **A backdrop that does not change is declared, not captured.** Glass over a
    fixed gradient, wallpaper or colour: wrap the page in
    `GlassBackdrop.painter` / `.image` / `.color`, and the glass samples a
    texture made once while the host captures nothing for it. Never over
    content that moves (a list, a video): the glass shows the declaration, not
    the screen. `GlassBackdrop.live` hands a subtree back to the capture.

## Pick the widget

| Need | Use | Reference |
|---|---|---|
| App-wide capture and config | `GlassHost` | [foundations/host](references/foundations/host.md) |
| Custom glass shape, lens, panel | `GlassSurface` | [foundations/surface](references/foundations/surface.md) |
| Material: regular, clear, frosted, custom tint | `GlassFinish` | [foundations/finishes](references/foundations/finishes.md) |
| Label colour, subtree finish/tier/backdrop | `GlassTheme`, `GlassThemeData` | [foundations/legibility](references/foundations/legibility.md) |
| Glass reads its own backdrop | `GlassAdaptive` | [foundations/adaptive](references/foundations/adaptive.md) |
| Reduce transparency, low-end, fallbacks | `GlassTierPolicy`, `GlassTier` | [foundations/tiers](references/foundations/tiers.md) |
| Touch wave | `GlassRipple` | [foundations/ripple](references/foundations/ripple.md) |
| Held-drop stretch/squash | `GlassDropMotion` | [foundations/drop-motion](references/foundations/drop-motion.md) |
| Surfaces that fuse into one silhouette | `GlassGroup`, `GlassUnion` | [foundations/groups](references/foundations/groups.md) |
| Moving glass without captures | `GlassTravel` | [foundations/travel](references/foundations/travel.md) |
| Glass refracting sibling glass | `GlassAbove` | [foundations/above](references/foundations/above.md) |
| Video, platform view, map under glass | `GlassProxy` | [foundations/capture](references/foundations/capture.md) |
| Fixed colour, gradient or wallpaper: skip the capture | `GlassBackdrop` | [foundations/backdrop](references/foundations/backdrop.md) |
| iOS scroll-edge blur under a bar | `GlassScrollEdge` | [foundations/scroll-edge](references/foundations/scroll-edge.md) |
| Cost, surface count, `GlassLedger` | — | [foundations/performance](references/foundations/performance.md) |
| Top/bottom navigation capsule | `GlassBar` | [components/bar](references/components/bar.md) |
| Standalone tappable glass | `GlassButton` | [components/button](references/components/button.md) |
| Floating content panel | `GlassCard` | [components/card](references/components/card.md) |
| On/off | `GlassSwitch` | [components/switch](references/components/switch.md) |
| Continuous 0..1 value | `GlassSlider` | [components/slider](references/components/slider.md) |
| 2–5 views/filters in one screen | `GlassSegmentedControl` | [components/segmented-control](references/components/segmented-control.md) |
| 2–5 app sections | `GlassTabBar`, `GlassTabItem` | [components/tab-bar](references/components/tab-bar.md) |
| Search / single-line input | `GlassTextField`, `.search` | [components/text-field](references/components/text-field.md) |
| Row of icon actions | `GlassButtonGroup`, `GlassToolbarItem` | [components/toolbar](references/components/toolbar.md) |
| Confirmation | `showGlassDialog`, `GlassAlert` | [components/alert](references/components/alert.md) |
| Bottom sheet | `showGlassSheet` | [components/sheet](references/components/sheet.md) |
| "More" menu of actions | `GlassMenuAnchor`, `GlassMenuItem` | [components/menu](references/components/menu.md) |
| Panel of live controls from a button | `GlassPopoverAnchor` | [components/popover](references/components/popover.md) |
| Glass that flows to a new child's size | `GlassMorph` | [components/morph](references/components/morph.md) |
| Whole screen: bar, list, tab bar, FAB | `GlassScaffold` | [components/scaffold](references/components/scaffold.md) |

Background: [start/how-it-works](references/start/how-it-works.md) (what
triggers a capture), [start/declarations](references/start/declarations.md)
(everything the app declares), [start/platforms](references/start/platforms.md)
(renderers, web), [start/installation](references/start/installation.md),
[start/common-errors](references/start/common-errors.md) (symptom, cause and
fix for missing glass, holes, grey boxes, captures on every frame, and every
debug message the package prints).

Each reference has the guide, a complete runnable example, and the full
parameter table. Read the one for the widget you are about to use before
writing it; do not guess parameter names.

## Snippets

```dart
// Menu from a bar button, then a confirmation.
GlassMenuAnchor(
  items: <GlassMenuItem>[
    GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: () => confirm(context)),
  ],
  builder: (BuildContext context, GlassMenuController menu) => GlassButton(
    onPressed: menu.open,
    semanticLabel: 'More',
    padding: EdgeInsets.zero,
    child: const Icon(Icons.more_horiz),
  ),
);

Future<bool?> confirm(BuildContext context) => showGlassDialog<bool>(
  context: context,
  builder: (BuildContext context) => GlassAlert(
    title: const Text('Delete?'),
    message: const Text('This cannot be undone.'),
    actions: <GlassAlertAction>[
      GlassAlertAction(label: 'Cancel', isDefault: true, onPressed: () => Navigator.pop(context, false)),
      GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context, true)),
    ],
  ),
);

// A bar over a list of glass cards: lift it so it refracts them.
const GlassAbove(child: GlassBar(child: Text('Cards')));

// A video under glass.
GlassProxy.replace(
  painter: const GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF1B1F2A), Color(0xFFFF9F0A)])),
  child: videoPlayer,
);

// A custom lens: clear, text-free, a circle.
const SizedBox.square(
  dimension: 96,
  child: GlassSurface(borderRadius: kGlassCapsule, finish: GlassFinish.clear, labelled: false),
);
```

## Verify

- Glass missing, grey, or capturing every frame, or a debug message from the
  package: look it up in
  [start/common-errors](references/start/common-errors.md) before changing
  code.
- `flutter analyze` must be clean; parameter names come from the references.
- Widget tests: the first frame of a screen has no glass (the capture lands a
  frame later). Pump at least one more frame before asserting on glass. Glass
  widgets need a `GlassHost` ancestor in the test tree as in the app;
  modals need it above the `Navigator`.
- `debugPaintGlassSurfaces = true` outlines every surface in debug builds.
- Surface count and cost at runtime:
  `GlassScope.maybeOf(context)?.read(viewSize: MediaQuery.sizeOf(context), model: GlassHardware.detect().surfaceCostModel)`.
- Measure performance in profile mode on a device, never in debug.

## More

- Live site with every component: https://g1455.plugfox.dev
- All pages as one file for agents: https://g1455.plugfox.dev/llms-full.txt
- API reference: https://pub.dev/documentation/g1455/latest/g1455/
- Source: https://github.com/PlugFox/g1455
