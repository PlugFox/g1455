# How it works

> One host captures the backdrop once for every glass surface, only when something under the glass changed.

- Live: https://g1455.plugfox.dev/start/how-it-works
- API: [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassTravel`](https://pub.dev/documentation/g1455/latest/g1455/GlassTravel-class.html)
- Source: [`lib/src/surface/glass_host.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_host.dart)

Most glass packages put a `BackdropFilter` on every surface, which means the engine reads the backdrop once per surface
on every frame. g1455 takes a different route, built for cost first: one capture for the whole screen, taken only when
it has to be, and a blur that comes almost for free.

Knowing the route helps you predict what is cheap and what is not, which is most of what there is to know about
performance with this package.

## One host, one capture

A [GlassHost](../foundations/host.md) records what is painted under **all** of its glass into one atlas, at a resolution
picked against a measured quality budget. Every surface then samples its own slot of that atlas and draws the
refraction, blur, tint and rim in one shader pass.

So ten surfaces do not mean ten reads of the backdrop. They mean one capture and ten draws.

## A capture only when something changed

The host walks the composited layer tree. When nothing under the glass changed, it keeps the capture it already has.
That covers a still screen, and a moving glass over content that stays put.

Keeping the capture is the default, and it is the biggest saving in the package: 79.4% and 66.3% of the route's added
cost on Adreno, 97.8% on Metal.

What triggers a new capture:

- content under the glass repaints: a list scrolls under a bar, an animation plays behind a card, a video runs;
- the glass appears, disappears, resizes or moves to a new place;
- a surface's `materialize` animates, because that changes the blur.

What does not:

- a still screen, however much glass it has;
- glass moving inside a [GlassTravel](../foundations/travel.md) region over still content, such as a slider's knob, a
  dragged lens or orbiting blobs;
- a blinking caret or typing in a [text field](../components/text-field.md);
- repaints that happen away from every glass surface.

## The blur is a downscale

A capture taken at 1/N of the screen's resolution and scaled back up is a Gaussian blur of σ ≈ N/2, to within about
1%, at a fraction of the price of a real Gaussian. The host picks the downscale for each finish against measured
quality tables: a blurry finish such as [frosted](../foundations/finishes.md) tolerates a smaller capture, and clear glass,
which has no blur, needs a sharper one.

## What it costs

Measured costs, each on its own platform, because the platforms are not comparable:

| platform | glass vs stock Material | engine `BackdropFilter.grouped` |
|---|---|---|
| Android, Impeller/Vulkan, Adreno 830 (GPU cycles) | ×0.99…1.08 | ×1.78…3.15 |
| iPad, Impeller/Metal (GPU ms, scrolling screen) | ×1.93…2.02, or ×1.46…1.54 with thermal throttling | — |

## Where the numbers come from

Every number on this site was measured in a profile build, on the device named, before the package's first release:
the code that became 0.1.0 on 2026-10-03, on Flutter **3.47.1** stable (framework `6655482ec0`, engine `5d53178869`,
Dart 3.13.1). The raw digests are in
[`provenance/`](https://github.com/PlugFox/g1455/tree/master/provenance) in the repository.

| device | GPU | system | renderer | metric | dates |
|---|---|---|---|---|---|
| Samsung Galaxy S25 Ultra (SM-S938B) | Snapdragon 8 Elite, Adreno 830 | Android 16 | Impeller, Vulkan; 1080×2340 at 3×, 120 Hz | GPU cycles a frame (kgsl `busy × freq`), windows of 30 s × 3 | 2026-08-24 to 2026-09-23 |
| iPad Pro 11″, 4th generation (iPad14,3) | Apple M2 | iPadOS 26.6.1 | Impeller, Metal; 1668×2388 at 2×, 120 Hz | GPU ms a frame (the engine's `GPUTracer`), after a reboot, windows of 4 s × 3 | 2026-09-08 to 2026-09-26 |
| Samsung Galaxy S22 Ultra (SM-S908B) | Exynos 2200, Xclipse 920 | Android 16 | Impeller, Vulkan; 720×1544 | GPU `busy × freq`, which does not see the capture: a cross-check only | 2026-09-08 to 2026-09-26 |
| MacBook Pro | Apple M3 Max | macOS 26.4.1 | Impeller, Metal; 1600×1200 at 2× | raster ms a frame | 2026-09-15 |

The ratios compare scenes on one device, run in one binary in a shuffled order. They do not carry from one device to
another, and they are not frame times.

## What this means for your app

- A still screen with glass costs almost nothing beyond drawing the glass itself.
- Glass that moves over still content belongs in a [GlassTravel](../foundations/travel.md) region. The built-in switch,
  slider, segmented control and tab bar already do this.
- Content that changes under glass costs one capture per changed frame. That is the honest price of a list scrolling
  under a bar, and it is still one capture, not one per surface.
- Each surface is still one draw, and the overhead grows faster than the count. Keep glass in the navigation and
  controls layers. See [Performance](../foundations/performance.md).
- Glass on top of other glass needs one capture per level. Glass nested inside glass gets that automatically;
  sibling glass that floats above other glass needs [GlassAbove](../foundations/above.md).

> [!NOTE]
> If you have reason to distrust the change detection, `GlassHost(content: GlassContentDeclaration.undeclared)`
> re-captures every frame. It is the most expensive thing the package can be asked to do; use it to rule the
> detection out, not to ship.
