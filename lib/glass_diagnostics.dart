/// The seams a benchmark turns, kept out of `g1455.dart`.
///
/// Each of these changes how the glass is drawn or exposes the host's plumbing
/// so a run can count it — none of them is something an application declares.
/// They are public because the research application that prices the package
/// lives in another package and has to reach them; an application that imports
/// this library is running an experiment.
///
/// ## Did this frame capture?
///
/// The host publishes a [GlassProxyHandle] through [GlassProxyScope]; its
/// counters say what the host did, which is what a test or a report reads:
///
/// ```dart
/// final GlassProxyHandle? handle = GlassProxyScope.maybeOf(context);
/// final int before = handle?.snapshots ?? 0;
/// // … pump a frame …
/// final bool captured = (handle?.snapshots ?? 0) > before;
/// ```
///
/// ## The arms a measurement was priced with
///
/// - [debugGlassFusedSplit] and [debugGlassFoldCull]: how a [GlassGroup]'s
///   fused draw is split and culled.
/// - [debugGlassShaderAntiAlias]: the shader's anti-alias flag.
/// - [debugGlassShaderLoader]: the loader a test replaces to see a load fail.
///
/// Each has a measured default; set one back when the run is over.
///
/// ## Models without a frame
///
/// [GlassRippleField] and [GlassBackdropReadings] are the ripple's and the
/// adaptive glass's models, which a test drives directly.
///
/// {@category Diagnostics}
library;

import 'g1455.dart' show GlassGroup;

// Which spelling of the blend group's draw runs, and the cull inside its fold:
// the arms D189 and D170 were priced with. The defaults are the measured ones.
export 'src/surface/glass_group.dart'
    show
        GlassFusedTile,
        debugGlassFoldCull,
        debugGlassFusedSplit,
        debugGlassFusedSplitDefault,
        fusedDrawTiles,
        kGlassGroupShaderAsset,
        kMaxFusedTiles;
// The verdicts a host that reads its backdrop publishes, and the band-and-hold
// rule each one is kept by — which a test drives without a frame. The count of
// read-backs is `GlassProxyHandle.readBacks`.
export 'src/surface/glass_adaptive.dart' show GlassBackdropReadings, GlassBackdropVerdict;
// The host's published proxy and its counters — `recorded`, `held`,
// `readBacks` — which is what a report reads to say whether a frame captured,
// and the shader loader a test replaces to see a load fail.
export 'src/surface/glass_host.dart'
    show GlassProxyHandle, GlassProxyScope, debugGlassShaderLoader, kGlassRippleShaderAsset, kGlassShaderAsset;
// The ripple's model, which a test drives without a frame.
export 'src/surface/glass_ripple.dart' show GlassRippleField, GlassRippleWave;
// The anti-alias flag of the surface's draw, off by default since D200.
export 'src/surface/glass_surface.dart' show debugGlassShaderAntiAlias, debugGlassShaderAntiAliasDefault;
