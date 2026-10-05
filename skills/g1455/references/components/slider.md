# Slider

> GlassSlider is a continuous 0 to 1 slider whose knob turns into a clear glass drop while you drag it, for volume, brightness or a scrubber.

- Live: https://g1455.plugfox.dev/components/slider
- API: [`GlassSlider`](https://pub.dev/documentation/g1455/latest/g1455/GlassSlider-class.html), [`SliderGeometry`](https://pub.dev/documentation/g1455/latest/g1455/SliderGeometry-class.html), [`kGlassDropScale`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDropScale-constant.html), [`kGlassDisabledOpacity`](https://pub.dev/documentation/g1455/latest/g1455/kGlassDisabledOpacity-constant.html)
- Source: [`lib/src/surface/glass_controls.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_controls.dart)

`GlassSlider` picks a value between 0 and 1. It is 44 px tall and as wide as its parent lets it be.
At rest the knob is a white capsule on a thin track; while you press or drag it, the knob lifts into a
clear glass drop, like the [switch](../components/switch.md)'s.

Tapping anywhere on the track jumps the value there. Screen readers can step it up and down.

## When to use

- Continuous values: volume, brightness, a playback scrubber, a blur radius.
- **Not** for discrete steps. There is no snapping; if you need steps, round the value yourself or
  use a [segmented control](../components/segmented-control.md).
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

## Accessibility

Give every slider a `semanticLabel` ("Volume", "Brightness"). `semanticStep` (default 0.1) is how far
one increase or decrease moves it; 0.05 gives a screen reader 20 steps.

## Performance

The fill of the track ends under the drop and follows it, so every frame of a drag changes what is
under the glass, and the host captures again each frame. That is expected and is the price of a
slider over glass. At rest it costs nothing.

## Lining things up with the fill

`SliderGeometry.fillEnd(value, width)` returns the x position where the fill ends on a slider of
that width. Use it to place a tick, a label or a buffered-range bar exactly under the knob's centre.

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
| `semanticStep` | `double` | `0.1` | How far one accessibility increase or decrease moves the value. Between 0 (exclusive) and 1. |
| `key` | `Key?` | `null` | |

### Helpers

| Name | Description |
|---|---|
| `SliderGeometry.fillEnd(double value, double width)` | The x position, in px from the slider's left edge, where the fill ends for `value` on a slider `width` wide. |
