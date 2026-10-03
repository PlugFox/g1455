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

## Next steps

- [How it works](/start/how-it-works): one capture for the whole screen, and only when something changed.
- [What the app declares](/start/declarations): the backdrop, reduce transparency, contrast, thermal state.
- [GlassHost](/foundations/host) and [GlassSurface](/foundations/surface): the two building blocks.
- [Finishes](/foundations/finishes): regular, clear and frosted glass.
- The components: [Bar](/components/bar), [Button](/components/button), [Card](/components/card),
  [Switch](/components/switch), [Slider](/components/slider), [Tab bar](/components/tab-bar),
  [Alert](/components/alert), [Sheet](/components/sheet) and more.
- [Performance](/foundations/performance): what glass costs and how to keep it cheap.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const GlassApp());

class GlassApp extends StatelessWidget {
  const GlassApp({super.key});

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

> [!NOTE]
> Browsers do not tell an app about Reduce Transparency, increased contrast or thermal state. Declare what you know,
> as on any platform: see [What the app declares](/start/declarations).

## Shaders

Every bundled shader is compiled for all five shader targets (SkSL, Vulkan, GLES, GLES3 and Metal) in the package's
own test suite, so a shader that one of the compilers would reject fails the package's tests rather than your app.

## Hardware and cost

What the glass costs differs between GPU families, and the package's measurements come from two of them: an Adreno 830
on Vulkan and Apple GPUs on Metal. On other hardware the glass works the same; only the reported prices are missing.
See [What the app declares](/start/declarations) for `GlassHost.hardware`, and [Performance](/foundations/performance)
for keeping the cost down on any device.
''',
  ),
];
