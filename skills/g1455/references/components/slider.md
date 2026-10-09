# Slider

> GlassSlider is a 0 to 1 slider, continuous or in steps, whose knob turns into a clear glass drop while you drag it, for volume, brightness or a scrubber.

- Live: https://g1455.plugfox.dev/components/slider
- API: [`GlassSlider`](https://pub.dev/documentation/g1455/latest/g1455/GlassSlider-class.html), [`SliderGeometry`](https://pub.dev/documentation/g1455/latest/g1455/SliderGeometry-class.html), [`kGlassDropScale`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropScale-constant.html), [`kGlassDisabledOpacity`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledOpacity-constant.html)
- Source: [`lib/src/surface/glass_controls.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_controls.dart)

`GlassSlider` picks a value between 0 and 1. It is 44 px tall and as wide as its parent lets it be.
At rest the knob is a white capsule on a thin track; while you press or drag it, the knob lifts into a
clear glass drop, like the [switch](../components/switch.md)'s.

Tapping anywhere on the track jumps the value there. Screen readers can step it up and down.

## When to use

- Continuous values: volume, brightness, a playback scrubber, a blur radius.
- A value in steps, with `divisions`: a rating out of five, a zoom in quarters.
- **Not** for a handful of named options. That is a [segmented control](../components/segmented-control.md). A small whole
  number changed one at a time is a [stepper](../components/stepper.md).
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
- The knob is dragged from touch-down. Inside a horizontal `PageView` or list a horizontal drag moves the slider and
  not the page, and a vertical swipe that starts on the slider still scrolls the vertical list around it.
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

## Complete example

```dart
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
```

## API

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
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](../foundations/drop-motion.md). |
| `semanticLabel` | `String?` | `null` | Screen-reader label. |
| `semanticStep` | `double` | `0.1` | How far one accessibility increase or decrease, or an arrow key, moves the value. Between 0 (exclusive) and 1. Ignored with `divisions`. |
| `divisions` | `int?` | `null` | How many equal steps the value snaps to, or null for a continuous slider. Above 0. |
| `focusNode` | `FocusNode?` | `null` | The slider's focus. Null makes one the slider owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the slider is built. |
| `key` | `Key?` | `null` | |

### Helpers

| Name | Description |
|---|---|
| `SliderGeometry.fillEnd(double value, double width, {TextDirection textDirection = TextDirection.ltr})` | The x position, in px from the slider's left edge, where the fill ends for `value` on a slider `width` wide; mirrored under `TextDirection.rtl`. |
