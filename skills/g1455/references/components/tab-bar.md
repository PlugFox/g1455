# Tab bar

> GlassTabBar is the floating iOS 26 tab bar. The selected tab lifts into a glass drop you can drag from tab to tab, and the bar can collapse to that tab on a scroll down.

- Live: https://g1455.plugfox.dev/components/tab-bar
- API: [`GlassTabBar`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabBar-class.html), [`GlassTabItem`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItem-class.html), [`GlassTabItemLook`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItemLook-class.html), [`GlassTabItemBuilder`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabItemBuilder.html), [`GlassTabBarMinimizeBehavior`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabBarMinimizeBehavior.html), [`GlassTabBarMinimizer`](https://pub.dev/documentation/g1455/latest/g1455/GlassTabBarMinimizer-class.html), [`kGlassTabDropZoom`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabDropZoom-constant.html), [`kGlassTabDropGrow`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabDropGrow-constant.html), [`kGlassTabMinimizeScroll`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabMinimizeScroll-constant.html), [`kGlassTabAccessoryHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabAccessoryHeight-constant.html)
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

## Collapsing on scroll

iOS 26's tab bar shrinks to its selected tab while the content scrolls down, and comes back when it scrolls up. With
`minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown`, the bar collapses to a circle of its own height at its
start edge, the selected tab's icon in it, once the content has gone
[`kGlassTabMinimizeScroll`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabMinimizeScroll-constant.html)
(12 px) down, and expands once it has come as far back up or reached its top. A tap on the circle expands it and
selects nothing.

A scroll reports only upward, and the bar is not inside the scroll view, so both go under one
`GlassTabBarMinimizer`. [`GlassScaffold`](../components/scaffold.md) is one already; a screen built by hand puts one above
its body and its bar:

```dart
GlassTabBarMinimizer(
  child: Stack(
    children: <Widget>[
      ListView.builder(itemCount: 50, itemBuilder: buildRow),
      Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: GlassTabBar(
          items: tabs,
          selectedIndex: _tab,
          onSelected: (int i) => setState(() => _tab = i),
          minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
        ),
      ),
    ],
  ),
)
```

Only the nearest vertical scroll view counts, not one nested in it, nor a horizontal one.
`GlassTabBarMinimizer.maybeOf(context)` is the `ValueNotifier<bool>` it holds: set it `false` to expand the bar when the
app changes the page.

- **Cost.** The circle is the bar shrunk inside the travel region the bar already grows in, so the collapse is no
  capture: no record over 60 frames of it, against 60 without the declaration. The bar's box keeps its height, so the
  body is not laid out again. The scroll that set it off captures on every frame anyway, because the content under the
  bar moves.
- Collapsed, a screen reader hears one button named for the selected tab. Under reduced motion it is not animated.
- The circle's size and the spring are layout taste: Apple's collapse was not measured.

## An accessory

`bottomAccessory` is UIKit's `tabViewBottomAccessory`: a widget on a glass capsule
[`kGlassTabAccessoryHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabAccessoryHeight-constant.html)
(48) tall above the bar, a now-playing row or a status, drawn in the bar's label colour. When the bar collapses it moves
down beside the circle, inside a travel region of its own, so that is no capture either. The bar's box is taller by the
accessory and the gap, and stays that height.

## Custom icons and badges

An `IconData` is drawn by the bar in the right colour: the accent when selected, otherwise the label colour its glass
chose. For anything else, an SVG, an image, a [badge](../components/badge.md), give `iconBuilder` (or `labelBuilder`), which
is handed that colour and size in a `GlassTabItemLook`:

```dart
GlassTabItem(
  label: 'Inbox',
  iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
    count: unread,
    child: Icon(Icons.inbox, color: look.color, size: look.iconSize),
  ),
)
```

`label` stays what a screen reader says, whatever the builders draw. The items are built once and again only when
their colour changes, which is when the drop moves onto them or off them; on a bar that can collapse, the selected
item's icon is built once more, for the circle.

> [!WARNING]
> If glass cards scroll under the tab bar, wrap it in [`GlassAbove`](../foundations/above.md), or put a bottom
> [scroll edge](../foundations/scroll-edge.md) under it. Otherwise the bar shows the content but not the cards.

> [!TIP]
> [`GlassScaffold`](../components/scaffold.md) places a tab bar as its `bottomBar`: lifted, at the bottom of the safe area,
> with the list padded to end above it, and its scrolls collapse a bar that asks to.

> [!NOTE]
> A bare `setState` that rebuilds the bar costs one capture, even when nothing it draws changed. A known cost, not yet
> traced: rebuild the bar when its selection or its items change, not with every change of the screen around it.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// An app shell: one page per tab, a floating glass tab bar on top that
/// collapses while a page scrolls down.
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
      // Above the pages and the bar both: a page's scrolls reach it, and the
      // bar reads it.
      body: GlassTabBarMinimizer(
        child: Stack(
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
              child: GlassTabBar(
                items: _tabs,
                selectedIndex: _tab,
                onSelected: (int i) => setState(() => _tab = i),
                minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
              ),
            ),
          ],
        ),
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
| `minimizeBehavior` | `GlassTabBarMinimizeBehavior` | `.never` | `.onScrollDown` collapses the bar to its selected tab while the content scrolls down, under a `GlassTabBarMinimizer`. |
| `bottomAccessory` | `Widget?` | `null` | A widget on a glass capsule above the bar, which moves beside the collapsed circle. |
| `key` | `Key?` | `null` | |

### GlassTabBarMinimizer

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree whose vertical scrolls collapse the bars in it: the scroll view and the bar both. |

`static ValueNotifier<bool>? maybeOf(BuildContext context)`: whether the bars below are collapsed, or null with no
minimizer above. Writable: set it `false` to expand them.

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
| `kGlassTabMinimizeScroll` | `12` | How far the content scrolls one way, in px, before the bar collapses or expands. Layout taste. |
| `kGlassTabAccessoryHeight` | `48` | The accessory's glass height. Layout taste. |
