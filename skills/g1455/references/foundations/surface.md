# GlassSurface

> The primitive: a box of the screen that is glass. It refracts, blurs and tints the backdrop, then paints its child.

- Live: https://g1455.plugfox.dev/foundations/surface
- API: [`GlassSurface`](https://pub.dev/documentation/g1455/latest/g1455/GlassSurface-class.html), [`kGlassCapsule`](https://pub.dev/documentation/g1455/latest/g1455/kGlassCapsule-constant.html), [`GlassFade`](https://pub.dev/documentation/g1455/latest/g1455/GlassFade-class.html), [`GlassConcentric`](https://pub.dev/documentation/g1455/latest/g1455/GlassConcentric-class.html)
- Source: [`lib/src/surface/glass_surface.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_surface.dart)

`GlassSurface` says "this box of the screen is glass". It refracts, blurs and tints what is behind it, draws a thin rim
along its edge, then paints its child on top. Its shape is a smooth rounded rectangle, Apple's continuous-corner
squircle, drawn as the engine's own `RSuperellipse`.

Every component in the package is built from it. Reach for it when you need a shape no component offers.

## When to use

- Custom glass: lenses, blobs, a now-playing pill, a panel of your own design.
- Members of a [GlassGroup](../foundations/groups.md) or `GlassUnion`, which fuse surfaces into one silhouette.
- Not when a component exists. [GlassBar](../components/bar.md), [GlassCard](../components/card.md) and
  [GlassButton](../components/button.md) also choose a legible label colour, which a raw surface does not.

## Usage

```dart
const SizedBox(
  width: 220,
  height: 120,
  child: GlassSurface(
    borderRadius: BorderRadius.all(Radius.circular(28)),
    child: Center(child: Text('Glass', style: TextStyle(color: Color(0xFFFFFFFF)))),
  ),
)
```

A surface is a plain box: give it a size with a `SizedBox`, a `Positioned` with a width and height, or a child that
has one. `kGlassCapsule` makes a pill or a circle at any size.

## Appearing and leaving

Two values, from 0 to 1, and they do different things:

- `materialize` is how far the **material** has arrived: the bend and the blur first, the tint last, over the whole
  shape. That is Apple's materialize transition, and the one to animate when a panel appears or leaves. At 0 nothing
  is drawn or captured.
- `presence` is how much of the **shape** exists. Inside a [GlassGroup](../foundations/groups.md) a member growing from 0
  buds out of its neighbours. On a lone panel it narrows the shape to a line, which is rarely what you want.

## Labels

`labelled` (true by default) says text sits on this glass. When the host declares `minLabelContrast`, labelled glass
may be dimmed to keep that text readable. Set `labelled: false` on glass that carries no text, such as lenses, drops
and blobs, so it keeps its finish exactly as named. Inside a raw surface, set the text colour yourself; see
[Legibility & theme](../foundations/legibility.md).

## Nested shapes

A shape inside glass, a highlight, a thumb, a ring, an inner panel, looks right when it is concentric with the glass:
its corner shares the glass's centre of curvature, so its radius is the glass's less the inset between them. That is
Apple's rule for iOS 26 (SwiftUI's `ConcentricRectangle`), and `GlassConcentric` is it as arithmetic, with a floor so a
deep inset does not square the corner off:

```dart
// A highlight 6 px inside a card of radius 24: radius 18.
final BorderRadius inner = GlassConcentric.borderRadius(
  const BorderRadius.all(Radius.circular(24)),
  const EdgeInsets.all(6),
  min: 4,
);

GlassCard(
  borderRadius: const BorderRadius.all(Radius.circular(24)),
  padding: const EdgeInsets.all(6),
  child: DecoratedBox(
    // The glass's own shape, so the corners agree all the way round.
    decoration: ShapeDecoration(color: const Color(0x33FFFFFF), shape: RoundedSuperellipseBorder(borderRadius: inner)),
    child: const SizedBox(height: 64),
  ),
)
```

- `GlassConcentric.radius(outer, inset, min: 0)` is the rule for one corner: `outer - inset`, never below `min`.
- `GlassConcentric.borderRadius(outer, insets, min: 0)` applies it per corner, each corner less the two insets beside it.
- `GlassConcentric.outset(inner, distance)` goes the other way, for a ring drawn outside a shape: 3 px outside a radius
  of 12 is 15.
- A capsule nests as a capsule: `kGlassCapsule` less any inset is still a pill.

The package's own nested shapes go through it: the segmented control's capsule (14 inside a 16 track inset 2) and the
keyboard's focus rings.

## Performance

- Each surface is one draw. Keep the count low and prefer one bigger surface to many small ones.
- Animating `presence` costs no capture. Animating `materialize` changes the blur, which means a capture every frame
  while it runs.
- Moving glass belongs in a [GlassTravel](../foundations/travel.md) region so the motion costs no capture.

> [!TIP]
> Set `debugPaintGlassSurfaces = true` in debug builds to outline every surface in cyan.

## Gotchas

- Hit-testing goes to the child only: an empty surface is not tappable unless it has a ripple.
- Glass sitting beside other glass does not show it. To float a surface above other glass, wrap it in
  [GlassAbove](../foundations/above.md).

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A now-playing pill that materializes in, next to a magnifying lens.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AnimatedBuilder(
        animation: _in,
        builder: (BuildContext context, Widget? child) => GlassSurface(
          borderRadius: kGlassCapsule,
          // Blur and bend arrive first, the tint last.
          materialize: Curves.easeOut.transform(_in.value),
          child: child,
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.music_note, color: Colors.white),
              SizedBox(width: 8),
              Text('Now playing', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 16),
      // A text-free lens: `labelled: false` keeps the clear finish undimmed.
      SizedBox(
        width: 72,
        height: 72,
        child: GlassSurface(
          borderRadius: kGlassCapsule,
          finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.4)),
          labelled: false,
        ),
      ),
    ],
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `borderRadius` | `BorderRadius` | `BorderRadius.all(Radius.circular(24))` | Corner radii. `kGlassCapsule` gives a pill or a circle at any size. |
| `finish` | `GlassFinish?` | `null` | The material for this surface. Null takes the theme's. |
| `materialize` | `double` | `1` | 0 to 1: how far the material has arrived, blur and bend first, tint last. At 0 nothing is drawn or captured. |
| `presence` | `double` | `1` | 0 to 1: how much of the shape exists. In a group a member buds from its neighbours; alone it narrows to a line. |
| `labelled` | `bool` | `true` | Text sits on this glass, so it may be dimmed to meet `minLabelContrast`. `false` for lenses and drops. |
| `fade` | `GlassFade?` | `null` | Fades the glass out across the surface, scroll-edge style. Ignored for members of a fusing group. |
| `ripple` | `GlassRipple?` | `null` | A touch wave for this surface. Null takes the theme's, which is none by default. |
| `child` | `Widget?` | `null` | Drawn on top of the glass. It receives the hits. |

### GlassFade

| Constructor | Description |
|---|---|
| `GlassFade({required Offset begin, required Offset end})` | Whole at `begin`, gone at `end`, in local logical pixels, with a smoothstep between. |
| `GlassFade.vertical({required double from, required double extent})` | The vertical form. A negative `extent` fades upward. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassCapsule` | `BorderRadius.all(Radius.circular(1e9))` | An over-large radius the engine clamps to half the short side: a stadium at any size. |
| `debugPaintGlassSurfaces` | `false` | A top-level variable. In debug builds, outlines every surface in cyan. |

### GlassConcentric

| Member | Description |
|---|---|
| `static double radius(double outer, double inset, {double min = 0})` | The radius of a shape `inset` px inside a container of radius `outer`: `outer - inset`, never below `min`. |
| `static BorderRadius borderRadius(BorderRadius outer, EdgeInsets inset, {double min = 0})` | The same per corner, each less the insets of the two sides that meet there. |
| `static BorderRadius outset(BorderRadius inner, double distance)` | The radii of a shape `distance` px outside `inner`. |
