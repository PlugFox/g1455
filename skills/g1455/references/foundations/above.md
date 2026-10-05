# Glass on glass

> Glass inside other glass refracts it automatically. A bar floating over sibling glass, such as glass cards, needs GlassAbove to show them.

- Live: https://g1455.plugfox.dev/foundations/above
- API: [`GlassAbove`](https://pub.dev/documentation/g1455/latest/g1455/GlassAbove-class.html), [`kGlassModalLift`](https://pub.dev/documentation/g1455/latest/g1455/kGlassModalLift-constant.html)
- Source: [`lib/src/surface/glass_above.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_above.dart)

Glass can stand on other glass in two ways, and the package treats them differently.

- **Nested:** glass written *inside* other glass refracts it automatically. A `GlassButton` in a `GlassBar`, or the drop of a tab bar, shows the bar under it. Nothing to declare.
- **Siblings:** glass *beside* other glass in the tree doesn't see it. A bar floating over a list of `GlassCard`s is the cards' sibling, so on its own it shows the page with **the cards cut out**. Wrap the bar in `GlassAbove` and it refracts them.

The demo shows exactly that. Switch `GlassAbove` off and watch the bar as cards scroll under it.

## When to use

- Bars, tab bars, floating buttons and custom overlays over a page that has glass of its own.
- **Already done for you** by [`GlassScrollEdge`](../foundations/scroll-edge.md) (and the bar in its `child`), [dialogs](../components/alert.md), [sheets](../components/sheet.md), [menus](../components/menu.md) and [popovers](../components/popover.md).
- **Not needed** over plain content. It does no harm there and costs nothing.

## Usage

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: cardList), // a list of GlassCards
    const Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: GlassAbove(child: GlassBar(child: Text('Inbox'))),
      ),
    ),
  ],
);
```

## Levels

Every glass surface sits on a *level*: the number of glass surfaces it is written inside, plus the lifts above it. A level's capture draws all the glass of lower levels, which is how the bar gets to see the cards.

- `lift: 1` (the default) raises a bar above the page's glass.
- [`kGlassModalLift`](https://pub.dev/documentation/g1455/latest/g1455/kGlassModalLift-constant.html) (`2`) is for a modal-like layer that must also stand above bars that are themselves lifted. The package's own modals use it.

## Performance

Each occupied extra level costs **one more capture** on frames that re-capture. A lifted bar over plain content stays on level 0 and costs nothing extra; the levels that count are the ones with glass under them.

## Gotchas

- **Levels are a declaration, not paint order.** Glass *beside* a lifted subtree but painted on top of it still appears in its capture. A bar left unlifted next to a lifted scroll edge shows up blurred inside the edge, so lift such bars together (put the bar in `GlassScrollEdge.child`).
- Each lift is another capture level, so don't lift what has no glass under it "just in case" deep in a list.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Glass cards scrolling under a glass bar. Assumes a GlassHost above.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.subjects});

  final List<String> subjects;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 80, 16, safe.bottom + 16),
            itemCount: subjects.length,
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(child: Text(subjects[i])),
            ),
          ),
        ),
        Positioned(
          top: safe.top + 8,
          left: 16,
          right: 16,
          // The bar is a sibling of the cards, not their child: without
          // GlassAbove it would show the page with the cards cut out.
          child: GlassAbove(
            child: GlassBar(
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  // A button inside the bar is glass *on* the bar already:
                  // it refracts the bar with no GlassAbove of its own.
                  GlassButton(
                    onPressed: () {},
                    semanticLabel: 'Compose',
                    padding: EdgeInsets.zero,
                    child: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

## API

`GlassAbove`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `lift` | `int` | `1` | How many levels the glass below is raised. Must be > 0. |
| `child` | `Widget?` | `null` | The glass that stands on its neighbours. |

`GlassAbove` has no layout or paint of its own. It is a marker the host reads.

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassModalLift` | `2` | The lift of a modal layer (menu, dialog, sheet): above the page's glass and above bars lifted over it. |
