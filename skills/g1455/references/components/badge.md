# Badge

> GlassBadge puts a count, a label or a dot on the corner of an icon or a tab: an opaque red capsule, not glass, as iOS 26 draws one. It costs no surface.

- Live: https://g1455.plugfox.dev/components/badge
- API: [`GlassBadge`](https://pub.dev/documentation/g1455/latest/g1455/GlassBadge-class.html), [`kGlassBadgeRed`](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeRed-constant.html), [`kGlassBadgeHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeHeight-constant.html), [`kGlassBadgeDot`](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeDot-constant.html)
- Source: [`lib/src/surface/glass_badge.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_badge.dart)

`GlassBadge` marks the corner of its child with a count, a short label or a dot, the way iOS 26 marks a tab, an app icon
or a toolbar button. **It is not glass, and that is Apple's call rather than a saving**: a badge has to read at a glance
over any backdrop, and a translucent red would be a different colour over every one. So it is an opaque capsule of
`systemRed` with white text, on the glass and not of it.

## When to use

- An unread count on a [tab](../components/tab-bar.md), a [toolbar](../components/toolbar.md) icon or a [button](../components/button.md).
- A dot for "something new" where the number does not matter.
- **Not** as a glass pill of your own: that would be one more surface, and a red that changes with the backdrop.

## Usage

On a tab, through `iconBuilder`, so the icon keeps the colour the bar gives it:

```dart
GlassTabItem(
  label: 'Mail',
  iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
    count: unread,
    child: Icon(Icons.mail, color: look.color, size: look.iconSize),
  ),
)
```

On a toolbar icon:

```dart
GlassToolbarItem(
  icon: GlassBadge(count: notifications, child: const Icon(Icons.notifications_none)),
  label: 'Notifications',
  onPressed: openNotifications,
)
```

## What it shows

- With `count`, the number, or "99+" past `maxCount`, and **nothing at all at 0**, as an app icon's badge disappears.
- With `label`, that text. A badge takes a count or a label, not both.
- With neither, a dot [kGlassBadgeDot](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeDot-constant.html)
  (10) across.
- `isVisible: false` hides it and leaves the child.
- Its centre sits on the child's top trailing corner; `offset` moves it. Without a child it is the badge alone, for a row
  or a cell to place.

## Colour

[kGlassBadgeRed](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeRed-constant.html) is UIKit's documented
`systemRed` in the light appearance, (255, 59, 48). The dark appearance's is (255, 69, 58); the package has no
appearance of its own, so pass that as `color` where your app is dark. The height,
[kGlassBadgeHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeHeight-constant.html) (18), the dot and
the type size are layout, not readings.

## Cost

None in the glass. A badge takes no slot in the atlas and does not count in the ledger, and a count changing on a glass
bar is a repaint inside the glass, which is no capture. On a [tab bar](../components/tab-bar.md) the count reaches the badge
through the bar's items, so changing it rebuilds the bar, which costs one capture for now.

## Accessibility

A screen reader hears `semanticLabel`, or the count or label as written. Give a dot a `semanticLabel` ("New"), or it says
nothing, since nothing is all it shows.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A mail app's tab bar, the unread count on the Mail tab.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class MailTabs extends StatelessWidget {
  const MailTabs({required this.unread, required this.tab, required this.onTab, super.key});

  final int unread;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: <GlassTabItem>[
      GlassTabItem(
        label: 'Mail',
        iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
          // Nothing at 0; "99+" past 99.
          count: unread,
          semanticLabel: '$unread unread',
          child: Icon(Icons.mail, color: look.color, size: look.iconSize),
        ),
      ),
      const GlassTabItem(icon: Icons.people, label: 'Contacts'),
      GlassTabItem(
        label: 'Settings',
        // A dot: an update waits.
        iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
          semanticLabel: 'Update available',
          child: Icon(Icons.settings, color: look.color, size: look.iconSize),
        ),
      ),
    ],
    selectedIndex: tab,
    onSelected: onTab,
  );
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `count` | `int?` | `null` | The number shown; nothing at 0, "`maxCount`+" past it. Not with `label`. |
| `label` | `String?` | `null` | A short text instead of a number. Not with `count`. |
| `maxCount` | `int` | `99` | The largest number shown as it is. Above 0. |
| `isVisible` | `bool` | `true` | Whether the badge is drawn. The child always is. |
| `color` | `Color` | `kGlassBadgeRed` | The capsule's fill. |
| `textColor` | `Color` | `Color(0xFFFFFFFF)` | The count's or label's colour. |
| `offset` | `Offset` | `Offset.zero` | Moves the badge from the child's top trailing corner. |
| `semanticLabel` | `String?` | `null` | What a screen reader says. Null says the count or label; a dot then says nothing. |
| `child` | `Widget?` | `null` | What the badge marks. Null is the badge alone. |
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassBadgeRed` | `Color(0xFFFF3B30)` | `systemRed` in the light appearance. |
| `kGlassBadgeHeight` | `18` | The height with a count, and the smallest width. Layout, not a reading. |
| `kGlassBadgeDot` | `10` | A dot's diameter. Layout, not a reading. |
