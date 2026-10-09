import '../catalog.dart';

/// Bars, buttons, cards and the controls whose knob becomes a drop.
const List<Entry> kComponentEntriesA = <Entry>[
  Entry(
    section: Section.components,
    id: 'bar',
    title: 'Bar',
    icon: 'web_asset',
    summary:
        'GlassBar is a floating glass capsule for navigation: a title bar, a bottom bar or a now-playing pill, '
        'with black or white labels picked for legibility.',
    api: <String>['GlassBar', 'kGlassCapsule'],
    source: 'lib/src/surface/glass_components.dart',
    guide: r'''
`GlassBar` is one glass surface with padding around its child. It is the navigation layer of an
iOS 26 style screen: the top bar with a back button and a title, a floating bottom bar, a
"now playing" pill over a feed.

The bar picks the text and icon colour of everything inside it, black or white, whichever reads
best on the glass over what is behind it. Its items are ordinary widgets, not glass, so a bar
full of icons and text still costs one surface.

## When to use

- Navigation chrome that floats over content: titles, back and search actions, a mini player.
- A small pill that names the current screen or state.
- **Not** for content panels: use a [Card](/components/card) instead (same body, a corner instead
  of a capsule).
- **Not** as a row of glass buttons. Every [`GlassButton`](/components/button) inside a bar is one more
  surface. Use plain icons, or a [toolbar](/components/toolbar) (`GlassButtonGroup`), which draws
  many actions as one surface.

## Usage

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: content), // what the glass refracts
    const Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GlassBar(child: Center(child: Text('Library'))),
    ),
  ],
)
```

The bar sizes itself to its child. To stretch it across the screen, give it a width with
`Positioned(left:, right:)`, a `SizedBox` or an `Expanded`.

## Layout

- `borderRadius` defaults to [`kGlassCapsule`](https://pub.dev/documentation/g1455/latest/g1455/kGlassCapsule-constant.html),
  a full pill whatever the height. Pass a `BorderRadius` for a rounded rectangle.
- `padding` defaults to 16 across and 8 down. Icon buttons usually want less, so their 44 px tap
  targets reach the edge of the glass.
- No `SafeArea` is applied for you. Add `MediaQuery.paddingOf(context)` to your offsets.

## Labels

Text and icons inside the bar get the label colour through `DefaultTextStyle` and `IconTheme`.
Widgets that hard-code their own colour (for example Material's `IconButton`, which uses the colour
scheme) ignore it, so pass `IconTheme.of(context).color` to them, or use plain `Icon`s in a
`GestureDetector`. The choice of colour is only as good as what the host knows about the backdrop:
see [Legibility](/foundations/legibility).

> [!WARNING]
> A bar is not refracted by glass that is its sibling. If glass cards scroll under a bar, wrap the bar
> in [`GlassAbove`](/foundations/above), or use a [scroll edge](/foundations/scroll-edge) instead.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A library screen: a top bar and a "now playing" bar over a list.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 72, 16, safe.bottom + 96),
            itemCount: 30,
            itemBuilder: (BuildContext context, int i) =>
                ListTile(leading: const Icon(Icons.album), title: Text('Album ${i + 1}')),
          ),
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.arrow_back_ios_new),
                  Expanded(child: Text('Library', textAlign: TextAlign.center)),
                  Icon(Icons.search),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safe.bottom + 16,
            child: const GlassBar(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.music_note),
                  SizedBox(width: 12),
                  Expanded(child: Text('Heat Waves', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Icon(Icons.pause),
                  SizedBox(width: 16),
                  Icon(Icons.fast_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The bar's items. They are content, not glass, and get the bar's label colour. |
| `borderRadius` | `BorderRadius` | `kGlassCapsule` | Corner radii. The default is a pill at any height. |
| `padding` | `EdgeInsets` | `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` | Space between the glass edge and the items. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's (normally the host's). |
| `key` | `Key?` | `null` | |
''',
  ),
  Entry(
    section: Section.components,
    id: 'button',
    title: 'Button',
    icon: 'smart_button',
    summary:
        'GlassButton is a tappable glass capsule that brightens and swells while held, with a 44 × 44 minimum tap '
        'target, keyboard focus and dimmed labels when disabled.',
    api: <String>[
      'GlassButton',
      'GlassPress',
      'kGlassMinTapTarget',
      'kGlassDisabledDarkLabel',
      'kGlassDisabledLightLabel',
      'kGlassFocusRingColor',
    ],
    source: 'lib/src/surface/glass_components.dart',
    guide: r'''
`GlassButton` is a glass capsule that takes a tap. While a finger is on it, the whole shape
brightens by the finish's rim colour, so the material itself changes rather than a highlight being
laid on top, and the glass swells a little and leans toward a finger that drags. The label (text,
icon, or both) is centred and gets a legible colour, like a [Bar](/components/bar).

The whole capsule is the tap target, and it is never smaller than
[`kGlassMinTapTarget`](https://pub.dev/documentation/g1455/latest/g1455/kGlassMinTapTarget-constant.html)
(44 × 44, Apple's minimum).

## When to use

- A standalone action on glass: a floating "add" button, the choices in a [sheet](/components/sheet),
  the trigger of a [menu](/components/menu) or a [popover](/components/popover).
- A primary action on a [Card](/components/card).
- **Not** for a row of actions in a toolbar: each button is a surface of its own. A
  [toolbar](/components/toolbar) (`GlassButtonGroup`) draws all of them as one.
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

## The press

Held, the glass grows by 12 px on its longest side, the shorter side by the same factor, and leans up to 3 px toward a
finger that drags, stretched a little along the drag. Let go, and it springs back. That is
[`GlassPress`](https://pub.dev/documentation/g1455/latest/g1455/GlassPress-class.html), read from the theme unless the
button names its own:

```dart
// One button that keeps its box, and a gentler swell for the rest of the app.
GlassButton(press: GlassPress.none, onPressed: save, child: const Text('Save'))

GlassHost(press: const GlassPress(grow: 8), child: navigator!)
```

- **A feel, not a measurement.** iOS 26's interactive glass does this, and Apple's press has not been measured here.
  The shape of the law, a fixed growth rather than a ratio, comes from another package; its 17 px would be 1.39× a
  44 px button, more than any held drop the package has read, so the default is 12.
- **What it costs:** two captures a press, one as the region the glass grows in is declared at touch-down and one as it
  goes when the spring settles, and none while it moves. Nothing at rest: declared always, the region took a 44 px
  button's slot from 3,600 to 7,056 px².
- Off under reduced motion, on a disabled button, and with `GlassPress.none`, which builds no region at all.
- A [toolbar](/components/toolbar)'s cells brighten but do not swell: the group is one surface.

## Keyboard

The button takes the focus from the keyboard (`focusNode`, `autofocus`), and Space or Enter presses it. The focus ring,
[`kGlassFocusRingColor`](https://pub.dev/documentation/g1455/latest/g1455/kGlassFocusRingColor-constant.html) 3 px wide
and 2 px outside the glass, concentric with its corners, is drawn from inside the glass's own subtree, which no capture
sees: focusing a button costs nothing.

## Gotchas

- Don't wrap a button in `Opacity`, `ColorFilter` or `ImageFilter`. The press highlight is added
  onto the glass, and those widgets make it add onto transparency instead, which looks wrong.
  A `RepaintBoundary` is fine.
- `pressedOverlay: Color(0x00000000)` turns the highlight off. Any other colour replaces the rim's. The swell is
  `press`, a separate thing.
- A button inside a bar or a card is glass on glass. It works, but it is one more surface and one
  more capture level. See [Performance](/foundations/performance).
''',
    code: r'''
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
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The label or icon, centred, in a legible colour. |
| `onPressed` | `VoidCallback?` | `null` | Called on a tap. Null disables the button. |
| `borderRadius` | `BorderRadius` | `kGlassCapsule` | Corner radii. |
| `padding` | `EdgeInsets` | `EdgeInsets.symmetric(horizontal: 20, vertical: 10)` | Space between the glass and the label. |
| `minSize` | `Size` | `kGlassMinTapTarget` | The smallest the button may be. |
| `pressedOverlay` | `Color?` | `null` | Added over the whole shape while held. Null takes the finish's `rim`; `Color(0x00000000)` disables it. |
| `press` | `GlassPress?` | `null` | How the glass swells and leans while held. Null takes the theme's; `GlassPress.none` keeps the box. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's. |
| `semanticLabel` | `String?` | `null` | What a screen reader says instead of the child. Set it on icon-only buttons. |
| `focusNode` | `FocusNode?` | `null` | The button's focus. Null makes one the button owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the button is built. |
| `key` | `Key?` | `null` | |

## GlassPress

| Parameter | Type | Default | Description |
|---|---|---|---|
| `grow` | `double` | `12` | How much longer the longest side is while held, in px; the shorter side grows by the same factor. |
| `maxStretch` | `double` | `0.05` | The most the glass stretches along a drag, as a fraction; the area is kept. 0 to 0.25. |
| `maxPull` | `double` | `3` | The most the glass's centre moves toward a dragging finger, in px. |
| `pullReach` | `double` | `12` | How far the finger drags, in px, for the lean and the stretch to reach three quarters of their most. |
| `stiffness` | `double` | `500` | The spring, at unit mass. |
| `damping` | `double` | `26` | The spring's damping, at unit mass. |

`GlassPress.none` responds to nothing. `rect(Size rest, double press, Offset finger)` and `margin(Size rest)` are the
geometry, pure, for a control of your own.

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassMinTapTarget` | `Size(44, 44)` | Apple's minimum tap target; the default `minSize`. |
| `kGlassDisabledDarkLabel` | `Color(0x4D3C3C43)` | Disabled label where the enabled one is black. |
| `kGlassDisabledLightLabel` | `Color(0x4DEBEBF5)` | Disabled label where the enabled one is white. |
| `kGlassFocusRingColor` | `Color(0xFF0A84FF)` | The keyboard's focus ring, on every control that takes the focus. |
| `kGlassFocusRingWidth` | `3` | The ring's stroke, in px. |
| `kGlassFocusRingGap` | `2` | The gap between the control's edge and the ring, in px. |
''',
  ),
  Entry(
    section: Section.components,
    id: 'card',
    title: 'Card',
    icon: 'crop_7_5',
    summary:
        'GlassCard is a rounded glass panel for a few floating groups of content, such as widgets on a '
        'wallpaper, with a legible label colour for its children.',
    api: <String>['GlassCard'],
    source: 'lib/src/surface/glass_components.dart',
    guide: r'''
`GlassCard` is the same panel as a [Bar](/components/bar) with a 24 px corner instead of a capsule
and 16 px of padding all round. Its children get a legible label colour, black or white, picked
against the glass over what is behind it.

## When to use

- A few floating panels over a wallpaper or a photo: weather and calendar widgets, a now-playing
  card, a settings group on a lock-screen style page.
- A panel that holds controls: [switches](/components/switch), [sliders](/components/slider), a
  [button](/components/button).
- **Not** for every item of a list or a feed. Apple keeps Liquid Glass in the navigation and
  controls layers, out of the content layer. Each card is one more surface, and the cost grows
  faster than the number of surfaces. A feed of glass cards is the most expensive thing you can
  build with this package. If you really need it, check the count with
  [`GlassLedger`](/foundations/performance).
- **Not** over a plain, flat background. Glass over one flat colour looks like a grey box. Use an
  ordinary `Card` or `Container` there.

## Usage

```dart
GlassCard(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text('Battery', style: TextStyle(fontWeight: FontWeight.w600)),
      const Text('82% - about 9 hours left'),
      GlassButton(onPressed: () {}, child: const Text('Details')),
    ],
  ),
)
```

A card sizes itself to its child, like a `Container` with padding. Give it a width with a
`SizedBox`, `ConstrainedBox` or the layout around it.

## Choosing a finish

The card uses the host's finish unless you pass one. Over a busy photo, `GlassFinish.frosted`
blurs the most and is easiest to read; `GlassFinish.clear` shows the most of the photo and is the
hardest to read on. Try them in the demo above, and see [Finishes](/foundations/finishes).

## Gotchas

- A bar or tab bar floating above glass cards does not show those cards unless it is wrapped in
  [`GlassAbove`](/foundations/above). Controls written *inside* a card refract it automatically.
- Secondary text in a card: derive it from `DefaultTextStyle.of(context).style.color` (for example
  at 70% alpha) rather than a fixed grey, so it follows the label colour the card chose.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A weather widget over a wallpaper.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  static const List<(String, IconData, int)> _hours = <(String, IconData, int)>[
    ('Now', Icons.wb_sunny, 21),
    ('14', Icons.wb_sunny, 23),
    ('15', Icons.wb_cloudy, 24),
    ('16', Icons.water_drop, 19),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      padding: const EdgeInsets.all(20),
      child: Builder(
        // Under the card, so it reads the label colour the card picked.
        builder: (BuildContext context) {
          final Color? ink = DefaultTextStyle.of(context).style.color;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Lisbon', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Text('21°', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300)),
              Text('Mostly sunny · H:24° L:16°', style: TextStyle(color: ink?.withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final (String hour, IconData icon, int temp) in _hours)
                    Column(children: <Widget>[Text(hour), Icon(icon, size: 20), Text('$temp°')]),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The content. Gets the card's label colour. |
| `borderRadius` | `BorderRadius` | `BorderRadius.all(Radius.circular(24))` | Corner radii. |
| `padding` | `EdgeInsets` | `EdgeInsets.all(16)` | Space between the glass and the content. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's. |
| `key` | `Key?` | `null` | |
''',
  ),
  Entry(
    section: Section.components,
    id: 'switch',
    title: 'Switch',
    icon: 'toggle_on',
    summary:
        'GlassSwitch is the iOS 26 on/off switch: a white knob that lifts into a clear glass drop while you '
        'press or drag it, and costs nothing extra at rest.',
    api: <String>[
      'GlassSwitch',
      'kGlassSwitchSize',
      'kGlassDropScale',
      'kGlassSwitchDropWiden',
      'kGlassDropOptics',
      'kGlassDropDuration',
      'kGlassDisabledOpacity',
    ],
    source: 'lib/src/surface/glass_controls.dart',
    guide: r'''
`GlassSwitch` is an on/off switch drawn the way iOS 26 draws it: a 64 × 28 track and a white knob.
When you press the knob, it lifts into a clear glass drop about 1.57 times its size, which bends
what is under it. Drag it to the other side, or just tap; let go and the value commits.

At rest the knob and the track are ordinary paint, not glass. The drop exists only while the switch
is held, so a page with twenty switches costs the glass nothing until someone touches one.

## When to use

- Boolean settings: Wi-Fi on or off, notifications, a feature flag in a settings group.
- Over imagery or on a [Card](/components/card), where an ordinary switch would look flat.
- **Not** for choosing between more than two options: use a
  [segmented control](/components/segmented-control).
- **Not** for an action that happens right away and can't be undone. That is a
  [button](/components/button).

## Usage

The switch is controlled: you hold the value and pass it back in.

```dart
bool _wifi = true;

GlassSwitch(
  value: _wifi,
  onChanged: (bool v) => setState(() => _wifi = v),
)
```

Pass `onChanged: null` to disable it. A disabled switch is drawn at
[`kGlassDisabledOpacity`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledOpacity-constant.html)
(50%).

## Accessibility

The switch reports itself as a toggle with its state. It has no label of its own. Either pass a
`semanticLabel`, or put it in a row with a `Text` and wrap the row in `MergeSemantics`, so a screen
reader says "Wi-Fi, switch, on" as one item:

```dart
MergeSemantics(
  child: Row(
    children: <Widget>[
      const Expanded(child: Text('Wi-Fi')),
      GlassSwitch(value: wifi, onChanged: onWifi),
    ],
  ),
)
```

The switch is never smaller than 44 px tall, so it stays easy to hit.

## Keyboard, right to left, and a PageView

- The switch takes the focus from the keyboard (`focusNode`, `autofocus`), and Space or Enter flips it. The ring is
  drawn around the track behind a boundary of its own; on a switch that sits under other glass, showing or hiding it is
  one capture.
- Under a right-to-left `Directionality` it is mirrored: on is at the left.
- The knob is dragged from touch-down, and inside a horizontal `PageView` the switch claims the drag, so the page does
  not turn under it. In a vertical list a swipe that starts on the switch still scrolls the list.

## The drop

- `dropScale` (default [`kGlassDropScale`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropScale-constant.html),
  1.57) is how much bigger the held drop is than the knob. It must be at least 1.
- `dropWiden` (default `kGlassSwitchDropWiden`, 5 px) makes the drop show a little more of what is
  around it, which looks slightly zoomed out, as on iOS. 0 turns that off.
- The drop's refraction is `kGlassDropOptics`, and it grows in over `kGlassDropDuration` (180 ms).

> [!NOTE]
> The drop needs a [`GlassHost`](/foundations/host) above it to be glass. Without one the switch still
> works, but the held knob is not drawn as glass.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A settings group on a glass card.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class ConnectivitySettings extends StatefulWidget {
  const ConnectivitySettings({super.key});

  @override
  State<ConnectivitySettings> createState() => _ConnectivitySettingsState();
}

class _ConnectivitySettingsState extends State<ConnectivitySettings> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _airplane = false;

  Widget _row(IconData icon, String label, bool value, ValueChanged<bool>? onChanged, {Color? color}) => MergeSemantics(
    // One item for a screen reader: "Wi-Fi, switch, on".
    child: SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          GlassSwitch(value: value, onChanged: onChanged, activeColor: color ?? const Color(0xFF34C759)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _row(
          Icons.flight,
          'Airplane mode',
          _airplane,
          (bool v) => setState(() => _airplane = v),
          color: const Color(0xFFFF9F0A),
        ),
        // While airplane mode is on, the radios can't be changed: onChanged null disables them.
        _row(Icons.wifi, 'Wi-Fi', _wifi, _airplane ? null : (bool v) => setState(() => _wifi = v)),
        _row(
          Icons.bluetooth,
          'Bluetooth',
          _bluetooth,
          _airplane ? null : (bool v) => setState(() => _bluetooth = v),
          color: const Color(0xFF0A84FF),
        ),
      ],
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `bool` | **required** | Whether the switch is on. |
| `onChanged` | `ValueChanged<bool>?` | **required** | Called with the new value. Null disables the switch (drawn at 50% opacity). |
| `activeColor` | `Color` | `Color(0xFF34C759)` | Track colour when on (iOS green). |
| `trackColor` | `Color` | `Color(0x29787880)` | Track colour when off. |
| `dropScale` | `double` | `kGlassDropScale` | Size of the held drop relative to the knob. At least 1. |
| `dropWiden` | `double` | `kGlassSwitchDropWiden` | How many px of the surroundings the drop pulls in (a slight zoom-out). 0 for none. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](/foundations/drop-motion). |
| `semanticLabel` | `String?` | `null` | Screen-reader label. Or wrap the row in `MergeSemantics` with a `Text`. |
| `focusNode` | `FocusNode?` | `null` | The switch's focus. Null makes one the switch owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the switch is built. |
| `key` | `Key?` | `null` | |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSwitchSize` | `Size(64, 28)` | The track. The widget is at least 44 px tall. |
| `kGlassDropScale` | `1.57` | Held drop size relative to the knob (switch and slider). |
| `kGlassSwitchDropWiden` | `5` | The switch's default `dropWiden`, in px. |
| `kGlassDropOptics` | `GlassOptics(thickness: 10, strength: -4.1)` | The drop's refraction. |
| `kGlassDropDuration` | `Duration(milliseconds: 180)` | How long the drop takes to grow in and out. |
| `kGlassDisabledOpacity` | `0.5` | Opacity of a disabled switch or slider. |
''',
  ),
  Entry(
    section: Section.components,
    id: 'slider',
    title: 'Slider',
    icon: 'tune',
    summary:
        'GlassSlider is a 0 to 1 slider, continuous or in steps, whose knob turns into a clear glass drop while you '
        'drag it, for volume, brightness or a scrubber.',
    api: <String>['GlassSlider', 'SliderGeometry', 'kGlassDropScale', 'kGlassDisabledOpacity'],
    source: 'lib/src/surface/glass_controls.dart',
    guide: r'''
`GlassSlider` picks a value between 0 and 1. It is 44 px tall and as wide as its parent lets it be.
At rest the knob is a white capsule on a thin track; while you press or drag it, the knob lifts into a
clear glass drop, like the [switch](/components/switch)'s.

Tapping anywhere on the track jumps the value there. Screen readers can step it up and down.

## When to use

- Continuous values: volume, brightness, a playback scrubber, a blur radius.
- A value in steps, with `divisions`: a rating out of five, a zoom in quarters.
- **Not** for a handful of named options. That is a [segmented control](/components/segmented-control). A small whole
  number changed one at a time is a [stepper](/components/stepper).
- **Not** for values you need to type exactly. Pair it with a readout, or use a text field.

## Usage

The slider is controlled. It needs a bounded width, so in a `Row` put it in an `Expanded`:

```dart
Row(
  children: <Widget>[
    const Icon(Icons.volume_down),
    Expanded(
      child: GlassSlider(
        value: _volume,
        onChanged: (double v) => setState(() => _volume = v),
        onChangeEnd: (double v) => save(v),
        semanticLabel: 'Volume',
      ),
    ),
    const Icon(Icons.volume_up),
  ],
)
```

`onChanged` fires on every frame of a drag. Use `onChangeStart` / `onChangeEnd` for work that should
happen once, such as saving. `onChanged: null` disables the slider (50% opacity).

## Steps

`divisions` snaps the value to `divisions + 1` stops, as Material's `Slider` does. A drag, a tap, a key and a screen
reader all land on a stop, and `onChanged` is called only when the stop changes, not on every frame of a drag:

```dart
GlassSlider(
  value: _rating / 5,
  divisions: 5, // 0, 0.2, ... 1
  semanticLabel: 'Rating',
  onChanged: (double v) => setState(() => _rating = (v * 5).round()),
)
```

Rounding the value yourself in `onChanged` instead leaves the knob between the stops and the callback told every frame.

## Keyboard, right to left, and a PageView

- A focused slider steps by `semanticStep`, or by one division, with the arrow keys. The focus ring is drawn around
  the knob, inside the drop's glass, so focusing it costs nothing.
- Under a right-to-left `Directionality` it is mirrored: 0 is at the right, the fill grows leftward, and the left
  arrow increases.
- The knob is dragged from touch-down, and inside a horizontal `PageView` the slider claims the drag, so the page does
  not turn under it. In a vertical list a swipe that starts on the slider still scrolls the list.
## Accessibility

Give every slider a `semanticLabel` ("Volume", "Brightness"). `semanticStep` (default 0.1) is how far
one increase or decrease moves it; 0.05 gives a screen reader 20 steps. With `divisions` the step is one division.

## Performance

The fill of the track ends under the drop and follows it, so every frame of a drag changes what is
under the glass, and the host captures again each frame. That is expected and is the price of a
slider over glass. At rest it costs nothing.

## Lining things up with the fill

`SliderGeometry.fillEnd(value, width)` returns the x position where the fill ends on a slider of
that width. Use it to place a tick, a label or a buffered-range bar exactly under the knob's centre. Pass
`textDirection: TextDirection.rtl` for a mirrored slider, whose fill ends that far from the right.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Volume and brightness on a glass card, with a readout.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class DisplayControls extends StatefulWidget {
  const DisplayControls({super.key});

  @override
  State<DisplayControls> createState() => _DisplayControlsState();
}

class _DisplayControlsState extends State<DisplayControls> {
  double _volume = 0.6;
  double _brightness = 0.8;

  Widget _slider(String label, IconData icon, double value, ValueChanged<double> onChanged, Color color) => Row(
    children: <Widget>[
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: GlassSlider(
          value: value,
          onChanged: onChanged,
          onChangeEnd: (double v) => debugPrint('$label saved: $v'),
          activeColor: color,
          semanticLabel: label,
          semanticStep: 0.05,
        ),
      ),
      SizedBox(width: 44, child: Text('${(value * 100).round()}%', textAlign: TextAlign.end)),
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _slider(
            'Volume',
            Icons.volume_up,
            _volume,
            (double v) => setState(() => _volume = v),
            const Color(0xFF0A84FF),
          ),
          _slider(
            'Brightness',
            Icons.light_mode,
            _brightness,
            (double v) => setState(() => _brightness = v),
            const Color(0xFFFFD60A),
          ),
        ],
      ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `double` | **required** | The value, from 0 to 1 (clamped). |
| `onChanged` | `ValueChanged<double>?` | **required** | Called while dragging. Null disables the slider (50% opacity). |
| `onChangeStart` | `ValueChanged<double>?` | `null` | A drag or tap began. |
| `onChangeEnd` | `ValueChanged<double>?` | `null` | A drag or tap ended. |
| `activeColor` | `Color` | `Color(0xFF0A84FF)` | The filled part of the track. |
| `trackColor` | `Color` | `Color(0x29787880)` | The rest of the track. |
| `dropScale` | `double` | `kGlassDropScale` | Size of the held drop relative to the knob. At least 1. |
| `dropWiden` | `double` | `0` | How many px of the surroundings the drop pulls in. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](/foundations/drop-motion). |
| `semanticLabel` | `String?` | `null` | Screen-reader label. |
| `semanticStep` | `double` | `0.1` | How far one accessibility increase or decrease, or an arrow key, moves the value. Between 0 (exclusive) and 1. Ignored with `divisions`. |
| `divisions` | `int?` | `null` | How many equal steps the value snaps to, or null for a continuous slider. Above 0. |
| `focusNode` | `FocusNode?` | `null` | The slider's focus. Null makes one the slider owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the slider is built. |
| `key` | `Key?` | `null` | |

## Helpers

| Name | Description |
|---|---|
| `SliderGeometry.fillEnd(double value, double width, {TextDirection textDirection = TextDirection.ltr})` | The x position, in px from the slider's left edge, where the fill ends for `value` on a slider `width` wide; mirrored under `TextDirection.rtl`. |
''',
  ),
  Entry(
    section: Section.components,
    id: 'segmented-control',
    title: 'Segmented control',
    icon: 'view_week',
    summary:
        'GlassSegmentedControl picks one of two to five options. The selected segment lifts into a clear glass '
        'drop you can slide to another segment.',
    api: <String>['GlassSegmentedControl', 'kGlassSegmentTrack', 'kGlassSegmentDropGrow', 'kGlassSegmentDropWiden'],
    source: 'lib/src/surface/glass_segmented_control.dart',
    guide: r'''
`GlassSegmentedControl` is iOS 26's segmented control. The track is a flat translucent fill, and the
selected segment sits on a white capsule. Press the selection and it lifts into a clear glass drop
that stands out of the track; slide it along and let go over another segment to select that one.
Tapping a segment selects it directly.

The track and the capsule are paint, not glass, so at rest the control costs nothing. The drop
exists only while it is held.

## When to use

- Two to five mutually exclusive views or filters: Day / Week / Month, List / Grid / Map.
- **Not** for navigation between the main sections of an app: that is a [tab bar](/components/tab-bar).
- **Not** for one on/off option: that is a [switch](/components/switch).
- **Not** for more than five options, or long labels. It asserts at least two segments.

## Usage

```dart
SizedBox(
  width: 280,
  child: GlassSegmentedControl(
    segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
    selectedIndex: _range,
    onSelected: (int i) => setState(() => _range = i),
  ),
)
```

The control is 32 px tall (44 px with its tap area) and takes the width of its parent, divided
evenly between segments. It needs a bounded width.

## Label colours

The control lives in the content layer, so it does not pick a label colour for the unselected
segments: they use the ambient `DefaultTextStyle` and `IconTheme`. Inside a [Card](/components/card)
that is already the card's legible colour. Elsewhere, set it yourself with `DefaultTextStyle.merge`.

The **selected** segment's label is picked for you, black on a light `thumbColor` and white on a
dark one.

## Accessibility

Each segment is a button for a screen reader, with the selected one marked as selected. Text
segments read their text. For icon segments, wrap each icon in `Semantics(label: ...)` or use
`Icon(..., semanticLabel: ...)`.

## Keyboard, right to left, and a PageView

- The control takes the focus from the keyboard (`focusNode`, `autofocus`), and the arrow keys move the selection. The
  ring is drawn around the track behind a boundary of its own; on a control under other glass, showing or hiding it is
  one capture.
- Under a right-to-left `Directionality` the first segment is at the right, and the arrows follow.
- The drop is dragged from touch-down, and inside a horizontal `PageView` the control claims the drag, so the page does
  not turn under it. In a vertical list a swipe that starts on it still scrolls the list.
- The capsule's corner is concentric with the track's, by `GlassConcentric` (see
  [GlassSurface](/foundations/surface)): 14 inside a 16 track inset 2.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A calendar header: a range picker on a glass card, and what it selects.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class RangePicker extends StatefulWidget {
  const RangePicker({super.key});

  @override
  State<RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends State<RangePicker> {
  static const List<String> _ranges = <String>['Day', 'Week', 'Month', 'Year'];
  int _range = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Unselected labels take this style; the card has already set the colour.
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            child: GlassSegmentedControl(
              segments: <Widget>[for (final String r in _ranges) Text(r)],
              selectedIndex: _range,
              onSelected: (int i) => setState(() => _range = i),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This ${_ranges[_range].toLowerCase()}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Icon segments with labels for screen readers, on a dark thumb.
Widget layoutPicker(int index, ValueChanged<int> onSelected) => SizedBox(
  width: 200,
  child: GlassSegmentedControl(
    segments: const <Widget>[
      Icon(Icons.list, semanticLabel: 'List'),
      Icon(Icons.grid_view, semanticLabel: 'Grid'),
      Icon(Icons.map, semanticLabel: 'Map'),
    ],
    selectedIndex: index,
    onSelected: onSelected,
    thumbColor: const Color(0xFF636366),
  ),
);
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `segments` | `List<Widget>` | **required** | One widget per segment, usually a `Text` or an `Icon`. At least 2. |
| `selectedIndex` | `int` | **required** | The selected segment. |
| `onSelected` | `ValueChanged<int>?` | **required** | Called with the new index. Null disables the control (half opacity). |
| `trackColor` | `Color` | `kGlassSegmentTrack` | The track's fill. |
| `thumbColor` | `Color` | `Color(0xFFFFFFFF)` | The capsule under the selected segment at rest. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](/foundations/drop-motion). |
| `focusNode` | `FocusNode?` | `null` | The control's focus. Null makes one the control owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the control is built. |
| `key` | `Key?` | `null` | |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSegmentTrack` | `Color.fromRGBO(118, 118, 128, 0.12)` | The default track fill (iOS's tertiary system fill). |
| `kGlassSegmentDropGrow` | `Size(12, 8)` | How much larger the held drop is than the capsule, per side. |
| `kGlassSegmentDropWiden` | `2.9` | How many px of the surroundings the drop pulls in (a slight zoom-out). |
''',
  ),
  Entry(
    section: Section.components,
    id: 'tab-bar',
    title: 'Tab bar',
    icon: 'tab',
    summary:
        'GlassTabBar is the floating iOS 26 tab bar. The selected tab lifts into a glass drop you can drag from tab '
        'to tab, and the bar can collapse to that tab on a scroll down.',
    api: <String>[
      'GlassTabBar',
      'GlassTabItem',
      'GlassTabItemLook',
      'GlassTabItemBuilder',
      'GlassTabBarMinimizeBehavior',
      'GlassTabBarMinimizer',
      'kGlassTabDropZoom',
      'kGlassTabDropGrow',
      'kGlassTabMinimizeScroll',
      'kGlassTabAccessoryHeight',
    ],
    source: 'lib/src/surface/glass_tab_bar.dart',
    guide: r'''
`GlassTabBar` is the floating tab bar of iOS 26: a [Bar](/components/bar) holding two to five tabs,
each an icon over a label. The selected tab sits on a grey pill in the `activeColor`. Press it and
the pill lifts into a clear glass drop that magnifies the bar under it; drag the drop along the bar
and the tab under your finger lights up; let go and that tab is selected. A plain tap on a tab works
too.

The layout adapts to the width: below 80 px per tab, the icon sits over the label (phones); above
that, they sit side by side (tablets and desktop).

## When to use

- The top-level sections of an app: Home, Search, Library, Profile.
- **Not** for switching views inside one screen: that is a
  [segmented control](/components/segmented-control).
- **Not** for actions: tabs select a place, they don't do something. Use a
  [toolbar](/components/toolbar) for actions.
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
  [Drop motion](/foundations/drop-motion).

## Collapsing on scroll

iOS 26's tab bar shrinks to its selected tab while the content scrolls down, and comes back when it scrolls up. With
`minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown`, the bar collapses to a circle of its own height at its
start edge, the selected tab's icon in it, once the content has gone
[`kGlassTabMinimizeScroll`](https://pub.dev/documentation/g1455/latest/g1455/kGlassTabMinimizeScroll-constant.html)
(12 px) down, and expands once it has come as far back up or reached its top. A tap on the circle expands it and
selects nothing.

A scroll reports only upward, and the bar is not inside the scroll view, so both go under one
`GlassTabBarMinimizer`. [`GlassScaffold`](/components/scaffold) is one already; a screen built by hand puts one above
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
chose. For anything else, an SVG, an image, a [badge](/components/badge), give `iconBuilder` (or `labelBuilder`), which
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
> If glass cards scroll under the tab bar, wrap it in [`GlassAbove`](/foundations/above), or put a bottom
> [scroll edge](/foundations/scroll-edge) under it. Otherwise the bar shows the content but not the cards.

> [!TIP]
> [`GlassScaffold`](/components/scaffold) places a tab bar as its `bottomBar`: lifted, at the bottom of the safe area,
> with the list padded to end above it, and its scrolls collapse a bar that asks to.

> [!NOTE]
> A bare `setState` that rebuilds the bar costs one capture, even when nothing it draws changed. A known cost, not yet
> traced: rebuild the bar when its selection or its items change, not with every change of the screen around it.
''',
    code: r'''
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
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassTabItem>` | **required** | The tabs. At least 2. |
| `selectedIndex` | `int` | **required** | The selected tab. |
| `onSelected` | `ValueChanged<int>?` | **required** | Called with the new tab. Null disables the bar. |
| `activeColor` | `Color` | `Color(0xFF007AFF)` | Icon and label colour of the selected tab, and of the tab under a held drop. |
| `dropZoom` | `double` | `kGlassTabDropZoom` | How much the held drop magnifies the bar. `1` for none; must be above 0. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](/foundations/drop-motion). |
| `minimizeBehavior` | `GlassTabBarMinimizeBehavior` | `.never` | `.onScrollDown` collapses the bar to its selected tab while the content scrolls down, under a `GlassTabBarMinimizer`. |
| `bottomAccessory` | `Widget?` | `null` | A widget on a glass capsule above the bar, which moves beside the collapsed circle. |
| `key` | `Key?` | `null` | |

## GlassTabBarMinimizer

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree whose vertical scrolls collapse the bars in it: the scroll view and the bar both. |

`static ValueNotifier<bool>? maybeOf(BuildContext context)`: whether the bars below are collapsed, or null with no
minimizer above. Writable: set it `false` to expand them.

## GlassTabItem

| Parameter | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | **required** | The tab's name: the text drawn unless `labelBuilder` is given, and what a screen reader says always. |
| `icon` | `IconData?` | `null` | The tab's icon, drawn in the colour the bar resolved. Ignored when `iconBuilder` is given. |
| `iconBuilder` | `GlassTabItemBuilder?` | `null` | Builds the icon instead of `icon`: an SVG, an image, a badge. Sized by you; the bar's own icons are `look.iconSize`. |
| `labelBuilder` | `GlassTabItemBuilder?` | `null` | Builds the label instead of the text of `label`. |

An item needs an `icon` or an `iconBuilder`; it asserts. `GlassTabItemBuilder` is
`Widget Function(BuildContext context, GlassTabItemLook look)`.

## GlassTabItemLook

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

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassTabDropZoom` | `1.17` | The default `dropZoom`, read off iOS 26. |
| `kGlassTabDropGrow` | `10.5` | How much larger the held drop is than the resting pill, per side, in px. |
| `kGlassTabMinimizeScroll` | `12` | How far the content scrolls one way, in px, before the bar collapses or expands. Layout taste. |
| `kGlassTabAccessoryHeight` | `48` | The accessory's glass height. Layout taste. |
''',
  ),
];
