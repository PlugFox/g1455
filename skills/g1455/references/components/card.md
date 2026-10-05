# Card

> GlassCard is a rounded glass panel for a few floating groups of content, such as widgets on a wallpaper, with a legible label colour for its children.

- Live: https://g1455.plugfox.dev/components/card
- API: [`GlassCard`](https://pub.dev/documentation/g1455/latest/g1455/GlassCard-class.html)
- Source: [`lib/src/surface/glass_components.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_components.dart)

`GlassCard` is the same panel as a [Bar](../components/bar.md) with a 24 px corner instead of a capsule
and 16 px of padding all round. Its children get a legible label colour, black or white, picked
against the glass over what is behind it.

## When to use

- A few floating panels over a wallpaper or a photo: weather and calendar widgets, a now-playing
  card, a settings group on a lock-screen style page.
- A panel that holds controls: [switches](../components/switch.md), [sliders](../components/slider.md), a
  [button](../components/button.md).
- **Not** for every item of a list or a feed. Apple keeps Liquid Glass in the navigation and
  controls layers, out of the content layer. Each card is one more surface, and the cost grows
  faster than the number of surfaces. A feed of glass cards is the most expensive thing you can
  build with this package. If you really need it, check the count with
  [`GlassLedger`](../foundations/performance.md).
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
hardest to read on. Try them in the demo above, and see [Finishes](../foundations/finishes.md).

## Gotchas

- A bar or tab bar floating above glass cards does not show those cards unless it is wrapped in
  [`GlassAbove`](../foundations/above.md). Controls written *inside* a card refract it automatically.
- Secondary text in a card: derive it from `DefaultTextStyle.of(context).style.color` (for example
  at 70% alpha) rather than a fixed grey, so it follows the label colour the card chose.

## Complete example

```dart
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
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The content. Gets the card's label colour. |
| `borderRadius` | `BorderRadius` | `BorderRadius.all(Radius.circular(24))` | Corner radii. |
| `padding` | `EdgeInsets` | `EdgeInsets.all(16)` | Space between the glass and the content. |
| `finish` | `GlassFinish?` | `null` | The material. Null takes the theme's. |
| `key` | `Key?` | `null` | |
