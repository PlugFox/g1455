import '../catalog.dart';

/// Foundations, first half: the host, the surface, the finishes, legibility,
/// adaptive glass and the tiers.
const List<Entry> kFoundationEntriesA = <Entry>[
  Entry(
    section: Section.foundations,
    id: 'host',
    title: 'GlassHost',
    icon: 'layers',
    summary:
        'The engine room of a screen: one capture of the backdrop for all its glass, re-taken only when it changed.',
    api: <String>['GlassHost', 'GlassThermalPolicy', 'ProxyResolution'],
    source: 'lib/src/surface/glass_host.dart',
    guide: r'''
`GlassHost` records the content under every glass surface below it into one shared, downscaled image, and only
re-records it when something under the glass actually changed. Every surface then samples its own slice of that image.

It is also where a screen's glass is configured: the default finish, the tier, what is behind the glass, contrast,
thermal state and the ripple. The host installs a [GlassTheme](/foundations/legibility) with those values for
everything below it.

## When to use

- Always: any screen with glass needs exactly one host above it. A surface at the full tier with no host above draws no
  glass, only its child.
- Put it in `MaterialApp(builder: ...)`, above the navigator, so dialogs, sheets, menus and popovers find it too. They
  throw a debug error when they can't.
- Don't nest a host around each widget, and don't put it below the `Navigator` if you use any modal.

## Usage

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(
    backdrop: const Color(0xFF101014),
    richBackdrop: true,
    minLabelContrast: kTextContrastAA,
    child: child!,
  ),
  home: const HomePage(),
)
```

## Behaviour

- **One capture for the screen.** Ten surfaces are one capture and ten draws, not ten reads of the backdrop.
- **Captures only on change.** When nothing under the glass changed since the last frame, the host keeps the capture
  it has. A still screen and glass moving inside a [GlassTravel](/foundations/travel) region cost no capture. Content
  that repaints under glass, such as a list scrolling under a bar, costs one capture per changed frame.
- **The first frame has no glass.** The host captures after a frame is painted, and surfaces draw the capture on the
  next frame.
- **Shaders compile when the host mounts.** Until they land, glass draws the blurred backdrop with no tint, rim or bend.
  `await GlassHost.precache()` in `main()`, before `runApp`, compiles them first. See
  [Installation](/start/installation).
- **The resolution is chosen for you** against a quality budget (`budgetDeltaE`), from the finishes in use. Pin it
  with `resolution:` only for tests and benchmarks.

The demo above counts the host's captures. Leave everything still and the count stays flat; turn on the drifting
backdrop and it captures every frame.

## Theme

The host builds a `GlassTheme` from its parameters and puts it below itself. That has two consequences:

- A `GlassTheme` placed **above** the host is ignored. Configure the screen through the host's parameters.
- A `GlassTheme` placed **below** the host overrides a subtree: a different finish for one panel, or the cheap tier
  for a list of cards. See [Legibility & theme](/foundations/legibility) and [Tiers & fallbacks](/foundations/tiers).

When `finish` is null the host uses Apple's `.regular`, which is two materials: it picks `regularDark` or
`regularLight` from `backdrop` and the platform's appearance, and follows appearance changes. With `adaptive:` set it
picks per glass instead, from what each one reads under it: see [Adaptive glass](/foundations/adaptive).

The host also sets the screen's motion: `ripple:` for a touch wave ([Ripple](/foundations/ripple)) and `dropMotion:`
for how the held drops of the controls stretch and squash ([Drop motion](/foundations/drop-motion)).

## Gotchas

> [!WARNING]
> `maxCaptures`, `blurPass`, `resolution` and `content: GlassContentDeclaration.undeclared` are diagnostics. They are
> there to measure and to rule things out; don't ship them.

- No platform code ships. Reduce transparency, thermal state and macOS increase-contrast must be read by your app and
  passed in. See [What the app declares](/start/declarations).
- On a very large window, `maxTextureSide` (8192 on Apple, 4096 elsewhere) may limit the capture. Raise it, for
  example to 16384, if you know the GPU supports it.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const HostApp(reduceTransparency: false));

class HostApp extends StatelessWidget {
  const HostApp({super.key, required this.reduceTransparency});

  /// Read natively by the app: Flutter does not pass it on.
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Above the navigator, so dialogs, sheets and menus find the host too.
    builder: (BuildContext context, Widget? child) => GlassHost(
      // What is behind the glass: images and colour over a near-black page.
      backdrop: const Color(0xFF101014),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      // Reduce transparency gives the opaque tier, which fills with `backdrop`.
      tier: GlassTierPolicy(reduceTransparency: reduceTransparency).choose(),
      thermal: GlassThermalState.nominal,
      child: child!,
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101014),
    body: Stack(
      children: <Widget>[
        // Still content: the host captures it once and keeps the capture.
        const Positioned.fill(child: FlutterLogo(style: FlutterLogoStyle.stacked)),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: GlassBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(onPressed: () {}, icon: const Icon(Icons.home)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | The screen. Everything the glass shows must be inside it. |
| `finish` | `GlassFinish?` | `null` | The default material for every surface below. Null is Apple's `.regular`: `regularDark` or `regularLight`, picked from `backdrop` and the platform's appearance. |
| `tier` | `GlassTierChoice` | `GlassTierChoice.byDefault` | Full glass, a cheap translucent fill, or an opaque fill. Usually from `GlassTierPolicy.choose()`. |
| `backdrop` | `Color?` | `null` | The screen's average background colour. Used for the label colour, and needed for the opaque tier to look right. |
| `richBackdrop` | `bool` | `false` | The content behind the glass is an image, video, map or feed, so labels are chosen for the worst case. |
| `minLabelContrast` | `double?` | `null` | Minimum label contrast, e.g. `kTextContrastAA` (4.5). The glass is dimmed just enough to meet it. |
| `highContrast` | `bool?` | `null` | Draws an opaque outline instead of the subtle rim. Null reads `MediaQuery.highContrastOf`; on macOS pass it yourself. |
| `ripple` | `GlassRipple?` | `null` | A touch wave for every surface below. None by default. |
| `dropMotion` | `GlassDropMotion` | `GlassDropMotion()` | How the held drop of the switch, slider, segmented control and tab bar stretches and squashes. `GlassDropMotion.none` keeps it round. |
| `adaptive` | `GlassAdaptive?` | `null` | Each bar, card and button reads the backdrop under it and picks its branch and label. Null reads nothing. |
| `thermal` | `GlassThermalState?` | `null` | The device's thermal state, read by your app. Null is nominal. |
| `thermalPolicy` | `GlassThermalPolicy` | `GlassThermalPolicy()` | How much staleness each thermal state may spend. `GlassThermalPolicy.never` keeps every frame fresh. |
| `hardware` | `GlassHardware?` | `null` | Which device family's measurements apply. Null detects: `appleMetal` on Apple, otherwise `unmeasured`. |
| `budgetDeltaE` | `double` | `ProxyResolutionPolicy.defaultDamageBudgetDeltaE` | The quality budget the host trades for speed when it picks the capture's resolution. |
| `maxTextureSide` | `int?` | `null` | Largest GPU texture side in device pixels. Null is the hardware's floor: 8192 on Apple, 4096 elsewhere. |
| `content` | `GlassContentDeclaration` | `GlassContentDeclaration.byDefault` | `undeclared` forces a capture every frame. Diagnostic. |
| `resolution` | `ProxyResolution?` | `null` | Pins the capture's downscale (`full()`, `half()`, `quarter()`, `divisor(n)`). For tests and benchmarks. |
| `blurPass` | `ProxyBlurPass?` | `null` | How the residual blur is applied. Diagnostic. |
| `maxCaptures` | `int?` | `null` | Stops capturing after N captures. Diagnostic; never ship it. |

## GlassHost.precache

`static Future<void> precache({bool group = true, bool ripple = true})`: compiles the package's shaders now, so the
first glass on screen is drawn through its optics. Call it in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
Idempotent, and it shares the loads a host starts, so nothing compiles twice. `group: false` and `ripple: false` leave
out those programs. Completes with a load's error if one fails.
''',
  ),
  Entry(
    section: Section.foundations,
    id: 'surface',
    title: 'GlassSurface',
    icon: 'crop_square',
    summary: 'The primitive: a box of the screen that is glass. It refracts, blurs and tints the backdrop, then paints its child.',
    api: <String>['GlassSurface', 'kGlassCapsule', 'GlassFade'],
    source: 'lib/src/surface/glass_surface.dart',
    guide: r'''
`GlassSurface` says "this box of the screen is glass". It refracts, blurs and tints what is behind it, draws a thin rim
along its edge, then paints its child on top. Its shape is a smooth rounded rectangle, Apple's continuous-corner
squircle, drawn as the engine's own `RSuperellipse`.

Every component in the package is built from it. Reach for it when you need a shape no component offers.

## When to use

- Custom glass: lenses, blobs, a now-playing pill, a panel of your own design.
- Members of a [GlassGroup](/foundations/groups) or `GlassUnion`, which fuse surfaces into one silhouette.
- Not when a component exists. [GlassBar](/components/bar), [GlassCard](/components/card) and
  [GlassButton](/components/button) also choose a legible label colour, which a raw surface does not.

## Usage

```dart
const SizedBox(
  width: 220,
  height: 120,
  child: GlassSurface(
    borderRadius: BorderRadius.all(Radius.circular(28)),
    child: Center(child: Text('Glass', style: TextStyle(color: Color(0xFFFFFFFF)))),
  ),
)
```

A surface is a plain box: give it a size with a `SizedBox`, a `Positioned` with a width and height, or a child that
has one. `kGlassCapsule` makes a pill or a circle at any size.

## Appearing and leaving

Two values, from 0 to 1, and they do different things:

- `materialize` is how far the **material** has arrived: the bend and the blur first, the tint last, over the whole
  shape. That is Apple's materialize transition, and the one to animate when a panel appears or leaves. At 0 nothing
  is drawn or captured.
- `presence` is how much of the **shape** exists. Inside a [GlassGroup](/foundations/groups) a member growing from 0
  buds out of its neighbours. On a lone panel it narrows the shape to a line, which is rarely what you want.

## Labels

`labelled` (true by default) says text sits on this glass. When the host declares `minLabelContrast`, labelled glass
may be dimmed to keep that text readable. Set `labelled: false` on glass that carries no text, such as lenses, drops
and blobs, so it keeps its finish exactly as named. Inside a raw surface, set the text colour yourself; see
[Legibility & theme](/foundations/legibility).

## Performance

- Each surface is one draw. Keep the count low and prefer one bigger surface to many small ones.
- Animating `presence` costs no capture. Animating `materialize` changes the blur, which means a capture every frame
  while it runs.
- Moving glass belongs in a [GlassTravel](/foundations/travel) region so the motion costs no capture.

> [!TIP]
> Set `debugPaintGlassSurfaces = true` in debug builds to outline every surface in cyan.

## Gotchas

- Hit-testing goes to the child only: an empty surface is not tappable unless it has a ripple.
- Glass sitting beside other glass does not show it. To float a surface above other glass, wrap it in
  [GlassAbove](/foundations/above).
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A now-playing pill that materializes in, next to a magnifying lens.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key});

  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AnimatedBuilder(
        animation: _in,
        builder: (BuildContext context, Widget? child) => GlassSurface(
          borderRadius: kGlassCapsule,
          // Blur and bend arrive first, the tint last.
          materialize: Curves.easeOut.transform(_in.value),
          child: child,
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.music_note, color: Colors.white),
              SizedBox(width: 8),
              Text('Now playing', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 16),
      // A text-free lens: `labelled: false` keeps the clear finish undimmed.
      SizedBox(
        width: 72,
        height: 72,
        child: GlassSurface(
          borderRadius: kGlassCapsule,
          finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.4)),
          labelled: false,
        ),
      ),
    ],
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `borderRadius` | `BorderRadius` | `BorderRadius.all(Radius.circular(24))` | Corner radii. `kGlassCapsule` gives a pill or a circle at any size. |
| `finish` | `GlassFinish?` | `null` | The material for this surface. Null takes the theme's. |
| `materialize` | `double` | `1` | 0 to 1: how far the material has arrived, blur and bend first, tint last. At 0 nothing is drawn or captured. |
| `presence` | `double` | `1` | 0 to 1: how much of the shape exists. In a group a member buds from its neighbours; alone it narrows to a line. |
| `labelled` | `bool` | `true` | Text sits on this glass, so it may be dimmed to meet `minLabelContrast`. `false` for lenses and drops. |
| `fade` | `GlassFade?` | `null` | Fades the glass out across the surface, scroll-edge style. Ignored for members of a fusing group. |
| `ripple` | `GlassRipple?` | `null` | A touch wave for this surface. Null takes the theme's, which is none by default. |
| `child` | `Widget?` | `null` | Drawn on top of the glass. It receives the hits. |

## GlassFade

| Constructor | Description |
|---|---|
| `GlassFade({required Offset begin, required Offset end})` | Whole at `begin`, gone at `end`, in local logical pixels, with a smoothstep between. |
| `GlassFade.vertical({required double from, required double extent})` | The vertical form. A negative `extent` fades upward. |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassCapsule` | `BorderRadius.all(Radius.circular(1e9))` | An over-large radius the engine clamps to half the short side: a stadium at any size. |
| `debugPaintGlassSurfaces` | `false` | A top-level variable. In debug builds, outlines every surface in cyan. |
''',
  ),
  Entry(
    section: Section.foundations,
    id: 'finishes',
    title: 'Finishes',
    icon: 'palette',
    summary: "The material of the glass: regular dark and light, clear and frosted, calibrated against Apple's iOS 26 materials.",
    api: <String>['GlassFinish', 'GlassOptics', 'kCalibratedRim'],
    source: 'lib/src/surface/glass_finish.dart',
    guide: r'''
A `GlassFinish` is the material the glass is made of: how much it blurs, the tint it lays over the refracted backdrop,
the rim along its edge, and the shape of the refraction (`GlassOptics`). The presets are calibrated against Apple's own
materials on iOS 26.

A finish can be set for the whole app (`GlassHost.finish`), for a subtree (a [GlassTheme](/foundations/legibility)
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
  `minLabelContrast` when text sits on it; see [Legibility & theme](/foundations/legibility).
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
  [GlassButton](/components/button).
- **Optics**: `GlassOptics(thickness:, strength:, edgePower:, shoulder:, widen:, zoom:)` shapes the bend.
  `strength` is the peak bend at the rim in pixels, negative being inward (Apple's direction); `zoom` magnifies about
  the centre, which is how a lens is made. `GlassOptics.none` turns the bend off.

> [!NOTE]
> The demo sets the tint and the backdrop for its own panels only. The menu at the top of the site sets the finish and
> tint of the whole site through the host.
''',
    code: r'''
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
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | **required** | Key into the measured quality and cost tables. Use a preset's name. |
| `blurSigmaLogical` | `double` | **required** | The blur, in logical pixels. |
| `tint` | `Color` | **required** | Laid over the refracted backdrop. Its alpha is how opaque the glass is. |
| `rim` | `Color` | `kCalibratedRim` | Added along the 0.79 px outline; also the button press highlight. |
| `optics` | `GlassOptics` | `GlassOptics()` | The shape of the refraction. |

## GlassOptics

| Parameter | Type | Default | Description |
|---|---|---|---|
| `thickness` | `double` | `21` | How far in from the rim the refraction reaches, in pixels. |
| `strength` | `double` | `-58.2` | Peak bend at the rim, in pixels. Negative is inward; closer to 0 is subtler. |
| `edgePower` | `double` | `1.9` | Falloff exponent. |
| `shoulder` | `double` | `0.6` | Falloff shape exponent. |
| `widen` | `double` | `0` | Shows backdrop from this many pixels beyond the box, which minifies. |
| `zoom` | `double` | `1` | Magnification about the centre. Must be greater than 0. |

## Presets and methods

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
''',
  ),
  Entry(
    section: Section.foundations,
    id: 'legibility',
    title: 'Legibility & theme',
    icon: 'contrast',
    summary:
        'How glass components choose black or white labels, keep them readable, and how a subtree gets its own look.',
    api: <String>['GlassTheme', 'GlassThemeData', 'GlassLegibility', 'kTextContrastAA'],
    source: 'lib/src/surface/glass_theme.dart',
    guide: r'''
Text on glass sits over whatever the glass sits over, so its colour cannot be fixed in advance. The components
([GlassBar](/components/bar), [GlassButton](/components/button), [GlassCard](/components/card), the
[text field](/components/text-field), the [alert](/components/alert), the [menu](/components/menu) and the
[popover](/components/popover)) choose black or white for their labels, from the finish and from what you told the host
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
`GlassHost(adaptive: GlassAdaptive())`. See [Adaptive glass](/foundations/adaptive).

> [!NOTE]
> `GlassThemeData.copyWith` cannot set a nullable field back to null. To drop `minLabelContrast` or `backdrop` for a
> subtree, build a new `GlassThemeData`.
''',
    code: r'''
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
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `finish` | `GlassFinish` | `GlassFinish.regularDark` | The material every surface below wears unless it names its own. |
| `tier` | `GlassTierChoice` | `GlassTierChoice.byDefault` | Which rung is drawn: full, cheap or opaque. |
| `backdrop` | `Color?` | `null` | The average colour behind the glass. Chooses the label over a flat page; fills the opaque tier. |
| `highContrast` | `bool` | `false` | Draws an opaque outline instead of the calibrated rim. |
| `richBackdrop` | `bool` | `false` | The backdrop is an image or feed: labels are chosen for the worst case. |
| `minLabelContrast` | `double?` | `null` | The least label contrast. The glass is dimmed just enough to meet it. |
| `ripple` | `GlassRipple?` | `null` | The default touch wave. |
| `dropMotion` | `GlassDropMotion` | `GlassDropMotion()` | How held drops stretch and squash. See [Drop motion](/foundations/drop-motion). |
| `adaptive` | `GlassAdaptive?` | `null` | Whether glass reads its backdrop. Installed by `GlassHost.adaptive`. See [Adaptive glass](/foundations/adaptive). |
| `regularAppearance` | `Brightness?` | `null` | The appearance `finish` was picked in when it is `.regular` and nobody named it. Set by an adaptive host. |
| `reading` | `GlassBackdropReading?` | `null` | What the glass this theme was installed for read of its backdrop. |

## GlassTheme

| Member | Description |
|---|---|
| `GlassTheme({required GlassThemeData data, required Widget child})` | Gives a subtree its own glass configuration. Must be below the host. |
| `GlassTheme.of(context)` | The theme in force, or the defaults with the platform's `.regular` branch. |
| `GlassTheme.maybeOf(context)` | The theme in force, or null. |
| `GlassThemeData.legibility([GlassFinish? own, bool labelled = true])` | The finish to draw, the label colour and the outline, for this theme. |

## GlassLegibility

| Field | Type | Description |
|---|---|---|
| `finish` | `GlassFinish` | The finish to draw: the declared one, or it dimmed to meet the floor. |
| `label` | `Color` | Black or white, whichever reads best. |
| `rim` | `Color?` | The opaque outline under increased contrast, or null. |

## Constants

| Name | Value | Description |
|---|---|---|
| `kTextContrastAA` | `4.5` | WCAG AA for body text. |
| `kNonTextContrast` | `3` | WCAG's floor for non-text elements. |
''',
  ),
  // --------------------------------------------------------------- adaptive
  Entry(
    section: Section.foundations,
    id: 'adaptive',
    title: 'Adaptive glass',
    icon: 'brightness_6',
    summary:
        'Glass that reads its own backdrop: a bar over a bright sky turns light, a button over a shadow stays '
        'dark, each with a label to match. Off by default and free when off.',
    api: <String>['GlassAdaptive', 'GlassBackdropReading', 'GlassHost', 'GlassThemeData'],
    source: 'lib/src/surface/glass_adaptive.dart',
    guide: r'''
Apple's `.regular` is two materials, dark over dark content and light over light. Without help the package picks one
branch for the whole screen, from what you declared: the host's `backdrop` and the platform's appearance. A screen is
not one level, though. A bar over a photograph's sky and a button over its shadow sit on different branches of Apple's
own material.

`GlassHost(adaptive: GlassAdaptive())` lets each glass look. The host already holds the pixels under every surface, so
it reads back the mean level inside each one's box, and a [GlassBar](/components/bar), a [GlassCard](/components/card)
or a [GlassButton](/components/button) picks the branch of `.regular` and its label colour from it.

## When to use

- Glass over photographs, maps or video, where one declared level is wrong for half the screen.
- Bars and buttons that stay put while the content under them changes from light to dark, such as a full-bleed hero
  image scrolling under a bar.
- **Not** over a flat page: declare its colour as the host's `backdrop` instead, which is exact and reads nothing.

## Usage

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(
    adaptive: const GlassAdaptive(),
    child: child!,
  ),
  home: const PhotoPage(),
)
```

That's all. The components under the host follow what is under them.

## What a reading changes

- **The branch of `.regular`.** Only when nobody named a finish. A finish named by the component, by an inner
  `GlassTheme` or by the host (`GlassHost(finish: GlassFinish.regularDark)`) is kept. Only its label follows the
  reading.
- **The label.** The reading stands in for the declared `backdrop` for that one glass: the label colour, the
  high-contrast outline and the `minLabelContrast` dim are all chosen against it.
- **Not under `richBackdrop: true`.** A mean says nothing about the brightest corner of a photograph, so there the label
  stays chosen against every backdrop, and the reading moves only the branch.

Until a glass has its first reading (its first couple of frames, or a [tier](/foundations/tiers) that captures nothing),
it wears what the declarations give, exactly as with adaptive off.

## Behaviour

- **No flicker.** A reading moves a glass only when it is more than `band` (12) code values from the one it last
  moved on, and not within `hold` (600 ms) of its last move. A list of light and dark rows scrolling under a bar keeps
  the bar on the branch it has.
- **Moves animate.** A glass crossing between branches tweens its tint over `duration` (300 ms), and on every frame
  of it the label is the one that reads on the glass as drawn, so the floor holds halfway too. Under reduced motion it
  is a cut.
- **What adapts.** `GlassBar`, `GlassCard` and `GlassButton`. A raw `GlassSurface`, the
  [scroll edge](/foundations/scroll-edge), the [tab bar](/components/tab-bar) and the
  [segmented control](/components/segmented-control) do not adapt yet.

The demo above turns adaptive on in the site's own host while the page is open, so the site's top bar and side panel
follow it too. The site declares a rich backdrop, so the stage nests a `GlassTheme` with `richBackdrop: false` to let
the labels follow as well. It needs the full tier (the High or Ultra setting) and the Regular material: a lower tier
captures nothing to read, and a named material is kept.

## Content on the glass

Inside a component that reads its backdrop, `GlassTheme.of(context).reading` is what it read, so an icon that is not a
label, or a custom painter, can follow it:

```dart
final GlassBackdropReading? reading = GlassTheme.of(context).reading;
final bool overLight = reading?.brightness == Brightness.light;
```

It is null with adaptive off and before the first reading. `level` is the mean's luma in code values (0 to 255),
`luminance` its WCAG relative luminance, and `brightness` whether black or white stands out more against it. The
branch the glass is on is `GlassTheme.of(context).finish`.

A custom component does what the built-in ones do with `GlassThemeData.adaptedTo(reading)`. To turn adaptive off for a
subtree, nest `GlassTheme(data: GlassTheme.of(context).withAdaptive(null), ...)`.

## Cost

- **Off: nothing.** No reader exists, nothing is recorded, read back or scheduled.
- **On, a still screen: nothing** after the first reading. A frame that keeps its capture has nothing new under the
  glass and reads nothing.
- **On, a frame that captures:** at most one read-back of a 4 × 4-pixel cell per surface, asynchronously, and at most
  once per `interval`. The frame that asked doesn't wait for it.
- **On the web it is dearer.** CanvasKit reads back synchronously, a GPU flush on the frame it lands in, so `interval`
  is a second there rather than 250 ms. Raise it further for a screen that scrolls a lot.

> [!TIP]
> The finish table of [Finishes](/foundations/finishes) and the label rules of
> [Legibility & theme](/foundations/legibility) still apply: adaptive only gives each glass its own `backdrop`.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const PhotoApp());

class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // One host, reading the backdrop under each glass. No finish named, so
    // each bar and button may take the branch of `.regular` it reads.
    builder: (BuildContext context, Widget? child) => GlassHost(adaptive: const GlassAdaptive(), child: child!),
    home: const PhotoPage(),
  );
}

class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Bright at the top, dark at the bottom: a sky and its shadow.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFEAF2FA), Color(0xFFB9D3EA), Color(0xFF1B2A1F), Color(0xFF0A110C)],
                  stops: <double>[0, 0.5, 0.52, 1],
                ),
              ),
            ),
          ),
          // Over the sky: turns light, with a dark label.
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(child: Text('Lake Tekapo')),
          ),
          // Over the shadow: stays dark, with a white label.
          Positioned(
            bottom: safe.bottom + 16,
            left: 16,
            child: GlassButton(onPressed: () {}, child: const Text('Directions')),
          ),
          // Content that follows the reading itself.
          Positioned(
            bottom: safe.bottom + 16,
            right: 16,
            child: GlassButton(
              onPressed: () {},
              semanticLabel: 'Weather',
              child: Builder(
                builder: (BuildContext context) {
                  final GlassBackdropReading? reading = GlassTheme.of(context).reading;
                  return Icon(reading?.brightness == Brightness.light ? Icons.wb_sunny : Icons.nightlight_round);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''',
    properties: r'''
`GlassHost`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `adaptive` | `GlassAdaptive?` | `null` | Turns reading on, and says how. Null: glass goes by what is declared, and nothing is read. |

`GlassAdaptive`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `band` | `double` | `GlassAdaptive.kDefaultBand` (12) | How far, in code values of luma, a reading must be from the last one to move the glass. Must be ≥ 0. |
| `hold` | `Duration` | `GlassAdaptive.kDefaultHold` (600 ms) | The least time between two moves of one glass. |
| `interval` | `Duration` | `GlassAdaptive.kDefaultInterval` (250 ms; 1 s on the web) | The least time between two read-backs. |
| `duration` | `Duration` | `GlassAdaptive.kDefaultDuration` (300 ms) | How long a glass takes to cross between branches. None under reduced motion. |

## GlassBackdropReading

| Member | Type | Description |
|---|---|---|
| `mean` | `Color` | The mean colour of the captured backdrop under the glass, opaque. |
| `level` | `double` | The mean's luma in code values, 0 to 255: the scale `.regular` switches on. |
| `luminance` | `double` | The mean's WCAG relative luminance. |
| `brightness` | `Brightness` | Light when black stands out more against the mean, dark when white does. Not the branch of the glass. |

## GlassThemeData

| Member | Description |
|---|---|
| `adaptive` | The host's `GlassAdaptive`, or null. Installed by `GlassHost.adaptive`. |
| `reading` | What the glass this theme was installed for read, or null. Read it as `GlassTheme.of(context).reading`. |
| `adaptedTo(GlassBackdropReading reading)` | This theme as it applies over one glass that read `reading`: what a custom component installs around its content. |
| `withAdaptive(GlassAdaptive? adaptive)` | This theme with `adaptive` replaced, null included: turns reading off for a subtree. |
''',
  ),
  Entry(
    section: Section.foundations,
    id: 'tiers',
    title: 'Tiers & fallbacks',
    icon: 'stairs',
    summary:
        'Full glass, a cheap translucent fill, or opaque: the rung for reduce transparency, low-end devices and tests.',
    api: <String>['GlassTier', 'GlassTierPolicy', 'GlassTierChoice', 'GlassTierReason'],
    source: 'lib/src/surface/glass_tier.dart',
    guide: r'''
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
- Below full, [groups](/foundations/groups) stop fusing (no bridges between members) and
  [ripples](/foundations/ripple) are off.
- The cheap and opaque rungs draw even without a host above, as flat panels.

> [!WARNING]
> With `opaque`, declare `backdrop` on the host or the theme. Without it the fill is the tint alone, which is wrong,
> and you get a debug error when the rung is painted.

> [!WARNING]
> `pinned` overrides everything, the user's Reduce Transparency setting included.
''',
    code: r'''
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
''',
    properties: r'''
## GlassTierPolicy

| Parameter | Type | Default | Description |
|---|---|---|---|
| `pinned` | `GlassTier?` | `null` | Forces a tier. Overrides everything, including the user's accessibility setting. |
| `reduceTransparency` | `bool` | `false` | The OS Reduce Transparency switch, as your app read it. Gives `opaque`. |
| `ceiling` | `GlassTier?` | `null` | The richest tier this device should run, e.g. `cheap` on low-end hardware. |

`choose()` returns a `GlassTierChoice`, resolving `pinned`, then `reduceTransparency`, then `ceiling`, then full.

## GlassTierChoice

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tier` | `GlassTier` | **required** (positional) | The rung drawn. |
| `reason` | `GlassTierReason` | **required** (positional) | Why, for reporting. |

`GlassTierChoice.byDefault` is `(GlassTier.full, GlassTierReason.byDefault)`.

## Enums

| Name | Values | Description |
|---|---|---|
| `GlassTier` | `full`, `cheap`, `opaque` | The rungs. `readsBackdrop` is true only for `full`. |
| `GlassTierReason` | `byDefault`, `pinnedByHost`, `reduceTransparency`, `deviceCeiling` | Why a rung was chosen. Reporting only. |
''',
  ),
];
