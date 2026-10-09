# Switch

> GlassSwitch is the iOS 26 on/off switch: a white knob that lifts into a clear glass drop while you press or drag it, and costs nothing extra at rest.

- Live: https://g1455.plugfox.dev/components/switch
- API: [`GlassSwitch`](https://pub.dev/documentation/g1455/latest/g1455/GlassSwitch-class.html), [`kGlassSwitchSize`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSwitchSize-constant.html), [`kGlassDropScale`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropScale-constant.html), [`kGlassSwitchDropWiden`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSwitchDropWiden-constant.html), [`kGlassDropOptics`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropOptics-constant.html), [`kGlassDropDuration`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropDuration-constant.html), [`kGlassDisabledOpacity`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledOpacity-constant.html)
- Source: [`lib/src/surface/glass_controls.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_controls.dart)

`GlassSwitch` is an on/off switch drawn the way iOS 26 draws it: a 64 × 28 track and a white knob.
When you press the knob, it lifts into a clear glass drop about 1.57 times its size, which bends
what is under it. Drag it to the other side, or just tap; let go and the value commits.

At rest the knob and the track are ordinary paint, not glass. The drop exists only while the switch
is held, so a page with twenty switches costs the glass nothing until someone touches one.

## When to use

- Boolean settings: Wi-Fi on or off, notifications, a feature flag in a settings group.
- Over imagery or on a [Card](../components/card.md), where an ordinary switch would look flat.
- **Not** for choosing between more than two options: use a
  [segmented control](../components/segmented-control.md).
- **Not** for an action that happens right away and can't be undone. That is a
  [button](../components/button.md).

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
> The drop needs a [`GlassHost`](../foundations/host.md) above it to be glass. Without one the switch still
> works, but the held knob is not drawn as glass.

## Complete example

```dart
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
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `bool` | **required** | Whether the switch is on. |
| `onChanged` | `ValueChanged<bool>?` | **required** | Called with the new value. Null disables the switch (drawn at 50% opacity). |
| `activeColor` | `Color` | `Color(0xFF34C759)` | Track colour when on (iOS green). |
| `trackColor` | `Color` | `Color(0x29787880)` | Track colour when off. |
| `dropScale` | `double` | `kGlassDropScale` | Size of the held drop relative to the knob. At least 1. |
| `dropWiden` | `double` | `kGlassSwitchDropWiden` | How many px of the surroundings the drop pulls in (a slight zoom-out). 0 for none. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](../foundations/drop-motion.md). |
| `semanticLabel` | `String?` | `null` | Screen-reader label. Or wrap the row in `MergeSemantics` with a `Text`. |
| `focusNode` | `FocusNode?` | `null` | The switch's focus. Null makes one the switch owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the switch is built. |
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSwitchSize` | `Size(64, 28)` | The track. The widget is at least 44 px tall. |
| `kGlassDropScale` | `1.57` | Held drop size relative to the knob (switch and slider). |
| `kGlassSwitchDropWiden` | `5` | The switch's default `dropWiden`, in px. |
| `kGlassDropOptics` | `GlassOptics(thickness: 10, strength: -4.1)` | The drop's refraction. |
| `kGlassDropDuration` | `Duration(milliseconds: 180)` | How long the drop takes to grow in and out. |
| `kGlassDisabledOpacity` | `0.5` | Opacity of a disabled switch or slider. |
