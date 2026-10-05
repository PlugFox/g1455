import '../catalog.dart';

const List<Entry> kFoundationEntriesB = <Entry>[
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'ripple',
    title: 'Ripple',
    icon: 'waves',
    summary:
        'An optional liquid wave when glass is touched, from water to honey. Not an Apple behaviour, '
        'off under reduced motion, and it costs no capture.',
    api: <String>['GlassRipple', 'kMaxRippleWaves'],
    source: 'lib/src/surface/glass_ripple.dart',
    guide: r'''
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
- **It switches itself off** when the platform asks for reduced motion (`MediaQuery.disableAnimations`), for members of a fusing [group](/foundations/groups), and below the full [tier](/foundations/tiers).
- The defaults were chosen by eye. There is no platform reference to measure them against.

## Performance

A wave changes how the captured backdrop is sampled, not the backdrop itself, so it **takes no capture and repaints nothing**. The ripple has its own shader, which runs only on frames where a wave is alive. A surface at rest draws exactly as it would without a ripple.

> [!TIP]
> Glass without text, like the panel in the demo, should set `labelled: false`. Otherwise a clear finish may be dimmed to keep labels legible, and the wave is harder to see.
''',
    code: r'''
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
''',
    properties: r'''
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

## Constants

| Name | Value | Description |
|---|---|---|
| `kMaxRippleWaves` | `4` | The most waves one surface draws at once. |
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'drop-motion',
    title: 'Drop motion',
    icon: 'water_drop',
    summary:
        'The held drop of the switch, slider, segmented control and tab bar stretches as it sets off, squashes as it '
        'stops and springs back round. One spec for the app, or per control.',
    api: <String>['GlassDropMotion', 'GlassDropStretch', 'GlassDropStretchDriver'],
    source: 'lib/src/surface/glass_drop_motion.dart',
    guide: r'''
Four controls lift their selection into a clear glass drop while a finger is on it: the [switch](/components/switch),
the [slider](/components/slider), the [segmented control](/components/segmented-control) and the
[tab bar](/components/tab-bar). `GlassDropMotion` makes that drop move like a liquid: long and thin as it sets off,
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

- **No capture.** The drop changes shape inside the [travel](/foundations/travel) region it already moves in. Each
  control grows that region by the most the spec can stretch the drop, so the deformation never leaves it.
- **A repaint of the drop's own layer** on the frames it deforms: the same one draw a frame.
- **A ticker** while the drop moves or springs back, and none at rest or while a finger holds it still.

## Your own drop

`GlassDropStretch` is the model alone, with no widget and no ticker: feed it where your drop is with `step(dt, x)` and
draw `GlassDropStretch.apply(size, value)`. `GlassDropStretchDriver` runs one off a ticker, as the package's controls
do: call `wake()` when the drop moves, and listen for `value`.
''',
    code: r'''
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
''',
    properties: r'''
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

## GlassDropStretch

| Member | Description |
|---|---|
| `GlassDropStretch([GlassDropMotion motion = const GlassDropMotion()])` | The model of one drop. `motion` may be replaced. |
| `double step(double dt, double x)` | Advances `dt` seconds to a drop at `x` px along its travel; returns `value`. |
| `void jump(double x)` | The drop is at `x` without having travelled there. |
| `void reset()` | Round, still, and the next `step` is a first sample. |
| `value` | The deformation, from `-maxStretch` (squashed) to `maxStretch` (stretched). |
| `isSettled` | Round, still and heading nowhere. |
| `static Size apply(Size size, double stretch)` | `size` deformed along x, the area kept. |

## GlassDropStretchDriver

| Member | Description |
|---|---|
| `GlassDropStretchDriver({required TickerProvider vsync, required double Function() position})` | Runs a `GlassDropStretch` off a ticker. A `ChangeNotifier`: notifies when `value` changes. |
| `motion` | The spec. Set it from `GlassDropMotion.resolve` in `didChangeDependencies`. |
| `void wake()` | The drop moved: sample it every frame until it settles. |
| `void jump()` | The drop is where it is without having travelled there. |
| `value` | The deformation to draw. |
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'groups',
    title: 'Groups & unions',
    icon: 'bubble_chart',
    summary:
        'Draw several glass surfaces as one piece of liquid glass: GlassGroup fuses them when they come close, '
        'GlassUnion keeps them joined at any distance.',
    api: <String>[
      'GlassGroup',
      'GlassUnion',
      'kMaxFusedShapes',
      'unionBlendRadius()',
      'GlassBlendGroup',
      'GlassGroupScope',
    ],
    source: 'lib/src/surface/glass_group.dart',
    guide: r'''
A `GlassGroup` draws every `GlassSurface` inside it as **one piece of glass**, like SwiftUI's `GlassEffectContainer`. Members closer than `spacing` grow a smooth bridge and merge into one silhouette, then separate again as they move apart. A member whose `presence` animates up from 0 "buds" out of its neighbours instead of appearing on its own.

A `GlassUnion` is the always-joined variant, like SwiftUI's `glassEffectUnion`. Its members form **one connected piece however far apart they are**. The blend radius is solved so that everyone just connects, so the further apart the members, the puffier the whole silhouette.

## When to use

- **GlassGroup:** the merging-blob look, or controls that should visibly melt together as they approach (a button that buds out of a bar, a drop that leaves its track).
- **GlassUnion:** separated controls that must read as one glass object, such as a split pill or a cluster of buttons.
- **Not** as a performance trick. A group costs *more* than the same surfaces drawn separately, and `spacing: 0` shares a draw but saves nothing.
- **Not** around your page background. Everything inside the group paints on top of the glass.

## Usage

```dart
// Two circles that fuse when they are within 16 px of each other.
GlassGroup(
  spacing: 16,
  labelled: false,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(width: 56, height: 56, child: GlassSurface(borderRadius: kGlassCapsule)),
      SizedBox(width: 8),
      SizedBox(width: 56, height: 56, child: GlassSurface(borderRadius: kGlassCapsule)),
    ],
  ),
);
```

Swap `GlassGroup` for `GlassUnion` (it has no `spacing`) and the two stay joined however far apart you put them.

## Behaviour

- **One finish per group.** The group's `finish` (or the host's) is used for every member. A member's own `finish` is ignored, with a debug warning once.
- **At most [`kMaxFusedShapes`](https://pub.dev/documentation/g1455/latest/g1455/kMaxFusedShapes-constant.html) (12) members fuse.** A bigger group stops fusing, and its members draw separately without bridges.
- **The nearest group wins.** A union nested inside a group takes its members out of the group.
- **Below the full [tier](/foundations/tiers), nothing fuses**: the bridges disappear and members draw as separate shapes.
- `fade` and `ripple` are not drawn on fused members.
- Raw `GlassSurface` members don't pick a label colour for you. Set text colours yourself, or put components such as `GlassButton` inside.

## Moving members

Blobs that orbit or follow a finger move over still content, so wrap them in a [`GlassTravel`](/foundations/travel) and a `RepaintBoundary`, like the demo above. The motion then costs no capture.

## Plumbing

`GlassBlendGroup` is the membership object behind a group or union, and `GlassGroupScope` is the inherited widget that hands it to the surfaces below. You don't build these yourself, but `GlassGroupScope.maybeOf(context) != null` tells a widget whether it is inside a group. `unionBlendRadius(boxes, radii)` returns the blend radius a union would use for those boxes.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Blobs that fuse, one that buds, and a split pill. Assumes a GlassHost above.
class FusingControls extends StatefulWidget {
  const FusingControls({super.key});

  @override
  State<FusingControls> createState() => _FusingControlsState();
}

class _FusingControlsState extends State<FusingControls> {
  bool _third = false;

  Widget _blob(double size, {double presence = 1}) => SizedBox(
    width: size,
    height: size,
    child: GlassSurface(borderRadius: kGlassCapsule, presence: presence, labelled: false),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // Members closer than `spacing` grow a bridge and fuse.
      GlassGroup(
        spacing: 20,
        finish: GlassFinish.clear,
        labelled: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _blob(64),
            const SizedBox(width: 12),
            _blob(64),
            const SizedBox(width: 12),
            // Animating presence from 0 makes it bud out of its neighbours.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _third ? 1 : 0),
              duration: const Duration(milliseconds: 400),
              builder: (BuildContext context, double p, Widget? _) => _blob(48, presence: p),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      // A union is always one piece, however far apart its members are.
      SizedBox(
        width: 280,
        child: GlassUnion(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 48,
                height: 48,
                child: GlassSurface(
                  borderRadius: kGlassCapsule,
                  child: IconButton(
                    onPressed: () => setState(() => _third = !_third),
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 160,
                height: 48,
                child: GlassSurface(
                  borderRadius: kGlassCapsule,
                  child: Center(
                    child: Text('Now playing', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
''',
    properties: r'''
`GlassGroup`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree that contains the member surfaces. |
| `spacing` | `double` | `0` | Edge-to-edge gap, in px, at which members fuse. `0` keeps shapes separate but shares one draw. |
| `finish` | `GlassFinish?` | `null` (the host's) | The finish of the whole group. Members' own finishes are ignored. |
| `labelled` | `bool` | `true` | Whether text sits on the glass. Set `false` for text-free blobs so the finish isn't dimmed. |

`GlassUnion`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The subtree that contains the member surfaces. |
| `finish` | `GlassFinish?` | `null` (the host's) | The finish of the whole union. |
| `labelled` | `bool` | `true` | As `GlassGroup.labelled`. |

Related: `double unionBlendRadius(List<Rect> boxes, List<double> radii)` returns the blend radius a union would use. `GlassGroupScope({required GlassBlendGroup group, required Widget child})` with `static GlassBlendGroup? maybeOf(BuildContext context)`.

## Constants

| Name | Value | Description |
|---|---|---|
| `kMaxFusedShapes` | `12` | The most members a group or union fuses. Past it, members draw separately. |
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'travel',
    title: 'Travel',
    icon: 'open_with',
    summary:
        'Declare the region moving glass travels in, so a dragged lens or a sliding knob is redrawn from the '
        'capture the host already holds instead of triggering a new one.',
    api: <String>['GlassTravel', 'GlassTravelScope', 'GlassTravelRegion'],
    source: 'lib/src/surface/glass_travel.dart',
    guide: r'''
`GlassTravel` is a performance hint: "glass inside this box may move anywhere within it." The host then captures the **whole box** once, and glass that moves inside it is redrawn from that capture instead of triggering a new one on every frame.

Without it, glass that moves over still content still costs a capture per frame, because each surface's slot in the capture is its own box plus a margin, and any move leaves it. The package can't see where a surface is *going*. `GlassTravel` is how you tell it.

The built-in [switch](/components/switch), [slider](/components/slider), [segmented control](/components/segmented-control) and [tab bar](/components/tab-bar) already use it for their drops.

## When to use

- A custom control or effect whose glass moves while the content under it stays still: a draggable lens, a custom knob, orbiting blobs.
- **Not** for glass that sits still. The capture becomes bigger for no benefit.
- **Not** as a cure for glass over content that is itself changing (a scrolling list, a video). When the content under the glass changes, the host re-captures regardless.

## Usage

```dart
SizedBox(
  width: 300,
  height: 60,
  child: GlassTravel(
    child: Stack(
      children: <Widget>[
        Positioned(left: x, top: 0, width: 60, height: 60, child: const GlassSurface(borderRadius: kGlassCapsule)),
      ],
    ),
  ),
);
```

`GlassTravel` is transparent to layout, paint and hit-testing. It only marks a region.

## Making motion free

The motion is free only if **moving the glass repaints nothing else**. A repaint anywhere under the glass looks like changed content and triggers a capture. So:

1. Put the content the glass moves over behind its own `RepaintBoundary`.
2. Put the moving glass behind another `RepaintBoundary`, inside the `GlassTravel`, with a parent that paints nothing of its own.

The example in the Code tab follows that layout. Turn the switch in the demo off and the lens looks exactly the same, but every frame of the drag now re-captures.

> [!NOTE]
> The declaration is a price, never a correctness claim. Glass that leaves the region is simply captured the normal way: correct, just not free.

## Plumbing

`GlassTravelScope` is the inherited widget that carries the region down to the surfaces, and `GlassTravelRegion` is the region itself. `GlassTravelScope.maybeOf(context)?.globalRect` gives its current rectangle in global logical pixels. You don't need either to use `GlassTravel`.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A magnifier you drag over a photo. Inside GlassTravel the drag costs no
/// capture: the lens is redrawn from the capture the host already holds.
/// Assumes a GlassHost above.
class Magnifier extends StatefulWidget {
  const Magnifier({super.key, required this.photo});

  final ImageProvider photo;

  @override
  State<Magnifier> createState() => _MagnifierState();
}

class _MagnifierState extends State<Magnifier> {
  static const double _lens = 96;
  Offset _at = const Offset(120, 120);

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      // The content, behind its own boundary: the drag repaints none of it.
      Positioned.fill(
        child: RepaintBoundary(
          child: Image(image: widget.photo, fit: BoxFit.cover),
        ),
      ),
      // The region the lens may move in: the whole photo.
      Positioned.fill(
        child: GlassTravel(
          // The moving glass, behind a boundary of its own.
          child: RepaintBoundary(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: _at.dx - _lens / 2,
                  top: _at.dy - _lens / 2,
                  width: _lens,
                  height: _lens,
                  child: GestureDetector(
                    onPanUpdate: (DragUpdateDetails d) => setState(() => _at += d.delta),
                    child: GlassSurface(
                      borderRadius: kGlassCapsule,
                      labelled: false,
                      finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.5)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
''',
    properties: r'''
`GlassTravel`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The region. Glass that moves goes inside it. |

`GlassTravelScope` (plumbing):

| Parameter | Type | Default | Description |
|---|---|---|---|
| `region` | `GlassTravelRegion` | **required** | The region the surfaces below may move within. |
| `child` | `Widget` | **required** | The subtree. |

`static GlassTravelRegion? maybeOf(BuildContext context)` finds the nearest region. `GlassTravelRegion.globalRect` (`Rect?`) is where it is now, or `null` when it can't say.
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'above',
    title: 'Glass on glass',
    icon: 'arrow_upward',
    summary:
        'Glass inside other glass refracts it automatically. A bar floating over sibling glass, such as glass '
        'cards, needs GlassAbove to show them.',
    api: <String>['GlassAbove', 'kGlassModalLift'],
    source: 'lib/src/surface/glass_above.dart',
    guide: r'''
Glass can stand on other glass in two ways, and the package treats them differently.

- **Nested:** glass written *inside* other glass refracts it automatically. A `GlassButton` in a `GlassBar`, or the drop of a tab bar, shows the bar under it. Nothing to declare.
- **Siblings:** glass *beside* other glass in the tree doesn't see it. A bar floating over a list of `GlassCard`s is the cards' sibling, so on its own it shows the page with **the cards cut out**. Wrap the bar in `GlassAbove` and it refracts them.

The demo shows exactly that. Switch `GlassAbove` off and watch the bar as cards scroll under it.

## When to use

- Bars, tab bars, floating buttons and custom overlays over a page that has glass of its own.
- **Already done for you** by [`GlassScrollEdge`](/foundations/scroll-edge) (and the bar in its `child`), [dialogs](/components/alert), [sheets](/components/sheet), [menus](/components/menu) and [popovers](/components/popover).
- **Not needed** over plain content. It does no harm there and costs nothing.

## Usage

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: cardList), // a list of GlassCards
    const Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: GlassAbove(child: GlassBar(child: Text('Inbox'))),
      ),
    ),
  ],
);
```

## Levels

Every glass surface sits on a *level*: the number of glass surfaces it is written inside, plus the lifts above it. A level's capture draws all the glass of lower levels, which is how the bar gets to see the cards.

- `lift: 1` (the default) raises a bar above the page's glass.
- [`kGlassModalLift`](https://pub.dev/documentation/g1455/latest/g1455/kGlassModalLift-constant.html) (`2`) is for a modal-like layer that must also stand above bars that are themselves lifted. The package's own modals use it.

## Performance

Each occupied extra level costs **one more capture** on frames that re-capture. A lifted bar over plain content stays on level 0 and costs nothing extra; the levels that count are the ones with glass under them.

## Gotchas

- **Levels are a declaration, not paint order.** Glass *beside* a lifted subtree but painted on top of it still appears in its capture. A bar left unlifted next to a lifted scroll edge shows up blurred inside the edge, so lift such bars together (put the bar in `GlassScrollEdge.child`).
- Each lift is another capture level, so don't lift what has no glass under it "just in case" deep in a list.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Glass cards scrolling under a glass bar. Assumes a GlassHost above.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.subjects});

  final List<String> subjects;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 80, 16, safe.bottom + 16),
            itemCount: subjects.length,
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(child: Text(subjects[i])),
            ),
          ),
        ),
        Positioned(
          top: safe.top + 8,
          left: 16,
          right: 16,
          // The bar is a sibling of the cards, not their child: without
          // GlassAbove it would show the page with the cards cut out.
          child: GlassAbove(
            child: GlassBar(
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  // A button inside the bar is glass *on* the bar already:
                  // it refracts the bar with no GlassAbove of its own.
                  GlassButton(
                    onPressed: () {},
                    semanticLabel: 'Compose',
                    padding: EdgeInsets.zero,
                    child: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
''',
    properties: r'''
`GlassAbove`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `lift` | `int` | `1` | How many levels the glass below is raised. Must be > 0. |
| `child` | `Widget?` | `null` | The glass that stands on its neighbours. |

`GlassAbove` has no layout or paint of its own. It is a marker the host reads.

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassModalLift` | `2` | The lift of a modal layer (menu, dialog, sheet): above the page's glass and above bars lifted over it. |
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'capture',
    title: 'Capture control',
    icon: 'capture',
    summary:
        'Tell the capture what a subtree is: paint a stand-in for a video or a platform view, leave a subtree '
        'out, mark an opaque cover, or keep a blur the shadow filter would drop.',
    api: <String>[
      'GlassProxy',
      'GlassProxyRole',
      'GlassProxyPainter',
      'GradientProxyPainter',
      'SolidProxyPainter',
      'RenderGlassProxy',
    ],
    source: 'lib/src/proxy/proxy_role.dart',
    guide: r'''
The host captures what is under its glass by painting that part of the tree a second time, into a picture of its own
(see [How it works](/start/how-it-works)). Most of the time that is exactly right, and there is nothing to declare.
`GlassProxy` is for the subtrees where it is not: it tells the capture what a subtree is, and changes nothing in the
frame the user sees.

## Four declarations

| Constructor | The capture… | For |
|---|---|---|
| `GlassProxy.replace(painter:)` | paints the painter's stand-in instead of the subtree | a video, a camera preview, a map or any platform view: they record nothing, and the glass would show a hole |
| `GlassProxy.hidden()` | leaves the subtree out, and does not run its `paint` | a subtree the glass should not show, or one whose `paint` has side effects (counters, analytics, lazy loading) that should not run twice a frame |
| `GlassProxy.opaque()` | takes the subtree as covering its own box | a full-bleed image or panel: the capture stops looking under it |
| `GlassProxy.verbatim()` | exempts the subtree from the shadow filter | a highlight drawn through a `MaskFilter` on purpose, which the filter would drop as a shadow |

The outermost declaration wins: a `replace` inside a `hidden` is never reached.

## A stand-in

A stand-in is a `GlassProxyPainter`, shaped like a `CustomPainter`. Two come with the package:

- `SolidProxyPainter(color)`: one flat colour, the cheapest stand-in there is.
- `GradientProxyPainter(gradient)`: a gradient, which keeps the colour across the box where one colour would not.

Write your own for anything else: the last frame of the video as an image, the map's tiles at a lower zoom, the
camera's average colour. The canvas is clipped to the subtree's box before `paint` runs, so a stand-in cannot spill
onto glass elsewhere on the screen.

```dart
class PosterProxyPainter extends GlassProxyPainter {
  const PosterProxyPainter(this.poster);

  final ui.Image poster;

  @override
  void paint(Canvas canvas, Size size) => paintImage(
    canvas: canvas,
    rect: Offset.zero & size,
    image: poster,
    fit: BoxFit.cover,
  );

  @override
  bool shouldRepaint(PosterProxyPainter old) => old.poster != poster;
}
```

`shouldRepaint` tells the host the stand-in itself changed, and the next frame captures it. `isOpaque` (false by
default) says the stand-in covers its whole box, which makes it a cover as `opaque` does. A rounded stand-in is not
opaque: its corners are where the page shows through.

> [!NOTE]
> A stand-in changes what the glass sees, not when the host captures. The host still watches the composited layers
> under its glass, and a video that composites a new frame is a change it captures for. What `replace` buys is a
> picture where there would have been a hole.

## What it does not do

`GlassProxy` does not simplify content to save time: the capture already runs at a fraction of the screen's
resolution, and that is a cheaper and better-looking saving than swapping text for blocks of colour. Declare what the
capture cannot know, not what it can.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A video player under a glass control bar. The player is a platform view,
/// which a capture cannot read: without a stand-in, the bar would refract a
/// hole. With one, it refracts the poster's colours.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.player});

  /// The video: a platform view, a `Texture`, anything that paints outside
  /// Flutter's own pictures.
  final Widget player;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      GlassProxy.replace(
        painter: const GradientProxyPainter(
          LinearGradient(colors: <Color>[Color(0xFF1B1F2A), Color(0xFF3A2E5C), Color(0xFFFF9F0A)]),
        ),
        child: player,
      ),
      // An overlay that counts its own paints: the capture should not run it a
      // second time every frame.
      const Positioned(top: 16, right: 16, child: GlassProxy.hidden(child: _ViewerCount())),
      Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: GlassBar(
          child: Row(
            children: <Widget>[
              IconButton(onPressed: () {}, icon: const Icon(Icons.pause)),
              const Expanded(child: Text('Live')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.fullscreen)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ViewerCount extends StatelessWidget {
  const _ViewerCount();

  @override
  Widget build(BuildContext context) => const Text('1,204 watching');
}
''',
    properties: r'''
`GlassProxy`:

| Constructor | Parameters | Role |
|---|---|---|
| `GlassProxy.replace` | `painter` (`GlassProxyPainter`, **required**), `child` (**required**) | `GlassProxyRole.replace` |
| `GlassProxy.hidden` | `child` (**required**) | `GlassProxyRole.hidden` |
| `GlassProxy.opaque` | `child` (**required**) | `GlassProxyRole.opaque` |
| `GlassProxy.verbatim` | `child` (**required**) | `GlassProxyRole.verbatim` |

`GlassProxyPainter` (abstract):

| Member | Type | Description |
|---|---|---|
| `paint(Canvas canvas, Size size)` | `void` | Paints the stand-in, in the subtree's local space, clipped to `size`. |
| `shouldRepaint(covariant GlassProxyPainter old)` | `bool` | Whether the stand-in changed and has to be captured again. |
| `isOpaque` | `bool` | Whether `paint` covers the whole box. `false` by default. |

`SolidProxyPainter(Color color)` and `GradientProxyPainter(Gradient gradient)` are the two the package ships.

The real frame never changes: every declaration is a `RenderGlassProxy`, a proxy box that paints its child as usual.
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'scroll-edge',
    title: 'Scroll edge',
    icon: 'vertical_align_top',
    summary:
        "iOS 26's scroll edge effect: content softly blurs and fades as it scrolls under a bar, or meets an "
        'opaque band. It also holds and lifts the bar.',
    api: <String>[
      'GlassScrollEdge',
      'GlassScrollEdgeStyle',
      'GlassScrollEdgeSide',
      'GlassScrollEdgeAppearance',
      'kGlassScrollEdgeSigma',
      'kGlassScrollEdgeHardSigma',
      'kGlassScrollEdgeLightTint',
      'kGlassScrollEdgeDarkTint',
      'kGlassScrollEdgeHardFill',
    ],
    source: 'lib/src/surface/glass_scroll_edge.dart',
    guide: r'''
`GlassScrollEdge` draws what iOS 26 draws where a list scrolls under a bar. In the **soft** style (iOS's default), content blurs slightly and fades into a tint as it goes under the bar. In the **hard** style (macOS's default), it meets an opaque white band with a sharp edge. The values were read off Apple's own effect on iOS 26 simulators.

It also **holds your bar**: pass the bar as `child` and it is laid out inside `extent` and lifted together with the effect, so it shows glass scrolling under it (see [Glass on glass](/foundations/above)). Touches outside the bar pass through to the list.

## When to use

- A list that scrolls under a top app bar, or under a bottom toolbar or [tab bar](/components/tab-bar).
- **Not** without a scrolling list beneath. Over a still page, a plain [`GlassAbove`](/foundations/above) around the bar is enough.

> [!TIP]
> For a whole screen, a top bar over a list with an optional tab bar, [`GlassScaffold`](/components/scaffold) puts the bar in a soft scroll edge, works out `extent`, and tells the list its padding. Reach for `GlassScrollEdge` itself for anything else.

## Usage

Place it full-width against its edge, over the list:

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: list),
    Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GlassScrollEdge(
        side: GlassScrollEdgeSide.top,
        extent: MediaQuery.paddingOf(context).top + 60,
        child: appBar,
      ),
    ),
  ],
);
```

`extent` is the distance from the screen edge to the bar's inner edge: the status bar plus the bar at the top, the bar plus the home indicator at the bottom. Pad the list by the same amount so its first and last rows can be seen.

## Styles and sides

| | Top | Bottom |
|---|---|---|
| `soft` | A light blur (σ [`kGlassScrollEdgeSigma`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScrollEdgeSigma-constant.html) = 1.6) plus a tint that fades in toward the edge. This is a glass surface. | A tint only, no blur, as Apple draws it. A gradient, nothing captured. |
| `hard` | A near-opaque white band (`kGlassScrollEdgeHardFill`, 90%) with a sharp edge. | The same band at the bottom. |

The effect reaches **past** `extent` into the content, by about 40 px at the soft top. That is the fade.

## Appearance

A soft edge tints toward white over light content and toward black over dark content (`kGlassScrollEdgeLightTint`, `kGlassScrollEdgeDarkTint`). Apple picks the direction from the content itself. The package can't read the content, so with `appearance: null` it reads the host's declared `backdrop`: dark below a relative luminance of 0.4, light otherwise, **and light when no backdrop is declared**. Over a dark app, declare `backdrop` on the [host](/foundations/host) or pass `appearance: GlassScrollEdgeAppearance.dark`.

## Performance

- The soft top is one glass surface the width of the screen. Under a scrolling list, what's under it changes every frame, so **it re-captures on every scrolling frame** and costs nothing once the list stops.
- The soft bottom is a gradient and costs no capture.
- Being lifted costs one extra capture level, but only when there is glass under it.

> [!WARNING]
> Put the bar **in** `child`. An unlifted bar placed beside a lifted edge appears blurred inside the edge's capture.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A list under a top app bar and a bottom toolbar, each in a scroll edge.
/// Assumes a GlassHost above.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double top = safe.top + 64; // status bar + bar
    final double bottom = safe.bottom + 72; // toolbar + home indicator
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView.builder(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            itemCount: titles.length,
            itemBuilder: (BuildContext context, int i) => ListTile(title: Text(titles[i])),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.top,
            extent: top,
            // The bar goes in `child`, so it is lifted with the edge.
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, safe.top + 8, 16, 4),
              child: const GlassBar(child: Center(child: Text('Library'))),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.bottom,
            extent: bottom,
            style: GlassScrollEdgeStyle.hard, // macOS-style opaque band
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, safe.bottom + 8),
              child: Align(
                alignment: Alignment.topRight,
                child: GlassButtonGroup(
                  items: <GlassToolbarItem>[
                    GlassToolbarItem(icon: const Icon(Icons.add), label: 'Add', onPressed: () {}),
                    GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
''',
    properties: r'''
`GlassScrollEdge`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `side` | `GlassScrollEdgeSide` | **required** | `top` or `bottom`. |
| `extent` | `double` | **required** | From the screen edge to the bar's inner edge, in logical px. Must be ≥ 0. |
| `style` | `GlassScrollEdgeStyle` | `GlassScrollEdgeStyle.soft` | `soft` (blur and tint, iOS) or `hard` (opaque band, macOS). |
| `appearance` | `GlassScrollEdgeAppearance?` | `null` (dark if the theme's `backdrop` luminance is < 0.4, otherwise light) | Which way a soft edge tints: `light` (white) or `dark` (black). |
| `blurSigma` | `double` | `kGlassScrollEdgeSigma` (1.6) | The soft edge's blur. |
| `child` | `Widget?` | `null` | The bar, laid out within `extent` and lifted with the effect. |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassScrollEdgeSigma` | `1.6` | The soft edge's blur, in logical px. |
| `kGlassScrollEdgeHardSigma` | `2.15` | The hard band's blur. |
| `kGlassScrollEdgeLightTint` | `Color.fromRGBO(255, 255, 255, 0.85)` | The soft tint at the edge, light appearance. |
| `kGlassScrollEdgeDarkTint` | `Color.fromRGBO(0, 0, 0, 0.25)` | The soft tint at the edge, dark appearance. |
| `kGlassScrollEdgeHardFill` | `Color.fromRGBO(255, 255, 255, 0.90)` | The hard band. |
''',
  ),
  // ---------------------------------------------------------------------------
  Entry(
    section: Section.foundations,
    id: 'performance',
    title: 'Performance',
    icon: 'speed',
    summary:
        'What glass costs and how to keep it cheap: surface count, button groups, travel regions, thermal '
        'state, and the ledger that reports the glass on screen.',
    api: <String>[
      'GlassLedger',
      'GlassScope',
      'GlassLoad',
      'GlassLoadVerdict',
      'GlassHardware',
      'GlassThermalState',
      'GlassThermalPolicy',
      'debugPaintGlassSurfaces',
    ],
    source: 'lib/src/surface/glass_ledger.dart',
    guide: r'''
g1455 is built for cost first. Instead of a `BackdropFilter` on every surface, one [`GlassHost`](/foundations/host) records what's under all of its glass into **one** shared, downscaled capture, and **only re-records when something under the glass changed**. A still screen costs no capture at all. See [How it works](/start/how-it-works) for the details.

What's left for you is to not spend that budget by accident.

## What costs what

- **Each surface is one draw**, and the overhead grows faster than the surface count. A bar with five `GlassButton`s is six surfaces.
- **Changing content under glass** (scrolling, video, an animated background) means a capture on that frame. That's expected, and it's what the measured numbers cover (the devices and the dates: [How it works](/start/how-it-works)).
- **Moving glass over still content** costs a capture per frame, unless it moves inside a [`GlassTravel`](/foundations/travel).
- **Glass on glass** adds a capture level for each occupied level (nested glass, or [`GlassAbove`](/foundations/above)).
- **Animating `materialize`** changes the blur, so it captures every frame while it runs. Animating `presence` doesn't.
- **A ripple** costs no capture. **Groups** cost more than the same surfaces drawn separately.

## Practical advice

- **Keep glass in the navigation and controls layer**, as Apple's guidelines do. Bars, tab bars, toolbars and floating controls, not every card in a feed.
- **Prefer [`GlassButtonGroup`](/components/toolbar)** for rows of actions. It's one surface no matter how many items, where N `GlassButton`s are N surfaces.
- **Inside a glass bar, plain icons are cheaper** than `GlassButton`s, which are glass on glass.
- **Wrap moving glass in `GlassTravel`** with `RepaintBoundary`s around the glass and the content.
- **Offer cheaper [tiers](/foundations/tiers)** on low-end devices (`GlassTierPolicy(ceiling: GlassTier.cheap)`), and honour Reduce Transparency.
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
''',
    code: r'''
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
''',
    properties: r'''
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

## Debug flag

| Name | Type | Default | Description |
|---|---|---|---|
| `debugPaintGlassSurfaces` | `bool` | `false` | Outlines every registered glass surface. Debug builds only. |
''',
  ),
];
