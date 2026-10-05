# Scroll edge

> iOS 26's scroll edge effect: content softly blurs and fades as it scrolls under a bar, or meets an opaque band. It also holds and lifts the bar.

- Live: https://g1455.plugfox.dev/foundations/scroll-edge
- API: [`GlassScrollEdge`](https://pub.dev/documentation/g1455/latest/g1455/GlassScrollEdge-class.html), [`GlassScrollEdgeStyle`](https://pub.dev/documentation/g1455/latest/g1455/GlassScrollEdgeStyle.html), [`GlassScrollEdgeSide`](https://pub.dev/documentation/g1455/latest/g1455/GlassScrollEdgeSide.html), [`GlassScrollEdgeAppearance`](https://pub.dev/documentation/g1455/latest/g1455/GlassScrollEdgeAppearance.html), [`kGlassScrollEdgeSigma`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeSigma-constant.html), [`kGlassScrollEdgeHardSigma`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeHardSigma-constant.html), [`kGlassScrollEdgeLightTint`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeLightTint-constant.html), [`kGlassScrollEdgeDarkTint`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeDarkTint-constant.html), [`kGlassScrollEdgeHardFill`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeHardFill-constant.html)
- Source: [`lib/src/surface/glass_scroll_edge.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_scroll_edge.dart)

`GlassScrollEdge` draws what iOS 26 draws where a list scrolls under a bar. In the **soft** style (iOS's default), content blurs slightly and fades into a tint as it goes under the bar. In the **hard** style (macOS's default), it meets an opaque white band with a sharp edge. The values were read off Apple's own effect on iOS 26 simulators.

It also **holds your bar**: pass the bar as `child` and it is laid out inside `extent` and lifted together with the effect, so it shows glass scrolling under it (see [Glass on glass](../foundations/above.md)). Touches outside the bar pass through to the list.

## When to use

- A list that scrolls under a top app bar, or under a bottom toolbar or [tab bar](../components/tab-bar.md).
- **Not** without a scrolling list beneath. Over a still page, a plain [`GlassAbove`](../foundations/above.md) around the bar is enough.

> [!TIP]
> For a whole screen, a top bar over a list with an optional tab bar, [`GlassScaffold`](../components/scaffold.md) puts the bar in a soft scroll edge, works out `extent`, and tells the list its padding. Reach for `GlassScrollEdge` itself for anything else.

## Usage

Place it full-width against its edge, over the list:

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: list),
    Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GlassScrollEdge(
        side: GlassScrollEdgeSide.top,
        extent: MediaQuery.paddingOf(context).top + 60,
        child: appBar,
      ),
    ),
  ],
);
```

`extent` is the distance from the screen edge to the bar's inner edge: the status bar plus the bar at the top, the bar plus the home indicator at the bottom. Pad the list by the same amount so its first and last rows can be seen.

## Styles and sides

| | Top | Bottom |
|---|---|---|
| `soft` | A light blur (σ [`kGlassScrollEdgeSigma`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeSigma-constant.html) = 1.6) plus a tint that fades in toward the edge. This is a glass surface. | A tint only, no blur, as Apple draws it. A gradient, nothing captured. |
| `hard` | A near-opaque white band (`kGlassScrollEdgeHardFill`, 90%) with a sharp edge. | The same band at the bottom. |

The effect reaches **past** `extent` into the content, by about 40 px at the soft top. That is the fade.

## Appearance

A soft edge tints toward white over light content and toward black over dark content (`kGlassScrollEdgeLightTint`, `kGlassScrollEdgeDarkTint`). Apple picks the direction from the content itself. The package can't read the content, so with `appearance: null` it reads the host's declared `backdrop`: dark below a relative luminance of 0.4, light otherwise, **and light when no backdrop is declared**. Over a dark app, declare `backdrop` on the [host](../foundations/host.md) or pass `appearance: GlassScrollEdgeAppearance.dark`.

## Performance

- The soft top is one glass surface the width of the screen. Under a scrolling list, what's under it changes every frame, so **it re-captures on every scrolling frame** and costs nothing once the list stops.
- The soft bottom is a gradient and costs no capture.
- Being lifted costs one extra capture level, but only when there is glass under it.

> [!WARNING]
> Put the bar **in** `child`. An unlifted bar placed beside a lifted edge appears blurred inside the edge's capture.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A list under a top app bar and a bottom toolbar, each in a scroll edge.
/// Assumes a GlassHost above.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double top = safe.top + 64; // status bar + bar
    final double bottom = safe.bottom + 72; // toolbar + home indicator
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView.builder(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            itemCount: titles.length,
            itemBuilder: (BuildContext context, int i) => ListTile(title: Text(titles[i])),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.top,
            extent: top,
            // The bar goes in `child`, so it is lifted with the edge.
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, safe.top + 8, 16, 4),
              child: const GlassBar(child: Center(child: Text('Library'))),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.bottom,
            extent: bottom,
            style: GlassScrollEdgeStyle.hard, // macOS-style opaque band
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, safe.bottom + 8),
              child: Align(
                alignment: Alignment.topRight,
                child: GlassButtonGroup(
                  items: <GlassToolbarItem>[
                    GlassToolbarItem(icon: const Icon(Icons.add), label: 'Add', onPressed: () {}),
                    GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

## API

`GlassScrollEdge`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `side` | `GlassScrollEdgeSide` | **required** | `top` or `bottom`. |
| `extent` | `double` | **required** | From the screen edge to the bar's inner edge, in logical px. Must be ≥ 0. |
| `style` | `GlassScrollEdgeStyle` | `GlassScrollEdgeStyle.soft` | `soft` (blur and tint, iOS) or `hard` (opaque band, macOS). |
| `appearance` | `GlassScrollEdgeAppearance?` | `null` (dark if the theme's `backdrop` luminance is < 0.4, otherwise light) | Which way a soft edge tints: `light` (white) or `dark` (black). |
| `blurSigma` | `double` | `kGlassScrollEdgeSigma` (1.6) | The soft edge's blur. |
| `child` | `Widget?` | `null` | The bar, laid out within `extent` and lifted with the effect. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassScrollEdgeSigma` | `1.6` | The soft edge's blur, in logical px. |
| `kGlassScrollEdgeHardSigma` | `2.15` | The hard band's blur. |
| `kGlassScrollEdgeLightTint` | `Color.fromRGBO(255, 255, 255, 0.85)` | The soft tint at the edge, light appearance. |
| `kGlassScrollEdgeDarkTint` | `Color.fromRGBO(0, 0, 0, 0.25)` | The soft tint at the edge, dark appearance. |
| `kGlassScrollEdgeHardFill` | `Color.fromRGBO(255, 255, 255, 0.90)` | The hard band. |
