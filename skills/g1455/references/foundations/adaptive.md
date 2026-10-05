# Adaptive glass

> Glass that reads its own backdrop: a bar over a bright sky turns light, a button over a shadow stays dark, each with a label to match. Off by default and free when off.

- Live: https://g1455.plugfox.dev/foundations/adaptive
- API: [`GlassAdaptive`](https://pub.dev/documentation/g1455/latest/g1455/GlassAdaptive-class.html), [`GlassBackdropReading`](https://pub.dev/documentation/g1455/latest/g1455/GlassBackdropReading-class.html), [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassThemeData`](https://pub.dev/documentation/g1455/latest/g1455/GlassThemeData-class.html)
- Source: [`lib/src/surface/glass_adaptive.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_adaptive.dart)

Apple's `.regular` is two materials, dark over dark content and light over light. Without help the package picks one
branch for the whole screen, from what you declared: the host's `backdrop` and the platform's appearance. A screen is
not one level, though. A bar over a photograph's sky and a button over its shadow sit on different branches of Apple's
own material.

`GlassHost(adaptive: GlassAdaptive())` lets each glass look. The host already holds the pixels under every surface, so
it reads back the mean level inside each one's box, and a [GlassBar](../components/bar.md), a [GlassCard](../components/card.md)
or a [GlassButton](../components/button.md) picks the branch of `.regular` and its label colour from it.

## When to use

- Glass over photographs, maps or video, where one declared level is wrong for half the screen.
- Bars and buttons that stay put while the content under them changes from light to dark, such as a full-bleed hero
  image scrolling under a bar.
- **Not** over a flat page: declare its colour as the host's `backdrop` instead, which is exact and reads nothing.

## Usage

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(
    adaptive: const GlassAdaptive(),
    child: child!,
  ),
  home: const PhotoPage(),
)
```

That's all. The components under the host follow what is under them.

## What a reading changes

- **The branch of `.regular`.** Only when nobody named a finish. A finish named by the component, by an inner
  `GlassTheme` or by the host (`GlassHost(finish: GlassFinish.regularDark)`) is kept. Only its label follows the
  reading.
- **The label.** The reading stands in for the declared `backdrop` for that one glass: the label colour, the
  high-contrast outline and the `minLabelContrast` dim are all chosen against it.
- **Not under `richBackdrop: true`.** A mean says nothing about the brightest corner of a photograph, so there the label
  stays chosen against every backdrop, and the reading moves only the branch.

Until a glass has its first reading (its first couple of frames, or a [tier](../foundations/tiers.md) that captures nothing),
it wears what the declarations give, exactly as with adaptive off.

## Behaviour

- **No flicker.** A reading moves a glass only when it is more than `band` (12) code values from the one it last
  moved on, and not within `hold` (600 ms) of its last move. A list of light and dark rows scrolling under a bar keeps
  the bar on the branch it has.
- **Moves animate.** A glass crossing between branches tweens its tint over `duration` (300 ms), and on every frame
  of it the label is the one that reads on the glass as drawn, so the floor holds halfway too. Under reduced motion it
  is a cut.
- **What adapts.** `GlassBar`, `GlassCard` and `GlassButton`. A raw `GlassSurface`, the
  [scroll edge](../foundations/scroll-edge.md), the [tab bar](../components/tab-bar.md) and the
  [segmented control](../components/segmented-control.md) do not adapt yet.

The demo above turns adaptive on in the site's own host while the page is open, so the site's top bar and side panel
follow it too. The site declares a rich backdrop, so the stage nests a `GlassTheme` with `richBackdrop: false` to let
the labels follow as well. It needs the full tier (the High or Ultra setting), the Regular material and the Neutral
tint: a lower tier captures nothing to read, and a named material is kept — and a tint names one, the material with
that colour.

## Content on the glass

Inside a component that reads its backdrop, `GlassTheme.of(context).reading` is what it read, so an icon that is not a
label, or a custom painter, can follow it:

```dart
final GlassBackdropReading? reading = GlassTheme.of(context).reading;
final bool overLight = reading?.brightness == Brightness.light;
```

It is null with adaptive off and before the first reading. `level` is the mean's luma in code values (0 to 255),
`luminance` its WCAG relative luminance, and `brightness` whether black or white stands out more against it. The
branch the glass is on is `GlassTheme.of(context).finish`.

A custom component does what the built-in ones do with `GlassThemeData.adaptedTo(reading)`. To turn adaptive off for a
subtree, nest `GlassTheme(data: GlassTheme.of(context).withAdaptive(null), ...)`.

## Cost

- **Off: nothing.** No reader exists, nothing is recorded, read back or scheduled.
- **On, a still screen: nothing** after the first reading. A frame that keeps its capture has nothing new under the
  glass and reads nothing.
- **On, a frame that captures:** at most one read-back of a 4 × 4-pixel cell per surface, asynchronously, and at most
  once per `interval`. The frame that asked doesn't wait for it.
- **On the web it is dearer.** CanvasKit reads back synchronously, a GPU flush on the frame it lands in, so `interval`
  is a second there rather than 250 ms. Raise it further for a screen that scrolls a lot.

> [!TIP]
> The finish table of [Finishes](../foundations/finishes.md) and the label rules of
> [Legibility & theme](../foundations/legibility.md) still apply: adaptive only gives each glass its own `backdrop`.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const PhotoApp());

class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // One host, reading the backdrop under each glass. No finish named, so
    // each bar and button may take the branch of `.regular` it reads.
    builder: (BuildContext context, Widget? child) => GlassHost(adaptive: const GlassAdaptive(), child: child!),
    home: const PhotoPage(),
  );
}

class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Bright at the top, dark at the bottom: a sky and its shadow.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFEAF2FA), Color(0xFFB9D3EA), Color(0xFF1B2A1F), Color(0xFF0A110C)],
                  stops: <double>[0, 0.5, 0.52, 1],
                ),
              ),
            ),
          ),
          // Over the sky: turns light, with a dark label.
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(child: Text('Lake Tekapo')),
          ),
          // Over the shadow: stays dark, with a white label.
          Positioned(
            bottom: safe.bottom + 16,
            left: 16,
            child: GlassButton(onPressed: () {}, child: const Text('Directions')),
          ),
          // Content that follows the reading itself.
          Positioned(
            bottom: safe.bottom + 16,
            right: 16,
            child: GlassButton(
              onPressed: () {},
              semanticLabel: 'Weather',
              child: Builder(
                builder: (BuildContext context) {
                  final GlassBackdropReading? reading = GlassTheme.of(context).reading;
                  return Icon(reading?.brightness == Brightness.light ? Icons.wb_sunny : Icons.nightlight_round);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## API

`GlassHost`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `adaptive` | `GlassAdaptive?` | `null` | Turns reading on, and says how. Null: glass goes by what is declared, and nothing is read. |

`GlassAdaptive`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `band` | `double` | `GlassAdaptive.kDefaultBand` (12) | How far, in code values of luma, a reading must be from the last one to move the glass. Must be ≥ 0. |
| `hold` | `Duration` | `GlassAdaptive.kDefaultHold` (600 ms) | The least time between two moves of one glass. |
| `interval` | `Duration` | `GlassAdaptive.kDefaultInterval` (250 ms; 1 s on the web) | The least time between two read-backs. |
| `duration` | `Duration` | `GlassAdaptive.kDefaultDuration` (300 ms) | How long a glass takes to cross between branches. None under reduced motion. |

### GlassBackdropReading

| Member | Type | Description |
|---|---|---|
| `mean` | `Color` | The mean colour of the captured backdrop under the glass, opaque. |
| `level` | `double` | The mean's luma in code values, 0 to 255: the scale `.regular` switches on. |
| `luminance` | `double` | The mean's WCAG relative luminance. |
| `brightness` | `Brightness` | Light when black stands out more against the mean, dark when white does. Not the branch of the glass. |

### GlassThemeData

| Member | Description |
|---|---|
| `adaptive` | The host's `GlassAdaptive`, or null. Installed by `GlassHost.adaptive`. |
| `reading` | What the glass this theme was installed for read, or null. Read it as `GlassTheme.of(context).reading`. |
| `adaptedTo(GlassBackdropReading reading)` | This theme as it applies over one glass that read `reading`: what a custom component installs around its content. |
| `withAdaptive(GlassAdaptive? adaptive)` | This theme with `adaptive` replaced, null included: turns reading off for a subtree. |
