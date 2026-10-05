# Sheet

> A floating glass bottom sheet with a grabber, inset from the screen edges. Drag it down or flick it to dismiss, and await the value it was closed with.

- Live: https://g1455.plugfox.dev/components/sheet
- API: [`showGlassSheet()`](https://pub.dev/documentation/g1455/latest/g1455/showGlassSheet.html), [`kGlassSheetInset`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSheetInset-constant.html), [`kGlassSheetRadius`](https://pub.dev/documentation/g1455/latest/g1455/kGlassSheetRadius-constant.html)
- Source: [`lib/src/surface/glass_modal.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_modal.dart)

`showGlassSheet` shows your content in a glass sheet that rises from the bottom of the screen over a 20% dim, like an
iOS 26 sheet at its medium height. The sheet floats 8 px in from the screen's sides and bottom, has 36 px corners and a
grabber, and sizes itself to its content, up to the safe area.

Drag it down past a third of its height, or flick it, and it goes; let go earlier and it springs back. A tap on the dim
closes it too. Like `showDialog`, it returns a `Future` that completes with the value the sheet was popped with.

On a narrow window, this site's own navigation (the menu button at the left of the top bar) opens in a glass sheet.

## When to use

- Share sheets, action sheets, pickers and short forms.
- Details about one item that the user glances at and dismisses.
- **Not** for full-screen flows: there is only one height, the content's. Push a page instead.
- **Not** for a yes/no confirmation. That's an [alert](../components/alert.md).

## Usage

```dart
final String? colour = await showGlassSheet<String>(
  context: context,
  builder: (BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String c in <String>['Red', 'Green', 'Blue'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassButton(onPressed: () => Navigator.pop(context, c), child: Text(c)),
          ),
      ],
    ),
  ),
);
```

## Content

> [!WARNING]
> The sheet does **not** colour its content for legibility. Text inherits the style of the page that opened the sheet,
> which may not read on the glass. Ask the theme for the label colour and apply it yourself:
>
> `final Color label = GlassTheme.of(context).legibility(finish).label;`
>
> Glass components inside the sheet, such as [GlassButton](../components/button.md), pick their own colour.

- The content is laid out in a `Flexible` under the grabber. Long content should scroll: a `SingleChildScrollView` works,
  and a `ListView` needs `shrinkWrap: true` or a bounded height.
- The route has no `Material`. Widgets that need one, such as `InkWell` or `ListTile`, need a
  `Material(type: MaterialType.transparency)` around them.
- `finish` sets the glass of this sheet only. Pass the same finish to `legibility` so the text matches it.

## Setup

The [GlassHost](../foundations/host.md) must be above the navigator (in `MaterialApp(builder: ...)`), as for every modal. The
sheet lifts itself above page glass and bars on its own.

## Accessibility

- With `barrierDismissible` on (the default), the dim is announced with `barrierLabel`.
- Dragging is not the only way out: give the sheet a visible close or cancel action as well.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// Opens a glass sheet to choose who to share with, and returns the name.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
Future<String?> shareWith(BuildContext context) => showGlassSheet<String>(
  context: context,
  builder: (BuildContext context) {
    // The sheet doesn't colour its content: ask the theme what reads on it.
    final Color label = GlassTheme.of(context).legibility().label;
    return DefaultTextStyle.merge(
      style: TextStyle(color: label, fontSize: 17),
      child: IconTheme.merge(
        data: IconThemeData(color: label),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Share with', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final String name in <String>['Anna', 'Ben', 'Chiara'])
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, name),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 12),
                          Text(name),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GlassButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  },
);

/// A button that opens the sheet and shows the choice.
class ShareButton extends StatelessWidget {
  const ShareButton({super.key});

  @override
  Widget build(BuildContext context) => GlassButton(
    onPressed: () async {
      final String? name = await shareWith(context);
      if (name != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to $name')));
      }
    },
    child: const Text('Share'),
  );
}
```

## API

`showGlassSheet<T>`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | **required** | Where to find the navigator. |
| `builder` | `WidgetBuilder` | **required** | The sheet's content, laid out in a `Flexible` under the grabber. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `showGrabber` | `bool` | `true` | Draws the 36 × 5 grabber at the top. |
| `barrierDismissible` | `bool` | `true` | Whether a tap on the dim closes the sheet (with `null`). |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the dim. |
| *returns* | `Future<T?>` | | The value passed to `Navigator.pop`, or `null`. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSheetInset` | `8` | The sheet's distance from the screen's sides and bottom. |
| `kGlassSheetRadius` | `36` | The sheet's corner radius. |
| `kGlassModalDim` | `Color.fromRGBO(0, 0, 0, 0.20)` | The dim behind the sheet. |
