# Performance

> What glass costs and how to keep it cheap: surface count, button groups, travel regions, thermal state, and the ledger that reports the glass on screen.

- Live: https://g1455.plugfox.dev/foundations/performance
- API: [`GlassLedger`](https://pub.dev/documentation/g1455/latest/g1455/GlassLedger-class.html), [`GlassScope`](https://pub.dev/documentation/g1455/latest/g1455/GlassScope-class.html), [`GlassLoad`](https://pub.dev/documentation/g1455/latest/g1455/GlassLoad-class.html), [`GlassLoadVerdict`](https://pub.dev/documentation/g1455/latest/g1455/GlassLoadVerdict.html), [`GlassHardware`](https://pub.dev/documentation/g1455/latest/g1455/GlassHardware.html), [`GlassThermalState`](https://pub.dev/documentation/g1455/latest/g1455/GlassThermalState.html), [`GlassThermalPolicy`](https://pub.dev/documentation/g1455/latest/g1455/GlassThermalPolicy-class.html), [`debugPaintGlassSurfaces`](https://pub.dev/documentation/g1455/latest/g1455/debugPaintGlassSurfaces.html)
- Source: [`lib/src/surface/glass_ledger.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_ledger.dart)

g1455 is built for cost first. Instead of a `BackdropFilter` on every surface, one [`GlassHost`](../foundations/host.md) records what's under all of its glass into **one** shared, downscaled capture, and **only re-records when something under the glass changed**. A still screen costs no capture at all. See [How it works](../start/how-it-works.md) for the details.

What's left for you is to not spend that budget by accident.

## What costs what

- **Each surface is one draw**, and the overhead grows faster than the surface count. A bar with five `GlassButton`s is six surfaces.
- **Changing content under glass** (scrolling, video, an animated background) means a capture on that frame. That's expected, and it's what the measured numbers cover (the devices and the dates: [How it works](../start/how-it-works.md)).
- **Moving glass over still content** costs a capture per frame, unless it moves inside a [`GlassTravel`](../foundations/travel.md).
- **Glass on glass** adds a capture level for each occupied level (nested glass, or [`GlassAbove`](../foundations/above.md)).
- **Animating `materialize`** changes the blur, so it captures every frame while it runs. Animating `presence` doesn't.
- **A ripple** costs no capture. **Groups** cost more than the same surfaces drawn separately.

## Practical advice

- **Keep glass in the navigation and controls layer**, as Apple's guidelines do. Bars, tab bars, toolbars and floating controls, not every card in a feed.
- **Prefer [`GlassButtonGroup`](../components/toolbar.md)** for rows of actions. It's one surface no matter how many items, where N `GlassButton`s are N surfaces.
- **Inside a glass bar, plain icons are cheaper** than `GlassButton`s, which are glass on glass.
- **Wrap moving glass in `GlassTravel`** with `RepaintBoundary`s around the glass and the content.
- **Offer cheaper [tiers](../foundations/tiers.md)** on low-end devices (`GlassTierPolicy(ceiling: GlassTier.cheap)`), and honour Reduce Transparency.
- **Measure in profile mode on a real device.** Debug builds are much slower across the board, so their frame times tell you little about glass.

## Reading the ledger

The host keeps a register of every glass surface on the screen, the `GlassLedger`. Reach it with `GlassScope.maybeOf(context)` and call `read()` to get a `GlassLoad`: the surface count, how many of them are captured, the glass area, *screens of glass* (area relative to the screen), and a `verdict` against what was measured on that hardware.

```dart
final GlassLedger? ledger = GlassScope.maybeOf(context);
final GlassLoad? load = ledger?.read(
  viewSize: MediaQuery.sizeOf(context),
  model: GlassHardware.detect().surfaceCostModel,
);
// e.g. "6 surfaces, 0.12 screens, withinMeasured"
```

The ledger notifies when surfaces are added or removed, not when they move: geometry is read on demand. For a debug overlay, poll it (the code example uses a timer). The demo above shows the readout for the page you're reading.

> [!NOTE]
> A verdict of `hardwareUnmeasured` is not a warning. It means no measurement covers this device, which is what `GlassHardware.detect()` returns everywhere except Apple platforms.

## Hardware and thermals

- **`GlassHardware`** tells the package whose measurements apply: `appleMetal` (detected on iOS and macOS), `adrenoVulkan` (Adreno 830-class only, declare it yourself), or `unmeasured`. It changes reported costs, never rendering decisions.
- **`GlassThermalState`** is the device's thermal pressure, which **your app reads natively** and passes to `GlassHost.thermal`. At `serious` and `critical`, the host may reuse a slightly stale capture for a frame or two while content changes. Blurry finishes tolerate that; `clear` gets no staleness. Tiers are never changed by thermals.
- **`GlassThermalPolicy`** sets how much staleness each state may spend. `GlassThermalPolicy.never` keeps every frame fresh.

## Debugging

Set the top-level `debugPaintGlassSurfaces = true` (debug builds only, like `debugPaintSizeEnabled`) to outline every registered glass surface. It's the quickest way to spot glass you didn't know was there.

## Complete example

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A debug overlay that reads what the host's ledger says about the screen.
/// Put it anywhere under the GlassHost.
class GlassLoadBadge extends StatefulWidget {
  const GlassLoadBadge({super.key});

  @override
  State<GlassLoadBadge> createState() => _GlassLoadBadgeState();
}

class _GlassLoadBadgeState extends State<GlassLoadBadge> {
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    // Geometry is read on demand (the ledger does not notify when glass
    // moves), so poll it rather than rebuild on every frame.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlassLedger? ledger = GlassScope.maybeOf(context);
    if (ledger == null) {
      return const SizedBox.shrink();
    }
    final GlassLoad load = ledger.read(
      viewSize: MediaQuery.sizeOf(context),
      model: GlassHardware.detect().surfaceCostModel,
    );
    return Text(
      '${load.surfaceCount} surfaces · '
      '${load.screensOfGlass.toStringAsFixed(2)} screens of glass · '
      '${load.verdict.name}',
    );
  }
}

/// The host, told what the package cannot read for itself.
Widget performantHost(Widget child, {required GlassThermalState thermal, bool snapdragon = false}) => GlassHost(
  // Whose measurements apply: changes reported costs, never correctness.
  hardware: snapdragon ? GlassHardware.adrenoVulkan : GlassHardware.detect(),
  // Read natively by the app and passed in; under pressure the host may
  // reuse a slightly stale capture for a frame or two.
  thermal: thermal,
  thermalPolicy: const GlassThermalPolicy(),
  child: child,
);
```

## API

`GlassLedger` (reach it with `GlassScope.maybeOf(context)`; you never construct one):

| Member | Type | Description |
|---|---|---|
| `read({required Size viewSize, required GlassSurfaceCostModel model})` | `GlassLoad` | Reads the register against one platform's measurements. |
| `registeredCount` | `int` | How many surfaces are registered. |
| `surfaces` | `Iterable<GlassSurfaceRecord>` | Every surface that can say where it is, read now. |
| `bounds` | `Rect?` | What one capture covering every surface would span. |

`GlassLoad` (main fields):

| Field | Type | Description |
|---|---|---|
| `surfaceCount` | `int` | Glass surfaces on the screen. |
| `capturedSurfaceCount` | `int` | Of those, how many read a capture (full tier). |
| `screensOfGlass` | `double` | Total glass area divided by the screen's area. |
| `rectAreaLogical` / `shapeAreaLogical` | `double` | Glass area as boxes and as shapes, in logical px². |
| `taxCycles` | `double?` | Estimated GPU cost, where measured (Adreno only). |
| `verdict` | `GlassLoadVerdict` | `withinMeasured`, `pastMeasuredRange`, `betweenMeasuredPoints`, `overMeasuredCliff` or `hardwareUnmeasured`. |

`GlassHost` parameters that matter here:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `hardware` | `GlassHardware?` | `null` (`GlassHardware.detect()`) | `appleMetal`, `adrenoVulkan` or `unmeasured`. Affects reported costs only. |
| `thermal` | `GlassThermalState?` | `null` (nominal) | `nominal`, `fair`, `serious` or `critical`, as read by your app. |
| `thermalPolicy` | `GlassThermalPolicy` | `const GlassThermalPolicy()` | How much staleness each thermal state may spend. |

`const GlassThermalPolicy({double fairDeltaE = 0, double seriousDeltaE = 0.02 * kMaterialScaleDeltaE, double criticalDeltaE = 0.04 * kMaterialScaleDeltaE})`: the allowed staleness per state, as a colour difference (ΔE): about 0.70 at `serious` and 1.39 at `critical` by default. `GlassThermalPolicy.never` allows none.

### Debug flag

| Name | Type | Default | Description |
|---|---|---|---|
| `debugPaintGlassSurfaces` | `bool` | `false` | Outlines every registered glass surface. Debug builds only. |
