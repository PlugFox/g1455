The glass a screen is made of. Each wears the theme's finish unless it names
its own, and picks a label colour that reads over it.

| Widget | What it is |
|---|---|
| [GlassBar](../g1455/GlassBar-class.html) | A capsule for a title, a search field or a row of actions. |
| [GlassButton](../g1455/GlassButton-class.html) | A tappable capsule that brightens while held. |
| [GlassCard](../g1455/GlassCard-class.html) | A panel for grouped content. |
| [GlassSwitch](../g1455/GlassSwitch-class.html), [GlassSlider](../g1455/GlassSlider-class.html) | Controls whose knob turns into a clear drop while held. A slider with `divisions` lands on stops. |
| [GlassSegmentedControl](../g1455/GlassSegmentedControl-class.html) | The selection lifts into a drop that slides between segments. |
| [GlassTabBar](../g1455/GlassTabBar-class.html) | A tab bar whose selection is a drop that can be dragged between tabs. It collapses to its selected tab on a scroll down under a [GlassTabBarMinimizer](../g1455/GlassTabBarMinimizer-class.html), and carries a `bottomAccessory`. |
| [GlassStepper](../g1455/GlassStepper-class.html) | A minus and a plus in one glass capsule; a held half repeats, and the end at a limit is disabled. One surface; a press is no capture. |
| [GlassPageControl](../g1455/GlassPageControl-class.html) | Page dots on a glass capsule; follows and turns a `PageController`, a tap steps toward its side, a drag scrubs. One surface. |
| [GlassButtonGroup](../g1455/GlassButtonGroup-class.html) | One capsule of icon buttons ([GlassToolbarItem](../g1455/GlassToolbarItem-class.html)): one surface however many. |
| [GlassTextField](../g1455/GlassTextField-class.html) | A single line of text in a glass capsule. |
| [GlassSearchBar](../g1455/GlassSearchBar-class.html) | The search field with a clear button and a Cancel that slides in on focus. One surface; the slide costs a capture a frame for 250 ms (16 captures; 1 with reduced motion). |
| [GlassBadge](../g1455/GlassBadge-class.html) | A count or a dot on an icon's corner, as an opaque red capsule. Not glass, as Apple's isn't; costs no surface. |
| [GlassScrollEdge](../g1455/GlassScrollEdge-class.html) | iOS's soft edge under a bar, where content scrolls away. |
| [GlassScaffold](../g1455/GlassScaffold-class.html) | A whole screen: host, top bar, scroll edge, bottom bar and floating action. |

## A bar of actions

```dart
GlassBar(
  child: Row(
    children: <Widget>[
      const Expanded(child: Text('Inbox')),
      GlassButton(onPressed: compose, child: const Icon(Icons.edit)),
    ],
  ),
)
```

Inside a bar, plain icons are cheaper than [GlassButton](../g1455/GlassButton-class.html)s, which are glass on
glass; a row of actions is cheapest as a [GlassButtonGroup](../g1455/GlassButtonGroup-class.html).

## Controls

```dart
GlassCard(
  child: Column(
    children: <Widget>[
      GlassSwitch(value: on, onChanged: (bool v) => setState(() => on = v)),
      GlassSlider(value: level, onChanged: (double v) => setState(() => level = v)),
    ],
  ),
)
```

The drop of a switch, a slider, a segmented control and a tab bar moves inside
a travel region of its own: dragging it takes no capture. The button, switch,
slider, segmented control and a toolbar's cells take the keyboard's focus, and
the switch, slider and segmented control claim a drag from touch-down inside a
horizontal `PageView`.

## A stepper with its value

```dart
Row(
  children: <Widget>[
    Expanded(child: Text('Copies: $copies')),
    GlassStepper(
      value: copies.toDouble(),
      min: 1,
      max: 10,
      semanticLabel: 'Copies',
      onChanged: (double v) => setState(() => copies = v.round()),
    ),
  ],
)
```

## A tab bar that collapses on scroll

```dart
GlassScaffold(
  // The scaffold is a GlassTabBarMinimizer: the body's scrolls reach the bar.
  bottomBar: GlassTabBar(
    items: tabs,
    selectedIndex: tab,
    onSelected: (int i) => setState(() => tab = i),
    minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
  ),
  body: ListView.builder(itemCount: 50, itemBuilder: buildRow),
)
```
