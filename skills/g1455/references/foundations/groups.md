# Groups & unions

> Draw several glass surfaces as one piece of liquid glass: GlassGroup fuses them when they come close, GlassUnion keeps them joined at any distance.

- Live: https://g1455.plugfox.dev/foundations/groups
- API: [`GlassGroup`](https://pub.dev/documentation/g1455/latest/g1455/GlassGroup-class.html), [`GlassUnion`](https://pub.dev/documentation/g1455/latest/g1455/GlassUnion-class.html), [`kMaxFusedShapes`](https://pub.dev/documentation/g1455/latest/g1455/kMaxFusedShapes-constant.html), [`unionBlendRadius()`](https://pub.dev/documentation/g1455/latest/g1455/unionBlendRadius.html), [`GlassBlendGroup`](https://pub.dev/documentation/g1455/latest/g1455/GlassBlendGroup-class.html), [`GlassGroupScope`](https://pub.dev/documentation/g1455/latest/g1455/GlassGroupScope-class.html)
- Source: [`lib/src/surface/glass_group.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_group.dart)

A `GlassGroup` draws every `GlassSurface` inside it as **one piece of glass**, like SwiftUI's `GlassEffectContainer`. Members closer than `spacing` grow a smooth bridge and merge into one silhouette, then separate again as they move apart. A member whose `presence` animates up from 0 "buds" out of its neighbours instead of appearing on its own.

A `GlassUnion` is the always-joined variant, like SwiftUI's `glassEffectUnion`. Its members form **one connected piece however far apart they are**. The blend radius is solved so that everyone just connects, so the further apart the members, the puffier the whole silhouette.

## When to use

- **GlassGroup:** the merging-blob look, or controls that should visibly melt together as they approach (a button that buds out of a bar, a drop that leaves its track).
- **GlassUnion:** separated controls that must read as one glass object, such as a split pill or a cluster of buttons.
- **Not** as a performance trick. A group costs *more* than the same surfaces drawn separately, and `spacing: 0` shares a draw but saves nothing.
- **Not** around your page background. Everything inside the group paints on top of the glass.

## Usage

```dart
// Two circles that fuse when they are within 16 px of each other.
GlassGroup(
  spacing: 16,
  labelled: false,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(width: 56, height: 56, child: GlassSurface(borderRadius: kGlassCapsule)),
      SizedBox(width: 8),
      SizedBox(width: 56, height: 56, child: GlassSurface(borderRadius: kGlassCapsule)),
    ],
  ),
);
```

Swap `GlassGroup` for `GlassUnion` (it has no `spacing`) and the two stay joined however far apart you put them.

## Behaviour

- **One finish per group.** The group's `finish` (or the host's) is used for every member. A member's own `finish` is ignored, with a debug warning once.
- **At most [`kMaxFusedShapes`](https://pub.dev/documentation/g1455/latest/g1455/kMaxFusedShapes-constant.html) (12) members fuse.** A bigger group stops fusing, and its members draw separately without bridges.
- **The nearest group wins.** A union nested inside a group takes its members out of the group.
- **Below the full [tier](../foundations/tiers.md), nothing fuses**: the bridges disappear and members draw as separate shapes.
- `fade` and `ripple` are not drawn on fused members.
- Raw `GlassSurface` members don't pick a label colour for you. Set text colours yourself, or put components such as `GlassButton` inside.

## Moving members

Blobs that orbit or follow a finger move over still content, so wrap them in a [`GlassTravel`](../foundations/travel.md) and a `RepaintBoundary`, like the demo above. The motion then costs no capture.

## Plumbing

`GlassBlendGroup` is the membership object behind a group or union, and `GlassGroupScope` is the inherited widget that hands it to the surfaces below. You don't build these yourself, but `GlassGroupScope.maybeOf(context) != null` tells a widget whether it is inside a group. `unionBlendRadius(boxes, radii)` returns the blend radius a union would use for those boxes.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Blobs that fuse, one that buds, and a split pill. Assumes a GlassHost above.
class FusingControls extends StatefulWidget {
  const FusingControls({super.key});

  @override
  State<FusingControls> createState() => _FusingControlsState();
}

class _FusingControlsState extends State<FusingControls> {
  bool _third = false;

  Widget _blob(double size, {double presence = 1}) => SizedBox(
    width: size,
    height: size,
    child: GlassSurface(borderRadius: kGlassCapsule, presence: presence, labelled: false),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // Members closer than `spacing` grow a bridge and fuse.
      GlassGroup(
        spacing: 20,
        finish: GlassFinish.clear,
        labelled: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _blob(64),
            const SizedBox(width: 12),
            _blob(64),
            const SizedBox(width: 12),
            // Animating presence from 0 makes it bud out of its neighbours.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _third ? 1 : 0),
              duration: const Duration(milliseconds: 400),
              builder: (BuildContext context, double p, Widget? _) => _blob(48, presence: p),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      // A union is always one piece, however far apart its members are.
      SizedBox(
        width: 280,
        child: GlassUnion(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 48,
                height: 48,
                child: GlassSurface(
                  borderRadius: kGlassCapsule,
                  child: IconButton(
                    onPressed: () => setState(() => _third = !_third),
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 160,
                height: 48,
                child: GlassSurface(
                  borderRadius: kGlassCapsule,
                  child: Center(
                    child: Text('Now playing', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
```

## API

`GlassGroup`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree that contains the member surfaces. |
| `spacing` | `double` | `0` | Edge-to-edge gap, in px, at which members fuse. `0` keeps shapes separate but shares one draw. |
| `finish` | `GlassFinish?` | `null` (the host's) | The finish of the whole group. Members' own finishes are ignored. |
| `labelled` | `bool` | `true` | Whether text sits on the glass. Set `false` for text-free blobs so the finish isn't dimmed. |

`GlassUnion`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree that contains the member surfaces. |
| `finish` | `GlassFinish?` | `null` (the host's) | The finish of the whole union. |
| `labelled` | `bool` | `true` | As `GlassGroup.labelled`. |

Related: `double unionBlendRadius(List<Rect> boxes, List<double> radii)` returns the blend radius a union would use. `GlassGroupScope({required GlassBlendGroup group, required Widget child})` with `static GlassBlendGroup? maybeOf(BuildContext context)`.

### Constants

| Name | Value | Description |
|---|---|---|
| `kMaxFusedShapes` | `12` | The most members a group or union fuses. Past it, members draw separately. |
