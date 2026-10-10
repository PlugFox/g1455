# Search bar

> GlassSearchBar is the glass search field with a clear button and a Cancel that slides in on focus. One surface; the slide is its one cost, a capture a frame for 250 ms.

- Live: https://g1455.plugfox.dev/components/search-bar
- API: [`GlassSearchBar`](https://pub.dev/documentation/g1455/latest/g1455/GlassSearchBar-class.html), [`GlassTextField.search`](https://pub.dev/documentation/g1455/latest/g1455/GlassTextField/GlassTextField.search.html), [`kGlassFieldHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassFieldHeight-constant.html)
- Source: [`lib/src/surface/glass_search_bar.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_search_bar.dart)

`GlassSearchBar` is `UISearchBar` with `showsCancelButton`, as an iPhone shows it: the glass search field of
[GlassTextField.search](../components/text-field.md), a clear button inside it while there is text, and a Cancel beside it
that slides in while the field has the focus.

The clear button, a filled circle with a cross at the field's end, empties the field and keeps the focus. Cancel empties
it, lets go of the focus and calls `onCancel`. Cancel is plain text in `cancelColor`, beside the glass rather than on
it, as iOS draws it.

## When to use

- The search at the top of a list or a screen, in a [bar](../components/bar.md) or floating on its own.
- **Not** for a field that is not a search: use a [GlassTextField](../components/text-field.md), which has no Cancel.
- **Not** in a row with other glass that would have to move as the field narrows. The bar takes the width it is given
  and narrows itself; give it a row of its own.

## Usage

```dart
GlassSearchBar(
  onChanged: (String query) => setState(() => filter = query),
  onSubmitted: runSearch,
  onCancel: () => setState(() => filter = ''),
)
```

`controller` and `focusNode` are made and disposed of by the bar when you pass none; pass your own to read or set the
query or the focus. `placeholder` is "Search" and `cancelLabel` "Cancel" by default.

## Cost

One surface, the field's. Typing, the caret and the clear button are inside the glass and are no capture.

**What does cost is Cancel's slide.** The field's glass narrows to make room, and glass whose box changes is retaken: a
capture a frame for `cancelDuration`, 16 over 250 ms at 60 Hz in the package's tests, once as the field takes the focus
and once as it lets go, and none after. A `GlassTravel` around the row was tried and changed nothing (16 with it and
without), because it is the field's resize that costs, not Cancel's paint. Under reduced motion the slide is one frame.
`showsCancelButton: false` keeps the box still, and then focus costs nothing. The count under the demo shows both.

## Layout

- The field is [kGlassFieldHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassFieldHeight-constant.html)
  (44) tall, and Cancel's tap target is at least 44 tall too.
- The bar stretches to the width it is given, so the width must be bounded: an `Expanded` in a `Row`, a `Positioned`
  with a `left` and a `right`.

## Accessibility

The field is an `EditableText`, read as a text field with its placeholder. The clear button and Cancel are buttons.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A list of contacts with a search bar floating over its top.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  static const List<String> _names = <String>['Anna', 'Ben', 'Chiara', 'Dmitri', 'Emma', 'Farid', 'Grace'];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<String> shown = <String>[
      for (final String n in _names)
        if (n.toLowerCase().contains(_query.toLowerCase())) n,
    ];
    final double top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.fromLTRB(16, top + 72, 16, 16),
          children: <Widget>[for (final String n in shown) ListTile(title: Text(n))],
        ),
        Positioned(
          top: top + 12,
          left: 16,
          right: 16, // a bounded width: the bar stretches, and narrows for Cancel
          child: GlassSearchBar(
            placeholder: 'Search contacts',
            onChanged: (String q) => setState(() => _query = q),
            onCancel: () => setState(() => _query = ''),
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
| `controller` | `TextEditingController?` | `null` | The query. Null makes one the bar owns. |
| `focusNode` | `FocusNode?` | `null` | The focus. Null makes one the bar owns. |
| `placeholder` | `String` | `'Search'` | Shown while the field is empty. |
| `onChanged` | `ValueChanged<String>?` | `null` | Called on every change of the query, the clear button's included. |
| `onSubmitted` | `ValueChanged<String>?` | `null` | Called on the keyboard's search action. |
| `onCancel` | `VoidCallback?` | `null` | Called after Cancel has emptied the field and let go of the focus. |
| `showsCancelButton` | `bool` | `true` | Whether Cancel slides in while the field has the focus. `false` keeps the field's box still. |
| `cancelLabel` | `String` | `'Cancel'` | Cancel's text. |
| `cancelColor` | `Color` | `Color(0xFF007AFF)` | Cancel's colour. |
| `cancelDuration` | `Duration` | `Duration(milliseconds: 250)` | How long Cancel takes to slide in or out: a capture a frame for as long. |
| `autofocus` | `bool` | `false` | Focus the field as soon as it is built. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `key` | `Key?` | `null` | |
