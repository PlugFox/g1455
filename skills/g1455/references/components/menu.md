# Menu

> iOS 26's pull-down menu: a glass list of actions that grows out of the button that opened it. Choosing a row runs it and closes the menu.

- Live: https://g1455.plugfox.dev/components/menu
- API: [`GlassMenuAnchor`](https://pub.dev/documentation/g1455/latest/g1455/GlassMenuAnchor-class.html), [`GlassMenuItem`](https://pub.dev/documentation/g1455/latest/g1455/GlassMenuItem-class.html), [`GlassMenuController`](https://pub.dev/documentation/g1455/latest/g1455/GlassMenuController-class.html), [`kGlassMenuRadius`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRadius-constant.html), [`kGlassMenuRowHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRowHeight-constant.html), [`kGlassMenuWidth`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuWidth-constant.html)
- Source: [`lib/src/surface/glass_modal.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_modal.dart)

`GlassMenuAnchor` wraps the widget that opens a menu, usually a "…" [GlassButton](../components/button.md), and shows a
glass menu of `GlassMenuItem`s when you call `open()` on the controller its `builder` is given. The menu grows out of
the button the way iOS 26's does: from the button's own capsule to the menu's size, **over** the button rather than
beside it. The button is hidden while the menu is open, because the menu is what it turned into.

Choosing a row runs its action and closes the menu. A tap anywhere outside closes it too. There is no dim behind a menu.

## When to use

- A "more" (…) button with a handful of actions on an item: rename, duplicate, share, delete.
- A short list of one-shot choices from a button, such as "Sort by".
- **Not** for controls you adjust in place, such as switches or sliders. Those belong in a
  [popover](../components/popover.md), which stays open.
- **Not** for a single confirmation. That's an [alert](../components/alert.md).

## Usage

```dart
GlassMenuAnchor(
  items: <GlassMenuItem>[
    GlassMenuItem(label: 'Rename', icon: const Icon(Icons.edit_outlined), onPressed: rename),
    GlassMenuItem(label: 'Duplicate', icon: const Icon(Icons.copy), onPressed: duplicate),
    GlassMenuItem(label: 'Delete', icon: const Icon(Icons.delete_outline), isDestructive: true, onPressed: delete),
  ],
  builder: (BuildContext context, GlassMenuController menu) => GlassButton(
    onPressed: menu.open,
    semanticLabel: 'More actions',
    padding: EdgeInsets.zero,
    child: const Icon(Icons.more_horiz),
  ),
)
```

## Placement

- The menu opens **downward** from the button's top when there is room below, and **upward** from its bottom when not.
  When it opens upward, the items are reversed, so the first one stays nearest your finger.
- It lines up with the button on the side of the screen the button is on, and stays at least 8 px inside the screen.
- It's built in the nearest `Overlay`, so it stands over everything on the page, bars included.

## Items

- Each row is [kGlassMenuRowHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRowHeight-constant.html)
  (42) high, with the icon in a 48 px column before the label. Labels are one line and end with an ellipsis.
- `isDestructive` draws the row in iOS red. `onPressed: null` disables the row and dims it to 30%.
- The menu is [kGlassMenuWidth](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuWidth-constant.html) (250)
  wide unless you pass `width`, with corners of
  [kGlassMenuRadius](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRadius-constant.html) (31.5).

## Opening from code

Pass your own `GlassMenuController` to open or close the menu from anywhere: `open()`, `close()` and `isOpen`. A
controller drives one anchor at a time.

## Setup and accessibility

- The [GlassHost](../foundations/host.md) must be above the overlay the menu is built in. With the host in
  `MaterialApp(builder: ...)`, that's true everywhere.
- Give an icon-only button a `semanticLabel`. The area around the open menu is announced with `barrierLabel`.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A note's header with a "…" menu of actions.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
class NoteHeader extends StatefulWidget {
  const NoteHeader({required this.title, super.key});

  final String title;

  @override
  State<NoteHeader> createState() => _NoteHeaderState();
}

class _NoteHeaderState extends State<NoteHeader> {
  bool _pinned = false;

  void _toast(String what) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.headlineSmall)),
      GlassMenuAnchor(
        width: 220,
        items: <GlassMenuItem>[
          GlassMenuItem(
            label: _pinned ? 'Unpin' : 'Pin',
            icon: const Icon(Icons.push_pin_outlined, size: 20),
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          GlassMenuItem(
            label: 'Duplicate',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () => _toast('Duplicated'),
          ),
          const GlassMenuItem(label: 'Move to…', icon: Icon(Icons.folder_outlined, size: 20)), // disabled
          GlassMenuItem(
            label: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            isDestructive: true,
            onPressed: () => _toast('Deleted'),
          ),
        ],
        builder: (BuildContext context, GlassMenuController menu) => GlassButton(
          onPressed: menu.open,
          semanticLabel: 'More actions',
          padding: EdgeInsets.zero,
          child: const Icon(Icons.more_horiz),
        ),
      ),
    ],
  );
}
```

## API

`GlassMenuAnchor`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassMenuItem>` | **required** | The menu's rows, top to bottom. |
| `builder` | `Widget Function(BuildContext, GlassMenuController)` | **required** | Builds the anchor, such as a button, and gets the controller that opens the menu. |
| `controller` | `GlassMenuController?` | `null` | Your own controller, to open or close the menu from outside. Null makes an internal one. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `width` | `double` | `kGlassMenuWidth` (250) | The menu's width. |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the area around the open menu. |

`GlassMenuItem`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | **required** | The row's text, one line. |
| `icon` | `Widget?` | `null` | Drawn before the label. |
| `onPressed` | `VoidCallback?` | `null` | The action. Null disables the row. The menu closes after it runs. |
| `isDestructive` | `bool` | `false` | Draws the row in iOS red. |

`GlassMenuController`: `open()`, `close()`, `bool get isOpen`.

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassMenuWidth` | `250` | The menu's default width. |
| `kGlassMenuRowHeight` | `42` | Each row's height. |
| `kGlassMenuRadius` | `31.5` | The menu's corner radius, and the popover's default. |
