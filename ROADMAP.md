# Roadmap

What comes next, and why. Each item says what it costs when it is on and how
it is turned off: anything that adds a capture, a read-back, a shader pass or
a ticker is a declaration on `GlassHost`, `GlassTheme` or the widget, and the
cheap setting is reachable without a fork.

## Done — branch `improvements`

### The package page

- [x] `documentation:` in the pubspec, pointing at the site, so pub.dev links
      it from the side panel.
- [x] Topics people search for: `glass` next to `liquid-glass` (`shader` stays:
      on pub.dev it has about twice the packages of `shaders`).
- [x] A description that names what is in the box, not only how the capture
      works.

### The README

- [x] One loop of a whole screen above the tiles: a bar, a list scrolling
      under it, a tab bar, a menu opening — glass in an app, not on a stage.
- [x] A quick start that runs as pasted: a whole `MaterialApp`, a backdrop
      worth refracting, a bar and a tab bar.
- [x] The values of each `GlassFinish` in a table, so a reader can compare
      `.clear` with `.frosted` without opening the API reference.
- [x] Common patterns: glass over a scrolling list, moving glass in a
      `GlassTravel`, glass on glass, a dialog over a bar, the cheap rung.
- [x] What is not here, and why: dispersion, shapes other than
      `RSuperellipse`.

### Glass that reads its backdrop

- [x] The host already holds the pixels under every surface in its atlas. A
      surface can be told the mean luminance of its own slot and pick the
      dark or light branch of `.regular`, and its label colour, from it,
      instead of from what the application declared.
- [x] Off by default. On, it costs one small read-back per capture, never per
      frame, and nothing on a frame that keeps its capture. A hysteresis band
      and a minimum hold keep a surface from flickering over a backdrop near
      the threshold.

### Motion

- [x] `GlassMorph`: swap the child and the glass flows to its new size, the
      way a button becomes a menu in iOS 26. Built on the group's union, so
      mid-morph the outline has a waist.
- [x] The drop in the slider, switch, segmented control and tab bar stretches
      as it launches and squashes as it brakes, from its acceleration.
      A spec on the theme; none under reduced motion; zero turns it off.
- [x] Custom icons and labels in tabs, through a builder that is handed the
      colour the bar resolved for the layer it draws.

### Start-up and scaffolding

- [x] `GlassHost.precache()`: compile the bundled shaders before the first
      frame, so the first glass on screen is glass on that frame.
- [x] `GlassScaffold`: a host, a bar, a body that scrolls under it and an
      optional tab bar, wired the way the README recommends.

## Done — 0.2.0

- [x] A backdrop the application declares (`GlassBackdrop`): a colour, an
      image, a texture or a painter, per subtree. Glass under it samples a
      texture made once per finish blur and size, and the host captures
      nothing for it; `GlassBackdrop.live` hands a part back to the capture.
- [x] The SDK floor at Flutter 3.47.0 / Dart 3.13.0, the lowest the package
      runs on unchanged; CI tests that exact version.
- [x] "Misuse and common errors" in the README and on the site.
- [x] Four components: `GlassStepper`, `GlassPageControl` and
      `GlassSearchBar`, one surface each, and `GlassBadge`, which is not glass
      and costs none. Cancel's slide is the one capture they add: 16 over
      250 ms, each way.
- [x] Sheet detents (`GlassSheetDetent.medium`, `.large`); a large sheet at
      full alpha drops to the cheap rung and reads no backdrop.
- [x] A dismissible sheet follows the finger, and declares where it travels
      while it moves: one retake a drag instead of 16.
- [x] A tab bar that collapses to its selected tab on a scroll down
      (`GlassTabBarMinimizeBehavior`, `GlassTabBarMinimizer`), with a
      `bottomAccessory`; the collapse is declared travel and takes no capture.
- [x] `GlassPress`: a button swells under the finger and leans after a drag,
      two captures a press and none at rest; `GlassPress.none` turns it off.
- [x] `GlassSlider.divisions`; controls that claim a drag from touch-down
      inside a `PageView`; keyboard focus for the button, switch, slider,
      segmented control and toolbar cells; right to left for the switch,
      slider, segmented control and toolbar.
- [x] `GlassConcentric`, the rule for a shape nested in glass, used by the
      segmented control and the focus rings.
- [x] Shader uniforms packed into `vec4`s: 19 slots to 9 for a surface and a
      group, 24 to 12 for the ripple; byte-identical pixels, about a
      microsecond less raster time a draw on Metal.

## Done — 0.3.0

- [x] The tab bar adapts as one control: its accessory wears the bar's
      verdict on its backdrop.
- [x] `GlassLoad` prices only glass that draws; a control's drop at rest is
      `restingSurfaceCount`.
- [x] Controls removed under a held finger ignore the rest of the gesture.
- [x] A surface that replaces another at the same rect, or glass back on the
      top rung where it was, gets a capture: the host compares whose
      rectangles it captured, not only where they are.
- [x] Animation controllers are created in `initState`, never first from
      `dispose` (flutter/flutter#185248): the menu and popover anchors and a
      page control given a `PageController`.

## Done — 0.4.0

- [x] `GlassHost.appearance`, for an app whose theme does not follow the
      phone's (#16).
- [x] Fills, reds and the grabber's grey in the appearance of the glass
      they lie on (#15).
- [x] Large text: the tab bar and the segmented control stop at the default
      size, as UIKit's do; the field grows (#20).
- [x] Right to left: the tab bar's touches, capsule and drop (#19), menu
      rows, and the segmented control's capsule as segments change.
- [x] Clips at fractional device pixel ratios: the tab bar's drop (#23) and
      its accessory.
- [x] The capture walk: a shader mask off the origin, a composited image
      filter at an offset, filters under a fade, and the shadow filter's
      sharp draws (#17, #18).

## Next — what 0.4.0 left open

- [ ] A fallback for what the walk cannot reproduce (#32).
- [ ] Menus that grow with large text (#26) and the tab bar's large content
      viewer (#27).
- [ ] Every control's default colours per appearance (#28).

## Next — what 0.2.0 left open

- [ ] The engine's `RSuperellipse` corner in the shader. Tried and deferred:
      +22% fragment GPU time on a Mac, and Skia draws a native
      `RSuperellipse` as an `RRect`, so on Skia the glass and the engine's own
      shape would not agree. Measure it on Adreno before deciding.
- [ ] A bare `setState` on a `GlassTabBar` costs one capture even when nothing
      it draws changed. Measured, not traced.
- [ ] The dim behind a sheet does not fade while the sheet is dragged down to
      close.
- [ ] No trailing action circle beside the tab bar, such as the search tab
      iOS 26 sets apart from the others.
- [ ] Content that scrolls inside a sheet does not hand the drag over to the
      sheet at its top, as UIKit's does.
- [ ] `GlassPageControl` with many pages: iOS shrinks the dots toward the ends
      of a long row; ours draws them all at one size.
- [ ] Apple's medium detent is half the window whatever the content; ours is
      the content's height.

- [ ] Measure a declared backdrop against its capture on the devices: the
      saving is a snapshot per changed frame, and a still screen already
      holds its capture, so the price on a scrolling or animating screen is
      the number to have.
- [ ] Adaptive glass over a declared backdrop: the texture is in hand, so the
      mean level is a read-back once per texture, not per capture.

## Next — what the branch left open

- [ ] Adaptivity for the rest: a raw `GlassSurface`, `GlassScrollEdge` (still
      keys its tint off the declared `backdrop`) and the segmented control.
      Fused group members adapt only their labels. The tab bar adapts as one
      control from 0.3.0: its accessory wears the bar's verdict.
- [ ] Measure the adaptive read-back on devices, CanvasKit and Skwasm
      included; the band, hold and interval are taste until then.
- [ ] `GlassMorph`: carry the spring's velocity through a swap mid-morph, and
      keep glass inside fading content (an `Opacity` layer drops it).
- [ ] `GlassScaffold`: the keyboard (`viewInsets`), a bottom scroll edge, and
      a top bar shorter than `topBarHeight`.
- [ ] Tune the drop's stretch and the morph's timing against Apple's devices;
      both are set by eye.

## Later

- A contact shadow as part of the finish: a soft ring under the rim, painted
  without a capture.
- Glass that answers a finger as a soft body, each edge on its own spring.
  `GlassPress` (0.2.0) swells, leans and springs back as one shape; Apple's
  press is still to be measured.
- Reading reduce transparency, increase contrast and thermal state natively,
  as an optional companion package, so the core stays free of platform code.
