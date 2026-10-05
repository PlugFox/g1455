# Text field

> A single-line text field in its own glass capsule, like the search field of an iOS 26 bar. Text, placeholder and icons take a legible colour.

- Live: https://g1455.plugfox.dev/components/text-field
- API: [`GlassTextField`](https://pub.dev/documentation/g1455/latest/g1455/GlassTextField-class.html), [`GlassTextField.search`](https://pub.dev/documentation/g1455/latest/g1455/GlassTextField/GlassTextField.search.html), [`kGlassFieldHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassFieldHeight-constant.html)
- Source: [`lib/src/surface/glass_text_field.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_text_field.dart)

`GlassTextField` is a single line of text in a 44 px glass capsule, built on Flutter's `EditableText`. The text, the
placeholder and the icons are drawn in the label colour the theme picks for the glass, so they read over whatever is
behind it. The placeholder is the label colour at 30% and the icons at 60%. Typing and the blinking caret repaint only
the text inside the capsule, so neither makes the host capture again.

`GlassTextField.search` is the preset for a bar's search field: a magnifier in front, "Search" as the placeholder, and
the keyboard's search action.

## When to use

- A search field that floats on its own: at the top of a list, in a toolbar, over a photo or a map.
- A short single-line input that stands directly on the content, such as a caption or a name.
- **Not** for fields that sit *on* a glass card or in a sheet. On iOS those are ordinary fields, and a glass field
  there is glass on glass, which costs an extra capture level. Use a plain field there.
- **Not** for multi-line text or full forms. There is no `maxLines`, `decoration`, `inputFormatters` or validation.

## Usage

```dart
Positioned(
  top: 16,
  left: 16,
  right: 16, // the field stretches, so give it a bounded width
  child: GlassTextField.search(
    onSubmitted: (String query) => search(query),
  ),
)
```

The main constructor takes everything the preset fixes: `placeholder`, `leading`, `keyboardType`, `textInputAction` and
`obscureText` for a password.

```dart
GlassTextField(
  placeholder: 'Password',
  leading: const Icon(Icons.lock_outline),
  obscureText: true,
  textInputAction: TextInputAction.done,
  onSubmitted: signIn,
)
```

## Layout

- The field **stretches to the width it is given**, so the width has to be bounded. In a `Row`, wrap it in `Expanded`;
  in a `Stack`, give the `Positioned` a `left` and a `right`.
- Its height is fixed at [kGlassFieldHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassFieldHeight-constant.html)
  (44), which is also the minimum tap target. A tap anywhere on the capsule focuses the field.

## Behaviour

- `controller` and `focusNode` are optional. Without them the field makes its own and disposes of them.
- There is no built-in clear button. Pass one as `trailing` and wire it to `controller.clear()`, as the code example does.
  Icons in `leading` and `trailing` are themed at 20 px.
- `cursorColor` defaults to iOS blue (`0xFF007AFF`); the selection is the same colour at 30%.
- The field is an `EditableText`, so it needs what an app provides: `MediaQuery`, `Directionality` and an `Overlay` for
  the selection handles. Any `MaterialApp` or `WidgetsApp` has them.

> [!TIP]
> The label colour is only as right as what the host knows about the backdrop. Over photos or a scrolling feed, set
> `richBackdrop: true` on the [GlassHost](../foundations/host.md). See [Legibility](../foundations/legibility.md).

## Accessibility

- An icon-only `trailing` button says nothing to a screen reader on its own. Wrap it in
  `Semantics(button: true, label: 'Clear', ...)`.
- Keep a visible label or a clear placeholder: the field has no separate label parameter.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A list of cities with a glass search field floating over it.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class CitySearch extends StatefulWidget {
  const CitySearch({super.key});

  @override
  State<CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<CitySearch> {
  static const List<String> _cities = <String>['Amsterdam', 'Berlin', 'Kyoto', 'Lisbon', 'Oslo', 'Porto', 'Tbilisi'];
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.text.toLowerCase();
    final List<String> shown = _cities.where((String c) => c.toLowerCase().contains(q)).toList();
    return Stack(
      children: <Widget>[
        // The content the glass floats over.
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 76, 16, 16),
          children: <Widget>[for (final String city in shown) ListTile(title: Text(city))],
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16, // a bounded width: the field stretches
          child: GlassTextField.search(
            controller: _query,
            onChanged: (_) => setState(() {}),
            trailing: _query.text.isEmpty
                ? null
                : Semantics(
                    button: true,
                    label: 'Clear',
                    child: GestureDetector(
                      onTap: () => setState(_query.clear),
                      child: const Icon(Icons.cancel),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
```

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `controller` | `TextEditingController?` | `null` | The text. Null makes an internal one. |
| `focusNode` | `FocusNode?` | `null` | The focus. Null makes an internal one. |
| `placeholder` | `String?` | `null` (`'Search'` in `.search`) | Shown, dimmed to 30%, while the field is empty. |
| `leading` | `Widget?` | `null` (a magnifier in `.search`) | Before the text, such as an icon. |
| `trailing` | `Widget?` | `null` | After the text, such as a clear button. |
| `onChanged` | `ValueChanged<String>?` | `null` | Called on every change of the text. |
| `onSubmitted` | `ValueChanged<String>?` | `null` | Called on the keyboard's action. |
| `keyboardType` | `TextInputType?` | `null` | Main constructor only; `.search` uses `TextInputType.text`. |
| `textInputAction` | `TextInputAction?` | `null` | Main constructor only; `.search` uses `TextInputAction.search`. |
| `autofocus` | `bool` | `false` | Focus the field when it first appears. |
| `obscureText` | `bool` | `false` | Main constructor only. Hides the text, for passwords. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `cursorColor` | `Color` | `Color(0xFF007AFF)` | The caret, and the selection at 30%. |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassFieldHeight` | `44` | The field's height. |
