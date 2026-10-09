// At what resolution the proxy is recorded — the largest lever the capture has.
//
// **Three measured facts, and they do not agree with intuition.**
//
//  1. **The saving is not the area.** On Adreno 830, halving the pixel ratio
//     costs 0.53 of the full capture price and quartering it 0.27, against the
//     ideals 0.25 and 0.0625 — the law is roughly `ratio^0.9`, not `ratio^2`.
//     And it is a property of the capture rather than of what is under it: zero
//     content and 24 draw ops per cell give 0.528 ± 0.021 against
//     0.533 ± 0.010.
//  2. **On Metal the *capture* is not charged for resolution at all, and the
//     divisor is still the largest lever.** On an M2 iPad Pro the capture fits
//     `C_frame + C_pass·n` with **no area term**: halving the pixel ratio costs
//     **1.04** of full price and quartering it **1.06** (exponent
//     **-0.05 ± 0.06** where Adreno's is 0.9). But the whole route's addition
//     falls to 0.44 of full resolution at a divisor of 4, because everything
//     else the route does with the proxy pays by area — above all the residual
//     blur over the atlas. A capture cost model answers a question about the
//     capture, and a policy that read it as a question about the route would
//     forbid itself the only large saving that platform has. [routeCostFactor]
//     is the table about the route; [captureCostFactor] stays because the merge
//     criterion is a capture question and reads it.
//  3. **What it costs in quality belongs to the finish, not to the glass.** The
//     damage is 4.6x wider across finishes than across three steps of divisor —
//     `clear` pays 1.279 ΔE at a quarter where `regular` pays 0.222 — because
//     tolerance is bought by how little of the backdrop reaches the eye, not by
//     how blurred it is. Against the 34.8 ΔE between Apple's own `.regular` and
//     `.clear`, `regular` at a quarter is 0.64% of the distance between two
//     shipping materials.
//
// **And the divisor is not independent of the blur.** Recording at 1/k is
// itself a low-pass: the detail above the texel grid is never rasterized and the
// magnification back is a reconstruction filter. Measured by MTF on a
// square-wave grating, the pair is worth **0.30 logical px of
// Gaussian-equivalent sigma per unit of divisor**, and it composes with the
// finish's own blur in quadrature. Two consequences:
//
//  - Blurring a 1/k recording by the finish's *whole* sigma over-blurs it —
//    12% at a quarter for `Glass.regular` on a dpr-1 view — so the residual the
//    blur pass should ask for is [residualSigmaFor], not the finish's own sigma.
//  - A divisor puts a **floor** under the finish. On a dpr-1 view `regular` at
//    sigma 2.6 is within 8% of its floor at an eighth and past it at a
//    sixteenth: at that point the proxy is blurrier than the material, and the
//    material cannot be rendered at all. [maxDivisorFor] is that ceiling.
//
// Both are stated per *texel*, not per divisor — the texel is the filter's only
// length, so the same divisor on a denser screen delivers proportionally less.
//
// **And so is the damage.** The damage table was measured at a device pixel
// ratio of 2, so its divisor-4 row is a row at half a texel per logical pixel;
// read on another screen as "a quarter" it is wrong by up to a factor of three.
// Measured at densities 1, 2 and 4, the two candidate keys separate cleanly:
//
//  - matched **texel scale**, three densities: median spread 12.9%, 0.045 ΔE;
//  - matched **divisor**: median 115.5%, 0.488 ΔE, worst 2.44.
//
// The residual is content. Scenes drawn entirely in logical units transport
// almost exactly (ratios 1.00…1.04 at dpr 1 and 4 against dpr 2). Text does not:
// it reads 0.82 at dpr 1 and 1.21 at dpr 4, because glyph antialiasing puts
// energy up at the *device* grid, so a denser screen has more detail for a fixed
// texel scale to lose. **A denser screen is therefore slightly worse than the
// table says, never better**, and that is the direction a caller has to carry.
//
// Hence [damageAtTexelScale] beside [meanDamage]: **the two halves of this knob
// are indexed differently.** The price follows the divisor — it is a ratio of
// linear sizes and knows nothing about the screen — and the quality follows the
// texel. A policy that reads either table with the other's key is wrong by a
// factor, not by a percent.
//
// And it is why this file holds tables instead of a formula: **the right
// divisor is a function of the finish and of the backend**, and both of those
// are numbers somebody measured rather than constants anybody can derive. A bare
// `0.25` in a constructor carries neither.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How the hardware charges for a capture — which decides whether resolution is
/// a lever at all.
///
/// Normally read off the declared hardware with
/// [GlassHardware.captureCostModel] rather than named. It decides only what a
/// divisor is *priced* at, never which divisor is chosen.
///
/// See also:
///
///  * [ProxyResolution.captureCostFactor] and
///    [ProxyResolution.routeCostFactor], the two tables it keys.
///  * <https://g1455.plugfox.dev/foundations/performance>.
///
/// {@category Cost and policy}
enum ProxyCostModel {
  /// `C_pass·n + k·area`, fitted on Adreno 830. The only model in which
  /// lowering the resolution makes the capture itself cheaper.
  areaCharged,

  /// `C_frame + C_pass·n`, with no area term — Metal, fitted on the M2 iPad
  /// Pro. A capture costs about one more frame, once, whatever its size.
  frameCharged,

  /// Neither model has been fitted on this hardware. Every price below refuses
  /// rather than guessing; the Xclipse numbers are in a different unit again and
  /// the vendor GPUs have no counter at all.
  ///
  /// What it does **not** refuse is the divisor. The saving's *size* is
  /// unpriced here, but its *sign* is the same on every family measured —
  /// Adreno's capture, Metal's route and Xclipse's route
  /// ([ProxyResolution.xclipseRouteSources]): on a Galaxy S22 Ultra (Xclipse
  /// 920) full resolution ran at 37 fps against 115 at a quarter, where a
  /// stock Material card holds 120.
  unmeasured,
}

/// A damage figure, and whether it is a reading or a bound.
///
/// `measured` is false when the texel scale asked for is off the table's own
/// rows: interpolated between two of them, or coarser than the top one, where
/// monotonicity says "at most this" and nothing says more. A caller that needs
/// a value and is handed a bound is being told to measure, not to round.
///
/// `deltaE` is mean ΔE against the same finish at full resolution; divide it by
/// [ProxyResolution.kMaterialScaleDeltaE] to compare across finishes.
///
/// See also:
///
///  * [ProxyResolution.damageAtTexelScale], which returns it.
///  * [ProxyResolutionChoice.damage], where the chooser reports it.
///
/// {@category Cost and policy}
typedef ProxyDamage = ({double deltaE, bool measured});

/// What the whole route costs at a divisor, relative to the same route at full
/// resolution — and whether that point was measured or interpolated between two
/// that were.
///
/// `measured` is false for a predicted rather than measured point: a
/// prediction has no residual to be judged by, and it is labelled as such.
///
/// See also:
///
///  * [ProxyResolution.routeCostFactor], which returns it.
///
/// {@category Cost and policy}
typedef ProxyRouteCost = ({double factor, bool measured});

/// The proxy's recording resolution, as an integer divisor of the device pixel
/// ratio.
///
/// An integer because that is what was measured (1 to 8) and because it
/// keeps the ratio comparable between devices; on a device whose own ratio is
/// integral it also keeps one texel a whole number of device pixels, so the
/// source grid and the texel grid share a phase.
///
/// The policy picks one per frame; a host pins one through
/// [GlassHost.resolution], which is how an unpriced divisor gets priced (see
/// [ProxyDivisorReason.pinnedByHost]). Its tables can also be read directly:
///
/// ```dart
/// const ProxyResolution quarter = ProxyResolution.quarter();
/// final ProxyDamage? damage = ProxyResolution.damageAtTexelScale(
///   'regularDark',
///   quarter.ratioFor(3), // a dpr-3 phone: 0.75 texels per logical pixel
/// );
/// final double? capture = quarter.captureCostFactor(ProxyCostModel.areaCharged);
/// ```
///
/// See also:
///
///  * [ProxyResolutionPolicy], which chooses it.
///  * [ProxyResolutionChoice], the choice with its damage and price.
///  * <https://g1455.plugfox.dev/foundations/performance> and
///    <https://g1455.plugfox.dev/start/how-it-works>.
///
/// {@category Cost and policy}
@immutable
class ProxyResolution {
  /// Recording at `1/divisor` of the device pixel ratio. [divisor] is at least
  /// 1.
  const ProxyResolution.divisor(this.divisor) : assert(divisor >= 1, 'the proxy is never larger than the screen');

  /// Recording at the screen's own resolution.
  const ProxyResolution.full() : divisor = 1;

  /// Recording at half the device pixel ratio, a quarter of the texels.
  const ProxyResolution.half() : divisor = 2;

  /// Recording at a quarter of the device pixel ratio — what the policy picks
  /// for `regular` on a dpr-2 screen at the default budget.
  const ProxyResolution.quarter() : divisor = 4;

  /// How many times coarser than the screen the proxy is recorded, per axis.
  final int divisor;

  /// Texels per logical pixel.
  double ratioFor(double devicePixelRatio) => devicePixelRatio / divisor;

  /// Capture price relative to [ProxyResolution.full] on the same hardware, or
  /// null when this point was never measured.
  ///
  /// Null rather than `pow(1 / divisor, 0.9)`: the exponent is itself a fit over
  /// three points and the eighth was never priced, so the numbers are quoted
  /// only where they were taken. A caller that wants the extrapolation can
  /// write it and own it.
  double? captureCostFactor(ProxyCostModel model) {
    switch (model) {
      case ProxyCostModel.areaCharged:
        return const <int, double>{1: 1.00, 2: 0.53, 4: 0.27}[divisor];
      case ProxyCostModel.frameCharged:
        // Not a saving that rounds to one: the model has no area term at all, so
        // the divisor is not on the price — and measured on the scale axis it is
        // slightly the wrong way round. Same refusal as above past the divisors
        // that were run.
        return const <int, double>{1: 1.00, 2: 1.04, 4: 1.06}[divisor];
      case ProxyCostModel.unmeasured:
        return null;
    }
  }

  /// What the **whole route** costs at this divisor, relative to the same route
  /// at full resolution — or null where nobody has measured it.
  ///
  /// Stated over the *addition over the floor* rather than over the frame: the
  /// floor is the application's own UI and the package neither pays it nor
  /// changes it, so a frame-relative figure would be a statement about the
  /// scene as much as about the proxy. On the scene it was measured — two
  /// surfaces, 224 440 logical px² of glass over a photographic backdrop — the
  /// frame-relative figure is 0.604 at a divisor of 4.
  ///
  /// **Measured on Metal (M2 iPad Pro) only**, at divisors 1, 2, 4 and 8 in one
  /// run ([metalRouteCostSource]). The rows are readings, not a formula: no
  /// power law in the proxy's size describes all four.
  ///
  /// Null on [ProxyCostModel.areaCharged], although the route was measured
  /// there too (four divisors on two scenes, Adreno 830), for two reasons
  /// about what this table *is*. Metal's column is normalised to divisor 1,
  /// and on Adreno divisor 1 misses vsync (36.8 and 54.8 fps of 120), so
  /// cycles per frame there are not a frame price; a column normalised to
  /// divisor 2 instead would be a different quantity under the same name. And
  /// the two scenes disagree: the divisor-4 row is 0.194 of the addition on a
  /// banking screen and 0.271 over a photo, 40% apart, so a single column per
  /// divisor would really be a column per scene.
  ProxyRouteCost? routeCostFactor(ProxyCostModel model) {
    switch (model) {
      case ProxyCostModel.frameCharged:
        if (divisor < 1 || divisor > 8) {
          // Same refusal as the capture table's: past the divisors that were
          // run there is no curve to read off. Every family fitted to the first
          // three points predicted the fourth wrongly, by -10% (area) to +20%
          // (Adreno's exponent), in both directions.
          return null;
        }
        // Four readings, not a formula over any of them.
        //
        // An area law (`(1 - share) + share / divisor²`) misses the divisor-2
        // row by 18.6%, and no `A·k^-p + C` at any exponent predicts a held-out
        // interior point to better than 1.5x what the repeats moved. The curve
        // has a knee — 0.94, 0.65 and **0.05** ms across the three intervals,
        // where a power law's drops fall by a constant ratio.
        //
        // The reason: what a divisor buys here is the residual blur pass and
        // nothing else (115% of the fall — without the pass a smaller proxy is
        // *dearer*), so this column is one term that follows the divisor
        // steeply on top of one that does not follow it at all. See
        // [metalBlurSplitSource]. The lever named here is really a blur knob,
        // and a finish with no sigma gets nothing from it but damage.
        //
        // All four come from one run (`metalRouteCostSource`). Three of them,
        // measured again across a reboot and a different seed, reproduce to
        // 0.75% and 1.11% as ratios.
        const Map<int, double> measured = <int, double>{
          1: 1.0,
          2: 0.6713,
          4: 0.4439,
          // Not a saving. 4.1% of the addition and 1.3% of the full-resolution
          // frame, against a between-run reproducibility of about 1% — this row
          // exists to record that the lever has run out, which is a thing the
          // table can say and a formula cannot.
          8: 0.4258,
        };
        final double? factor = measured[divisor];
        if (factor == null) {
          // Includes 3: an integer inside the span is still a divisor nobody
          // ran, and interpolating between families that disagree by 4x is not
          // a reading.
          return null;
        }
        return (factor: factor, measured: true);
      case ProxyCostModel.areaCharged:
      case ProxyCostModel.unmeasured:
        // See the doc comment: measured on Adreno and still not a column,
        // because divisor 1 there is not a frame price and the two scenes
        // disagree by 40% at divisor 4.
        return null;
    }
  }

  /// What a two-point fit of `A·f + C` with `f = 1/k²` over divisors 1 and 4
  /// returns for the share of the route's addition a divisor can buy back on
  /// Metal (M2 iPad Pro). **Do not price anything with it.**
  ///
  /// The fit's family is refuted: the measured divisor-2 point misses it, and
  /// no power of the proxy's size describes all four measured divisors (the
  /// drops across the intervals are 0.94, 0.65 and 0.05 ms, where a power law's
  /// drops fall by a constant ratio). There is no share of the addition that
  /// follows area. The constant is kept only so that
  /// `test/proxy_resolution_test.dart` can re-derive it from
  /// [metalRouteSources], keeping that arithmetic checkable; [routeCostFactor]
  /// does not read it.
  static const double metalAdditionAreaShare = 0.5818;

  /// The pair of runs [routeCostFactor] is read from, digested to their cells.
  ///
  /// Tracked in the repository for the same reason the damage tables' reports
  /// are: a constant baked into `lib/` that a fresh clone cannot check is a
  /// number somebody remembered. Re-derived by `test/proxy_resolution_test.dart`,
  /// together with the check that makes them one measurement — the parts of
  /// the frame that did *not* move between the two runs.
  static const Map<int, String> metalRouteSources = <int, String>{
    1: 'provenance/digest/ipad-m7glass-a.json',
    4: 'provenance/digest/ipad-m7glass-q4.json',
  };

  /// A run with three divisors in one binary, in shuffled order.
  ///
  /// Separate from [metalRouteSources]: those two runs are what this one had
  /// to reproduce before its third point meant anything, and it did — the
  /// glass-free baselines to 0.50…1.71%, and the two glass anchors to 0.10%
  /// and 0.48% across two reboots.
  static const String metalThreePointSource = 'provenance/digest/ipad-m7glass-3pt.json';

  /// The run [routeCostFactor]'s four factors are read from — one binary, one
  /// shuffled order, one floor, all four divisors.
  ///
  /// Three of the four divisors were also measured in [metalThreePointSource],
  /// under another seed and either side of a reboot, and the agreement between
  /// the two runs is what says the fourth point belongs on the same curve.
  static const String metalRouteCostSource = 'provenance/digest/ipad-m7glass-4pt.json';

  /// The run that says what a divisor actually buys, by turning the residual
  /// blur pass off and measuring the same two divisors again.
  ///
  /// The answer, on the M2 iPad Pro, is that it buys that pass and nothing
  /// else. With the blur on, an eighth is 1.69 ms cheaper than full
  /// resolution; with it off, an eighth is 0.25 ms **dearer** — so the pass's
  /// own fall is 115% of the route's. What is left when it is gone costs 0.731
  /// of the floor frame at a divisor of 1 and 0.967 at 8, inside the measured
  /// band for what a capture costs there (0.73…1.01).
  ///
  /// So the route is a pass that follows the divisor steeply plus a capture
  /// that on Metal does not follow it at all, and no two-term form fits it.
  static const String metalBlurSplitSource = 'provenance/digest/ipad-m7glass-blur.json';

  /// The middle of that curve, which says the knee belongs to the blur pass
  /// itself rather than to the route around it.
  ///
  /// At a divisor of 2 a power law through [metalBlurSplitSource]'s two points
  /// predicts 0.814 ms for the pass, and a knee in the pass needs about 1.06 to
  /// reconstruct the route's total. The M2 iPad Pro returned **1.108** — the
  /// power law missed by 36%, the knee by 4.5%.
  ///
  /// So the pass's own price is not a power of the proxy's size either: 1.964 /
  /// 1.108 / 0.288 ms at divisors 1, 2 and 4, whose pairwise exponents are 0.83,
  /// 1.94 and 1.27, with the *middle* interval the steepest. And Impeller is not
  /// the explanation: `CalculateScale` returns 1.0 below a sigma of 4 texels and
  /// rounds `4/sigma` to a power of two above it
  /// (`gaussian_blur_filter_contents.cc:751-765`), so at our largest texel sigma
  /// of 5.20 the engine's own downsample never engages in these runs. It would
  /// at 5.66, which is `regular` at full resolution on a dpr-3 screen.
  ///
  /// The number to carry into a budget: at the divisor the policy picks on a
  /// dpr-2 screen, the addition splits **77% not the blur / 23% the blur** (73%
  /// / 27% at full resolution).
  static const String metalBlurCurveSource = 'provenance/digest/ipad-m7glass-blur2.json';

  /// The two runs that justify [ProxyResolutionPolicy.choose] lowering the
  /// resolution on [ProxyCostModel.unmeasured] at all, digested and keyed by
  /// the shuffle seed they ran under.
  ///
  /// Xclipse 920 (Galaxy S22 Ultra) is the one device measured that no cost
  /// model fits, and so the only evidence about what `unmeasured` gets. Both
  /// runs measure a banking screen at divisors 1 and 4 in one binary, beside
  /// the same screen without glass: **37 fps against 115**, with the proxy
  /// recorded every frame at both divisors. The metric is wall clock and not
  /// cycles, because on this device `busy × frequency` reads an added
  /// submission up to 25% cheaper and full resolution misses vsync, where
  /// cycles per frame are not a frame price.
  ///
  /// What they do **not** give is a number for [routeCostFactor]: the two-term
  /// decomposition returns a negative `C` there (the quarter sits 4% over the
  /// floor and vsync pins it from below), so the route's price on this family
  /// has a measured *sign* and no coefficient. That is the difference between
  /// choosing a divisor on quality — which this justifies — and pricing one,
  /// which it does not.
  static const Map<int, String> xclipseRouteSources = <int, String>{
    20260908: 'provenance/digest/s22u-m7glass-bank-wall.json',
    20260909: 'provenance/digest/s22u-holdpair-bank-wall.json',
  };

  /// The run that measured the default policy on a host that declares no
  /// hardware, beside the two divisors it could have landed on, pinned 1 and
  /// pinned 4, in one binary.
  ///
  /// On the Galaxy S22 Ultra (Xclipse 920) it landed on the quarter: 8.339 ms
  /// against the pinned quarter's 8.341 and the glass-free floor's 8.354, at
  /// 119.9 fps, with the proxy recorded every frame — and the pinned full
  /// resolution at 25.5 ms and 39 fps in the same run. Not in
  /// [xclipseRouteSources], because it is not the same measurement: there the
  /// quarter's atlas was unmerged, here it is merged, and every glass variant
  /// but full resolution sits on the display's period, where the wall clock is
  /// a floor and not a price.
  static const String xclipseDefaultSource = 'provenance/digest/s22u-d136-bank-wall.json';

  /// Mean ΔE against the *same finish* at full resolution, over seven test
  /// scenes, or null for a divisor that was never measured.
  ///
  /// Read it as damage relative to that finish, never as an absolute: a more
  /// opaque finish is more forgiving by construction. The number that makes it
  /// comparable across finishes is [kMaterialScaleDeltaE].
  ///
  /// [blurCorrected] picks the recipe. Off blurs the proxy by the finish's whole
  /// sigma on top of the low-pass the divisor already applied. On is what a
  /// shipping surface does, and it is **not uniformly better**: it removes the
  /// over-blur, which was partly cancelling the lost detail, so smooth scenes
  /// gain up to 34% and text-heavy ones lose up to 7%.
  double? meanDamage(String finish, {bool blurCorrected = false}) =>
      (blurCorrected ? _damageCorrected : _damage)[finish]?[divisor];

  /// Gaussian-equivalent sigma the recording delivers on its own, **in texels**
  /// — the rasterization at the texel grid plus the bilinear reconstruction
  /// back.
  ///
  /// Per texel rather than per divisor, because the texel is the filter's only
  /// length: at a device pixel ratio of 2 the same divisor covers half as many
  /// logical pixels and delivers half the sigma. Measured both ways — 0.356 /
  /// 0.308 / 0.294 per unit of divisor at dpr 1 for divisors 2 / 4 / 8, each
  /// from three periods agreeing to better than 1%, and dpr 2 returning half
  /// of dpr 1. The value taken is what the two well-sampled divisors agree on:
  /// at a divisor of 2 the attenuation is only readable near the texel scale,
  /// where a Gaussian equivalent is at its weakest, so it reads high.
  static const double sigmaPerTexel = 0.30;

  /// What this divisor low-passes the proxy by, in logical pixels, before any
  /// blur pass runs — **relative to a full-resolution recording**, which is the
  /// frame every comparison here is made in.
  ///
  /// Zero at [ProxyResolution.full] by construction, not by physics: recording
  /// at 1:1 has a filter of its own, and the measurement divided it out by using
  /// that recording as its reference. The proportional model is fitted on
  /// divisors 2, 4 and 8 and does not extend to 1.
  double deliveredSigmaLogical(double devicePixelRatio) =>
      divisor == 1 ? 0 : sigmaPerTexel * divisor / devicePixelRatio;

  /// The sigma a blur pass should ask for so the finish lands at
  /// [finishSigmaLogical] rather than past it — or null when this divisor has
  /// already exceeded the finish and no blur can undo it.
  ///
  /// In logical pixels, and it needs the device pixel ratio for the same reason
  /// [deliveredSigmaLogical] does.
  ///
  /// Quadrature, because that is what was measured: total sigma comes back as
  /// `sqrt(delivered^2 + asked^2)` to within 15% over four combinations of
  /// divisor and finish. The error is one-sided — the measured total runs
  /// 2…15% *above* the prediction, more at the larger finish sigma — and
  /// unexplained, so a caller reaching for the last few percent of a blur
  /// budget should measure rather than trust this.
  double? residualSigmaFor(double finishSigmaLogical, double devicePixelRatio) {
    final double delivered = deliveredSigmaLogical(devicePixelRatio);
    final double residual = finishSigmaLogical * finishSigmaLogical - delivered * delivered;
    return residual <= 0 ? null : math.sqrt(residual);
  }

  /// Mean ΔE at a **texel scale** — texels per logical pixel, which is what
  /// [ratioFor] returns and what the damage actually indexes on.
  ///
  /// The table's rows were measured at dpr 2, so divisors 2 to 8 sit at 1.0 to
  /// 0.25 texels per logical pixel. Between them this interpolates in log-log,
  /// which is a choice with no measurement behind it beyond the curve being
  /// smooth — but the alternative is refusing every screen whose density is
  /// not 2, and a real phone at dpr 3 lands on few of the rows at any integer
  /// divisor.
  ///
  /// Three refusals, and the last is the one that matters:
  ///
  ///  - an unknown finish, or a texel scale coarser than the deepest row (0.25):
  ///    null. Past the measured end the curve is still rising and nothing says
  ///    how fast.
  ///  - a texel scale finer than the top row (1.0): the top row's damage with
  ///    `measured: false`. That is a **bound**, not a reading — damage falls
  ///    as the texel scale rises everywhere it was measured, so a finer
  ///    recording cannot cost more. The value at the top of the curve cannot be
  ///    read off the dpr-2 table at all, because its divisor-1 row is the
  ///    reference and scores 0.000 by construction at every density — at dpr 4
  ///    the same texel scale of 2.0 costs 0.314 ΔE on `clear`, which shows the
  ///    zero is a definition rather than a point.
  ///  - anything at all when the finish transmits nothing that a texel could
  ///    cost it: not modelled here, because no such finish is measured.
  static ProxyDamage? damageAtTexelScale(
    String finish,
    double texelsPerLogicalPixel, {
    bool blurCorrected = false,
  }) {
    final Map<int, double>? table = (blurCorrected ? _damageCorrected : _damage)[finish];
    if (table == null) {
      return null;
    }
    // Descending in texel scale, which is ascending in divisor.
    final List<int> divisors = measuredDivisors;
    final List<double> scales = <double>[
      for (final int divisor in divisors) damageTableDevicePixelRatio / divisor,
    ];
    final List<double> values = <double>[
      for (final int divisor in divisors) table[divisor]!,
    ];
    if (texelsPerLogicalPixel >= scales.first) {
      return (deltaE: values.first, measured: texelsPerLogicalPixel == scales.first);
    }
    if (texelsPerLogicalPixel < scales.last) {
      return null;
    }
    for (var i = 0; i < scales.length; i++) {
      // A row returns the table's own number rather than the interpolation's
      // value at t = 0, which is `exp(log(y))` and differs in the last bit.
      if (texelsPerLogicalPixel == scales[i]) {
        return (deltaE: values[i], measured: true);
      }
    }
    for (var i = 0; i < scales.length - 1; i++) {
      if (texelsPerLogicalPixel <= scales[i] && texelsPerLogicalPixel >= scales[i + 1]) {
        final double t =
            (math.log(texelsPerLogicalPixel) - math.log(scales[i + 1])) /
            (math.log(scales[i]) - math.log(scales[i + 1]));
        final double deltaE = math.exp(
          math.log(values[i + 1]) + t * (math.log(values[i]) - math.log(values[i + 1])),
        );
        return (deltaE: deltaE, measured: false);
      }
    }
    return null;
  }

  /// The largest divisor at which a finish of [finishSigmaLogical] is still
  /// reachable — a ceiling from the optics, not a recommendation.
  ///
  /// Above it the proxy is blurrier than the material, and no amount of tint or
  /// rim work makes that back: the surface would be showing a blur nobody asked
  /// for. `Glass.regular` (2.6) caps at 8 on a dpr-1 view and at 17 on a phone
  /// at dpr 2; `Glass.frosted` (8.0) is never threatened by any divisor this
  /// package would use.
  ///
  /// **It reads 1 at sigma 0, and the policy does not consult it there.** The
  /// floor is arithmetic — every divisor out-blurs a material that asked for
  /// no blur — so for `clear` and `identity` it would be a ceiling of 1 on
  /// every screen at every budget, a refusal rather than a ceiling. Where the
  /// material does have blur the policy gates on this, because the damage
  /// tables are keyed by the finish's name and cannot see a thin sigma.
  static int maxDivisorFor(double finishSigmaLogical, double devicePixelRatio) {
    final int cap = (finishSigmaLogical * devicePixelRatio / sigmaPerTexel).floor();
    return cap < 1 ? 1 : cap;
  }

  /// The reports `test/proxy_recorder_test.dart` re-derives the two tables from,
  /// tracked because a constant baked into the package needs its source in the
  /// repository.
  ///
  /// Taken on the package's current optics: a report taken on an older shader
  /// describes a surface this package no longer renders.
  static const String damageSource = 'provenance/quality/d186-uncorrected-2026-09-14T20-16-32.json';

  /// The same measurement as [damageSource] under the blur-corrected recipe —
  /// the source of `meanDamage(..., blurCorrected: true)`.
  static const String damageSourceCorrected = 'provenance/quality/d186-corrected-2026-09-14T20-18-05.json';

  /// Where `regularLight`'s rows came from: the same measurement, both recipes,
  /// over `regular` and `regularLight` — and the `regular` rows reproduce
  /// [damageSource] and [damageSourceCorrected] to 0.0006 ΔE, which is what
  /// lets a row from another run sit in this table.
  static const String lightDamageSource = 'provenance/quality/d230-light-uncorrected-2026-10-03T00-39-20.json';

  /// [lightDamageSource] under the blur-corrected recipe.
  static const String lightDamageSourceCorrected = 'provenance/quality/d230-light-corrected-2026-10-03T00-40-09.json';

  /// The run that says the table's key survives a magnification that is not a
  /// power of two, and the reason the 3 and 6 rows can be read the same way as
  /// the others.
  ///
  /// A texel is `divisor` device pixels wide, so a divisor of 3 or 6
  /// reconstructs through a filter with three sub-texel phases instead of two
  /// or four — one of them exactly on a texel centre — which might cost
  /// something the texel scale cannot see.
  ///
  /// It does not. At dpr 3 with the backdrop pinned to one density, texel 1.0
  /// (magnification 3) lands at 0.93…1.02 of the same texel scale at dpr 2
  /// (magnification 2), and texel 0.5 (magnification 6) at 1.02…1.06 of
  /// magnification 4 — inside [transportSpreadMedian] on every finish.
  static const String magnificationSource = 'provenance/quality/d186-dpr3-pin2-2026-09-14T20-23-47.json';

  /// The same measurement at three screen densities — the runs that say which
  /// key the damage table has. Keyed by the device pixel ratio.
  ///
  /// Tracked for the same reason as the two above, and read by
  /// `test/proxy_resolution_test.dart`, which re-derives the claim from them
  /// rather than restating it: matched texel scales agree, matched divisors do
  /// not.
  static const Map<int, String> transportSources = <int, String>{
    1: 'provenance/quality/d120-dpr1-2026-09-08T07-53-35.json',
    2: 'provenance/quality/d120-dpr2-2026-09-08T07-53-58.json',
    4: 'provenance/quality/d120-dpr4-2026-09-08T07-55-09.json',
  };

  /// The same runs with the photographic backdrop pinned to one density instead
  /// of following the view, at dpr 1 and 4.
  ///
  /// Two of the seven scenes disagreed with [transportSources] by a factor of
  /// two because their content is drawn in *device* pixels, so it is not the
  /// same picture on a denser screen. With the backdrop pinned they fall into
  /// line and nothing else moves.
  static const Map<int, String> transportControlSources = <int, String>{
    1: 'provenance/quality/d120-pin1-2026-09-08T07-51-51.json',
    4: 'provenance/quality/d120-pin4-2026-09-08T07-52-47.json',
  };

  /// The density the damage table was taken at — which is what makes its rows
  /// texel scales of 1.0, 0.5 and 0.25 rather than divisors of 2, 4 and 8.
  static const double damageTableDevicePixelRatio = 2;

  /// How far apart two measurements at the same texel scale and different
  /// densities landed, over densities 1…4: the accuracy of every number
  /// [damageAtTexelScale] returns away from its own row.
  ///
  /// Median rather than worst, and stated with its own worst case in the file
  /// header, because the tail belongs to one scene and one mechanism (text)
  /// rather than to the reading.
  static const double transportSpreadMedian = 0.129;

  /// ΔE between Apple's own `.regular` and `.clear` glass on one backdrop,
  /// measured off iOS 26.
  ///
  /// The only external unit this package has. A damage figure divided by it is
  /// "this fraction of the distance between two of Apple's own materials".
  static const double kMaterialScaleDeltaE = 34.8;

  /// Finishes the damage table has rows for, in the order of how much backdrop
  /// they let through — which is also the order of how much a lost texel costs
  /// them.
  static const List<String> measuredFinishes = <String>[
    'clear',
    'thinLight',
    'frosted',
    'regularDark',
    'regularLight',
  ];

  /// Keyed by divisor, which at [damageTableDevicePixelRatio] is a texel scale
  /// of `2 / divisor` — 1.0, 0.667, 0.5, 0.333 and 0.25.
  ///
  /// The run that measured the 3 and 6 rows reproduced the other three **to
  /// 0.00%**, which is what says they belong to the same measurement.
  static const Map<String, Map<int, double>> _damage = <String, Map<int, double>>{
    'clear': <int, double>{1: 0.0, 2: 0.646, 3: 1.168, 4: 1.279, 6: 1.790, 8: 1.999},
    'thinLight': <int, double>{1: 0.0, 2: 0.264, 3: 0.459, 4: 0.449, 6: 0.779, 8: 0.760},
    'frosted': <int, double>{1: 0.0, 2: 0.281, 3: 0.398, 4: 0.500, 6: 0.623, 8: 0.652},
    // Measured under the name `regular`.
    'regularDark': <int, double>{1: 0.0, 2: 0.143, 3: 0.235, 4: 0.222, 6: 0.379, 8: 0.372},
    // [lightDamageSource]: its own run, whose `regular` rows reproduce
    // [damageSource]'s to 0.0006.
    'regularLight': <int, double>{1: 0.0, 2: 0.108, 3: 0.174, 4: 0.167, 6: 0.285, 8: 0.282},
  };

  static const Map<String, Map<int, double>> _damageCorrected = <String, Map<int, double>>{
    'clear': <int, double>{1: 0.0, 2: 0.646, 3: 1.168, 4: 1.279, 6: 1.790, 8: 1.999},
    'thinLight': <int, double>{1: 0.0, 2: 0.264, 3: 0.462, 4: 0.443, 6: 0.774, 8: 0.757},
    'frosted': <int, double>{1: 0.0, 2: 0.281, 3: 0.398, 4: 0.484, 6: 0.623, 8: 0.565},
    'regularDark': <int, double>{1: 0.0, 2: 0.143, 3: 0.235, 4: 0.221, 6: 0.380, 8: 0.374},
    'regularLight': <int, double>{1: 0.0, 2: 0.108, 3: 0.173, 4: 0.164, 6: 0.281, 8: 0.282},
  };

  /// The divisors the tables above have rows for, deepest last.
  ///
  /// Read off the table rather than written down, so that adding a row is one
  /// edit: [damageAtTexelScale] interpolates between consecutive entries and
  /// [ProxyResolutionPolicy.candidateDivisors] is exactly this list.
  ///
  /// `static final` rather than a getter: [damageAtTexelScale] reads it on every
  /// lookup and the chooser makes five of those per capture, so a getter that
  /// built and sorted a list would allocate six of them per recorded frame for
  /// an answer that cannot change.
  static final List<int> measuredDivisors = List<int>.unmodifiable(
    _damage['regularDark']!.keys.where((int d) => d > 1).toList()..sort(),
  );

  @override
  bool operator ==(Object other) => other is ProxyResolution && other.divisor == divisor;

  @override
  int get hashCode => divisor.hashCode;

  @override
  String toString() => divisor == 1 ? 'ProxyResolution.full' : 'ProxyResolution.divisor($divisor)';
}

/// Why the chooser stopped where it did.
///
/// Carried in the result rather than logged, because every one of these is a
/// different conversation with whoever asked: "your hardware has no lever",
/// "your finish cannot take one" and "the next step was never priced" all look
/// identical from the divisor alone.
///
/// See also:
///
///  * [ProxyResolutionChoice.reason], where it is carried.
///  * <https://g1455.plugfox.dev/foundations/performance>.
///
/// {@category Cost and policy}
enum ProxyDivisorReason {
  // No reason here is the hardware: the divisor's saving has the same sign on
  // every family measured, so the hardware decides only the *price*
  // ([ProxyResolutionChoice.routeCostFactor] is null on `unmeasured`), never
  // the choice.

  /// The next divisor up would cost more quality than the budget allows, or
  /// would land off the measured end of the damage curve, which is the same
  /// answer arrived at by refusing to extrapolate.
  damageBudget,

  /// The next divisor up would low-pass the proxy past the finish's own blur
  /// ([ProxyResolution.maxDivisorFor]). Past that the surface shows a blur
  /// nobody asked for, and no tint makes it back.
  ///
  /// Only ever returned for a finish that *has* blur. A blurless one is refused
  /// by the budget instead, because there the ceiling is 1 by arithmetic and
  /// says nothing the damage table has not measured directly.
  opticsCeiling,

  /// Nothing stopped it: budget and optics both allow more, and the damage
  /// table has no deeper row to say what more would cost.
  ///
  /// The walk does not extrapolate past the table: measured against two rows
  /// added between the old ones, the log-log interpolation came out low by
  /// 3…29% at every one of eight points, never high — so a walk that carried
  /// on past the deepest row would be spending its budget against a number
  /// biased in the direction that overspends it.
  ///
  /// A caller seeing this is being told the honest thing: the budget has room,
  /// and buying it needs a measurement, not a bolder policy.
  offTheLadder,

  /// The divisor the quality walk returned would have packed an atlas larger
  /// than the GPU can hold, so it was deepened until the atlas fits.
  ///
  /// The one reason here that is not a statement about quality, and the only
  /// one that can **overrule** the budget: the alternative is not a worse
  /// picture but a wrong one, because the engine rescales an oversized snapshot
  /// without telling anybody (`AtlasLayout.fitsTexture`). The damage reported
  /// beside it is the real damage at the divisor that was forced, which may be
  /// past the budget and may be null — off the measured end of the table
  /// entirely. A host seeing this is being told to expect a visibly softer
  /// proxy, and that the fix is a smaller surface or a larger declared
  /// [GlassHardware.maxTextureSide], not a larger budget.
  textureCeiling,

  /// Nothing was chosen: the host named the divisor and the policy was not
  /// asked.
  ///
  /// It exists so a divisor the policy would not pick can be measured: the
  /// policy's job is to pick the best divisor, not an interesting one. Reaching
  /// it through the budget instead ([ProxyResolutionPolicy.choose]'s
  /// `damageBudgetDeltaE`) would move the retake ceiling in the same breath,
  /// changing two things at once.
  ///
  /// It does not check the optics ceiling. Refusing there would forbid pricing
  /// the very divisors whose price is missing, and the consequence of overshooting
  /// is visible rather than silent: the surface shows a blur nobody asked for.
  pinnedByHost,
}

/// What the chooser decided, and enough to argue with it.
///
/// Returned by [ProxyResolutionPolicy.choose], [ProxyResolutionPolicy.pin]
/// and [ProxyResolutionPolicy.read]. Its [toString] is the line a report
/// quotes.
///
/// ```dart
/// final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
///   finish: 'regularDark',
///   finishSigmaLogical: 2.6,
///   devicePixelRatio: 2,
///   costModel: ProxyCostModel.frameCharged,
/// );
/// // ProxyResolutionChoice(1/4, damageBudget, dE 0.221, capture 1.06, route 0.44)
/// ```
///
/// See also:
///
///  * [ProxyDivisorReason], what [reason] can say.
///  * <https://g1455.plugfox.dev/foundations/performance>.
///
/// {@category Cost and policy}
@immutable
class ProxyResolutionChoice {
  /// A choice with every column filled in by the caller.
  const ProxyResolutionChoice({
    required this.resolution,
    required this.reason,
    required this.damage,
    required this.captureCostFactor,
    required this.routeCostFactor,
  });

  /// The divisor chosen, pinned or forced.
  final ProxyResolution resolution;

  /// What stopped it going deeper.
  final ProxyDivisorReason reason;

  /// Expected mean ΔE against the same finish at full resolution — null at
  /// [ProxyResolution.full], which *is* the reference.
  ///
  /// Damage relative to that finish, never an absolute: a more opaque finish is
  /// more forgiving by construction. Divide by
  /// [ProxyResolution.kMaterialScaleDeltaE] to compare across finishes.
  final ProxyDamage? damage;

  /// Capture price relative to full resolution under the cost model asked for.
  ///
  /// Not what the divisor is chosen on — the capture is one term of the route,
  /// and on Metal it is the term that does *not* move. Compare it with
  /// [routeCostFactor] to see why the capture alone is the wrong question.
  final double? captureCostFactor;

  /// Price of the **whole route** at this divisor, relative to full resolution,
  /// as a fraction of its own addition over the floor — or null where nobody
  /// measured it ([ProxyResolution.routeCostFactor]).
  final ProxyRouteCost? routeCostFactor;

  @override
  String toString() =>
      'ProxyResolutionChoice(1/${resolution.divisor}, ${reason.name}, '
      'dE ${damage == null ? '—' : damage!.deltaE.toStringAsFixed(3)}, '
      'capture ${captureCostFactor?.toStringAsFixed(2) ?? '—'}, '
      'route ${routeCostFactor == null ? '—' : routeCostFactor!.factor.toStringAsFixed(2)})';
}

/// Chooses the divisor.
///
/// The choice is a function of the finish and of the screen's density, and
/// both are inputs here: each is a table somebody measured, and this class is
/// the arithmetic that puts them together plus the places it refuses.
///
/// It does not detect the platform. [ProxyCostModel] separates Adreno from
/// Metal, and **nothing in Dart tells those apart on Android**, so the host
/// declares it ([GlassHardware]). The declaration decides only what the chosen
/// divisor is *priced* at — [ProxyResolutionChoice.routeCostFactor] — because
/// the divisor's saving has the same sign on every family measured. A host
/// that declares nothing gets the same quality walk as a declared one and a
/// null where the price would be.
///
/// [GlassHost] runs it on every recorded frame; calling it directly is for a
/// report or a test that wants the same answer without a frame:
///
/// ```dart
/// final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
///   finish: 'regularDark',
///   finishSigmaLogical: 2.6,
///   devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
///   costModel: GlassHardware.detect().captureCostModel,
/// );
/// ```
///
/// A host spends a different allowance through [GlassHost.budgetDeltaE], which
/// the retake oracle draws on as well.
///
/// See also:
///
///  * [ProxyResolution], the tables it reads.
///  * [ProxyResolutionChoice], what it returns.
///  * <https://g1455.plugfox.dev/foundations/performance> and
///    <https://g1455.plugfox.dev/start/how-it-works>.
///
/// {@category Cost and policy}
abstract final class ProxyResolutionPolicy {
  /// The default quality budget: **1% of the distance between two of Apple's
  /// own shipping materials** ([ProxyResolution.kMaterialScaleDeltaE]).
  ///
  /// A threshold in bare ΔE would be a taste; written as a fraction of a
  /// measured scale it is at least a statement about something outside this
  /// package. On a dpr-2 screen it picks a **quarter**-resolution proxy for the
  /// Apple-calibrated finish, from the quality side alone — which on an M2 iPad
  /// Pro costs 2.14x a stock Material card's frame against 3.56x at full
  /// resolution.
  static const double defaultDamageBudgetDeltaE = 0.01 * ProxyResolution.kMaterialScaleDeltaE;

  /// The divisors the walk may visit.
  ///
  /// Named for the quality table, because that is the only thing it is a table
  /// of: the choice below is made on damage alone, and every divisor here is
  /// one [ProxyResolution.damageAtTexelScale] can answer for at some density.
  /// The price is *reported* on the way out and may be null.
  ///
  /// Not limited to divisors with a measured price: the walk stops only at the
  /// budget, the optics ceiling, or the damage table running out of rows. At
  /// the default budget and `regular`:
  ///
  /// | dpr | divisor | texels/logical px | ΔE |
  /// |---|---|---|---|
  /// | 1 | 1/2 | 0.5 | 0.222 (1/4 would be 0.25 px → 0.372, over) |
  /// | 2 | 1/4 | 0.5 | 0.222 (1/8 would be 0.25 px → 0.372, over) |
  /// | 3 | 1/8 | 0.375 | 0.275, **interpolated** |
  /// | 4 | 1/8 | 0.5 | 0.222, measured |
  ///
  /// The dpr-3 row spends the budget against a bound rather than a reading,
  /// which is not new — its previous answer, 0.75 texels, was a bound too — and
  /// the caller can see which it got: `measured` rides along on
  /// [ProxyResolutionChoice.damage].
  static final List<int> candidateDivisors = List<int>.unmodifiable(<int>[
    1,
    ...ProxyResolution.measuredDivisors,
  ]);

  /// The choice a host makes for itself, with the tables read at that divisor
  /// rather than used to pick it.
  ///
  /// Everything but the divisor is the same lookup [choose] does, deliberately:
  /// a pinned divisor still reports what the damage table says about it, so a run
  /// that pins a divisor off the measured end reports a null damage rather than
  /// a number nobody measured. See [ProxyDivisorReason.pinnedByHost] for why
  /// this exists at all.
  static ProxyResolutionChoice pin(
    ProxyResolution resolution, {
    required String finish,
    required double devicePixelRatio,
    required ProxyCostModel costModel,
    bool blurCorrected = true,
  }) => read(
    resolution,
    ProxyDivisorReason.pinnedByHost,
    finish: finish,
    devicePixelRatio: devicePixelRatio,
    costModel: costModel,
    blurCorrected: blurCorrected,
  );

  /// A divisor arrived at somewhere other than the quality walk, with the
  /// tables read at it rather than used to pick it.
  ///
  /// [pin] is this with [ProxyDivisorReason.pinnedByHost]; the texture ceiling
  /// is this with [ProxyDivisorReason.textureCeiling]. Kept as one body because
  /// the whole point of both is that the *reporting* does not depend on how the
  /// divisor was reached — a forced divisor still says what the damage table
  /// says about it, including saying nothing when the table has nothing.
  static ProxyResolutionChoice read(
    ProxyResolution resolution,
    ProxyDivisorReason reason, {
    required String finish,
    required double devicePixelRatio,
    required ProxyCostModel costModel,
    bool blurCorrected = true,
  }) => ProxyResolutionChoice(
    resolution: resolution,
    reason: reason,
    damage: resolution.divisor == 1
        ? null
        : ProxyResolution.damageAtTexelScale(
            finish,
            resolution.ratioFor(devicePixelRatio),
            blurCorrected: blurCorrected,
          ),
    captureCostFactor: resolution.captureCostFactor(costModel),
    routeCostFactor: resolution.routeCostFactor(costModel),
  );

  /// The deepest divisor whose damage is inside [damageBudgetDeltaE] and below
  /// the optics ceiling, given the finish, the screen and the hardware.
  ///
  /// [finish] is a key into the measured damage table
  /// ([ProxyResolution.measuredFinishes]); an unknown one refuses the same way
  /// an unmeasured texel scale does, which is to say it comes back at full
  /// resolution rather than at a guess. [finishSigmaLogical] is the finish's
  /// own blur, which sets [ProxyResolution.maxDivisorFor] where it is above
  /// zero. [costModel] prices the result and does not enter the choice.
  /// [blurCorrected] picks which damage table is read (see
  /// [ProxyResolution.meanDamage]).
  static ProxyResolutionChoice choose({
    required String finish,
    required double finishSigmaLogical,
    required double devicePixelRatio,
    required ProxyCostModel costModel,
    double damageBudgetDeltaE = defaultDamageBudgetDeltaE,
    bool blurCorrected = true,
  }) {
    ProxyResolutionChoice at(int divisor, ProxyDivisorReason reason, ProxyDamage? damage) {
      final resolution = ProxyResolution.divisor(divisor);
      return ProxyResolutionChoice(
        resolution: resolution,
        reason: reason,
        damage: damage,
        captureCostFactor: resolution.captureCostFactor(costModel),
        routeCostFactor: resolution.routeCostFactor(costModel),
      );
    }

    // The cost model does not enter the choice. Every family measured has the
    // lever, each for its own reason — on `areaCharged` the capture itself is
    // charged by area, on `frameCharged` the capture is not and the rest of the
    // route is, and on the one device no model fits the recording is charged
    // by area end to end — and the size of the saving does not enter here:
    // only quality does. Returning full resolution on `unmeasured` would hand
    // the default Android host the slowest option there is.

    final int opticsCeiling = ProxyResolution.maxDivisorFor(finishSigmaLogical, devicePixelRatio);
    // **The ceiling applies only where the material has blur of its own.** At
    // sigma 0 it is 1 on every screen — not a statement about optics but the
    // arithmetic degenerating, because *any* divisor delivers more blur than
    // zero — so it would refuse to divide a transparent finish at any budget
    // whatsoever. The damage table prices that excess instead, and for a
    // blurless finish it prices exactly what the pipeline builds: the blur pass
    // returns a null residual at sigma 0 (`proxy_pipeline.dart`), so `clear`'s
    // rows were measured with no correction either, and 0.646 ΔE at a divisor
    // of 2 *is* the price of the blur nobody asked for.
    //
    // At the default budget this changes no divisor — 0.646 against 0.348
    // refuses on its own — only the *reason*, which is the part a host reads.
    // Above zero the ceiling keeps its work, and it is not
    // redundant there: the damage table is keyed by the finish's **name** and
    // cannot see that a finish declared a thin sigma, so for a thin material the
    // two criteria are about different quantities rather than the same one twice.
    final bool ceilingApplies = finishSigmaLogical > 0;
    var chosen = 1;
    ProxyDamage? chosenDamage;
    var reason = ProxyDivisorReason.offTheLadder;

    for (final int divisor in candidateDivisors.skip(1)) {
      if (ceilingApplies && divisor > opticsCeiling) {
        reason = ProxyDivisorReason.opticsCeiling;
        break;
      }
      final ProxyDamage? damage = ProxyResolution.damageAtTexelScale(
        finish,
        ProxyResolution.divisor(divisor).ratioFor(devicePixelRatio),
        blurCorrected: blurCorrected,
      );
      // Null is off the measured end of the curve, which is a refusal to
      // extrapolate rather than a verdict about the picture — but it stops the
      // walk for the same reason the optics ceiling does: every deeper divisor
      // is further off the same end, so there is nothing behind it to find.
      if (damage == null) {
        reason = ProxyDivisorReason.damageBudget;
        break;
      }
      // **A row over the budget does not stop the walk.** The damage curve is
      // not monotone in the texel scale: `regular` costs 0.235 at 0.667 texels
      // and 0.221 at 0.5, `frosted` 0.623 at 0.333 and 0.565 at 0.25. The
      // inversions are small — under 10% between rows — and the consequence is
      // not: at a budget of 0.443 a walk that stopped at the first row over
      // would stop `thinLight` at a half because 0.667 texels costs 0.462,
      // while the deeper row costs 0.443 and fits. Scanning the whole list and
      // keeping the deepest that fits costs five table lookups.
      if (damage.deltaE > damageBudgetDeltaE) {
        reason = ProxyDivisorReason.damageBudget;
        continue;
      }
      chosen = divisor;
      chosenDamage = damage;
      reason = ProxyDivisorReason.offTheLadder;
    }
    return at(chosen, reason, chosenDamage);
  }
}
