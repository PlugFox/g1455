## 0.1.5

A backdrop the application declares:

- `GlassBackdrop` declares what is behind the glass in a subtree, and that
  glass samples a texture made from the declaration instead of a capture of
  the screen: `GlassBackdrop.color`, `.image` (an `ImageProvider`, placed by
  `fit` and `alignment`), `.texture` (a `ui.Image` the application holds) and
  `.gradient` and `.painter` (any `GlassProxyPainter`). The texture is
  made once per finish blur and size, through the same shader and the same
  blur arithmetic as a captured slot, and the host leaves those surfaces out
  of its capture: a screen whose glass is all declared takes no snapshot.
  Over a declared colour the glass draws what it draws over a captured screen
  of that colour, to 2 code values.
- Scoped to the subtree, innermost first: `GlassBackdrop.live` hands a part
  back to the capture, so a page can declare its wallpaper and still let the
  bar over its list refract the list. The widget paints what it declares under
  its child unless `paintBackdrop: false`, and an image that has not loaded
  leaves the glass on the capture until it has.
- Glass over a declared backdrop is ordinary content for the capture of other
  glass, as a cheap surface is: a captured bar over declared cards shows them.
  Fused groups sample the declaration too. Adaptive glass does not read a
  declared backdrop yet, and falls back to its declarations.
- `RenderGlassSurface.paintsWithDeclaredBackdrop`,
  `RenderGlassGroup.paintsWithDeclaredBackdrop`,
  `RenderGlassSurface.readsDeclaredBackdrop` and
  `GlassBackdropDeclaration.renders` say what was sampled and how many
  textures were made; `GlassSurfaceRecord.declared` and `readsCapture` say
  what the ledger priced.

Components:

- `GlassStepper`: a minus and a plus in one glass capsule, as `UIStepper`. A
  press steps at once; held, a half repeats after
  `kGlassStepperRepeatDelay` (500 ms) every `kGlassStepperRepeatInterval`
  (100 ms), and the half that would pass a limit is disabled unless `wraps`.
  One surface: a press, the repeat and a glyph dimming are drawn inside the
  glass and are no capture. A screen reader hears one adjustable control.
- `GlassPageControl`: page dots on a glass capsule, as `UIPageControl` on its
  platter. It follows a `PageController` without a build and turns it; a tap
  moves one page toward the side tapped, as iOS's does, and a drag scrubs.
  One surface. A `PageView` beside it is retaken while it scrolls (43 captures
  a swipe in the package's tests), which belongs to the view: the same 43 with
  dots that stay put.
- `GlassSearchBar`: the glass search field with a clear button while there is
  text, and a Cancel that slides in while it has the focus. One surface, the
  field's; typing and the clear button are no capture. Cancel's slide narrows
  the glass, and that is a capture a frame for `cancelDuration` (16 over
  250 ms at 60 Hz, each way), one frame under reduced motion.
- `GlassBadge`: a count, a label or a dot on the corner of an icon or a tab,
  as an opaque `systemRed` capsule. Not glass, as iOS 26's badge is not; it
  costs no surface, and a count changing on glass is a repaint inside the
  glass.
- Their sizes (`kGlassStepperSize`, `kGlassPageDot`, `kGlassPageDotGap`,
  `kGlassPageControlHeight`, `kGlassBadgeHeight`, `kGlassBadgeDot`) are
  layout, not Apple measurements: none of the four was among the controls
  measured. The stepper, the page control and the search bar are laid
  out at least `kGlassMinTapTarget` tall.

iOS 26 behaviours:

- Sheet detents: `showGlassSheet(detents:, initialDetent:,
  onDetentChanged:)` with `GlassSheetDetent.medium` (the content's height, as
  before; Apple's is half the window) and `GlassSheetDetent.large` (the whole
  height below the top safe area less 8, edge to edge). A drag between them
  follows the finger and settles at the nearer, or where a flick was heading.
- A large sheet is `largeFinish`, by default the finish with its tint at full
  alpha. Once it is all the way up it is drawn on `GlassTier.cheap` and reads
  no backdrop: headless, with a glass bar under it, one surface of two
  captured instead of two, and 20,608 px² of capture against 337,408. The
  other way: the sheet is then content to the capture of the glass around it,
  so a change inside it is a retake (1 against 0). A translucent
  `largeFinish` keeps it glass.
- `GlassTabBar(minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown)`
  collapses the bar to a circle of the selected tab's icon when the content
  scrolls down, and expands it on a scroll up or a tap on the circle, which
  selects nothing. The scroll is read by a `GlassTabBarMinimizer` above both
  the scroll view and the bar; `GlassScaffold` is one. The collapse moves
  inside a declared travel region: no record over 60 frames, against 60
  without the declaration. Collapsed, a screen reader hears one button named
  for the selected tab.
- `GlassTabBar.bottomAccessory`: a glass capsule `kGlassTabAccessoryHeight`
  (48) tall above the bar, which moves down beside the collapsed circle. The
  bar's box keeps its height, so the body is not laid out again for it.
- The gap above a large sheet, its radius, the circle's size, the accessory's
  height and gaps, `kGlassTabMinimizeScroll` (12) and the springs are layout
  taste: none was measured on Apple's devices.

Interaction:

- `GlassPress`: a pressed `GlassButton` swells by 12 px on its longest side
  and leans up to 3 px toward a dragging finger, then springs back. Declared
  on `GlassHost.press`, `GlassThemeData.press` or `GlassButton.press`;
  `GlassPress.none` turns it off, and so do reduced motion and a disabled
  button. A feel rather than a measurement: Apple's press was not measured,
  and 17 px, another package's number, would be 1.39× a 44 px button. It
  costs two captures a press (touch-down and settle) and nothing at rest,
  because the region it grows in is declared only while it moves; declared
  always, it doubled a 44 px button's captured area (3,600 to 7,056 px²).
  Toolbar cells take the focus but do not swell: the group is one surface.
- `GlassSlider.divisions`: every input, a drag, a tap, a key or a screen
  reader, lands on a stop, and `onChanged` is called only when the stop
  changes.
- The switch, the slider and the segmented control drag from touch-down and
  claim the pointer inside a horizontal scrollable such as a `PageView`; in a
  vertical list a swipe that starts on them still scrolls the list.
- The keyboard: the button, switch, slider, segmented control and toolbar
  cells take the focus (`focusNode`, `autofocus`); Space and Enter activate,
  and the arrows step the slider and the segmented control. The ring
  (`kGlassFocusRingColor`, `kGlassFocusRingWidth`, `kGlassFocusRingGap`) is
  drawn inside the glass's own subtree, which no capture sees; a switch's or a
  segmented control's ring under other glass costs one capture as the focus
  changes.
- Right to left: the switch is on at the left, the slider fills from the
  right, the segmented control's first segment is at the right, the toolbar's
  first item is at the right, and the arrow keys follow.
  `SliderGeometry.fillEnd` takes a `textDirection`.
- `GlassConcentric`: Apple's concentric corners as arithmetic, a shape's
  radius as its container's less the inset, with a floor. The segmented
  control's capsule (pixel for pixel what it was) and the focus rings use it.

Fixes:

- A dismissible sheet follows the finger: a 116 px drag moved it about
  4.5 px. It closes past a third of its height or on a flick, and while it
  moves it declares where it travels: one retake a drag instead of 16.
- Under right to left, the segmented control's capsule sat under the wrong
  label, and `GlassButtonGroup` brightened the wrong cell.

Performance:

- The shaders' uniforms are packed into `vec4`s: 19 slots to 9 for a surface
  and a group, 24 to 12 for the ripple. Metal binds each declared float
  uniform on its own every draw, where Vulkan binds one struct. The pixels are
  byte-identical; the raster thread spends 0.9 to 1.4 µs less a surface draw
  and 1.0 to 1.8 µs less a group draw, on macOS under Impeller/Metal. The ripple's
  `count`, `reach` and `light` moved after its arrays, which matters only to
  code that writes the uniforms by hand.

Platforms:

- The floor is Flutter 3.47.0 (Dart 3.13.0): `sdk: ^3.13.1` shut 3.47.0 out
  although the package runs on it unchanged, and CI now tests that exact
  version rather than the newest 3.47 patch. Below 3.47 the package would need
  code changes, and on Apple hosts that opt into SDF rendering it would draw
  differently, so the floor stays there.

Documentation:

- "Misuse and common errors", in the README and on the site: each mistake
  with what it looks like, the error text where there is one, the cause and
  the fix.
- The site has a page with a live demo for the stepper, the page control, the
  search bar and the badge, and the sheet, tab bar, button, slider and
  segmented control pages show detents, the collapse, the press, divisions,
  the keyboard and right to left. The README has a pattern for a tab bar that
  collapses on scroll, and the agent skill has the same pages and rules.

## 0.1.4

- `showGlassSheet(barrierDismissible: false)` is a sheet only its content
  closes, as UIKit's `isModalInPresentation`: a drag or a flick used to close
  it whatever the flag said. Now a pull gives a quarter of the way, no more
  than half the sheet's height, and springs back; the dim and Escape were
  already held by the flag.

Documentation:

- The API reference is grouped into topics, each with a page of its own:
  Getting started, Foundations, Panels and controls, Modals, Composition,
  Capture control, Cost and policy, Diagnostics. Every public name has a doc
  comment, the main widgets an example and a list of what to see next with
  their page on the site, and `dart doc` reports no unresolved reference.
- `GlassProxy`, the way to tell the capture what a subtree is, is in the
  README at last: a stand-in for a video, a map or a platform view (which
  record nothing, so the glass over them showed a hole), a subtree left out,
  an opaque cover, a blur the shadow filter keeps. The site has a page for it,
  live: Capture control.
- Every measured number now says where it comes from: the devices, their
  systems, the renderer, the metric, the dates, and the Flutter and engine
  revisions, in the README and on the site's How it works.
- An agent skill for Claude Code, Codex, Cursor, Antigravity, Gemini CLI and
  Copilot, in `skills/g1455/`: the rules for writing glass that works, with
  every page of the site as a reference. `npx skills add PlugFox/g1455`, or
  `/plugin marketplace add PlugFox/g1455` in Claude Code. The site publishes
  it at `/.well-known/agent-skills/` (`npx skills add
  https://g1455.plugfox.dev`), with `llms.txt`, `llms-full.txt` and every
  page as markdown at its address plus `.md`.
- pub.dev shows a square, still picture of the package: its icon leads the
  screenshots, ahead of the loops, which it showed as one frame. pub.dev takes
  ten, so the materialize loop makes room; the alert's shows the same arrival.

## 0.1.3

- The README's images show on pub.dev again. 0.1.2 linked the banner, the
  showcase loops and the How it works cards by relative path, and pub.dev
  drops a relative image; they are linked from GitHub again, as in 0.1.1.

## 0.1.2

Glass that reads its backdrop:

- `GlassHost(adaptive: GlassAdaptive())` tells each `GlassBar`, `GlassCard`
  and `GlassButton` the mean level of the captured backdrop inside its own
  box, and the glass picks the branch of `.regular` and its label from it: a
  bar over a photograph's sky and a button over its shadow each wear the
  branch Apple's material would. Off by default and free when off. On, a
  frame that captures reads back a 4 × 4-pixel cell per surface,
  asynchronously, at most once per `interval` (250 ms, a second on the web,
  where CanvasKit reads back synchronously), and a frame that keeps its
  capture reads nothing. A band of 12 code values and a hold of 600 ms keep a
  glass near the threshold from flickering; crossings tween over 300 ms and
  cut under reduced motion. A finish a component, the host or a theme names
  is kept, and only its label follows; under `richBackdrop` the label stays
  chosen against every backdrop. `GlassTheme.of(context).reading` hands the
  verdict to content on the glass. A raw `GlassSurface`, the scroll edge, the
  tab bar and the segmented control do not adapt yet.

Motion:

- `GlassMorph`: swap the child and the glass flows to its size, the way a
  button becomes its menu. It measures the child; `width` and `height` pin an
  axis, and `alignment` names the point that holds still. While it grows it
  is a two-shape union, a body on a spring and a capsule running ahead, so
  the outline has a neck. At rest it is one plain surface, and a settled
  morph is that surface pixel for pixel. `GlassMorphMotion.fluid` and
  `.calm`; under reduced motion it changes at once. A morph is a capture per
  frame, unless a `GlassTravel` around a fixed-size ancestor holds it.
- The held drop in the switch, the slider, the segmented control and the tab
  bar stretches as it sets off and squashes as it stops, from its
  acceleration, and springs back round; at rest and at a constant speed it
  keeps its shape. `GlassHost.dropMotion` or `GlassThemeData.dropMotion` sets
  it for the app, and each control's `dropMotion` overrides it;
  `GlassDropMotion.none` turns it off, and so does reduced motion. It costs no
  capture: the drop deforms inside the region it already travels in. It does
  repaint the drop's own layer on the frames it deforms.
- `GlassTabItem` takes an `iconBuilder` and a `labelBuilder`, handed the
  colour the bar draws the item in, so an SVG, an image or a badge matches its
  neighbours. **Breaking for code that reads it:** `GlassTabItem.icon` is now
  nullable, so `item.icon` used as an `IconData` needs a null check.

Start-up and scaffolding:

- `GlassHost.precache()` compiles the package's shaders before the first
  frame. Call it in `main()` after `WidgetsFlutterBinding.ensureInitialized()`,
  and the first frame that has a capture is drawn through the optics rather
  than as the plain blurred backdrop. It shares the loads a host starts on its
  own, so it never compiles a program twice; `group: false` and
  `ripple: false` leave those out.
- `GlassScaffold` is a screen wired the way the README recommends: a host when
  none is above it, a top bar in a soft `GlassScrollEdge`, an optional bottom
  bar and floating action, and a body that scrolls under the bars and is told
  their extents through `MediaQuery.padding`.

Fixed:

- A shader that fails to load no longer escapes as an uncaught error. A host
  or a ripple that waited on it reports it through `FlutterError`, and the
  failed load is forgotten, so the next host or `GlassHost.precache()` tries
  again rather than being handed the same failure.
- On the web, a painter that throws while a glass layer records no longer
  leaks the shaders it drew with before the throw.

The package page and the README:

- The package page links the site as its documentation, names what is in the
  box in its description, and adds `glass` to its topics.
- The README opens with a loop of a whole app screen, shot headless like the
  tiles by `tool/showcase.sh screen`. How it works is four cards. The quick
  start is a whole app that runs as pasted. New sections give the values of
  every `GlassFinish` preset, five common patterns, and what is not here and
  why: no dispersion, because Apple's material has none to measure,
  and one shape, `RSuperellipse`. A test keeps the README's code identical to
  files that are analyzed and pumped, and its finish table equal to the
  constants. Every image is linked relatively.

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
beside the benchmark application that measures it: the library is now
`package:g1455/g1455.dart`, the shader asset keys are
`packages/g1455/shaders/...`, and `glass_diagnostics.dart` keeps its name.
Everything since the first cut:

**Breaking:** `GlassFinish.regular` is now `GlassFinish.regularDark`, and its
damage-table key is `'regularDark'`. It was always the dark branch of Apple's
`.regular`, because the iPad it was measured on was in dark mode. The light
branch is the new `GlassFinish.regularLight`: transmission 0.282, tint 252 at
0.718, and its own rows in the resolution and staleness tables.
`GlassFinish.regular(appearance:, backdrop:)` picks the branch Apple's
material would. It switches at a backdrop level of 54 in light mode and 222 in
dark mode. `GlassHost.finish` is now optional. Null means that choice,
following the declared `backdrop` and the platform's appearance. `GlassTheme.of`
with no host above does the same. At the default budget the light branch may
hold its capture one frame (0.284 ΔE against 0.348).

Drops and lone panels no longer appear through `presence`, which eroded a
capsule to a bright line about 2 pt tall for ~50 ms on the way out. The
tab bar's, switch's, slider's and segmented control's drops, and the alert and
the menu, now come and go through `materialize`, as Apple's do.

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

New components, read off Apple's own on iOS 26.5 simulators:

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
  The menu is placed as Apple places a button's menu: over the anchor,
  corner on corner, with the anchor hidden. It is 250 wide with rows of 42 and
  a 31.5 corner. When it opens upward, its items are reversed.
  These need the `GlassHost` above the navigator (`MaterialApp.builder`), and
  they say so in debug when it is not.
- `GlassSurface.fade` (`GlassFade`): the glass fades across itself. It is a
  smoothstep, and an exact `1.0` when unused.

- `GlassRipple`, optional and not Apple's: a viscous wave from where the
  glass was touched. A dimple sinks under the finger, a front travels out, and
  the dimple springs back on release. `viscosity` goes from water to honey. Set
  it on `GlassHost.ripple`, `GlassThemeData.ripple` or `GlassSurface.ripple`. It
  is drawn by a second program, so a surface with no wave runs the same bytes as
  before, and a wave takes no capture. Off under reduced motion. Not drawn by
  fused group members.

Fixed:

- The slider's fill ended in a square cut that the clear drop magnified. It is
  now a capsule, as Apple's is.
- A screen whose only glass was a resting drop (switches, segments) never
  stopped drawing. `publishUpper` notified listeners on every frame even when
  nothing had changed.
- Under glass on glass, a still screen recorded on every frame when the lower
  glass held content that was not behind a `RepaintBoundary`, such as a plain
  `Text`. The publish repainted the content, and the new pictures read as a
  change. A surface now re-adds its content layer when only the proxy
  changed.
- With two finishes on one screen, each blur class blurred the whole atlas.
  It now blurs only the box around its own slots. On the iPad this was 0.8 ms
  of a scrolling frame with a scroll edge over cards.

## 0.1.0-dev.1

Not published.

First cut of the package, moved out of the benchmark application that
measured it. Behaviour is unchanged from that application's `lib/`, with one
exception: a debug assertion. The changes:

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
  reads a second walk that excludes only the glass draws.
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
  enabled. A control disabled mid-press or mid-drag lets go.
