// A toolbar's group of buttons: several actions in one glass capsule.
//
// Read off Apple's own `UIToolbar` on iOS 26.5, iPhone 17 Pro:
// a toolbar of four items, the first alone and three after a flexible space,
// comes out as **two** glass shapes — a 48 pt circle for the one and a
// 159 x 48 pt capsule for the three. Apple groups adjacent items into one
// glass; it does not put a glass behind each.
//
// That is also the cheap way to build it here, and it is why this is a widget
// and not advice: a surface is charged per draw, and the fragmentation excess
// grows as the square of the surface count — three buttons as three
// [GlassButton]s are three surfaces where Apple draws one. So a group is one
// [GlassSurface], and pressing an item brightens that item's part of it the
// way [GlassButton] brightens its whole: the finish's rim, added, over the
// item's cell clipped to the capsule (with `plus`; nothing between the
// overlay and the glass opens a `saveLayer`).
//
// Each item takes the keyboard's focus and Space or Enter presses it; its
// focus ring is drawn inside its cell, concentric with the capsule, on the
// group's own canvas — inside the surface's subtree, which no capture sees.
// An item does not swell when pressed, as a [GlassButton] does: the group is
// one glass, and one cell of it cannot grow.

import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassMinTapTarget;
import 'glass_concentric.dart';
import 'glass_finish.dart';
import 'glass_focus.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// The group's height, and the circle a group of one is, as iOS 26.5 draws it.
///
/// {@category Panels and controls}
const double kGlassToolbarHeight = 48;

/// Each item's width in a group of more than one: 159 pt for three on
/// iOS 26.5.
///
/// A group of n items is n times this wide; a group of one is a circle of
/// [kGlassToolbarHeight] instead.
///
/// {@category Panels and controls}
const double kGlassToolbarItemWidth = 53;

/// One action of a [GlassButtonGroup].
///
/// ```dart
/// GlassToolbarItem(icon: const Icon(Icons.share), label: 'Share', onPressed: share)
/// ```
///
/// {@category Panels and controls}
@immutable
class GlassToolbarItem {
  /// An action drawn as [icon] and run by [onPressed]. Give it a [label]:
  /// an icon says nothing to a screen reader.
  const GlassToolbarItem({required this.icon, required this.onPressed, this.label});

  /// What the item shows, centred in its cell. An [Icon] takes the group's
  /// label colour at size 22; anything else can read them from [IconTheme].
  final Widget icon;

  /// Null disables the item.
  final VoidCallback? onPressed;

  /// What the semantics say; the icon alone says nothing to a screen reader.
  final String? label;
}

/// Adjacent actions in one glass capsule — a circle for one — as iOS 26's
/// toolbar draws them. One surface whatever the count.
///
/// The group is [kGlassToolbarHeight] tall and [kGlassToolbarItemWidth] wide
/// per item. A held item brightens its own cell of the capsule by
/// [pressedOverlay], the way [GlassButton] brightens its whole; a disabled
/// item is drawn at 0.3 opacity. A focused item is pressed by Space or Enter,
/// and ringed inside its cell.
///
/// The items run in the reading direction: under [TextDirection.rtl] the
/// first is at the right.
///
/// ```dart
/// GlassButtonGroup(
///   items: <GlassToolbarItem>[
///     GlassToolbarItem(icon: const Icon(Icons.reply), label: 'Reply', onPressed: reply),
///     GlassToolbarItem(icon: const Icon(Icons.archive), label: 'Archive', onPressed: archive),
///     GlassToolbarItem(icon: const Icon(Icons.delete), label: 'Delete', onPressed: delete),
///   ],
/// )
/// ```
///
/// > **Note:** three [GlassButton]s are three surfaces, and the fragmentation
/// > excess grows as the square of the count. Three items here are one.
///
/// See also:
///
///  * [GlassButton], a single action with a label of its own.
///  * [GlassBar], which a group can sit beside or, at the price of glass on
///    glass, on.
///  * [Toolbar on the site](https://g1455.plugfox.dev/components/toolbar).
///
/// {@category Panels and controls}
class GlassButtonGroup extends StatefulWidget {
  /// A group of [items], of which there must be at least one.
  const GlassButtonGroup({required this.items, this.finish, this.pressedOverlay, super.key}) : assert(items.length > 0);

  /// The actions, in the reading direction.
  final List<GlassToolbarItem> items;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// What is added over a held item's cell. Null takes the finish's rim, as
  /// [GlassButton] does.
  final Color? pressedOverlay;

  @override
  State<GlassButtonGroup> createState() => _GlassButtonGroupState();
}

class _GlassButtonGroupState extends State<GlassButtonGroup> {
  int? _held;

  /// The item whose focus ring is shown.
  int? _focused;

  @override
  void didUpdateWidget(GlassButtonGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A removed item's detector goes without reporting that its highlight
    // ended, so a ring on a cell past the new end would stay, drawn outside
    // the group. A held one does report its press cancelled — but while the
    // tree is being torn down, where the `setState` that clears the light
    // throws; cleared here first, that report changes nothing.
    final int n = widget.items.length;
    if ((_focused ?? -1) >= n) {
      _focused = null;
    }
    if ((_held ?? -1) >= n) {
      _held = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlassThemeData theme = GlassTheme.of(context);
    final GlassFinish finish = widget.finish ?? theme.finish;
    final Color overlay = widget.pressedOverlay ?? finish.rim;
    final int n = widget.items.length;
    final double width = n == 1 ? kGlassToolbarHeight : n * kGlassToolbarItemWidth;
    final Color label = theme.legibility(finish).label;
    return SizedBox(
      width: width,
      height: kGlassToolbarHeight,
      child: GlassSurface(
        borderRadius: kGlassCapsule,
        finish: widget.finish,
        child: CustomPaint(
          painter: _held == null && _focused == null
              ? null
              : _CellOverlay(
                  _held,
                  n,
                  overlay,
                  focused: _focused,
                  rtl: Directionality.maybeOf(context) == TextDirection.rtl,
                ),
          child: IconTheme.merge(
            data: IconThemeData(color: label, size: 22),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < n; i++) Expanded(child: _item(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final GlassToolbarItem item = widget.items[i];
    final bool enabled = item.onPressed != null;
    void hold(bool on) {
      if ((on ? i : null) != _held) {
        setState(() => _held = on ? i : null);
      }
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: item.label,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (bool on) {
          if (on) {
            setState(() => _focused = i);
          } else if (_focused == i) {
            setState(() => _focused = null);
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => item.onPressed?.call()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => hold(true) : null,
          onTapUp: enabled ? (_) => hold(false) : null,
          onTapCancel: enabled ? () => hold(false) : null,
          onTap: item.onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: kGlassMinTapTarget.height),
            child: Center(
              child: enabled ? item.icon : Opacity(opacity: 0.3, child: item.icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds a colour over item [index]'s cell, clipped to the capsule, and rings
/// item [focused]'s cell inside it.
class _CellOverlay extends CustomPainter {
  const _CellOverlay(this.index, this.count, this.color, {this.focused, this.rtl = false});

  final int? index;
  final int count;
  final Color color;
  final int? focused;

  /// The row runs right to left, so item 0's cell is the rightmost.
  final bool rtl;

  Rect _cell(int i, Size size) {
    final double cell = size.width / count;
    return Rect.fromLTWH(cell * (rtl ? count - 1 - i : i), 0, cell, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int? index = this.index;
    final int? focused = this.focused;
    if (index != null && color.a > 0) {
      canvas
        ..save()
        ..clipRSuperellipse(kGlassCapsule.toRSuperellipse(Offset.zero & size).scaleRadii())
        ..drawRect(
          _cell(index, size),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = color,
        )
        ..restore();
    }
    if (focused != null) {
      // Inside the cell — a ring outside it would sit on its neighbours — and
      // concentric with the capsule it is inset in. Over the press, which
      // would otherwise add to it.
      const double inset = kGlassFocusRingGap + kGlassFocusRingWidth / 2;
      final Rect ring = _cell(focused, size).deflate(inset);
      canvas.drawRSuperellipse(
        GlassConcentric.borderRadius(
          BorderRadius.circular(size.height / 2),
          const EdgeInsets.all(inset),
        ).toRSuperellipse(ring).scaleRadii(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kGlassFocusRingWidth
          ..color = kGlassFocusRingColor,
      );
    }
  }

  @override
  bool shouldRepaint(_CellOverlay oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.count != count ||
      oldDelegate.color != color ||
      oldDelegate.focused != focused ||
      oldDelegate.rtl != rtl;
}
