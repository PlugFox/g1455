import 'package:flutter/widgets.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

/// How much of the box the glyph's height takes. SF Symbols are drawn larger
/// on their em than Material's icons, which leave a margin inside it; at the
/// box's own size they read a size too large next to a label.
const double _kGlyphScale = 0.94;

/// An SF Symbol (`package:flutter_sficon`) in an icon's square box, the way
/// [Icon] lays out a Material one.
///
/// [Icon] centres the glyph in a square of its size and lets it overflow: a
/// Material glyph is square, so it never does. An SF Symbol has a width of its
/// own — the eye, the laptop and the house are wider than tall — and in that
/// box it runs into the label beside it. Here the glyph is measured, and one
/// wider than the box is scaled down until it fits; the rest keep their size.
///
/// Drawn by [SFIcon], whose symbols are vector paths (flutter_sficon 2 bundles
/// no font, and [Icon] cannot draw them), in the line box the font had, so
/// the glyph sits where it always did.
///
/// Themed as [Icon] is: [IconTheme]'s size, colour and opacity, and no text
/// scaling. Not selectable, and silent to a screen reader unless
/// [semanticLabel] names it.
class SiteIcon extends StatelessWidget {
  const SiteIcon(this.icon, {this.size, this.color, this.shadows, this.semanticLabel, super.key});

  /// Null for an empty box of the size, as [Icon] has.
  final IconData? icon;
  final double? size;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final IconThemeData theme = IconTheme.of(context);
    final double side = size ?? theme.size ?? 24;
    Color colour = color ?? theme.color ?? const Color(0xFF000000);
    final double opacity = theme.opacity ?? 1;
    if (opacity != 1) {
      colour = colour.withValues(alpha: colour.a * opacity);
    }
    final IconData? icon = this.icon;
    if (icon == null) {
      return Semantics(
        label: semanticLabel,
        child: SizedBox.square(dimension: side),
      );
    }
    final TextDirection direction = Directionality.of(context);
    // No text scaling, as [Icon] has none: [SFIcon] scales with the text.
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    Widget glyph = SFIcon(
      icon,
      fontSize: side * _kGlyphScale,
      color: colour,
      shadows: shadows,
      textDirection: direction,
    );
    if (media != null) {
      glyph = MediaQuery(
        data: media.copyWith(textScaler: TextScaler.noScaling),
        child: glyph,
      );
    }
    final Widget box = SizedBox.square(
      dimension: side,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: icon.matchTextDirection && direction == TextDirection.rtl
              ? Transform.flip(flipX: true, child: glyph)
              : glyph,
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      container: semanticLabel != null,
      child: box,
    );
  }
}

/// A tab of a [GlassTabBar] showing an SF Symbol, which the bar's own [Icon]
/// cannot draw: through [GlassTabItem.iconBuilder], in the size and colour the
/// bar resolved for the item.
///
/// One builder per symbol, held: the bar compares builders by identity, and a
/// fresh closure on every build would read to it as a changed item.
GlassTabItem siteTab(IconData icon, String label) =>
    GlassTabItem(label: label, iconBuilder: _tabIcons.putIfAbsent(icon, () => _tabIcon(icon)));

final Map<IconData, GlassTabItemBuilder> _tabIcons = <IconData, GlassTabItemBuilder>{};

GlassTabItemBuilder _tabIcon(IconData icon) =>
    (BuildContext context, GlassTabItemLook look) => SiteIcon(icon, size: look.iconSize, color: look.color);
