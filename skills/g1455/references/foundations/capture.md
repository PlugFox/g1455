# Capture control

> Tell the capture what a subtree is: paint a stand-in for a video or a platform view, leave a subtree out, mark an opaque cover, or keep a blur the shadow filter would drop.

- Live: https://g1455.plugfox.dev/foundations/capture
- API: [`GlassProxy`](https://pub.dev/documentation/g1455/latest/g1455/GlassProxy-class.html), [`GlassProxyRole`](https://pub.dev/documentation/g1455/latest/g1455/GlassProxyRole.html), [`GlassProxyPainter`](https://pub.dev/documentation/g1455/latest/g1455/GlassProxyPainter-class.html), [`GradientProxyPainter`](https://pub.dev/documentation/g1455/latest/g1455/GradientProxyPainter-class.html), [`SolidProxyPainter`](https://pub.dev/documentation/g1455/latest/g1455/SolidProxyPainter-class.html), [`RenderGlassProxy`](https://pub.dev/documentation/g1455/latest/g1455/RenderGlassProxy-class.html)
- Source: [`lib/src/proxy/proxy_role.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/proxy/proxy_role.dart)

The host captures what is under its glass by painting that part of the tree a second time, into a picture of its own
(see [How it works](../start/how-it-works.md)). Most of the time that is exactly right, and there is nothing to declare.
`GlassProxy` is for the subtrees where it is not: it tells the capture what a subtree is, and changes nothing in the
frame the user sees.

## Four declarations

| Constructor | The capture… | For |
|---|---|---|
| `GlassProxy.replace(painter:)` | paints the painter's stand-in instead of the subtree | a video, a camera preview, a map or any platform view: they record nothing, and the glass would show a hole |
| `GlassProxy.hidden()` | leaves the subtree out, and does not run its `paint` | a subtree the glass should not show, or one whose `paint` has side effects (counters, analytics, lazy loading) that should not run twice a frame |
| `GlassProxy.opaque()` | takes the subtree as covering its own box | a full-bleed image or panel: the capture stops looking under it |
| `GlassProxy.verbatim()` | exempts the subtree from the shadow filter | a highlight drawn through a `MaskFilter` on purpose, which the filter would drop as a shadow |

The outermost declaration wins: a `replace` inside a `hidden` is never reached.

## A stand-in

A stand-in is a `GlassProxyPainter`, shaped like a `CustomPainter`. Two come with the package:

- `SolidProxyPainter(color)`: one flat colour, the cheapest stand-in there is.
- `GradientProxyPainter(gradient)`: a gradient, which keeps the colour across the box where one colour would not.

Write your own for anything else: the last frame of the video as an image, the map's tiles at a lower zoom, the
camera's average colour. The canvas is clipped to the subtree's box before `paint` runs, so a stand-in cannot spill
onto glass elsewhere on the screen.

```dart
class PosterProxyPainter extends GlassProxyPainter {
  const PosterProxyPainter(this.poster);

  final ui.Image poster;

  @override
  void paint(Canvas canvas, Size size) => paintImage(
    canvas: canvas,
    rect: Offset.zero & size,
    image: poster,
    fit: BoxFit.cover,
  );

  @override
  bool shouldRepaint(PosterProxyPainter old) => old.poster != poster;
}
```

`shouldRepaint` tells the host the stand-in itself changed, and the next frame captures it. `isOpaque` (false by
default) says the stand-in covers its whole box, which makes it a cover as `opaque` does. A rounded stand-in is not
opaque: its corners are where the page shows through.

> [!NOTE]
> A stand-in changes what the glass sees, not when the host captures. The host still watches the composited layers
> under its glass, and a video that composites a new frame is a change it captures for. What `replace` buys is a
> picture where there would have been a hole.

## What it does not do

`GlassProxy` does not simplify content to save time: the capture already runs at a fraction of the screen's
resolution, and that is a cheaper and better-looking saving than swapping text for blocks of colour. Declare what the
capture cannot know, not what it can.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A video player under a glass control bar. The player is a platform view,
/// which a capture cannot read: without a stand-in, the bar would refract a
/// hole. With one, it refracts the poster's colours.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.player});

  /// The video: a platform view, a `Texture`, anything that paints outside
  /// Flutter's own pictures.
  final Widget player;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      GlassProxy.replace(
        painter: const GradientProxyPainter(
          LinearGradient(colors: <Color>[Color(0xFF1B1F2A), Color(0xFF3A2E5C), Color(0xFFFF9F0A)]),
        ),
        child: player,
      ),
      // An overlay that counts its own paints: the capture should not run it a
      // second time every frame.
      const Positioned(top: 16, right: 16, child: GlassProxy.hidden(child: _ViewerCount())),
      Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: GlassBar(
          child: Row(
            children: <Widget>[
              IconButton(onPressed: () {}, icon: const Icon(Icons.pause)),
              const Expanded(child: Text('Live')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.fullscreen)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ViewerCount extends StatelessWidget {
  const _ViewerCount();

  @override
  Widget build(BuildContext context) => const Text('1,204 watching');
}
```

## API

`GlassProxy`:

| Constructor | Parameters | Role |
|---|---|---|
| `GlassProxy.replace` | `painter` (`GlassProxyPainter`, **required**), `child` (**required**) | `GlassProxyRole.replace` |
| `GlassProxy.hidden` | `child` (**required**) | `GlassProxyRole.hidden` |
| `GlassProxy.opaque` | `child` (**required**) | `GlassProxyRole.opaque` |
| `GlassProxy.verbatim` | `child` (**required**) | `GlassProxyRole.verbatim` |

`GlassProxyPainter` (abstract):

| Member | Type | Description |
|---|---|---|
| `paint(Canvas canvas, Size size)` | `void` | Paints the stand-in, in the subtree's local space, clipped to `size`. |
| `shouldRepaint(covariant GlassProxyPainter old)` | `bool` | Whether the stand-in changed and has to be captured again. |
| `isOpaque` | `bool` | Whether `paint` covers the whole box. `false` by default. |

`SolidProxyPainter(Color color)` and `GradientProxyPainter(Gradient gradient)` are the two the package ships.

The real frame never changes: every declaration is a `RenderGlassProxy`, a proxy box that paints its child as usual.
