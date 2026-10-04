## 0.1.1

What a screen reader is told and can do:

- `GlassSwitch` and `GlassSlider` take a `semanticLabel`. A screen reader steps
  `GlassSlider` with increase and decrease, by `semanticStep` (a tenth by
  default), through `onChangeStart`, `onChanged` and `onChangeEnd`, and never
  past either end.
- `GlassButton` takes a `semanticLabel` that is read in place of its child,
  for a button that is only an icon.
- `showGlassSheet` takes a `barrierLabel`, as `showGlassDialog` already did.
  `GlassMenuAnchor` and `GlassPopoverAnchor` take one too. Their barrier used
  to be a tap target with no label, so a screen reader had no way to close a
  popover.

On a page:

- `showGlassSheet` takes `constraints`, as `showModalBottomSheet` does. A
  `maxWidth` keeps the sheet at its content's width, centred, on a window
  wider than that. Null, it spans the window as before.
- The labels of `GlassButton`, `GlassSegmentedControl` and `GlassTabBar` are
  not text to select. Under a `SelectionArea`, a drag across the page used to
  take them along with the prose around them.

Fixed:

- Glass draws on CanvasKit, which is every Safari and every browser without
  WasmGC. CanvasKit keeps a fragment shader's uniforms by reference until the
  picture is rasterized, and the glass released its shaders straight after
  the draw. So it drew from freed memory: a shape in the wrong place, a solid
  grey or green slab, a different one each frame. On the web a shader now
  lives as long as the picture drawn with it.
- Glass standing on glass no longer moves what is under the glass it stands
  on. When a level was captured, the walk painted the levels below it, and a
  `CompositedTransformTarget` among them wrote the walk's offset into its own
  live `LeaderLayer`. A `SelectionArea` creates one. So with a popover open
  over a bar, the bar's text jumped right and down, and it stayed there until
  the bar repainted. The walk now puts back every live offset it touches.
- A `GlassGroup` drawn in tiles no longer loses members on the web. Skwasm's
  fragment shader keeps its uniforms by reference rather than copying them on
  each draw, so every tile drew the last tile's members, and blobs flickered
  in and out. On the web each tile now gets its own shader.
- A platform view or a `Texture` is a hole in the capture of an upper level,
  as it already was in the base level. It used to be a grey stub. On the web
  every `SelectionArea` lays a transparent platform view under what it holds,
  so a bar over a selectable page showed grey.

Documented:

- The README says what the glass costs on the web outside Chromium — Safari,
  Firefox and every browser on iOS, Chrome for iOS included, get CanvasKit,
  where each capture is a synchronous GPU readback — and what to do about it:
  allow Skwasm on WebKit, or declare a cheaper rung where CanvasKit remains.

## 0.1.0

First release on pub.dev, as `g1455`. The package was `glass` while it lived
beside the research application that measures it: the library is now
`package:g1455/g1455.dart`, the shader asset keys are
`packages/g1455/shaders/...`, and `glass_diagnostics.dart` keeps its name.
Everything since the first cut:

**Breaking:** `GlassFinish.regular` is now `GlassFinish.regularDark`, and its
damage-table key is `'regularDark'` (D230). It was always the dark branch of
Apple's `.regular`, because S4's iPad was in dark mode. The light branch is the
new `GlassFinish.regularLight`: transmission 0.282, tint 252 at 0.718, and its
own rows in the resolution and staleness tables.
`GlassFinish.regular(appearance:, backdrop:)` picks the branch Apple's
material would. It switches at a backdrop level of 54 in light mode and 222 in
dark mode. `GlassHost.finish` is now optional. Null means that choice,
following the declared `backdrop` and the platform's appearance. `GlassTheme.of`
with no host above does the same. At the default budget the light branch may
hold its capture one frame (0.284 ΔE against 0.348).

Drops and lone panels no longer appear through `presence`, which eroded a
capsule to a bright line about 2 pt tall for ~50 ms on the way out. The
tab bar's, switch's, slider's and segmented control's drops, and the alert and
the menu, now come and go through `materialize`, as Apple's do (D216, D230).

`showGlassDialog` and `showGlassSheet` carry the caller's `InheritedTheme`s
to the navigator's overlay, as `showDialog` does. Their content used to
inherit what stands above the navigator, which in a `MaterialApp` is its
error style: red, monospace, underlined in yellow.

`GlassMenuAnchor`'s menu grows out of its anchor — from the anchor's size and
capsule to its own, about the corner the two share — while it materializes,
and shrinks back into it on the way out. New `GlassPopoverAnchor`: the same
panel around any content, open until a tap outside it. Opening a menu over an
anchor with a semantics node of its own no longer trips the framework's
`!semantics.parentDataDirty` on close.

New components, read off Apple's own on iOS 26.5 simulators (D222–D226):

- `GlassScrollEdge`: the scroll edge effect under a bar, soft or hard, top or
  bottom. It carries the bar and lifts it. The soft top is a blur of σ 1.6
  through the new `GlassFade` plus an erf tint. The soft bottom is a tint and
  nothing else, so it captures nothing.
- `GlassAbove`: raises glass over the glass beside it. A bar over glass cards
  now shows the cards. It costs one snapshot per recorded frame, and only when
  there is glass under it.
- `GlassSegmentedControl`: the selection lifts into a clear drop over a track
  that is not glass. One level; a slide records nothing.
- `GlassButtonGroup`: adjacent toolbar actions in one capsule, so one surface
  rather than one per button.
- `GlassTextField` and `GlassTextField.search`: a glass capsule holding an
  `EditableText`. The caret and typing take no capture.
- `showGlassDialog` with `GlassAlert`, `showGlassSheet` and `GlassMenuAnchor`.
  The menu is placed as Apple places a button's menu (D228): over the anchor,
  corner on corner, with the anchor hidden. It is 250 wide with rows of 42 and
  a 31.5 corner. When it opens upward, its items are reversed.
  These need the `GlassHost` above the navigator (`MaterialApp.builder`), and
  they say so in debug when it is not.
- `GlassSurface.fade` (`GlassFade`): the glass fades across itself. It is a
  smoothstep, and an exact `1.0` when unused.

- `GlassRipple` (D229), optional and not Apple's: a viscous wave from where the
  glass was touched. A dimple sinks under the finger, a front travels out, and
  the dimple springs back on release. `viscosity` goes from water to honey. Set
  it on `GlassHost.ripple`, `GlassThemeData.ripple` or `GlassSurface.ripple`. It
  is drawn by a second program, so a surface with no wave runs the same bytes as
  before, and a wave takes no capture. Off under reduced motion. Not drawn by
  fused group members.

Fixed:

- The slider's fill ended in a square cut that the clear drop magnified. It is
  now a capsule, as Apple's is (D222).
- A screen whose only glass was a resting drop (switches, segments) never
  stopped drawing. `publishUpper` notified listeners on every frame even when
  nothing had changed (D224).
- Under glass on glass, a still screen recorded on every frame when the lower
  glass held content that was not behind a `RepaintBoundary`, such as a plain
  `Text`. The publish repainted the content, and the new pictures read as a
  change. A surface now re-adds its content layer when only the proxy changed
  (D224).
- With two finishes on one screen, each blur class blurred the whole atlas.
  It now blurs only the box around its own slots. On the iPad this was 0.8 ms
  of a scrolling frame with a scroll edge over cards (D227).

## 0.1.0-dev.1

Not published.

First cut of the package, moved out of the research application that measured
it. Behaviour is unchanged from that application's `lib/`, with one exception:
a debug assertion. The changes:

- Shaders moved under `lib/shaders/` and are declared through `packages/glass/`.
  The asset key is now `packages/glass/shaders/...` whether the package is the
  root or a dependency.
- `glass_diagnostics.dart` is a new library for benchmark switches and the
  host's proxy handle: `debugGlassFusedSplit`, `debugGlassFoldCull`,
  `debugGlassShaderAntiAlias`, `fusedDrawTiles`, `GlassFusedTile`,
  `kMaxFusedTiles`, the two shader asset keys, `GlassProxyHandle` and
  `GlassProxyScope`. These are no longer exported from `glass.dart`.
- `GlassPlatformSignals` and `GlassSignals` were removed from the package. It
  ships no platform code, and the native side never belonged to it. The
  application reads these settings and passes them in. `GlassThermalState`
  stays, because `GlassHost.thermal` takes it.
- The host's debug check that the layer watch saw a repaint no longer fires when
  everything that repainted is glass content. Example: a label inside a
  `GlassBar` changing, when the bar's height follows the label. That case is
  not a hole, because glass content is not part of the proxy. The check now
  reads a second walk that excludes only the glass draws (D219).
- The same check no longer fires when the host's boundary was repainted but
  drew nothing of its own. `RenderObject.layout` marks paint unconditionally,
  so an application's `setState` that re-runs a `Scaffold`'s layout at the same
  geometry repaints the host's boundary. When every pixel under it belongs to a
  nested boundary, that repaint mints no picture and the screen is still. The
  example's slider tripped it on its first press. The check now fires only when
  a picture outside every nested boundary is present.
- `GlassSurface.labelled`, `GlassGroup.labelled` and `GlassUnion.labelled`:
  glass that carries no label is exempt from the theme's `minLabelContrast` dim
  and keeps the finish it names. The switch's, slider's and tab bar's drops are
  unlabelled. Dimmed for a label they do not have, they turned grey over a rich
  backdrop.
- `GlassButton` no longer fills the width it is offered. In a `Wrap` or a
  `Column` it was a bar, because its label sat in a bare `Center`.
- Disabled controls now look disabled. Before, `onPressed: null` and
  `onChanged: null` removed the gestures and nothing else. As on iOS 26, a
  disabled `GlassSwitch` or `GlassSlider` is drawn as one group at
  `kGlassDisabledOpacity` (0.5), with a plain knob in place of the drop. A
  disabled `GlassButton` keeps its glass, and its label becomes
  `kGlassDisabledDarkLabel` or `kGlassDisabledLightLabel` (iOS's
  `tertiaryLabel`), chosen by the polarity of the label it would have drawn
  enabled (D221). A control disabled mid-press or mid-drag lets go.
