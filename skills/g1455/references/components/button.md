# Button

> GlassButton is a tappable glass capsule that brightens and swells while held, with a 44 × 44 minimum tap target, keyboard focus and dimmed labels when disabled.

- Live: https://g1455.plugfox.dev/components/button
- API: [`GlassButton`](https://pub.dev/documentation/g1455/latest/g1455/GlassButton-class.html), [`GlassPress`](https://pub.dev/documentation/g1455/latest/g1455/GlassPress-class.html), [`kGlassMinTapTarget`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMinTapTarget-constant.html), [`kGlassDisabledDarkLabel`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledDarkLabel-constant.html), [`kGlassDisabledLightLabel`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledLightLabel-constant.html), [`kGlassFocusRingColor`](https://pub.dev/documentation/g1455/latest/g1455/kGlassFocusRingColor-constant.html)
- Source: [`lib/src/surface/glass_components.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_components.dart)

`GlassButton` is a glass capsule that takes a tap. While a finger is on it, the whole shape
brightens by the finish's rim colour, so the material itself changes rather than a highlight being
laid on top, and the glass swells a little and leans toward a finger that drags. The label (text,
icon, or both) is centred and gets a legible colour, like a [Bar](../components/bar.md).

The whole capsule is the tap target, and it is never smaller than
[`kGlassMinTapTarget`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMinTapTarget-constant.html)
(44 × 44, Apple's minimum).

## When to use

- A standalone action on glass: a floating "add" button, the choices in a [sheet](../components/sheet.md),
  the trigger of a [menu](../components/menu.md) or a [popover](../components/popover.md).
- A primary action on a [Card](../components/card.md).
- **Not** for a row of actions in a toolbar: each button is a surface of its own. A
  [toolbar](../components/toolbar.md) (`GlassButtonGroup`) draws all of them as one.
- **Not** for every button of your app. Glass belongs to controls that float over content.

## Usage

```dart
GlassButton(
  onPressed: () {},
  child: const Text('Done'),
)
```

An icon-only button has nothing for a screen reader to say, so give it a `semanticLabel`. It
replaces the child's semantics. Drop the padding so it stays a circle:

```dart
GlassButton(
  onPressed: close,
  semanticLabel: 'Close',
  padding: EdgeInsets.zero,
  child: const Icon(Icons.close),
)
```

## Disabled

Pass `onPressed: null`. The glass stays exactly as it is and the label dims: to
`kGlassDisabledDarkLabel` where the enabled label would be black, and to `kGlassDisabledLightLabel`
where it would be white. That follows iOS 26, which also leaves the glass alone and only dims the
title. Semantics report the button as disabled.

## The press

Held, the glass grows by 12 px on its longest side, the shorter side by the same factor, and leans up to 3 px toward a
finger that drags, stretched a little along the drag. Let go, and it springs back. That is
[`GlassPress`](https://pub.dev/documentation/g1455/latest/g1455/GlassPress-class.html), read from the theme unless the
button names its own:

```dart
// One button that keeps its box, and a gentler swell for the rest of the app.
GlassButton(press: GlassPress.none, onPressed: save, child: const Text('Save'))

GlassHost(press: const GlassPress(grow: 8), child: navigator!)
```

- **A feel, not a measurement.** iOS 26's interactive glass does this, and Apple's press has not been measured here.
  The shape of the law, a fixed growth rather than a ratio, comes from another package; its 17 px would be 1.39× a
  44 px button, more than any held drop the package has read, so the default is 12.
- **What it costs:** two captures a press, one as the region the glass grows in is declared at touch-down and one as it
  goes when the spring settles, and none while it moves. Nothing at rest: declared always, the region took a 44 px
  button's slot from 3,600 to 7,056 px².
- Off under reduced motion, on a disabled button, and with `GlassPress.none`, which builds no region at all.
- A [toolbar](../components/toolbar.md)'s cells brighten but do not swell: the group is one surface.

## Keyboard

The button takes the focus from the keyboard (`focusNode`, `autofocus`), and Space or Enter presses it. The focus ring,
[`kGlassFocusRingColor`](https://pub.dev/documentation/g1455/latest/g1455/kGlassFocusRingColor-constant.html) 3 px wide
and 2 px outside the glass, concentric with its corners, is drawn from inside the glass's own subtree, which no capture
sees: focusing a button costs nothing.

## Gotchas

- Don't wrap a button in `Opacity`, `ColorFilter` or `ImageFilter`. The press highlight is added
  onto the glass, and those widgets make it add onto transparency instead, which looks wrong.
  A `RepaintBoundary` is fine.
- `pressedOverlay: Color(0x00000000)` turns the highlight off. Any other colour replaces the rim's. The swell is
  `press`, a separate thing.
- A button inside a bar or a card is glass on glass. It works, but it is one more surface and one
  more capture level. See [Performance](../foundations/performance.md).

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A photo viewer's floating actions.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class PhotoActions extends StatefulWidget {
  const PhotoActions({required this.canShare, super.key});

  final bool canShare;

  @override
  State<PhotoActions> createState() => _PhotoActionsState();
}

class _PhotoActionsState extends State<PhotoActions> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      GlassButton(
        // Null disables the button: the glass stays, the label dims.
        onPressed: widget.canShare ? () {} : null,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[Icon(Icons.ios_share, size: 18), SizedBox(width: 6), Text('Share')],
        ),
      ),
      const SizedBox(width: 12),
      GlassButton(
        onPressed: () => setState(() => _liked = !_liked),
        // Icon-only: say what it does, and keep it round.
        semanticLabel: _liked ? 'Unlike' : 'Like',
        padding: EdgeInsets.zero,
        child: Icon(_liked ? Icons.favorite : Icons.favorite_border),
      ),
      const SizedBox(width: 12),
      GlassButton(
        onPressed: () => Navigator.maybePop(context),
        semanticLabel: 'Close',
        padding: EdgeInsets.zero,
        child: const Icon(Icons.close),
      ),
    ],
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The label or icon, centred, in a legible colour. |
| `onPressed` | `VoidCallback?` | `null` | Called on a tap. Null disables the button. |
| `borderRadius` | `BorderRadius` | `kGlassCapsule` | Corner radii. |
| `padding` | `EdgeInsets` | `EdgeInsets.symmetric(horizontal: 20, vertical: 10)` | Space between the glass and the label. |
| `minSize` | `Size` | `kGlassMinTapTarget` | The smallest the button may be. |
| `pressedOverlay` | `Color?` | `null` | Added over the whole shape while held. Null takes the finish's `rim`; `Color(0x00000000)` disables it. |
| `press` | `GlassPress?` | `null` | How the glass swells and leans while held. Null takes the theme's; `GlassPress.none` keeps the box. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's. |
| `semanticLabel` | `String?` | `null` | What a screen reader says instead of the child. Set it on icon-only buttons. |
| `focusNode` | `FocusNode?` | `null` | The button's focus. Null makes one the button owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the button is built. |
| `key` | `Key?` | `null` | |

### GlassPress

| Parameter | Type | Default | Description |
|---|---|---|---|
| `grow` | `double` | `12` | How much longer the longest side is while held, in px; the shorter side grows by the same factor. |
| `maxStretch` | `double` | `0.05` | The most the glass stretches along a drag, as a fraction; the area is kept. 0 to 0.25. |
| `maxPull` | `double` | `3` | The most the glass's centre moves toward a dragging finger, in px. |
| `pullReach` | `double` | `12` | How far the finger drags, in px, for the lean and the stretch to reach three quarters of their most. |
| `stiffness` | `double` | `500` | The spring, at unit mass. |
| `damping` | `double` | `26` | The spring's damping, at unit mass. |

`GlassPress.none` responds to nothing. `rect(Size rest, double press, Offset finger)` and `margin(Size rest)` are the
geometry, pure, for a control of your own.

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassMinTapTarget` | `Size(44, 44)` | Apple's minimum tap target; the default `minSize`. |
| `kGlassDisabledDarkLabel` | `Color(0x4D3C3C43)` | Disabled label where the enabled one is black. |
| `kGlassDisabledLightLabel` | `Color(0x4DEBEBF5)` | Disabled label where the enabled one is white. |
| `kGlassFocusRingColor` | `Color(0xFF0A84FF)` | The keyboard's focus ring, on every control that takes the focus. |
| `kGlassFocusRingWidth` | `3` | The ring's stroke, in px. |
| `kGlassFocusRingGap` | `2` | The gap between the control's edge and the ring, in px. |
