The glass a screen is made of. Each wears the theme's finish unless it names
its own, and picks a label colour that reads over it.

| Widget | What it is |
|---|---|
| [GlassBar](../g1455/GlassBar-class.html) | A capsule for a title, a search field or a row of actions. |
| [GlassButton](../g1455/GlassButton-class.html) | A tappable capsule that brightens while held. |
| [GlassCard](../g1455/GlassCard-class.html) | A panel for grouped content. |
| [GlassSwitch](../g1455/GlassSwitch-class.html), [GlassSlider](../g1455/GlassSlider-class.html) | Controls whose knob turns into a clear drop while held. |
| [GlassSegmentedControl](../g1455/GlassSegmentedControl-class.html) | The selection lifts into a drop that slides between segments. |
| [GlassTabBar](../g1455/GlassTabBar-class.html) | A tab bar whose selection is a drop that can be dragged between tabs. |
| [GlassButtonGroup](../g1455/GlassButtonGroup-class.html) | One capsule of icon buttons ([GlassToolbarItem](../g1455/GlassToolbarItem-class.html)): one surface however many. |
| [GlassTextField](../g1455/GlassTextField-class.html) | A single line of text in a glass capsule. |
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
a travel region of its own: dragging it takes no capture.
