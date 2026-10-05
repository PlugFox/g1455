# What the app declares

> What the package cannot read from the render tree: the backdrop, reduce transparency, contrast, thermal state.

- Live: https://g1455.plugfox.dev/start/declarations
- API: [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassTierPolicy`](https://pub.dev/documentation/g1455/latest/g1455/GlassTierPolicy-class.html), [`GlassThermalState`](https://pub.dev/documentation/g1455/latest/g1455/GlassThermalState.html), [`GlassHardware`](https://pub.dev/documentation/g1455/latest/g1455/GlassHardware.html)
- Source: [`lib/src/surface/glass_host.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_host.dart)

Some things the glass needs to know are not in the render tree, and Flutter does not pass some platform settings on.
g1455 ships no platform code to go and read them, so the application declares them, all as parameters of
[GlassHost](../foundations/host.md). Everything here is optional: leave a declaration out and you get a safe default.

## What is behind the glass

Components such as [GlassBar](../components/bar.md) and [GlassCard](../components/card.md) choose black or white text. To choose
well, the host needs to know what the glass sits over:

- `backdrop:` the screen's average background colour, for a flat background. It is also what the opaque tier fills
  with, so declare it whenever you might use that tier.
- `richBackdrop: true` for an image, a video, a map or a feed. Labels are then chosen for the worst case over any
  backdrop.
- `minLabelContrast:` a contrast floor, such as `kTextContrastAA` (4.5, WCAG AA for body text). When the finish cannot
  reach it, the glass is dimmed just enough to do so.

Without any of these, labels are picked against the worst case, and in debug the package warns once when a finish
cannot be read over it. More on [Legibility & theme](../foundations/legibility.md).

## Reduce transparency

Flutter does not expose the operating system's Reduce Transparency switch. Read it natively and pass it to a
[GlassTierPolicy](../foundations/tiers.md), which answers with the opaque tier:

```dart
GlassHost(
  backdrop: const Color(0xFF101014), // the opaque tier fills with this
  tier: GlassTierPolicy(reduceTransparency: reduceTransparency).choose(),
  child: child,
)
```

The same policy takes a `ceiling` for low-end devices, such as `GlassTier.cheap`. The package never switches tiers on
its own.

## Increase contrast

`GlassHost.highContrast` draws an opaque, visible outline instead of the subtle rim. On iOS and on Android 34 and
later the host already reads it from `MediaQuery`. On macOS the engine does not pass it on, so read it natively and
pass `highContrast: true`.

## Thermal state

Pass the device's thermal state as a `GlassThermalState` (`nominal`, `fair`, `serious`, `critical`, Apple's four
names). Under `serious` and `critical` the host may reuse a slightly stale capture for a frame or two on screens that
change. Blurry finishes tolerate that; `clear` gets none. Tiers are never changed by thermals.

On Android, map `PowerManager`'s thermal status: NONE to `nominal`, LIGHT and MODERATE to `fair`, SEVERE to
`serious`, and CRITICAL, EMERGENCY and SHUTDOWN to `critical`.

## Hardware

`GlassHost.hardware` says which device family's measurements apply. `GlassHardware.detect()` returns `appleMetal` on
iOS and macOS and `unmeasured` elsewhere, because Dart cannot name the GPU. Declare `adrenoVulkan` only for a
Snapdragon with an Adreno 830-class GPU. Undeclared hardware gets the same behaviour with no price attached: it changes
reported costs and the default texture limit, never correctness.

> [!WARNING]
> A `GlassTierPolicy(pinned: ...)` overrides everything, the user's Reduce Transparency setting included. Pin a tier
> for tests and benchmarks, not for users.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// The settings the package cannot read for itself. Fill them from your own
/// platform code (a method channel, a plugin) and rebuild when they change.
class DeviceSignals {
  const DeviceSignals({
    this.reduceTransparency = false,
    this.increaseContrast,
    this.thermal = GlassThermalState.nominal,
    this.lowEndDevice = false,
  });

  final bool reduceTransparency;
  final bool? increaseContrast; // null: let the host read MediaQuery
  final GlassThermalState thermal;
  final bool lowEndDevice;
}

class DeclaredApp extends StatelessWidget {
  const DeclaredApp({super.key, required this.signals, required this.home});

  final DeviceSignals signals;
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) => GlassHost(
      // What is behind the glass: a feed over a near-black page.
      backdrop: const Color(0xFF101014),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      // Reduce transparency gives the opaque tier; a low-end device stops at cheap.
      tier: GlassTierPolicy(
        reduceTransparency: signals.reduceTransparency,
        ceiling: signals.lowEndDevice ? GlassTier.cheap : null,
      ).choose(),
      highContrast: signals.increaseContrast,
      thermal: signals.thermal,
      hardware: GlassHardware.detect(),
      child: child!,
    ),
    home: home,
  );
}
```
