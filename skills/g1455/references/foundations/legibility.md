# Legibility & theme

> How glass components choose black or white labels, keep them readable, and how a subtree gets its own look.

- Live: https://g1455.plugfox.dev/foundations/legibility
- API: [`GlassTheme`](https://pub.dev/documentation/g1455/latest/g1455/GlassTheme-class.html), [`GlassThemeData`](https://pub.dev/documentation/g1455/latest/g1455/GlassThemeData-class.html), [`GlassLegibility`](https://pub.dev/documentation/g1455/latest/g1455/GlassLegibility-class.html), [`kTextContrastAA`](https://pub.dev/documentation/g1455/latest/g1455/kTextContrastAA-constant.html)
- Source: [`lib/src/surface/glass_theme.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_theme.dart)

Text on glass sits over whatever the glass sits over, so its colour cannot be fixed in advance. The components
([GlassBar](../components/bar.md), [GlassButton](../components/button.md), [GlassCard](../components/card.md), the
[text field](../components/text-field.md), the [alert](../components/alert.md), the [menu](../components/menu.md) and the
[popover](../components/popover.md)) choose black or white for their labels, from the finish and from what you told the host
is behind the glass.

All of that lives in a `GlassTheme`: the host installs one, and you can nest another to give a subtree its own finish,
tier or backdrop.

## When to use

- Declare the backdrop on the host, always: `backdrop:` for a flat colour, `richBackdrop: true` for images and feeds.
- Add `minLabelContrast: kTextContrastAA` when text sits on clear glass or over bright content.
- Nest a `GlassTheme` below the host when one part of a screen differs: a light panel, a cheaper list.
- Read `GlassTheme.of(context).legibility()` when you put your own text on a raw `GlassSurface`.
- Don't put a `GlassTheme` above the host: the host installs its own and overrides it.

## Usage

```dart
// A panel over a light page, below the app's host.
GlassTheme(
  data: GlassTheme.of(context).copyWith(
    backdrop: const Color(0xFFF2F2F7),
    finish: GlassFinish.regularLight,
  ),
  child: const GlassCard(child: Text('Black text, chosen for you')),
)
```

## How the label is chosen

- **A flat backdrop** (`backdrop:` declared, `richBackdrop` false): the label is whichever of black or white stands out
  more against the glass laid over that colour. Exact, because every pixel under the glass is that colour.
- **A rich backdrop**, or **none declared**: the label is whichever has the better *worst* case over any backdrop. In
  debug, the package warns once when that worst case cannot reach WCAG AA.
- **A contrast floor** (`minLabelContrast:`): when neither colour reaches it, the glass is dimmed by the least amount
  that does. Dimming is a change of tint, so it costs nothing to draw. `regularDark` needs no dim for AA over any
  backdrop; `clear` does.

Glass with `labelled: false` has no label to protect and is never dimmed.

The demo shows it: drag the backdrop from dark to light and watch the label flip and the contrast change, then switch
the floor on with clear glass.

## Custom glass

A raw `GlassSurface` does not colour its child. Ask the theme:

```dart
final GlassLegibility look = GlassTheme.of(context).legibility(GlassFinish.clear);
Text('Now playing', style: TextStyle(color: look.label));
```

`look.finish` is the finish actually drawn (dimmed, if a floor asked for it), and `look.rim` the opaque outline under
increased contrast, or null.

## Glass that reads its backdrop

Everything above goes by what you declared: one `backdrop` for the whole screen. Over photographs, where one bar sits
on a bright sky and a button on a dark shadow, let each glass read what is under it instead with
`GlassHost(adaptive: GlassAdaptive())`. See [Adaptive glass](../foundations/adaptive.md).

> [!NOTE]
> `GlassThemeData.copyWith` cannot set a nullable field back to null. To drop `minLabelContrast` or `backdrop` for a
> subtree, build a new `GlassThemeData`.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A light settings panel inside a dark app, and custom glass that reads
/// its label colour from the theme. Assumes a GlassHost above.
class LightPanel extends StatelessWidget {
  const LightPanel({super.key});

  static const Color page = Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    final GlassThemeData outer = GlassTheme.of(context);
    return ColoredBox(
      color: page,
      child: GlassTheme(
        // Inherit the host's tier and contrast; only the backdrop and finish differ.
        data: outer.copyWith(
          backdrop: page,
          richBackdrop: false,
          finish: GlassFinish.regularLight,
          minLabelContrast: kTextContrastAA,
        ),
        child: Builder(
          builder: (BuildContext context) {
            final GlassLegibility look = GlassTheme.of(context).legibility(GlassFinish.clear);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // A component picks its own label colour.
                const GlassCard(child: Text('Notifications')),
                const SizedBox(height: 16),
                // A raw surface: take the colour from the theme.
                SizedBox(
                  width: 200,
                  height: 56,
                  child: GlassSurface(
                    borderRadius: kGlassCapsule,
                    finish: GlassFinish.clear,
                    child: Center(
                      child: Text('Clear glass', style: TextStyle(color: look.label)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `finish` | `GlassFinish` | `GlassFinish.regularDark` | The material every surface below wears unless it names its own. |
| `tier` | `GlassTierChoice` | `GlassTierChoice.byDefault` | Which rung is drawn: full, cheap or opaque. |
| `backdrop` | `Color?` | `null` | The average colour behind the glass. Chooses the label over a flat page; fills the opaque tier. |
| `highContrast` | `bool` | `false` | Draws an opaque outline instead of the calibrated rim. |
| `richBackdrop` | `bool` | `false` | The backdrop is an image or feed: labels are chosen for the worst case. |
| `minLabelContrast` | `double?` | `null` | The least label contrast. The glass is dimmed just enough to meet it. |
| `ripple` | `GlassRipple?` | `null` | The default touch wave. |
| `dropMotion` | `GlassDropMotion` | `GlassDropMotion()` | How held drops stretch and squash. See [Drop motion](../foundations/drop-motion.md). |
| `adaptive` | `GlassAdaptive?` | `null` | Whether glass reads its backdrop. Installed by `GlassHost.adaptive`. See [Adaptive glass](../foundations/adaptive.md). |
| `regularAppearance` | `Brightness?` | `null` | The appearance `finish` was picked in when it is `.regular` and nobody named it. Set by an adaptive host. |
| `reading` | `GlassBackdropReading?` | `null` | What the glass this theme was installed for read of its backdrop. |

### GlassTheme

| Member | Description |
|---|---|
| `GlassTheme({required GlassThemeData data, required Widget child})` | Gives a subtree its own glass configuration. Must be below the host. |
| `GlassTheme.of(context)` | The theme in force, or the defaults with the platform's `.regular` branch. |
| `GlassTheme.maybeOf(context)` | The theme in force, or null. |
| `GlassThemeData.legibility([GlassFinish? own, bool labelled = true])` | The finish to draw, the label colour and the outline, for this theme. |

### GlassLegibility

| Field | Type | Description |
|---|---|---|
| `finish` | `GlassFinish` | The finish to draw: the declared one, or it dimmed to meet the floor. |
| `label` | `Color` | Black or white, whichever reads best. |
| `rim` | `Color?` | The opaque outline under increased contrast, or null. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kTextContrastAA` | `4.5` | WCAG AA for body text. |
| `kNonTextContrast` | `3` | WCAG's floor for non-text elements. |
