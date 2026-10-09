# GlassHost

> The engine room of a screen: one capture of the backdrop for all its glass, re-taken only when it changed.

- Live: https://g1455.plugfox.dev/foundations/host
- API: [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassThermalPolicy`](https://pub.dev/documentation/g1455/latest/g1455/GlassThermalPolicy-class.html), [`ProxyResolution`](https://pub.dev/documentation/g1455/latest/g1455/ProxyResolution-class.html)
- Source: [`lib/src/surface/glass_host.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_host.dart)

`GlassHost` records the content under every glass surface below it into one shared, downscaled image, and only
re-records it when something under the glass actually changed. Every surface then samples its own slice of that image.

It is also where a screen's glass is configured: the default finish, the tier, what is behind the glass, contrast,
thermal state and the ripple. The host installs a [GlassTheme](../foundations/legibility.md) with those values for
everything below it.

## When to use

- Always: any screen with glass needs exactly one host above it. A surface at the full tier with no host above draws no
  glass, only its child.
- Put it in `MaterialApp(builder: ...)`, above the navigator, so dialogs, sheets, menus and popovers find it too. They
  throw a debug error when they can't.
- Don't nest a host around each widget, and don't put it below the `Navigator` if you use any modal.

## Usage

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(
    backdrop: const Color(0xFF101014),
    richBackdrop: true,
    minLabelContrast: kTextContrastAA,
    child: child!,
  ),
  home: const HomePage(),
)
```

## Behaviour

- **One capture for the screen.** Ten surfaces are one capture and ten draws, not ten reads of the backdrop.
- **Captures only on change.** When nothing under the glass changed since the last frame, the host keeps the capture
  it has. A still screen and glass moving inside a [GlassTravel](../foundations/travel.md) region cost no capture. Content
  that repaints under glass, such as a list scrolling under a bar, costs one capture per changed frame.
- **The first frame has no glass.** The host captures after a frame is painted, and surfaces draw the capture on the
  next frame.
- **Shaders compile when the host mounts.** Until they land, glass draws the blurred backdrop with no tint, rim or bend.
  `await GlassHost.precache()` in `main()`, before `runApp`, compiles them first. See
  [Installation](../start/installation.md).
- **The resolution is chosen for you** against a quality budget (`budgetDeltaE`), from the finishes in use. Pin it
  with `resolution:` only for tests and benchmarks.

The demo above counts the host's captures. Leave everything still and the count stays flat; turn on the drifting
backdrop and it captures every frame.

## Theme

The host builds a `GlassTheme` from its parameters and puts it below itself. That has two consequences:

- A `GlassTheme` placed **above** the host is ignored. Configure the screen through the host's parameters.
- A `GlassTheme` placed **below** the host overrides a subtree: a different finish for one panel, or the cheap tier
  for a list of cards. See [Legibility & theme](../foundations/legibility.md) and [Tiers & fallbacks](../foundations/tiers.md).

When `finish` is null the host uses Apple's `.regular`, which is two materials: it picks `regularDark` or
`regularLight` from `backdrop` and the platform's appearance, and follows appearance changes. With `adaptive:` set it
picks per glass instead, from what each one reads under it: see [Adaptive glass](../foundations/adaptive.md).

The host also sets the screen's motion: `ripple:` for a touch wave ([Ripple](../foundations/ripple.md)), `dropMotion:`
for how the held drops of the controls stretch and squash ([Drop motion](../foundations/drop-motion.md)), and `press:` for
how a pressed [button](../components/button.md) swells and leans (`GlassPress.none` to keep buttons still).

## Gotchas

> [!WARNING]
> `maxCaptures`, `blurPass`, `resolution` and `content: GlassContentDeclaration.undeclared` are diagnostics. They are
> there to measure and to rule things out; don't ship them.

- No platform code ships. Reduce transparency, thermal state and macOS increase-contrast must be read by your app and
  passed in. See [What the app declares](../start/declarations.md).
- On a very large window, `maxTextureSide` (8192 on Apple, 4096 elsewhere) may limit the capture. Raise it, for
  example to 16384, if you know the GPU supports it.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const HostApp(reduceTransparency: false));

class HostApp extends StatelessWidget {
  const HostApp({super.key, required this.reduceTransparency});

  /// Read natively by the app: Flutter does not pass it on.
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Above the navigator, so dialogs, sheets and menus find the host too.
    builder: (BuildContext context, Widget? child) => GlassHost(
      // What is behind the glass: images and colour over a near-black page.
      backdrop: const Color(0xFF101014),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      // Reduce transparency gives the opaque tier, which fills with `backdrop`.
      tier: GlassTierPolicy(reduceTransparency: reduceTransparency).choose(),
      thermal: GlassThermalState.nominal,
      child: child!,
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101014),
    body: Stack(
      children: <Widget>[
        // Still content: the host captures it once and keeps the capture.
        const Positioned.fill(child: FlutterLogo(style: FlutterLogoStyle.stacked)),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: GlassBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(onPressed: () {}, icon: const Icon(Icons.home)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The screen. Everything the glass shows must be inside it. |
| `finish` | `GlassFinish?` | `null` | The default material for every surface below. Null is Apple's `.regular`: `regularDark` or `regularLight`, picked from `backdrop` and the platform's appearance. |
| `tier` | `GlassTierChoice` | `GlassTierChoice.byDefault` | Full glass, a cheap translucent fill, or an opaque fill. Usually from `GlassTierPolicy.choose()`. |
| `backdrop` | `Color?` | `null` | The screen's average background colour. Used for the label colour, and needed for the opaque tier to look right. |
| `richBackdrop` | `bool` | `false` | The content behind the glass is an image, video, map or feed, so labels are chosen for the worst case. |
| `minLabelContrast` | `double?` | `null` | Minimum label contrast, e.g. `kTextContrastAA` (4.5). The glass is dimmed just enough to meet it. |
| `highContrast` | `bool?` | `null` | Draws an opaque outline instead of the subtle rim. Null reads `MediaQuery.highContrastOf`; on macOS pass it yourself. |
| `ripple` | `GlassRipple?` | `null` | A touch wave for every surface below. None by default. |
| `dropMotion` | `GlassDropMotion` | `GlassDropMotion()` | How the held drop of the switch, slider, segmented control and tab bar stretches and squashes. `GlassDropMotion.none` keeps it round. |
| `press` | `GlassPress` | `GlassPress()` | How a pressed `GlassButton` swells and leans: two captures a press, none at rest. `GlassPress.none` keeps every button its size. |
| `adaptive` | `GlassAdaptive?` | `null` | Each bar, card and button reads the backdrop under it and picks its branch and label. Null reads nothing. |
| `thermal` | `GlassThermalState?` | `null` | The device's thermal state, read by your app. Null is nominal. |
| `thermalPolicy` | `GlassThermalPolicy` | `GlassThermalPolicy()` | How much staleness each thermal state may spend. `GlassThermalPolicy.never` keeps every frame fresh. |
| `hardware` | `GlassHardware?` | `null` | Which device family's measurements apply. Null detects: `appleMetal` on Apple, otherwise `unmeasured`. |
| `budgetDeltaE` | `double` | `ProxyResolutionPolicy.defaultDamageBudgetDeltaE` | The quality budget the host trades for speed when it picks the capture's resolution. |
| `maxTextureSide` | `int?` | `null` | Largest GPU texture side in device pixels. Null is the hardware's floor: 8192 on Apple, 4096 elsewhere. |
| `content` | `GlassContentDeclaration` | `GlassContentDeclaration.byDefault` | `undeclared` forces a capture every frame. Diagnostic. |
| `resolution` | `ProxyResolution?` | `null` | Pins the capture's downscale (`full()`, `half()`, `quarter()`, `divisor(n)`). For tests and benchmarks. |
| `blurPass` | `ProxyBlurPass?` | `null` | How the residual blur is applied. Diagnostic. |
| `maxCaptures` | `int?` | `null` | Stops capturing after N captures. Diagnostic; never ship it. |

### GlassHost.precache

`static Future<void> precache({bool group = true, bool ripple = true})`: compiles the package's shaders now, so the
first glass on screen is drawn through its optics. Call it in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
Idempotent, and it shares the loads a host starts, so nothing compiles twice. `group: false` and `ripple: false` leave
out those programs. Completes with a load's error if one fails.
