# Declared backdrop

> Declare a backdrop the app already knows (a colour, a gradient, a wallpaper) so the glass over it samples a texture made once and the host captures nothing for it.

- Live: https://g1455.plugfox.dev/foundations/backdrop
- API: [`GlassBackdrop`](https://pub.dev/documentation/g1455/latest/g1455/GlassBackdrop-class.html), [`GlassBackdropDeclaration`](https://pub.dev/documentation/g1455/latest/g1455/GlassBackdropDeclaration-class.html)
- Source: [`lib/src/surface/glass_backdrop.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_backdrop.dart)

The host captures what is under its glass because it cannot know what is there (see
[How it works](../start/how-it-works.md)). When the application does know, because the page is one colour, a wallpaper that
does not change or a gradient, that capture is a snapshot of something already in hand. `GlassBackdrop` declares it for
a subtree: the glass below samples a texture made from the declaration, through the same shader and the same optics as
captured glass, and the host leaves that glass out of its capture. A screen whose glass is all declared takes no
snapshot at all.

## When to use

- A page, a sheet or a lock screen whose background is fixed: one colour, a gradient, a wallpaper image.
- Glass that sits straight on that background, with nothing in between that the glass ought to refract.
- **Not** over content that moves or changes: a list, a feed, a video, a map. Glass over a declaration shows the
  declaration, not the screen.
- **Not** for a stand-in under a video or a platform view: that is [`GlassProxy.replace`](../foundations/capture.md), which
  changes what the capture sees, where this removes the capture.

## Five constructors

| Constructor | Declares | The texture is made |
|---|---|---|
| `GlassBackdrop.color(color)` | one colour, which should be opaque | once: a single texel, the same at every blur and size |
| `GlassBackdrop.painter(painter)` | a `GlassProxyPainter`: `GradientProxyPainter`, or anything you draw | once per finish blur and box size; again when `shouldRepaint` says so |
| `GlassBackdrop.image(provider)` | an `ImageProvider`, placed by `fit` and `alignment` as `DecorationImage` places one | the same, once the image has loaded |
| `GlassBackdrop.texture(image)` | a `ui.Image` the app already holds | the same; pass a new `ui.Image` to make it again |
| `GlassBackdrop.live()` | nothing: glass in its subtree captures again | never |

The innermost declaration wins, so a `GlassBackdrop.live` inside a declared page hands its own subtree back to the
capture: the cards on a wallpaper capture nothing while the bar over the page's list still refracts the list.

## What it costs

A declaration costs no capture. The texture is made when the glass first paints, once per finish blur and per size of
the `GlassBackdrop`'s box, and kept; a repaint, a scroll of the page around it or a move of the glass does not make
another. The blur is the pipeline's own arithmetic: the texture is rendered at a reduced resolution where the finish's
blur allows it, and only the rest of the blur is applied, once. A colour is cheapest of all: one texel, made once.

Two finishes over one painter, image or texture make two textures. Animating `materialize` over a painter, an image or a texture asks
for a new blur on every frame of the animation, so each frame makes a texture (a declaration keeps the four most
recent); over a colour it makes none.

## The declaration has to be true

Glass over a declared backdrop shows the declaration and nothing else:

- Content between the backdrop and the glass, such as text under a card or a list scrolling under a bar, is **not
  refracted**.
- A backdrop that changes without the declaration changing is shown as it was.

That is why `GlassBackdrop` paints what it declares under its child by default: the declaration is then true by
construction for any glass that sits straight on it. Set `paintBackdrop: false` only when something else already paints
the same pixels at the same place, such as a `Scaffold.backgroundColor` declared again with `GlassBackdrop.color`, so
they are not painted twice.

> [!NOTE]
> A declaration is what the glass samples, not what it reads for legibility. The label colour and the dim still go by
> `GlassHost.backdrop` and `richBackdrop`, or a `GlassTheme` below the host
> (see [Legibility](../foundations/legibility.md)).

## What it still needs

- **A `GlassHost` above**, as all glass does: the host carries the shader and the ledger.
- **An image that loads.** While a `GlassBackdrop.image` is loading, the glass below captures as if nothing were
  declared, so a wallpaper that has not decoded yet is never a hole. It switches to the declaration once the image has
  arrived.

## Checking that it works

Glass over a declared colour and glass over a captured screen of that colour draw the same pixels, so a screenshot
cannot tell you the declaration took. The counters can:

- `RenderGlassSurface.readsDeclaredBackdrop` is true while a surface samples a declaration, and
  `paintsWithDeclaredBackdrop` counts its paints that did. `RenderGlassGroup` has the same two.
- `GlassBackdrop.maybeOf(context)` returns the `GlassBackdropDeclaration` in force; its `renders` counts the textures
  it made. It should stay put while the screen repaints, and grow only with a new finish or a new size.
- The ledger counts declared glass as not captured: `GlassLoad.capturedSurfaceCount` leaves it out, and its
  `GlassSurfaceRecord` has `declared: true`.
- On a screen whose glass is all declared, the host captures nothing: the handle from `GlassProxyScope.maybeOf(context)`
  (in `package:g1455/glass_diagnostics.dart`, for tests only) keeps `snapshots` at 0 and `frame` null.

The demo above shows the same counters live: switch the declaration off and on, and turn on the motion under the glass.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A home screen over a gradient that never changes, with a feed below it.
/// Assumes a GlassHost above, in MaterialApp.builder.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.feed});

  /// A list that scrolls: the bar over it has to refract it.
  final Widget feed;

  static const GradientProxyPainter _sky = GradientProxyPainter(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFFF375F)],
    ),
  );

  @override
  Widget build(BuildContext context) => GlassBackdrop.painter(
    // Painted under the child, and sampled by every glass below: the two
    // cards capture nothing at all.
    _sky,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GlassCard(child: Text('Good morning')),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Expanded(child: GlassCard(child: Text('21°'))),
                SizedBox(width: 12),
                Expanded(child: GlassCard(child: Text('8.2k steps'))),
              ],
            ),
          ),
          Expanded(
            // The list moves, so the bar over it captures as usual.
            child: GlassBackdrop.live(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: feed),
                  const Positioned(left: 16, right: 16, top: 8, child: GlassBar(child: Text('Feed'))),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

## API

`GlassBackdrop`:

| Constructor | Parameters |
|---|---|
| `GlassBackdrop.color` | `color` (`Color`, **required**, positional), `paintBackdrop`, `child` (**required**) |
| `GlassBackdrop.painter` | `painter` (`GlassProxyPainter`, **required**, positional), `paintBackdrop`, `child` (**required**) |
| `GlassBackdrop.image` | `image` (`ImageProvider`, **required**, positional), `fit`, `alignment`, `paintBackdrop`, `child` (**required**) |
| `GlassBackdrop.texture` | `texture` (`ui.Image`, **required**, positional), `fit`, `alignment`, `paintBackdrop`, `child` (**required**) |
| `GlassBackdrop.live` | `child` (**required**) |

| Parameter | Type | Default | Description |
|---|---|---|---|
| `fit` | `BoxFit` | `BoxFit.cover` | How an image or texture is fitted into the widget's box. |
| `alignment` | `AlignmentGeometry` | `Alignment.center` | Where an image or texture sits inside the widget's box. |
| `paintBackdrop` | `bool` | `true` | Whether the widget paints what it declares under `child`. `false` only when something else paints the same pixels. |
| `child` | `Widget` | **required** | The subtree the declaration applies to. |

The caller of `GlassBackdrop.texture` keeps ownership of the image and must not dispose it while the widget shows it.
Drawing into the same `ui.Image` is not a change anything can see; pass a new one.

| Static | Type | Description |
|---|---|---|
| `GlassBackdrop.maybeOf(context)` | `GlassBackdropDeclaration?` | The declaration in force at `context`, or `null` where glass captures (none above, or under `GlassBackdrop.live`). |

`GlassBackdropDeclaration` (made by `GlassBackdrop`; you never construct one):

| Member | Type | Description |
|---|---|---|
| `renders` | `int` | How many textures it has made. Grows per finish blur and size, never per frame. |
| `ready` | `bool` | Whether glass can sample it now: `false` while an image loads and before the widget is laid out. |
| `globalRect` | `Rect?` | Where the declared backdrop is on the screen, in logical pixels, or `null` before layout. |

On the glass (`RenderGlassSurface`, and `RenderGlassGroup` for a fused group):

| Member | Type | Description |
|---|---|---|
| `readsDeclaredBackdrop` | `bool` | Whether this glass samples a declaration now. |
| `paintsWithDeclaredBackdrop` | `int` | Paints that sampled a declaration rather than the host's capture. |
