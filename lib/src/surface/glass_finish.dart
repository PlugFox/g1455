// The optics: what the glass does to what it samples.
//
// Every number here is measured against Apple's own material:
//
//  - the **displacement** is inward and its peak is a constant of the material
//    rather than a fraction of the shape — eleven geometries read the same
//    number;
//  - its **falloff** is `(1 - (u/t)^0.6)^1.9`, chosen over eight candidate
//    families;
//  - the **outline** is an additive neutral step 0.79 logical px wide with no
//    light direction, and Apple draws no bevel at all;
//  - there is **no dispersion**: Apple's material sends the three channels to
//    the same place to within 0.155 logical px against a reading floor of
//    0.457, so one sample is the reference rather than a shortcut;
//  - and the **finish** — blur and tint — is calibrated to `Glass.regular` on
//    its two independent axes, blur and transmission.
//
// Two numbers are deliberately not fitted. The reach and the falloff exponent
// trade off along a valley: every reach from 22 to 32 logical px reproduces the
// reference inside the reading's floor, and moving an unidentified parameter
// would dress a guess as a calibration.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Width of the outline, in logical pixels — measured, not chosen.
///
/// One band and one coverage fitted across seven rims of two Apple materials
/// give **0.790** with an rms residual of 0.54 code values; a ramp, a
/// smoothstep and a gaussian given the same freedom fit 4.7x worse.
///
/// {@category Foundations}
const double kRimWidthLogical = 0.79;

/// What the outline adds, and it *adds* rather than mixes.
///
/// 50.2 code values of 255, neutral: the three channels of both Apple materials
/// agree to 2-5%, so this is white at a fraction rather than a colour. A mix
/// toward any colour would necessarily be weaker on the brighter material, and
/// Apple's is not.
///
/// {@category Foundations}
const Color kCalibratedRim = Color.fromRGBO(255, 255, 255, 50.2 / 255);

/// ΔE between Apple's `Glass.regular` and `Glass.clear` on one backdrop, read
/// on an iPad: the external unit the package's damage numbers are scaled by.
///
/// {@category Foundations}
const double kMaterialScaleDeltaE = 34.78;

/// Width of the outline under the platform's increase-contrast switch, logical
/// px.
///
/// **Layout taste, not a measurement**: Apple's material was read with the
/// switch off, and the width of what the switch draws — "a more visible
/// border" — has not been measured. One logical pixel is the narrowest line
/// that is a whole device pixel or more on every screen, which the calibrated
/// 0.79 is not: a sub-pixel band is a coverage fraction, and a fraction is what
/// "increase contrast" is asked to remove.
///
/// {@category Foundations}
const double kHighContrastRimWidthLogical = 1;

/// WCAG 2.2's contrast floor for a component's boundary against what is next
/// to it (SC 1.4.11, non-text contrast).
///
/// What [GlassFinish.highContrastRim] is checked against. An external
/// documented constant, like `kGlassMinTapTarget`, which is why it has a name.
///
/// {@category Foundations}
const double kNonTextContrast = 3;

/// WCAG 2.2's AA floor for body text (SC 1.4.3).
///
/// {@category Foundations}
const double kTextContrastAA = 4.5;

/// The dimming layer Apple's guidelines put behind clear Liquid Glass over
/// bright content: "consider adding a dark dimming layer of 35% opacity"
/// (HIG, Materials).
///
/// Kept as the external cross-check on [GlassFinish.dimmingFor] rather than as
/// its answer: the guideline is a suggestion for one finish, and what a label
/// needs is a function of the finish's own transmission — which the arithmetic
/// has and the guideline does not.
///
/// {@category Foundations}
const double kAppleDimmingOpacity = 0.35;

/// The shape of the refraction: how far in it reaches, how hard it bends, and
/// how it falls off.
///
/// Every [GlassFinish] carries one, and the default is the measured one: an
/// inward bend of [strength] at the rim, falling off over [thickness] with the
/// profile [shoulder] and [edgePower] describe. [widen] and [zoom] are 0 and 1
/// on every finish; they are what the drops of the controls use to minify or
/// magnify what is under them.
///
/// ```dart
/// // A lens that magnifies what is under it, as iOS's tab-bar drop does.
/// final GlassFinish lens = GlassFinish.clear.copyWith(
///   optics: const GlassOptics(zoom: 1.17),
/// );
/// ```
///
/// See also:
///
///  * [GlassFinish], which pairs these optics with a blur, a tint and a rim.
///  * [GlassOptics.none], the optics with the refraction switched off.
///  * [Finishes](https://g1455.plugfox.dev/foundations/finishes) on the site.
///
/// {@category Foundations}
@immutable
class GlassOptics {
  /// Optics with the measured defaults; name a field to change only that one.
  const GlassOptics({
    this.thickness = 21,
    this.strength = -58.2,
    this.edgePower = 1.9,
    this.shoulder = 0.6,
    this.widen = 0,
    this.zoom = 1,
  }) : assert(zoom > 0);

  /// How far in from the rim the refraction reaches, logical px.
  ///
  /// **Not identified**, and kept rather than fitted: it trades off with
  /// [edgePower] along a valley from 22 to 32.
  final double thickness;

  /// Peak sample displacement at the rim, logical px.
  ///
  /// **Negative is inward**, which is the sign Apple's materials have and the
  /// one that falls out of refracting through a bevel.
  ///
  /// −58.2 is the curve's value at u = 0, which is an extrapolation past where
  /// the reading starts (2.3 logical px); −43 is the same curve read where it
  /// was measured. The two do not disagree.
  final double strength;

  /// Falloff exponent. Not identified on its own — see [thickness].
  final double edgePower;

  /// Exponent on the depth itself: `bend = (1 - (u/t)^shoulder)^edgePower`.
  ///
  /// 1.0 is the plain two-parameter falloff, and 0.6 is measured:
  /// `(1 - u/t)^p` misses Apple's profile by 0.52
  /// logical px at the rim against a floor of 0.464, and misses it
  /// *structurally* — the residual alternates in sign rather than scattering.
  final double shoulder;

  /// How far past its own box the glass shows, logical px on every side —
  /// the backdrop of the grown box drawn into the shape, which minifies it.
  ///
  /// **0 for every finish**, and nothing but iOS's held switch uses it: its
  /// drop shows the grid at 0.85 of its pitch across and 0.79 down, which is
  /// one margin of 5 pt on a 29 × 19 pt half-box and not one zoom (a single
  /// zoom fits 2.21 device px rms against the margin's 1.61). The slider's
  /// drop, read the same way, fits 0.0. Negative magnifies.
  ///
  /// Scaled by `presence`, so a drop that grows in does not open on a pinhole
  /// showing the whole margin. The host captures the box grown by it.
  final double widen;

  /// How much the glass magnifies what is under it, about its centre: the
  /// sample is drawn from `rel / zoom`. **1 for every finish**; iOS's tab-bar
  /// drop is 1.17 over the bar it is lifted from, on an iPhone and an iPad
  /// alike — the label under it 1.22x its resting size against 1.045x for a
  /// label beside it, both of which grew with the bar.
  ///
  /// Composes with [widen] in one term; below 1 the host captures the box
  /// grown by what it reaches.
  final double zoom;

  /// The per-axis fraction of its distance from the centre a sample walks out
  /// by, on a box with half-extents [half] — [widen] and [zoom] in one, which
  /// is what the shader takes.
  Offset walk(Size half) => Offset(
    (half.width <= 0 ? 0 : widen / half.width) + 1 / zoom - 1,
    (half.height <= 0 ? 0 : widen / half.height) + 1 / zoom - 1,
  );

  /// How far past its box a sample can land, logical px, on a box with
  /// half-extents [half] — what the capture has to hold beyond it.
  double reach(Size half) => math.max(0, widen) + math.max(0, 1 / zoom - 1) * half.longestSide;

  /// These optics with the named fields replaced.
  GlassOptics copyWith({
    double? thickness,
    double? strength,
    double? edgePower,
    double? shoulder,
    double? widen,
    double? zoom,
  }) => GlassOptics(
    thickness: thickness ?? this.thickness,
    strength: strength ?? this.strength,
    edgePower: edgePower ?? this.edgePower,
    shoulder: shoulder ?? this.shoulder,
    widen: widen ?? this.widen,
    zoom: zoom ?? this.zoom,
  );

  /// The optics part of the way from [a] to [b], every field linearly.
  static GlassOptics lerp(GlassOptics a, GlassOptics b, double t) {
    if (a == b) {
      return a;
    }
    double mix(double x, double y) => x + (y - x) * t;
    return GlassOptics(
      thickness: mix(a.thickness, b.thickness),
      strength: mix(a.strength, b.strength),
      edgePower: mix(a.edgePower, b.edgePower),
      shoulder: mix(a.shoulder, b.shoulder),
      widen: mix(a.widen, b.widen),
      zoom: mix(a.zoom, b.zoom),
    );
  }

  /// The optics with the refraction switched off: with them the whole route is
  /// transparent.
  ///
  /// Not a finish anybody would ship: an identity glass is the one test that
  /// exercises every uniform of the map at once. Named rather than assembled
  /// field by field, because rebuilding a value object field by field is how a
  /// pinned constant leaks.
  static const GlassOptics none = GlassOptics(
    thickness: 21,
    strength: 0,
    edgePower: 1.9,
    shoulder: 0.6,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassOptics &&
      other.thickness == thickness &&
      other.strength == strength &&
      other.edgePower == edgePower &&
      other.shoulder == shoulder &&
      other.widen == widen &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(thickness, strength, edgePower, shoulder, widen, zoom);
}

/// What the glass does to the light it lets through: how much it blurs and how
/// much of it survives.
///
/// A finish is a blur ([blurSigmaLogical]), a tint laid over the blurred
/// sample ([tint]), an additive outline ([rim]) and the bend at the edge
/// ([optics]). The host's finish is what every surface under it wears;
/// a [GlassSurface] or a [GlassTheme] can name another.
///
/// Every damage number the package carries is keyed by a finish's [name].
///
/// Four finishes are calibrated against Apple's own materials:
///
/// | Finish | Blur sigma | Looks like |
/// |---|---|---|
/// | [regularDark] | 2.6 | `.regular` over dark content: dark, and barely transmitting |
/// | [regularLight] | 2.6 | `.regular` over light content |
/// | [clear] | 0 | `.clear`: no blur, a light tint, the bend in full |
/// | [frosted] | 8 | a heavy blur with a light, thin tint |
///
/// [regular] picks between the two branches of `.regular` the way Apple's
/// material does, and is what a host with no [GlassHost.finish] wears.
/// [identity] is a check rather than a look: a surface wearing it is invisible.
///
/// ```dart
/// GlassSurface(
///   finish: GlassFinish.clear,
///   borderRadius: const BorderRadius.all(Radius.circular(28)),
///   child: const Padding(
///     padding: EdgeInsets.all(20),
///     child: Text('Clear glass'),
///   ),
/// )
/// ```
///
/// > **Note:** a finish whose [name] is not one of the measured ones gets
/// > refusals from the resolution policy rather than numbers. Derive a custom
/// > finish with [copyWith] and keep the name of the one it is closest to.
///
/// See also:
///
///  * [GlassOptics], the shape of the bend at the edge.
///  * [GlassHost.finish] and [GlassThemeData.finish], where a finish is named
///    for a screen or a subtree.
///  * [GlassThemeData.legibility], which dims a finish for its label.
///  * [Finishes](https://g1455.plugfox.dev/foundations/finishes) and
///    [Legibility](https://g1455.plugfox.dev/foundations/legibility) on the site.
///
/// {@category Foundations}
@immutable
class GlassFinish {
  /// A finish of its own. The [name] keys it into the measured damage tables,
  /// so a finish nobody has graded should borrow the name of its nearest one.
  const GlassFinish({
    required this.name,
    required this.blurSigmaLogical,
    required this.tint,
    this.rim = kCalibratedRim,
    this.optics = const GlassOptics(),
  });

  /// Key into the measured damage tables ([ProxyResolution.meanDamage],
  /// `ProxyStaleness.damageAt`). A finish whose name is not among the measured
  /// ones gets refusals rather than numbers, which is the intended behaviour
  /// for a finish nobody has graded.
  final String name;

  /// The blur, in logical pixels, applied to the proxy before it is sampled.
  final double blurSigmaLogical;

  /// Laid over the refracted sample as `mix(base, rgb, a)`.
  final Color tint;

  /// What the outline adds.
  final Color rim;

  /// How the glass bends what it samples at the edge. See [GlassOptics].
  final GlassOptics optics;

  /// The dark branch of Apple's `Glass.regular`, calibrated on its two axes,
  /// blur and transmission, which are independent of each other.
  ///
  /// Sigma **2.6**, because that is where our low-pass crosses the material's
  /// own; and a tint that is *dark and heavy* rather than light and thin — the
  /// level response of `mix(base, tint, a)` is `transmission = 1 - a`, and a
  /// four-backdrop fit on an iPad gave `.regular` a transmission of 0.307 with
  /// an additive of 20.4 code values, which is `a = 0.693` at a tint luma of
  /// 29.4 of 255. `.regular` is dark not because it lays something dark over
  /// the backdrop but because it barely transmits it.
  ///
  /// The iPad was in the dark appearance; a simulator reproduces the fit there
  /// to 0.306 / +20.4.
  static const GlassFinish regularDark = GlassFinish(
    name: 'regularDark',
    blurSigmaLogical: 2.6,
    tint: Color.fromRGBO(29, 29, 32, 0.693),
  );

  /// The light branch of `.regular`: what Apple's material is over a light
  /// backdrop.
  ///
  /// Read in the light appearance on the simulator that reproduced
  /// [regularDark]'s fit: transmission **0.282**, additive **180.9** code
  /// values, R² 0.998, worst residual 1.01 over the same four backdrops — so
  /// `a = 0.718` at a tint of 252, inside the code range, unlike `.clear`'s.
  /// Neutral (R = G = B on every flat level read), and the blur
  /// [regularDark]'s: texture per unit transmission is 0.48 on both.
  static const GlassFinish regularLight = GlassFinish(
    name: 'regularLight',
    blurSigmaLogical: 2.6,
    tint: Color.fromRGBO(252, 252, 252, 0.718),
  );

  /// Below this backdrop level `.regular` is [regularDark] in the light
  /// appearance, and at or above it [regularLight] — encoded code values of
  /// a grey.
  ///
  /// Read between flat greys 52 and 56, a bar-sized capsule each, fresh from
  /// launch: hysteresis, which a scrolling screen would show, is not read.
  static const double kRegularSwitchLight = 54;

  /// The same switch in the dark appearance: read between 220 and 224.
  ///
  /// The appearance moves the threshold and not the materials — the two
  /// branches read the same in both, to a code, wherever they overlap.
  static const double kRegularSwitchDark = 222;

  /// Apple's `.regular`: [regularDark] or [regularLight], as the material
  /// would choose over [backdrop] in [appearance].
  ///
  /// `.regular` is not one material. Over eight flat greys the same glass
  /// is dark up to a level and light from it, and the appearance only moves
  /// where — 54 in the light one, 222 in the dark — so in practice light
  /// screens get light glass and dark screens dark, and a dark band on a light
  /// screen still gets dark glass.
  ///
  /// With no [backdrop], the branch the appearance gives a typical screen:
  /// light in the light appearance, dark in the dark. With one, its Rec.709
  /// luma against the appearance's threshold — the thresholds were read on
  /// greys, and that a colour switches by its luma is the assumption.
  ///
  /// ```dart
  /// // The branch Apple's material would wear over a light grouped background.
  /// final GlassFinish finish = GlassFinish.regular(
  ///   appearance: MediaQuery.platformBrightnessOf(context),
  ///   backdrop: const Color(0xFFF2F2F7),
  /// );
  /// ```
  static GlassFinish regular({required Brightness appearance, Color? backdrop}) {
    if (backdrop == null) {
      return appearance == Brightness.dark ? regularDark : regularLight;
    }
    final double level = levelOf(backdrop);
    final double threshold = appearance == Brightness.dark ? kRegularSwitchDark : kRegularSwitchLight;
    return level < threshold ? regularDark : regularLight;
  }

  /// The level [regular] switches on: [colour]'s Rec.709 luma over its encoded
  /// channels, in code values of 255 — the scale [kRegularSwitchLight] and
  /// [kRegularSwitchDark] were read in.
  ///
  /// Luma rather than relative luminance because the thresholds were read on
  /// greys, as code values, and a grey's luma *is* its code value; what a
  /// colour of the same luma does is the assumption [regular] already names.
  static double levelOf(Color colour) => 255 * (0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b);

  /// The finish part of the way from [a] to [b], [t] from 0 to 1 — what a
  /// glass that reads its backdrop draws while it moves between the branches
  /// of `.regular` (`GlassHost.adaptive`).
  ///
  /// Every quantity is interpolated except the name, which is a key into the
  /// damage tables and has no midpoint: it is [a]'s for the first half and
  /// [b]'s for the second. Between the two branches of `.regular` the blur is
  /// 2.6 on both, so no slot is re-blurred on account of the move, and the
  /// tint passes through levels between the two, which is the whole of the
  /// motion. The name is not free: a screen whose glass wears both branches is
  /// priced by the stricter of their tables, so the flip at the half can lower
  /// the capture's divisor — a larger atlas — for as long as the screen stays
  /// mixed.
  static GlassFinish lerp(GlassFinish a, GlassFinish b, double t) {
    if (t <= 0 || a == b) {
      return a;
    }
    if (t >= 1) {
      return b;
    }
    return GlassFinish(
      name: t < 0.5 ? a.name : b.name,
      blurSigmaLogical: a.blurSigmaLogical + (b.blurSigmaLogical - a.blurSigmaLogical) * t,
      tint: Color.lerp(a.tint, b.tint, t)!,
      rim: Color.lerp(a.rim, b.rim, t)!,
      optics: GlassOptics.lerp(a.optics, b.optics, t),
    );
  }

  /// A heavy blur with a light, thin tint. Scored against Apple's materials it
  /// is closer to `UIVisualEffectView(.systemMaterial)` than to Liquid Glass;
  /// kept because it is the honest name for a heavy blur and the damage tables
  /// carry it.
  static const GlassFinish frosted = GlassFinish(
    name: 'frosted',
    blurSigmaLogical: 8,
    tint: Color.fromRGBO(249, 249, 249, 0.22),
  );

  /// No blur at all: the refraction reads the proxy straight. The hardest case
  /// for every degradation.
  static const GlassFinish clear = GlassFinish(
    name: 'clear',
    blurSigmaLogical: 0,
    tint: Color.fromRGBO(249, 249, 249, 0.22),
  );

  /// Nothing at all: no blur, no tint, no outline, no displacement.
  ///
  /// A surface wearing it must be **invisible**, which checks the whole route
  /// in one comparison — the coordinate space, the resolution's scale, the
  /// atlas's map, the shader's uniforms and the recording's clip. Its name is
  /// in no measured table on purpose: it is not a picture anybody grades.
  static const GlassFinish identity = GlassFinish(
    name: 'identity',
    blurSigmaLogical: 0,
    tint: Color.fromRGBO(0, 0, 0, 0),
    rim: Color.fromRGBO(0, 0, 0, 0),
    optics: GlassOptics.none,
  );

  /// This finish part of the way through appearing, [progress] from 0 (not
  /// there) to 1 (this finish).
  ///
  /// **Read off Apple, not chosen**: a `.glassEffect()` capsule inserted with
  /// `.glassEffectTransition(.materialize)` under a linear three-second
  /// animation, photographed 62 times on macOS 27. It is not an opacity fade —
  /// the best crossfade between the frames before and after leaves up to 0.20
  /// of the difference unexplained — and it is not a shape: what changed is
  /// full-sized from the first frame it shows. The blur arrives first and the
  /// level last: the backdrop's contrast inside the glass falls roughly
  /// linearly with the animation's progress p, while the mean level moves as
  /// about p³ (0.13 at p = 0.5, 0.27 at 0.67, 0.57 at 0.83), rim and centre
  /// keeping pace. So sigma and the refraction scale with p, tint and rim with
  /// p³. The refraction's own curve is the one assumption — the rim keeping
  /// pace with the centre is what licenses giving it the blur's.
  ///
  /// Keeps the name, so the damage tables still apply, and moves the blur: a
  /// surface materializing is a blur class of its own on every frame of it,
  /// which is a capture per frame for as long as it lasts.
  GlassFinish materializing(double progress) {
    if (progress >= 1) {
      return this;
    }
    final double p = progress <= 0 ? 0 : progress;
    final double level = p * p * p;
    return GlassFinish(
      name: name,
      blurSigmaLogical: blurSigmaLogical * p,
      tint: tint.withValues(alpha: tint.a * level),
      rim: rim.withValues(alpha: rim.a * level),
      optics: optics.copyWith(strength: optics.strength * p, widen: optics.widen * p, zoom: 1 + (optics.zoom - 1) * p),
    );
  }

  /// The level this finish shows over a backdrop of [backdrop], as an opaque
  /// fill — what [GlassTier.opaque] paints.
  ///
  /// Not a new constant: all three rungs of [GlassTier] are the same affine
  /// law, `mix(·, tint, a)`, applied to three different arguments. The full
  /// rung passes the *blurred* backdrop, the cheap rung the backdrop itself,
  /// and this one the one number a rung that reads nothing can still be told —
  /// the backdrop's **mean**. So the ladder is one projection at three
  /// transmissions rather than three looks kept in agreement by hand.
  ///
  /// Painting the tint itself instead — the same law at `a = 1`, the colour
  /// the material *lays on* rather than the level it shows — is far off: over
  /// a light screen it is 23.3 ΔE from the glass, two thirds of the distance
  /// from `Glass.regular` to `Glass.clear`. Through this law the difference is
  /// about 2 ΔE and no longer depends on the backdrop's level.
  ///
  /// Composited in the encoded space rather than in linear light, because that
  /// is where every other level here lives: the shader's own `mix` runs on the
  /// texels as stored, the fits that produced `a` and the tint were done on
  /// code values, and the blur the full rung applies averages stored bytes.
  Color opaqueFillOver(Color backdrop) {
    final double a = tint.a;
    double mix(double base, double over) => base * (1 - a) + over * a;
    return Color.from(
      alpha: 1,
      red: mix(backdrop.r, tint.r),
      green: mix(backdrop.g, tint.g),
      blue: mix(backdrop.b, tint.b),
      colorSpace: tint.colorSpace,
    );
  }

  /// The label colour with more contrast against the level this finish shows
  /// over [backdrop] — [dark] or [light], whichever wins.
  ///
  /// A label has to be legible against what is actually under it, and what is
  /// under it is not the tint: all three rungs of [GlassTier] put
  /// `mix(backdrop, tint, a)` there — the full one because a low-pass of a
  /// level *is* that level, the cheap one by construction, the opaque one by
  /// declaration — so **one colour is right at every rung**, and the only input
  /// it needs is the one the ladder already asks for ([opaqueFillOver]).
  ///
  /// Choosing against the **tint** instead is wrong: `frosted` lays a
  /// near-white tint over a dark screen and shows 67 of 255, so a label picked
  /// off the tint comes out black at a contrast of 2.1 where the right answer
  /// is white at 9.9. On [regularDark], whose tint and level are both dark,
  /// the two choices happen to agree.
  ///
  /// [contrastRatio] is WCAG's, so 4.5 is AA for body text and 3.0 for large.
  /// The package does not enforce a threshold: it has no way to know the text's
  /// size, and a component that silently changed a colour to reach a number the
  /// application had not asked about would be deciding its typography.
  Color foregroundOver(
    Color backdrop, {
    Color dark = const Color(0xFF000000),
    Color light = const Color(0xFFFFFFFF),
  }) {
    final Color level = opaqueFillOver(backdrop);
    return contrastRatio(level, dark) >= contrastRatio(level, light) ? dark : light;
  }

  /// The darkest and lightest level this finish can show, over **any**
  /// backdrop at all — the fill over black and the fill over white.
  ///
  /// Exact rather than a bound, and the reason is the law itself: every rung
  /// shows `mix(b, tint, a)`, each channel of which increases with the same
  /// channel of `b` (the slope is `1 - a`, never negative), and relative
  /// luminance increases with each channel. So over the whole cube of
  /// backdrops the level's luminance is least at black and greatest at white,
  /// and a photograph, a video or a map is somewhere inside. On the full rung
  /// the level is a *blurred* backdrop's, whose extremes are inside the
  /// unblurred ones, so there the range is conservative.
  ({Color darkest, Color lightest}) levelRange() => (
    darkest: opaqueFillOver(const Color(0xFF000000)),
    lightest: opaqueFillOver(const Color(0xFFFFFFFF)),
  );

  /// The least contrast [label] can have against this finish, over any
  /// backdrop — the number that is true on a photograph.
  ///
  /// 1.0 when the label's luminance lies inside [levelRange]: some backdrop
  /// then puts a level under it of exactly the label's luminance, which is no
  /// contrast at all. Otherwise the worst case is the nearer end.
  double worstContrast(Color label) {
    final (:Color darkest, :Color lightest) = levelRange();
    final double l = label.computeLuminance();
    if (l >= lightest.computeLuminance()) {
      return contrastRatio(label, lightest);
    }
    if (l <= darkest.computeLuminance()) {
      return contrastRatio(label, darkest);
    }
    return 1;
  }

  /// The label colour — [dark] or [light] — whose **worst** contrast over any
  /// backdrop is the larger.
  ///
  /// What a component uses when nothing has been declared about the backdrop,
  /// or when the backdrop is declared rich (a photograph, a video, a map), and
  /// the point is that this is not a guess: [foregroundOver] needs a level and
  /// has to be told one, this needs only the finish. On [regularDark] it picks
  /// white at a worst case of 6.05, which is AA over every image there is; on
  /// [frosted] and [clear] the best it can do is black at 1.76, and
  /// [dimmingFor] is what says how much has to change.
  Color foregroundOverAny({
    Color dark = const Color(0xFF000000),
    Color light = const Color(0xFFFFFFFF),
  }) => worstContrast(dark) > worstContrast(light) ? dark : light;

  /// The least dimming layer under this finish that gives [label] a worst-case
  /// contrast of [minContrast] over any backdrop, or null when no dimming does.
  ///
  /// A dimming layer is Apple's own answer to clear glass over bright content
  /// ([kAppleDimmingOpacity]), and here it is not a new layer: a dim
  /// of `d` under the glass is `mix(b, black, d)`, and the glass over that is
  /// `(1 - a)(1 - d)·b + a·tint` — the same affine law with less transmission.
  /// So it is folded into the tint ([dimmed]) and costs nothing to draw.
  ///
  /// Only ever helps a *light* label — dimming lowers both ends of the range —
  /// so for a dark one the answer is 0 or null. Zero when the finish already
  /// meets the floor, which is the answer for [regularDark] at AA with a white
  /// label.
  ///
  /// **Met after the screen stores it, not before.** A framebuffer holds 8-bit
  /// codes, and the least continuous dim puts the level exactly on the floor —
  /// so rounding half a code the wrong way misses it: 118.7 of 255 stored as
  /// 119 reads 4.48 against a floor of 4.5. So the level is taken at the *next*
  /// code toward the label before it is compared, which costs a thousandth of
  /// dim and is the difference between a floor met on paper and one met in
  /// pixels.
  double? dimmingFor(double minContrast, {Color label = const Color(0xFFFFFFFF)}) {
    if (_storedWorstContrast(label) >= minContrast) {
      return 0;
    }
    if (dimmed(1)._storedWorstContrast(label) < minContrast) {
      return null;
    }
    // Monotone in d for a light label: every level falls as d rises. Bisected
    // rather than solved, because the sRGB transfer function between code
    // values and luminance has no convenient inverse through `mix`.
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 40; i++) {
      final double mid = (lo + hi) / 2;
      if (dimmed(mid)._storedWorstContrast(label) >= minContrast) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  /// [worstContrast] with each end of the range moved to the stored code nearest
  /// the label, which is where rounding can put it.
  double _storedWorstContrast(Color label) {
    final (:Color darkest, :Color lightest) = levelRange();
    final bool light = label.computeLuminance() >= lightest.computeLuminance();
    final bool dark = label.computeLuminance() <= darkest.computeLuminance();
    if (!light && !dark) {
      return 1;
    }
    double toward(double v) => light ? (v * 255).ceilToDouble() / 255 : (v * 255).floorToDouble() / 255;
    final Color end = light ? lightest : darkest;
    return contrastRatio(
      label,
      Color.from(alpha: 1, red: toward(end.r), green: toward(end.g), blue: toward(end.b)),
    );
  }

  /// This finish over a black dimming layer of opacity [dim], as one finish.
  ///
  /// `(1 - a)(1 - d)·b + a·tint` is `mix(b, tint', a')` with
  /// `a' = 1 - (1 - a)(1 - d)` and `tint' = a·tint / a'`, so the dim changes
  /// the tint and nothing else — not the blur, not the rim, not the optics.
  ///
  /// **The name is kept**, so the parent's damage tables apply, and that errs
  /// on the safe side. The tables are ΔE against the same finish at full
  /// quality; a dim scales everything the finish transmits by `1 - d`, so every
  /// difference a degradation makes shrinks with it. Graded directly, `clear`
  /// under the AA dim (0.679, transmission ratio 0.321) shows 0.32…0.35 of the
  /// parent's mean damage at every quality level — so the parent's table
  /// overstates it by about a factor of three.
  GlassFinish dimmed(double dim) {
    assert(dim >= 0 && dim <= 1, 'a dimming layer is an opacity: $dim');
    if (dim <= 0) {
      return this;
    }
    final double a = tint.a;
    final double a2 = 1 - (1 - a) * (1 - dim);
    double channel(double c) => a2 <= 0 ? 0 : a * c / a2;
    return copyWith(
      tint: Color.from(
        alpha: a2,
        red: channel(tint.r),
        green: channel(tint.g),
        blue: channel(tint.b),
        colorSpace: tint.colorSpace,
      ),
    );
  }

  /// The outline under the platform's increase-contrast switch: an **opaque**
  /// line of the colour with the most contrast against this finish, rather than
  /// the calibrated additive white.
  ///
  /// Apple's switch keeps the translucency and makes the border visible. The
  /// calibrated rim cannot be made visible by turning it up, because it adds:
  /// white added to a light level saturates into the level and says nothing,
  /// which is why a light screen under [regularDark] shows its rim at all only
  /// because the level is dark. So the switch changes the rim's *kind* — from
  /// added to laid on — and its colour is the label's, chosen the same way and
  /// for the same reason: it is the colour that stands out against what is
  /// under it. Against [backdrop] when that is declared and not rich, and
  /// against every backdrop otherwise.
  ///
  /// WCAG's floor for a boundary is [kNonTextContrast], and against a declared
  /// backdrop this clears it on every finish by construction: the better of
  /// black and white is never below **4.59** against any single level (the two
  /// ratios cross at a luminance of 0.179). Over any backdrop it is 6.05 or more
  /// on [regularDark] and 1.76 on [frosted] and [clear] — which is the case for
  /// [dimmingFor], not for a wider line.
  Color highContrastRim({Color? backdrop}) => backdrop == null ? foregroundOverAny() : foregroundOver(backdrop);

  /// WCAG's contrast ratio between two opaque colours, 1.0 to 21.0.
  ///
  /// Built on `Color.computeLuminance`, which is already the W3C relative
  /// luminance — reading the SDK rather than re-deriving the sRGB transfer
  /// function, which is the kind of arithmetic that agrees with itself.
  /// Alpha is ignored, as it is there; both arguments are meant to be opaque,
  /// and the level [foregroundOver] passes in is.
  static double contrastRatio(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// This finish with the named fields replaced.
  ///
  /// The name is kept unless one is given, so the damage tables keep applying;
  /// see [name] before changing it.
  GlassFinish copyWith({
    String? name,
    double? blurSigmaLogical,
    Color? tint,
    Color? rim,
    GlassOptics? optics,
  }) => GlassFinish(
    name: name ?? this.name,
    blurSigmaLogical: blurSigmaLogical ?? this.blurSigmaLogical,
    tint: tint ?? this.tint,
    rim: rim ?? this.rim,
    optics: optics ?? this.optics,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassFinish &&
      other.name == name &&
      other.blurSigmaLogical == blurSigmaLogical &&
      other.tint == tint &&
      other.rim == rim &&
      other.optics == optics;

  @override
  int get hashCode => Object.hash(name, blurSigmaLogical, tint, rim, optics);

  @override
  String toString() => 'GlassFinish($name, sigma $blurSigmaLogical)';
}
