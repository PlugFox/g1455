# Bar

> GlassBar is a floating glass capsule for navigation: a title bar, a bottom bar or a now-playing pill, with black or white labels picked for legibility.

- Live: https://g1455.plugfox.dev/components/bar
- API: [`GlassBar`](https://pub.dev/documentation/g1455/latest/g1455/GlassBar-class.html), [`kGlassCapsule`](https://pub.dev/documentation/g1455/latest/g1455/kGlassCapsule-constant.html)
- Source: [`lib/src/surface/glass_components.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_components.dart)

`GlassBar` is one glass surface with padding around its child. It is the navigation layer of an
iOS 26 style screen: the top bar with a back button and a title, a floating bottom bar, a
"now playing" pill over a feed.

The bar picks the text and icon colour of everything inside it, black or white, whichever reads
best on the glass over what is behind it. Its items are ordinary widgets, not glass, so a bar
full of icons and text still costs one surface.

## When to use

- Navigation chrome that floats over content: titles, back and search actions, a mini player.
- A small pill that names the current screen or state.
- **Not** for content panels: use a [Card](../components/card.md) instead (same body, a corner instead
  of a capsule).
- **Not** as a row of glass buttons. Every [`GlassButton`](../components/button.md) inside a bar is one more
  surface. Use plain icons, or a [toolbar](../components/toolbar.md) (`GlassButtonGroup`), which draws
  many actions as one surface.

## Usage

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: content), // what the glass refracts
    const Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GlassBar(child: Center(child: Text('Library'))),
    ),
  ],
)
```

The bar sizes itself to its child. To stretch it across the screen, give it a width with
`Positioned(left:, right:)`, a `SizedBox` or an `Expanded`.

## Layout

- `borderRadius` defaults to [`kGlassCapsule`](https://pub.dev/documentation/g1455/latest/g1455/kGlassCapsule-constant.html),
  a full pill whatever the height. Pass a `BorderRadius` for a rounded rectangle.
- `padding` defaults to 16 across and 8 down. Icon buttons usually want less, so their 44 px tap
  targets reach the edge of the glass.
- No `SafeArea` is applied for you. Add `MediaQuery.paddingOf(context)` to your offsets.

## Labels

Text and icons inside the bar get the label colour through `DefaultTextStyle` and `IconTheme`.
Widgets that hard-code their own colour (for example Material's `IconButton`, which uses the colour
scheme) ignore it, so pass `IconTheme.of(context).color` to them, or use plain `Icon`s in a
`GestureDetector`. The choice of colour is only as good as what the host knows about the backdrop:
see [Legibility](../foundations/legibility.md).

> [!WARNING]
> A bar is not refracted by glass that is its sibling. If glass cards scroll under a bar, wrap the bar
> in [`GlassAbove`](../foundations/above.md), or use a [scroll edge](../foundations/scroll-edge.md) instead.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A library screen: a top bar and a "now playing" bar over a list.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 72, 16, safe.bottom + 96),
            itemCount: 30,
            itemBuilder: (BuildContext context, int i) =>
                ListTile(leading: const Icon(Icons.album), title: Text('Album ${i + 1}')),
          ),
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.arrow_back_ios_new),
                  Expanded(child: Text('Library', textAlign: TextAlign.center)),
                  Icon(Icons.search),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safe.bottom + 16,
            child: const GlassBar(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.music_note),
                  SizedBox(width: 12),
                  Expanded(child: Text('Heat Waves', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Icon(Icons.pause),
                  SizedBox(width: 16),
                  Icon(Icons.fast_forward),
                ],
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

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The bar's items. They are content, not glass, and get the bar's label colour. |
| `borderRadius` | `BorderRadius` | `kGlassCapsule` | Corner radii. The default is a pill at any height. |
| `padding` | `EdgeInsets` | `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` | Space between the glass edge and the items. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's (normally the host's). |
| `key` | `Key?` | `null` | |
