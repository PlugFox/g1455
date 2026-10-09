// A tab bar whose selection lifts into a glass drop while a finger is on it —
// a drop over another glass, which is what level capture is for.
//
// What it does was read off Apple's own `UITabBar` on iOS 26.5, pressed by
// XCUITest on an iPhone 17 Pro and an iPad Pro simulator:
//
//  - at rest the selected item sits on a grey capsule, its icon and label in
//    the accent colour; nothing about it is glass;
//  - pressed, the capsule becomes a clear drop **10.5 pt larger on every
//    side** (73 x 53 -> 94 x 72 on the phone, 85 x 36 -> 110 x 56.5 on the
//    iPad), standing out of the bar above and below, and the bar itself grows
//    by about 8.5 pt across and 2.5 pt down;
//  - the drop **magnifies** what it is over — the bar and its items — 1.17x on
//    both devices once the bar's own growth is taken out;
//  - dragged, it follows the finger, and the item under it takes the accent
//    colour while the one it left gives it up; let go, it settles on the item
//    and that is the selection.
//
// Not taken: Apple's drop disperses at its rim and ours does not (Apple's
// material showed none; the drop is another material), and the bar's items
// grow with it by ~1.05 where ours stay put.
//
// What it costs, by construction rather than by hope:
//
//  - at rest: the bar, one surface; the drop is at materialize 0 and captured
//    for nothing;
//  - held: the drop is glass on glass, so the frames that record take a second
//    snapshot — while it lifts and the bar grows, every frame; while it
//    moves, **only the frames where the highlighted item changes**, because the
//    highlight is an item, not a blend, and the drop moves inside its own
//    `GlassTravel` behind its own boundary;
//  - the bar's growth is inside a `GlassTravel` of the grown box, so the bar's
//    own capture is not retaken for it;
//  - the drop's stretch and squash ([GlassDropMotion]) is a change of its size
//    inside its own region, grown by the most the motion reaches: no capture
//    of either level, and a repaint of the bar's draw while it changes.
//
// **Minimized** (iOS 26's `tabBarMinimizeBehavior(.onScrollDown)`), the bar
// collapses to a circle of its own height at its start edge, showing the
// selected item's icon, and an accessory above it
// (`tabViewBottomAccessory`) moves down beside the circle. Read off nothing
// but Apple's description and screenshots — the sizes and the spring are
// layout taste. What it costs is the point:
//
//  - the circle is the bar, shrunk inside the same `GlassTravel` the bar
//    grows in, and the accessory moves inside one of the whole box: so the
//    animation is **no capture**, only the bars' draws repainted;
//  - the bar's box does not change size, so the body under it is not told a
//    new padding and is neither laid out nor repainted for it;
//  - the scroll that set it off is a capture on every frame anyway (the
//    content under the bar moves), so what the travel saves is the frames the
//    spring runs on after the finger lets go.
//
// The items are drawn once, under the drop, and the drop shows them magnified:
// there is no second copy of an item over the glass. A custom icon or label
// ([GlassTabItem.iconBuilder], [GlassTabItem.labelBuilder]) is therefore built
// once per item for each look the bar gives the row: every item's builder runs
// again when the drop moves onto an item or off one, not only the two whose
// colour changed — and, on a bar that can collapse, the selected item's icon
// once more, for the collapsed circle. A builder that is dear to run should cache what it builds.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart';
import 'glass_controls.dart' show kGlassDropOptics;
import 'glass_drop_motion.dart';
import 'glass_finish.dart';
import 'glass_surface.dart';
import 'glass_travel.dart';

/// What a [GlassTabBar] resolved for one of its items, as it draws it.
///
/// Handed to [GlassTabItem.iconBuilder] and [GlassTabItem.labelBuilder], so a
/// glyph the bar cannot colour itself — an SVG, an image, a badge — takes the
/// colour its neighbours are drawn in.
///
/// ```dart
/// GlassTabItem(
///   label: 'Inbox',
///   iconBuilder: (BuildContext context, GlassTabItemLook look) => Badge(
///     isLabelVisible: unread > 0,
///     child: Icon(Icons.inbox, size: look.iconSize, color: look.color),
///   ),
/// )
/// ```
///
/// {@category Panels and controls}
@immutable
class GlassTabItemLook {
  /// What the bar resolved for item [index]. Built by the bar; a test of a
  /// builder can build one by hand.
  const GlassTabItemLook({
    required this.index,
    required this.color,
    required this.iconSize,
    required this.labelStyle,
    required this.selected,
    required this.highlighted,
    required this.inline,
  });

  /// Which item.
  final int index;

  /// The colour this item is drawn in now: [GlassTabBar.activeColor] when
  /// [highlighted], and otherwise the label colour the bar's glass chose
  /// against what is behind it ([GlassThemeData.legibility]).
  final Color color;

  /// The size the bar draws its own icons at: 26 stacked, 20 side by side.
  final double iconSize;

  /// The label's style, [color] included.
  final TextStyle labelStyle;

  /// Whether this is [GlassTabBar.selectedIndex].
  final bool selected;

  /// Whether this item takes the accent: the selected one at rest, and the
  /// one under the drop while it is held — which is when the two differ.
  final bool highlighted;

  /// Whether the bar lays its items out icon beside label (a wide bar, an
  /// iPad's) rather than icon over label.
  final bool inline;

  @override
  bool operator ==(Object other) =>
      other is GlassTabItemLook &&
      other.index == index &&
      other.color == color &&
      other.iconSize == iconSize &&
      other.labelStyle == labelStyle &&
      other.selected == selected &&
      other.highlighted == highlighted &&
      other.inline == inline;

  @override
  int get hashCode => Object.hash(index, color, iconSize, labelStyle, selected, highlighted, inline);

  @override
  String toString() =>
      'GlassTabItemLook($index, $color${selected ? ', selected' : ''}'
      '${highlighted ? ', highlighted' : ''}${inline ? ', inline' : ''})';
}

/// Builds an item's icon or label from what the bar resolved for it.
///
/// The type of [GlassTabItem.iconBuilder] and [GlassTabItem.labelBuilder].
/// Run again for every item whenever the drop moves onto an item or off one,
/// so a builder that is dear to run should cache what it builds.
///
/// {@category Panels and controls}
typedef GlassTabItemBuilder = Widget Function(BuildContext context, GlassTabItemLook look);

/// One item of a [GlassTabBar].
///
/// An [IconData] and a string, or anything at all through [iconBuilder] and
/// [labelBuilder] — which are handed the colour the bar draws the item in.
/// [label] is what a screen reader says either way.
///
/// ```dart
/// const GlassTabItem(icon: Icons.photo_library, label: 'Library')
/// ```
///
/// {@category Panels and controls}
@immutable
class GlassTabItem {
  /// An item named [label], drawn with [icon] or built by [iconBuilder] —
  /// one of the two is required, which an assert checks.
  const GlassTabItem({required this.label, this.icon, this.iconBuilder, this.labelBuilder})
    : assert(icon != null || iconBuilder != null, 'A tab item needs an icon or an iconBuilder.');

  /// Drawn by the bar in the colour it resolved. Ignored when [iconBuilder]
  /// is given.
  final IconData? icon;

  /// The item's name: the text drawn unless [labelBuilder] is given, and what
  /// a screen reader says always.
  final String label;

  /// Builds the icon instead of [icon]. Sized by the caller; the bar's own
  /// icons are [GlassTabItemLook.iconSize].
  final GlassTabItemBuilder? iconBuilder;

  /// Builds the label instead of the text of [label].
  final GlassTabItemBuilder? labelBuilder;
}

/// How much the held drop magnifies the bar under it.
///
/// Read off iOS 26.5's own tab bar on a phone and an iPad, both at 1.17x once
/// the bar's own growth under the drop is taken out. [GlassTabBar.dropZoom]'s
/// default.
///
/// {@category Panels and controls}
const double kGlassTabDropZoom = 1.17;

/// How much larger than the resting capsule the held drop is, on every side,
/// logical px.
///
/// Read off iOS 26.5: 73 x 53 -> 94 x 72 on the phone, 85 x 36 -> 110 x 56.5
/// on the iPad, so the held drop stands out of the bar above and below.
///
/// {@category Panels and controls}
const double kGlassTabDropGrow = 10.5;

/// How much the bar grows while held, logical px per side, read off iOS 26.5.
const Size _kBarGrow = Size(8.5, 2.5);

/// When a [GlassTabBar] collapses to its selected tab — iOS 26's
/// `TabBarMinimizeBehavior`, two of its cases.
///
/// {@category Panels and controls}
enum GlassTabBarMinimizeBehavior {
  /// The bar stays as it is. The default.
  never,

  /// The bar collapses to the selected tab when the content under it scrolls
  /// down and expands when it scrolls back up, as told by the nearest
  /// [GlassTabBarMinimizer] above it — which a [GlassScaffold] puts there.
  onScrollDown,
}

/// How far the content has to scroll one way, logical px, before a
/// [GlassTabBarMinimizer] says so: past this down, the bars collapse; past it
/// up, they expand. Layout taste — enough to ignore a finger settling, short
/// enough that a deliberate scroll is answered at once.
///
/// {@category Panels and controls}
const double kGlassTabMinimizeScroll = 12;

/// The height of [GlassTabBar.bottomAccessory]'s glass, logical px. Layout
/// taste: the bar's minimum tap target and a little.
///
/// {@category Panels and controls}
const double kGlassTabAccessoryHeight = 48;

/// Between the accessory and the bar, or the collapsed circle.
const double _kAccessoryGap = 8;

/// Whether the bar's and the accessory's collapse moves inside a declared
/// travel region. The default, and what was measured; a test turns it off to
/// see what it saves.
@visibleForTesting
bool debugGlassTabMinimizeTravel = true;

/// Says whether the content below has scrolled down, for the
/// [GlassTabBar]s below it that collapse on a scroll
/// ([GlassTabBarMinimizeBehavior.onScrollDown]).
///
/// It listens to the vertical scrolls of its subtree — the nearest scroll view
/// of each, not one nested in another — and holds one value, [maybeOf]: true
/// once the content has gone [kGlassTabMinimizeScroll] down, false once it has
/// come as far back up or reached its top. The bar is not inside the scroll
/// view, so both are put under one of these: a [GlassScaffold] does that, and
/// a screen laid out by hand puts one above its body and its bar.
///
/// ```dart
/// GlassTabBarMinimizer(
///   child: Stack(
///     children: <Widget>[
///       ListView.builder(itemCount: 50, itemBuilder: buildRow),
///       Positioned(
///         left: 12,
///         right: 12,
///         bottom: 24,
///         child: GlassTabBar(
///           items: items,
///           selectedIndex: tab,
///           onSelected: select,
///           minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// {@category Panels and controls}
class GlassTabBarMinimizer extends StatefulWidget {
  /// Watches the scrolls in [child] for the tab bars in it.
  const GlassTabBarMinimizer({required this.child, super.key});

  /// The subtree whose scrolls collapse the bars in it.
  final Widget child;

  /// Whether the bars below [context] are collapsed, or null with no
  /// minimizer above. Writable: a bar sets it false when its collapsed circle
  /// is tapped, and an application may set either value — to expand the bars
  /// when it changes the page, say.
  static ValueNotifier<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassTabBarMinimizerScope>()?.minimized;

  @override
  State<GlassTabBarMinimizer> createState() => _GlassTabBarMinimizerState();
}

class _GlassTabBarMinimizerState extends State<GlassTabBarMinimizer> {
  final ValueNotifier<bool> _minimized = ValueNotifier<bool>(false);

  /// How far the content has gone in the direction it is going, logical px.
  double _run = 0;

  @override
  void dispose() {
    _minimized.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollUpdateNotification n) {
    final ScrollMetrics m = n.metrics;
    if (n.depth != 0 || m.axis != Axis.vertical) {
      return false;
    }
    if (m.pixels <= m.minScrollExtent) {
      _run = 0;
      _minimized.value = false;
      return false;
    }
    // A bounce past the end is not the reader going back up.
    final double delta = n.scrollDelta ?? 0;
    if (m.outOfRange || delta == 0) {
      return false;
    }
    if (delta.sign != _run.sign) {
      _run = 0;
    }
    _run += delta;
    if (_run > kGlassTabMinimizeScroll) {
      _minimized.value = true;
    } else if (_run < -kGlassTabMinimizeScroll) {
      _minimized.value = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollUpdateNotification>(
    onNotification: _onScroll,
    child: _GlassTabBarMinimizerScope(minimized: _minimized, child: widget.child),
  );
}

class _GlassTabBarMinimizerScope extends InheritedWidget {
  const _GlassTabBarMinimizerScope({required this.minimized, required super.child});

  final ValueNotifier<bool> minimized;

  @override
  bool updateShouldNotify(_GlassTabBarMinimizerScope oldWidget) => !identical(minimized, oldWidget.minimized);
}

/// The resting capsule: iOS's fill on a light material.
const Color _kPill = Color(0x33787880);

/// Below this much bar per item the items stack icon over label, as an
/// iPhone's do; above it they sit side by side, as an iPad's do.
const double _kInlinePitch = 80;

/// The bar's layout at one width: where the items are and how large the
/// capsule and the drop are. Pure, so the gesture code and the paint agree.
@immutable
class _TabGeometry {
  factory _TabGeometry(double width, int count) {
    final bool inline = (width - 16) / count >= _kInlinePitch;
    // Read off the simulators: the phone's bar is 60 tall with items
    // 66 apart and 7 in from its ends, the capsule 3.5 in from the bar all
    // round; the iPad's is 44 tall, 8 in, the capsule 3 narrower than the
    // pitch. Layout taste where a device had nothing to say.
    final double height = inline ? 44 : 60;
    final double pad = inline ? 8 : 7;
    final double pitch = (width - 2 * pad) / count;
    final Size pill = inline ? Size(pitch - 3, height - 8) : Size(pitch + 7, height - 7);
    return _TabGeometry._(inline, height, pad, pitch, pill);
  }

  const _TabGeometry._(this.inline, this.height, this.pad, this.pitch, this.pill);

  final bool inline;
  final double height;
  final double pad;
  final double pitch;
  final Size pill;

  Size get drop => pill + const Offset(2 * kGlassTabDropGrow, 2 * kGlassTabDropGrow);

  /// The centre of item [i] — fractional while the drop is between two.
  double centre(double i) => pad + pitch * (i + 0.5);

  /// The item index under [x], fractional, clamped to the items.
  double indexAt(double x, int count) => ((x - pad) / pitch - 0.5).clamp(0.0, count - 1.0);

  /// How far the drop reaches past the bar's resting box, per side — held,
  /// and stretched or squashed as far as [motion] can.
  Size margin(int count, GlassDropMotion motion) {
    final Size reach = motion.reach(drop);
    return Size(
      math.max(drop.width / 2 + reach.width - centre(0), _kBarGrow.width) + 2,
      math.max((drop.height - height) / 2 + reach.height, _kBarGrow.height) + 2,
    );
  }
}

/// A bottom bar of tabs whose selection becomes a glass drop under a finger.
///
/// The bar is a [GlassBar] — the theme's finish, the theme's label colour —
/// and the drop is a clear glass that magnifies it. See the file comment for
/// what each part costs.
///
/// At rest the selected item sits on a grey capsule in [activeColor], and
/// nothing about it but the bar is glass. Pressed, the capsule lifts into a
/// drop [kGlassTabDropGrow] larger on every side that magnifies the bar by
/// [dropZoom]; dragged, it follows the finger and the item under it takes the
/// accent; let go, it settles on an item and [onSelected] is told which. A
/// flick carries the drop on to the item it was heading for.
///
/// The items stack icon over label, as an iPhone's do, while the bar gives
/// each less than 80 px, and sit side by side, as an iPad's do, above that.
/// The bar is 60 tall stacked and 44 side by side, and takes the whole width
/// it is given.
///
/// ```dart
/// GlassTabBar(
///   items: const <GlassTabItem>[
///     GlassTabItem(icon: Icons.home, label: 'Home'),
///     GlassTabItem(icon: Icons.search, label: 'Search'),
///     GlassTabItem(icon: Icons.person, label: 'Profile'),
///   ],
///   selectedIndex: tab,
///   onSelected: (int i) => setState(() => tab = i),
/// )
/// ```
///
/// > **Note:** the drop is glass on glass, so the frames that record while it
/// > is held take a second snapshot. While it moves, only the frames where
/// > the highlighted item changes record at all.
///
/// **Minimized on scroll.** With [minimizeBehavior]
/// [GlassTabBarMinimizeBehavior.onScrollDown], under a
/// [GlassTabBarMinimizer] (a [GlassScaffold] is one), the bar collapses to a
/// circle of its own height at its start edge when the content scrolls down —
/// the selected item's icon in it — and expands when the content scrolls back
/// up; a tap on the circle expands it too, and selects nothing. The collapse
/// is a shape changing inside a declared travel region, so it takes no
/// capture; under reduced motion it is not animated at all.
///
/// **An accessory** ([bottomAccessory], UIKit's `tabViewBottomAccessory`) is
/// a glass capsule [kGlassTabAccessoryHeight] tall above the bar, which moves
/// down beside the collapsed circle. The bar's box is the same height either
/// way, so a body told the bar's height is not laid out again for it.
///
/// See also:
///
///  * [GlassTabItem] and [GlassTabItemLook], for an icon or a label the bar
///    cannot colour itself.
///  * [GlassScaffold.bottomBar], where a tab bar usually goes.
///  * [GlassSegmentedControl], the same drop over a track that is not glass.
///  * [Tab bar on the site](https://g1455.plugfox.dev/components/tab-bar).
///
/// {@category Panels and controls}
class GlassTabBar extends StatefulWidget {
  /// A bar of [items] — at least two — with [selectedIndex] highlighted.
  ///
  /// [dropZoom] must be above 0. [onSelected] null disables the bar.
  const GlassTabBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.activeColor = const Color(0xFF007AFF),
    this.dropZoom = kGlassTabDropZoom,
    this.dropMotion,
    this.minimizeBehavior = GlassTabBarMinimizeBehavior.never,
    this.bottomAccessory,
    super.key,
  }) : assert(items.length >= 2),
       assert(dropZoom > 0);

  /// The tabs, left to right.
  final List<GlassTabItem> items;

  /// The selected item's index into [items]. The capsule slides to it when it
  /// changes, unless a finger is down on the bar.
  final int selectedIndex;

  /// Called with the item a tap or a drag settles on, when it is not
  /// [selectedIndex]. Null disables the bar.
  final ValueChanged<int>? onSelected;

  /// The selected item's icon and label, and the one under a held drop.
  final Color activeColor;

  /// See [kGlassTabDropZoom]; 1 is a drop that does not magnify.
  final double dropZoom;

  /// How the held drop deforms as it launches and brakes. Null takes
  /// [GlassThemeData.dropMotion]; [GlassDropMotion.none] keeps its shape.
  /// Off under reduced motion either way.
  final GlassDropMotion? dropMotion;

  /// Whether the bar collapses to the selected tab when the content scrolls
  /// down. [GlassTabBarMinimizeBehavior.never] by default; see the class
  /// comment.
  final GlassTabBarMinimizeBehavior minimizeBehavior;

  /// A widget on a glass capsule above the bar — a now-playing row, a status —
  /// that moves down beside the bar's collapsed circle when it is minimized.
  /// Drawn in the bar's label colour. Null for none.
  final Widget? bottomAccessory;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar> with TickerProviderStateMixin {
  /// 0 at rest, 1 held — and past 1 for a moment, because it is a spring.
  late final AnimationController _lift = AnimationController.unbounded(vsync: this);

  /// Where the drop (or the capsule) is, in item units.
  late final AnimationController _at = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  /// The item the drop is over while held; drives the highlight, which is
  /// binary so a drag repaints the items only when it crosses into another.
  final ValueNotifier<int> _over = ValueNotifier<int>(0);

  late final GlassDropStretchDriver _stretch = GlassDropStretchDriver(
    vsync: this,
    position: () => _at.value * (_geometry?.pitch ?? 1),
  );
  GlassDropMotion _motion = GlassDropMotion.none;

  /// 0 expanded, 1 collapsed to the selected tab.
  late final AnimationController _minimize = AnimationController.unbounded(vsync: this);

  /// What says whether to collapse, and what it last said.
  ValueNotifier<bool>? _minimizer;

  /// Whether the bar is collapsed, or collapsing. A notifier rather than
  /// state: what follows it — where a press lands, what a screen reader is
  /// offered — is a few small widgets, and a rebuild of the whole bar costs a
  /// capture even when nothing it draws changed. Measured, not traced: one
  /// record per bare `setState` on the bar, before the collapse existed as
  /// after; through `setState` the collapse took one on the first frame of
  /// each direction, through this none.
  final ValueNotifier<bool> _collapsed = ValueNotifier<bool>(false);
  bool get _minimized => _collapsed.value;
  bool _reduceMotion = false;

  _TabGeometry? _geometry;
  bool _down = false;
  bool _moved = false;
  double _downX = 0;
  int _pressed = 0;
  VelocityTracker? _tracker;

  // Read off nothing — a feel, like the switch's 180 ms. Critically damped
  // would be no overshoot; this lifts a few percent past and settles.
  static const SpringDescription _liftSpring = SpringDescription(mass: 1, stiffness: 520, damping: 34);
  static const SpringDescription _slideSpring = SpringDescription(mass: 1, stiffness: 380, damping: 36);
  // Critically damped near enough: a shape that overshot would pass through
  // a circle narrower than the bar's height.
  static const SpringDescription _minimizeSpring = SpringDescription(mass: 1, stiffness: 300, damping: 36);

  @override
  void initState() {
    super.initState();
    _over.value = widget.selectedIndex;
    _at
      ..addListener(_noteOver)
      // Only while there is a drop to deform: the resting capsule keeps its
      // shape and needs no ticker.
      ..addListener(() => _down || _lift.value > 0 ? _stretch.wake() : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _listen();
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stretch.motion = _motion = GlassDropMotion.resolve(context, widget.dropMotion);
    if (widget.selectedIndex != oldWidget.selectedIndex && !_down) {
      _slideTo(widget.selectedIndex, 0);
    }
    if (widget.minimizeBehavior != oldWidget.minimizeBehavior) {
      _listen();
    }
  }

  /// Follows the minimizer above, if this bar collapses at all.
  void _listen() {
    final ValueNotifier<bool>? next = widget.minimizeBehavior == GlassTabBarMinimizeBehavior.onScrollDown
        ? GlassTabBarMinimizer.maybeOf(context)
        : null;
    if (!identical(next, _minimizer)) {
      _minimizer?.removeListener(_follow);
      _minimizer = next?..addListener(_follow);
    }
    _minimizeTo(next?.value ?? false);
  }

  void _follow() {
    final bool target = _minimizer?.value ?? false;
    _minimizeTo(target);
  }

  void _minimizeTo(bool target) {
    if (target == _minimized) {
      return;
    }
    _collapsed.value = target;
    if (target && _down) {
      // Collapsed under a finger: the hold is over, and selects nothing.
      _down = false;
      _slideTo(widget.selectedIndex, 0);
      _liftTo(0);
    }
    final double to = target ? 1 : 0;
    if (_reduceMotion) {
      _minimize.value = to;
      return;
    }
    _minimize
        .animateWith(SpringSimulation(_minimizeSpring, _minimize.value, to, _minimize.velocity, tolerance: _tolerance))
        .then((_) => _minimize.value = to);
  }

  /// A tap on the collapsed circle: the bar expands, and nothing is selected.
  void _expand() => _minimizer?.value = false;

  @override
  void dispose() {
    _minimizer?.removeListener(_follow);
    _minimize.dispose();
    _collapsed.dispose();
    _stretch.dispose();
    _lift.dispose();
    _at.dispose();
    _over.dispose();
    super.dispose();
  }

  void _noteOver() {
    final int i = _at.value.round().clamp(0, widget.items.length - 1);
    if (i != _over.value) {
      _over.value = i;
    }
  }

  bool get _enabled => widget.onSelected != null;

  // Ends the springs where the motion is under a device pixel, rather than at
  // the default thousandth: every frame of a spring's tail is a frame the bar
  // under the drop changed size, which is a capture.
  static const Tolerance _tolerance = Tolerance(distance: 0.004, velocity: 0.05);

  // And lands exactly on the target once inside it, so a held drop is at
  // materialize 1 and a settled one at 0 — not a spring's last residue of either.
  void _liftTo(double target) {
    _lift
        .animateWith(
          SpringSimulation(_liftSpring, _lift.value, target, _lift.velocity, tolerance: _tolerance),
        )
        .then((_) => _lift.value = target);
  }

  void _slideTo(int index, double velocity) {
    _at
        .animateWith(
          SpringSimulation(_slideSpring, _at.value, index.toDouble(), velocity, tolerance: _tolerance),
        )
        .then((_) => _at.value = index.toDouble());
  }

  void _onDown(PointerDownEvent e) {
    final _TabGeometry? g = _geometry;
    if (!_enabled || g == null || _down || _minimized || _minimize.value != 0) {
      return;
    }
    _down = true;
    _moved = false;
    _downX = e.localPosition.dx;
    _tracker = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.localPosition);
    _liftTo(1);
    // A press on another item takes the drop there; a press on the selected
    // one lifts it where it is.
    final int i = _pressed = g.indexAt(e.localPosition.dx, widget.items.length).round();
    _slideTo(i, 0);
  }

  void _onMove(PointerMoveEvent e) {
    final _TabGeometry? g = _geometry;
    if (!_down || g == null) {
      return;
    }
    _tracker?.addPosition(e.timeStamp, e.localPosition);
    if (!_moved && (e.localPosition.dx - _downX).abs() < 4) {
      return;
    }
    _moved = true;
    _at.value = g.indexAt(e.localPosition.dx, widget.items.length);
  }

  void _onUp(PointerUpEvent e) {
    final _TabGeometry? g = _geometry;
    if (!_down || g == null) {
      return;
    }
    _down = false;
    // The drop keeps the finger's speed into the settle, in item units, and a
    // flick carries it on to the item it was heading for.
    final double velocity = _moved ? (_tracker?.getVelocity().pixelsPerSecond.dx ?? 0) / g.pitch : 0;
    // A tap is the item pressed, wherever the drop has got to on its way.
    final int i = _moved ? (_at.value + velocity * 0.08).round().clamp(0, widget.items.length - 1) : _pressed;
    _slideTo(i, velocity);
    _liftTo(0);
    if (i != widget.selectedIndex) {
      widget.onSelected?.call(i);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (!_down) {
      return;
    }
    _down = false;
    _slideTo(widget.selectedIndex, 0);
    _liftTo(0);
  }

  // Two `LayoutBuilder`s, and the second is the point. A `LayoutBuilder` is a
  // build scope: every tick of an animation below it schedules it for layout,
  // and one whose constraints are loose — a bar placed with `bottom:` and no
  // height, which is how bars are placed — passes that up to its parent, and
  // the relayout repaints the host's whole screen on every frame of a press.
  // So the outer one only measures the width, and the animated tree lives
  // under an inner one that is given a tight size: a relayout boundary, behind
  // a repaint boundary of its own. And one above the outer one too, for the
  // rebuild a new selection brings.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Tab labels are not text to select, as a button's are not.
    child: SelectionContainer.disabled(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final _TabGeometry g = _geometry = _TabGeometry(width, widget.items.length);
          final Size margin = g.margin(widget.items.length, _motion);
          final double slot = math.max(g.height, kGlassMinTapTarget.height);
          final Widget? accessory = widget.bottomAccessory;
          final double above = accessory == null ? 0 : kGlassTabAccessoryHeight + _kAccessoryGap;
          final bool rtl = Directionality.of(context) == TextDirection.rtl;
          // The collapsed circle, in the box: the bar's own height, at its
          // start edge.
          final Rect circle = Rect.fromLTWH(
            rtl ? width - g.height : 0,
            above + (slot - g.height) / 2,
            g.height,
            g.height,
          );
          Widget travel(Widget child) => debugGlassTabMinimizeTravel ? GlassTravel(child: child) : child;
          return SizedBox(
            width: width,
            height: above + slot,
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints _) => Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // The bar's whole growth is declared, so growing does not retake
                    // the bar's own capture — and so is its collapse, which is inside
                    // the same box.
                    Positioned(
                      left: -_kBarGrow.width,
                      right: -_kBarGrow.width,
                      top: above - _kBarGrow.height,
                      height: slot + 2 * _kBarGrow.height,
                      child: travel(
                        // A boundary of its own, so the bar resizing repaints this
                        // and not the screen it sits on.
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[_lift, _minimize]),
                            builder: (BuildContext context, Widget? child) => _bar(
                              context,
                              g,
                              margin,
                              slot,
                              circle.translate(_kBarGrow.width, _kBarGrow.height - above),
                              child!,
                            ),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _collapsed,
                              child: _content(g),
                              builder: (BuildContext context, bool collapsed, Widget? content) =>
                                  ExcludeSemantics(excluding: collapsed, child: content),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (accessory != null)
                      Positioned.fill(
                        child: travel(
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _minimize,
                              builder: (BuildContext context, Widget? child) {
                                final double m = _minimize.value.clamp(0.0, 1.0);
                                final open = Rect.fromLTWH(0, 0, width, kGlassTabAccessoryHeight);
                                final inline = Rect.fromLTRB(
                                  rtl ? 0 : circle.right + _kAccessoryGap,
                                  circle.center.dy - kGlassTabAccessoryHeight / 2,
                                  rtl ? circle.left - _kAccessoryGap : width,
                                  circle.center.dy + kGlassTabAccessoryHeight / 2,
                                );
                                return Stack(
                                  children: <Widget>[
                                    Positioned.fromRect(
                                      rect: _snap(context, Rect.lerp(open, inline, m)!),
                                      child: GlassBar(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: child!,
                                      ),
                                    ),
                                  ],
                                );
                              },
                              child: Align(alignment: AlignmentDirectional.centerStart, child: accessory),
                            ),
                          ),
                        ),
                      ),
                    // The press, over the bar's slot only: an accessory above it
                    // takes its own taps, and a collapsed bar takes none here.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: above,
                      height: slot,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _collapsed,
                        builder: (BuildContext context, bool collapsed, Widget? listener) =>
                            IgnorePointer(ignoring: collapsed, child: listener),
                        // Translucent: a sibling over the bar now, not its ancestor,
                        // and an opaque one would end the hit test here — the bar's
                        // glass would never hear the touch its ripple answers.
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _onDown,
                          onPointerMove: _onMove,
                          onPointerUp: _onUp,
                          onPointerCancel: _onCancel,
                        ),
                      ),
                    ),
                    // Always in the tree, and live only while collapsed.
                    Positioned.fromRect(
                      rect: circle,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _collapsed,
                        builder: (BuildContext context, bool collapsed, Widget? circle) => IgnorePointer(
                          ignoring: !collapsed,
                          child: ExcludeSemantics(excluding: !collapsed, child: circle),
                        ),
                        child: Semantics(
                          button: true,
                          label: widget.items[widget.selectedIndex].label,
                          selected: true,
                          enabled: true,
                          onTap: _expand,
                          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _expand),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  /// [rect] with its edges on whole device pixels: a change under a pixel is a
  /// repaint of the glass that nobody can see.
  static Rect _snap(BuildContext context, Rect rect) {
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    double px(double v) => (v * dpr).round() / dpr;
    return Rect.fromLTRB(px(rect.left), px(rect.top), px(rect.right), px(rect.bottom));
  }

  /// The bar in its travel region — grown while held, collapsed to [circle]
  /// (in the region's coordinates) while minimized — with [content] in it.
  Widget _bar(BuildContext context, _TabGeometry g, Size margin, double slot, Rect circle, Widget content) {
    // In whole device pixels: the drop on the bar shows the bar, so a growth
    // under a pixel is a capture that changes nothing anybody can see.
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    double px(double v) => (v * dpr).round() / dpr;
    final double t = _lift.value.clamp(0.0, 1.2);
    final double m = _minimize.value.clamp(0.0, 1.0);
    final double gx = px(_kBarGrow.width * t);
    final double gy = px(_kBarGrow.height * t);
    final double width = g.pad * 2 + g.pitch * widget.items.length;
    // Where the items sit at rest, in the region: the bar's growth goes round
    // them.
    final Offset row = Offset(_kBarGrow.width, _kBarGrow.height + (slot - g.height) / 2);
    final open = Rect.fromLTWH(row.dx - gx, row.dy - gy, width + 2 * gx, g.height + 2 * gy);
    final Rect bar = m == 0 ? open : _snap(context, Rect.lerp(open, circle, m)!);
    // Collapsing, the items slide so the selected one ends in the circle, and
    // fade as the circle's own icon comes in.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double selected = g.centre(widget.selectedIndex.toDouble());
    final double slide = m * (circle.center.dx - (row.dx + (rtl ? width - selected : selected)));
    final Offset items = row.translate(slide, 0) - bar.topLeft;
    final Offset drop = row.translate(-margin.width, -margin.height) - bar.topLeft;
    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: bar,
          child: GlassBar(
            padding: EdgeInsets.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // The same widgets at every stage of the collapse, so it changes
                // properties and never the tree: clipped to the bar only while it
                // collapses — at rest the items are inside it anyway — and the
                // fades at 1 and 0 paint as if they were not there.
                Positioned.fill(
                  child: ClipRect(
                    clipBehavior: m > 0 ? Clip.hardEdge : Clip.none,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          left: items.dx,
                          top: items.dy,
                          width: width,
                          height: g.height,
                          child: Opacity(opacity: 1 - (2 * m).clamp(0.0, 1.0), child: content),
                        ),
                        // Only on a bar that can collapse, which is fixed for its
                        // lifetime as far as the tree is concerned: a bar that never
                        // does draws exactly what it drew before it could.
                        if (widget.minimizeBehavior != GlassTabBarMinimizeBehavior.never)
                          Positioned.fill(
                            child: Opacity(
                              opacity: (2 * m - 1).clamp(0.0, 1.0),
                              child: Center(child: _glyph(context, g)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: drop.dx,
                  top: drop.dy,
                  width: width + 2 * margin.width,
                  height: g.height + 2 * margin.height,
                  child: _dropStage(g, margin),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The selected item's icon, as the collapsed circle shows it.
  Widget _glyph(BuildContext context, _TabGeometry g) {
    final int i = widget.selectedIndex;
    final GlassTabItem item = widget.items[i];
    final GlassTabItemLook look = _look(context, g, i, highlighted: true);
    return item.iconBuilder?.call(context, look) ?? Icon(item.icon, size: look.iconSize, color: look.color);
  }

  /// The capsule and the items: everything the drop magnifies.
  Widget _content(_TabGeometry g) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      // The capsule, behind its own boundary: it slides with `_at` at rest and
      // is gone while the drop is up, so a drag repaints nothing here.
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_lift, _at]),
            builder: (BuildContext context, Widget? _) {
              final double fade = 1 - _lift.value.clamp(0.0, 1.0);
              if (fade <= 0) {
                return const SizedBox.shrink();
              }
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: g.centre(_at.value) - g.pill.width / 2,
                    top: (g.height - g.pill.height) / 2,
                    width: g.pill.width,
                    height: g.pill.height,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: _kPill.withValues(alpha: _kPill.a * fade),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      Positioned.fill(
        child: RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _over,
            builder: (BuildContext context, int over, Widget? _) => Row(
              children: <Widget>[
                SizedBox(width: g.pad),
                for (var i = 0; i < widget.items.length; i++)
                  SizedBox(
                    width: g.pitch,
                    child: _item(g, i, highlighted: i == over),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _item(_TabGeometry g, int i, {required bool highlighted}) {
    final GlassTabItem item = widget.items[i];
    return Semantics(
      button: true,
      label: item.label,
      selected: i == widget.selectedIndex,
      enabled: _enabled,
      onTap: _enabled ? () => widget.onSelected?.call(i) : null,
      child: ExcludeSemantics(
        // Under the bar's glass, so the ambient colour is the one its
        // legibility chose — read here rather than at the bar's build, which
        // is above the glass.
        child: Builder(
          builder: (BuildContext context) {
            final GlassTabItemLook look = _look(context, g, i, highlighted: highlighted);
            final Widget icon =
                item.iconBuilder?.call(context, look) ?? Icon(item.icon, size: look.iconSize, color: look.color);
            final Widget label =
                item.labelBuilder?.call(context, look) ??
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: look.labelStyle,
                );
            return g.inline
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      icon,
                      const SizedBox(width: 6),
                      Flexible(child: label),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[icon, const SizedBox(height: 2), label],
                  );
          },
        ),
      ),
    );
  }

  GlassTabItemLook _look(BuildContext context, _TabGeometry g, int i, {required bool highlighted}) {
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final Color colour = highlighted
        ? widget.activeColor
        : IconTheme.of(context).color ?? ambient.color ?? const Color(0xFF000000);
    return GlassTabItemLook(
      index: i,
      color: colour,
      iconSize: g.inline ? 20 : 26,
      labelStyle: ambient.merge(
        TextStyle(fontSize: g.inline ? 12 : 11, fontWeight: FontWeight.w600, color: colour),
      ),
      selected: i == widget.selectedIndex,
      highlighted: highlighted,
      inline: g.inline,
    );
  }

  /// The drop's region: the bar's resting box plus how far the drop reaches
  /// past it.
  ///
  /// No boundary of its own, unlike the switch's: moving the drop repaints the
  /// bar, whose draw the watch excludes and whose content sits behind its own
  /// boundaries, so nothing the watch reads changes either way — a boundary
  /// here was tried and broke no test when removed.
  Widget _dropStage(_TabGeometry g, Size margin) => GlassTravel(
    child: AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_lift, _at, _stretch]),
      builder: (BuildContext context, Widget? _) {
        final double lift = _lift.value;
        final double appear = lift.clamp(0.0, 1.0);
        // Deformed only as far as it has lifted: the drop arriving is round.
        final Size size = GlassDropStretch.apply(
          Size(
            lerpDouble(g.pill.width, g.drop.width, lift)!,
            lerpDouble(g.pill.height, g.drop.height, lift)!,
          ),
          _stretch.value * appear,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: margin.width + g.centre(_at.value) - size.width / 2,
              top: margin.height + (g.height - size.height) / 2,
              width: size.width,
              height: size.height,
              child: GlassSurface(
                borderRadius: kGlassCapsule,
                finish: GlassFinish.clear.copyWith(
                  optics: kGlassDropOptics.copyWith(zoom: widget.dropZoom),
                ),
                // The drop arrives by its optics, not its shape: `presence`
                // erodes a lone capsule to its medial axis, which on the
                // way down read as a bright stripe across the item for
                // ~50 ms after the capsule was back. Apple's keeps its
                // outline and fades the bend and the rim in and out.
                materialize: appear,
                labelled: false,
              ),
            ),
          ],
        );
      },
    ),
  );
}
