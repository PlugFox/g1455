# Platforms & web

> The same glass on Impeller (Metal, Vulkan, GLES), on Skia, and on the web with CanvasKit and Skwasm.

- Live: https://g1455.plugfox.dev/start/platforms

g1455 is Dart and fragment shaders, with no platform code of its own. The glass renders byte-identically on Impeller
and on Skia, and it works on the web.

## Renderers

- **Impeller** on Metal (iOS, macOS), Vulkan and GLES (Android).
- **Skia/GLES**, which Android falls back to below API 29 and on Vivante GPUs.

There is nothing to switch on per platform: the same `GlassHost` and the same surfaces work everywhere.

## Web

The glass works on Flutter web with both renderers, **CanvasKit** and **Skwasm**. This very site is a Flutter web app:
every demo on it is the package running in your browser, under one `GlassHost` in the app's `builder:`.

CanvasKit is the slow one. Every capture goes through `Picture.toImageSync`, which on CanvasKit reads the pixels back
from the GPU and waits for them: on a MacBook Pro with an M3 Max (macOS 26.4.1), a frame of full glass on this site took
15 to 30 ms on CanvasKit and 4 to 10 ms on Skwasm, in WebKit and in Chromium alike (g1455 0.1.1 on Flutter 3.47.1,
2026-10-04). Flutter picks Skwasm only in Chromium browsers unless the app allows WebKit too; where an app still runs
on CanvasKit, a [cheaper tier](../foundations/tiers.md) captures nothing and the two renderers are level there.

> [!NOTE]
> Browsers do not tell an app about Reduce Transparency, increased contrast or thermal state. Declare what you know,
> as on any platform: see [What the app declares](../start/declarations.md).

## Shaders

Every bundled shader is compiled for all five shader targets (SkSL, Vulkan, GLES, GLES3 and Metal) in the package's
own test suite, so a shader that one of the compilers would reject fails the package's tests rather than your app.

## Hardware and cost

What the glass costs differs between GPU families, and the package's measurements come from two of them: an Adreno 830
on Vulkan and Apple GPUs on Metal; the devices, systems and dates are in
[Where the numbers come from](../start/how-it-works.md). On other hardware the glass works the same; only the reported prices are missing.
See [What the app declares](../start/declarations.md) for `GlassHost.hardware`, and [Performance](../foundations/performance.md)
for keeping the cost down on any device.
