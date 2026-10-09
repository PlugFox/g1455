The material and the host it needs. Everything else in the package is built
from these.

## The host

[GlassHost](../g1455/GlassHost-class.html) records what is painted under its glass into one atlas, at a
resolution chosen against a measured quality budget, and only when something
under the glass changed: a still screen captures nothing, and glass moving over
still content inside a [GlassTravel](../g1455/GlassTravel-class.html) captures nothing either. It also takes
what the application knows and the render tree does not: the [GlassHost.backdrop](../g1455/GlassHost/backdrop.html)
behind the glass, [GlassHost.richBackdrop](../g1455/GlassHost/richBackdrop.html), [GlassHost.minLabelContrast](../g1455/GlassHost/minLabelContrast.html), the
[GlassHost.thermal](../g1455/GlassHost/thermal.html) state, [GlassHost.hardware](../g1455/GlassHost/hardware.html) and [GlassHost.highContrast](../g1455/GlassHost/highContrast.html).

```dart
GlassHost(
  backdrop: const Color(0xFF101014), // what is behind the glass, on average
  ripple: const GlassRipple(viscosity: 0.3), // every surface answers a touch
  child: navigator!,
)
```

## The surface

[GlassSurface](../g1455/GlassSurface-class.html) is the primitive: a region of the screen that is glass, with a
corner radius drawn as the engine's round superellipse, an optional finish, and
two ways in and out: `materialize`, the whole shape at once (blur first, tint
last), and `presence`, which erodes it (for budding inside a [GlassGroup](../g1455/GlassGroup-class.html)).

```dart
GlassSurface(
  borderRadius: const BorderRadius.all(Radius.circular(28)),
  finish: GlassFinish.clear,
  child: const Padding(padding: EdgeInsets.all(20), child: Text('Clear glass')),
)
```

Most screens never use it directly: [GlassBar](../g1455/GlassBar-class.html), [GlassButton](../g1455/GlassButton-class.html) and [GlassCard](../g1455/GlassCard-class.html)
are surfaces with a label colour chosen for legibility.

## Finishes

A [GlassFinish](../g1455/GlassFinish-class.html) is what the glass does to the light: the blur, the tint, the
rim and the [GlassOptics](../g1455/GlassOptics-class.html) of the edge. Four are calibrated against Apple's own
materials on iOS 26:

| Finish | Looks like |
|---|---|
| [GlassFinish.regularDark](../g1455/GlassFinish/regularDark-constant.html) | `.regular` over dark content: dark, and barely transmitting |
| [GlassFinish.regularLight](../g1455/GlassFinish/regularLight-constant.html) | `.regular` over light content |
| [GlassFinish.clear](../g1455/GlassFinish/clear-constant.html) | `.clear`: no blur, a light tint, the bend in full |
| [GlassFinish.frosted](../g1455/GlassFinish/frosted-constant.html) | heavy blur, a frosted pane |

Name none and the host picks the branch of `.regular` the way Apple does: from
the declared backdrop and the platform's appearance, or, with a
[GlassAdaptive](../g1455/GlassAdaptive-class.html) on the host, from what each glass reads under it.

## The theme

[GlassTheme](../g1455/GlassTheme-class.html) hands a subtree its [GlassThemeData](../g1455/GlassThemeData-class.html): the finish every surface
wears unless it names its own, the tier, the label floor, the drop motion.
[GlassThemeData.legibility](../g1455/GlassThemeData/legibility.html) answers the label colour for a finish, as
[GlassLegibility](../g1455/GlassLegibility-class.html).

## Optional

- [GlassRipple](../g1455/GlassRipple-class.html): a viscous wave from the touch, from water to honey. No capture,
  no repaint; off under reduced motion.
- [GlassAdaptive](../g1455/GlassAdaptive-class.html): glass that reads its own backdrop and picks its branch and
  label from it.
- [GlassDropMotion](../g1455/GlassDropMotion-class.html): how the held drop of a switch, a slider, a segmented control
  or a tab bar stretches as it sets off and squashes as it stops.
- [GlassPress](../g1455/GlassPress-class.html): how a pressed [GlassButton](../g1455/GlassButton-class.html) swells and leans toward a
  dragging finger. On by default; two captures a press and none at rest. [GlassPress.none](../g1455/GlassPress/none-constant.html)
  turns it off, and so does reduced motion.

## Nested shapes

[GlassConcentric](../g1455/GlassConcentric-class.html) is Apple's rule for a shape inside another: its radius is the
container's less the inset between them, never below a floor. Use it for a highlight, a thumb or a ring inset in glass.

```dart
// A highlight 4 px inside a card of radius 24: radius 20.
final BorderRadius inner = GlassConcentric.borderRadius(
  const BorderRadius.all(Radius.circular(24)),
  const EdgeInsets.all(4),
);
```
