import '../catalog.dart';

/// Getting started: install, how it works, what the app declares, platforms.
const List<Entry> kStartEntries = <Entry>[
  Entry(
    section: Section.start,
    id: 'installation',
    title: 'Installation',
    icon: 'download',
    summary: 'Add the package, put one GlassHost above the navigator, and lay the first glass over content.',
    api: <String>['GlassHost', 'GlassBar', 'kTextContrastAA'],
    source: 'lib/src/surface/glass_host.dart',
    guide: r'''
g1455 draws Liquid Glass in Flutter: refraction, blur, tint and a rim over whatever is painted behind it. Getting it on
screen takes three steps: add the package, put one `GlassHost` at the top of the app, and place glass over some content.

The package is pure Dart and shaders. It ships no platform code, so there is nothing to configure in Xcode or Gradle.

## Install

```bash
flutter pub add g1455
```

It needs Flutter 3.47 or later. Then import it wherever you use glass:

```dart
import 'package:g1455/g1455.dart';
```

## Add the host

Every piece of glass needs a [GlassHost](/foundations/host) above it. The host records what is painted under all the
glass of the screen into one shared image, and every surface samples its own slice of it. Without a host, a glass
surface draws **no glass at all**, only its child.

Put the host in the `builder:` of your `MaterialApp` (or `WidgetsApp`, `CupertinoApp`). That places it above the
navigator, which is also where dialogs, sheets, menus and popovers are built, so they find the host too:

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(child: child!),
  home: const HomePage(),
)
```

One host per app is the normal setup. Don't nest a host around each widget.

## The first glass

Glass shows what is behind it, so it needs something behind it: lay it over content in a `Stack`.
[GlassBar](/components/bar) is a floating capsule for navigation that also picks a legible label colour for its
children:

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: content), // what the glass refracts
    const Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GlassBar(child: Text('Library')),
    ),
  ],
)
```

The "Code" tab has a complete `main.dart` with a scrolling list under a bar.

> [!TIP]
> Tell the host what is behind the glass. For a list of photos or a feed, pass `richBackdrop: true` and
> `minLabelContrast: kTextContrastAA`; over a flat colour, pass `backdrop:`. Labels are then chosen and kept readable
> for that case. See [Legibility & theme](/foundations/legibility).

## The first frame has no glass

The host captures the backdrop after a frame has been painted, and the glass draws that capture on the next frame. So
the very first frame of a screen shows the glass's children without the glass itself. That is by design and is not
visible in practice, but it matters in widget tests: pump one more frame before you look for glass.

## Compile the shaders before the first frame

The host loads the package's shaders when it mounts, and a shader is compiled asynchronously. Until it lands, glass
that has a capture draws a stand-in: the captured, blurred backdrop clipped to its shape, with no tint, rim or bend.
Compile them before `runApp` and the first frame that has a capture is drawn through the optics:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlassHost.precache();
  runApp(const MyApp());
}
```

`GlassHost.precache()` shares the loads a host starts on its own, so nothing is compiled twice, and once the programs
are in it costs nothing. `group: false` and `ripple: false` leave out the programs of [groups](/foundations/groups) and
the [ripple](/foundations/ripple) for an app that uses neither. It completes with the error of a load that fails, so
catch it if the app should start regardless.

## Next steps

- [How it works](/start/how-it-works): one capture for the whole screen, and only when something changed.
- [What the app declares](/start/declarations): the backdrop, reduce transparency, contrast, thermal state.
- [GlassHost](/foundations/host) and [GlassSurface](/foundations/surface): the two building blocks.
- [Finishes](/foundations/finishes): regular, clear and frosted glass.
- [Scaffold](/components/scaffold): a whole screen, a bar, a tab bar and a list scrolling under them, wired for you.
- The components: [Bar](/components/bar), [Button](/components/button), [Card](/components/card),
  [Switch](/components/switch), [Slider](/components/slider), [Tab bar](/components/tab-bar),
  [Alert](/components/alert), [Sheet](/components/sheet) and more.
- [Adaptive glass](/foundations/adaptive): glass that reads its backdrop, for screens over photographs.
- [Performance](/foundations/performance): what glass costs and how to keep it cheap.
- [Misuse & common errors](/start/common-errors): missing glass, holes, grey boxes, and what the debug messages mean.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compiles the shaders before the first frame, so the first glass on screen
  // is drawn through its optics.
  await GlassHost.precache();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glass',
    theme: ThemeData.dark(),
    // One host for the whole app, above the navigator, so pages, dialogs,
    // sheets and menus are all under it.
    builder: (BuildContext context, Widget? child) => GlassHost(
      // A feed of colourful tiles scrolls under the glass: choose labels for
      // the worst case, and keep them at WCAG AA.
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      backdrop: const Color(0xFF101014),
      child: child!,
    ),
    home: const LibraryPage(),
  );
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Stack(
        children: <Widget>[
          // The content: what the glass refracts.
          ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 76, 16, safe.bottom + 16),
            itemCount: 30,
            itemBuilder: (BuildContext context, int i) => Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: <Color>[
                    HSVColor.fromAHSV(1, (i * 37) % 360.0, 0.7, 0.9).toColor(),
                    HSVColor.fromAHSV(1, (i * 37 + 60) % 360.0, 0.8, 0.5).toColor(),
                  ],
                ),
              ),
            ),
          ),
          // The glass: a bar floating over the list.
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(
              child: Row(
                children: <Widget>[
                  Icon(Icons.photo_library_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.search),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''',
  ),
  Entry(
    section: Section.start,
    id: 'how-it-works',
    title: 'How it works',
    icon: 'lightbulb',
    summary:
        'One host captures the backdrop once for every glass surface, only when something under the glass changed.',
    api: <String>['GlassHost', 'GlassTravel'],
    source: 'lib/src/surface/glass_host.dart',
    guide: r'''
Most glass packages put a `BackdropFilter` on every surface, which means the engine reads the backdrop once per surface
on every frame. g1455 takes a different route, built for cost first: one capture for the whole screen, taken only when
it has to be, and a blur that comes almost for free.

Knowing the route helps you predict what is cheap and what is not, which is most of what there is to know about
performance with this package.

## One host, one capture

A [GlassHost](/foundations/host) records what is painted under **all** of its glass into one atlas, at a resolution
picked against a measured quality budget. Every surface then samples its own slot of that atlas and draws the
refraction, blur, tint and rim in one shader pass.

So ten surfaces do not mean ten reads of the backdrop. They mean one capture and ten draws.

## A capture only when something changed

The host walks the composited layer tree. When nothing under the glass changed, it keeps the capture it already has.
That covers a still screen, and a moving glass over content that stays put.

Keeping the capture is the default, and it is the biggest saving in the package: 79.4% and 66.3% of the route's added
cost on Adreno, 97.8% on Metal.

What triggers a new capture:

- content under the glass repaints: a list scrolls under a bar, an animation plays behind a card, a video runs;
- the glass appears, disappears, resizes or moves to a new place;
- a surface's `materialize` animates, because that changes the blur.

What does not:

- a still screen, however much glass it has;
- glass moving inside a [GlassTravel](/foundations/travel) region over still content, such as a slider's knob, a
  dragged lens or orbiting blobs;
- a blinking caret or typing in a [text field](/components/text-field);
- repaints that happen away from every glass surface.

## The blur is a downscale

A capture taken at 1/N of the screen's resolution and scaled back up is a Gaussian blur of σ ≈ N/2, to within about
1%, at a fraction of the price of a real Gaussian. The host picks the downscale for each finish against measured
quality tables: a blurry finish such as [frosted](/foundations/finishes) tolerates a smaller capture, and clear glass,
which has no blur, needs a sharper one.

## What it costs

Measured costs, each on its own platform, because the platforms are not comparable:

| platform | glass vs stock Material | engine `BackdropFilter.grouped` |
|---|---|---|
| Android, Impeller/Vulkan, Adreno 830 (GPU cycles) | ×0.99…1.08 | ×1.78…3.15 |
| iPad, Impeller/Metal (GPU ms, scrolling screen) | ×1.93…2.02, or ×1.46…1.54 with thermal throttling | — |

## Where the numbers come from

Every number on this site was measured in a profile build, on the device named, before the package's first release:
the code that became 0.1.0 on 2026-10-03, on Flutter **3.47.1** stable (framework `6655482ec0`, engine `5d53178869`,
Dart 3.13.1). The raw digests are in
[`provenance/`](https://github.com/PlugFox/g1455/tree/master/provenance) in the repository.

| device | GPU | system | renderer | metric | dates |
|---|---|---|---|---|---|
| Samsung Galaxy S25 Ultra (SM-S938B) | Snapdragon 8 Elite, Adreno 830 | Android 16 | Impeller, Vulkan; 1080×2340 at 3×, 120 Hz | GPU cycles a frame (kgsl `busy × freq`), windows of 30 s × 3 | 2026-08-24 to 2026-09-23 |
| iPad Pro 11″, 4th generation (iPad14,3) | Apple M2 | iPadOS 26.6.1 | Impeller, Metal; 1668×2388 at 2×, 120 Hz | GPU ms a frame (the engine's `GPUTracer`), after a reboot, windows of 4 s × 3 | 2026-09-08 to 2026-09-26 |
| Samsung Galaxy S22 Ultra (SM-S908B) | Exynos 2200, Xclipse 920 | Android 16 | Impeller, Vulkan; 720×1544 | GPU `busy × freq`, which does not see the capture: a cross-check only | 2026-09-08 to 2026-09-26 |
| MacBook Pro | Apple M3 Max | macOS 26.4.1 | Impeller, Metal; 1600×1200 at 2× | raster ms a frame | 2026-09-15 |

The ratios compare scenes on one device, run in one binary in a shuffled order. They do not carry from one device to
another, and they are not frame times.

## What this means for your app

- A still screen with glass costs almost nothing beyond drawing the glass itself.
- Glass that moves over still content belongs in a [GlassTravel](/foundations/travel) region. The built-in switch,
  slider, segmented control and tab bar already do this.
- Content that changes under glass costs one capture per changed frame. That is the honest price of a list scrolling
  under a bar, and it is still one capture, not one per surface.
- Each surface is still one draw, and the overhead grows faster than the count. Keep glass in the navigation and
  controls layers. See [Performance](/foundations/performance).
- Glass on top of other glass needs one capture per level. Glass nested inside glass gets that automatically;
  sibling glass that floats above other glass needs [GlassAbove](/foundations/above).

> [!NOTE]
> If you have reason to distrust the change detection, `GlassHost(content: GlassContentDeclaration.undeclared)`
> re-captures every frame. It is the most expensive thing the package can be asked to do; use it to rule the
> detection out, not to ship.
''',
  ),
  Entry(
    section: Section.start,
    id: 'declarations',
    title: 'What the app declares',
    icon: 'visibility',
    summary: 'What the package cannot read from the render tree: the backdrop, reduce transparency, contrast, thermal state.',
    api: <String>['GlassHost', 'GlassTierPolicy', 'GlassThermalState', 'GlassHardware'],
    source: 'lib/src/surface/glass_host.dart',
    guide: r'''
Some things the glass needs to know are not in the render tree, and Flutter does not pass some platform settings on.
g1455 ships no platform code to go and read them, so the application declares them, all as parameters of
[GlassHost](/foundations/host). Everything here is optional: leave a declaration out and you get a safe default.

## What is behind the glass

Components such as [GlassBar](/components/bar) and [GlassCard](/components/card) choose black or white text. To choose
well, the host needs to know what the glass sits over:

- `backdrop:` the screen's average background colour, for a flat background. It is also what the opaque tier fills
  with, so declare it whenever you might use that tier.
- `richBackdrop: true` for an image, a video, a map or a feed. Labels are then chosen for the worst case over any
  backdrop.
- `minLabelContrast:` a contrast floor, such as `kTextContrastAA` (4.5, WCAG AA for body text). When the finish cannot
  reach it, the glass is dimmed just enough to do so.

Without any of these, labels are picked against the worst case, and in debug the package warns once when a finish
cannot be read over it. More on [Legibility & theme](/foundations/legibility).

## Reduce transparency

Flutter does not expose the operating system's Reduce Transparency switch. Read it natively and pass it to a
[GlassTierPolicy](/foundations/tiers), which answers with the opaque tier:

```dart
GlassHost(
  backdrop: const Color(0xFF101014), // the opaque tier fills with this
  tier: GlassTierPolicy(reduceTransparency: reduceTransparency).choose(),
  child: child,
)
```

The same policy takes a `ceiling` for low-end devices, such as `GlassTier.cheap`. The package never switches tiers on
its own.

## Increase contrast

`GlassHost.highContrast` draws an opaque, visible outline instead of the subtle rim. On iOS and on Android 34 and
later the host already reads it from `MediaQuery`. On macOS the engine does not pass it on, so read it natively and
pass `highContrast: true`.

## Thermal state

Pass the device's thermal state as a `GlassThermalState` (`nominal`, `fair`, `serious`, `critical`, Apple's four
names). Under `serious` and `critical` the host may reuse a slightly stale capture for a frame or two on screens that
change. Blurry finishes tolerate that; `clear` gets none. Tiers are never changed by thermals.

On Android, map `PowerManager`'s thermal status: NONE to `nominal`, LIGHT and MODERATE to `fair`, SEVERE to
`serious`, and CRITICAL, EMERGENCY and SHUTDOWN to `critical`.

## Hardware

`GlassHost.hardware` says which device family's measurements apply. `GlassHardware.detect()` returns `appleMetal` on
iOS and macOS and `unmeasured` elsewhere, because Dart cannot name the GPU. Declare `adrenoVulkan` only for a
Snapdragon with an Adreno 830-class GPU. Undeclared hardware gets the same behaviour with no price attached: it changes
reported costs and the default texture limit, never correctness.

> [!WARNING]
> A `GlassTierPolicy(pinned: ...)` overrides everything, the user's Reduce Transparency setting included. Pin a tier
> for tests and benchmarks, not for users.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// The settings the package cannot read for itself. Fill them from your own
/// platform code (a method channel, a plugin) and rebuild when they change.
class DeviceSignals {
  const DeviceSignals({
    this.reduceTransparency = false,
    this.increaseContrast,
    this.thermal = GlassThermalState.nominal,
    this.lowEndDevice = false,
  });

  final bool reduceTransparency;
  final bool? increaseContrast; // null: let the host read MediaQuery
  final GlassThermalState thermal;
  final bool lowEndDevice;
}

class DeclaredApp extends StatelessWidget {
  const DeclaredApp({super.key, required this.signals, required this.home});

  final DeviceSignals signals;
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) => GlassHost(
      // What is behind the glass: a feed over a near-black page.
      backdrop: const Color(0xFF101014),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      // Reduce transparency gives the opaque tier; a low-end device stops at cheap.
      tier: GlassTierPolicy(
        reduceTransparency: signals.reduceTransparency,
        ceiling: signals.lowEndDevice ? GlassTier.cheap : null,
      ).choose(),
      highContrast: signals.increaseContrast,
      thermal: signals.thermal,
      hardware: GlassHardware.detect(),
      child: child!,
    ),
    home: home,
  );
}
''',
  ),
  Entry(
    section: Section.start,
    id: 'platforms',
    title: 'Platforms & web',
    icon: 'devices',
    summary: 'The same glass on Impeller (Metal, Vulkan, GLES), on Skia, and on the web with CanvasKit and Skwasm.',
    guide: r'''
g1455 is Dart and fragment shaders, with no platform code of its own. The glass renders byte-identically on Impeller
and on Skia, and it works on the web.

## Renderers

- **Impeller** on Metal (iOS, macOS), Vulkan and GLES (Android).
- **Skia/GLES**, which Android falls back to below API 29 and on Vivante GPUs.

There is nothing to switch on per platform: the same `GlassHost` and the same surfaces work everywhere.

## Web

The glass works on Flutter web with both renderers, **CanvasKit** and **Skwasm**. This very site is a Flutter web app:
every demo on it is the package running in your browser, under one `GlassHost` in the app's `builder:`.

CanvasKit is the slow one. Every capture goes through `Picture.toImageSync`, which on CanvasKit reads the pixels back
from the GPU and waits for them: on a MacBook Pro with an M3 Max (macOS 26.4.1), a frame of full glass on this site took
15 to 30 ms on CanvasKit and 4 to 10 ms on Skwasm, in WebKit and in Chromium alike (g1455 0.1.1 on Flutter 3.47.1,
2026-10-04). Flutter picks Skwasm only in Chromium browsers unless the app allows WebKit too; where an app still runs
on CanvasKit, a [cheaper tier](/foundations/tiers) captures nothing and the two renderers are level there.

> [!NOTE]
> Browsers do not tell an app about Reduce Transparency, increased contrast or thermal state. Declare what you know,
> as on any platform: see [What the app declares](/start/declarations).

## Shaders

Every bundled shader is compiled for all five shader targets (SkSL, Vulkan, GLES, GLES3 and Metal) in the package's
own test suite, so a shader that one of the compilers would reject fails the package's tests rather than your app.

## Hardware and cost

What the glass costs differs between GPU families, and the package's measurements come from two of them: an Adreno 830
on Vulkan and Apple GPUs on Metal; the devices, systems and dates are in
[Where the numbers come from](/start/how-it-works). On other hardware the glass works the same; only the reported prices are missing.
See [What the app declares](/start/declarations) for `GlassHost.hardware`, and [Performance](/foundations/performance)
for keeping the cost down on any device.
''',
  ),
  Entry(
    section: Section.start,
    id: 'common-errors',
    title: 'Misuse & common errors',
    icon: 'healing',
    summary:
        'What goes wrong with glass and why: missing glass, holes, grey boxes, a capture on every frame, and the debug '
        'messages the package prints, each with its fix.',
    api: <String>['GlassHost', 'GlassSurface', 'GlassProxy', 'GlassTravel', 'GlassAbove', 'debugPaintGlassSurfaces'],
    source: 'lib/src/surface/glass_host.dart',
    guide: r'''
Most mistakes with glass fail quietly: no exception, only glass that is missing, grey, or captured on every frame.
Each entry below is a symptom, its cause and the fix. Where a debug build says something, the message is quoted as it
starts.

To see where the glass is, set `debugPaintGlassSurfaces = true` in a debug build: every surface gets a cyan outline.

## Setup

### Only the children are drawn, with no glass

A surface samples the capture of the [GlassHost](/foundations/host) above it. With no host above, it paints its child
over nothing, and says nothing. Put one host in the app's `builder:`, as in [Installation](/start/installation).

### "GlassAlert was built with no GlassHost above it."

The same error names "A glass sheet", or the panel of a menu or a popover. A dialog and a sheet are built in the
navigator's overlay, and a menu and a popover in the nearest overlay, so a host around one screen, inside the route,
does not reach them. That includes the host [GlassScaffold](/components/scaffold) mounts when there is none above it.
The check runs in debug only; in release the modal shows without glass. Move the host above the navigator:

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(child: child!),
  home: const HomePage(),
)
```

### A GlassTheme above the host changes nothing

The host installs a theme of its own, built from its parameters, for everything under it, so a `GlassTheme` above the
host is overridden. Declare screen-wide settings on `GlassHost`, and put a `GlassTheme` below it to change a subtree.

### The first frames show no glass, then a blur with no tint or rim

Two delays, of which only one is avoidable. The host captures a frame after it has been painted, so the first frame of
any screen has no glass; that is by design. The shaders compile asynchronously, and until they arrive, glass that has a
capture draws the blurred backdrop clipped to its shape, without tint, rim or bend. `await GlassHost.precache()` in
`main()` compiles them before the first frame. A shader that fails to load is reported "while loading a glass shader",
and the glass keeps drawing that stand-in.

## What the glass shows

### A hole over a video, a map or a platform view

The host captures what is under its glass by painting that part of the tree a second time. A platform view, a
`Texture`, a video or a camera preview paints outside Flutter's pictures and records nothing. Wrap it in
`GlassProxy.replace` with a stand-in, as on [Capture control](/foundations/capture). A stand-in changes what the glass
sees, not when the host captures: a video that composites a new frame is still a change.

### Glass inside an Opacity or a fade disappears

An `Opacity` below 1, an `AnimatedOpacity` or a `FadeTransition` mid-animation, a `ColorFilter` or an `ImageFiltered`
opens a layer, and glass inside that layer does not survive it. On the [cheap tier](/foundations/tiers) the rim and the
press highlight, which add light to what is under them, add it to the layer instead: one `Opacity(0.99)` above a
button takes its press from +50 code values to +4.

To fade glass, animate the surface's `materialize` (blur first, tint last); to hide it, use `Visibility`. The package
does both itself: its alert materializes, and a menu hides its anchor button with `Visibility`.

```dart
// Not Opacity(opacity: t, child: GlassSurface(...)).
GlassSurface(materialize: t, child: label)
```

Content that fades *under* the glass is fine: the host sees the fade and captures it.

### A bar over glass cards shows the page with the cards cut out

The bar is the cards' sibling, and sibling glass does not see sibling glass. Wrap the bar in
[GlassAbove](/foundations/above), which raises it a level so it refracts the cards. Glass nested inside glass, a
[scroll edge](/foundations/scroll-edge) and the package's modals are lifted already.

### An unlifted bar shows up blurred inside a scroll edge

Levels are a declaration, not paint order: glass beside a lifted subtree is drawn into its capture even when it is
painted on top of it. Lift the bar with the edge; `GlassScrollEdge.child` does that for you.

### A surface that replaces another at the same place draws nothing

A known issue, not yet fixed: when a host replaces one surface with another at exactly the same rect, it keeps the old
capture, and the new surface draws nothing until something else under the glass changes.

### A tab bar with minimizeBehavior: onScrollDown never collapses

A scroll notification travels only up the tree, and the bar is the scroll view's sibling, not its child, so it hears
nothing by itself. Put a `GlassTabBarMinimizer` above both the scroll view and the bar; a
[GlassScaffold](/components/scaffold) is one already. Only the nearest vertical scroll view counts: a list nested in
another scroll view, or a horizontal one, does not collapse the bar. See [Tab bar](/components/tab-bar).

## Look and legibility

### "A glass component has no GlassThemeData.backdrop, and its finish is not legible over every backdrop"

Printed once, in debug. Nothing said what is behind the glass, so the label was chosen against every backdrop, and
none reaches WCAG AA over the worst of them. Declare the screen's background as `GlassHost(backdrop: ...)` if it is
flat, or `richBackdrop: true` with `minLabelContrast: kTextContrastAA` over an image or a feed: the glass is then dimmed
until the label reaches the floor. Or let the glass measure it: [adaptive glass](/foundations/adaptive). See
[What the app declares](/start/declarations).

### "GlassTier.opaque with no GlassThemeData.backdrop declared."

The opaque tier transmits nothing, so it fills with the level the glass would show over the declared `backdrop`.
Without one the fill is the finish's tint itself, much darker than the glass: 29 of 255 for `GlassFinish.regularDark`,
against the 69 the glass shows over mid-grey. Declare `backdrop:` whenever the opaque tier can be chosen, which includes
every app that passes Reduce Transparency to a `GlassTierPolicy`.

### Glass over a flat colour is a grey box

Glass shows what is behind it, bent, blurred and tinted; over one flat colour that is the same colour, tinted. Put
glass over content, in a `Stack`. Over a plain page, a plain `Container` or `Card` is the honest choice.

### A lens or a held drop looks grey

A surface counts as labelled by default, and the label floor (`minLabelContrast`) dims the glass for a label it does
not have. Pass `labelled: false` to glass that carries no text.

### Labels or icons in a bar have the wrong colour

[GlassBar](/components/bar), [GlassCard](/components/card), [GlassButton](/components/button) and the modals set
`DefaultTextStyle` and `IconTheme` to the legible colour, black or white. A colour hard-coded inside them overrides
it, and so does a widget that takes its colour from the app's `ThemeData` rather than from those two. Leave the colour
out, or pass `IconTheme.of(context).color` on.

### Adaptive glass does not adapt

`GlassHost(adaptive: GlassAdaptive())` re-picks the glass for bars, cards and buttons only. A raw `GlassSurface`, a
`GlassScrollEdge`, the tab bar and the segmented control keep the branch picked from `backdrop`, and a fused group's
members adapt only their labels. A finish that is named anywhere, on the surface, the component, the host or a theme,
is held, and only its label follows the reading.

### "N of M surfaces in a GlassGroup name their own finish."

A fused [group](/foundations/groups) is one draw with one set of optics, so the group's finish is what ships and the
members' are ignored. Put the finish on the `GlassGroup`, or take the surface out of it. For the same reason a member
of a fusing group draws no `fade` and no ripple.

### "A GlassGroup holds 13 surfaces; the fused draw carries 12."

`kMaxFusedShapes` is 12. Past it the group is refused rather than truncated: its members draw themselves, and the
bridges between them are missing. Split the group, or fuse fewer surfaces.

### A ripple does not show

[GlassRipple](/foundations/ripple) is off while the platform asks for reduced motion, below `GlassTier.full`, and on a
member of a fusing group. It is also off by default: declare it on `GlassHost.ripple` or on the surface.

### A panel appearing through presence narrows to a line

`presence` erodes the shape and is for budding inside a `GlassGroup`; a lone panel erodes to its middle line. Animate
`materialize` to make a panel appear or leave.

### A shape inside glass sits badly in its corners

A highlight, a thumb or an inner panel inset in glass looks off when its corner does not share the glass's centre of
curvature. Its radius is the glass's less the inset: `GlassConcentric.radius(outer, inset)`, or
`GlassConcentric.borderRadius(outer, insets)` per corner, rather than a number that agrees by accident until one of the
two moves. See [GlassSurface](/foundations/surface).

### A badge drawn as glass is a different red over every backdrop

Apple's badge is opaque, on the glass and not of it, so that it reads at a glance over anything. A translucent glass
pill is one more surface and a colour that changes with what is behind it. Use [GlassBadge](/components/badge), a plain
capsule that costs no surface.

## Cost

### Moving glass captures on every frame

A surface's slot in the capture is its own box, so glass that moves is captured again wherever it goes. Wrap the
region it moves in in a [GlassTravel](/foundations/travel): the host captures the whole region once, and moving over
still content inside it captures nothing. The switch, slider, segmented control and tab bar already do this.

### Glass inside a GlassTravel still captures as it moves

Motion is free only if moving the glass repaints nothing else, because a repaint under the glass is changed content.
Put the still content behind a `RepaintBoundary` of its own and the moving glass behind another, so the moving glass's
parent paints nothing. A surface that leaves the region is captured again.

### A minus and a plus are two surfaces

Two [GlassButton](/components/button)s side by side are two glasses. A [GlassStepper](/components/stepper) is one
capsule, with the divider and the held half drawn inside it, and a press that costs no capture.

### The search bar captures when it takes or loses the focus

Cancel slides in as the field takes the focus, and the field's glass narrows to make room: glass whose box changes is
retaken, a capture a frame for `cancelDuration`, 16 over 250 ms at 60 Hz in the package's tests, each way. A
`GlassTravel` does not help, because it is the resize that costs, not Cancel's paint. `showsCancelButton: false` keeps
the box still; under reduced motion the slide is one frame. See [Search bar](/components/search-bar).

### A change inside a large sheet captures

An opaque large sheet (the default `largeFinish`) reads no backdrop and is drawn on the cheap tier, which saves its
capture: one surface fewer in it, 20,608 px² against 337,408 headless. But a cheap surface is ordinary content to the
capture of the glass around it, so a change inside the sheet is a retake where a glass sheet took none. A sheet whose
content animates may be cheaper with a translucent `largeFinish`. See [Sheet](/components/sheet).

### Every press of a button captures twice

The press swells the glass inside a travel region declared from touch-down until the spring settles: one capture as
the region appears and one as it goes, nothing while it moves and nothing at rest. `GlassPress.none`, on
`GlassHost.press`, a theme or one button, keeps the box still and builds no region.

### A tab bar rebuilt by a bare setState captures once

A known cost, not yet traced: a `setState` that rebuilds a [GlassTabBar](/components/tab-bar) costs one capture even
when nothing it draws changed. Rebuild the bar when its selection or its items change, not with every change of the
screen around it.

### A page control captures while the pages turn

It does not: the `PageView` moving under the glass does, 43 captures a swipe in the package's tests, the same with the
dots following and with dots that stay put. Content that moves under glass is a capture a frame. See
[Page control](/components/page-control).

### A slider rounded in onChanged is told every frame

Rounding the value yourself leaves the knob between the stops and calls `onChanged` on every frame of a drag. Pass
`divisions`: every input lands on a stop, and `onChanged` is called only when the stop changes. See
[Slider](/components/slider).

### A custom finish costs more than the preset it came from

A finish's `name` is its key into the measured quality tables. A name that is not in them gets no measured damage, so
the host does not lower the capture's resolution for it. Derive a custom finish with `copyWith` from the preset it is
closest to, which keeps the name.

### Too much glass

Each surface is one more draw, and the cost grows faster than the count. Keep glass to the navigation and controls
layer, not every card of a feed. A row of icon actions is one [GlassButtonGroup](/components/toolbar), and plain icons
inside a bar are cheaper than glass buttons, which are glass on glass: a level, and a snapshot per captured frame.
[GlassGroup and GlassUnion](/foundations/groups) are a look, not a saving: twelve clustered surfaces grouped cost
1.60 to 1.65 times the same twelve ungrouped. See [Performance](/foundations/performance).

### Glass is coarser on a large window

The capture must fit the GPU's texture limit, and the host's only answer to hitting it is a coarser capture. The limit
it assumes is the specification's floor, not the device's: 4096 on Vulkan, 8192 on Metal, 2048 on GLES. Every GPU the
package was measured on allocates 16384; a host that knows its device can say so with `GlassHost(maxTextureSide:)`.

### Every frame captures, still screen or not

`GlassHost(content: GlassContentDeclaration.undeclared)` re-captures on every frame. It exists to rule the change
detection out, and is the most expensive thing the package can be asked to do; don't ship it. The same goes for
`maxCaptures`, `resolution`, `blurPass` and `package:g1455/glass_diagnostics.dart`.

### Slow on the web outside Chromium

CanvasKit reads every capture back from the GPU. Build with `--wasm`, and where the app still runs on CanvasKit,
declare the cheap tier. See [Platforms & web](/start/platforms).

## Platform settings

### Reduce Transparency, increased contrast or thermal state change nothing

Flutter does not pass Reduce Transparency or thermal state on, nor increased contrast on macOS, and the package ships
no platform code to read them. Read them natively and declare them: `GlassTierPolicy(reduceTransparency: ...)`,
`GlassHost.highContrast`, `GlassHost.thermal`. Tiers never change on their own. See
[What the app declares](/start/declarations).

### The user's Reduce Transparency is ignored

`GlassTierPolicy(pinned: ...)` overrides everything, the user's setting included. Pin a tier in tests and benchmarks,
never for users; for a low-end device, pass a `ceiling` instead.

## Widget tests

### No glass on the first pump

Glass widgets need a `GlassHost` above them in the test as in the app, and above the `Navigator` for modals. The first
frame has no glass, because the capture lands a frame later: pump at least one more frame before looking for it.

### await GlassHost.precache() never completes

The shader load needs real time, and a widget test's fake clock does not give it. Alternate `tester.runAsync` with
`tester.pump` until the future completes, or leave the precache out: the host loads the shaders on its own.
''',
  ),
  Entry(
    section: Section.start,
    id: 'agents',
    title: 'AI agents',
    icon: 'auto_awesome',
    summary:
        'An agent skill for Claude Code, Codex, Cursor, Antigravity, Gemini CLI and Copilot: the rules for writing '
        'glass, and every page of this site, installed with one command.',
    guide: r'''
g1455 ships an [agent skill](https://agentskills.io): a `SKILL.md` that tells a coding agent how to write glass that
works the first time (one host above the navigator, what the app declares, what costs a capture, which widget fits),
with every page of this site beside it as a reference file. The agent loads it on its own when a project uses g1455 or
you ask for liquid glass, and reads a component's page before it writes one.

## Any agent

```bash
npx skills add PlugFox/g1455
```

The installer ([skills.sh](https://skills.sh)) asks which agents to install for and puts the skill where each one looks.
`-a claude-code -a codex` picks agents without asking, `-g` installs for your user instead of the project, `-y` skips
the questions. `npx skills update` brings it up to date.

The same works from this site's address, which publishes the skill at
`/.well-known/agent-skills/index.json`:

```bash
npx skills add https://g1455.plugfox.dev
```

## Claude Code

The repository is a plugin marketplace with the skill as its one plugin. In Claude Code:

```text
/plugin marketplace add PlugFox/g1455
/plugin install g1455@g1455
```

`/plugin marketplace update g1455` fetches a newer one.

## Without Node

The skill is one archive. Unpack it where your agent looks for skills:

```bash
mkdir -p .agents/skills/g1455
curl -fsSL https://g1455.plugfox.dev/.well-known/agent-skills/g1455.tar.gz | tar -xz -C .agents/skills/g1455
```

| Agent | In the project | For your user |
|---|---|---|
| Claude Code | `.claude/skills/g1455` | `~/.claude/skills/g1455` |
| Codex, Cursor, Antigravity, Gemini CLI, GitHub Copilot | `.agents/skills/g1455` | `~/.agents/skills/g1455` |

Commit the project's copy and everyone working on the app gets it.

## Without installing

Tell the agent to read the skill from the site, and it follows the links it needs:

```text
Read https://g1455.plugfox.dev/SKILL.md and follow it.
```

Every page of the site is also markdown at its address plus `.md`, such as
[/components/slider.md](https://g1455.plugfox.dev/components/slider.md). [llms.txt](https://g1455.plugfox.dev/llms.txt)
lists them all, and [llms-full.txt](https://g1455.plugfox.dev/llms-full.txt) is every page in one file.

> [!NOTE]
> The skill describes the package's current version, and the API is 0.x. Update the skill when you update the package;
> it tells the agent to check the changelog when the versions differ.
''',
  ),
];
