Glass with other glass, and glass that moves.

| API | What it is |
|---|---|
| [GlassGroup](../g1455/GlassGroup-class.html), [GlassUnion](../g1455/GlassUnion-class.html) | Several surfaces drawn as one silhouette, fusing where they meet. |
| [GlassTravel](../g1455/GlassTravel-class.html) | The region a moving glass travels in: its motion costs no capture. |
| [GlassMorph](../g1455/GlassMorph-class.html) | Swap the child and the glass flows to its size, as a button becomes its menu. |
| [GlassAbove](../g1455/GlassAbove-class.html) | Raises the glass below it a level: a bar over glass cards refracts the cards. |

## Fused glass

```dart
GlassGroup(
  spacing: 24, // how near two surfaces have to be to fuse
  child: Stack(
    children: <Widget>[
      Positioned(left: 20, top: 40, width: 120, height: 120, child: const GlassSurface(borderRadius: kGlassCapsule)),
      Positioned(left: 150, top: 60, width: 80, height: 80, child: const GlassSurface(borderRadius: kGlassCapsule)),
    ],
  ),
)
```

## Moving glass for free

Glass that moves over still content would take a capture a frame. Inside a
[GlassTravel](../g1455/GlassTravel-class.html) the host captures the whole region once and the glass samples
what it already holds:

```dart
GlassTravel(
  child: Stack(
    children: <Widget>[
      Positioned(left: at.dx, top: at.dy, width: 120, height: 120,
          child: const GlassSurface(borderRadius: kGlassCapsule)),
    ],
  ),
)
```

## Glass on glass

Glass written *inside* other glass refracts it automatically. Glass *beside*
it does not: a bar floating over a list of [GlassCard](../g1455/GlassCard-class.html)s sees the page with the
cards cut out, until it is wrapped in a [GlassAbove](../g1455/GlassAbove-class.html).
