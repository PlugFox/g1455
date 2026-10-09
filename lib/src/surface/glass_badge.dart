// A badge: a count, or a dot, on the corner of an icon or a tab.
//
// **Not glass, and that is Apple's call rather than a saving.** iOS 26 draws a
// badge — on a tab bar item, an app icon, a toolbar button — as an opaque
// capsule of `systemRed` with white text, on the glass and not of it: it has
// to read at a glance over any backdrop, and a translucent red would be a
// different colour over every one. So this is a `DecoratedBox`. It costs no
// surface, takes no slot in the atlas, and a count changing is a repaint of a
// small capsule — inside the glass's subtree when the badge sits on glass,
// where it is no capture (asserted in `glass_badge_test.dart`).
//
// **Not measured:** the sizes. The red is UIKit's documented `systemRed`; the
// height, the dot and the type size are layout, named as such.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// iOS's `systemRed` in the light appearance, (255, 59, 48): the badge's
/// fill by default. The dark appearance's is (255, 69, 58); the package has
/// no appearance (D179), so pass that one where yours is dark.
///
/// {@category Panels and controls}
const Color kGlassBadgeRed = Color(0xFFFF3B30);

/// A badge's height with a count in it, logical px — and its smallest width,
/// so one digit is a circle. Layout, not a reading.
///
/// {@category Panels and controls}
const double kGlassBadgeHeight = 18;

/// A dot badge's diameter, logical px. Layout, not a reading.
///
/// {@category Panels and controls}
const double kGlassBadgeDot = 10;

/// A count or a dot on the corner of [child] — an opaque red capsule, **not
/// glass**, as iOS 26 draws a badge.
///
/// With [count], the number, or "[maxCount]+" past it, and nothing at all at
/// 0, as an app icon's badge disappears; with [label], that text; with
/// neither, a dot. Its centre sits on [child]'s top trailing corner, moved by
/// [offset]. Without a [child] it is the badge alone, for a row or a cell to
/// place.
///
/// ```dart
/// GlassTabItem(
///   label: 'Mail',
///   iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
///     count: unread,
///     child: Icon(Icons.mail, color: look.color, size: look.iconSize),
///   ),
/// )
/// ```
///
/// > **Note:** not glass, and so not a surface: a badge costs nothing in the
/// > atlas or the ledger, and a count changing on a glass bar is a repaint
/// > inside the glass, not a capture.
///
/// A screen reader hears [semanticLabel], or the count or label as written;
/// a dot without a [semanticLabel] says nothing, since nothing is all it
/// shows.
///
/// See also:
///
///  * [GlassTabBar] and [GlassButtonGroup], whose icons it usually marks.
///
/// {@category Panels and controls}
class GlassBadge extends StatelessWidget {
  /// A badge on [child] showing [count], [label], or — with neither — a dot.
  const GlassBadge({
    this.count,
    this.label,
    this.maxCount = 99,
    this.isVisible = true,
    this.color = kGlassBadgeRed,
    this.textColor = const Color(0xFFFFFFFF),
    this.offset = Offset.zero,
    this.semanticLabel,
    this.child,
    super.key,
  }) : assert(count == null || label == null, 'a badge shows a count or a label, not both'),
       assert(count == null || count >= 0),
       assert(maxCount > 0);

  /// The number shown. 0 hides the badge.
  final int? count;

  /// The text shown, when it is not a number — "New", "!".
  final String? label;

  /// The largest [count] shown as itself; past it the badge says
  /// "[maxCount]+".
  final int maxCount;

  /// Whether the badge is drawn. [child] is drawn either way.
  final bool isVisible;

  /// The fill. [kGlassBadgeRed] by default.
  final Color color;

  /// The text. White by default, whatever the glass's label colour is: the
  /// badge is opaque, so what reads on it is fixed by [color] alone.
  final Color textColor;

  /// How far the badge's centre is moved from [child]'s top trailing corner,
  /// with x toward the trailing side.
  final Offset offset;

  /// What a screen reader says in place of the text — "3 unread". Null says
  /// the text, and nothing for a dot.
  final String? semanticLabel;

  /// What the badge marks. Null is the badge alone.
  final Widget? child;

  /// What the badge says: the count, capped, or the label — or null for a dot.
  String? get text {
    final int? n = count;
    if (n != null) {
      return n > maxCount ? '$maxCount+' : '$n';
    }
    return label;
  }

  bool get _shown => isVisible && count != 0;

  @override
  Widget build(BuildContext context) {
    final Widget? child = this.child;
    if (!_shown) {
      return child ?? const SizedBox.shrink();
    }
    final Widget badge = _capsule(context);
    if (child == null) {
      return badge;
    }
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          top: 0,
          right: rtl ? null : 0,
          left: rtl ? 0 : null,
          child: Transform.translate(
            offset: Offset(rtl ? -offset.dx : offset.dx, offset.dy),
            // The badge's centre on the corner.
            child: FractionalTranslation(translation: Offset(rtl ? -0.5 : 0.5, -0.5), child: badge),
          ),
        ),
      ],
    );
  }

  Widget _capsule(BuildContext context) {
    final String? text = this.text;
    final String? said = semanticLabel ?? text;
    final Widget body = text == null
        ? SizedBox.square(
            dimension: kGlassBadgeDot,
            child: DecoratedBox(
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: color),
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minWidth: kGlassBadgeHeight, minHeight: kGlassBadgeHeight),
            child: DecoratedBox(
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: color),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    text,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    // The text is the badge's, not the glass's: a bar's label
                    // colour would put white on white or black on red.
                    style: DefaultTextStyle.of(context).style.copyWith(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
    return Semantics(
      container: said != null,
      label: said,
      excludeSemantics: true,
      child: body,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('count', count, defaultValue: null))
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(IntProperty('maxCount', maxCount, defaultValue: 99))
      ..add(FlagProperty('isVisible', value: isVisible, ifFalse: 'hidden'))
      ..add(ColorProperty('color', color, defaultValue: kGlassBadgeRed))
      ..add(ColorProperty('textColor', textColor, defaultValue: const Color(0xFFFFFFFF)))
      ..add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: Offset.zero))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}
