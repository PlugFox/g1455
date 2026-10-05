# Morph

> One piece of glass that flows to the size of whatever child it holds: a button that becomes a panel, with a liquid neck while it moves.

- Live: https://g1455.plugfox.dev/components/morph
- API: [`GlassMorph`](https://pub.dev/documentation/g1455/latest/g1455/GlassMorph-class.html), [`GlassMorphMotion`](https://pub.dev/documentation/g1455/latest/g1455/GlassMorphMotion-class.html), [`kGlassMorphSpacing`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMorphSpacing-constant.html)
- Source: [`lib/src/surface/glass_morph.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_morph.dart)

`GlassMorph` holds one child on glass. Give it a child of another identity, another type or another `Key`, and the
glass flows to the new child's size while the old content fades out and the new fades in. It's how a button becomes its
menu in iOS 26.

You never type a size: the glass measures the child. `width` and `height` are overrides that pin one axis.

## When to use

- A control that turns into the panel it opens, in place: a "+" into a list of actions, a pill into a search field.
- A card whose content changes size, where the glass should follow rather than jump.
- **Not** for a menu that floats over the page and closes on a tap outside. Use the [menu](../components/menu.md) or the
  [popover](../components/popover.md), which bring their own overlay and barrier.

## Usage

```dart
Align(
  alignment: Alignment.topRight,
  child: GlassMorph(
    alignment: Alignment.topRight,
    borderRadius: open ? const BorderRadius.all(Radius.circular(28)) : kGlassCapsule,
    child: open
        ? ActionsPanel(key: const ValueKey<String>('panel'), onDone: close)
        : PlusButton(key: const ValueKey<String>('plus'), onTap: openPanel),
  ),
)
```

## Alignment: what holds still

`alignment` is the point of the glass that stays put **inside the morph's own box** while the size changes. The box is
placed by the morph's parent, so to hold a corner on the screen, the parent has to hold the same corner: an `Align`, a
`Positioned` with `top` and `right`, the end of a `Row`. Inside a `Center`, the glass grows from its centre whatever
`alignment` says. Give the parent and the morph the same alignment, as the demo does.

## Identity

The rule is `AnimatedSwitcher`'s. A child of the same type and key is updated in place: no morph, and the glass takes its
new size at once. Changing `width`, `height` or `borderRadius` alone does morph. A child swapped back while it is still
fading out keeps its state.

## Motion

- `GlassMorphMotion.fluid`, the default: a spring with a little overshoot.
- `GlassMorphMotion.calm`: no overshoot, a little slower, for large panels.
- Or your own: `GlassMorphMotion(duration: ..., bounce: ...)`, SwiftUI's spring parameters.
- With reduce motion on, there is no motion: the new child and its size arrive at once.

## Cost

- At rest it's one plain glass surface.
- While it grows, it's a [group](../foundations/groups.md) of two shapes, and a capture on every frame, because the glass
  changes size. Wrap a fixed-size ancestor that holds every size the morph takes in a `GlassTravel`, and the motion is
  drawn from the proxy already held.
- `spacing: 0` turns the neck off: a plain resize with the cross-fade, and no group even mid-morph.

## Accessibility

- Only the new child is hit and read by a screen reader while the glass moves.
- Label the controls inside the panel as you would anywhere else.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A "+" in the corner that flows into a panel of actions.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class NewThing extends StatefulWidget {
  const NewThing({super.key});

  @override
  State<NewThing> createState() => _NewThingState();
}

class _NewThingState extends State<NewThing> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Align(
    // The parent holds the top-right corner, and so does the glass.
    alignment: Alignment.topRight,
    child: GlassMorph(
      alignment: Alignment.topRight,
      borderRadius: _open ? const BorderRadius.all(Radius.circular(28)) : kGlassCapsule,
      child: _open
          ? Column(
              key: const ValueKey<String>('panel'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String name in <String>['Note', 'List', 'Photo'])
                  SizedBox(
                    width: 200,
                    child: TextButton(onPressed: () => setState(() => _open = false), child: Text(name)),
                  ),
              ],
            )
          : IconButton(
              key: const ValueKey<String>('plus'),
              tooltip: 'New',
              onPressed: () => setState(() => _open = true),
              icon: const Icon(Icons.add),
            ),
    ),
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | What the glass holds and measures. A child of another type or key starts a morph. |
| `alignment` | `AlignmentGeometry` | `Alignment.center` | The point that holds still in the morph's box. The parent has to hold it on screen. |
| `width` | `double?` | `null` | Pins the glass's width; the child is laid out at it. Null measures. |
| `height` | `double?` | `null` | Pins the glass's height; the child is laid out at it. Null measures. |
| `borderRadius` | `BorderRadius` | `24` all round | The corners around this child. `kGlassCapsule` is a pill at any size. |
| `motion` | `GlassMorphMotion` | `GlassMorphMotion.fluid` | The spring. `GlassMorphMotion.calm` has no overshoot. |
| `spacing` | `double` | `kGlassMorphSpacing` (16) | How far the neck reaches while the glass moves. Zero: no neck and no group. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `labelled` | `bool` | `true` | Whether a label is drawn over the glass, so the theme's label floor applies. |
| `onEnd` | `VoidCallback?` | `null` | Called when a morph has settled. |
