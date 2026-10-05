# Ripple

> An optional liquid wave when glass is touched, from water to honey. Not an Apple behaviour, off under reduced motion, and it costs no capture.

- Live: https://g1455.plugfox.dev/foundations/ripple
- API: [`GlassRipple`](https://pub.dev/documentation/g1455/latest/g1455/GlassRipple-class.html), [`kMaxRippleWaves`](https://pub.dev/documentation/g1455/latest/g1455/kMaxRippleWaves-constant.html)
- Source: [`lib/src/surface/glass_ripple.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_ripple.dart)

`GlassRipple` makes glass answer a touch like a liquid: a dimple forms under the finger, a ring travels outward from it, and the dimple springs back when you let go. One knob, `viscosity`, runs from water (`0`, thin rings that overshoot) to honey (`1`, one slow, broad bump).

This is **not** something Apple's Liquid Glass does. iOS 26 answers a touch with light and a springy scale, and never deforms the material. The ripple is opt-in, and nothing ripples unless you ask for it.

## When to use

- Playful or brand moments: a hero panel, an onboarding card, a game UI.
- Large, text-free glass where a wave reads well.
- **Not** when you want platform fidelity. An app that should feel like a stock iOS 26 app should leave it off.
- **Not** on glass that sits over other tappable things: a rippling surface becomes hit-testable over its whole shape, even without a child.

## Usage

Declare it once on the host for every surface on the screen, or on one surface:

```dart
// Every surface below the host ripples.
GlassHost(ripple: const GlassRipple(), child: page);

// Just this panel, thick and subtle.
const GlassSurface(
  finish: GlassFinish.clear,
  labelled: false,
  ripple: GlassRipple(viscosity: 0.9, amplitude: 8, press: 0.5, light: 0.05),
);
```

A `GlassTheme` below the host can also set `ripple:` for a subtree through [`GlassThemeData`](https://pub.dev/documentation/g1455/latest/g1455/GlassThemeData-class.html). A surface's own `ripple:` wins over the theme's.

## Behaviour

- **Viscosity is one mechanism.** A thick liquid loses its rings (the front is a single bump), spreads wider, fades sooner and stops overshooting. A thin one rings.
- **Each touch makes two impulses:** one on press and one on release. Up to [`kMaxRippleWaves`](https://pub.dev/documentation/g1455/latest/g1455/kMaxRippleWaves-constant.html) (4) waves run on one surface at once.
- **It switches itself off** when the platform asks for reduced motion (`MediaQuery.disableAnimations`), for members of a fusing [group](../foundations/groups.md), and below the full [tier](../foundations/tiers.md).
- The defaults were chosen by eye. There is no platform reference to measure them against.

## Performance

A wave changes how the captured backdrop is sampled, not the backdrop itself, so it **takes no capture and repaints nothing**. The ripple has its own shader, which runs only on frames where a wave is alive. A surface at rest draws exactly as it would without a ripple.

> [!TIP]
> Glass without text, like the panel in the demo, should set `labelled: false`. Otherwise a clear finish may be dimmed to keep labels legible, and the wave is harder to see.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A hero panel that answers a touch with a wave. Assumes a GlassHost above,
/// in MaterialApp.builder. For every surface at once, pass
/// `ripple: const GlassRipple()` to the GlassHost instead.
class RippleHero extends StatefulWidget {
  const RippleHero({super.key});

  @override
  State<RippleHero> createState() => _RippleHeroState();
}

class _RippleHeroState extends State<RippleHero> {
  bool _honey = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: 320,
        height: 200,
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          finish: GlassFinish.clear,
          // No text to read on it, so keep the clear finish exactly as named.
          labelled: false,
          ripple: GlassRipple(
            viscosity: _honey ? 0.95 : 0.15, // 0 is water, 1 is honey
            amplitude: 8,
            light: 0.06,
          ),
          child: const Center(child: Icon(Icons.waves, size: 40, color: Colors.white)),
        ),
      ),
      const SizedBox(height: 16),
      GlassButton(
        onPressed: () => setState(() => _honey = !_honey),
        child: Text(_honey ? 'Make it water' : 'Make it honey'),
      ),
    ],
  );
}
```

## API

`const GlassRipple({...})`. Every field is optional.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `amplitude` | `double` | `6` | Peak displacement of the wave, in logical px. Must be ≥ 0. |
| `speed` | `double` | `360` | How fast the ring travels, in px/s. Must be > 0. |
| `width` | `double` | `12` | Half-width of the ring when it is born, in px. Must be > 0. |
| `viscosity` | `double` | `0.6` | `0` is water (thin, ringing), `1` is honey (one slow bump). |
| `press` | `double` | `0.8` | Depth of the dimple under the finger, as a fraction of `amplitude`. `0` means no dimple. |
| `pressRadius` | `double` | `26` | Radius of the dimple, in px. Must be > 0. |
| `light` | `double` | `0.08` | Highlight and shadow on the slopes. `0` means refraction only. |

Also `copyWith(...)` for every field.

Where it goes: `GlassHost.ripple`, `GlassThemeData.ripple` or `GlassSurface.ripple` (all `GlassRipple?`, `null` means none or "inherit").

### Constants

| Name | Value | Description |
|---|---|---|
| `kMaxRippleWaves` | `4` | The most waves one surface draws at once. |
