# Alert

> iOS 26's alert on glass: a title, an optional message and capsule actions, shown over a dim with showGlassDialog. It materializes in, blur first and tint last.

- Live: https://g1455.plugfox.dev/components/alert
- API: [`GlassAlert`](https://pub.dev/documentation/g1455/latest/g1455/GlassAlert-class.html), [`GlassAlertAction`](https://pub.dev/documentation/g1455/latest/g1455/GlassAlertAction-class.html), [`showGlassDialog()`](https://pub.dev/documentation/g1455/latest/g1455/showGlassDialog.html), [`kGlassAlertRadius`](https://pub.dev/documentation/g1455/latest/g1455/kGlassAlertRadius-constant.html), [`kGlassAlertWidth`](https://pub.dev/documentation/g1455/latest/g1455/kGlassAlertWidth-constant.html), [`kGlassModalDim`](https://pub.dev/documentation/g1455/latest/g1455/kGlassModalDim-constant.html)
- Source: [`lib/src/surface/glass_modal.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_modal.dart)

`GlassAlert` is iOS 26's alert: a 320 px glass panel with 34 px corners, a title, an optional message and capsule
action buttons. You show it with `showGlassDialog`, which pushes it on the navigator, centred over a 20% black dim, and
returns a `Future` with the value the alert was closed with.

The alert materializes in: blur first, tint last, with the text fading in on top. It lifts itself above page glass and
glass bars, so you don't need a [GlassAbove](../foundations/above.md) for it.

## When to use

- Short confirmations and destructive-action prompts: "Delete this photo?", "Discard changes?".
- A message the user must acknowledge before going on.
- **Not** for forms, pickers or anything long. Use a [sheet](../components/sheet.md).
- **Not** for a list of actions on an item. Use a [menu](../components/menu.md).

## Usage

```dart
final bool? delete = await showGlassDialog<bool>(
  context: context,
  builder: (BuildContext context) => GlassAlert(
    title: const Text('Delete "Lisbon.jpg"?'),
    message: const Text('This cannot be undone.'),
    actions: <GlassAlertAction>[
      GlassAlertAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
      GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context, true)),
    ],
  ),
);
```

> [!NOTE]
> **Actions don't close the alert by themselves.** Call `Navigator.pop(context, value)` in each `onPressed`. The value
> you pop with is what `showGlassDialog` returns.

## Behaviour

- Exactly two actions sit side by side. One, or three and more, are stacked.
- `isDefault` draws an action's label bold; `isDestructive` draws it in iOS red. `onPressed: null` disables it.
- The title is 17 px semibold, the message 15 px at 60% of the label colour. Both start-aligned by default; pass
  `textAlign: TextAlign.center` to your `Text`s for the centred iOS look.
- The panel is 320 px wide, or the screen width less 16 px on each side when that is narrower.
- By default a tap on the dim does nothing, as in iOS. Set `barrierDismissible: true` to let it close the alert; the
  `Future` then completes with `null`.

## Setup

> [!WARNING]
> The [GlassHost](../foundations/host.md) must be **above the navigator**, so put it in `MaterialApp(builder: ...)`. The
> alert is built in the navigator's overlay; with the host inside a page instead, it finds no host and says so in debug.

## Accessibility

- The dim is announced with `barrierLabel` ("Dismiss" by default) when it can close the alert.
- Keep action labels short verbs ("Delete", "Keep"), not "Yes" and "No".

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A row that asks before deleting its file.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
class FileTile extends StatefulWidget {
  const FileTile({required this.name, required this.onDelete, super.key});

  final String name;
  final VoidCallback onDelete;

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  Future<void> _confirm() async {
    final bool? delete = await showGlassDialog<bool>(
      context: context,
      builder: (BuildContext context) => GlassAlert(
        title: Text('Delete "${widget.name}"?', textAlign: TextAlign.center),
        message: const Text('It will be removed from all your devices.', textAlign: TextAlign.center),
        actions: <GlassAlertAction>[
          // Actions don't close the alert: pop with the answer.
          GlassAlertAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
          GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (delete ?? false) {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.image_outlined),
    title: Text(widget.name),
    trailing: GlassButton(
      onPressed: _confirm,
      semanticLabel: 'Delete ${widget.name}',
      padding: EdgeInsets.zero,
      child: const Icon(Icons.delete_outline),
    ),
  );
}
```

## API

`showGlassDialog<T>`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | **required** | Where to find the navigator. |
| `builder` | `WidgetBuilder` | **required** | Builds the dialog, usually a `GlassAlert`. Centred in a `SafeArea`. |
| `barrierDismissible` | `bool` | `false` | Whether a tap on the dim closes the dialog (with `null`). |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the dim. |
| `transitionDuration` | `Duration` | `Duration(milliseconds: 250)` | How long the alert takes to materialize. |
| *returns* | `Future<T?>` | | The value passed to `Navigator.pop`, or `null`. |

`GlassAlert`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `title` | `Widget` | **required** | The title, 17 px semibold. |
| `message` | `Widget?` | `null` | The message under it, 15 px at 60% of the label colour. |
| `actions` | `List<GlassAlertAction>` | `[]` | The buttons. Two sit side by side; other counts are stacked. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |

`GlassAlertAction`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | **required** | The button's text. |
| `onPressed` | `VoidCallback?` | `null` | The action. Null disables it. It does not close the alert. |
| `isDefault` | `bool` | `false` | Draws the label bold, as the preferred action. |
| `isDestructive` | `bool` | `false` | Draws the label in iOS red. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassAlertWidth` | `320` | The alert's width. |
| `kGlassAlertRadius` | `34` | The alert's corner radius. |
| `kGlassModalDim` | `Color.fromRGBO(0, 0, 0, 0.20)` | The dim behind an alert and a sheet. |
