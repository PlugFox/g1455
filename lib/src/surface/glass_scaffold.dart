// A screen wired the way the README recommends: a host, a bar with the scroll
// edge effect under it, a body that scrolls under the bar, and an optional
// bottom bar and floating action.
//
// **Composition and nothing else.** Every pixel here is drawn by a widget that
// exists without it — [GlassHost], [GlassScrollEdge], [GlassAbove] and whatever
// the application puts in the slots — and what this file adds is where they go
// and what the body is told about them. It is the arrangement the example's
// own shell and the scroll edge demo spell out by hand, written once.
//
// **The body is told the bars' extents through `MediaQuery.padding`**, the
// way `Scaffold` tells it with `extendBody` and `extendBodyBehindAppBar`: the
// body is laid out under the whole screen, so content scrolls under the glass,
// and a scroll view that takes its padding from the media query (every
// `ListView`, `GridView` and `CustomScrollView` with a `SafeArea`-style
// padding) starts below the top bar and ends above the bottom one. The bottom
// bar is measured, because a [GlassTabBar]'s height follows its width; the
// top bar is declared ([GlassScaffold.topBarHeight]), because the scroll edge
// is laid out from it.
//
// **What it costs is what the README's arrangement costs.** The bars are
// lifted ([GlassAbove]) so that glass scrolling under them is in their
// backdrop; over plain content that is level 0 and free, over glass cards it is
// one more snapshot on every frame that records. While the body scrolls, the
// content under the bars changes on every frame, and so **every frame of a
// scroll is one capture** — of the whole host, for every glass on the screen at
// once — and a still screen is held, which is the default and the package's
// largest saving. Nothing moves *inside* the bars on a scroll, so there is
// nothing for a `GlassTravel` to declare here; a [GlassTabBar] declares its own
// drop's.
//
// **The screen is a [GlassTabBarMinimizer]**, because the body's scroll view
// and the bottom bar are siblings and a scroll notification only travels up:
// a [GlassTabBar] that collapses on a scroll down
// ([GlassTabBarMinimizeBehavior.onScrollDown]) is told by it. A bar that does
// not ask is not told, and the listener costs a comparison per scroll update.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass_above.dart';
import 'glass_host.dart';
import 'glass_scroll_edge.dart';
import 'glass_tab_bar.dart';

/// [GlassScaffold.topBarHeight]'s default, logical px. Layout taste, not a
/// measurement: Material's toolbar height, which the example's shell uses.
///
/// {@category Panels and controls}
const double kGlassScaffoldBarHeight = 56;

/// [GlassScaffold.barMargin]'s default: the space around each bar, inside the
/// safe area. Layout taste.
///
/// {@category Panels and controls}
const EdgeInsets kGlassScaffoldBarMargin = EdgeInsets.fromLTRB(12, 8, 12, 8);

/// How far the floating action stands from the screen's end edge and from the
/// bottom bar, logical px. Layout taste, as Material's.
///
/// {@category Panels and controls}
const double kGlassScaffoldActionGap = 16;

/// A screen: a [body] that scrolls under a glass [topBar], with an optional
/// [bottomBar] and [floatingAction], under a [GlassHost].
///
/// ```dart
/// GlassScaffold(
///   topBar: const GlassBar(
///     child: Row(
///       children: <Widget>[Icon(Icons.arrow_back), SizedBox(width: 12), Text('Library')],
///     ),
///   ),
///   bottomBar: GlassTabBar(
///     items: const <GlassTabItem>[
///       GlassTabItem(icon: Icons.home, label: 'Home'),
///       GlassTabItem(icon: Icons.search, label: 'Search'),
///     ],
///     selectedIndex: tab,
///     onSelected: (int i) => setState(() => tab = i),
///   ),
///   // Takes its padding from the media query: starts below the top bar,
///   // ends above the tab bar, and scrolls under both.
///   body: ListView.builder(itemCount: 50, itemBuilder: buildRow),
/// )
/// ```
///
/// **The host.** By default the scaffold mounts a [GlassHost] only when there
/// is none above it ([host]). The one it mounts takes every default; to
/// declare anything — a backdrop, a finish, the hardware, a ripple — put your
/// own host above and the scaffold uses it. Dialogs, sheets and menus are built
/// in the navigator's overlay, so they need the host above the navigator
/// (`MaterialApp.builder`); a host the scaffold mounts is inside the route and
/// does not reach them.
///
/// **The body** fills the whole scaffold and is told the bars' extents as
/// `MediaQuery.padding` — top and bottom, never less than the safe area's —
/// which is what lets it scroll under them. A body that is not a scroll view
/// can read the same padding, or wrap itself in a `SafeArea`. The keyboard is
/// not handled: the body sees `MediaQuery.viewInsets` as it is.
///
/// **A tab bar that collapses on scroll.** The scaffold is a
/// [GlassTabBarMinimizer]: a [GlassTabBar] in [bottomBar] with
/// `minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown` collapses to
/// its selected tab when the body scrolls down and expands when it scrolls up.
/// Its box keeps its height, so the body's padding does not move.
///
/// > **Note:** every frame of a scroll is one capture of the whole host, for
/// > every glass on the screen at once, because the content under the bars
/// > changes; a still screen is held. Over glass cards, the lifted bars add
/// > one snapshot to each frame that records.
///
/// See also:
///
///  * [GlassScrollEdge], the effect under the top bar, for a layout this
///    does not cover.
///  * [GlassHost], to declare what the scaffold's own host leaves at its
///    defaults.
///  * [GlassBar] and [GlassTabBar], the usual [topBar] and [bottomBar].
///  * [Scaffold on the site](https://g1455.plugfox.dev/components/scaffold).
///
/// {@category Panels and controls}
class GlassScaffold extends StatelessWidget {
  /// A screen of [body], with whichever of [topBar], [bottomBar] and
  /// [floatingAction] are given. [topBarHeight] must not be negative.
  const GlassScaffold({
    required this.body,
    this.topBar,
    this.topBarHeight = kGlassScaffoldBarHeight,
    this.scrollEdge = GlassScrollEdgeStyle.soft,
    this.bottomBar,
    this.floatingAction,
    this.barMargin = kGlassScaffoldBarMargin,
    this.host,
    super.key,
  }) : assert(topBarHeight >= 0);

  /// The screen's content: laid out under the whole scaffold, and told the
  /// bars' extents through `MediaQuery.padding`.
  final Widget body;

  /// The bar at the top — usually a [GlassBar] — laid out [topBarHeight] tall
  /// and the scaffold's width less [barMargin] and the safe area. Null for no
  /// top bar and no scroll edge.
  final Widget? topBar;

  /// The height [topBar] is laid out in, logical px. Declared rather than
  /// measured, because the scroll edge under the bar is laid out from it.
  final double topBarHeight;

  /// The scroll edge effect under [topBar], or null for none — the bar is then
  /// lifted ([GlassAbove]) and nothing else.
  ///
  /// [GlassScrollEdgeStyle.soft] is iOS's: one glass strip the width of the
  /// screen, which is a slot in the capture and nothing more. Its tint follows
  /// the host's declared backdrop; see [GlassScrollEdge.appearance].
  final GlassScrollEdgeStyle? scrollEdge;

  /// The bar at the bottom — usually a [GlassTabBar] — at its own height, the
  /// scaffold's width less [barMargin] and the safe area, and lifted. Null for
  /// none.
  final Widget? bottomBar;

  /// A control floating at the end edge, above [bottomBar] — usually a
  /// [GlassButton] — at its own size, and lifted. Null for none.
  final Widget? floatingAction;

  /// The space around each bar, inside the safe area: the top bar's top and
  /// sides and the gap under it, the bottom bar's sides and the gap above it.
  /// Under the bottom bar it is the larger of this and the safe area.
  final EdgeInsets barMargin;

  /// Whether the scaffold mounts a [GlassHost] of its own: null (the default)
  /// when there is none above it, true always, false never.
  final bool? host;

  /// The top bar's extent from the top of the screen, logical px: the safe
  /// area, [barMargin] above and below, and [topBarHeight]. What the body is
  /// told as its top padding, and the scroll edge's [GlassScrollEdge.extent].
  double topExtentFor(EdgeInsets safe) => safe.top + barMargin.top + topBarHeight + barMargin.bottom;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double? top = topBar == null ? null : topExtentFor(safe);
    final Widget screen = CustomMultiChildLayout(
      delegate: _GlassScaffoldLayout(
        safe: safe,
        margin: barMargin,
        textDirection: Directionality.of(context),
      ),
      // In paint order: the body under everything, the top bar over all.
      children: <Widget>[
        LayoutId(
          id: _Slot.body,
          child: _GlassScaffoldBody(top: top, child: body),
        ),
        if (bottomBar case final Widget bar)
          LayoutId(
            id: _Slot.bottom,
            child: GlassAbove(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  safe.left + barMargin.left,
                  barMargin.top,
                  safe.right + barMargin.right,
                  math.max(safe.bottom, barMargin.bottom),
                ),
                child: bar,
              ),
            ),
          ),
        if (floatingAction case final Widget action)
          LayoutId(
            id: _Slot.action,
            child: GlassAbove(child: action),
          ),
        if (top != null) LayoutId(id: _Slot.top, child: _top(safe, top)),
      ],
    );
    final bool own = host ?? GlassProxyScope.maybeOf(context) == null;
    final Widget minimizing = GlassTabBarMinimizer(child: screen);
    return own ? GlassHost(child: minimizing) : minimizing;
  }

  Widget _top(EdgeInsets safe, double extent) {
    final Widget bar = Padding(
      padding: EdgeInsets.fromLTRB(
        safe.left + barMargin.left,
        safe.top + barMargin.top,
        safe.right + barMargin.right,
        barMargin.bottom,
      ),
      child: SizedBox(height: topBarHeight, child: topBar),
    );
    if (scrollEdge case final GlassScrollEdgeStyle style) {
      return GlassScrollEdge(side: GlassScrollEdgeSide.top, extent: extent, style: style, child: bar);
    }
    return GlassAbove(
      child: SizedBox(height: extent, child: bar),
    );
  }
}

enum _Slot { body, bottom, action, top }

/// The body's constraints, carrying the bottom bar's measured extent — the
/// way `Scaffold` hands its body the heights of the bars it extends under.
class _GlassScaffoldConstraints extends BoxConstraints {
  _GlassScaffoldConstraints({required this.bottom, required Size size})
    : super(minWidth: size.width, maxWidth: size.width, minHeight: size.height, maxHeight: size.height);

  /// From the bottom of the screen to the top of the bottom bar's margin, or
  /// null with no bottom bar.
  final double? bottom;

  @override
  bool operator ==(Object other) => super == other && other is _GlassScaffoldConstraints && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(super.hashCode, bottom);
}

/// Lays out the bottom bar first, so the body can be told its height.
class _GlassScaffoldLayout extends MultiChildLayoutDelegate {
  _GlassScaffoldLayout({required this.safe, required this.margin, required this.textDirection});

  final EdgeInsets safe;
  final EdgeInsets margin;
  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    final across = BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height);
    double? bottom;
    if (hasChild(_Slot.bottom)) {
      final double height = layoutChild(_Slot.bottom, across).height;
      positionChild(_Slot.bottom, Offset(0, size.height - height));
      bottom = height;
    }
    if (hasChild(_Slot.top)) {
      layoutChild(_Slot.top, across);
      positionChild(_Slot.top, Offset.zero);
    }
    if (hasChild(_Slot.action)) {
      final Size action = layoutChild(_Slot.action, BoxConstraints.loose(size));
      final double above = bottom ?? safe.bottom;
      final double y = size.height - above - kGlassScaffoldActionGap - action.height;
      final double x = switch (textDirection) {
        TextDirection.ltr => size.width - safe.right - kGlassScaffoldActionGap - action.width,
        TextDirection.rtl => safe.left + kGlassScaffoldActionGap,
      };
      positionChild(_Slot.action, Offset(x, y));
    }
    layoutChild(_Slot.body, _GlassScaffoldConstraints(bottom: bottom, size: size));
    positionChild(_Slot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_GlassScaffoldLayout oldDelegate) =>
      oldDelegate.safe != safe || oldDelegate.margin != margin || oldDelegate.textDirection != textDirection;
}

/// The body, told the bars' extents as its media query's padding.
class _GlassScaffoldBody extends StatelessWidget {
  const _GlassScaffoldBody({required this.top, required this.child});

  /// The top bar's extent, or null with no top bar.
  final double? top;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double? bottom = constraints is _GlassScaffoldConstraints ? constraints.bottom : null;
      final MediaQueryData query = MediaQuery.of(context);
      final EdgeInsets padding = query.padding;
      return MediaQuery(
        data: query.copyWith(
          padding: padding.copyWith(
            top: math.max(padding.top, top ?? 0),
            bottom: math.max(padding.bottom, bottom ?? 0),
          ),
        ),
        child: child,
      );
    },
  );
}
