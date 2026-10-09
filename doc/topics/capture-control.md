The host captures what is under its glass by painting that part of the tree a
second time, into a picture of its own. Most of the time that is exactly right.
[GlassProxy](../g1455/GlassProxy-class.html) is for the subtrees where it is not: it tells the capture what a
subtree is, and changes nothing in the frame the user sees.

| Declaration | The capture… | For |
|---|---|---|
| [GlassProxy.replace](../g1455/GlassProxy/GlassProxy.replace.html) | paints a [GlassProxyPainter](../g1455/GlassProxyPainter-class.html)'s stand-in instead of the subtree | a video, a camera preview, a map or any platform view: they record nothing, and the glass would show a hole |
| [GlassProxy.hidden](../g1455/GlassProxy/GlassProxy.hidden.html) | leaves the subtree out, and does not run its `paint` | a subtree the glass should not show, or one whose `paint` has side effects |
| [GlassProxy.opaque](../g1455/GlassProxy/GlassProxy.opaque.html) | takes the subtree as covering its own box | a full-bleed image or panel: the capture stops looking under it |
| [GlassProxy.verbatim](../g1455/GlassProxy/GlassProxy.verbatim.html) | exempts the subtree from the shadow filter | a highlight blurred through a `MaskFilter` on purpose |

## A stand-in for a video

```dart
Stack(
  fit: StackFit.expand,
  children: <Widget>[
    GlassProxy.replace(
      painter: const GradientProxyPainter(
        LinearGradient(colors: <Color>[Color(0xFF1B1F2A), Color(0xFFFF9F0A)]),
      ),
      child: videoPlayer, // a platform view
    ),
    const Positioned(left: 16, right: 16, bottom: 16, child: GlassBar(child: Text('Live'))),
  ],
)
```

Two stand-ins come with the package, [SolidProxyPainter](../g1455/SolidProxyPainter-class.html) and
[GradientProxyPainter](../g1455/GradientProxyPainter-class.html); anything else is a [GlassProxyPainter](../g1455/GlassProxyPainter-class.html) of your own:

```dart
class PosterProxyPainter extends GlassProxyPainter {
  const PosterProxyPainter(this.poster);

  final ui.Image poster;

  @override
  void paint(Canvas canvas, Size size) =>
      paintImage(canvas: canvas, rect: Offset.zero & size, image: poster, fit: BoxFit.cover);

  @override
  bool shouldRepaint(PosterProxyPainter oldPainter) => oldPainter.poster != poster;
}
```

A stand-in changes **what** the glass sees, not **when** the host captures: a
video that composites a new frame is still a change. Live, with each
declaration: [Capture control](https://g1455.plugfox.dev/foundations/capture).

## When the backdrop is known

[GlassBackdrop](../g1455/GlassBackdrop-class.html) is the other side of the same question: it declares what is behind
the glass in a subtree — a colour, an image, a gradient — and that glass samples a texture made once from the
declaration instead of a capture. The host captures nothing for it.
