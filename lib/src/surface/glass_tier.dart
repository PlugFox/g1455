// The finish ladder: what a surface actually paints, and why.
//
// The ladder has no automatic input. The backend is not a reason to step down:
// the route renders identically on every backend, and Skia is the cheaper one.
// Thermals act on a different knob — the retake ceiling, through
// `GlassThermalPolicy`, because a stale frame is nearly invisible behind a
// blur. And Flutter exposes no reduce-transparency flag, so the application
// reads it and passes it in.
//
// The rung is also a visible loss, and whether a screen needs the saving is a
// question about the application's frame budget, which the package does not
// see. So the application declares one value, and [GlassTierPolicy] turns its
// signals into a tier.

import 'package:flutter/foundation.dart';

/// What a surface paints. The rungs of the finish ladder, in order of what they
/// draw rather than of what they cost.
///
/// A whole host is on one rung, chosen by a [GlassTierPolicy] and handed to
/// [GlassHost.tier] as a [GlassTierChoice]. A single surface can still be
/// read at its own rung through [GlassSurfaceRecord.tier].
///
/// ```dart
/// final GlassTierChoice choice = const GlassTierPolicy(
///   ceiling: GlassTier.cheap,
/// ).choose();
/// assert(!choice.tier.readsBackdrop); // nothing on this screen is captured
/// ```
///
/// See also:
///
///  * [GlassTierPolicy], which turns the application's signals into a rung.
///  * [GlassLoad.capturedSurfaceCount], which counts only the [full] surfaces.
///  * <https://g1455.plugfox.dev/foundations/tiers>, for the three rungs side
///    by side.
///
/// {@category Cost and policy}
enum GlassTier {
  /// The route: proxy, atlas, residual blur, refraction, rim.
  full,

  /// The same shape, the same rim, and the finish's own tint drawn straight
  /// over whatever is behind — **no backdrop read at all**.
  ///
  /// The "no read" half is a requirement rather than an optimisation: on Skia a
  /// `BackdropFilter` grows with the number of surfaces (0.37 M cycles at 6
  /// against 1.26 M at 36, on Adreno). A screen whose surfaces are all below
  /// [full] takes no capture, so there is no texture to read even by accident.
  ///
  /// The *level* it produces is not a new constant: drawing a tint of alpha `a`
  /// over the backdrop is `mix(backdrop, tint, a)`, the same affine law that
  /// fits Apple's own materials on four backdrops (R² = 1.0000). So this rung
  /// transmits `1 - a` of what is behind it — for [GlassFinish.regularDark] the
  /// 0.307 measured off `.regular` itself. The material's level survives; what
  /// is lost is the low-pass and the refraction.
  cheap,

  /// A fill: the same shape and rim, nothing behind it showing through.
  ///
  /// The reason for it is accessibility, not economy. It is the rung Apple's own
  /// Reduce Transparency lands on, and the only one that answers a reader who
  /// cannot read text over a moving background at all.
  ///
  /// **What it fills with is the same law as the other two rungs, evaluated at
  /// the declared backdrop** — `mix(GlassThemeData.backdrop, tint, a)`, see
  /// [GlassFinish.opaqueFillOver]. The tint alone (that law at `a = 1`) is the
  /// colour the material lays on, not the level it shows: over a light screen it
  /// is 23.3 ΔE from the glass it stands in for, against 2.4 through the
  /// declared backdrop. This is the one rung that needs something declared
  /// about the backdrop: it reads nothing, so it can measure nothing.
  opaque;

  /// Whether this rung reads a proxy. True for [full] and nothing else, and it
  /// is the whole structural consequence of the axis: the host captures for the
  /// surfaces where this is true and for no others.
  bool get readsBackdrop => this == GlassTier.full;
}

/// Why the rung in force is the one in force.
///
/// Carried next to the rung rather than derived from it, for the reason
/// [ProxyDivisorReason] and [RetakeReason] exist: a screen that came out
/// [GlassTier.cheap] because the user asked for it and one that came out cheap
/// because a host pinned it look identical on a screenshot and in a report.
///
/// See also:
///
///  * [GlassTierChoice.reason], where it is carried.
///  * <https://g1455.plugfox.dev/foundations/tiers>.
///
/// {@category Cost and policy}
enum GlassTierReason {
  /// Nothing asked for anything else.
  byDefault,

  /// The host named the rung outright.
  ///
  /// It wins over every other input, including the accessibility one, and that
  /// ordering is a decision with a consequence worth saying plainly: **a host
  /// that pins [GlassTier.full] has overridden the user's own switch.** The
  /// alternative — accessibility winning over the pin — would make the full
  /// route unmeasurable on a device with the switch on, and a package whose
  /// most expensive path cannot be forced is a package whose most expensive
  /// path cannot be benchmarked. Same shape, and the same justification, as
  /// [ProxyDivisorReason.pinnedByHost].
  pinnedByHost,

  /// The application read the platform's reduce-transparency switch and passed
  /// it in.
  ///
  /// Flutter does not carry it (as of 3.47.1, `AccessibilityFeatures` has no
  /// such flag), so this reason arrives from outside — a settings flag, or
  /// native code the application runs that reads
  /// `UIAccessibility.isReduceTransparencyEnabled` on iOS and
  /// `NSWorkspace.accessibilityDisplayShouldReduceTransparency` on macOS.
  /// Android has no such switch.
  reduceTransparency,

  /// The application declared a ceiling for this device and the ceiling bound.
  ///
  /// It is a declaration because the package has no way to work it out: what a
  /// lower rung saves is known (see [GlassTierPolicy.ceiling]), but whether this
  /// screen needs the saving is a fact about the application's frame.
  deviceCeiling,
}

/// One rung and the reason it holds.
///
/// What [GlassHost.tier] takes. Usually produced by [GlassTierPolicy.choose]
/// rather than built by hand, so that the reason is the one the policy
/// resolved; constructing one directly is for a host that already knows both.
///
/// ```dart
/// // A benchmark that pins the cheap rung, and says so in its report.
/// const GlassTierChoice choice = GlassTierChoice(
///   GlassTier.cheap,
///   GlassTierReason.pinnedByHost,
/// );
/// GlassHost(tier: choice, child: const MyScreen());
/// ```
///
/// See also:
///
///  * [GlassTierPolicy], which produces it.
///  * [GlassTierChoice.byDefault], what a host gets when nobody says anything.
///  * <https://g1455.plugfox.dev/foundations/tiers>.
///
/// {@category Cost and policy}
@immutable
class GlassTierChoice {
  /// A rung and the reason given for it, as they are.
  const GlassTierChoice(this.tier, this.reason);

  /// What every surface under this configuration paints.
  final GlassTier tier;

  /// Why. Quoted by reports; never read by the painting.
  final GlassTierReason reason;

  /// The rung a screen gets when nobody has said anything.
  static const GlassTierChoice byDefault = GlassTierChoice(
    GlassTier.full,
    GlassTierReason.byDefault,
  );

  @override
  bool operator ==(Object other) => other is GlassTierChoice && other.tier == tier && other.reason == reason;

  @override
  int get hashCode => Object.hash(tier, reason);

  @override
  String toString() => 'GlassTierChoice(${tier.name}, ${reason.name})';
}

/// Turns whatever an application knows into one rung.
///
/// Every input is a declaration: the package detects none of them. The policy
/// exists because the signals arrive from three unrelated places and the order
/// they resolve in is a decision — see [GlassTierReason.pinnedByHost] for the
/// one that is not obvious.
///
/// The order is [pinned], then [reduceTransparency], then [ceiling], then the
/// default:
///
/// | inputs | [choose] returns |
/// |---|---|
/// | nothing | [GlassTier.full], [GlassTierReason.byDefault] |
/// | `ceiling: GlassTier.cheap` | [GlassTier.cheap], [GlassTierReason.deviceCeiling] |
/// | `reduceTransparency: true` | [GlassTier.opaque], [GlassTierReason.reduceTransparency] |
/// | `pinned: GlassTier.full`, `reduceTransparency: true` | [GlassTier.full], [GlassTierReason.pinnedByHost] |
///
/// The reduce-transparency flag is the application's to read: Flutter does
/// not carry it (see [GlassTierReason.reduceTransparency]).
///
/// ```dart
/// GlassHost(
///   tier: GlassTierPolicy(
///     reduceTransparency: platformSaysReduceTransparency,
///     ceiling: isLowEndDevice ? GlassTier.cheap : null,
///   ).choose(),
///   child: const MyScreen(),
/// )
/// ```
///
/// See also:
///
///  * [GlassTier], the rungs.
///  * [GlassTierChoice], what [choose] returns and [GlassHost.tier] takes.
///  * <https://g1455.plugfox.dev/foundations/tiers>, and
///    <https://g1455.plugfox.dev/start/declarations> for the other things an
///    application declares.
///
/// {@category Cost and policy}
@immutable
class GlassTierPolicy {
  /// A policy from whatever the application knows. With no arguments it
  /// chooses [GlassTierChoice.byDefault].
  const GlassTierPolicy({this.pinned, this.reduceTransparency = false, this.ceiling});

  /// The rung the host named. Overrides everything below it.
  final GlassTier? pinned;

  /// The platform's reduce-transparency switch, as the application read it.
  ///
  /// [GlassTier.opaque] rather than [GlassTier.cheap] when it is set, because
  /// that is what the switch does on the platform it comes from: a
  /// `UIVisualEffectView` under Reduce Transparency stops sampling and fills.
  /// A cheap rung would still be translucent, which is the property the setting
  /// exists to remove.
  final bool reduceTransparency;

  /// The richest rung this device should run, if the application has worked
  /// that out — by its own benchmark, its own device table, or a user setting.
  ///
  /// Null means no ceiling, and **the package supplies none**: the rung is a
  /// visible loss, and whether a screen can afford the top one is a question
  /// about the application's frame, which the package does not see.
  ///
  /// What the saving is, on Adreno 830 (Galaxy S25 Ultra), measured as the cost
  /// added over an opaque fill: [GlassTier.cheap] keeps 15…24% of the full
  /// rung's addition on two-surface screens, 41…42% on fifteen surfaces and
  /// 69…71% on twelve small ones. So it pays in proportion to the glass's area
  /// rather than its count, and least where the glass is many small panels.
  /// [GlassTier.opaque] is not cheaper than [GlassTier.cheap] there: it costs
  /// 0.6…2.7% more of the frame, because a depth-writing fill pays for itself.
  ///
  /// On the M2 iPad Pro, in GPU time: [GlassTier.cheap] keeps **3…7%** of the
  /// full rung's addition whatever the layout, because the full rung's price
  /// there is the capture, which no lower rung takes. So a ceiling saves more on
  /// Metal than anywhere measured. [GlassTier.opaque] cannot be told from
  /// [GlassTier.cheap] there.
  ///
  /// Rungs are ordered by what they draw, so a ceiling of [GlassTier.cheap]
  /// permits `cheap` and `opaque` and forbids `full`.
  final GlassTier? ceiling;

  /// Resolves the three inputs into one rung, in the order [pinned],
  /// [reduceTransparency], [ceiling].
  ///
  /// A [ceiling] of [GlassTier.full] binds nothing and comes back as
  /// [GlassTierChoice.byDefault], not as [GlassTierReason.deviceCeiling].
  GlassTierChoice choose() {
    final GlassTier? pin = pinned;
    if (pin != null) {
      return GlassTierChoice(pin, GlassTierReason.pinnedByHost);
    }
    if (reduceTransparency) {
      return const GlassTierChoice(GlassTier.opaque, GlassTierReason.reduceTransparency);
    }
    final GlassTier? cap = ceiling;
    if (cap != null && cap.index > GlassTier.full.index) {
      return GlassTierChoice(cap, GlassTierReason.deviceCeiling);
    }
    return GlassTierChoice.byDefault;
  }

  @override
  bool operator ==(Object other) =>
      other is GlassTierPolicy &&
      other.pinned == pinned &&
      other.reduceTransparency == reduceTransparency &&
      other.ceiling == ceiling;

  @override
  int get hashCode => Object.hash(pinned, reduceTransparency, ceiling);
}
