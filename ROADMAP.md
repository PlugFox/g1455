# Roadmap

What comes next, and why. Each item says what it costs when it is on and how
it is turned off: anything that adds a capture, a read-back, a shader pass or
a ticker is a declaration on `GlassHost`, `GlassTheme` or the widget, and the
cheap setting is reachable without a fork.

## Now — branch `improvements`

### The package page

- [ ] `documentation:` in the pubspec, pointing at the site, so pub.dev links
      it from the side panel.
- [ ] Topics people search for: `glass` and `shaders` next to `liquid-glass`.
- [ ] A description that names what is in the box, not only how the capture
      works.

### The README

- [ ] One loop of a whole screen above the tiles: a bar, a list scrolling
      under it, a tab bar, a menu opening — glass in an app, not on a stage.
- [ ] A quick start that runs as pasted: a whole `MaterialApp`, a backdrop
      worth refracting, a bar and a tab bar.
- [ ] The values of each `GlassFinish` in a table, so a reader can compare
      `.clear` with `.frosted` without opening the API reference.
- [ ] Common patterns: glass over a scrolling list, moving glass in a
      `GlassTravel`, glass on glass, a dialog over a bar, the cheap rung.
- [ ] What is not here, and why: dispersion, shapes other than
      `RSuperellipse`.

### Glass that reads its backdrop

- [ ] The host already holds the pixels under every surface in its atlas. A
      surface can be told the mean luminance of its own slot and pick the
      dark or light branch of `.regular`, and its label colour, from it,
      instead of from what the application declared.
- [ ] Off by default. On, it costs one small read-back per capture, never per
      frame, and nothing on a frame that keeps its capture. A hysteresis band
      and a minimum hold keep a surface from flickering over a backdrop near
      the threshold.

### Motion

- [ ] `GlassMorph`: swap the child and the glass flows to its new size, the
      way a button becomes a menu in iOS 26. Built on the group's union, so
      mid-morph the outline has a waist.
- [ ] The drop in the slider, switch, segmented control and tab bar stretches
      as it launches and squashes as it brakes, from its acceleration.
      A spec on the theme; none under reduced motion; zero turns it off.
- [ ] Custom icons and labels in tabs, through a builder that is handed the
      colour the bar resolved for the layer it draws.

### Start-up and scaffolding

- [ ] `GlassHost.precache()`: compile the bundled shaders before the first
      frame, so the first glass on screen is glass on that frame.
- [ ] `GlassScaffold`: a host, a bar, a body that scrolls under it and an
      optional tab bar, wired the way the README recommends.

## Later

- A contact shadow as part of the finish: a soft ring under the rim, painted
  without a capture.
- Glass that answers a finger as a soft body: swells under a press, leans
  after a drag, springs back. Each edge on its own spring.
- Reading reduce transparency, increase contrast and thermal state natively,
  as an optional companion package, so the core stays free of platform code.
