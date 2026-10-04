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

## Next — what the branch left open

- [ ] Adaptivity for the rest: a raw `GlassSurface`, `GlassScrollEdge` (still
      keys its tint off the declared `backdrop`), the tab bar and the
      segmented control. Fused group members adapt only their labels.
- [ ] Measure the adaptive read-back on devices, CanvasKit and Skwasm
      included; the band, hold and interval are taste until then.
- [ ] A host replacing one surface with another at exactly the same rect
      keeps the old capture, and the new surface draws nothing until
      something else changes. Found while testing `GlassMorph`; look in
      `glass_host.dart`.
- [ ] `GlassMorph`: carry the spring's velocity through a swap mid-morph, and
      keep glass inside fading content (an `Opacity` layer drops it, D185).
- [ ] `GlassScaffold`: the keyboard (`viewInsets`), a bottom scroll edge, and
      a top bar shorter than `topBarHeight`.
- [ ] Tune the drop's stretch and the morph's timing against Apple's devices;
      both are set by eye.

## Later

- A contact shadow as part of the finish: a soft ring under the rim, painted
  without a capture.
- Glass that answers a finger as a soft body: swells under a press, leans
  after a drag, springs back. Each edge on its own spring.
- Reading reduce transparency, increase contrast and thermal state natively,
  as an optional companion package, so the core stays free of platform code.
