# g1455_example

One `GlassHost` over the whole screen, four pages under it, and the glass on
top: an app bar with a settings menu, and a tab bar between the pages.

- **Scroll** — a list scrolling under the bars, a slider, buttons, and a lens
  to drag over the list.
- **Controls** — switches, sliders and buttons on glass cards. The hue slider
  and "Drift backdrop" change what is under the glass on every frame.
- **Blobs** — metaballs: blobs in a `GlassGroup` fuse when they come within
  `spacing`, or are all joined in a `GlassUnion`. They orbit inside a
  `GlassTravel`, so the motion costs no capture. One blob follows the finger,
  and the − / + buttons bud blobs in and out through `presence`.
- **Cards** — a photo grid with a glass caption on every photo.

The settings menu (the tune icon in the app bar) works like a game's graphics
settings. It sets:

- the material: Regular, Clear or Frosted;
- the tint: Neutral, Indigo or Rose;
- the rendering: Glass, Translucent (the cheap rung, no capture) or Opaque;
- the ripple: Off, Water, Jelly or Honey. This one is not Apple's;
- the contrast: System, or Increased.

Above them are the presets: Ultra (glass with a ripple), High (glass as iOS
draws it), Medium (translucent) and Low (opaque). Change any setting and the
preset becomes Custom. Set it back and the preset returns. The app bar shows
the preset in force.

```bash
flutter run --profile -d <device>
```

Profile rather than debug if you are looking at cost: debug builds are not
representative of what the GPU does.
