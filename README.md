# g1455

[![pub](https://img.shields.io/pub/v/g1455.svg)](https://pub.dev/packages/g1455)
[![Checks](https://github.com/PlugFox/g1455/actions/workflows/checks.yml/badge.svg)](https://github.com/PlugFox/g1455/actions/workflows/checks.yml)
[![codecov](https://codecov.io/gh/PlugFox/g1455/graph/badge.svg)](https://codecov.io/gh/PlugFox/g1455)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Site](https://img.shields.io/badge/demo-g1455.plugfox.dev-8ab4ff.svg)](https://g1455.plugfox.dev)

Liquid Glass for Flutter: refraction, blur, tint and a rim over the live
backdrop, in the shape the engine already draws (`RSuperellipse`). Built for
cost first. Features come second.

The name is *glass*, spelled in digits.

> **Status: 0.x.** The API will still change between minor versions; every
> change is in the [changelog](CHANGELOG.md).

<p align="center">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/group.webp" width="800" alt="GlassGroup: three clear glass blobs orbit over the word GLASS and fuse into one silhouette where they meet">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/finishes.webp" width="800" alt="GlassFinish: regular, clear and frosted glass panels side by side over the same backdrop">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/ripple.webp" width="800" alt="GlassRipple: taps and a drag send viscous waves across a clear glass panel">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/switch.webp" width="800" alt="GlassSwitch: switches on a glass card, the knob turning into a clear drop while held">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/slider.webp" width="800" alt="GlassSlider: two sliders dragged, the knob a clear drop while held">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/tab_bar.webp" width="800" alt="GlassTabBar: the selection lifts into a drop that magnifies the bar and is dragged between tabs">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/segmented.webp" width="800" alt="GlassSegmentedControl: the selected segment lifts into a drop and slides to another">
<img src="https://raw.githubusercontent.com/PlugFox/g1455/master/doc/showcase/alert.webp" width="800" alt="GlassAlert: an alert materializes over the screen, blur first and tint last, and is dismissed">
</p>

Every loop above is rendered by the package itself, headless, from
`example/showcase/`; the tiles share one backdrop and meet without a seam.
To re-shoot them after a change, run `tool/showcase.sh` — see
[Re-shooting the animations](#re-shooting-the-animations).

## How it works

Most glass packages put a `BackdropFilter` on every surface, which means the
engine reads the backdrop once per surface on every frame. This package takes a
different route:

- **One host, one capture.** A `GlassHost` records what is painted under all of
  its glass into one atlas, at a resolution picked against a measured quality
  budget. Every surface then samples its own slot of that atlas.
- **A capture only when something changed.** The host walks the composited
  layer tree. When nothing under the glass changed, it keeps the proxy it
  already has. That covers a still screen, and a moving glass over content that
  stays put. Keeping the proxy is the default, and it is the biggest saving in
  the package: 79.4% and 66.3% of the route's added cost on Adreno, 97.8% on
  Metal.
- **The blur is a downscale.** A 1/N proxy is a Gaussian of σ ≈ N/2 to within
  about 1%, at a fraction of the price of a real Gaussian.

Measured costs, each on its own platform, because the platforms are not
comparable:

| platform | glass vs stock Material | engine `BackdropFilter.grouped` |
|---|---|---|
| Android, Impeller/Vulkan, Adreno 830 (GPU cycles) | ×0.99…1.08 | ×1.78…3.15 |
| iPad, Impeller/Metal (GPU ms, scrolling screen) | ×1.93…2.02, or ×1.46…1.54 with thermal throttling | — |

## Install

```bash
flutter pub add g1455
```

Requires Flutter 3.47 or later.

## Usage

```dart
import 'package:g1455/g1455.dart';

GlassHost(
  child: Stack(
    children: <Widget>[
      Positioned.fill(child: content),           // what the glass refracts
      Positioned(
        top: 16, left: 16, right: 16,
        child: GlassBar(child: Text('Library')),  // the glass
      ),
    ],
  ),
)
```

What is in the box:

- `GlassSurface` is the primitive: a region of the screen that is glass, with a
  corner radius, an optional finish, and `presence` / `materialize` for
  appearing.
- `GlassBar`, `GlassButton` and `GlassCard` are panels with a label colour
  chosen for legibility. `GlassSwitch`, `GlassSlider` and `GlassTabBar` are
  controls whose knob or selection turns into a clear drop while held.
- `GlassGroup` and `GlassUnion` draw several surfaces as one silhouette.
- `GlassTravel` declares the region a moving glass travels in, so the motion
  does not trigger a capture.
- `GlassFinish.regularDark`, `.regularLight`, `.clear` and `.frosted` are the
  optics, calibrated against Apple's own materials on iOS 26. Apple's
  `.regular` is two materials, dark over dark content and light over light,
  and `GlassHost` picks the branch the same way unless you name one:
  from `backdrop` and the platform's appearance.
- Glass appears and leaves through `GlassSurface.materialize`: the bend, the
  blur and the tint arrive over the whole shape. `presence` erodes the shape
  and is for budding inside a `GlassGroup`; on a lone panel it narrows to a
  line.
- `GlassTier` / `GlassTierPolicy` pick the rung: full glass, a flat
  translucent fill, or opaque. Use it for reduce transparency, low-end devices
  and thermal pressure.
- `GlassLedger` reports how much glass is on the screen and what it costs.
- `GlassRipple` is optional and not Apple's. When the glass is touched, a
  viscous wave spreads from the touch: a dimple under the finger, a front that
  travels out, and a spring-back on release. `viscosity` goes from water (0)
  to honey (1). Declare it on `GlassHost.ripple` for every surface, or on
  `GlassSurface.ripple` for one. A wave takes no capture and repaints nothing,
  and a surface with no wave runs the same shader as before. It is off under
  reduced motion.

Every component is live at **[g1455.plugfox.dev](https://g1455.plugfox.dev)**,
with its guide, its code and its API. The site is the [`example/`](example/)
app built for the web: one host, every component on its own page, the original
full-screen demos, and a settings menu that switches the finish, the tint, the
rung and the ripple.

### Things the application has to declare

The package cannot work some things out from the render tree, so the
application declares them:

- **What is behind the glass**, for label legibility: `GlassHost.backdrop` for
  a flat colour, or `richBackdrop: true` with `minLabelContrast` for an image or
  a scrolling feed. Without either, labels are picked against the worst case,
  and in debug the package warns when a finish cannot be read over it.
- **Reduce transparency, increase contrast on macOS, and thermal state.**
  Flutter does not pass these on, and this package ships no platform code to
  read them. Read them natively and pass them in: reduce transparency to
  `GlassTierPolicy`, contrast to `GlassHost.highContrast`, thermal state to
  `GlassHost.thermal` as a `GlassThermalState`. On iOS and Android 34+ the
  host already reads contrast from `MediaQuery`. On macOS the engine does not
  pass it on.
- **The hardware family**, if it is not an Apple device: `GlassHost.hardware`.
  Undeclared hardware gets the same behaviour with no price attached.

## Platforms

The route renders byte-identically on Impeller (Metal, Vulkan, GLES) and on
Skia/GLES, which Android falls back to below API 29 and on Vivante GPUs. It also
works on web, with both CanvasKit and Skwasm. Every bundled shader is compiled
for all five shader targets in `test/shader_targets_test.dart`, so a shader that
SkSL would reject fails the tests rather than a user's app.

## Diagnostics

`package:g1455/glass_diagnostics.dart` exposes the switches a benchmark flips,
such as the tile split of a group's draw and the anti-alias flag. It also
exposes the host's proxy handle, whose counters show whether a frame captured.
An application has no reason to import it.

## Development

```bash
flutter pub get
dart format .
flutter analyze --fatal-infos
flutter test --coverage
(cd example && flutter test test/ showcase/)
```

`dart format` takes its width (120) and its trailing-comma rule from
`analysis_options.yaml`, and CI fails on a file it would change.

Some tests check a constant baked into `lib/` against the measurement it came
from. Those measurements are copied into `provenance/`, unchanged and under
their original file names. They live in the repository only; the published
package does not carry them.

A pull request runs the same checks in CI, plus `flutter pub publish --dry-run`
and pana. A release is a tag: bump `version` in `pubspec.yaml`, add its
`## <version>` section to `CHANGELOG.md`, and push `v<version>`. The tag
publishes to pub.dev and opens a GitHub release with that section as notes.

## Re-shooting the animations

```bash
tool/showcase.sh                  # every scene
tool/showcase.sh switch,tab_bar   # just these
```

The script plays each scene of `example/showcase/scenes.dart` under
`flutter test`, with a fake clock and scripted touches, so every run produces
the same frames and needs no device. It plays one loop to let springs and waves
settle and records the next, and it fails if the last frame does not lead back
into the first. It then packs the frames into looping webp files in
`doc/showcase/` with `cwebp` and `webpmux` (from libwebp: `brew install webp`),
each frame encoding only the rect that changed.

The screenshots pub.dev shows are the same loops at half the size, because pub
ships them with the package:

```bash
SHOWCASE_DPR=1 SHOWCASE_DIR=doc/screenshots tool/showcase.sh
```

A new scene is a `ShowcaseScene` in that list: a builder given the loop's phase
from 0 to 1, and `Stroke`s for the fingers. Scenes are cut from one tall
backdrop in list order, so a scene's position in the list is its place in the
strip.

## License

[MIT](LICENSE)
