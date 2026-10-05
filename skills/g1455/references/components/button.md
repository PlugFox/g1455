# Button

> GlassButton is a tappable glass capsule that brightens while held, with a 44 × 44 minimum tap target and dimmed labels when disabled.

- Live: https://g1455.plugfox.dev/components/button
- API: [`GlassButton`](https://pub.dev/documentation/g1455/latest/g1455/GlassButton-class.html), [`kGlassMinTapTarget`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMinTapTarget-constant.html), [`kGlassDisabledDarkLabel`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledDarkLabel-constant.html), [`kGlassDisabledLightLabel`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledLightLabel-constant.html)
- Source: [`lib/src/surface/glass_components.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_components.dart)

`GlassButton` is a glass capsule that takes a tap. While a finger is on it, the whole shape
brightens by the finish's rim colour, so the material itself changes rather than a highlight being
laid on top. The label (text, icon, or both) is centred and gets a legible colour, like a
[Bar](../components/bar.md).

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

## Gotchas

- Don't wrap a button in `Opacity`, `ColorFilter` or `ImageFilter`. The press highlight is added
  onto the glass, and those widgets make it add onto transparency instead, which looks wrong.
  A `RepaintBoundary` is fine.
- `pressedOverlay: Color(0x00000000)` turns the highlight off. Any other colour replaces the rim's.
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
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's. |
| `semanticLabel` | `String?` | `null` | What a screen reader says instead of the child. Set it on icon-only buttons. |
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassMinTapTarget` | `Size(44, 44)` | Apple's minimum tap target; the default `minSize`. |
| `kGlassDisabledDarkLabel` | `Color(0x4D3C3C43)` | Disabled label where the enabled one is black. |
| `kGlassDisabledLightLabel` | `Color(0x4DEBEBF5)` | Disabled label where the enabled one is white. |
