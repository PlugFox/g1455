# Tiers & fallbacks

> Full glass, a cheap translucent fill, or opaque: the rung for reduce transparency, low-end devices and tests.

- Live: https://g1455.plugfox.dev/foundations/tiers
- API: [`GlassTier`](https://pub.dev/documentation/g1455/latest/g1455/GlassTier.html), [`GlassTierPolicy`](https://pub.dev/documentation/g1455/latest/g1455/GlassTierPolicy-class.html), [`GlassTierChoice`](https://pub.dev/documentation/g1455/latest/g1455/GlassTierChoice-class.html), [`GlassTierReason`](https://pub.dev/documentation/g1455/latest/g1455/GlassTierReason.html)
- Source: [`lib/src/surface/glass_tier.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_tier.dart)

Glass comes in three rungs. The package never switches between them on its own: you decide, and `GlassTierPolicy`
turns your signals into a choice.

| Tier | What is drawn | Captures |
|---|---|---|
| `GlassTier.full` | Real glass: refraction, blur, tint and rim. | Yes |
| `GlassTier.cheap` | The same shape and rim, with the tint laid straight over what is behind. No blur, no refraction. | No |
| `GlassTier.opaque` | A solid fill matching the glass's average look over the declared backdrop. | No |

## When to use

- **Opaque** for the operating system's Reduce Transparency setting. That is what the setting asks for.
- **Cheap** as a ceiling on low-end devices, or for a long list of cards below full-glass bars.
- **Pinned** tiers for tests, screenshots and benchmarks.
- Don't expect auto-detection. Flutter doesn't expose Reduce Transparency, so read it natively.

## Usage

```dart
GlassHost(
  backdrop: const Color(0xFF101014), // the opaque tier fills with this
  tier: GlassTierPolicy(
    reduceTransparency: reduceTransparency, // read natively by the app
    ceiling: lowEndDevice ? GlassTier.cheap : null,
  ).choose(),
  child: child,
)
```

`choose()` resolves in this order: `pinned`, then `reduceTransparency` (opaque), then `ceiling`, then full. The
`GlassTierChoice` it returns carries the tier and a `GlassTierReason` for reporting.

## A tier for a subtree

The host's tier applies to the whole screen. To run one part of it on another rung, nest a `GlassTheme` below the
host. The demo above does exactly that around its stage:

```dart
GlassTheme(
  data: GlassTheme.of(context).copyWith(
    tier: const GlassTierPolicy(ceiling: GlassTier.cheap).choose(),
  ),
  child: cardList, // cheap cards under full-glass bars
)
```

## Behaviour

- Below the full tier nothing is captured, so the cheap and opaque rungs cost no capture at all.
- Below full, [groups](../foundations/groups.md) stop fusing (no bridges between members) and
  [ripples](../foundations/ripple.md) are off.
- The cheap and opaque rungs draw even without a host above, as flat panels.

> [!WARNING]
> With `opaque`, declare `backdrop` on the host or the theme. Without it the fill is the tint alone, which is wrong,
> and you get a debug error when the rung is painted.

> [!WARNING]
> `pinned` overrides everything, the user's Reduce Transparency setting included.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// The app's tier from what the app knows about the device and the user.
class TieredApp extends StatelessWidget {
  const TieredApp({
    super.key,
    required this.reduceTransparency,
    required this.lowEndDevice,
    required this.home,
  });

  final bool reduceTransparency; // read natively: Flutter does not pass it on
  final bool lowEndDevice; // your own device table or benchmark
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) => GlassHost(
      backdrop: const Color(0xFF101014), // needed by the opaque tier
      tier: GlassTierPolicy(
        reduceTransparency: reduceTransparency,
        ceiling: lowEndDevice ? GlassTier.cheap : null,
      ).choose(),
      child: child!,
    ),
    home: home,
  );
}

/// Full-glass bar over a list of cards held at the cheap tier.
class CheapCards extends StatelessWidget {
  const CheapCards({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      GlassTheme(
        data: GlassTheme.of(context).copyWith(
          tier: const GlassTierChoice(GlassTier.cheap, GlassTierReason.deviceCeiling),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 16),
          children: <Widget>[
            for (var i = 0; i < 20; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(child: Text('Card $i')),
              ),
          ],
        ),
      ),
      const Positioned(
        top: 24,
        left: 16,
        right: 16,
        child: GlassAbove(child: GlassBar(child: Text('Inbox'))),
      ),
    ],
  );
}
```

## API

### GlassTierPolicy

| Parameter | Type | Default | Description |
|---|---|---|---|
| `pinned` | `GlassTier?` | `null` | Forces a tier. Overrides everything, including the user's accessibility setting. |
| `reduceTransparency` | `bool` | `false` | The OS Reduce Transparency switch, as your app read it. Gives `opaque`. |
| `ceiling` | `GlassTier?` | `null` | The richest tier this device should run, e.g. `cheap` on low-end hardware. |

`choose()` returns a `GlassTierChoice`, resolving `pinned`, then `reduceTransparency`, then `ceiling`, then full.

### GlassTierChoice

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tier` | `GlassTier` | **required** (positional) | The rung drawn. |
| `reason` | `GlassTierReason` | **required** (positional) | Why, for reporting. |

`GlassTierChoice.byDefault` is `(GlassTier.full, GlassTierReason.byDefault)`.

### Enums

| Name | Values | Description |
|---|---|---|
| `GlassTier` | `full`, `cheap`, `opaque` | The rungs. `readsBackdrop` is true only for `full`. |
| `GlassTierReason` | `byDefault`, `pinnedByHost`, `reduceTransparency`, `deviceCeiling` | Why a rung was chosen. Reporting only. |
