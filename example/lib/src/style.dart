import 'package:flutter/widgets.dart';
import 'package:g1455/g1455.dart';

/// The material the glass is made of: one of the package's calibrated
/// finishes.
enum MaterialChoice {
  /// Apple's `.regular`: the host picks its dark or light branch from the
  /// declared backdrop and the appearance. Over this example's dark pages
  /// that is the dark one in either appearance.
  regular('Regular', null),
  dark('Dark', GlassFinish.regularDark),
  light('Light', GlassFinish.regularLight),
  clear('Clear', GlassFinish.clear),
  frosted('Frosted', GlassFinish.frosted);

  const MaterialChoice(this.label, this.finish);

  final String label;

  /// Null leaves the choice to the host.
  final GlassFinish? finish;
}

/// The colour of the tint, laid at the material's own alpha.
enum TintChoice {
  neutral('Neutral', null),
  indigo('Indigo', Color(0xFF28348C)),
  rose('Rose', Color(0xFF962850));

  const TintChoice(this.label, this.colour);

  final String label;

  /// Null keeps the material's own tint.
  final Color? colour;
}

/// Which rung of the ladder is drawn.
enum RenderingChoice {
  glass('Glass', GlassTier.full),
  translucent('Translucent', GlassTier.cheap),
  opaque('Opaque', GlassTier.opaque);

  const RenderingChoice(this.label, this.tier);

  final String label;
  final GlassTier tier;
}

/// The wave a touch makes — not Apple's, so off on every preset but one.
enum RippleChoice {
  off('Off', null),
  water('Water', 0),
  jelly('Jelly', 0.5),
  honey('Honey', 1);

  const RippleChoice(this.label, this.viscosity);

  final String label;
  final double? viscosity;
}

/// The outline: the platform's own setting, or increased whatever it says.
enum ContrastChoice {
  system('System'),
  increased('Increased');

  const ContrastChoice(this.label);

  final String label;
}

/// Everything the settings menu sets: what the host is given.
///
/// Every field is a declaration the host takes — nothing is drawn by the
/// example itself — so a change is a rebuild of one widget.
@immutable
class GlassSettings {
  const GlassSettings({
    this.material = MaterialChoice.regular,
    this.tint = TintChoice.neutral,
    this.rendering = RenderingChoice.glass,
    this.ripple = RippleChoice.off,
    this.contrast = ContrastChoice.system,
  });

  final MaterialChoice material;
  final TintChoice tint;
  final RenderingChoice rendering;
  final RippleChoice ripple;
  final ContrastChoice contrast;

  /// The material in the chosen tint, in [appearance] — or null for the
  /// host's own choice of `.regular`'s branch, when nothing is tinted.
  ///
  /// The name stays the material's on purpose: the package's damage tables
  /// are keyed by name and grade what the blur and the transmission do to a
  /// reduced capture, and both are the material's — only the tint's colour
  /// differs. A new name would get refusals instead of numbers. A tint over
  /// `.regular` goes on the branch the host would have picked.
  GlassFinish? finishIn(Brightness appearance) {
    final Color? colour = tint.colour;
    if (colour == null) {
      return material.finish;
    }
    final GlassFinish base = material.finish ?? GlassFinish.regular(appearance: appearance, backdrop: kExampleBackdrop);
    return base.copyWith(tint: colour.withValues(alpha: base.tint.a));
  }

  GlassTierChoice get tierChoice => GlassTierPolicy(pinned: rendering.tier).choose();

  GlassRipple? get glassRipple {
    final double? viscosity = ripple.viscosity;
    return viscosity == null ? null : GlassRipple(viscosity: viscosity);
  }

  /// For the host: null reads the platform's switch.
  bool? get highContrast => contrast == ContrastChoice.increased ? true : null;

  /// The preset these settings are, or null for custom ones.
  GlassPreset? get preset {
    for (final GlassPreset p in GlassPreset.values) {
      if (p.settings == this) {
        return p;
      }
    }
    return null;
  }

  GlassSettings copyWith({
    MaterialChoice? material,
    TintChoice? tint,
    RenderingChoice? rendering,
    RippleChoice? ripple,
    ContrastChoice? contrast,
  }) => GlassSettings(
    material: material ?? this.material,
    tint: tint ?? this.tint,
    rendering: rendering ?? this.rendering,
    ripple: ripple ?? this.ripple,
    contrast: contrast ?? this.contrast,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassSettings &&
      other.material == material &&
      other.tint == tint &&
      other.rendering == rendering &&
      other.ripple == ripple &&
      other.contrast == contrast;

  @override
  int get hashCode => Object.hash(material, tint, rendering, ripple, contrast);
}

/// Named settings, the way a game names its graphics settings: from the most
/// the package can draw down to what costs least.
///
/// A preset is not stored anywhere. The menu shows whichever one the current
/// settings equal, and "Custom" when they equal none — so changing one setting
/// makes it custom, and changing it back brings the preset back.
enum GlassPreset {
  ultra(
    'Ultra',
    'Liquid Glass with a wave under the finger',
    GlassSettings(ripple: RippleChoice.jelly),
  ),
  high(
    'High',
    'Liquid Glass as iOS draws it',
    GlassSettings(),
  ),
  medium(
    'Medium',
    'Tint over the backdrop, nothing captured',
    GlassSettings(rendering: RenderingChoice.translucent),
  ),
  low(
    'Low',
    'An opaque fill, nothing behind it shows',
    GlassSettings(rendering: RenderingChoice.opaque),
  );

  const GlassPreset(this.label, this.description, this.settings);

  final String label;
  final String description;
  final GlassSettings settings;
}

/// What every page's backdrop averages to, declared for the opaque rung —
/// the one rung that reads nothing and so has to be told.
const Color kExampleBackdrop = Color(0xFF1E2A44);
