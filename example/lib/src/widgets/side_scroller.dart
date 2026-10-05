import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import 'site_icon.dart';

/// A row that scrolls sideways, and says so with a mouse as well as a finger.
///
/// A bare horizontal `ListView` on the web scrolls under a finger and a
/// trackpad and does nothing under a mouse: Flutter's default behaviour drags
/// only with touch, a wheel turns vertically, and the scrollbar shows only
/// while it moves. Here:
///
/// - a mouse drags it, as a finger does;
/// - the scrollbar shows under it while the pointer is over the row, and can
///   be dragged;
/// - a round button at each end, shown while there is more that way, moves it
///   by most of a screenful;
/// - Shift and the wheel scroll it, as everywhere on the web.
class SideScroller extends StatefulWidget {
  const SideScroller({
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.spacing = 12,
    this.arrows = true,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// The height of the items. The scrollbar takes [kSideScrollbarGap] more
  /// under them.
  final double height;

  final double spacing;

  /// Whether the ends' buttons are shown at all. Off on a phone, where the
  /// row is swiped and the buttons would cover the cards.
  final bool arrows;

  @override
  State<SideScroller> createState() => _SideScrollerState();
}

/// The room under the items for the scrollbar.
const double kSideScrollbarGap = 14;

/// The room above the items for one that lifts on hover.
const double _kLift = 4;

class _SideScrollerState extends State<SideScroller> {
  final ScrollController _controller = ScrollController();
  bool _hover = false;
  bool _back = false;
  bool _forward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_measure);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure() {
    if (!_controller.hasClients) {
      return;
    }
    final ScrollPosition p = _controller.position;
    final bool back = p.pixels > p.minScrollExtent + 1;
    final bool forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _back || forward != _forward) {
      setState(() {
        _back = back;
        _forward = forward;
      });
    }
  }

  void _step(int direction) {
    final ScrollPosition p = _controller.position;
    final double target = (p.pixels + direction * p.viewportDimension * 0.8).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    _controller.animateTo(target, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = NotificationListener<ScrollMetricsNotification>(
      // The first layout and every resize: the ends' buttons follow the room.
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _measure();
          }
        });
        return false;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: <PointerDeviceKind>{
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: _hover,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            // Clipped to the row, with room above for a card that lifts on
            // hover: unclipped, the row ran on past the page's column to the
            // window's edge.
            padding: const EdgeInsets.only(top: _kLift, bottom: kSideScrollbarGap),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: _kLift + widget.height + kSideScrollbarGap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: list),
            if (widget.arrows) ...<Widget>[
              _end(left: true, shown: _back, onTap: () => _step(-1)),
              _end(left: false, shown: _forward, onTap: () => _step(1)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _end({required bool left, required bool shown, required VoidCallback onTap}) => Positioned(
    // Inside the row, over its first and last card: a stack takes no tap
    // outside its own box, so a button half over the edge was half dead.
    left: left ? 6 : null,
    right: left ? null : 6,
    top: _kLift,
    height: widget.height,
    child: Center(
      child: IgnorePointer(
        ignoring: !shown,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: shown ? 1 : 0,
          child: Tooltip(
            message: left ? 'Back' : 'More',
            child: GlassButton(
              semanticLabel: left ? 'Scroll back' : 'Scroll for more',
              padding: const EdgeInsets.all(8),
              minSize: const Size.square(40),
              onPressed: onTap,
              child: SiteIcon(left ? SFIcons.sf_chevron_left : SFIcons.sf_chevron_right, size: 18),
            ),
          ),
        ),
      ),
    ),
  );
}
