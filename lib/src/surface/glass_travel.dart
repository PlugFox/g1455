// Where a moving surface may go, declared so that its motion costs no capture.
//
// A proxy lives in the screen's coordinates, and a surface maps its *current*
// place into its slot on every paint — so a surface that moved over content
// that did not is already drawn correctly from the old proxy, provided the slot
// holds what it now covers. What stopped that from being free was the capture
// itself: a slot is its surface's box plus the bleed, so any move leaves it,
// and the oracle retook on every frame a surface moved (`noteSurfaces`).
//
// The fix is a declaration rather than a heuristic, because the one thing the
// package cannot see is where a surface is *going*. A switch's knob travels its
// track, a tab bar's lens travels the bar, a droplet a sheet — the component
// knows the region and says so; the host captures the region instead of the
// box, and while the surface stays inside it the capture input does not change
// and nothing is retaken. A surface that leaves it changes the input and is
// captured again, so the declaration is a price and never a correctness claim.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The region the surfaces below may move within, as something they can ask.
///
/// Owned by [GlassTravel]'s state for the reason [GlassBlendGroup] is: the
/// surfaces find it while they are being built, where no render object is
/// reachable.
///
/// Made by [GlassTravel] and found through [GlassTravelScope.maybeOf]; an
/// application does not make one.
///
/// {@category Composition}
class GlassTravelRegion {
  RenderGlassTravel? _box;

  /// Where the region is now, in global logical pixels, or null when it cannot
  /// say — which the surface reads as "no declaration".
  ///
  /// Read at the moment of asking, like every other geometry in the register:
  /// a region inside a scrolled list moves without repainting.
  Rect? get globalRect {
    final RenderGlassTravel? box = _box;
    if (box == null || !box.attached || !box.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
  }
}

/// Declares that the glass below may move anywhere inside this widget's box,
/// and asks the host to capture the whole box for it.
///
/// **What it buys:** a surface moving over still content inside the region is
/// drawn from the proxy already held — no capture, no repack. **What it
/// costs:** the slot is the region rather than the surface, so the atlas holds
/// more screen. Worth it for a control whose glass moves while a finger is
/// down; not for a panel that sits still.
///
/// Motion is free only if moving the glass repaints nothing else: the proxy is
/// also retaken when content under it changes, and a repaint mints a new
/// picture in whichever repaint boundary owns it. So the moving surface's
/// parent should paint nothing of its own — the content it moves over belongs
/// behind a `RepaintBoundary` of its own, which is what the package's own
/// components do.
///
/// A surface that leaves the region is captured again, so the declaration is
/// a price and never a correctness claim: a region drawn too small costs
/// captures, never a wrong picture.
///
/// ```dart
/// GlassTravel(
///   child: SizedBox(
///     width: 320,
///     height: 64,
///     child: Stack(
///       children: <Widget>[
///         const Positioned.fill(child: RepaintBoundary(child: Track())), // still content
///         AnimatedPositioned(
///           duration: const Duration(milliseconds: 200),
///           left: knobX,
///           top: 8,
///           width: 48,
///           height: 48,
///           child: const GlassSurface(borderRadius: kGlassCapsule),
///         ),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// See also:
///
///  * [GlassSlider], [GlassSwitch] and [GlassTabBar], whose drops move inside
///    one.
///  * [GlassMorph], which can move inside one around a fixed-size ancestor.
///  * [Travel on the site](https://g1455.plugfox.dev/foundations/travel).
///
/// {@category Composition}
class GlassTravel extends StatefulWidget {
  /// Declares [child]'s box as the region the glass inside it moves within.
  const GlassTravel({required this.child, super.key});

  /// The subtree whose glass moves; the region is this child's box.
  final Widget child;

  @override
  State<GlassTravel> createState() => _GlassTravelState();
}

class _GlassTravelState extends State<GlassTravel> {
  final GlassTravelRegion _region = GlassTravelRegion();

  @override
  Widget build(BuildContext context) => _GlassTravelBox(
    region: _region,
    child: GlassTravelScope(region: _region, child: widget.child),
  );
}

/// Carries the region down to the surfaces inside it. Never notifies: the
/// region's identity is fixed and its geometry is read when asked.
///
/// Put in the tree by [GlassTravel]; a custom glass control reads it.
///
/// {@category Composition}
class GlassTravelScope extends InheritedWidget {
  /// Makes [region] the travel region of the surfaces in [child].
  const GlassTravelScope({required this.region, required super.child, super.key});

  /// The region the surfaces below may move within.
  final GlassTravelRegion region;

  /// The region of the nearest [GlassTravel] above [context], or null when
  /// there is none.
  static GlassTravelRegion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassTravelScope>()?.region;

  @override
  bool updateShouldNotify(GlassTravelScope oldWidget) => !identical(region, oldWidget.region);
}

class _GlassTravelBox extends SingleChildRenderObjectWidget {
  const _GlassTravelBox({required this.region, required Widget super.child});

  final GlassTravelRegion region;

  @override
  RenderGlassTravel createRenderObject(BuildContext context) => RenderGlassTravel(region);

  @override
  void updateRenderObject(BuildContext context, RenderGlassTravel renderObject) {
    renderObject.region = region;
  }
}

/// The box behind [GlassTravel]. Transparent to layout, paint and hit testing.
///
/// {@category Composition}
class RenderGlassTravel extends RenderProxyBox {
  /// The box that answers for [GlassTravelRegion.globalRect] while it is
  /// attached.
  RenderGlassTravel(this._region);

  GlassTravelRegion _region;

  /// The region this box answers for. Setting another hands the old one back
  /// to "no declaration".
  set region(GlassTravelRegion value) {
    if (identical(value, _region)) {
      return;
    }
    if (identical(_region._box, this)) {
      _region._box = null;
    }
    _region = value;
    if (attached) {
      _region._box = this;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _region._box = this;
  }

  @override
  void detach() {
    if (identical(_region._box, this)) {
      _region._box = null;
    }
    super.detach();
  }
}
