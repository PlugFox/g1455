What the glass costs, and the rungs below full glass.

## The tiers

[GlassTier](../g1455/GlassTier.html) is the rung: full glass, a flat translucent fill that captures
nothing ([GlassTier.cheap](../g1455/GlassTier.html)), or an opaque fill ([GlassTier.opaque](../g1455/GlassTier.html)). The
package never moves between them on its own; a [GlassTierPolicy](../g1455/GlassTierPolicy-class.html) chooses from
what the application knows:

```dart
GlassHost(
  backdrop: const Color(0xFF101014), // what the opaque tier fills with
  tier: GlassTierPolicy(
    reduceTransparency: reduceTransparency, // read natively by the app
    ceiling: lowEndDevice ? GlassTier.cheap : null,
  ).choose(),
  child: navigator!,
)
```

## The device

Flutter does not pass on reduce transparency, contrast on macOS or the thermal
state, and the package ships no platform code. Read them natively and declare
them: [GlassThermalState](../g1455/GlassThermalState.html) to [GlassHost.thermal](../g1455/GlassHost/thermal.html), [GlassHardware](../g1455/GlassHardware.html) to
[GlassHost.hardware](../g1455/GlassHost/hardware.html). Hardware changes reported costs, never what is drawn.

## The ledger

[GlassLedger](../g1455/GlassLedger-class.html) is the host's register of every glass on screen. Read it through
[GlassScope](../g1455/GlassScope-class.html) to get a [GlassLoad](../g1455/GlassLoad-class.html): the count, the area, *screens of glass*, and
a [GlassLoadVerdict](../g1455/GlassLoadVerdict.html) against what was measured on that hardware.

```dart
final GlassLoad? load = GlassScope.maybeOf(context)?.read(
  viewSize: MediaQuery.sizeOf(context),
  model: GlassHardware.detect().surfaceCostModel,
);
debugPrint('$load'); // GlassLoad(6 surfaces, 0.12 screens, withinMeasured)
```

## The capture's resolution

The host chooses the downscale of its capture per finish, against measured
quality tables: [ProxyResolutionPolicy](../g1455/ProxyResolutionPolicy-class.html), [ProxyResolution](../g1455/ProxyResolution-class.html) and the reason it
gives, [ProxyDivisorReason](../g1455/ProxyDivisorReason.html). Whether it may hold a capture nothing under the
glass changed is [GlassContentDeclaration](../g1455/GlassContentDeclaration.html); why it took one is [RetakeReason](../g1455/RetakeReason.html).

## Where the numbers come from

Every measured number in this reference was taken in a profile build on the
device named, on Flutter 3.47.1: a Samsung Galaxy S25 Ultra (Adreno 830,
Vulkan), an iPad Pro 11″ M2 (Metal), a Galaxy S22 Ultra (Xclipse 920) and a
MacBook Pro M3 Max, between 2026-08-24 and 2026-09-26. The full table is in the
[README](https://github.com/PlugFox/g1455#where-the-numbers-come-from), and the
raw digests in the repository's
[`provenance/`](https://github.com/PlugFox/g1455/tree/master/provenance).
