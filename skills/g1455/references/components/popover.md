# Popover

> A glass panel of any content that grows out of its anchor and stays open while it is used: for quick settings and filters changed in place.

- Live: https://g1455.plugfox.dev/components/popover
- API: [`GlassPopoverAnchor`](https://pub.dev/documentation/g1455/latest/g1455/GlassPopoverAnchor-class.html)
- Source: [`lib/src/surface/glass_modal.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_modal.dart)

`GlassPopoverAnchor` is the [menu](../components/menu.md)'s sibling for content you change in place. It grows a glass panel
out of its anchor the same way, but the panel holds **any** widget you build, and it **stays open** until you tap
outside it or call `close()`. Text and icons inside take the label colour the theme picks for the glass.

The settings of this very site are a popover: the button with the tune icon at the right end of the top bar is a
`GlassPopoverAnchor`. Its panel holds the preset, material, tint, rendering, ripple and contrast choices, and the page
under it changes while you adjust them.

## When to use

- Quick settings and controls adjusted in place: display options, sort and filter, a volume slider.
- Small forms whose effect the user wants to see behind the panel as they change it.
- **Not** for a list of one-shot actions. A [menu](../components/menu.md) runs the action and closes for you.
- **Not** for long or multi-step forms. Use a [sheet](../components/sheet.md).

## Usage

```dart
GlassPopoverAnchor(
  width: 280,
  popoverBuilder: (BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Brightness'),
        const SizedBox(height: 8),
        GlassSlider(value: brightness, onChanged: setBrightness, semanticLabel: 'Brightness'),
      ],
    ),
  ),
  builder: (BuildContext context, GlassMenuController popover) => GlassButton(
    onPressed: popover.open,
    semanticLabel: 'Display settings',
    padding: EdgeInsets.zero,
    child: const Icon(Icons.tune),
  ),
)
```

## Placement

- Its height isn't known before it's laid out, so the popover opens **down** from an anchor in the upper half of the
  screen and **up** from one in the lower half.
- Like the menu, it lines up with the anchor on the side of the screen the anchor is on, and covers the anchor while
  open. Keep `width` within the screen: on a 320 px phone, a 320 px panel doesn't fit.
- `radius` sets the corners; it defaults to the menu's 31.5.

## Content that changes

The panel is rebuilt whenever the widget that builds the anchor rebuilds, so a `setState` there updates an open popover.
When the values live somewhere else, such as a `ValueNotifier`, a store or an `InheritedWidget`, listen to them inside
`popoverBuilder` so the open panel follows them too. The demo above keeps its filters in a `ValueNotifier` that both the
popover and the list listen to.

## Cost

- Glass controls inside the panel, such as a [slider](../components/slider.md) or a [switch](../components/switch.md), are glass
  on glass. That works, and costs one more capture level while the panel is open.
- When the anchor already sits on a glass bar, a plain `GestureDetector` is a cheaper anchor than a `GlassButton`. The
  site's settings button does exactly that.

## Accessibility

- The area around the open panel is announced with `barrierLabel` ("Dismiss"); it's how a screen reader closes it.
- Label the controls inside, e.g. `semanticLabel` on a `GlassSlider`, or `MergeSemantics` around a text and a switch.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A "Sort & filter" button whose popover changes the list behind it.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
class SortButton extends StatelessWidget {
  const SortButton({required this.sort, required this.openNow, super.key});

  /// 0 = name, 1 = distance, 2 = rating. The list listens to these too.
  final ValueNotifier<int> sort;
  final ValueNotifier<bool> openNow;

  @override
  Widget build(BuildContext context) => GlassPopoverAnchor(
    width: 300,
    radius: 26,
    // Listens, so the panel follows each change while it is open.
    popoverBuilder: (BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[sort, openNow]),
      builder: (BuildContext context, Widget? _) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Sort by', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GlassSegmentedControl(
              segments: const <Widget>[Text('Name'), Text('Distance'), Text('Rating')],
              selectedIndex: sort.value,
              onSelected: (int i) => sort.value = i,
            ),
            const SizedBox(height: 8),
            MergeSemantics(
              child: Row(
                children: <Widget>[
                  const Expanded(child: Text('Open now')),
                  GlassSwitch(value: openNow.value, onChanged: (bool v) => openNow.value = v),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    builder: (BuildContext context, GlassMenuController popover) => GlassButton(
      onPressed: popover.open,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Icon(Icons.tune, size: 20), SizedBox(width: 6), Text('Sort & filter')],
      ),
    ),
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `popoverBuilder` | `WidgetBuilder` | **required** | The panel's content. Built under a text style and icon theme in the label colour. |
| `builder` | `Widget Function(BuildContext, GlassMenuController)` | **required** | Builds the anchor, such as a button, and gets the controller that opens the panel. |
| `controller` | `GlassMenuController?` | `null` | Your own controller, to open or close the panel from outside. Null makes an internal one. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `width` | `double` | `320` | The panel's width. |
| `radius` | `double` | `kGlassMenuRadius` (31.5) | The panel's corner radius. |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the area around the open panel; a tap there closes it. |

`GlassMenuController`: `open()`, `close()`, `bool get isOpen`. The panel closes only on a tap outside or `close()`.
