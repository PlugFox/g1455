# Tab bar

> GlassTabBar is the floating iOS 26 tab bar. The selected tab lifts into a glass drop that magnifies the bar and can be dragged from tab to tab.

- Live: https://g1455.plugfox.dev/components/tab-bar
- API: [`GlassTabBar`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabBar-class.html), [`GlassTabItem`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItem-class.html), [`GlassTabItemLook`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItemLook-class.html), [`GlassTabItemBuilder`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItemBuilder.html), [`kGlassTabDropZoom`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabDropZoom-constant.html), [`kGlassTabDropGrow`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabDropGrow-constant.html)
- Source: [`lib/src/surface/glass_tab_bar.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_tab_bar.dart)

`GlassTabBar` is the floating tab bar of iOS 26: a [Bar](../components/bar.md) holding two to five tabs,
each an icon over a label. The selected tab sits on a grey pill in the `activeColor`. Press it and
the pill lifts into a clear glass drop that magnifies the bar under it; drag the drop along the bar
and the tab under your finger lights up; let go and that tab is selected. A plain tap on a tab works
too.

The layout adapts to the width: below 80 px per tab, the icon sits over the label (phones); above
that, they sit side by side (tablets and desktop).

## When to use

- The top-level sections of an app: Home, Search, Library, Profile.
- **Not** for switching views inside one screen: that is a
  [segmented control](../components/segmented-control.md).
- **Not** for actions: tabs select a place, they don't do something. Use a
  [toolbar](../components/toolbar.md) for actions.
- **Not** for more than five sections. It asserts at least two.

## Usage

```dart
const List<GlassTabItem> tabs = <GlassTabItem>[
  GlassTabItem(icon: Icons.home, label: 'Home'),
  GlassTabItem(icon: Icons.search, label: 'Search'),
  GlassTabItem(icon: Icons.person, label: 'Profile'),
];

Positioned(
  left: 16,
  right: 16,
  bottom: MediaQuery.paddingOf(context).bottom + 12,
  child: GlassTabBar(
    items: tabs,
    selectedIndex: _tab,
    onSelected: (int i) => setState(() => _tab = i),
  ),
)
```

The bar takes its width from its parent, so it needs a bounded width: `Positioned(left:, right:)`
is the usual way. Leave room at the bottom of your scrolling content so the last item is not hidden
behind it.

## Behaviour

- The drop magnifies by `dropZoom` (default `kGlassTabDropZoom`, 1.17, as on iOS). `1` means no
  magnification.
- The drop is glass over glass (the bar), so while it is held the host captures one extra level.
  At rest, the bar is one surface.
- Each tab is a button for screen readers, labelled with its `label` and marked selected.
- The held drop stretches as it sets off and squashes as it lands. `dropMotion:` tunes it or turns it off; see
  [Drop motion](../foundations/drop-motion.md).

## Custom icons and badges

An `IconData` is drawn by the bar in the right colour: the accent when selected, otherwise the label colour its glass
chose. For anything else, an SVG, an image, a badge, give `iconBuilder` (or `labelBuilder`), which is handed that
colour and size in a `GlassTabItemLook`:

```dart
GlassTabItem(
  label: 'Inbox',
  iconBuilder: (BuildContext context, GlassTabItemLook look) => Badge(
    label: const Text('3'),
    child: Icon(Icons.inbox, color: look.color, size: look.iconSize),
  ),
)
```

`label` stays what a screen reader says, whatever the builders draw. The items are built once and again only when
their colour changes, which is when the drop moves onto them or off them.

> [!WARNING]
> If glass cards scroll under the tab bar, wrap it in [`GlassAbove`](../foundations/above.md), or put a bottom
> [scroll edge](../foundations/scroll-edge.md) under it. Otherwise the bar shows the content but not the cards.

> [!TIP]
> [`GlassScaffold`](../components/scaffold.md) places a tab bar as its `bottomBar`: lifted, at the bottom of the safe area,
> with the list padded to end above it.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// An app shell: one page per tab, a floating glass tab bar on top.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const List<GlassTabItem> _tabs = <GlassTabItem>[
    GlassTabItem(icon: Icons.home, label: 'Home'),
    GlassTabItem(icon: Icons.search, label: 'Search'),
    GlassTabItem(icon: Icons.library_music, label: 'Library'),
    GlassTabItem(icon: Icons.person, label: 'Profile'),
  ];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            // Keeps every page alive; the bar floats over whichever is shown.
            child: IndexedStack(
              index: _tab,
              children: <Widget>[
                for (final GlassTabItem tab in _tabs)
                  ListView.builder(
                    // Room at the end so the last row is not under the bar.
                    padding: EdgeInsets.only(bottom: bottom + 96),
                    itemCount: 40,
                    itemBuilder: (BuildContext context, int i) => ListTile(title: Text('${tab.label} ${i + 1}')),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 12,
            child: GlassTabBar(items: _tabs, selectedIndex: _tab, onSelected: (int i) => setState(() => _tab = i)),
          ),
        ],
      ),
    );
  }
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassTabItem>` | **required** | The tabs. At least 2. |
| `selectedIndex` | `int` | **required** | The selected tab. |
| `onSelected` | `ValueChanged<int>?` | **required** | Called with the new tab. Null disables the bar. |
| `activeColor` | `Color` | `Color(0xFF007AFF)` | Icon and label colour of the selected tab, and of the tab under a held drop. |
| `dropZoom` | `double` | `kGlassTabDropZoom` | How much the held drop magnifies the bar. `1` for none; must be above 0. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](../foundations/drop-motion.md). |
| `key` | `Key?` | `null` | |

### GlassTabItem

| Parameter | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | **required** | The tab's name: the text drawn unless `labelBuilder` is given, and what a screen reader says always. |
| `icon` | `IconData?` | `null` | The tab's icon, drawn in the colour the bar resolved. Ignored when `iconBuilder` is given. |
| `iconBuilder` | `GlassTabItemBuilder?` | `null` | Builds the icon instead of `icon`: an SVG, an image, a badge. Sized by you; the bar's own icons are `look.iconSize`. |
| `labelBuilder` | `GlassTabItemBuilder?` | `null` | Builds the label instead of the text of `label`. |

An item needs an `icon` or an `iconBuilder`; it asserts. `GlassTabItemBuilder` is
`Widget Function(BuildContext context, GlassTabItemLook look)`.

### GlassTabItemLook

What the bar resolved for one item, as it draws it.

| Field | Type | Description |
|---|---|---|
| `index` | `int` | Which item. |
| `color` | `Color` | The colour the item is drawn in now: `activeColor` when `highlighted`, otherwise the label colour the bar's glass chose. |
| `iconSize` | `double` | The size the bar draws its own icons at: 26 stacked, 20 side by side. |
| `labelStyle` | `TextStyle` | The label's style, `color` included. |
| `selected` | `bool` | Whether this is `selectedIndex`. |
| `highlighted` | `bool` | Whether this item takes the accent: the selected one at rest, the one under the drop while it is held. |
| `inline` | `bool` | Whether the bar lays icon beside label (a wide bar) rather than icon over label. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassTabDropZoom` | `1.17` | The default `dropZoom`, read off iOS 26. |
| `kGlassTabDropGrow` | `10.5` | How much larger the held drop is than the resting pill, per side, in px. |
