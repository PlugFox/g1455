// Page dots on a glass capsule: iOS's `UIPageControl` with its platter on.
//
// What it costs: **one surface**. The dots are paint on the surface's own
// canvas, driven by a listenable without a build — the page controller's
// position, or the control's own animation — so a page turning, a tap and a
// drag across the dots repaint the surface's subtree and nothing else. That
// subtree is a repaint boundary the capture skips, so none of it is a
// capture. Asserted, with the control that makes the counter move, in
// `glass_page_control_test.dart`.
//
// What it does on a touch is Apple's, not a guess at it: a tap moves **one
// page toward the side tapped** — not to the dot under the finger, which at
// 8 px is not a target anyone can hit — and a drag along the capsule scrubs,
// the page following the dot under the finger (iOS 14's interaction).
//
// **Not measured:** the sizes. iOS 26's page control was not among the
// controls spikes 27-33 read. The dot, the gap and the current dot's width
// are layout, named as such.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassMinTapTarget;
import 'glass_finish.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// A page dot's diameter, logical px. Layout, not a reading.
///
/// {@category Panels and controls}
const double kGlassPageDot = 8;

/// The space between two dots, logical px. Layout, not a reading.
///
/// {@category Panels and controls}
const double kGlassPageDotGap = 8;

/// The capsule's height, logical px. Layout, not a reading; the control is
/// laid out [kGlassMinTapTarget] tall around it.
///
/// {@category Panels and controls}
const double kGlassPageControlHeight = 26;

const double _kPadding = 10;

/// The opacity of a dot that is not the current page, of the label colour.
const double _kRestingDot = 0.35;

/// Page dots on a glass capsule — iOS's `UIPageControl` on its platter.
///
/// [count] dots, the current one [currentDotWidth] wide and in the full label
/// colour, the others round and dimmed. Between two pages the two dots trade
/// width and brightness continuously, so the control can follow a swipe.
///
/// Either [controller] drives it — the dots follow the `PageView`'s scroll,
/// and a tap or a drag animates the view to the page — or, without one,
/// [currentPage] does, and the change is reported to [onPageChanged] for the
/// caller to pass back. [onPageChanged] is called in both cases; null with no
/// [controller] makes the control a display.
///
/// A tap moves one page toward the side tapped, as iOS's does; a drag along
/// the capsule scrubs to the dot under the finger.
///
/// ```dart
/// Stack(
///   children: <Widget>[
///     PageView(controller: pages, children: photos),
///     Align(
///       alignment: Alignment.bottomCenter,
///       child: GlassPageControl(count: photos.length, controller: pages),
///     ),
///   ],
/// )
/// ```
///
/// > **Note:** one surface. The dots are drawn inside the glass from the
/// > controller's position without a build, so turning a page is no capture
/// > of its own — what the page view scrolls under the glass is, and that is
/// > the honest price of glass over moving content.
///
/// A screen reader hears one adjustable control — "Page 2 of 5" by default —
/// and turns the page with increase and decrease.
///
/// See also:
///
///  * [GlassSegmentedControl], a choice among a few labelled options.
///  * [GlassTabBar], navigation between top-level pages.
///
/// {@category Panels and controls}
class GlassPageControl extends StatefulWidget {
  /// A control of [count] dots — at least one.
  const GlassPageControl({
    required this.count,
    this.currentPage = 0,
    this.onPageChanged,
    this.controller,
    this.currentDotWidth = 20,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.finish,
    this.semanticLabel,
    this.semanticFormatterCallback,
    super.key,
  }) : assert(count >= 1),
       assert(currentDotWidth >= kGlassPageDot);

  /// How many pages there are.
  final int count;

  /// The current page, when there is no [controller]. With one, the
  /// controller's position is the current page and this is ignored.
  final int currentPage;

  /// Called with the page a tap, a drag or a screen reader picks — and, with
  /// a [controller], with each page the view settles on nearest.
  final ValueChanged<int>? onPageChanged;

  /// The page view this control follows and turns. Null makes [currentPage]
  /// the page.
  final PageController? controller;

  /// The current dot's width, logical px; the others are [kGlassPageDot]
  /// round. [kGlassPageDot] is a control whose current page is told by
  /// brightness alone.
  final double currentDotWidth;

  /// How long a tap takes to turn the page — the controller's animation, or
  /// the dots' own without one.
  final Duration duration;

  /// The curve of that turn.
  final Curve curve;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// What a screen reader says the control is for.
  final String? semanticLabel;

  /// How a screen reader says the current page, from 0, of [count]. Null says
  /// "Page 2 of 5".
  final String Function(int page, int count)? semanticFormatterCallback;

  @override
  State<GlassPageControl> createState() => _GlassPageControlState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('count', count))
      ..add(IntProperty('currentPage', currentPage, defaultValue: 0))
      ..add(DiagnosticsProperty<PageController>('controller', controller, defaultValue: null))
      ..add(DoubleProperty('currentDotWidth', currentDotWidth, defaultValue: 20.0))
      ..add(FlagProperty('interactive', value: onPageChanged != null || controller != null, ifFalse: 'display'))
      ..add(DiagnosticsProperty<GlassFinish>('finish', finish, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

class _GlassPageControlState extends State<GlassPageControl> with SingleTickerProviderStateMixin {
  /// The dots' own position, without a controller: animated from the old
  /// page to the new one when [GlassPageControl.currentPage] changes.
  late final AnimationController _own = AnimationController.unbounded(
    vsync: this,
    value: widget.currentPage.toDouble(),
  );

  /// The page the last build said, so the semantics and [onPageChanged]
  /// follow a controller only when the nearest page changes, not per pixel.
  late int _page = _nearest;

  bool get _interactive => widget.onPageChanged != null || widget.controller != null;

  /// Where the dots are, in pages: fractional between two.
  double get _position {
    final PageController? controller = widget.controller;
    if (controller == null) {
      return _own.value;
    }
    if (controller.hasClients && controller.positions.length == 1) {
      final ScrollPosition p = controller.position;
      if (p.hasContentDimensions && p.hasPixels) {
        return controller.page ?? controller.initialPage.toDouble();
      }
    }
    return controller.initialPage.toDouble();
  }

  int get _nearest => _position.round().clamp(0, widget.count - 1);

  Listenable get _driver => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GlassPageControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
      _page = _nearest;
    }
    if (widget.controller == null && widget.currentPage != oldWidget.currentPage) {
      _page = widget.currentPage.clamp(0, widget.count - 1);
      _own.animateTo(_page.toDouble(), duration: widget.duration, curve: widget.curve);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onScroll);
    _own.dispose();
    super.dispose();
  }

  /// A rebuild — the semantics' value, and the callback — only when the
  /// nearest page changes; every other tick of a scroll is a repaint of the
  /// dots alone.
  void _onScroll() {
    final int page = _nearest;
    if (page == _page) {
      return;
    }
    setState(() => _page = page);
    widget.onPageChanged?.call(page);
  }

  void _goTo(int page) {
    final int to = page.clamp(0, widget.count - 1);
    final PageController? controller = widget.controller;
    if (controller != null) {
      if (controller.hasClients) {
        // `onPageChanged` comes from `_onScroll` as the view passes the page.
        controller.animateToPage(to, duration: widget.duration, curve: widget.curve);
      }
      return;
    }
    if (to != widget.currentPage) {
      widget.onPageChanged?.call(to);
    }
  }

  _DotGeometry get _geometry => _DotGeometry(widget.count, widget.currentDotWidth);

  void _onTapUp(TapUpDetails d) {
    final double x = d.localPosition.dx - _inset;
    final double current = _geometry.centreOf(_page.toDouble(), _page);
    _goTo(_page + (x < current ? -1 : 1));
  }

  /// The page a scrub last asked for: the caller's rebuild, or the
  /// controller's scroll, reaches [_page] only after the next pointer move,
  /// and a scrub compared with [_page] alone would ask for the same page
  /// again on every move until then.
  int? _asked;

  void _onDrag(DragUpdateDetails d) {
    final int page = _geometry.indexAt(d.localPosition.dx - _inset, _position);
    if (page != (_asked ?? _page)) {
      _asked = page;
      _goTo(page);
    }
  }

  /// How far the capsule is from the hit box's left edge.
  double get _inset => _hitWidth > _geometry.width ? (_hitWidth - _geometry.width) / 2 : 0;
  double get _hitWidth => math.max(_geometry.width, kGlassMinTapTarget.width);

  String _say(int page) {
    final String Function(int, int)? say = widget.semanticFormatterCallback;
    return say == null ? 'Page ${page + 1} of ${widget.count}' : say(page, widget.count);
  }

  @override
  Widget build(BuildContext context) {
    final GlassThemeData theme = GlassTheme.of(context);
    final Color label = theme.legibility(widget.finish ?? theme.finish).label;
    final _DotGeometry g = _geometry;
    final int page = _page;
    final bool interactive = _interactive;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _say(page),
      increasedValue: interactive && page < widget.count - 1 ? _say(page + 1) : null,
      decreasedValue: interactive && page > 0 ? _say(page - 1) : null,
      onIncrease: interactive && page < widget.count - 1 ? () => _goTo(page + 1) : null,
      onDecrease: interactive && page > 0 ? () => _goTo(page - 1) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The node above says what a screen reader can do: a tap that means
        // "toward this side" has no meaning without a side.
        excludeFromSemantics: true,
        onTapUp: interactive ? _onTapUp : null,
        onHorizontalDragStart: interactive ? (_) => _asked = null : null,
        onHorizontalDragUpdate: interactive ? _onDrag : null,
        onHorizontalDragEnd: interactive ? (_) => _asked = null : null,
        child: SizedBox(
          width: _hitWidth,
          height: math.max(kGlassPageControlHeight, kGlassMinTapTarget.height),
          child: Center(
            child: SizedBox(
              width: g.width,
              height: kGlassPageControlHeight,
              child: GlassSurface(
                borderRadius: kGlassCapsule,
                finish: widget.finish,
                child: CustomPaint(
                  painter: _DotsPainter(
                    geometry: g,
                    position: () => _position,
                    colour: label,
                    repaint: _driver,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the dots are on a capsule of [count] at a position. Pure, so the
/// gestures and the paint agree.
@immutable
class _DotGeometry {
  const _DotGeometry(this.count, this.current);

  final int count;
  final double current;

  /// The capsule's width: every dot round but one, which is [current] wide —
  /// at every position, since between two pages the two widths trade.
  double get width => 2 * _kPadding + (count - 1) * (kGlassPageDot + kGlassPageDotGap) + current;

  /// How far dot [i] is lit at [position]: 1 on its page, 0 a page away.
  static double litAt(int i, double position) => (1 - (i - position).abs()).clamp(0.0, 1.0);

  double dotWidth(int i, double position) => lerpDouble(kGlassPageDot, current, litAt(i, position))!;

  /// The centre of dot [i] at [position], from the capsule's left edge.
  double centreOf(double position, int i) {
    var x = _kPadding;
    for (var j = 0; j < i; j++) {
      x += dotWidth(j, position) + kGlassPageDotGap;
    }
    return x + dotWidth(i, position) / 2;
  }

  /// The dot whose centre is nearest [x], from the capsule's left edge, with
  /// the dots laid out for [position].
  int indexAt(double x, double position) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < count; i++) {
      final double d = (centreOf(position, i) - x).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.geometry, required this.position, required this.colour, required Listenable repaint})
    : super(repaint: repaint);

  final _DotGeometry geometry;
  final double Function() position;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final double p = position().clamp(0.0, geometry.count - 1.0);
    final double y = size.height / 2;
    var x = _kPadding;
    for (var i = 0; i < geometry.count; i++) {
      final double lit = _DotGeometry.litAt(i, p);
      final double w = geometry.dotWidth(i, p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y - kGlassPageDot / 2, w, kGlassPageDot),
          const Radius.circular(kGlassPageDot / 2),
        ),
        Paint()..color = colour.withValues(alpha: colour.a * lerpDouble(_kRestingDot, 1, lit)!),
      );
      x += w + kGlassPageDotGap;
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) =>
      oldDelegate.geometry.count != geometry.count ||
      oldDelegate.geometry.current != geometry.current ||
      oldDelegate.colour != colour;
}
