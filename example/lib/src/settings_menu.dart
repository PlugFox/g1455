import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import 'style.dart';

/// The current [GlassSettings]: presets on top, every setting under them.
///
/// The content of the app bar's [GlassPopoverAnchor], which is the glass,
/// grows it out of the button and fades this in; the text style and the icon
/// theme it gives are in the label colour the host chose for the finish and
/// the backdrop, so the menu reads on every setting it offers, the opaque
/// fill included.
///
/// The choices inside are not glass. A control on a glass panel is glass on
/// glass — a second capture level — and a segment to tap has nothing to show
/// for that price.
class GlassSettingsMenu extends StatelessWidget {
  const GlassSettingsMenu({required this.settings, required this.onChanged, super.key});

  final GlassSettings settings;
  final ValueChanged<GlassSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color label = DefaultTextStyle.of(context).style.color!;
    final TextTheme text = Theme.of(context).textTheme;
    final GlassPreset? preset = settings.preset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Heading('Preset', text: text, colour: label),
          _Choices<GlassPreset?>(
            // Custom is shown, never picked: it is where a change lands.
            values: const <GlassPreset?>[...GlassPreset.values, null],
            selected: preset,
            label: (GlassPreset? p) => p?.label ?? 'Custom',
            enabled: (GlassPreset? p) => p != null,
            onSelected: (GlassPreset? p) => onChanged(settings.withPreset(p!)),
            colour: label,
          ),
          const SizedBox(height: 6),
          Text(
            preset?.description ?? 'Your own settings',
            style: text.bodySmall?.copyWith(color: label.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          _Heading('Appearance', text: text, colour: label),
          _Choices<AppearanceChoice>(
            values: AppearanceChoice.values,
            selected: settings.appearance,
            label: (AppearanceChoice c) => c.label,
            onSelected: (AppearanceChoice c) => onChanged(settings.copyWith(appearance: c)),
            colour: label,
          ),
          _Heading('Material', text: text, colour: label),
          _Choices<MaterialChoice>(
            values: MaterialChoice.values,
            selected: settings.material,
            label: (MaterialChoice c) => c.label,
            onSelected: (MaterialChoice c) => onChanged(settings.copyWith(material: c)),
            colour: label,
          ),
          _Heading('Tint', text: text, colour: label),
          _Choices<TintChoice>(
            values: TintChoice.values,
            selected: settings.tint,
            label: (TintChoice c) => c.label,
            onSelected: (TintChoice c) => onChanged(settings.copyWith(tint: c)),
            colour: label,
          ),
          _Heading('Rendering', text: text, colour: label),
          _Choices<RenderingChoice>(
            values: RenderingChoice.values,
            selected: settings.rendering,
            label: (RenderingChoice c) => c.label,
            onSelected: (RenderingChoice c) => onChanged(settings.copyWith(rendering: c)),
            colour: label,
          ),
          _Heading('Ripple', text: text, colour: label),
          _Choices<RippleChoice>(
            values: RippleChoice.values,
            selected: settings.ripple,
            label: (RippleChoice c) => c.label,
            onSelected: (RippleChoice c) => onChanged(settings.copyWith(ripple: c)),
            colour: label,
          ),
          _Heading('Contrast', text: text, colour: label),
          _Choices<ContrastChoice>(
            values: ContrastChoice.values,
            selected: settings.contrast,
            label: (ContrastChoice c) => c.label,
            onSelected: (ContrastChoice c) => onChanged(settings.copyWith(contrast: c)),
            colour: label,
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {required this.text, required this.colour});

  final String title;
  final TextTheme text;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      title,
      style: text.labelMedium?.copyWith(
        color: colour.withValues(alpha: 0.7),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// One setting as a row of segments, the selected one filled.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.colour,
    this.enabled,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final Color colour;
  final bool Function(T)? enabled;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelLarge;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          for (final T value in values)
            Expanded(
              child: _Segment(
                text: label(value),
                selected: value == selected,
                onTap: (enabled?.call(value) ?? true) ? () => onSelected(value) : null,
                style: style,
                colour: colour,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.style,
    required this.colour,
  });

  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final TextStyle? style;
  final Color colour;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colour.withValues(alpha: 0.22) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              text,
              maxLines: 1,
              style: style?.copyWith(
                color: onTap == null && !selected ? colour.withValues(alpha: 0.45) : colour,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
