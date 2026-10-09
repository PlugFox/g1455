# Misuse & common errors

> What goes wrong with glass and why: missing glass, holes, grey boxes, a capture on every frame, and the debug messages the package prints, each with its fix.

- Live: https://g1455.plugfox.dev/start/common-errors
- API: [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassSurface`](https://pub.dev/documentation/g1455/latest/g1455/GlassSurface-class.html), [`GlassProxy`](https://pub.dev/documentation/g1455/latest/g1455/GlassProxy-class.html), [`GlassTravel`](https://pub.dev/documentation/g1455/latest/g1455/GlassTravel-class.html), [`GlassAbove`](https://pub.dev/documentation/g1455/latest/g1455/GlassAbove-class.html), [`debugPaintGlassSurfaces`](https://pub.dev/documentation/g1455/latest/g1455/debugPaintGlassSurfaces.html)
- Source: [`lib/src/surface/glass_host.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_host.dart)

Most mistakes with glass fail quietly: no exception, only glass that is missing, grey, or captured on every frame.
Each entry below is a symptom, its cause and the fix. Where a debug build says something, the message is quoted as it
starts.

To see where the glass is, set `debugPaintGlassSurfaces = true` in a debug build: every surface gets a cyan outline.

## Setup

### Only the children are drawn, with no glass

A surface samples the capture of the [GlassHost](../foundations/host.md) above it. With no host above, it paints its child
over nothing, and says nothing. Put one host in the app's `builder:`, as in [Installation](../start/installation.md).

### "GlassAlert was built with no GlassHost above it."

The same error names "A glass sheet", or the panel of a menu or a popover. A dialog and a sheet are built in the
navigator's overlay, and a menu and a popover in the nearest overlay, so a host around one screen, inside the route,
does not reach them. That includes the host [GlassScaffold](../components/scaffold.md) mounts when there is none above it.
The check runs in debug only; in release the modal shows without glass. Move the host above the navigator:

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(child: child!),
  home: const HomePage(),
)
```

### A GlassTheme above the host changes nothing

The host installs a theme of its own, built from its parameters, for everything under it, so a `GlassTheme` above the
host is overridden. Declare screen-wide settings on `GlassHost`, and put a `GlassTheme` below it to change a subtree.

### The first frames show no glass, then a blur with no tint or rim

Two delays, of which only one is avoidable. The host captures a frame after it has been painted, so the first frame of
any screen has no glass; that is by design. The shaders compile asynchronously, and until they arrive, glass that has a
capture draws the blurred backdrop clipped to its shape, without tint, rim or bend. `await GlassHost.precache()` in
`main()` compiles them before the first frame. A shader that fails to load is reported "while loading a glass shader",
and the glass keeps drawing that stand-in.

## What the glass shows

### A hole over a video, a map or a platform view

The host captures what is under its glass by painting that part of the tree a second time. A platform view, a
`Texture`, a video or a camera preview paints outside Flutter's pictures and records nothing. Wrap it in
`GlassProxy.replace` with a stand-in, as on [Capture control](../foundations/capture.md). A stand-in changes what the glass
sees, not when the host captures: a video that composites a new frame is still a change.

### Glass inside an Opacity or a fade disappears

An `Opacity` below 1, an `AnimatedOpacity` or a `FadeTransition` mid-animation, a `ColorFilter` or an `ImageFiltered`
opens a layer, and glass inside that layer does not survive it. On the [cheap tier](../foundations/tiers.md) the rim and the
press highlight, which add light to what is under them, add it to the layer instead: one `Opacity(0.99)` above a
button takes its press from +50 code values to +4.

To fade glass, animate the surface's `materialize` (blur first, tint last); to hide it, use `Visibility`. The package
does both itself: its alert materializes, and a menu hides its anchor button with `Visibility`.

```dart
// Not Opacity(opacity: t, child: GlassSurface(...)).
GlassSurface(materialize: t, child: label)
```

Content that fades *under* the glass is fine: the host sees the fade and captures it.

### A bar over glass cards shows the page with the cards cut out

The bar is the cards' sibling, and sibling glass does not see sibling glass. Wrap the bar in
[GlassAbove](../foundations/above.md), which raises it a level so it refracts the cards. Glass nested inside glass, a
[scroll edge](../foundations/scroll-edge.md) and the package's modals are lifted already.

### An unlifted bar shows up blurred inside a scroll edge

Levels are a declaration, not paint order: glass beside a lifted subtree is drawn into its capture even when it is
painted on top of it. Lift the bar with the edge; `GlassScrollEdge.child` does that for you.

### A surface that replaces another at the same place draws nothing

A known issue, not yet fixed: when a host replaces one surface with another at exactly the same rect, it keeps the old
capture, and the new surface draws nothing until something else under the glass changes.

## Look and legibility

### "A glass component has no GlassThemeData.backdrop, and its finish is not legible over every backdrop"

Printed once, in debug. Nothing said what is behind the glass, so the label was chosen against every backdrop, and
none reaches WCAG AA over the worst of them. Declare the screen's background as `GlassHost(backdrop: ...)` if it is
flat, or `richBackdrop: true` with `minLabelContrast: kTextContrastAA` over an image or a feed: the glass is then dimmed
until the label reaches the floor. Or let the glass measure it: [adaptive glass](../foundations/adaptive.md). See
[What the app declares](../start/declarations.md).

### "GlassTier.opaque with no GlassThemeData.backdrop declared."

The opaque tier transmits nothing, so it fills with the level the glass would show over the declared `backdrop`.
Without one the fill is the finish's tint itself, much darker than the glass: 29 of 255 for `GlassFinish.regularDark`,
against the 69 the glass shows over mid-grey. Declare `backdrop:` whenever the opaque tier can be chosen, which includes
every app that passes Reduce Transparency to a `GlassTierPolicy`.

### Glass over a flat colour is a grey box

Glass shows what is behind it, bent, blurred and tinted; over one flat colour that is the same colour, tinted. Put
glass over content, in a `Stack`. Over a plain page, a plain `Container` or `Card` is the honest choice.

### A lens or a held drop looks grey

A surface counts as labelled by default, and the label floor (`minLabelContrast`) dims the glass for a label it does
not have. Pass `labelled: false` to glass that carries no text.

### Labels or icons in a bar have the wrong colour

[GlassBar](../components/bar.md), [GlassCard](../components/card.md), [GlassButton](../components/button.md) and the modals set
`DefaultTextStyle` and `IconTheme` to the legible colour, black or white. A colour hard-coded inside them overrides
it, and so does a widget that takes its colour from the app's `ThemeData` rather than from those two. Leave the colour
out, or pass `IconTheme.of(context).color` on.

### Adaptive glass does not adapt

`GlassHost(adaptive: GlassAdaptive())` re-picks the glass for bars, cards and buttons only. A raw `GlassSurface`, a
`GlassScrollEdge`, the tab bar and the segmented control keep the branch picked from `backdrop`, and a fused group's
members adapt only their labels. A finish that is named anywhere, on the surface, the component, the host or a theme,
is held, and only its label follows the reading.

### "N of M surfaces in a GlassGroup name their own finish."

A fused [group](../foundations/groups.md) is one draw with one set of optics, so the group's finish is what ships and the
members' are ignored. Put the finish on the `GlassGroup`, or take the surface out of it. For the same reason a member
of a fusing group draws no `fade` and no ripple.

### "A GlassGroup holds 13 surfaces; the fused draw carries 12."

`kMaxFusedShapes` is 12. Past it the group is refused rather than truncated: its members draw themselves, and the
bridges between them are missing. Split the group, or fuse fewer surfaces.

### A ripple does not show

[GlassRipple](../foundations/ripple.md) is off while the platform asks for reduced motion, below `GlassTier.full`, and on a
member of a fusing group. It is also off by default: declare it on `GlassHost.ripple` or on the surface.

### A panel appearing through presence narrows to a line

`presence` erodes the shape and is for budding inside a `GlassGroup`; a lone panel erodes to its middle line. Animate
`materialize` to make a panel appear or leave.

## Cost

### Moving glass captures on every frame

A surface's slot in the capture is its own box, so glass that moves is captured again wherever it goes. Wrap the
region it moves in in a [GlassTravel](../foundations/travel.md): the host captures the whole region once, and moving over
still content inside it captures nothing. The switch, slider, segmented control and tab bar already do this.

### Glass inside a GlassTravel still captures as it moves

Motion is free only if moving the glass repaints nothing else, because a repaint under the glass is changed content.
Put the still content behind a `RepaintBoundary` of its own and the moving glass behind another, so the moving glass's
parent paints nothing. A surface that leaves the region is captured again.

### A custom finish costs more than the preset it came from

A finish's `name` is its key into the measured quality tables. A name that is not in them gets no measured damage, so
the host does not lower the capture's resolution for it. Derive a custom finish with `copyWith` from the preset it is
closest to, which keeps the name.

### Too much glass

Each surface is one more draw, and the cost grows faster than the count. Keep glass to the navigation and controls
layer, not every card of a feed. A row of icon actions is one [GlassButtonGroup](../components/toolbar.md), and plain icons
inside a bar are cheaper than glass buttons, which are glass on glass: a level, and a snapshot per captured frame.
[GlassGroup and GlassUnion](../foundations/groups.md) are a look, not a saving: twelve clustered surfaces grouped cost
1.60 to 1.65 times the same twelve ungrouped. See [Performance](../foundations/performance.md).

### Glass is coarser on a large window

The capture must fit the GPU's texture limit, and the host's only answer to hitting it is a coarser capture. The limit
it assumes is the specification's floor, not the device's: 4096 on Vulkan, 8192 on Metal, 2048 on GLES. Every GPU the
package was measured on allocates 16384; a host that knows its device can say so with `GlassHost(maxTextureSide:)`.

### Every frame captures, still screen or not

`GlassHost(content: GlassContentDeclaration.undeclared)` re-captures on every frame. It exists to rule the change
detection out, and is the most expensive thing the package can be asked to do; don't ship it. The same goes for
`maxCaptures`, `resolution`, `blurPass` and `package:g1455/glass_diagnostics.dart`.

### Slow on the web outside Chromium

CanvasKit reads every capture back from the GPU. Build with `--wasm`, and where the app still runs on CanvasKit,
declare the cheap tier. See [Platforms & web](../start/platforms.md).

## Platform settings

### Reduce Transparency, increased contrast or thermal state change nothing

Flutter does not pass Reduce Transparency or thermal state on, nor increased contrast on macOS, and the package ships
no platform code to read them. Read them natively and declare them: `GlassTierPolicy(reduceTransparency: ...)`,
`GlassHost.highContrast`, `GlassHost.thermal`. Tiers never change on their own. See
[What the app declares](../start/declarations.md).

### The user's Reduce Transparency is ignored

`GlassTierPolicy(pinned: ...)` overrides everything, the user's setting included. Pin a tier in tests and benchmarks,
never for users; for a low-end device, pass a `ceiling` instead.

## Widget tests

### No glass on the first pump

Glass widgets need a `GlassHost` above them in the test as in the app, and above the `Navigator` for modals. The first
frame has no glass, because the capture lands a frame later: pump at least one more frame before looking for it.

### await GlassHost.precache() never completes

The shader load needs real time, and a widget test's fake clock does not give it. Alternate `tester.runAsync` with
`tester.pump` until the future completes, or leave the precache out: the host loads the shaders on its own.
