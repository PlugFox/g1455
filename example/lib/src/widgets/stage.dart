import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/theme.dart';
import '../backdrops.dart';

/// Where a demo is shown: a rounded window onto something with colour and
/// edges — what glass needs to be seen at all — with the glass on top and
/// the demo's own knobs underneath.
///
/// The switches and sliders among the knobs are the package's own: the site
/// is built with what it documents.
class DemoStage extends StatelessWidget {
  const DemoStage({
    required this.child,
    this.height = 380,
    this.background,
    this.knobs = const <Widget>[],
    this.hint,
    super.key,
  });

  /// The glass. Laid over the whole stage: use a [Stack], [Center] or
  /// [Align] to place it.
  final Widget child;

  final double height;

  /// What the glass is over; a grid of coloured discs when null.
  final Widget? background;

  /// The demo's settings: [KnobSwitch], [KnobSlider], [KnobChoice].
  final List<Widget> knobs;

  /// One line under the stage: what to try.
  final String? hint;

  // Out of the page's selection: a drag on a demo moves the glass, it does
  // not select the labels on it.
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Live demo',
    explicitChildNodes: true,
    child: SelectionContainer.disabled(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kSiteLine),
          color: const Color(0x66070A12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      RepaintBoundary(child: background ?? const GridBackdrop()),
                      // A demo that animates repaints its own layer: not the
                      // backdrop, the knobs, or the page around the stage.
                      RepaintBoundary(
                        child: Material(type: MaterialType.transparency, child: child),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (knobs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Wrap(spacing: 24, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: knobs),
              ),
            if (hint case final String hint)
              Padding(
                padding: EdgeInsets.fromLTRB(20, knobs.isEmpty ? 6 : 0, 20, 14),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.touch_app_outlined, size: 16, color: kSiteTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(hint, style: const TextStyle(color: kSiteTextMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// An on/off setting of a demo: the package's own [GlassSwitch].
class KnobSwitch extends StatelessWidget {
  const KnobSwitch({required this.label, required this.value, required this.onChanged, super.key});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(label, style: const TextStyle(color: kSiteTextMuted, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          GlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

/// A number setting of a demo, its value shown beside it: the package's own
/// [GlassSlider], mapped from its 0 to 1 onto [min] to [max].
class KnobSlider extends StatelessWidget {
  const KnobSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.format,
    this.width = 180,
    super.key,
  }) : assert(max > min);

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// How the value reads; two decimals when null.
  final String Function(double value)? format;
  final double width;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(label, style: const TextStyle(color: kSiteTextMuted, fontSize: 13)),
      // Loose: on a phone the slider gives up width before the row overflows.
      Flexible(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GlassSlider(
              value: ((value - min) / (max - min)).clamp(0.0, 1.0),
              semanticLabel: label,
              onChanged: (double t) => onChanged(min + t * (max - min)),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(
          format?.call(value) ?? value.toStringAsFixed(2),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kSiteText),
        ),
      ),
    ],
  );
}

/// One of a few values: the package's own [GlassSegmentedControl], its
/// segments as wide as the longest label.
class KnobChoice<T> extends StatelessWidget {
  const KnobChoice({
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    super.key,
  }) : assert(values.length >= 2);

  final String label;
  final List<T> values;

  /// One of [values].
  final T selected;
  final ValueChanged<T> onChanged;

  /// The text of a value; its `toString` when null.
  final String Function(T value)? labelOf;

  static const TextStyle _kSegment = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kSiteText);

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[for (final T value in values) labelOf?.call(value) ?? '$value'];
    final int index = values.indexOf(selected);
    assert(index >= 0, '$selected is not one of $values');
    // The control divides its width evenly, so it is given the longest label
    // times the count — and no more than a phone has, where the knob row
    // wraps under its label instead.
    var widest = 0.0;
    for (final String text in labels) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: _kSegment),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final double width = (widest + 24) * values.length + 4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: const TextStyle(color: kSiteTextMuted, fontSize: 13)),
          const SizedBox(width: 10),
          Flexible(
            child: SizedBox(
              width: width,
              child: DefaultTextStyle.merge(
                style: _kSegment,
                child: GlassSegmentedControl(
                  segments: <Widget>[
                    for (final String text in labels)
                      Text(text, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                  ],
                  selectedIndex: math.max(index, 0),
                  onSelected: (int i) => onChanged(values[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
