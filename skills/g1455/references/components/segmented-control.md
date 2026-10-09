# Segmented control

> GlassSegmentedControl picks one of two to five options. The selected segment lifts into a clear glass drop you can slide to another segment.

- Live: https://g1455.plugfox.dev/components/segmented-control
- API: [`GlassSegmentedControl`](https://pub.dev/documentation/g1455/latest/g1455/GlassSegmentedControl-class.html), [`kGlassSegmentTrack`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSegmentTrack-constant.html), [`kGlassSegmentDropGrow`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSegmentDropGrow-constant.html), [`kGlassSegmentDropWiden`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSegmentDropWiden-constant.html)
- Source: [`lib/src/surface/glass_segmented_control.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_segmented_control.dart)

`GlassSegmentedControl` is iOS 26's segmented control. The track is a flat translucent fill, and the
selected segment sits on a white capsule. Press the selection and it lifts into a clear glass drop
that stands out of the track; slide it along and let go over another segment to select that one.
Tapping a segment selects it directly.

The track and the capsule are paint, not glass, so at rest the control costs nothing. The drop
exists only while it is held.

## When to use

- Two to five mutually exclusive views or filters: Day / Week / Month, List / Grid / Map.
- **Not** for navigation between the main sections of an app: that is a [tab bar](../components/tab-bar.md).
- **Not** for one on/off option: that is a [switch](../components/switch.md).
- **Not** for more than five options, or long labels. It asserts at least two segments.

## Usage

```dart
SizedBox(
  width: 280,
  child: GlassSegmentedControl(
    segments: const <Widget>[Text('Day'), Text('Week'), Text('Month')],
    selectedIndex: _range,
    onSelected: (int i) => setState(() => _range = i),
  ),
)
```

The control is 32 px tall (44 px with its tap area) and takes the width of its parent, divided
evenly between segments. It needs a bounded width.

## Label colours

The control lives in the content layer, so it does not pick a label colour for the unselected
segments: they use the ambient `DefaultTextStyle` and `IconTheme`. Inside a [Card](../components/card.md)
that is already the card's legible colour. Elsewhere, set it yourself with `DefaultTextStyle.merge`.

The **selected** segment's label is picked for you, black on a light `thumbColor` and white on a
dark one.

## Accessibility

Each segment is a button for a screen reader, with the selected one marked as selected. Text
segments read their text. For icon segments, wrap each icon in `Semantics(label: ...)` or use
`Icon(..., semanticLabel: ...)`.

## Keyboard, right to left, and a PageView

- The control takes the focus from the keyboard (`focusNode`, `autofocus`), and the arrow keys move the selection. The
  ring is drawn around the track behind a boundary of its own; on a control under other glass, showing or hiding it is
  one capture.
- Under a right-to-left `Directionality` the first segment is at the right, and the arrows follow.
- The drop is dragged from touch-down, and inside a horizontal `PageView` the control claims the drag, so the page does
  not turn under it. In a vertical list a swipe that starts on it still scrolls the list.
- The capsule's corner is concentric with the track's, by `GlassConcentric` (see
  [GlassSurface](../foundations/surface.md)): 14 inside a 16 track inset 2.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A calendar header: a range picker on a glass card, and what it selects.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class RangePicker extends StatefulWidget {
  const RangePicker({super.key});

  @override
  State<RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends State<RangePicker> {
  static const List<String> _ranges = <String>['Day', 'Week', 'Month', 'Year'];
  int _range = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Unselected labels take this style; the card has already set the colour.
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            child: GlassSegmentedControl(
              segments: <Widget>[for (final String r in _ranges) Text(r)],
              selectedIndex: _range,
              onSelected: (int i) => setState(() => _range = i),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This ${_ranges[_range].toLowerCase()}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Icon segments with labels for screen readers, on a dark thumb.
Widget layoutPicker(int index, ValueChanged<int> onSelected) => SizedBox(
  width: 200,
  child: GlassSegmentedControl(
    segments: const <Widget>[
      Icon(Icons.list, semanticLabel: 'List'),
      Icon(Icons.grid_view, semanticLabel: 'Grid'),
      Icon(Icons.map, semanticLabel: 'Map'),
    ],
    selectedIndex: index,
    onSelected: onSelected,
    thumbColor: const Color(0xFF636366),
  ),
);
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `segments` | `List<Widget>` | **required** | One widget per segment, usually a `Text` or an `Icon`. At least 2. |
| `selectedIndex` | `int` | **required** | The selected segment. |
| `onSelected` | `ValueChanged<int>?` | **required** | Called with the new index. Null disables the control (half opacity). |
| `trackColor` | `Color` | `kGlassSegmentTrack` | The track's fill. |
| `thumbColor` | `Color` | `Color(0xFFFFFFFF)` | The capsule under the selected segment at rest. |
| `dropMotion` | `GlassDropMotion?` | `null` | How the held drop stretches and squashes as it moves. Null takes the theme's; `GlassDropMotion.none` keeps it round. See [Drop motion](../foundations/drop-motion.md). |
| `focusNode` | `FocusNode?` | `null` | The control's focus. Null makes one the control owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the control is built. |
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSegmentTrack` | `Color.fromRGBO(118, 118, 128, 0.12)` | The default track fill (iOS's tertiary system fill). |
| `kGlassSegmentDropGrow` | `Size(12, 8)` | How much larger the held drop is than the capsule, per side. |
| `kGlassSegmentDropWiden` | `2.9` | How many px of the surroundings the drop pulls in (a slight zoom-out). |
