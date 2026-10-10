# Toolbar

> Several toolbar actions in one glass capsule, the way iOS 26 groups toolbar items. One surface for any number of actions, so it costs far less than a row of buttons.

- Live: https://g1455.plugfox.dev/components/toolbar
- API: [`GlassButtonGroup`](https://pub.dev/documentation/g1455/latest/g1455/GlassButtonGroup-class.html), [`GlassToolbarItem`](https://pub.dev/documentation/g1455/latest/g1455/GlassToolbarItem-class.html), [`kGlassToolbarHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarHeight-constant.html), [`kGlassToolbarItemWidth`](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarItemWidth-constant.html)
- Source: [`lib/src/surface/glass_toolbar.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_toolbar.dart)

iOS 26 doesn't put a glass behind each toolbar button. It groups adjacent items into one glass shape: a 48 px circle for
an item on its own, and a capsule for several. `GlassButtonGroup` does the same. You give it a list of
`GlassToolbarItem`s (an icon, an action and a label for screen readers), and it draws them in **one** glass surface.

Pressing an item brightens just its cell, the same way a [GlassButton](../components/button.md) brightens: the finish's rim
colour is added over the cell, clipped to the capsule. Icons are themed at 22 px in the label colour the theme picks for
the glass.

## When to use

- Icon actions in a toolbar or over content: undo and redo, share, like, delete, previous and next.
- Instead of a row of `GlassButton`s whenever the actions sit next to each other.
- **Not** for text labels. The group is icon-first and its size is fixed. For a labelled action, use a
  [GlassButton](../components/button.md).
- **Not** for choosing one of several values. That's a [segmented control](../components/segmented-control.md).

## Usage

```dart
Row(
  children: <Widget>[
    GlassButtonGroup(
      items: <GlassToolbarItem>[
        GlassToolbarItem(icon: const Icon(Icons.undo), label: 'Undo', onPressed: canUndo ? undo : null),
        GlassToolbarItem(icon: const Icon(Icons.redo), label: 'Redo', onPressed: canRedo ? redo : null),
      ],
    ),
    const Spacer(),
    GlassButtonGroup(
      items: <GlassToolbarItem>[
        GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: share),
      ],
    ),
  ],
)
```

## Why one surface

Glass is paid for per surface, and the overhead grows faster than the number of surfaces. Three `GlassButton`s are three
surfaces; a group of three is one. Grouping is how Apple draws it, and it's also the cheap way to build it. See
[Performance](../foundations/performance.md).

## Layout

- The size is fixed: [kGlassToolbarHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarHeight-constant.html)
  (48) high, and 48 wide for one item or
  [kGlassToolbarItemWidth](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarItemWidth-constant.html) (53)
  per item for more. Don't stretch it; place groups with a `Row` and `Spacer`s.
- Four items are 212 px wide. On a narrow phone, a 4-item group plus two circles don't fit in 320 px: drop an action
  or move it into a [menu](../components/menu.md).
- Groups float over the content on their own, as in iOS. Putting them inside a [GlassBar](../components/bar.md) works, but it
  is glass on glass and adds a capture level.

## Accessibility

- **Always set `label`.** It is what a screen reader says for the item; the icon alone says nothing.
- `onPressed: null` disables an item: its icon drops to 30% and it is announced as disabled.
- Each item takes the focus from the keyboard, Space or Enter presses it, and its ring is drawn inside its cell, inside
  the glass: no capture. A held cell brightens but does not swell as a [button](../components/button.md) does, because the
  group is one surface.
- The items run in the reading direction: under a right-to-left `Directionality` the first is at the right.
- A count on an icon is a [badge](../components/badge.md): `GlassToolbarItem(icon: GlassBadge(count: 3, child: icon))`.

> [!WARNING]
> Don't wrap a group in `Opacity`, `ColorFilter` or `ImageFilter`. The pressed highlight is added onto what's below, and
> those widgets break it. `RepaintBoundary` is fine.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A photo viewer's bottom toolbar: share alone, three actions grouped,
/// and delete alone. Three glass surfaces for five actions.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({required this.photo, super.key});

  final ImageProvider photo;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  bool _liked = false;

  void _toast(String what) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(child: Image(image: widget.photo, fit: BoxFit.cover)),
      Positioned(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
        child: Row(
          children: <Widget>[
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: () => _toast('Share')),
              ],
            ),
            const Spacer(),
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                  label: _liked ? 'Unlike' : 'Like',
                  onPressed: () => setState(() => _liked = !_liked),
                ),
                GlassToolbarItem(icon: const Icon(Icons.info_outline), label: 'Info', onPressed: () => _toast('Info')),
                GlassToolbarItem(icon: const Icon(Icons.tune), label: 'Edit', onPressed: () => _toast('Edit')),
              ],
            ),
            const Spacer(),
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(
                  icon: const Icon(Icons.delete_outline),
                  label: 'Delete',
                  onPressed: () => _toast('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
```

## API

`GlassButtonGroup`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassToolbarItem>` | **required** | The actions, in the reading direction. Must not be empty. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `pressedOverlay` | `Color?` | `null` | Added over a held item's cell. Null takes the finish's rim colour. |

`GlassToolbarItem`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `icon` | `Widget` | **required** | The icon, themed at 22 px in the label colour. |
| `onPressed` | `VoidCallback?` | **required** | The action. Null disables the item (icon at 30%). |
| `label` | `String?` | `null` | What a screen reader says. Always set it. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassToolbarHeight` | `48` | The group's height, and the size of a one-item circle. |
| `kGlassToolbarItemWidth` | `53` | Each item's width in a group of two or more. |
