// The modal layer: an alert, a sheet, a menu.
//
// What was read off Apple's own (iOS 26.5, iPhone 17 Pro, each put up
// programmatically over a grid and photographed against the bare grid):
//
//  - **the dim** behind an alert and behind a sheet is the same: black at
//    0.20 (0.201–0.203 over three channels, solved from the grid's two
//    levels);
//  - **the alert** is 320 pt wide, its corner a continuous one of 34 pt
//    (`layer.cornerRadius`), its text 30 pt in from its sides and its title
//    22 pt below its top; two actions sit side by side as 48 pt capsules 8 pt
//    apart, 16 pt in from the sides and the bottom;
//  - **the sheet** at the medium detent floats 8 pt in from the screen's
//    sides and bottom, its corner the engine's `RSuperellipse` of 36 pt (a
//    superellipse of exponent 3 and 51 pt reach, fitted at 0.54 device px
//    rms), with a grabber at its top.
//
// The large detent was not read: Apple says only that a sheet at full height
// loses its inset and "transitions to a more opaque appearance". Taken here
// as far as it goes — opaque — because that is the one place on this layer a
// glass can stop reading its backdrop without changing what it shows.
//
// Not read, and named where it is used: the alert's action fill, the menu's
// size and radius, and every animation. The glass of all three is the theme's
// finish — Apple's material was measured once, and a modal is the same
// material.
//
// **Where these must be built.** A glass surface is captured by the
// `GlassHost` above it, and an overlay is wherever its `Overlay` is — for
// `showGlassDialog` and `showGlassSheet` the navigator's, for a menu the
// nearest one. So the host has to be above the navigator, which in a
// `WidgetsApp` / `MaterialApp` is `builder:`. Built anywhere else they find no
// host, and say so in debug rather than drawing glass that samples nothing.
//
// **Each is lifted** ([GlassAbove], [kGlassModalLift]): a dialog over a page
// with glass bars has to show the bars, and bars over glass cards are
// themselves a level above the cards. Over a page with no glass, the lift
// costs nothing — the host numbers only the levels that are occupied.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'glass_above.dart';
import 'glass_finish.dart';
import 'glass_host.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';
import 'glass_tier.dart';
import 'glass_travel.dart';

/// The dim behind an alert and a sheet: black at 0.20, read off
/// iOS 26.5 over a grid of two known levels.
///
/// A menu and a popover put up no dim; their barrier is transparent.
///
/// {@category Modals}
const Color kGlassModalDim = Color.fromRGBO(0, 0, 0, 0.20);

/// The alert's width, logical px, as iOS 26.5 draws it.
///
/// On a window narrower than this plus 16 px a side, [GlassAlert] takes the
/// window's width less those margins instead.
///
/// {@category Modals}
const double kGlassAlertWidth = 320;

/// The alert's corner radius, logical px (iOS 26.5's `layer.cornerRadius`, a
/// continuous corner).
///
/// {@category Modals}
const double kGlassAlertRadius = 34;

/// How far the sheet stands in from the window's sides and bottom, and below
/// the top safe area, logical px (iOS 26.5, the medium detent).
///
/// {@category Modals}
const double kGlassSheetInset = 8;

/// The sheet's corner radius, logical px (iOS 26.5; the engine's
/// `RSuperellipse` of 36, fitted at 0.54 device px rms).
///
/// {@category Modals}
const double kGlassSheetRadius = 36;

/// iOS's `systemFill`, (120, 120, 128) at 0.20 — the alert's action capsules
/// look like it and were not measured: they lie on the alert's own glass, and
/// one backdrop cannot separate a fill from the material under it.
const Color _kActionFill = Color.fromRGBO(120, 120, 128, 0.20);

/// Says, in debug, when a modal was built outside any `GlassHost`.
void _assertHosted(BuildContext context, String what) {
  assert(() {
    if (GlassProxyScope.maybeOf(context) == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('$what was built with no GlassHost above it.'),
        ErrorDescription(
          'A glass surface is captured by the GlassHost above it, and a modal is built in '
          'the Overlay it is shown in — for a dialog or a sheet the navigator\'s.',
        ),
        ErrorHint(
          'Put the GlassHost above the navigator: WidgetsApp / MaterialApp(builder: '
          '(context, child) => GlassHost(child: child!)).',
        ),
      ]);
    }
    return true;
  }());
}

/// The text style, icon theme and app themes in force where a dialog or a
/// sheet was asked for, carried to the navigator's overlay it is built in —
/// as `showDialog` does. Without them the route's content inherits what
/// stands above the navigator, which in a `MaterialApp` is its error style:
/// red, monospace, underlined in yellow. The glass's own scopes are not
/// `InheritedTheme`s, so a page's group or level is not carried with them.
CapturedThemes _capture(BuildContext context, NavigatorState navigator) =>
    InheritedTheme.capture(from: context, to: navigator.context);

/// Wraps a modal's glass: lifted, and materializing with [progress] —
/// Apple's `.materialize`, blur first and tint last, the content fading
/// in on top.
class _Materializing extends StatelessWidget {
  const _Materializing({required this.progress, required this.builder});

  final Animation<double> progress;
  final Widget Function(BuildContext context, double t) builder;

  @override
  Widget build(BuildContext context) => GlassAbove(
    lift: kGlassModalLift,
    child: AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? _) => builder(context, progress.value.clamp(0.0, 1.0)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Alert

/// One button of a [GlassAlert].
///
/// Two actions sit side by side as capsules; one, or three and more, stack
/// one above the other. Pressing an action does not close the dialog by
/// itself: [onPressed] pops the route when it should.
///
/// ```dart
/// GlassAlertAction(
///   label: 'Delete',
///   isDestructive: true,
///   onPressed: () => Navigator.pop(context, true),
/// )
/// ```
///
/// {@category Modals}
@immutable
class GlassAlertAction {
  /// An action labelled [label], enabled when [onPressed] is not null.
  const GlassAlertAction({required this.label, this.onPressed, this.isDefault = false, this.isDestructive = false});

  /// The text on the button, on one line.
  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;

  /// Drawn bold, as iOS's preferred action is.
  final bool isDefault;

  /// Drawn in iOS's red.
  final bool isDestructive;
}

/// Shows [builder]'s widget — a [GlassAlert], typically — over a dim, centred,
/// in the navigator's overlay.
///
/// {@template g1455.modal.host}
/// > **Note:** The [GlassHost] has to be **above the navigator**. A glass
/// > surface is captured by the host above it, and a modal is built in the
/// > `Overlay` it is shown in — for a dialog or a sheet the navigator's, for a
/// > menu or a popover the nearest one. In a `WidgetsApp` or a `MaterialApp`
/// > that means `builder: (context, child) => GlassHost(child: child!)`. Built
/// > anywhere else the modal finds no host, and says so in debug rather than
/// > drawing glass that samples nothing.
/// {@endtemplate}
///
/// The route's content inherits the text style, icon theme and app themes in
/// force at [context], as `showDialog`'s does. [barrierDismissible] lets a tap
/// on the dim close it, and [barrierLabel] is what a screen reader says of the
/// dim. The returned future completes with the value the route is popped with.
///
/// ```dart
/// final bool? delete = await showGlassDialog<bool>(
///   context: context,
///   builder: (BuildContext context) => GlassAlert(
///     title: const Text('Delete all notes?'),
///     message: const Text('This cannot be undone.'),
///     actions: <GlassAlertAction>[
///       GlassAlertAction(label: 'Cancel', isDefault: true, onPressed: () => Navigator.pop(context, false)),
///       GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context, true)),
///     ],
///   ),
/// );
/// ```
///
/// See also:
///
///  * [GlassAlert], the content this is usually given.
///  * [showGlassSheet], the same over a sheet from the bottom edge.
///  * [kGlassModalDim], the dim.
///  * [The alert on the site](https://g1455.plugfox.dev/components/alert).
///
/// {@category Modals}
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  String barrierLabel = 'Dismiss',
  Duration transitionDuration = const Duration(milliseconds: 250),
}) {
  final NavigatorState navigator = Navigator.of(context);
  final CapturedThemes themes = _capture(context, navigator);
  return navigator.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: kGlassModalDim,
      transitionDuration: transitionDuration,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> _) =>
          themes.wrap(SafeArea(child: Center(child: builder(context)))),
    ),
  );
}

/// iOS 26's alert, on glass.
///
/// [kGlassAlertWidth] wide and [kGlassAlertRadius] round, its [title] bold
/// above a dimmer [message] and its [actions] below as capsules: two side by
/// side, any other number stacked. It materializes with the route that shows
/// it — blur first, tint last, the content fading in on top — and is lifted
/// [kGlassModalLift] levels ([GlassAbove]), so glass bars under it show in its
/// backdrop. Shown with [showGlassDialog].
///
/// {@macro g1455.modal.host}
///
/// ```dart
/// showGlassDialog<void>(
///   context: context,
///   builder: (BuildContext context) => GlassAlert(
///     title: const Text('Turn on notifications?'),
///     message: const Text('You can change this later in Settings.'),
///     actions: <GlassAlertAction>[
///       GlassAlertAction(label: 'Not now', onPressed: () => Navigator.pop(context)),
///       GlassAlertAction(label: 'Allow', isDefault: true, onPressed: () => Navigator.pop(context)),
///     ],
///   ),
/// );
/// ```
///
/// See also:
///
///  * [showGlassDialog], which puts it on screen.
///  * [GlassAlertAction], one of its buttons.
///  * [The alert on the site](https://g1455.plugfox.dev/components/alert).
///
/// {@category Modals}
class GlassAlert extends StatelessWidget {
  /// An alert headed by [title].
  const GlassAlert({
    required this.title,
    this.message,
    this.actions = const <GlassAlertAction>[],
    this.finish,
    super.key,
  });

  /// The heading, at 17 pt semibold in the label colour the theme chose for
  /// the glass. Usually a [Text].
  final Widget title;

  /// The text under [title], at 15 pt in the label colour at 60%. Null leaves
  /// it out.
  final Widget? message;

  /// The buttons, in order: two share a row, any other number stack. Empty
  /// leaves the alert without buttons, to be closed some other way.
  final List<GlassAlertAction> actions;

  /// The optics. Null takes the theme's.
  final GlassFinish? finish;

  @override
  Widget build(BuildContext context) {
    _assertHosted(context, 'GlassAlert');
    final Animation<double> progress = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final GlassThemeData theme = GlassTheme.of(context);
    final Color label = theme.legibility(finish ?? theme.finish).label;
    final double width = math.min(kGlassAlertWidth, MediaQuery.sizeOf(context).width - 2 * 16);
    return _Materializing(
      progress: progress,
      builder: (BuildContext context, double t) => SizedBox(
        width: width,
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(kGlassAlertRadius)),
          finish: finish,
          // Materialized, not grown: Apple's frame is whole from the first
          // frame, and `presence` erodes a lone panel to its medial
          // axis — a bright horizontal line for the first frames.
          materialize: t,
          child: Opacity(
            opacity: Curves.easeIn.transform(t),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: label),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 22, 0, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        child: title,
                      ),
                    ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 6, 30, 0),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(fontSize: 15, color: label.withValues(alpha: label.a * 0.6)),
                          child: message!,
                        ),
                      ),
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _actions(label)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(Color label) {
    Widget button(GlassAlertAction a) => _AlertButton(action: a, label: label);
    if (actions.length == 2) {
      return Row(
        children: <Widget>[
          Expanded(child: button(actions[0])),
          const SizedBox(width: 8),
          Expanded(child: button(actions[1])),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          button(actions[i]),
        ],
      ],
    );
  }
}

class _AlertButton extends StatefulWidget {
  const _AlertButton({required this.action, required this.label});

  final GlassAlertAction action;
  final Color label;

  @override
  State<_AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<_AlertButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final GlassAlertAction a = widget.action;
    final bool enabled = a.onPressed != null;
    final Color colour = a.isDestructive ? const Color(0xFFFF3B30) : widget.label;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _held = true) : null,
        onTapUp: enabled ? (_) => setState(() => _held = false) : null,
        onTapCancel: enabled ? () => setState(() => _held = false) : null,
        onTap: a.onPressed,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: _held ? _kActionFill.withValues(alpha: _kActionFill.a * 2) : _kActionFill,
          ),
          child: Text(
            a.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 17,
              fontWeight: a.isDefault ? FontWeight.w600 : FontWeight.w400,
              color: enabled ? colour : colour.withValues(alpha: colour.a * 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet

/// The heights a sheet from [showGlassSheet] rests at — UIKit's
/// `UISheetPresentationController.Detent`, two of them.
///
/// {@category Modals}
enum GlassSheetDetent {
  /// The sheet at its content's height, never taller than the window less its
  /// margins, floating [kGlassSheetInset] in from the window's sides and
  /// bottom. What every sheet was before there were detents.
  ///
  /// Apple's medium detent is half the window whatever the content; this one
  /// is the content's height, so a content half the window tall is Apple's.
  medium,

  /// The whole height below the top safe area less [kGlassSheetInset], and
  /// edge to edge: the inset at the sides and the bottom goes to nothing, and
  /// the glass moves to `largeFinish` — by default the same finish laid on
  /// opaquely, which is Apple's "transitions to a more opaque appearance"
  /// taken all the way, and which stops the sheet reading its backdrop at all.
  ///
  /// The top gap and keeping the corner radius at the bottom are layout taste:
  /// only the medium detent was read off iOS.
  large,
}

/// How long a sheet takes to settle at a detent, or back from a drag that did
/// not dismiss it. A feel, not a measurement.
const Duration _kSheetSettle = Duration(milliseconds: 300);

/// Faster than this, logical px per second, a released drag goes on to the
/// detent it was heading for rather than the nearer one. A feel.
const double _kSheetFlick = 700;

/// Whether a sheet declares the area it can move in while it moves. The
/// default, and what was measured; a test turns it off to see what it saves.
@visibleForTesting
bool debugGlassSheetTravel = true;

/// Shows [builder]'s widget in a glass sheet rising from the bottom, over a
/// dim. Dragged, it follows the finger; dragged down, it goes past a third of
/// its height or on a flick.
///
/// {@macro g1455.modal.host}
///
/// The sheet stands [kGlassSheetInset] in from the window's sides and bottom,
/// its corner [kGlassSheetRadius], with a grabber at its top unless
/// [showGrabber] is false. [finish] is its optics; null takes the theme's. The
/// returned future completes with the value the route is popped with.
///
/// **Detents.** [detents] are the heights it rests at, [initialDetent] the one
/// it opens at (the first of [detents] when null). By default it has one,
/// [GlassSheetDetent.medium]: the sheet at its content's height, as it always
/// was. With [GlassSheetDetent.large] too, a drag up pulls it to the whole
/// height — its top under the finger the whole way, its inset going to nothing
/// as it rises — and a release settles it at the nearer detent, or the one a
/// flick was heading for; [onDetentChanged] is told each time it settles at
/// another. The content is laid out at the height the sheet has, so a list in
/// it shows more rows at large.
///
/// At large the glass is [largeFinish] — by default [finish] laid on opaquely,
/// its tint at full alpha, which passes through every level between as the
/// sheet rises. **An opaque large sheet reads no backdrop**: a glass whose
/// tint covers at full alpha shows nothing of what it captured, so once it is
/// all the way up it is drawn on [GlassTier.cheap], which draws the same tint
/// over nothing and is captured for nothing. Glass in the sheet's content stays
/// on the theme's rung and sees the sheet behind it. A [largeFinish] whose
/// tint is translucent keeps the sheet glass, and keeps its capture.
///
/// [barrierDismissible] false is a sheet only its own content closes, as
/// UIKit's `isModalInPresentation`: a tap on the dim, Escape and a drag all
/// leave it where it is — a drag down past its lowest detent pulls it a quarter
/// of the way, never more than half the sheet's height, and it springs back
/// when let go. A drag between detents still moves it.
///
/// [constraints] bound the sheet inside the window's margins, as
/// `showModalBottomSheet`'s do: a `maxWidth` keeps it at its content's width
/// and centred on a wide window, where a sheet across the whole width leaves
/// its content in a corner of the glass. Null, it spans the window.
///
/// ```dart
/// showGlassSheet<void>(
///   context: context,
///   barrierDismissible: false, // not the dim, not Escape, not a drag
///   constraints: const BoxConstraints(maxWidth: 480),
///   builder: (BuildContext context) => Padding(
///     padding: const EdgeInsets.all(20),
///     child: GlassButton(
///       onPressed: () => Navigator.pop(context),
///       child: const Text('Done'),
///     ),
///   ),
/// );
/// ```
///
/// A sheet that opens at its content's height and can be pulled to the whole
/// window:
///
/// ```dart
/// showGlassSheet<void>(
///   context: context,
///   detents: const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
///   onDetentChanged: (GlassSheetDetent detent) => debugPrint('now $detent'),
///   builder: (BuildContext context) => const SizedBox(height: 320, child: Placeholder()),
/// );
/// ```
///
/// See also:
///
///  * [GlassSheetDetent], the two heights.
///  * [showGlassDialog], the same over a centred alert.
///  * [kGlassModalDim], the dim behind both.
///  * [The sheet on the site](https://g1455.plugfox.dev/components/sheet).
///
/// {@category Modals}
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlassFinish? finish,
  bool showGrabber = true,
  bool barrierDismissible = true,
  String barrierLabel = 'Dismiss',
  BoxConstraints? constraints,
  List<GlassSheetDetent> detents = const <GlassSheetDetent>[GlassSheetDetent.medium],
  GlassSheetDetent? initialDetent,
  ValueChanged<GlassSheetDetent>? onDetentChanged,
  GlassFinish? largeFinish,
}) {
  assert(detents.isNotEmpty, 'A sheet needs a detent to rest at.');
  assert(initialDetent == null || detents.contains(initialDetent), 'initialDetent is not one of detents.');
  final NavigatorState navigator = Navigator.of(context);
  return navigator.push<T>(
    _GlassSheetRoute<T>(
      builder: builder,
      themes: _capture(context, navigator),
      finish: finish,
      showGrabber: showGrabber,
      dismissible: barrierDismissible,
      dismissLabel: barrierLabel,
      constraints: constraints,
      detents: detents,
      initialDetent: initialDetent ?? detents.first,
      onDetentChanged: onDetentChanged,
      largeFinish: largeFinish,
    ),
  );
}

class _GlassSheetRoute<T> extends PopupRoute<T> {
  _GlassSheetRoute({
    required this.builder,
    required this.themes,
    required this.finish,
    required this.showGrabber,
    required this.dismissible,
    required this.dismissLabel,
    required this.constraints,
    required this.detents,
    required GlassSheetDetent initialDetent,
    required this.onDetentChanged,
    required this.largeFinish,
  }) : _detent = initialDetent,
       _extent = ValueNotifier<double>(initialDetent == GlassSheetDetent.large ? 1 : 0);

  final WidgetBuilder builder;
  final CapturedThemes themes;
  final GlassFinish? finish;
  final bool showGrabber;
  final bool dismissible;
  final String dismissLabel;
  final BoxConstraints? constraints;
  final List<GlassSheetDetent> detents;
  final ValueChanged<GlassSheetDetent>? onDetentChanged;
  final GlassFinish? largeFinish;

  @override
  Color get barrierColor => kGlassModalDim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String get barrierLabel => dismissLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      themes.wrap(_GlassSheet(route: this));

  bool get _between => detents.contains(GlassSheetDetent.medium) && detents.contains(GlassSheetDetent.large);

  /// Where the sheet is between its detents: 0 at medium, 1 at large. Moved
  /// by a drag, one logical pixel of the sheet's top for one of the finger's.
  final ValueNotifier<double> _extent;
  GlassSheetDetent _detent;

  /// How far a dismissible sheet has been dragged below its lowest detent,
  /// logical px.
  ///
  /// **Its own offset, and in pixels, rather than the route's controller.**
  /// The drag used to move the controller, whose value the sheet's position
  /// reads through the entrance curve — and `easeOutCubic` is flat at the top,
  /// so 116 px of finger moved the sheet 4.5 px and it only visibly followed
  /// once the finger was far down. The controller is the entrance and the
  /// exit; a drag is neither.
  final ValueNotifier<double> _drop = ValueNotifier<double>(0);

  /// How far a sheet a drag cannot close is pulled, in its heights: a quarter
  /// of the finger's travel, never more than half its height.
  final ValueNotifier<double> _pull = ValueNotifier<double>(0);

  /// What the last layout said: how far the top travels between medium and
  /// large, how tall the sheet is, and how tall the area it stands in is.
  double _span = 1;
  double _sheetHeight = double.infinity;
  double _pageHeight = 1;

  /// Whether a finger or a settle is moving the sheet, which is when it
  /// declares [_area] as where it travels. Not while it rests: the region is
  /// the whole area the sheet can stand in, and a resting sheet captured at
  /// that size would pay for screen it does not cover.
  final ValueNotifier<bool> _moving = ValueNotifier<bool>(false);

  /// The area below the top margin — everywhere the sheet can be between its
  /// detents — as a travel region, and a region that is never attached, which
  /// reads as no declaration.
  final GlassTravelRegion _area = GlassTravelRegion();
  final GlassTravelRegion _still = GlassTravelRegion();

  AnimationController? _settle;
  double _extentFrom = 0;
  double _extentTo = 0;
  double _dropFrom = 0;
  double _pullFrom = 0;

  /// [dy] is the finger's travel since the last update, logical px, down
  /// positive.
  void _drag(double dy) {
    _settle?.stop();
    _moving.value = true;
    final double span = math.max(_span, 1);
    var rest = dy;
    if (rest < 0) {
      // Up: out of a drag below the lowest detent first, then towards large.
      rest = _raise(rest);
      if (rest < 0 && _between) {
        _extent.value = math.min(1, _extent.value - rest / span);
      }
      return;
    }
    if (_between && _extent.value > 0) {
      final double room = _extent.value * span;
      if (rest < room) {
        _extent.value = _extent.value - rest / span;
        return;
      }
      _extent.value = 0;
      rest -= room;
    }
    if (dismissible) {
      _drop.value += rest;
    } else {
      // A quarter of the way, and never more than half its height: a pull
      // that is felt, and goes nowhere.
      _pull.value = math.min(0.5, _pull.value + rest / _sheetHeight / 4);
    }
  }

  /// Takes an upward [dy] out of whatever pulls the sheet below its lowest
  /// detent, and returns what is left of it.
  double _raise(double dy) {
    if (dismissible) {
      final double used = math.min(-dy, _drop.value);
      _drop.value -= used;
      return dy + used;
    }
    final double pulled = _pull.value * _sheetHeight * 4;
    final double used = math.min(-dy, pulled);
    _pull.value = math.max(0, _pull.value - used / _sheetHeight / 4);
    return dy + used;
  }

  /// [velocity] is the finger's at release, logical px per second, down
  /// positive.
  void _release(double velocity) {
    if (dismissible && _drop.value > 0 && (velocity / _pageHeight > 1.5 || _drop.value > _sheetHeight / 3)) {
      navigator?.pop();
      return;
    }
    var target = _extent.value;
    if (_between) {
      target = velocity.abs() > _kSheetFlick ? (velocity < 0 ? 1 : 0) : (_extent.value >= 0.5 ? 1 : 0);
      final GlassSheetDetent detent = target == 1 ? GlassSheetDetent.large : GlassSheetDetent.medium;
      if (detent != _detent) {
        _detent = detent;
        onDetentChanged?.call(detent);
      }
    }
    _settleTo(target);
  }

  void _settleTo(double extent) {
    final NavigatorState? navigator = this.navigator;
    if (navigator == null) {
      return;
    }
    if (_extent.value == extent && _drop.value == 0 && _pull.value == 0) {
      _moving.value = false;
      return;
    }
    _extentFrom = _extent.value;
    _extentTo = extent;
    _dropFrom = _drop.value;
    _pullFrom = _pull.value;
    final AnimationController settle = _settle ??= AnimationController(vsync: navigator, duration: _kSheetSettle)
      ..addListener(_settling)
      ..addStatusListener((AnimationStatus status) {
        if (status.isCompleted) {
          _moving.value = false;
        }
      });
    if (MediaQuery.maybeDisableAnimationsOf(navigator.context) ?? false) {
      settle.value = 1;
      _settling();
      _moving.value = false;
      return;
    }
    settle.forward(from: 0);
  }

  void _settling() {
    final double t = Curves.easeOutCubic.transform(_settle!.value);
    _extent.value = lerpDouble(_extentFrom, _extentTo, t)!;
    _drop.value = _dropFrom * (1 - t);
    _pull.value = _pullFrom * (1 - t);
  }

  @override
  void dispose() {
    _settle?.dispose();
    _moving.dispose();
    _extent.dispose();
    _drop.dispose();
    _pull.dispose();
    super.dispose();
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.route});

  final _GlassSheetRoute<Object?> route;

  @override
  Widget build(BuildContext context) {
    _assertHosted(context, 'A glass sheet');
    final Animation<double> progress = route.animation ?? kAlwaysCompleteAnimation;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final GlassThemeData theme = GlassTheme.of(context);
    final GlassFinish base = route.finish ?? theme.finish;
    final GlassFinish large = route.largeFinish ?? base.copyWith(tint: base.tint.withValues(alpha: 1));
    // The theme and the travel the sheet was given, put back under its glass:
    // a rung the sheet takes for itself at large, and the region it declares
    // while it moves, are the sheet's and not its content's.
    final Widget content = GlassTravelScope(
      region: GlassTravelScope.maybeOf(context) ?? route._still,
      child: GlassTheme(
        data: theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (route.showGrabber)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 5, bottom: 4),
                  width: 36,
                  height: 5,
                  decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x4D3C3C43)),
                ),
              ),
            Flexible(child: Builder(builder: route.builder)),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: safe.top + kGlassSheetInset),
      child: _SheetArea(
        region: route._area,
        child: ValueListenableBuilder<double>(
          valueListenable: route._extent,
          child: content,
          builder: (BuildContext context, double extent, Widget? content) {
            // All the way up, a glass whose tint covers at full alpha shows none
            // of its capture — so it stops taking one, and draws the same tint
            // on the rung that reads nothing. Only from the top rung: a host
            // already below it draws the sheet as it draws everything else.
            final bool opaque = extent >= 1 && large.tint.a >= 1 && theme.tier.tier == GlassTier.full;
            return _SheetFrame(
              route: route,
              extent: extent,
              child: GlassAbove(
                lift: kGlassModalLift,
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[progress, route._drop, route._pull]),
                  builder: (BuildContext context, Widget? child) {
                    final double t = Curves.easeOutCubic.transform(progress.value.clamp(0.0, 1.0));
                    return Transform.translate(
                      offset: Offset(0, route._drop.value),
                      child: FractionalTranslation(
                        translation: Offset(0, 1.05 * (1 - t) + route._pull.value),
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onVerticalDragUpdate: (DragUpdateDetails d) => route._drag(d.primaryDelta!),
                    onVerticalDragEnd: (DragEndDetails d) => route._release(d.primaryVelocity ?? 0),
                    onVerticalDragCancel: () => route._release(0),
                    child: GlassTheme(
                      data: opaque ? theme.copyWith(tier: _kSheetOpaqueTier) : theme,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: route._moving,
                        child: content,
                        builder: (BuildContext context, bool moving, Widget? content) => GlassTravelScope(
                          region: moving && debugGlassSheetTravel ? route._area : route._still,
                          child: GlassSurface(
                            borderRadius: const BorderRadius.all(Radius.circular(kGlassSheetRadius)),
                            // Untouched at medium, so a sheet with no large detent
                            // names exactly the finish it always named.
                            finish: extent <= 0 ? route.finish : GlassFinish.lerp(base, large, extent),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The area a sheet stands in, as the travel region it declares while it
/// moves: a [GlassTravel] whose scope the sheet hands its glass only then.
class _SheetArea extends SingleChildRenderObjectWidget {
  const _SheetArea({required this.region, super.child});

  final GlassTravelRegion region;

  @override
  RenderGlassTravel createRenderObject(BuildContext context) => RenderGlassTravel(region);

  @override
  void updateRenderObject(BuildContext context, RenderGlassTravel renderObject) => renderObject.region = region;
}

/// The rung an opaque large sheet takes: the one that draws the finish's tint
/// over whatever is behind and reads nothing. At a tint of full alpha that is
/// the colour the top rung draws too — `mix(backdrop, tint, 1)` is the tint
/// whatever the backdrop — so the step costs no picture, and unlike
/// [GlassTier.opaque] it needs no backdrop declared. Pinned, because it is the
/// sheet naming the rung outright.
const GlassTierChoice _kSheetOpaqueTier = GlassTierChoice(GlassTier.cheap, GlassTierReason.pinnedByHost);

/// Lays the sheet out between its detents: at its content's height and
/// [kGlassSheetInset] in at [extent] 0, the whole area and edge to edge at 1,
/// and linearly between — so the top moves with the finger.
class _SheetFrame extends SingleChildRenderObjectWidget {
  const _SheetFrame({required this.route, required this.extent, super.child});

  final _GlassSheetRoute<Object?> route;
  final double extent;

  @override
  _RenderSheetFrame createRenderObject(BuildContext context) =>
      _RenderSheetFrame(route: route, extent: extent, limits: route.constraints);

  @override
  void updateRenderObject(BuildContext context, _RenderSheetFrame renderObject) => renderObject
    ..route = route
    ..extent = extent
    ..limits = route.constraints;
}

class _RenderSheetFrame extends RenderShiftedBox {
  _RenderSheetFrame({required this.route, required this._extent, required this._limits}) : super(null);

  _GlassSheetRoute<Object?> route;

  double _extent;
  set extent(double value) {
    if (value != _extent) {
      _extent = value;
      markNeedsLayout();
    }
  }

  BoxConstraints? _limits;
  set limits(BoxConstraints? value) {
    if (value != _limits) {
      _limits = value;
      _natural = null;
      markNeedsLayout();
    }
  }

  /// The content's own height at medium, kept while the sheet rests at large,
  /// where nothing needs it and measuring would lay the content out twice.
  double? _natural;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final Size area = constraints.biggest;
    size = area;
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    BoxConstraints within(double width, double height) => (_limits ?? const BoxConstraints()).enforce(
      BoxConstraints(maxWidth: math.max(0, width), maxHeight: math.max(0, height)),
    );
    final double p = _extent.clamp(0.0, 1.0);
    if (p < 1 || _natural == null) {
      child.layout(within(area.width - 2 * kGlassSheetInset, area.height - kGlassSheetInset), parentUsesSize: true);
      _natural = child.size.height;
    }
    final double natural = _natural!;
    final double inset = kGlassSheetInset * (1 - p);
    if (p > 0) {
      final double height = lerpDouble(natural, area.height, p)!;
      child.layout(within(area.width - 2 * inset, area.height - inset).tighten(height: height), parentUsesSize: true);
    }
    (child.parentData! as BoxParentData).offset = Offset(
      (area.width - child.size.width) / 2,
      area.height - inset - child.size.height,
    );
    route
      .._span = area.height - kGlassSheetInset - natural
      .._sheetHeight = math.max(child.size.height, 1)
      .._pageHeight = math.max(area.height, 1);
  }
}

// ---------------------------------------------------------------------------
// Menu

/// One row of a [GlassMenuAnchor]'s menu, [kGlassMenuRowHeight] tall.
///
/// {@category Modals}
@immutable
class GlassMenuItem {
  /// A row labelled [label], enabled when [onPressed] is not null.
  const GlassMenuItem({required this.label, this.icon, this.onPressed, this.isDestructive = false});

  /// The row's text, on one line and ellipsized when it does not fit.
  final String label;

  /// Drawn ahead of [label], centred 40 px in, in the label colour at 20 px.
  /// Null leaves the space empty, so labels stay aligned.
  final Widget? icon;

  /// Null disables it. The menu closes after it runs.
  final VoidCallback? onPressed;

  /// Draws the label and icon in iOS's red.
  final bool isDestructive;
}

/// What a [GlassMenuAnchor]'s or a [GlassPopoverAnchor]'s builder is given to
/// open and close what it anchors.
///
/// Pass one as the anchor's `controller` to open or close it from outside the
/// builder; otherwise the anchor makes its own. One controller drives one
/// anchor at a time. Before the anchor is mounted, and after it is disposed,
/// [open] and [close] do nothing and [isOpen] is false.
///
/// {@category Modals}
class GlassMenuController {
  _AnchoredState<StatefulWidget>? _state;

  /// Whether the panel is open, or opening. False from the moment [close] is
  /// called, while the panel is still shrinking back.
  bool get isOpen => _state?._open ?? false;

  /// Opens the panel over the anchor. Does nothing if it is open.
  void open() => _state?._show();

  /// Closes the panel back into the anchor. Does nothing if it is closed.
  void close() => _state?._hide();
}

/// A menu's width, logical px (iOS 26.5's `UIMenu` from a button,
/// 250 wide). The default of [GlassMenuAnchor.width].
///
/// {@category Modals}
const double kGlassMenuWidth = 250;

/// The height of one [GlassMenuItem], logical px (iOS 26.5: rows of 42, with
/// 10 above the first and below the last).
///
/// {@category Modals}
const double kGlassMenuRowHeight = 42;

/// A menu's corner radius, logical px (iOS 26.5; the engine's `RSuperellipse`
/// of 31.5, fitted at 0.23 pt rms). The default of
/// [GlassPopoverAnchor.radius].
///
/// {@category Modals}
const double kGlassMenuRadius = 31.5;
const double _kMenuPad = 10;

/// A glass menu that grows out of [builder]'s anchor, in the nearest
/// `Overlay`, which has to be under the [GlassHost].
///
/// {@macro g1455.modal.host}
///
/// Placed as Apple places a button's menu: **over** the anchor, not
/// beside it — its corner on the anchor's matching corner, the anchor hidden
/// while it is open — opening downward from the anchor's top when there is
/// room and upward from its bottom when not, and then with **its items in
/// reverse**, so that the first one is still nearest the finger. The side it
/// aligns to is the anchor's half of the screen. No dim behind it (0.00 code
/// values, against the alert's and the sheet's 0.20).
///
/// Not read: the opening animation, which is shorter than the 0.43 s the
/// reference's screenshots were apart. This one grows out of the anchor —
/// from the anchor's size and capsule to its own, about the corner it shares
/// with the anchor, so the button reads as turning into the menu — while it
/// materializes; never through `presence`, which erodes a lone panel to
/// a line.
///
/// A tap on a row runs its [GlassMenuItem.onPressed] and closes the menu; a
/// tap anywhere outside closes it with nothing chosen.
///
/// ```dart
/// GlassMenuAnchor(
///   items: <GlassMenuItem>[
///     GlassMenuItem(label: 'Rename', icon: const Icon(Icons.edit), onPressed: rename),
///     GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: delete),
///   ],
///   builder: (BuildContext context, GlassMenuController menu) =>
///       GlassButton(onPressed: menu.open, child: const Icon(Icons.more_horiz)),
/// )
/// ```
///
/// See also:
///
///  * [GlassPopoverAnchor], the same placement for content of any kind.
///  * [GlassMenuController], to open and close it from outside [builder].
///  * [GlassMorph], for a button that turns into a panel in place.
///  * [The menu on the site](https://g1455.plugfox.dev/components/menu).
///
/// {@category Modals}
class GlassMenuAnchor extends StatefulWidget {
  /// A menu of [items] over the anchor [builder] returns.
  const GlassMenuAnchor({
    required this.items,
    required this.builder,
    this.controller,
    this.finish,
    this.width = kGlassMenuWidth,
    this.barrierLabel = 'Dismiss',
    super.key,
  });

  /// The rows, first to last as the menu opens downward. A menu that opens
  /// upward shows them in reverse, so the first is still nearest the anchor.
  final List<GlassMenuItem> items;

  /// Builds the anchor — usually a button whose `onPressed` calls
  /// [GlassMenuController.open]. Hidden while the menu stands over it, and
  /// kept laid out so nothing around it moves.
  final Widget Function(BuildContext context, GlassMenuController controller) builder;

  /// Opens and closes the menu from elsewhere. Null makes one, handed to
  /// [builder] either way.
  final GlassMenuController? controller;

  /// The menu's optics. Null takes the theme's.
  final GlassFinish? finish;

  /// The menu's width, logical px. [kGlassMenuWidth] by default.
  final double width;

  /// What a screen reader says of the space around the open menu, whose tap
  /// closes it.
  final String barrierLabel;

  @override
  State<GlassMenuAnchor> createState() => _GlassMenuAnchorState();
}

/// A glass panel of any content that grows out of [builder]'s anchor, as
/// [GlassMenuAnchor]'s menu does, and stays open until a tap outside it or
/// [GlassMenuController.close] — a popover, for content that is changed in
/// place rather than chosen once.
///
/// Its height is not known before it is laid out, so the side it opens to is
/// the anchor's half of the screen: down from an anchor in the upper half, up
/// from one in the lower.
///
/// {@macro g1455.modal.host}
///
/// ```dart
/// GlassPopoverAnchor(
///   width: 280,
///   popoverBuilder: (BuildContext context) => Padding(
///     padding: const EdgeInsets.all(16),
///     child: GlassSlider(value: volume, onChanged: setVolume),
///   ),
///   builder: (BuildContext context, GlassMenuController popover) =>
///       GlassButton(onPressed: popover.open, child: const Icon(Icons.volume_up)),
/// )
/// ```
///
/// See also:
///
///  * [GlassMenuAnchor], the same placement for a list of choices.
///  * [GlassMenuController], to open and close it from outside [builder].
///  * [The popover on the site](https://g1455.plugfox.dev/components/popover).
///
/// {@category Modals}
class GlassPopoverAnchor extends StatefulWidget {
  /// A panel of [popoverBuilder]'s content over the anchor [builder] returns.
  const GlassPopoverAnchor({
    required this.popoverBuilder,
    required this.builder,
    this.controller,
    this.finish,
    this.width = 320,
    this.radius = kGlassMenuRadius,
    this.barrierLabel = 'Dismiss',
    super.key,
  });

  /// The panel's content. Built under a text style and icon theme in the
  /// label colour the theme chose for [finish].
  final WidgetBuilder popoverBuilder;

  /// Builds the anchor — usually a button whose `onPressed` calls
  /// [GlassMenuController.open]. Hidden while the panel stands over it.
  final Widget Function(BuildContext context, GlassMenuController controller) builder;

  /// Opens and closes the panel from elsewhere. Null makes one, handed to
  /// [builder] either way.
  final GlassMenuController? controller;

  /// The panel's optics. Null takes the theme's.
  final GlassFinish? finish;

  /// The panel's width, logical px. Its height is its content's.
  final double width;

  /// The panel's corner radius once open, logical px; [kGlassMenuRadius] by
  /// default. It grows to this from the anchor's capsule.
  final double radius;

  /// See [GlassMenuAnchor.barrierLabel].
  final String barrierLabel;

  @override
  State<GlassPopoverAnchor> createState() => _GlassPopoverAnchorState();
}

/// Where an anchored panel stands: whether it opens down, the corner it
/// shares with the anchor, and the screen offsets that pin that corner.
typedef _Placement = ({bool down, Alignment corner, double? left, double? right, double? top, double? bottom});

/// What a menu and a popover share: the overlay, the controller, the hidden
/// anchor, the barrier, and a panel growing out of the anchor's corner.
abstract class _AnchoredState<W extends StatefulWidget> extends State<W> with SingleTickerProviderStateMixin<W> {
  final OverlayPortalController _portal = OverlayPortalController();
  late final GlassMenuController _controller = _widgetController ?? GlassMenuController();
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  bool _open = false;

  GlassMenuController? get _widgetController;
  Widget Function(BuildContext context, GlassMenuController controller) get _anchorBuilder;
  GlassFinish? get _finish;
  double get _width;
  double get _radius;
  String get _barrierLabel;

  /// Where the panel goes for an anchor at [at] on [screen].
  _Placement _place(Rect at, Size screen, EdgeInsets safe);

  /// The panel's content, in the label colour.
  Widget _content(BuildContext context, _Placement placement);

  @override
  void initState() {
    super.initState();
    _controller._state = this;
  }

  @override
  void dispose() {
    if (identical(_controller._state, this)) {
      _controller._state = null;
    }
    _progress.dispose();
    super.dispose();
  }

  void _show() {
    if (_open) {
      return;
    }
    setState(() => _open = true);
    _portal.show();
    _progress.forward();
  }

  void _hide() {
    if (!_open) {
      return;
    }
    setState(() => _open = false);
    _progress.reverse().then((_) {
      if (mounted && !_open) {
        _portal.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _overlay,
    // Hidden while the panel stands over it, as Apple's button is: the panel
    // is what it turned into. `Visibility`, not `Opacity` — an anchor that is
    // a glass button must not go under a `saveLayer`. Its semantics
    // are dropped by `ExcludeSemantics` rather than by `Visibility`: in 3.47.1
    // `_RenderVisibility.visible=` marks paint and not semantics, though what
    // it visits for semantics depends on it, and closing over an anchor with
    // a semantics node of its own trips `!semantics.parentDataDirty`.
    child: ExcludeSemantics(
      excluding: _open,
      child: Visibility(
        visible: !_open,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        maintainInteractivity: true,
        maintainSemantics: true,
        child: _anchorBuilder(context, _controller),
      ),
    ),
  );

  /// Pins the panel's left or right edge, by the anchor's half of the screen,
  /// kept 8 px inside it.
  ({Alignment corner, double? left, double? right}) _side(Rect at, Size screen) {
    // Spike 34: on the right half the panel's right edge is 3 pt past the
    // anchor's, on the left half its left edge 4 pt before.
    final bool right = at.center.dx > screen.width / 2;
    final double left = (right ? at.right + 3 - _width : at.left - 4).clamp(
      8.0,
      math.max(8.0, screen.width - _width - 8),
    );
    return right
        ? (corner: Alignment.topRight, left: null, right: screen.width - left - _width)
        : (corner: Alignment.topLeft, left: left, right: null);
  }

  Widget _overlay(BuildContext context) {
    _assertHosted(context, '$W\'s panel');
    final RenderBox? anchor = this.context.findRenderObject() as RenderBox?;
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null || !anchor.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect at = MatrixUtils.transformRect(anchor.getTransformTo(overlay), Offset.zero & anchor.size);
    final _Placement place = _place(at, overlay.size, MediaQuery.paddingOf(context));
    final GlassThemeData theme = GlassTheme.of(context);
    final Color label = theme.legibility(_finish ?? theme.finish).label;
    // Grown from the anchor's own capsule: at nought the glass is the button.
    final double from = at.shortestSide / 2;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          // Labelled, or a screen reader finds a tap target that says nothing
          // and no other way to close a popover.
          child: Semantics(
            label: _barrierLabel,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _hide),
          ),
        ),
        Positioned(
          left: place.left,
          right: place.right,
          top: place.top,
          bottom: place.bottom,
          child: _Materializing(
            progress: CurvedAnimation(parent: _progress, curve: Curves.easeOutCubic),
            builder: (BuildContext context, double t) => GlassSurface(
              borderRadius: BorderRadius.all(Radius.circular(lerpDouble(from, _radius, t)!)),
              finish: _finish,
              // See the alert: materialized, never eroded to a line.
              materialize: t,
              child: _Grow(
                progress: t,
                from: at.size,
                width: _width,
                corner: place.corner,
                child: Opacity(
                  opacity: Curves.easeIn.transform(t),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: label, fontSize: 17),
                    child: IconTheme.merge(
                      data: IconThemeData(color: label, size: 20),
                      child: Builder(builder: (BuildContext context) => _content(context, place)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassMenuAnchorState extends _AnchoredState<GlassMenuAnchor> {
  @override
  GlassMenuController? get _widgetController => widget.controller;
  @override
  Widget Function(BuildContext, GlassMenuController) get _anchorBuilder => widget.builder;
  @override
  GlassFinish? get _finish => widget.finish;
  @override
  double get _width => widget.width;
  @override
  double get _radius => kGlassMenuRadius;
  @override
  String get _barrierLabel => widget.barrierLabel;

  double get _height => widget.items.length * kGlassMenuRowHeight + 2 * _kMenuPad;

  @override
  _Placement _place(Rect at, Size screen, EdgeInsets safe) {
    final side = _side(at, screen);
    // Spike 34: opening down, the menu's top is 1 pt above the anchor's; up,
    // its bottom 1 pt below the anchor's — unless that would put its top
    // under the status bar, and then the top is pinned there instead.
    final bool down = at.top - 1 + _height <= screen.height - safe.bottom - 8;
    final double top = down ? at.top - 1 : math.max(safe.top + 8, at.bottom + 1 - _height);
    final bool bottomPinned = !down && top > safe.top + 8;
    return (
      down: down,
      corner: Alignment(side.corner.x, bottomPinned ? 1 : -1),
      left: side.left,
      right: side.right,
      top: bottomPinned ? null : top,
      bottom: bottomPinned ? screen.height - at.bottom - 1 : null,
    );
  }

  @override
  Widget _content(BuildContext context, _Placement placement) {
    // Reversed whenever it opens upward, whichever end is pinned: the first
    // item nearest the finger.
    final List<GlassMenuItem> items = placement.down ? widget.items : widget.items.reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kMenuPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[for (final GlassMenuItem item in items) _row(item, kGlassMenuRowHeight)],
      ),
    );
  }

  Widget _row(GlassMenuItem item, double height) {
    final bool enabled = item.onPressed != null;
    // Spike 34: the icon ahead of the label, centred 40 pt in; the label from
    // 64 pt to 28 pt short of the right edge.
    final Widget content = Row(
      children: <Widget>[
        SizedBox(width: 48, child: Center(child: item.icon ?? const SizedBox.shrink())),
        Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 28),
      ],
    );
    Widget row = Padding(padding: const EdgeInsets.only(left: 16), child: content);
    if (item.isDestructive) {
      row = DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFFFF3B30)),
        child: IconTheme.merge(
          data: const IconThemeData(color: Color(0xFFFF3B30)),
          child: row,
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                _hide();
                item.onPressed!();
              }
            : null,
        child: SizedBox(
          height: height,
          child: enabled ? row : Opacity(opacity: 0.3, child: row),
        ),
      ),
    );
  }
}

class _GlassPopoverAnchorState extends _AnchoredState<GlassPopoverAnchor> {
  @override
  GlassMenuController? get _widgetController => widget.controller;
  @override
  Widget Function(BuildContext, GlassMenuController) get _anchorBuilder => widget.builder;
  @override
  GlassFinish? get _finish => widget.finish;
  @override
  double get _width => widget.width;
  @override
  double get _radius => widget.radius;
  @override
  String get _barrierLabel => widget.barrierLabel;

  @override
  _Placement _place(Rect at, Size screen, EdgeInsets safe) {
    final side = _side(at, screen);
    final bool down = at.center.dy < screen.height / 2;
    return (
      down: down,
      corner: Alignment(side.corner.x, down ? -1 : 1),
      left: side.left,
      right: side.right,
      top: down ? at.top - 1 : null,
      bottom: down ? null : screen.height - at.bottom - 1,
    );
  }

  @override
  Widget _content(BuildContext context, _Placement placement) => widget.popoverBuilder(context);
}

/// Lays its child out at [width] and its own height, and is itself that size
/// lerped from [from] by [progress] — the child pinned at [corner] and clipped
/// to what has grown so far. Resized, not scaled: the glass above it is a
/// shape of this size, and a `Transform` would scale the content and leave the
/// shape's corner radius in the wrong units.
class _Grow extends SingleChildRenderObjectWidget {
  const _Grow({required this.progress, required this.from, required this.width, required this.corner, super.child});

  final double progress;
  final Size from;
  final double width;
  final Alignment corner;

  @override
  _RenderGrow createRenderObject(BuildContext context) =>
      _RenderGrow(progress: progress, from: from, width: width, corner: corner);

  @override
  void updateRenderObject(BuildContext context, _RenderGrow renderObject) => renderObject
    ..progress = progress
    ..from = from
    ..width = width
    ..corner = corner;
}

class _RenderGrow extends RenderShiftedBox {
  _RenderGrow({required this._progress, required this._from, required this._width, required this._corner})
    : super(null);

  double _progress;
  set progress(double value) {
    if (value != _progress) {
      _progress = value;
      markNeedsLayout();
    }
  }

  Size _from;
  set from(Size value) {
    if (value != _from) {
      _from = value;
      markNeedsLayout();
    }
  }

  double _width;
  set width(double value) {
    if (value != _width) {
      _width = value;
      markNeedsLayout();
    }
  }

  Alignment _corner;
  set corner(Alignment value) {
    if (value != _corner) {
      _corner = value;
      markNeedsLayout();
    }
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.constrain(_from);
      return;
    }
    child.layout(
      BoxConstraints.tightFor(width: _width).copyWith(maxHeight: constraints.maxHeight),
      parentUsesSize: true,
    );
    final Size full = child.size;
    size = constraints.constrain(Size.lerp(_from, full, _progress)!);
    (child.parentData! as BoxParentData).offset = _corner.alongOffset(
      Offset(size.width - full.width, size.height - full.height),
    );
  }

  bool get _clipped => child != null && (child!.size.width > size.width || child!.size.height > size.height);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    if (!_clipped) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      (Offset.zero & size).contains(position) && super.hitTestChildren(result, position: position);

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}
