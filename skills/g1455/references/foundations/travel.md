# Travel

> Declare the region moving glass travels in, so a dragged lens or a sliding knob is redrawn from the capture the host already holds instead of triggering a new one.

- Live: https://g1455.plugfox.dev/foundations/travel
- API: [`GlassTravel`](https://pub.dev/documentation/g1455/latest/g1455/GlassTravel-class.html), [`GlassTravelScope`](https://pub.dev/documentation/g1455/latest/g1455/GlassTravelScope-class.html), [`GlassTravelRegion`](https://pub.dev/documentation/g1455/latest/g1455/GlassTravelRegion-class.html)
- Source: [`lib/src/surface/glass_travel.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_travel.dart)

`GlassTravel` is a performance hint: "glass inside this box may move anywhere within it." The host then captures the **whole box** once, and glass that moves inside it is redrawn from that capture instead of triggering a new one on every frame.

Without it, glass that moves over still content still costs a capture per frame, because each surface's slot in the capture is its own box plus a margin, and any move leaves it. The package can't see where a surface is *going*. `GlassTravel` is how you tell it.

The built-in [switch](../components/switch.md), [slider](../components/slider.md), [segmented control](../components/segmented-control.md) and [tab bar](../components/tab-bar.md) already use it for their drops.

## When to use

- A custom control or effect whose glass moves while the content under it stays still: a draggable lens, a custom knob, orbiting blobs.
- **Not** for glass that sits still. The capture becomes bigger for no benefit.
- **Not** as a cure for glass over content that is itself changing (a scrolling list, a video). When the content under the glass changes, the host re-captures regardless.

## Usage

```dart
SizedBox(
  width: 300,
  height: 60,
  child: GlassTravel(
    child: Stack(
      children: <Widget>[
        Positioned(left: x, top: 0, width: 60, height: 60, child: const GlassSurface(borderRadius: kGlassCapsule)),
      ],
    ),
  ),
);
```

`GlassTravel` is transparent to layout, paint and hit-testing. It only marks a region.

## Making motion free

The motion is free only if **moving the glass repaints nothing else**. A repaint anywhere under the glass looks like changed content and triggers a capture. So:

1. Put the content the glass moves over behind its own `RepaintBoundary`.
2. Put the moving glass behind another `RepaintBoundary`, inside the `GlassTravel`, with a parent that paints nothing of its own.

The example in the Code tab follows that layout. Turn the switch in the demo off and the lens looks exactly the same, but every frame of the drag now re-captures.

> [!NOTE]
> The declaration is a price, never a correctness claim. Glass that leaves the region is simply captured the normal way: correct, just not free.

## Plumbing

`GlassTravelScope` is the inherited widget that carries the region down to the surfaces, and `GlassTravelRegion` is the region itself. `GlassTravelScope.maybeOf(context)?.globalRect` gives its current rectangle in global logical pixels. You don't need either to use `GlassTravel`.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A magnifier you drag over a photo. Inside GlassTravel the drag costs no
/// capture: the lens is redrawn from the capture the host already holds.
/// Assumes a GlassHost above.
class Magnifier extends StatefulWidget {
  const Magnifier({super.key, required this.photo});

  final ImageProvider photo;

  @override
  State<Magnifier> createState() => _MagnifierState();
}

class _MagnifierState extends State<Magnifier> {
  static const double _lens = 96;
  Offset _at = const Offset(120, 120);

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      // The content, behind its own boundary: the drag repaints none of it.
      Positioned.fill(
        child: RepaintBoundary(
          child: Image(image: widget.photo, fit: BoxFit.cover),
        ),
      ),
      // The region the lens may move in: the whole photo.
      Positioned.fill(
        child: GlassTravel(
          // The moving glass, behind a boundary of its own.
          child: RepaintBoundary(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: _at.dx - _lens / 2,
                  top: _at.dy - _lens / 2,
                  width: _lens,
                  height: _lens,
                  child: GestureDetector(
                    onPanUpdate: (DragUpdateDetails d) => setState(() => _at += d.delta),
                    child: GlassSurface(
                      borderRadius: kGlassCapsule,
                      labelled: false,
                      finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.5)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
```

## API

`GlassTravel`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The region. Glass that moves goes inside it. |

`GlassTravelScope` (plumbing):

| Parameter | Type | Default | Description |
|---|---|---|---|
| `region` | `GlassTravelRegion` | **required** | The region the surfaces below may move within. |
| `child` | `Widget` | **required** | The subtree. |

`static GlassTravelRegion? maybeOf(BuildContext context)` finds the nearest region. `GlassTravelRegion.globalRect` (`Rect?`) is where it is now, or `null` when it can't say.
