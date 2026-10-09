# Stepper

> GlassStepper is a minus and a plus in one glass capsule, as UIStepper: a held half repeats, the end at a limit is disabled, and a press costs no capture.

- Live: https://g1455.plugfox.dev/components/stepper
- API: [`GlassStepper`](https://pub.dev/documentation/g1455/latest/g1455/GlassStepper-class.html), [`kGlassStepperSize`](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperSize-constant.html), [`kGlassStepperRepeatDelay`](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatDelay-constant.html), [`kGlassStepperRepeatInterval`](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatInterval-constant.html)
- Source: [`lib/src/surface/glass_stepper.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_stepper.dart)

`GlassStepper` is iOS's `UIStepper` on glass: one capsule split by a hairline into a minus and a plus. A press steps the
value at once; held, the half repeats, half a second after the press and then ten times a second, until the finger lifts
or the value reaches a limit. At a limit the half that would pass it is disabled and its glyph dims, unless the stepper
`wraps`.

The stepper shows no number. As on iOS, the value goes in a label beside it, which you rebuild from `onChanged`.

## When to use

- A small count changed one step at a time: copies to print, guests, a quantity in a cart, a font size.
- **Not** for a wide range, where tapping a hundred times is no way to get there. Use a [slider](../components/slider.md),
  with `divisions` if the value is whole.
- **Not** as two [GlassButton](../components/button.md)s side by side. Two buttons are two surfaces; the stepper is one, and
  draws the divider and the pressed half inside it.

## Usage

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

The value is a `double`, so a fractional `step` works too: `step: 0.5` for a font size. `onChanged: null` disables both
halves.

## Behaviour

- `autorepeat` (on by default) repeats a held half after
  [kGlassStepperRepeatDelay](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatDelay-constant.html)
  (500 ms), every [kGlassStepperRepeatInterval](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatInterval-constant.html)
  (100 ms). The repeat stops at a limit.
- `wraps` goes from `max` to `min` and back instead of stopping, and keeps both halves enabled.
- A held half brightens its own cell by the finish's rim colour, clipped to the capsule, as a
  [toolbar](../components/toolbar.md) cell does. `pressedOverlay` replaces that colour.

## Size

The capsule is [kGlassStepperSize](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperSize-constant.html),
94 × 32: `UIStepper`'s width and the [segmented control](../components/segmented-control.md)'s track. The control is laid
out 44 tall around it, so a tap a little above or below still lands. **Layout, not a reading**: the iOS 26 stepper was
not among the controls measured for the package.

## Cost

One surface, whatever is held. A press, the repeat and a glyph dimming at a limit are drawn inside the glass, so none
of them is a capture. Keep the label you change beside the stepper on glass too, as the demo does on a card, and a
press repaints nothing under any glass: the count under the stage stays where it was.

## Accessibility

A screen reader hears one adjustable control: its `semanticLabel` and the value, which it increases or decreases by
`step`. `semanticFormatterCallback` says the value your way, "12.5 points" rather than "12.5".

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A print dialog's options on a glass card.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class PrintOptions extends StatefulWidget {
  const PrintOptions({super.key});

  @override
  State<PrintOptions> createState() => _PrintOptionsState();
}

class _PrintOptionsState extends State<PrintOptions> {
  int _copies = 1;
  double _scale = 100;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Copies: $_copies')),
              GlassStepper(
                value: _copies.toDouble(),
                min: 1,
                max: 99,
                semanticLabel: 'Copies',
                onChanged: (double v) => setState(() => _copies = v.round()),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(child: Text('Scale: ${_scale.round()}%')),
              GlassStepper(
                value: _scale,
                min: 25,
                max: 400,
                step: 25,
                semanticLabel: 'Scale',
                semanticFormatterCallback: (double v) => '${v.round()} percent',
                onChanged: (double v) => setState(() => _scale = v),
              ),
            ],
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
| `value` | `double` | **required** | The value shown. The stepper holds none of its own. |
| `onChanged` | `ValueChanged<double>?` | **required** | Called with the new value. Null disables both halves. |
| `min` | `double` | `0` | The lowest value. At most `max`. |
| `max` | `double` | `100` | The highest value. |
| `step` | `double` | `1` | How far one press moves the value. Above 0. |
| `wraps` | `bool` | `false` | Past `max` goes to `min` and back, instead of stopping. |
| `autorepeat` | `bool` | `true` | A held half repeats until the finger lifts or a limit is reached. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `pressedOverlay` | `Color?` | `null` | Added over the held half. Null takes the finish's rim colour. |
| `semanticLabel` | `String?` | `null` | What a screen reader calls the control. |
| `semanticFormatterCallback` | `String Function(double)?` | `null` | How a screen reader says the value. |
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassStepperSize` | `Size(94, 32)` | The capsule. Laid out at least 44 tall. Layout, not a reading. |
| `kGlassStepperRepeatDelay` | `Duration(milliseconds: 500)` | How long a held half waits before it repeats. |
| `kGlassStepperRepeatInterval` | `Duration(milliseconds: 100)` | How often it repeats after that. |
