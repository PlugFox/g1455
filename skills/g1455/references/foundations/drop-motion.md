# Drop motion

> The held drop of the switch, slider, segmented control and tab bar stretches as it sets off, squashes as it stops and springs back round. One spec for the app, or per control.

- Live: https://g1455.plugfox.dev/foundations/drop-motion
- API: [`GlassDropMotion`](https://pub.dev/documentation/g1455/latest/g1455/GlassDropMotion-class.html), [`GlassDropStretch`](https://pub.dev/documentation/g1455/latest/g1455/GlassDropStretch-class.html), [`GlassDropStretchDriver`](https://pub.dev/documentation/g1455/latest/g1455/GlassDropStretchDriver-class.html)
- Source: [`lib/src/surface/glass_drop_motion.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_drop_motion.dart)

Four controls lift their selection into a clear glass drop while a finger is on it: the [switch](../components/switch.md),
the [slider](../components/slider.md), the [segmented control](../components/segmented-control.md) and the
[tab bar](../components/tab-bar.md). `GlassDropMotion` makes that drop move like a liquid: long and thin as it sets off,
short and fat as it stops, then a little wobble back to round.

It is on by default. At rest, and gliding at a constant speed, the drop keeps its shape: only speeding up and slowing
down deform it.

## When to use

- Leave the default on for the feel of iOS 26, whose held drops lean into a fast slide and bulge as they stop.
- Turn it down, or off with `GlassDropMotion.none`, for a calmer app or a dense, serious UI.
- Turn it up for a playful one. It never deforms more than `maxStretch` (at most 0.5).

## Usage

For every control in the app, on the host:

```dart
GlassHost(
  dropMotion: const GlassDropMotion(maxStretch: 0.2),
  child: child!,
)
```

For one control, which wins over the theme's:

```dart
GlassTabBar(
  items: tabs,
  selectedIndex: tab,
  onSelected: (int i) => setState(() => tab = i),
  dropMotion: GlassDropMotion.none,
)
```

A `GlassTheme` below the host can set `dropMotion:` for a subtree through `GlassThemeData`, like the ripple.

## Behaviour

- **It follows the acceleration.** The drop is stretched along its travel while it speeds up, in either direction, and
  squashed while it slows down. The deformation keeps the drop's area: `w × (1 + s)` by `h / (1 + s)`.
- **It saturates.** At `saturation` (10 000 px/s²) the stretch reaches three quarters of `maxStretch`, and it eases
  towards `maxStretch` past it. With the defaults a tab bar's drop springing one tab over is about 7% long setting off
  and 5% short arriving; three tabs over, about 11% and 12%. The switch's short throw deforms only about 3%.
- **It springs back.** The shape follows its target through a spring (`stiffness` 900, `damping` 30, a damping ratio
  of 0.5): a little jelly, back to round in about half a second.
- **Reduced motion turns it off**, whatever was declared.

The demo puts all four controls on one spec. Tap a far segment or tab and watch the drop lean into the move.

## Cost

- **No capture.** The drop changes shape inside the [travel](../foundations/travel.md) region it already moves in. Each
  control grows that region by the most the spec can stretch the drop, so the deformation never leaves it.
- **A repaint of the drop's own layer** on the frames it deforms: the same one draw a frame.
- **A ticker** while the drop moves or springs back, and none at rest or while a finger holds it still.

## Your own drop

`GlassDropStretch` is the model alone, with no widget and no ticker: feed it where your drop is with `step(dt, x)` and
draw `GlassDropStretch.apply(size, value)`. `GlassDropStretchDriver` runs one off a ticker, as the package's controls
do: call `wake()` when the drop moves, and listen for `value`.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const DropApp());

class DropApp extends StatelessWidget {
  const DropApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (BuildContext context, Widget? child) => GlassHost(
      // Every drop in the app: a little more stretch, a little less wobble.
      dropMotion: const GlassDropMotion(maxStretch: 0.18, damping: 40),
      child: child!,
    ),
    home: const SettingsPage(),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _range = 0;
  double _volume = 0.4;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101014),
    body: Center(
      child: SizedBox(
        width: 320,
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Takes the host's motion.
              GlassSegmentedControl(
                segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
                selectedIndex: _range,
                onSelected: (int i) => setState(() => _range = i),
              ),
              const SizedBox(height: 16),
              // Names its own: this drop keeps its shape.
              GlassSlider(
                value: _volume,
                dropMotion: GlassDropMotion.none,
                onChanged: (double v) => setState(() => _volume = v),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

## API

`const GlassDropMotion({...})`. Every field is optional.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `maxStretch` | `double` | `0.12` | The most the drop stretches or squashes: 0.12 is up to 12% longer launching and 12% shorter braking. From 0 to 0.5; 0 is `none`. |
| `saturation` | `double` | `10000` | The acceleration, in px/s², that takes the drop to three quarters of `maxStretch`. Must be > 0. |
| `smoothing` | `Duration` | `Duration(milliseconds: 16)` | The time constant of the low-pass on the velocity and the acceleration. |
| `stiffness` | `double` | `900` | The spring the shape follows its target with, at unit mass. Must be > 0. |
| `damping` | `double` | `30` | The spring's damping. With 900, a damping ratio of 0.5. Must be ≥ 0. |

| Member | Description |
|---|---|
| `GlassDropMotion.none` | No deformation: the drop keeps the shape it is held at. |
| `isNone` | Whether this deforms nothing. |
| `GlassDropMotion.resolve(context, declared)` | What a control uses: its own, else the theme's, and `none` under reduced motion. |
| `copyWith(...)` | Every field. |

Where it goes: `GlassHost.dropMotion` and `GlassThemeData.dropMotion` (`GlassDropMotion`, default `GlassDropMotion()`),
and `dropMotion` on `GlassSwitch`, `GlassSlider`, `GlassSegmentedControl` and `GlassTabBar` (`GlassDropMotion?`,
`null` takes the theme's).

### GlassDropStretch

| Member | Description |
|---|---|
| `GlassDropStretch([GlassDropMotion motion = const GlassDropMotion()])` | The model of one drop. `motion` may be replaced. |
| `double step(double dt, double x)` | Advances `dt` seconds to a drop at `x` px along its travel; returns `value`. |
| `void jump(double x)` | The drop is at `x` without having travelled there. |
| `void reset()` | Round, still, and the next `step` is a first sample. |
| `value` | The deformation, from `-maxStretch` (squashed) to `maxStretch` (stretched). |
| `isSettled` | Round, still and heading nowhere. |
| `static Size apply(Size size, double stretch)` | `size` deformed along x, the area kept. |

### GlassDropStretchDriver

| Member | Description |
|---|---|
| `GlassDropStretchDriver({required TickerProvider vsync, required double Function() position})` | Runs a `GlassDropStretch` off a ticker. A `ChangeNotifier`: notifies when `value` changes. |
| `motion` | The spec. Set it from `GlassDropMotion.resolve` in `didChangeDependencies`. |
| `void wake()` | The drop moved: sample it every frame until it settles. |
| `void jump()` | The drop is where it is without having travelled there. |
| `value` | The deformation to draw. |
