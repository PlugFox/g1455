// Level 3 of the three-level structure (research SS7.2): components over the
// primitive, the way `FilledButton` and `Card` sit over `Material`.
//
// **And the first thing building them established is that SS7.2's third level is
// one component with three default sets.** The sketch named
// `GlassButton / GlassBar / GlassCard` as if they were three things; in this
// machine everything that differs between them is the shape, the padding and the
// tap target. The glass is the same glass, the label arithmetic is the same
// arithmetic, and exactly one of the three has behaviour of its own — the
// button, because a press changes the *material* and therefore cannot be a
// layer laid over it. So the body is private, the three names are its presets,
// and this comment is the record rather than three files pretending otherwise.
//
// **What a component adds that `GlassSurface` does not, and it is one thing:
// the label's colour.** A label has to be legible against what is under it, and
// what is under it is not the tint — all three rungs put `mix(backdrop, tint, a)`
// there (D178), so one colour is right at every rung and the only input it needs
// is the declaration the ladder already asks for. That arithmetic lives on
// [GlassFinish.foregroundOver]; what lives here is spending it — and, since
// D204, spending its worst-case twin when nobody has said what is behind the
// glass or the screen is an image, where a mean says nothing about the
// brightest corner ([GlassThemeData.legibility]).
//
// **Three things these deliberately do not do.**
//
//  - **No group.** A blend group is a way to get a picture and not a way to get
//    a price, and there is no count at which it pays for itself: twelve panels
//    declared one group came out at 2.25x stock Material where the same twelve
//    ungrouped were 1.19x (D169). A bar that wrapped its items in one would be
//    charging for a silhouette nobody asked for.
//  - **No repaint boundary between the glass and the content.** Considered and
//    rejected on the numbers rather than on taste: it would keep a content
//    change from re-running the panel's shader, and that shader is 9% of the
//    route's whole addition over the floor (D63) — about 17 000 cycles for a
//    400x60 bar at dpr 3 on D169's per-fragment coefficients, against millions
//    in a frame. A layer per component for an unmeasured saving is exactly what
//    `proxy_role.dart` refuses to sell.
//  - **No safe area.** `SafeArea` exists and an application already has it. A
//    second way to say the same thing is what SS7.3's `GlassId` turned out to be.
//
// **And one number these cannot avoid handing to the application: a component
// is a surface, and surfaces are charged per draw.** The translucency tax
// follows area (D21) with an excess for fragmentation that grows as the square
// of the count (D26, `GlassLoad.fragmentationExcessCycles`), so a bar holding
// five [GlassButton]s is **six** surfaces and thirty-six times one surface's
// excess term. That is not a defect and not forbidden — Apple does put glass
// controls on glass bars — but it is the largest lever left in the package and
// it is decided by whoever writes the tree, so the register counts it.

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'glass_adaptive.dart';
import 'glass_finish.dart';
import 'glass_focus.dart';
import 'glass_host.dart';
import 'glass_press.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// The smallest a control may be, logical px — Apple's Human Interface
/// Guidelines, 44 x 44 pt.
///
/// An external documented constant rather than one of ours, which is why it has
/// a name at all: the padding defaults in this file are layout taste and say so,
/// and this is not.
///
/// Every control in the package — [GlassButton], [GlassSwitch], [GlassSlider],
/// [GlassSegmentedControl], [GlassTabBar], each item of a [GlassButtonGroup],
/// [GlassTextField] and the [GlassSearchBar] built on it with its Cancel,
/// [GlassStepper] and [GlassPageControl] — is at least this tall, whatever it
/// draws.
///
/// {@category Panels and controls}
const Size kGlassMinTapTarget = Size(44, 44);

/// The label of a disabled [GlassButton] whose enabled label is black, and
/// whose enabled label is white.
///
/// iOS 26's glass `UIButton` leaves its glass as it is and draws a disabled
/// title in `tertiaryLabel`: (60, 60, 67) at 0.3 in light, (235, 235, 245) at
/// 0.3 in dark — which predicts the simulator's frames over black, grey and
/// white to 0.004 of full scale (D221). Apple picks between the two by the
/// appearance and stops adapting to the backdrop, so its disabled title over
/// glass of the other polarity is all but invisible. The package has no
/// appearance — the platform brightness was measured the wrong guess (D179) —
/// so it picks by the polarity of the label it would have drawn enabled, which
/// is the same choice wherever Apple's is legible.
///
/// This one is `tertiaryLabel` in light: (60, 60, 67) at 0.3, for a label that
/// would have been dark. [kGlassDisabledLightLabel] is its twin.
///
/// {@category Panels and controls}
const Color kGlassDisabledDarkLabel = Color(0x4D3C3C43);

/// The label of a disabled [GlassButton] whose enabled label is white:
/// `tertiaryLabel` in dark, (235, 235, 245) at 0.3 (D221).
///
/// See [kGlassDisabledDarkLabel] for how the two are chosen between.
///
/// {@category Panels and controls}
const Color kGlassDisabledLightLabel = Color(0x4DEBEBF5);

/// A glass bar: the navigation layer, which is where Apple's guidelines put this
/// material.
///
/// A capsule by default, because that is what a floating bar is in iOS 26 and
/// because SS5.3's rule — Apple uses a pill for controls, never a squircle — is
/// about exactly this shape. See [kGlassCapsule] for how a capsule is declared
/// and what declaring one found.
///
/// One surface, and its items are content rather than glass. Putting
/// [GlassButton]s in it is allowed and costs what the file comment says it
/// costs.
///
/// ```dart
/// GlassBar(
///   child: Row(
///     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
///     children: <Widget>[Icon(Icons.arrow_back), Text('Library'), Icon(Icons.search)],
///   ),
/// )
/// ```
///
/// {@template g1455.glass_label_colour}
/// **The label's colour is the component's, not the child's.** Text and icons
/// in [child] are given, through [DefaultTextStyle] and [IconTheme], the label
/// colour that reads over the glass ([GlassFinish.foregroundOver]): against
/// [GlassThemeData.backdrop] when the screen behind is declared and flat, and
/// against every backdrop — the worst case, [GlassFinish.foregroundOverAny] —
/// when it is undeclared or [GlassThemeData.richBackdrop] says it is an image
/// ([GlassThemeData.legibility]). A colour the child sets on itself wins. In
/// debug, a finish whose best label is under WCAG AA over that worst case is
/// reported once per process.
/// {@endtemplate}
///
/// See also:
///
///  * [GlassButton], the same panel with a press, for a control inside or
///    beside a bar.
///  * [GlassButtonGroup], a row of actions as one surface, cheaper than
///    several [GlassButton]s on a bar.
///  * [GlassScaffold], which lays a bar out over a scrolling body.
///  * [Bar on the site](https://g1455.plugfox.dev/components/bar).
///
/// {@category Panels and controls}
class GlassBar extends StatelessWidget {
  /// A bar around [child]: a capsule with 16 x 8 of padding, in the theme's
  /// finish unless [finish] names one.
  const GlassBar({
    required this.child,
    this.borderRadius = kGlassCapsule,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.finish,
    super.key,
  });

  /// The corner radii. [kGlassCapsule] by default.
  final BorderRadius borderRadius;

  /// Space between the glass and the items.
  ///
  /// **Layout taste, not a measurement**, and named as such wherever it appears
  /// in this file: S4 read Apple's *material* — its transmission, its blur, its
  /// rim — and no metric of its metrics. A number here dressed as a calibration
  /// would be the one kind of constant this project does not allow.
  final EdgeInsets padding;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// The bar's items, laid out inside [padding] and drawn in the label colour.
  final Widget child;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    borderRadius: borderRadius,
    padding: padding,
    finish: finish,
    child: child,
  );
}

/// A glass card: the same panel as [GlassBar] with a corner instead of a
/// capsule.
///
/// **The same body and different advice, and the advice is Apple's own:** the
/// HIG puts Liquid Glass in the navigation and functional layers and keeps it
/// out of the content layer, and a card is the content layer. The package has no
/// way to detect which layer it is in — the same shape of gap as the ladder's
/// (D175) — so this is a component with a warning rather than a refusal.
///
/// The measured half of the warning points the same way. A card is the widget
/// that multiplies: the translucency tax follows area (D21) and the
/// fragmentation excess grows as the square of the surface count (D26), so a
/// list of glass cards walks up the only large lever the package has left. The
/// register says so — `GlassLedger.read` returns the count, the area and a
/// verdict — and a screen of these is what it is for.
///
/// ```dart
/// GlassCard(
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     mainAxisSize: MainAxisSize.min,
///     children: <Widget>[
///       Text('Now playing', style: TextStyle(fontWeight: FontWeight.w600)),
///       SizedBox(height: 8),
///       Text('Side A, track 3'),
///     ],
///   ),
/// )
/// ```
///
/// {@macro g1455.glass_label_colour}
///
/// See also:
///
///  * [GlassBar], the same panel as a capsule, for the navigation layer.
///  * [GlassSurface], the primitive underneath, for a shape the presets do
///    not cover.
///  * [GlassLedger], which counts what a screen of cards costs.
///  * [Card on the site](https://g1455.plugfox.dev/components/card).
///
/// {@category Panels and controls}
class GlassCard extends StatelessWidget {
  /// A card around [child]: corners of 24 and 16 of padding, in the theme's
  /// finish unless [finish] names one.
  const GlassCard({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = const EdgeInsets.all(16),
    this.finish,
    super.key,
  });

  /// The corner radii. 24 by default, which is [GlassSurface]'s own default and
  /// the middle of the range the reference material was read at.
  final BorderRadius borderRadius;

  /// Space between the glass and the content. Layout taste — see
  /// [GlassBar.padding].
  final EdgeInsets padding;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// The card's content, laid out inside [padding] and drawn in the label
  /// colour.
  final Widget child;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    borderRadius: borderRadius,
    padding: padding,
    finish: finish,
    child: child,
  );
}

/// A glass control: a capsule that takes a tap and brightens while held.
///
/// The one component of the three with behaviour rather than defaults, and the
/// reason is the press: **Apple's glass brightens while it is held, which means
/// the material changes rather than something being laid over it.** So the
/// overlay is drawn onto the surface's own canvas with [BlendMode.plus], and the
/// press therefore re-runs the panel's shader — which is named rather than
/// avoided: the shader is 9% of the route's addition over the floor (D63) and a
/// control is one small panel.
///
/// **`plus` is scoped by a `saveLayer` and by nothing else.** A
/// `RepaintBoundary` does not open one — it lowers to
/// `SceneBuilder.pushOffset`, and that engine layer paints its children onto the
/// same canvas — so the overlay reaches the glass through one; an [Opacity], a
/// `ColorFilter` or an `ImageFilter` between the two does open one, and then the
/// press adds to transparency and comes out wrong. Both halves of that were
/// measured, one of them by a break that failed to break (D185).
///
/// **What it brightens by is the rim's own measured amount and nothing new.**
/// [pressedOverlay] defaults to the finish's [GlassFinish.rim] — 50.2 code
/// values of neutral white, fitted across seven rims of two Apple materials
/// (D86-D88) — spent over the whole shape instead of along its edge. Apple's own
/// press step was never measured here (S4 captured static bands), so a fraction
/// of this would be a guess where this is at least a quantity somebody read off
/// the reference. Pass your own to disagree.
///
/// **And it swells.** While held the glass grows by [GlassPress.grow] and
/// leans toward a finger that drags ([press], [GlassThemeData.press]) — inside
/// a travel region of its own and behind a boundary of its own, so the press
/// costs two captures — the region declared at touch-down and let go at the
/// settle — and repaints nothing but the glass. The button's layout
/// is its resting box throughout; the glass is drawn past it.
///
/// A keyboard reaches it: it takes the focus, Space or Enter presses it, and
/// while the focus is shown a ring ([kGlassFocusRingColor]) is drawn around
/// the glass from inside its own subtree — which no capture sees.
///
/// The tap target is [kGlassMinTapTarget] at the smallest, and the whole capsule
/// takes the tap rather than only where the label is: the gesture handler is
/// outside the surface and opaque, because a [GlassSurface] is a
/// `RenderProxyBox` and hit-tests only its child.
///
/// ```dart
/// GlassButton(
///   onPressed: () => Navigator.of(context).maybePop(),
///   semanticLabel: 'Back',
///   child: const Icon(Icons.arrow_back),
/// )
/// ```
///
/// {@macro g1455.glass_label_colour}
///
/// Disabled ([onPressed] null), the glass is left as it is and the label dims
/// to [kGlassDisabledDarkLabel] or [kGlassDisabledLightLabel].
///
/// See also:
///
///  * [GlassButtonGroup], several actions in one capsule and one surface.
///  * [GlassBar] and [GlassCard], the same panel without a press.
///  * [kGlassMinTapTarget], the smallest the button is laid out.
///  * [Button on the site](https://g1455.plugfox.dev/components/button).
///
/// {@category Panels and controls}
class GlassButton extends StatefulWidget {
  /// A button around [child], which is centred in a capsule at least
  /// [minSize] large. Disabled until [onPressed] is given.
  const GlassButton({
    required this.child,
    this.onPressed,
    this.borderRadius = kGlassCapsule,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.minSize = kGlassMinTapTarget,
    this.pressedOverlay,
    this.press,
    this.finish,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Called on a tap. Null disables the control, which is also what the
  /// semantics say: the glass stays as it is and the label dims to
  /// [kGlassDisabledDarkLabel] or [kGlassDisabledLightLabel].
  final VoidCallback? onPressed;

  /// The corner radii. [kGlassCapsule] by default.
  final BorderRadius borderRadius;

  /// Space between the glass and the label. Layout taste — see
  /// [GlassBar.padding].
  final EdgeInsets padding;

  /// The smallest the control may be. [kGlassMinTapTarget] by default.
  final Size minSize;

  /// What is added over the whole shape while the control is held.
  ///
  /// Null takes the finish's rim, which is the only additive quantity in this
  /// package that was measured rather than chosen. `Color(0x00000000)` is a
  /// control that draws nothing.
  final Color? pressedOverlay;

  /// How the glass swells and leans while held. Null takes
  /// [GlassThemeData.press]; [GlassPress.none] keeps the button its size and
  /// builds no travel region for it. Off under reduced motion either way.
  final GlassPress? press;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  /// The button's focus. Null makes one the button owns.
  final FocusNode? focusNode;

  /// Whether the button takes the focus as soon as it is built.
  final bool autofocus;

  /// What a screen reader says in place of [child] — for a button that is
  /// only an icon, which says nothing. Null lets [child]'s own semantics speak.
  final String? semanticLabel;

  /// The label — a [Text], an [Icon], or both in a row — centred in the
  /// capsule and drawn in the label colour.
  final Widget child;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with TickerProviderStateMixin {
  bool _held = false;
  bool _focused = false;

  /// 0 at rest, 1 held — on a spring, so past either end for a moment.
  late final AnimationController _press = AnimationController.unbounded(vsync: this);

  /// What the finger's drag is scaled by: 1 while held, sprung to 0 after.
  late final AnimationController _release = AnimationController.unbounded(vsync: this, value: 1);

  /// The finger from where it came down, while it is down.
  final ValueNotifier<Offset> _finger = ValueNotifier<Offset>(Offset.zero);
  Offset? _downAt;
  int? _pointer;

  GlassPress _spec = GlassPress.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spec = GlassPress.resolve(context, widget.press);
  }

  @override
  void didUpdateWidget(GlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _spec = GlassPress.resolve(context, widget.press);
    // Disabled under a finger: the framework cancels the tap from inside the
    // build that removed the handlers, through the `onTapCancel` it was built
    // with, and a `setState` there is one during build. Let go first and that
    // cancel finds nothing to do (D221).
    if (widget.onPressed == null) {
      _held = false;
      _press.value = 0;
      _release.value = 0;
      _pointer = null;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _release.dispose();
    _finger.dispose();
    super.dispose();
  }

  void _spring(AnimationController c, double to) {
    final GlassPress spec = _spec;
    c
        .animateWith(
          SpringSimulation(
            SpringDescription(mass: 1, stiffness: spec.stiffness, damping: spec.damping),
            c.value,
            to,
            c.velocity,
            tolerance: const Tolerance(distance: 1e-3, velocity: 1e-2),
          ),
        )
        // The spring settles within its tolerance, not on the target: a glass
        // left a thousandth larger than its rest would be a box that never
        // returns, and a region that differs from the one captured.
        .then((_) => c.value = to);
  }

  void _setHeld(bool value) {
    if (_held == value) {
      return;
    }
    setState(() => _held = value);
    if (_spec.isNone) {
      return;
    }
    if (value) {
      _release
        ..stop()
        ..value = 1;
      _spring(_press, 1);
    } else {
      _spring(_press, 0);
      _spring(_release, 0);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) {
      return;
    }
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _finger.value = Offset.zero;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final Offset? at = _downAt;
    // Only while held: a finger that a scroll took is not pressing anything.
    if (e.pointer != _pointer || at == null || !_held) {
      return;
    }
    _finger.value = e.localPosition - at;
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer == _pointer) {
      _pointer = null;
      _downAt = null;
    }
  }

  void _activate() {
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final GlassFinish finish = widget.finish ?? GlassTheme.of(context).finish;
    final Color overlay = widget.pressedOverlay ?? finish.rim;
    final bool enabled = widget.onPressed != null;
    Widget glass = _GlassPanel(
      borderRadius: widget.borderRadius,
      padding: widget.padding,
      finish: widget.finish,
      overlay: _held ? overlay : null,
      focusRing: _focused && enabled,
      enabled: enabled,
      // Factors of one: centred inside the minimum size, and no larger
      // than the label otherwise. A bare `Center` takes every pixel it is
      // offered, so a button in a `Wrap` or a `Column` was a bar.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        // A label is not text to select: a drag across a page that
        // selects would otherwise take it along.
        child: SelectionContainer.disabled(
          child: ExcludeSemantics(excluding: widget.semanticLabel != null, child: widget.child),
        ),
      ),
    );
    // Only while it can be pressed: a disabled button takes no press, and
    // pays for no region.
    if (enabled && !_spec.isNone) {
      final GlassPress spec = _spec;
      glass = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_press, _release, _finger]),
        child: glass,
        builder: (BuildContext context, Widget? panel) => GlassPressStage(
          press: spec,
          value: _press.value,
          finger: _finger.value * _release.value,
          // From touch-down until the spring has settled: at rest the glass is
          // its box, and its slot no larger.
          active:
              _held ||
              _press.isAnimating ||
              _release.isAnimating ||
              _press.value != 0 ||
              _finger.value * _release.value != Offset.zero,
          child: panel!,
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (bool on) => setState(() => _focused = on),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate()),
        },
        child: Listener(
          onPointerDown: enabled ? _onPointerDown : null,
          onPointerMove: enabled ? _onPointerMove : null,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: GestureDetector(
            // Opaque, so the whole capsule takes the tap and not only the part the
            // label covers. Outside the surface for the same reason.
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setHeld(true) : null,
            onTapUp: enabled ? (_) => _setHeld(false) : null,
            onTapCancel: enabled ? () => _setHeld(false) : null,
            onTap: widget.onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.minSize.width,
                minHeight: widget.minSize.height,
              ),
              child: glass,
            ),
          ),
        ),
      ),
    );
  }
}

/// The body all three components are presets of.
class _GlassPanel extends StatefulWidget {
  const _GlassPanel({
    required this.borderRadius,
    required this.padding,
    required this.finish,
    required this.child,
    this.overlay,
    this.focusRing = false,
    this.enabled = true,
  });

  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final GlassFinish? finish;
  final Color? overlay;

  /// Whether the keyboard's focus ring is drawn around the glass — from here,
  /// inside the surface's subtree, where no capture sees it.
  final bool focusRing;
  final bool enabled;
  final Widget child;

  @override
  State<_GlassPanel> createState() => _GlassPanelState();
}

/// The panel's one piece of state: what its glass read of the backdrop, when
/// the host reads it (`GlassHost.adaptive`), and the move between two readings.
///
/// Off, none of it runs: no listener, no controller, no ticker — the build is
/// the one it always was, under an inner [GlassTheme] equal to the outer one.
/// That theme is there either way so that turning the reading on or off keeps
/// the tree's shape, and with it the state of whatever the panel holds.
class _GlassPanelState extends State<_GlassPanel> with SingleTickerProviderStateMixin {
  GlassBackdropReadings? _readings;

  /// This glass's verdict, or null before it has one.
  GlassBackdropReading? _reading;

  /// The move between two verdicts, made the first time there is one to make.
  AnimationController? _move;

  /// The finish, before any dim, that was drawn when the verdict last moved —
  /// where the move starts.
  GlassFinish? _from;

  /// The finish, before any dim, that the last build drew, mid-move included.
  GlassFinish? _shown;

  /// What the last build read of the motion it may make: the reading's
  /// [GlassAdaptive.duration], and whether the platform asks for none.
  bool _reduceMotion = false;
  Duration _duration = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final GlassBackdropReadings? readings = GlassTheme.of(context).adaptive == null
        ? null
        : GlassProxyScope.maybeOf(context)?.readings;
    if (identical(readings, _readings)) {
      return;
    }
    _readings?.removeListener(_onReadings);
    _readings = readings;
    if (readings == null) {
      _reading = null;
      _from = null;
      _move?.stop();
    } else {
      readings.addListener(_onReadings);
      _reading = _readingOfGlass();
    }
  }

  @override
  void dispose() {
    _readings?.removeListener(_onReadings);
    _move?.dispose();
    super.dispose();
  }

  /// The verdict for this panel's own glass: the render object the panel
  /// builds first is its [RenderGlassSurface], and that is what the host keys
  /// the verdicts by. Asked when the verdicts move or the theme turns the
  /// reading on, never from [build], where the answer could be a frame old.
  GlassBackdropReading? _readingOfGlass() {
    final RenderObject? glass = context.findRenderObject();
    return glass is RenderGlassSurface ? _readings?.of(glass) : null;
  }

  void _onReadings() {
    final GlassBackdropReading? reading = _readingOfGlass();
    if (reading == _reading) {
      return;
    }
    setState(() {
      _reading = reading;
      final GlassFinish? shown = _shown;
      final Duration duration = _duration;
      if (shown == null || _reduceMotion || duration == Duration.zero) {
        _from = null;
        _move?.stop();
        return;
      }
      _from = shown;
      final AnimationController move = _move ??= AnimationController(vsync: this)..addListener(() => setState(() {}));
      move
        ..duration = duration
        ..forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlassThemeData outer = GlassTheme.of(context);
    final GlassAdaptive? adaptive = outer.adaptive;
    if (adaptive != null) {
      _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _duration = adaptive.duration;
    }
    final GlassBackdropReading? reading = adaptive == null ? null : _reading;
    final GlassThemeData theme = reading == null ? outer : outer.adaptedTo(reading);
    final GlassFinish target = widget.finish ?? theme.finish;
    // Mid-move, the glass draws the finish between where it was and where it
    // is going, and the floor is met by that finish, not by either end: two
    // ends that each reach it can pass through a level that no lerped label
    // reads on (a grey label on grey glass, halfway from dark to light). So
    // the in-between finish is resolved like any other — dimmed as far as it
    // needs, with the label that reads on it — and handed to the surface as
    // its own, kept from the floor's second dim.
    final GlassFinish? from = _from;
    final AnimationController? move = _move;
    final double t = from == null || move == null || !move.isAnimating ? 1 : Curves.easeInOut.transform(move.value);
    final bool moving = from != null && t < 1;
    final GlassFinish drawn = moving ? GlassFinish.lerp(from, target, t) : target;
    final GlassLegibility shown = theme.legibility(drawn);
    _shown = drawn;
    return GlassTheme(
      data: theme,
      child: GlassSurface(
        borderRadius: widget.borderRadius,
        finish: moving ? shown.finish : widget.finish,
        labelled: !moving,
        child: CustomPaint(
          // Nothing between this and the glass that would open a `saveLayer`, and
          // that is the whole requirement: `plus` adds to whatever is already on
          // the canvas it is recorded on, and a `saveLayer` above it would make
          // that transparency instead of the glass. A `RepaintBoundary` is **not**
          // one — it lowers to `SceneBuilder.pushOffset`, whose engine layer
          // paints its children onto the same canvas — so one here changes
          // nothing, which is measured rather than assumed (the break that failed
          // to break, D185). An `Opacity`, a `ColorFilter` or an `ImageFilter`
          // does open one, and then the press adds to nothing; that is a hazard
          // for whoever wraps a control, and it is why this sits directly over the
          // surface rather than under anything convenient.
          painter: widget.overlay == null && !widget.focusRing
              ? null
              : _GlassOverlay(widget.borderRadius, widget.overlay, focusRing: widget.focusRing),
          child: Padding(
            padding: widget.padding,
            child: _labelled(theme, shown, widget.child),
          ),
        ),
      ),
    );
  }

  /// Sets the label colour from the level the glass shows.
  ///
  /// Against the declared backdrop when it is flat, and against **every**
  /// backdrop when it is rich or undeclared ([GlassThemeData.legibility]). The
  /// second case used to leave the colour alone (D184), because the two
  /// available guesses — the tint, and the platform brightness — were both
  /// measured wrong (D179). The worst case is not a third guess: it is a bound
  /// that needs nothing but the finish, and on [GlassFinish.regularDark] it is
  /// white at 6.05, AA over any image there is (D204). What remains worth
  /// saying is when even the bound is below AA — a light, thin finish over an
  /// undeclared screen — and that is what the report says now.
  ///
  /// Under a host that reads its backdrop the reading is a third way, and not
  /// a guess either: it stands in for the declared backdrop for this glass
  /// alone ([GlassThemeData.adaptedTo]). Nothing is reported there — the label
  /// is about to be chosen against a measurement, on the frame after the first
  /// capture, and a complaint about the two frames before it would be noise.
  Widget _labelled(GlassThemeData theme, GlassLegibility legibility, Widget child) {
    if (theme.adaptive == null &&
        theme.backdrop == null &&
        !theme.richBackdrop &&
        legibility.finish.worstContrast(legibility.label) < kTextContrastAA) {
      _reportIllegible(legibility.finish.worstContrast(legibility.label));
    }
    final Color foreground = widget.enabled
        ? legibility.label
        : legibility.label.computeLuminance() < 0.5
        ? kGlassDisabledDarkLabel
        : kGlassDisabledLightLabel;
    return IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: child,
      ),
    );
  }
}

/// Said once per process, not once per frame: the condition is a property of the
/// tree, and this runs in every build of every component.
bool _warnedIllegible = false;

/// Re-arms the report above.
///
/// A once-per-process complaint is unobservable to the second test that wants to
/// see it, and a report nothing can read is the same as no report. Debug-shaped
/// rather than public: `assert` strips the complaint in profile anyway.
@visibleForTesting
void debugResetGlassBackdropReport() => _warnedIllegible = false;

void _reportIllegible(double worst) {
  assert(() {
    if (_warnedIllegible) {
      return true;
    }
    _warnedIllegible = true;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError(
          'A glass component has no GlassThemeData.backdrop, and its finish is '
          'not legible over every backdrop: the best label reaches a contrast of '
          '${worst.toStringAsFixed(2)} in the worst case, under WCAG AA (4.5).\n'
          'The label was chosen against every backdrop because nothing said which '
          'one is behind the glass (D204). Declare the screen background on '
          'GlassHost or GlassTheme if it is flat — then the label is chosen '
          'against it — or set richBackdrop and minLabelContrast if it is an '
          'image, and the glass is dimmed until the label reaches the floor.',
        ),
        library: 'glass',
        context: ErrorDescription('while building a glass component'),
      ),
    );
    return true;
  }());
}

/// Adds a colour over the whole shape, in the layer it is recorded in — and
/// draws the focus ring around it.
class _GlassOverlay extends CustomPainter {
  const _GlassOverlay(this.borderRadius, this.color, {this.focusRing = false});

  final BorderRadius borderRadius;
  final Color? color;
  final bool focusRing;

  @override
  void paint(Canvas canvas, Size size) {
    final Color? color = this.color;
    if (focusRing) {
      // Past the shape, and drawn here — on the surface's own canvas — so the
      // capture, which skips this subtree, never holds it.
      paintGlassFocusRing(canvas, Offset.zero & size, borderRadius);
    }
    if (color == null || color.a <= 0) {
      return;
    }
    canvas.drawRSuperellipse(
      // `scaleRadii` for the same reason `RenderGlassSurface.shapeAt` does it:
      // a capsule is declared as a radius larger than the box, and the overlay
      // has to be the shape the glass under it is.
      borderRadius.toRSuperellipse(Offset.zero & size).scaleRadii(),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_GlassOverlay oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius || oldDelegate.focusRing != focusRing;
}
