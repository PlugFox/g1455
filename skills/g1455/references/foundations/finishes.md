# Finishes

> The material of the glass: regular dark and light, clear and frosted, calibrated against Apple's iOS 26 materials.

- Live: https://g1455.plugfox.dev/foundations/finishes
- API: [`GlassFinish`](https://pub.dev/documentation/g1455/latest/g1455/GlassFinish-class.html), [`GlassOptics`](https://pub.dev/documentation/g1455/latest/g1455/GlassOptics-class.html), [`kCalibratedRim`](https://pub.dev/documentation/g1455/latest/g1455/kCalibratedRim-constant.html)
- Source: [`lib/src/surface/glass_finish.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_finish.dart)

A `GlassFinish` is the material the glass is made of: how much it blurs, the tint it lays over the refracted backdrop,
the rim along its edge, and the shape of the refraction (`GlassOptics`). The presets are calibrated against Apple's own
materials on iOS 26.

A finish can be set for the whole app (`GlassHost.finish`), for a subtree (a [GlassTheme](../foundations/legibility.md)
below the host), or for one surface (`finish:` on any component or `GlassSurface`).

## The presets

| Preset | Blur σ | Tint | What it is |
|---|---|---|---|
| `GlassFinish.regularDark` | 2.6 | `rgba(29, 29, 32, 0.693)` | Apple's `.regular` over dark content. |
| `GlassFinish.regularLight` | 2.6 | `rgba(252, 252, 252, 0.718)` | Apple's `.regular` over light content. |
| `GlassFinish.clear` | 0 | `rgba(249, 249, 249, 0.22)` | No blur and very transparent: the clearest glass, and the hardest to read text on. |
| `GlassFinish.frosted` | 8 | `rgba(249, 249, 249, 0.22)` | A heavy blur and a light tint, closer to the older iOS blur material. |

Apple's `.regular` is two materials, dark over dark content and light over light. `GlassFinish.regular(appearance:,
backdrop:)` picks the branch the way Apple does, and it is what the host uses when you name no finish.

## When to use

- **Regular** (the default) for bars, cards, buttons and anything carrying text.
- **Clear** for lenses, drops and media overlays, where the content should show through. Pair it with
  `minLabelContrast` when text sits on it; see [Legibility & theme](../foundations/legibility.md).
- **Frosted** when the content behind should be suggested rather than seen.
- Don't invent a new `name`. The name keys the package's measured quality and cost tables, and an unknown name falls
  back to a full-resolution capture, which is slower.

## Usage

```dart
// A brand tint that keeps the measured name, so the tables still apply.
final GlassFinish brand = GlassFinish.regularDark.copyWith(
  tint: const Color.fromRGBO(20, 30, 60, 0.6),
);

GlassCard(finish: GlassFinish.clear, child: Text('Clear'))
```

## Tint and optics

- **Tint**: the alpha is how opaque the glass is, the colour is its hue. To tint glass for a brand, `copyWith` a
  preset's tint and keep its alpha, as the demo does.
- **Rim**: added along a 0.79 px outline (`kCalibratedRim` by default). It is also the press highlight of
  [GlassButton](../components/button.md).
- **Optics**: `GlassOptics(thickness:, strength:, edgePower:, shoulder:, widen:, zoom:)` shapes the bend.
  `strength` is the peak bend at the rim in pixels, negative being inward (Apple's direction); `zoom` magnifies about
  the centre, which is how a lens is made. `GlassOptics.none` turns the bend off.

> [!NOTE]
> The demo sets the tint and the backdrop for its own panels only. The menu at the top of the site sets the finish and
> tint of the whole site through the host.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// The four presets side by side, plus a brand-tinted one.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class FinishSwatches extends StatelessWidget {
  const FinishSwatches({super.key});

  /// Indigo glass that keeps regularDark's name, alpha and optics.
  static final GlassFinish brand = GlassFinish.regularDark.copyWith(
    tint: const Color(0xFF28348C).withValues(alpha: GlassFinish.regularDark.tint.a),
    optics: const GlassOptics(strength: -40),
  );

  static final List<(String, GlassFinish)> finishes = <(String, GlassFinish)>[
    ('Regular dark', GlassFinish.regularDark),
    ('Regular light', GlassFinish.regularLight),
    ('Clear', GlassFinish.clear),
    ('Frosted', GlassFinish.frosted),
    ('Brand', brand),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      for (final (String name, GlassFinish finish) in finishes)
        SizedBox(
          width: 140,
          height: 96,
          // GlassCard picks black or white text for each finish.
          child: GlassCard(
            finish: finish,
            child: Align(alignment: Alignment.bottomLeft, child: Text(name)),
          ),
        ),
    ],
  );
}

/// Apple's two-branch `.regular`, chosen from the appearance and the page colour.
Widget regularHost(BuildContext context, Widget page) => GlassHost(
  finish: GlassFinish.regular(
    appearance: MediaQuery.platformBrightnessOf(context),
    backdrop: const Color(0xFFF2F2F7),
  ),
  backdrop: const Color(0xFFF2F2F7),
  child: page,
);
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | **required** | Key into the measured quality and cost tables. Use a preset's name. |
| `blurSigmaLogical` | `double` | **required** | The blur, in logical pixels. |
| `tint` | `Color` | **required** | Laid over the refracted backdrop. Its alpha is how opaque the glass is. |
| `rim` | `Color` | `kCalibratedRim` | Added along the 0.79 px outline; also the button press highlight. |
| `optics` | `GlassOptics` | `GlassOptics()` | The shape of the refraction. |

### GlassOptics

| Parameter | Type | Default | Description |
|---|---|---|---|
| `thickness` | `double` | `21` | How far in from the rim the refraction reaches, in pixels. |
| `strength` | `double` | `-58.2` | Peak bend at the rim, in pixels. Negative is inward; closer to 0 is subtler. |
| `edgePower` | `double` | `1.9` | Falloff exponent. |
| `shoulder` | `double` | `0.6` | Falloff shape exponent. |
| `widen` | `double` | `0` | Shows backdrop from this many pixels beyond the box, which minifies. |
| `zoom` | `double` | `1` | Magnification about the centre. Must be greater than 0. |

### Presets and methods

| Name | Description |
|---|---|
| `GlassFinish.regularDark` | Blur 2.6, tint `rgba(29, 29, 32, 0.693)`. Apple's `.regular` over dark content. |
| `GlassFinish.regularLight` | Blur 2.6, tint `rgba(252, 252, 252, 0.718)`. Apple's `.regular` over light content. |
| `GlassFinish.clear` | Blur 0, tint `rgba(249, 249, 249, 0.22)`. |
| `GlassFinish.frosted` | Blur 8, tint `rgba(249, 249, 249, 0.22)`. |
| `GlassFinish.identity` | Invisible: no blur, no tint, no rim, no bend. For tests. |
| `GlassFinish.regular({required Brightness appearance, Color? backdrop})` | Picks `regularDark` or `regularLight` the way Apple does. |
| `copyWith({name, blurSigmaLogical, tint, rim, optics})` | A variation that keeps everything you don't name. |
| `GlassOptics.none` | No bend at all. |
