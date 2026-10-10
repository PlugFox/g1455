// A search bar: the glass search field, a clear button inside it while there
// is text, and a Cancel that slides in beside it while it has the focus —
// `UISearchBar` with `showsCancelButton`, as an iPhone shows it.
//
// What it costs: **one surface**, the field's. The clear button is a glyph
// inside the glass and Cancel is a plain text button beside it, not glass —
// as iOS draws it — so the bar never fuses two shapes and has no group to
// pay for. The caret, the typing and the clear button are inside the field's
// surface and are no capture.
//
// **What does cost is Cancel's slide: a capture a frame while the field
// narrows** — 16 over the 250 ms at 60 Hz, once per focus and once per blur,
// and none after it. A glass whose box changes is retaken. A `GlassTravel`
// around the row was tried and did not change the count (16 with it, 16
// without, and 16 with Cancel replaced by an empty box — so it is the field's
// resize and not Cancel's paint), so the row has none: a declaration that buys
// nothing is a slot the size of the row for nothing. Measured in
// `glass_search_bar_test.dart`; reduced motion makes it one frame.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'glass_components.dart' show kGlassMinTapTarget;
import 'glass_finish.dart';
import 'glass_text_field.dart';

/// A search field in a glass capsule, with a clear button while there is text
/// and a Cancel button that slides in beside it while it has the focus.
///
/// The field is [GlassTextField.search]: a magnifier, "Search" while empty, and
/// the keyboard's search action. The clear button — a filled circle with a
/// cross, inside the glass at the field's end — appears while there is text
/// and empties the field, keeping the focus. Cancel, when [showsCancelButton],
/// slides in over [cancelDuration] as the field takes the focus; a tap empties
/// the field, lets go of the focus and calls [onCancel].
///
/// ```dart
/// GlassSearchBar(
///   onChanged: (String query) => setState(() => filter = query),
///   onSubmitted: runSearch,
///   onCancel: () => setState(() => filter = ''),
/// )
/// ```
///
/// > **Note:** one surface, the field's. Typing and the clear button are no
/// > capture. Cancel is plain text in [cancelColor], beside the glass rather
/// > than on it, as iOS draws it — but its slide narrows the glass, and a
/// > glass whose box changes is retaken: a capture a frame for
/// > [cancelDuration] on focus and on blur, none under reduced motion.
///
/// See also:
///
///  * [GlassTextField], the field underneath, for a field that is not search.
///  * [GlassBar], which can carry the bar at the top of a screen.
///
/// {@category Panels and controls}
class GlassSearchBar extends StatefulWidget {
  /// A search bar. [controller] and [focusNode] are made and disposed by the
  /// bar when null; pass your own to read or set the query or the focus.
  const GlassSearchBar({
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.showsCancelButton = true,
    this.cancelLabel = 'Cancel',
    this.cancelColor = const Color(0xFF007AFF),
    this.cancelDuration = const Duration(milliseconds: 250),
    this.autofocus = false,
    this.finish,
    super.key,
  });

  /// The query. Null makes one the bar owns and disposes.
  final TextEditingController? controller;

  /// The field's focus. Null makes one the bar owns and disposes.
  final FocusNode? focusNode;

  /// Shown, dimmed, while the field is empty.
  final String placeholder;

  /// Called with the whole query on every edit, and with `''` when the clear
  /// button or Cancel empties it.
  final ValueChanged<String>? onChanged;

  /// Called with the query when the keyboard's search action is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Called when Cancel is tapped, after the field is emptied and has let go
  /// of the focus.
  final VoidCallback? onCancel;

  /// Whether Cancel slides in while the field has the focus. On by default,
  /// as on an iPhone; iOS ignores it on an iPad.
  final bool showsCancelButton;

  /// Cancel's text. "Cancel" by default; pass the localized word.
  final String cancelLabel;

  /// Cancel's colour, and the caret's: iOS's blue by default.
  final Color cancelColor;

  /// How long Cancel takes to slide in or out. Zero under reduced motion
  /// whatever is passed.
  final Duration cancelDuration;

  /// Whether the field takes the focus as soon as it is built.
  final bool autofocus;

  /// The optics of the field's glass. Null takes the theme's.
  final GlassFinish? finish;

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TextEditingController>('controller', controller, defaultValue: null))
      ..add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null))
      ..add(StringProperty('placeholder', placeholder, defaultValue: 'Search'))
      ..add(FlagProperty('showsCancelButton', value: showsCancelButton, ifFalse: 'no cancel button'))
      ..add(StringProperty('cancelLabel', cancelLabel, defaultValue: 'Cancel'))
      ..add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'))
      ..add(DiagnosticsProperty<GlassFinish>('finish', finish, defaultValue: null));
  }
}

class _GlassSearchBarState extends State<GlassSearchBar> with SingleTickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  late final AnimationController _cancel = AnimationController(vsync: this, duration: widget.cancelDuration);

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// The node the listener is on, so a new [GlassSearchBar.focusNode] moves it.
  FocusNode? _listened;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(GlassSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cancel.duration = widget.cancelDuration;
    _listen();
    if (!widget.showsCancelButton) {
      _cancel.value = 0;
    } else if (!oldWidget.showsCancelButton) {
      // Turned on under a field that already has the focus: no focus change
      // is coming to bring Cancel in, so it comes in now, as it would have on
      // the focus.
      _onFocus();
    }
  }

  void _listen() {
    final FocusNode focus = _focus;
    if (identical(focus, _listened)) {
      return;
    }
    _listened?.removeListener(_onFocus);
    _listened = focus..addListener(_onFocus);
    _cancel.value = widget.showsCancelButton && focus.hasFocus ? 1 : 0;
  }

  @override
  void dispose() {
    _listened?.removeListener(_onFocus);
    _cancel.dispose();
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!widget.showsCancelButton) {
      return;
    }
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final double to = _focus.hasFocus ? 1 : 0;
    if (reduce) {
      _cancel.value = to;
    } else {
      _cancel.animateTo(to, curve: Curves.easeOutCubic);
    }
  }

  void _clear() {
    if (_controller.text.isEmpty) {
      return;
    }
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _onCancel() {
    _clear();
    _focus.unfocus();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = GlassTextField.search(
      controller: _controller,
      focusNode: _focus,
      placeholder: widget.placeholder,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      finish: widget.finish,
      cursorColor: widget.cancelColor,
      trailing: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (BuildContext context, TextEditingValue value, Widget? _) =>
            value.text.isEmpty ? const SizedBox.shrink() : _ClearButton(onPressed: _clear),
      ),
    );
    if (!widget.showsCancelButton) {
      return field;
    }
    return Row(
      children: <Widget>[
        Expanded(child: field),
        AnimatedBuilder(
          animation: _cancel,
          builder: (BuildContext context, Widget? child) => _cancel.value == 0
              ? const SizedBox.shrink()
              : ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: _cancel.value,
                    child: child,
                  ),
                ),
          child: Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onCancel,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: kGlassMinTapTarget.height),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      widget.cancelLabel,
                      maxLines: 1,
                      style: DefaultTextStyle.of(context).style.copyWith(color: widget.cancelColor, fontSize: 17),
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

/// iOS's `xmark.circle.fill`: a filled disc with a cross cut out of it, drawn
/// rather than taken from a font, as the field's magnifier is.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final IconThemeData icon = IconTheme.of(context);
    final double size = (icon.size ?? 20) * 0.85;
    return Semantics(
      button: true,
      label: 'Clear text',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        // Wider than the glyph to the field's height: a 17-px disc is not a
        // target.
        child: SizedBox(
          width: 28,
          height: 36,
          child: Center(
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(painter: _ClearPainter(icon.color ?? const Color(0xFF8E8E93))),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearPainter extends CustomPainter {
  const _ClearPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(s / 2, s / 2);
    final double arm = s * 0.18;
    // The cross is cut out of the disc, so the glass shows through it as it
    // does through iOS's glyph. The layer is the glyph's own bounds, inside
    // the glass's subtree, and has nothing under it but the disc.
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawCircle(c, s / 2, Paint()..color = color)
      ..drawLine(
        c.translate(-arm, -arm),
        c.translate(arm, arm),
        Paint()
          ..blendMode = BlendMode.clear
          ..strokeWidth = s * 0.1
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        c.translate(arm, -arm),
        c.translate(-arm, arm),
        Paint()
          ..blendMode = BlendMode.clear
          ..strokeWidth = s * 0.1
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ClearPainter oldDelegate) => oldDelegate.color != color;
}
