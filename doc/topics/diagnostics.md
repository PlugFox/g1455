`package:g1455/glass_diagnostics.dart`: the seams a benchmark or a test turns.
An application has no reason to import it.

- The host's published proxy and its counters, [GlassProxyHandle](../glass_diagnostics/GlassProxyHandle-class.html) through
  [GlassProxyScope](../glass_diagnostics/GlassProxyScope-class.html): `snapshots` counts the captures, `readBacks` the backdrop
  readings, `throttled` the holds thermal pressure bought.
- What the capture walk observed on the last frame, [WalkLog](../glass_diagnostics/WalkLog-class.html), as
  `handle.frame?.log`: subtrees it handed to the engine because it draws them apart from it (`fellBack`), and what it
  drew as it drew them all the same, because they held glass or a marker — layers it could not reproduce
  (`unhandledLayers`), filters under a fade it flattened (`opacityFoldedIntoFilter`) — and the markers it reached.
- The switches the measured arms were priced with: the tile split of a group's
  draw ([debugGlassFusedSplit](../glass_diagnostics/debugGlassFusedSplit.html)), the shader's anti-alias flag
  ([debugGlassShaderAntiAlias](../glass_diagnostics/debugGlassShaderAntiAlias.html)) and the walk's fallback
  ([debugGlassWalkFallback](../glass_diagnostics/debugGlassWalkFallback.html)).
- Models a test drives without a frame: [GlassRippleField](../glass_diagnostics/GlassRippleField-class.html),
  [GlassBackdropReadings](../glass_diagnostics/GlassBackdropReadings-class.html).

```dart
final GlassProxyHandle? handle = GlassProxyScope.maybeOf(context);
final int before = handle?.snapshots ?? 0;
// … pump a frame …
final bool captured = (handle?.snapshots ?? 0) > before;
```
