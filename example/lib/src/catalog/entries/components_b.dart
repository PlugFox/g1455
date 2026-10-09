import '../catalog.dart';

const List<Entry> kComponentEntriesB = <Entry>[
  // ---------------------------------------------------------------- text-field
  Entry(
    section: Section.components,
    id: 'text-field',
    title: 'Text field',
    icon: 'search',
    summary:
        'A single-line text field in its own glass capsule, like the search field of an iOS 26 bar. Text, '
        'placeholder and icons take a legible colour.',
    api: <String>['GlassTextField', 'GlassTextField.search', 'kGlassFieldHeight'],
    source: 'lib/src/surface/glass_text_field.dart',
    guide: r'''
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
- **Not** for a search with a clear button and Cancel built by hand: that is the [search bar](/components/search-bar).

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
> `richBackdrop: true` on the [GlassHost](/foundations/host). See [Legibility](/foundations/legibility).

## Accessibility

- An icon-only `trailing` button says nothing to a screen reader on its own. Wrap it in
  `Semantics(button: true, label: 'Clear', ...)`.
- Keep a visible label or a clear placeholder: the field has no separate label parameter.
''',
    code: r'''
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
''',
    properties: r'''
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

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassFieldHeight` | `44` | The field's height. |
''',
  ),

  // ---------------------------------------------------------------- toolbar
  Entry(
    section: Section.components,
    id: 'toolbar',
    title: 'Toolbar',
    icon: 'build',
    summary:
        'Several toolbar actions in one glass capsule, the way iOS 26 groups toolbar items. One surface for any '
        'number of actions, so it costs far less than a row of buttons.',
    api: <String>['GlassButtonGroup', 'GlassToolbarItem', 'kGlassToolbarHeight', 'kGlassToolbarItemWidth'],
    source: 'lib/src/surface/glass_toolbar.dart',
    guide: r'''
iOS 26 doesn't put a glass behind each toolbar button. It groups adjacent items into one glass shape: a 48 px circle for
an item on its own, and a capsule for several. `GlassButtonGroup` does the same. You give it a list of
`GlassToolbarItem`s (an icon, an action and a label for screen readers), and it draws them in **one** glass surface.

Pressing an item brightens just its cell, the same way a [GlassButton](/components/button) brightens: the finish's rim
colour is added over the cell, clipped to the capsule. Icons are themed at 22 px in the label colour the theme picks for
the glass.

## When to use

- Icon actions in a toolbar or over content: undo and redo, share, like, delete, previous and next.
- Instead of a row of `GlassButton`s whenever the actions sit next to each other.
- **Not** for text labels. The group is icon-first and its size is fixed. For a labelled action, use a
  [GlassButton](/components/button).
- **Not** for choosing one of several values. That's a [segmented control](/components/segmented-control).

## Usage

```dart
Row(
  children: <Widget>[
    GlassButtonGroup(
      items: <GlassToolbarItem>[
        GlassToolbarItem(icon: const Icon(Icons.undo), label: 'Undo', onPressed: canUndo ? undo : null),
        GlassToolbarItem(icon: const Icon(Icons.redo), label: 'Redo', onPressed: canRedo ? redo : null),
      ],
    ),
    const Spacer(),
    GlassButtonGroup(
      items: <GlassToolbarItem>[
        GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: share),
      ],
    ),
  ],
)
```

## Why one surface

Glass is paid for per surface, and the overhead grows faster than the number of surfaces. Three `GlassButton`s are three
surfaces; a group of three is one. Grouping is how Apple draws it, and it's also the cheap way to build it. See
[Performance](/foundations/performance).

## Layout

- The size is fixed: [kGlassToolbarHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarHeight-constant.html)
  (48) high, and 48 wide for one item or
  [kGlassToolbarItemWidth](https://pub.dev/documentation/g1455/latest/g1455/kGlassToolbarItemWidth-constant.html) (53)
  per item for more. Don't stretch it; place groups with a `Row` and `Spacer`s.
- Four items are 212 px wide. On a narrow phone, a 4-item group plus two circles don't fit in 320 px: drop an action
  or move it into a [menu](/components/menu).
- Groups float over the content on their own, as in iOS. Putting them inside a [GlassBar](/components/bar) works, but it
  is glass on glass and adds a capture level.

## Accessibility

- **Always set `label`.** It is what a screen reader says for the item; the icon alone says nothing.
- `onPressed: null` disables an item: its icon drops to 30% and it is announced as disabled.
- Each item takes the focus from the keyboard, Space or Enter presses it, and its ring is drawn inside its cell, inside
  the glass: no capture. A held cell brightens but does not swell as a [button](/components/button) does, because the
  group is one surface.
- The items run in the reading direction: under a right-to-left `Directionality` the first is at the right.
- A count on an icon is a [badge](/components/badge): `GlassToolbarItem(icon: GlassBadge(count: 3, child: icon))`.

> [!WARNING]
> Don't wrap a group in `Opacity`, `ColorFilter` or `ImageFilter`. The pressed highlight is added onto what's below, and
> those widgets break it. `RepaintBoundary` is fine.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A photo viewer's bottom toolbar: share alone, three actions grouped,
/// and delete alone. Three glass surfaces for five actions.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({required this.photo, super.key});

  final ImageProvider photo;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  bool _liked = false;

  void _toast(String what) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(child: Image(image: widget.photo, fit: BoxFit.cover)),
      Positioned(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
        child: Row(
          children: <Widget>[
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(icon: const Icon(Icons.ios_share), label: 'Share', onPressed: () => _toast('Share')),
              ],
            ),
            const Spacer(),
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                  label: _liked ? 'Unlike' : 'Like',
                  onPressed: () => setState(() => _liked = !_liked),
                ),
                GlassToolbarItem(icon: const Icon(Icons.info_outline), label: 'Info', onPressed: () => _toast('Info')),
                GlassToolbarItem(icon: const Icon(Icons.tune), label: 'Edit', onPressed: () => _toast('Edit')),
              ],
            ),
            const Spacer(),
            GlassButtonGroup(
              items: <GlassToolbarItem>[
                GlassToolbarItem(
                  icon: const Icon(Icons.delete_outline),
                  label: 'Delete',
                  onPressed: () => _toast('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
''',
    properties: r'''
`GlassButtonGroup`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassToolbarItem>` | **required** | The actions, in the reading direction. Must not be empty. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `pressedOverlay` | `Color?` | `null` | Added over a held item's cell. Null takes the finish's rim colour. |

`GlassToolbarItem`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `icon` | `Widget` | **required** | The icon, themed at 22 px in the label colour. |
| `onPressed` | `VoidCallback?` | **required** | The action. Null disables the item (icon at 30%). |
| `label` | `String?` | `null` | What a screen reader says. Always set it. |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassToolbarHeight` | `48` | The group's height, and the size of a one-item circle. |
| `kGlassToolbarItemWidth` | `53` | Each item's width in a group of two or more. |
''',
  ),

  // ---------------------------------------------------------------- alert
  Entry(
    section: Section.components,
    id: 'alert',
    title: 'Alert',
    icon: 'warning',
    summary:
        "iOS 26's alert on glass: a title, an optional message and capsule actions, shown over a dim with "
        'showGlassDialog. It materializes in, blur first and tint last.',
    api: <String>[
      'GlassAlert',
      'GlassAlertAction',
      'showGlassDialog()',
      'kGlassAlertRadius',
      'kGlassAlertWidth',
      'kGlassModalDim',
    ],
    source: 'lib/src/surface/glass_modal.dart',
    guide: r'''
`GlassAlert` is iOS 26's alert: a 320 px glass panel with 34 px corners, a title, an optional message and capsule
action buttons. You show it with `showGlassDialog`, which pushes it on the navigator, centred over a 20% black dim, and
returns a `Future` with the value the alert was closed with.

The alert materializes in: blur first, tint last, with the text fading in on top. It lifts itself above page glass and
glass bars, so you don't need a [GlassAbove](/foundations/above) for it.

## When to use

- Short confirmations and destructive-action prompts: "Delete this photo?", "Discard changes?".
- A message the user must acknowledge before going on.
- **Not** for forms, pickers or anything long. Use a [sheet](/components/sheet).
- **Not** for a list of actions on an item. Use a [menu](/components/menu).

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
> The [GlassHost](/foundations/host) must be **above the navigator**, so put it in `MaterialApp(builder: ...)`. The
> alert is built in the navigator's overlay; with the host inside a page instead, it finds no host and says so in debug.

## Accessibility

- The dim is announced with `barrierLabel` ("Dismiss" by default) when it can close the alert.
- Keep action labels short verbs ("Delete", "Keep"), not "Yes" and "No".
''',
    code: r'''
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
''',
    properties: r'''
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

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassAlertWidth` | `320` | The alert's width. |
| `kGlassAlertRadius` | `34` | The alert's corner radius. |
| `kGlassModalDim` | `Color.fromRGBO(0, 0, 0, 0.20)` | The dim behind an alert and a sheet. |
''',
  ),

  // ---------------------------------------------------------------- sheet
  Entry(
    section: Section.components,
    id: 'sheet',
    title: 'Sheet',
    icon: 'vertical_split',
    summary:
        'A floating glass bottom sheet with a grabber that follows the finger: dragged down to dismiss, pulled up '
        'to a large detent, and awaited for the value it was closed with.',
    api: <String>['showGlassSheet()', 'GlassSheetDetent', 'kGlassSheetInset', 'kGlassSheetRadius'],
    source: 'lib/src/surface/glass_modal.dart',
    guide: r'''
`showGlassSheet` shows your content in a glass sheet that rises from the bottom of the screen over a 20% dim, like an
iOS 26 sheet at its medium height. The sheet floats 8 px in from the screen's sides and bottom, has 36 px corners and a
grabber, and sizes itself to its content, up to the safe area.

The sheet follows the finger. Drag it down past a third of its height, or flick it, and it goes; let go earlier and it
springs back. A tap on the dim closes it too. Like `showDialog`, it returns a `Future` that completes with the value
the sheet was popped with.

On a narrow window, this site's own navigation (the menu button at the left of the top bar) opens in a glass sheet.

## When to use

- Share sheets, action sheets, pickers and short forms.
- Details about one item that the user glances at and dismisses.
- A list or a form that wants the whole height when the user asks for it: give it a large detent, below.
- **Not** for a flow of several screens. Push a page instead.
- **Not** for a yes/no confirmation. That's an [alert](/components/alert).

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

## Detents

`detents` are the heights the sheet rests at, UIKit's `UISheetPresentationController.Detent`. By default it has one,
`GlassSheetDetent.medium`: the sheet at its content's height, as above. Add `GlassSheetDetent.large` and a drag up pulls
it to the whole height below the top safe area less 8 px, its top under the finger the whole way and its inset going to
nothing as it rises; a release settles at the nearer detent, or the one a flick was heading for.

```dart
showGlassSheet<void>(
  context: context,
  detents: const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
  initialDetent: GlassSheetDetent.medium, // the first of detents when null
  onDetentChanged: (GlassSheetDetent detent) => debugPrint('now $detent'),
  builder: (BuildContext context) => const NotesList(),
);
```

The content is laid out at the height the sheet has, so a list in it shows more rows at large. Apple's medium detent is
half the window whatever the content; this one is the content's height.

### An opaque large sheet

At large the glass is `largeFinish`: by default `finish` with its tint at full alpha, which passes through every level
between as the sheet rises. **A sheet whose tint covers fully reads no backdrop**, since it would show nothing of what it
captured, so once it is all the way up it is drawn on the cheap [tier](/foundations/tiers): the same tint over nothing,
and nothing to capture. Headless, a 400 × 800 window with a glass bar under the sheet: one surface of two captured
instead of two, and 20,608 px² of capture against 337,408.

The other way: once it reads nothing, the sheet is ordinary content to the capture of the glass around it, so a change
inside it is a retake for that glass, one where a glass sheet took none. A sheet whose content animates while it is up
may be cheaper with a translucent `largeFinish`, which keeps it glass, and keeps its capture. Glass inside the sheet
stays on the theme's tier and sees the sheet behind it either way.

The gap above a large sheet and its keeping the corner radius at the bottom are layout taste: the medium detent is the
one that was measured.

### Moving

While the sheet is dragged, between detents or down to close, it declares where it travels, so the drag is one retake
rather than one a frame (1 against 16 in the package's tests). Two known gaps: the dim does not fade while the sheet is
dragged down, and a list inside the sheet does not hand the drag over to the sheet when it reaches its top.

## Content

> [!WARNING]
> The sheet does **not** colour its content for legibility. Text inherits the style of the page that opened the sheet,
> which may not read on the glass. Ask the theme for the label colour and apply it yourself:
>
> `final Color label = GlassTheme.of(context).legibility(finish).label;`
>
> Glass components inside the sheet, such as [GlassButton](/components/button), pick their own colour.

- The content is laid out in a `Flexible` under the grabber. Long content should scroll: a `SingleChildScrollView` works,
  and a `ListView` needs `shrinkWrap: true` or a bounded height. At a large detent the content is given the sheet's
  whole height.
- The route has no `Material`. Widgets that need one, such as `InkWell` or `ListTile`, need a
  `Material(type: MaterialType.transparency)` around them.
- `finish` sets the glass of this sheet only. Pass the same finish to `legibility` so the text matches it.

## Setup

The [GlassHost](/foundations/host) must be above the navigator (in `MaterialApp(builder: ...)`), as for every modal. The
sheet lifts itself above page glass and bars on its own.

## Accessibility

- With `barrierDismissible` on (the default), the dim is announced with `barrierLabel`.
- Dragging is not the only way out: give the sheet a visible close or cancel action as well.
''',
    code: r'''
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
''',
    properties: r'''
`showGlassSheet<T>`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | **required** | Where to find the navigator. |
| `builder` | `WidgetBuilder` | **required** | The sheet's content, laid out in a `Flexible` under the grabber. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `showGrabber` | `bool` | `true` | Draws the 36 × 5 grabber at the top. |
| `barrierDismissible` | `bool` | `true` | Whether a tap on the dim closes the sheet (with `null`). |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the dim. |
| `constraints` | `BoxConstraints?` | `null` | Bounds the sheet inside the window's margins; a `maxWidth` keeps it centred on a wide window. |
| `detents` | `List<GlassSheetDetent>` | `[GlassSheetDetent.medium]` | The heights the sheet rests at. Not empty. |
| `initialDetent` | `GlassSheetDetent?` | `null` | The one it opens at; the first of `detents` when null. |
| `onDetentChanged` | `ValueChanged<GlassSheetDetent>?` | `null` | Told each time the sheet settles at another detent. |
| `largeFinish` | `GlassFinish?` | `null` | The glass at the large detent. Null is `finish` with its tint at full alpha, which reads no backdrop. |
| *returns* | `Future<T?>` | | The value passed to `Navigator.pop`, or `null`. |

`GlassSheetDetent`: `medium`, the content's height, floating `kGlassSheetInset` in; `large`, the whole height below the
top safe area less `kGlassSheetInset`, edge to edge.

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassSheetInset` | `8` | The sheet's distance from the screen's sides and bottom. |
| `kGlassSheetRadius` | `36` | The sheet's corner radius. |
| `kGlassModalDim` | `Color.fromRGBO(0, 0, 0, 0.20)` | The dim behind the sheet. |
''',
  ),

  // ---------------------------------------------------------------- menu
  Entry(
    section: Section.components,
    id: 'menu',
    title: 'Menu',
    icon: 'menu_open',
    summary:
        "iOS 26's pull-down menu: a glass list of actions that grows out of the button that opened it. Choosing a "
        'row runs it and closes the menu.',
    api: <String>[
      'GlassMenuAnchor',
      'GlassMenuItem',
      'GlassMenuController',
      'kGlassMenuRadius',
      'kGlassMenuRowHeight',
      'kGlassMenuWidth',
    ],
    source: 'lib/src/surface/glass_modal.dart',
    guide: r'''
`GlassMenuAnchor` wraps the widget that opens a menu, usually a "…" [GlassButton](/components/button), and shows a
glass menu of `GlassMenuItem`s when you call `open()` on the controller its `builder` is given. The menu grows out of
the button the way iOS 26's does: from the button's own capsule to the menu's size, **over** the button rather than
beside it. The button is hidden while the menu is open, because the menu is what it turned into.

Choosing a row runs its action and closes the menu. A tap anywhere outside closes it too. There is no dim behind a menu.

## When to use

- A "more" (…) button with a handful of actions on an item: rename, duplicate, share, delete.
- A short list of one-shot choices from a button, such as "Sort by".
- **Not** for controls you adjust in place, such as switches or sliders. Those belong in a
  [popover](/components/popover), which stays open.
- **Not** for a single confirmation. That's an [alert](/components/alert).

## Usage

```dart
GlassMenuAnchor(
  items: <GlassMenuItem>[
    GlassMenuItem(label: 'Rename', icon: const Icon(Icons.edit_outlined), onPressed: rename),
    GlassMenuItem(label: 'Duplicate', icon: const Icon(Icons.copy), onPressed: duplicate),
    GlassMenuItem(label: 'Delete', icon: const Icon(Icons.delete_outline), isDestructive: true, onPressed: delete),
  ],
  builder: (BuildContext context, GlassMenuController menu) => GlassButton(
    onPressed: menu.open,
    semanticLabel: 'More actions',
    padding: EdgeInsets.zero,
    child: const Icon(Icons.more_horiz),
  ),
)
```

## Placement

- The menu opens **downward** from the button's top when there is room below, and **upward** from its bottom when not.
  When it opens upward, the items are reversed, so the first one stays nearest your finger.
- It lines up with the button on the side of the screen the button is on, and stays at least 8 px inside the screen.
- It's built in the nearest `Overlay`, so it stands over everything on the page, bars included.

## Items

- Each row is [kGlassMenuRowHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRowHeight-constant.html)
  (42) high, with the icon in a 48 px column before the label. Labels are one line and end with an ellipsis.
- `isDestructive` draws the row in iOS red. `onPressed: null` disables the row and dims it to 30%.
- The menu is [kGlassMenuWidth](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuWidth-constant.html) (250)
  wide unless you pass `width`, with corners of
  [kGlassMenuRadius](https://pub.dev/documentation/g1455/latest/g1455/kGlassMenuRadius-constant.html) (31.5).

## Opening from code

Pass your own `GlassMenuController` to open or close the menu from anywhere: `open()`, `close()` and `isOpen`. A
controller drives one anchor at a time.

## Setup and accessibility

- The [GlassHost](/foundations/host) must be above the overlay the menu is built in. With the host in
  `MaterialApp(builder: ...)`, that's true everywhere.
- Give an icon-only button a `semanticLabel`. The area around the open menu is announced with `barrierLabel`.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A note's header with a "…" menu of actions.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
class NoteHeader extends StatefulWidget {
  const NoteHeader({required this.title, super.key});

  final String title;

  @override
  State<NoteHeader> createState() => _NoteHeaderState();
}

class _NoteHeaderState extends State<NoteHeader> {
  bool _pinned = false;

  void _toast(String what) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(what)));

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.headlineSmall)),
      GlassMenuAnchor(
        width: 220,
        items: <GlassMenuItem>[
          GlassMenuItem(
            label: _pinned ? 'Unpin' : 'Pin',
            icon: const Icon(Icons.push_pin_outlined, size: 20),
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          GlassMenuItem(
            label: 'Duplicate',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () => _toast('Duplicated'),
          ),
          const GlassMenuItem(label: 'Move to…', icon: Icon(Icons.folder_outlined, size: 20)), // disabled
          GlassMenuItem(
            label: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            isDestructive: true,
            onPressed: () => _toast('Deleted'),
          ),
        ],
        builder: (BuildContext context, GlassMenuController menu) => GlassButton(
          onPressed: menu.open,
          semanticLabel: 'More actions',
          padding: EdgeInsets.zero,
          child: const Icon(Icons.more_horiz),
        ),
      ),
    ],
  );
}
''',
    properties: r'''
`GlassMenuAnchor`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<GlassMenuItem>` | **required** | The menu's rows, top to bottom. |
| `builder` | `Widget Function(BuildContext, GlassMenuController)` | **required** | Builds the anchor, such as a button, and gets the controller that opens the menu. |
| `controller` | `GlassMenuController?` | `null` | Your own controller, to open or close the menu from outside. Null makes an internal one. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `width` | `double` | `kGlassMenuWidth` (250) | The menu's width. |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the area around the open menu. |

`GlassMenuItem`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `label` | `String` | **required** | The row's text, one line. |
| `icon` | `Widget?` | `null` | Drawn before the label. |
| `onPressed` | `VoidCallback?` | `null` | The action. Null disables the row. The menu closes after it runs. |
| `isDestructive` | `bool` | `false` | Draws the row in iOS red. |

`GlassMenuController`: `open()`, `close()`, `bool get isOpen`.

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassMenuWidth` | `250` | The menu's default width. |
| `kGlassMenuRowHeight` | `42` | Each row's height. |
| `kGlassMenuRadius` | `31.5` | The menu's corner radius, and the popover's default. |
''',
  ),

  // ---------------------------------------------------------------- popover
  Entry(
    section: Section.components,
    id: 'popover',
    title: 'Popover',
    icon: 'chat_bubble',
    summary:
        'A glass panel of any content that grows out of its anchor and stays open while it is used: for quick '
        'settings and filters changed in place.',
    api: <String>['GlassPopoverAnchor'],
    source: 'lib/src/surface/glass_modal.dart',
    guide: r'''
`GlassPopoverAnchor` is the [menu](/components/menu)'s sibling for content you change in place. It grows a glass panel
out of its anchor the same way, but the panel holds **any** widget you build, and it **stays open** until you tap
outside it or call `close()`. Text and icons inside take the label colour the theme picks for the glass.

The settings of this very site are a popover: the button with the tune icon at the right end of the top bar is a
`GlassPopoverAnchor`. Its panel holds the preset, material, tint, rendering, ripple and contrast choices, and the page
under it changes while you adjust them.

## When to use

- Quick settings and controls adjusted in place: display options, sort and filter, a volume slider.
- Small forms whose effect the user wants to see behind the panel as they change it.
- **Not** for a list of one-shot actions. A [menu](/components/menu) runs the action and closes for you.
- **Not** for long or multi-step forms. Use a [sheet](/components/sheet).

## Usage

```dart
GlassPopoverAnchor(
  width: 280,
  popoverBuilder: (BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Brightness'),
        const SizedBox(height: 8),
        GlassSlider(value: brightness, onChanged: setBrightness, semanticLabel: 'Brightness'),
      ],
    ),
  ),
  builder: (BuildContext context, GlassMenuController popover) => GlassButton(
    onPressed: popover.open,
    semanticLabel: 'Display settings',
    padding: EdgeInsets.zero,
    child: const Icon(Icons.tune),
  ),
)
```

## Placement

- Its height isn't known before it's laid out, so the popover opens **down** from an anchor in the upper half of the
  screen and **up** from one in the lower half.
- Like the menu, it lines up with the anchor on the side of the screen the anchor is on, and covers the anchor while
  open. Keep `width` within the screen: on a 320 px phone, a 320 px panel doesn't fit.
- `radius` sets the corners; it defaults to the menu's 31.5.

## Content that changes

The panel is rebuilt whenever the widget that builds the anchor rebuilds, so a `setState` there updates an open popover.
When the values live somewhere else, such as a `ValueNotifier`, a store or an `InheritedWidget`, listen to them inside
`popoverBuilder` so the open panel follows them too. The demo above keeps its filters in a `ValueNotifier` that both the
popover and the list listen to.

## Cost

- Glass controls inside the panel, such as a [slider](/components/slider) or a [switch](/components/switch), are glass
  on glass. That works, and costs one more capture level while the panel is open.
- When the anchor already sits on a glass bar, a plain `GestureDetector` is a cheaper anchor than a `GlassButton`. The
  site's settings button does exactly that.

## Accessibility

- The area around the open panel is announced with `barrierLabel` ("Dismiss"); it's how a screen reader closes it.
- Label the controls inside, e.g. `semanticLabel` on a `GlassSlider`, or `MergeSemantics` around a text and a switch.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A "Sort & filter" button whose popover changes the list behind it.
/// Assumes a GlassHost above the navigator, e.g. in MaterialApp.builder.
class SortButton extends StatelessWidget {
  const SortButton({required this.sort, required this.openNow, super.key});

  /// 0 = name, 1 = distance, 2 = rating. The list listens to these too.
  final ValueNotifier<int> sort;
  final ValueNotifier<bool> openNow;

  @override
  Widget build(BuildContext context) => GlassPopoverAnchor(
    width: 300,
    radius: 26,
    // Listens, so the panel follows each change while it is open.
    popoverBuilder: (BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[sort, openNow]),
      builder: (BuildContext context, Widget? _) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Sort by', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GlassSegmentedControl(
              segments: const <Widget>[Text('Name'), Text('Distance'), Text('Rating')],
              selectedIndex: sort.value,
              onSelected: (int i) => sort.value = i,
            ),
            const SizedBox(height: 8),
            MergeSemantics(
              child: Row(
                children: <Widget>[
                  const Expanded(child: Text('Open now')),
                  GlassSwitch(value: openNow.value, onChanged: (bool v) => openNow.value = v),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    builder: (BuildContext context, GlassMenuController popover) => GlassButton(
      onPressed: popover.open,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Icon(Icons.tune, size: 20), SizedBox(width: 6), Text('Sort & filter')],
      ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `popoverBuilder` | `WidgetBuilder` | **required** | The panel's content. Built under a text style and icon theme in the label colour. |
| `builder` | `Widget Function(BuildContext, GlassMenuController)` | **required** | Builds the anchor, such as a button, and gets the controller that opens the panel. |
| `controller` | `GlassMenuController?` | `null` | Your own controller, to open or close the panel from outside. Null makes an internal one. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `width` | `double` | `320` | The panel's width. |
| `radius` | `double` | `kGlassMenuRadius` (31.5) | The panel's corner radius. |
| `barrierLabel` | `String` | `'Dismiss'` | What a screen reader says for the area around the open panel; a tap there closes it. |

`GlassMenuController`: `open()`, `close()`, `bool get isOpen`. The panel closes only on a tap outside or `close()`.
''',
  ),

  // ------------------------------------------------------------------ morph
  Entry(
    section: Section.components,
    id: 'morph',
    title: 'Morph',
    icon: 'animation',
    summary:
        'One piece of glass that flows to the size of whatever child it holds: a button that becomes a panel, '
        'with a liquid neck while it moves.',
    api: <String>['GlassMorph', 'GlassMorphMotion', 'kGlassMorphSpacing'],
    source: 'lib/src/surface/glass_morph.dart',
    guide: r'''
`GlassMorph` holds one child on glass. Give it a child of another identity, another type or another `Key`, and the
glass flows to the new child's size while the old content fades out and the new fades in. It's how a button becomes its
menu in iOS 26.

You never type a size: the glass measures the child. `width` and `height` are overrides that pin one axis.

## When to use

- A control that turns into the panel it opens, in place: a "+" into a list of actions, a pill into a search field.
- A card whose content changes size, where the glass should follow rather than jump.
- **Not** for a menu that floats over the page and closes on a tap outside. Use the [menu](/components/menu) or the
  [popover](/components/popover), which bring their own overlay and barrier.

## Usage

```dart
Align(
  alignment: Alignment.topRight,
  child: GlassMorph(
    alignment: Alignment.topRight,
    borderRadius: open ? const BorderRadius.all(Radius.circular(28)) : kGlassCapsule,
    child: open
        ? ActionsPanel(key: const ValueKey<String>('panel'), onDone: close)
        : PlusButton(key: const ValueKey<String>('plus'), onTap: openPanel),
  ),
)
```

## Alignment: what holds still

`alignment` is the point of the glass that stays put **inside the morph's own box** while the size changes. The box is
placed by the morph's parent, so to hold a corner on the screen, the parent has to hold the same corner: an `Align`, a
`Positioned` with `top` and `right`, the end of a `Row`. Inside a `Center`, the glass grows from its centre whatever
`alignment` says. Give the parent and the morph the same alignment, as the demo does.

## Identity

The rule is `AnimatedSwitcher`'s. A child of the same type and key is updated in place: no morph, and the glass takes its
new size at once. Changing `width`, `height` or `borderRadius` alone does morph. A child swapped back while it is still
fading out keeps its state.

## Motion

- `GlassMorphMotion.fluid`, the default: a spring with a little overshoot.
- `GlassMorphMotion.calm`: no overshoot, a little slower, for large panels.
- Or your own: `GlassMorphMotion(duration: ..., bounce: ...)`, SwiftUI's spring parameters.
- With reduce motion on, there is no motion: the new child and its size arrive at once.

## Cost

- At rest it's one plain glass surface.
- While it grows, it's a [group](/foundations/groups) of two shapes, and a capture on every frame, because the glass
  changes size. Wrap a fixed-size ancestor that holds every size the morph takes in a `GlassTravel`, and the motion is
  drawn from the proxy already held.
- `spacing: 0` turns the neck off: a plain resize with the cross-fade, and no group even mid-morph.

## Accessibility

- Only the new child is hit and read by a screen reader while the glass moves.
- Label the controls inside the panel as you would anywhere else.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A "+" in the corner that flows into a panel of actions.
/// Assumes a GlassHost above, e.g. in MaterialApp.builder.
class NewThing extends StatefulWidget {
  const NewThing({super.key});

  @override
  State<NewThing> createState() => _NewThingState();
}

class _NewThingState extends State<NewThing> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Align(
    // The parent holds the top-right corner, and so does the glass.
    alignment: Alignment.topRight,
    child: GlassMorph(
      alignment: Alignment.topRight,
      borderRadius: _open ? const BorderRadius.all(Radius.circular(28)) : kGlassCapsule,
      child: _open
          ? Column(
              key: const ValueKey<String>('panel'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String name in <String>['Note', 'List', 'Photo'])
                  SizedBox(
                    width: 200,
                    child: TextButton(onPressed: () => setState(() => _open = false), child: Text(name)),
                  ),
              ],
            )
          : IconButton(
              key: const ValueKey<String>('plus'),
              tooltip: 'New',
              onPressed: () => setState(() => _open = true),
              icon: const Icon(Icons.add),
            ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | **required** | What the glass holds and measures. A child of another type or key starts a morph. |
| `alignment` | `AlignmentGeometry` | `Alignment.center` | The point that holds still in the morph's box. The parent has to hold it on screen. |
| `width` | `double?` | `null` | Pins the glass's width; the child is laid out at it. Null measures. |
| `height` | `double?` | `null` | Pins the glass's height; the child is laid out at it. Null measures. |
| `borderRadius` | `BorderRadius` | `24` all round | The corners around this child. `kGlassCapsule` is a pill at any size. |
| `motion` | `GlassMorphMotion` | `GlassMorphMotion.fluid` | The spring. `GlassMorphMotion.calm` has no overshoot. |
| `spacing` | `double` | `kGlassMorphSpacing` (16) | How far the neck reaches while the glass moves. Zero: no neck and no group. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `labelled` | `bool` | `true` | Whether a label is drawn over the glass, so the theme's label floor applies. |
| `onEnd` | `VoidCallback?` | `null` | Called when a morph has settled. |
''',
  ),
  // --------------------------------------------------------------- scaffold
  Entry(
    section: Section.components,
    id: 'scaffold',
    title: 'Scaffold',
    icon: 'space_dashboard',
    summary:
        'GlassScaffold is a whole screen wired the recommended way: a top bar in a scroll edge, an optional bottom bar '
        'and floating action, and a body that scrolls under them.',
    api: <String>['GlassScaffold', 'kGlassScaffoldBarHeight', 'kGlassScaffoldBarMargin', 'kGlassScaffoldActionGap'],
    source: 'lib/src/surface/glass_scaffold.dart',
    guide: r'''
`GlassScaffold` lays out a screen of glass: a [bar](/components/bar) at the top in a soft
[scroll edge](/foundations/scroll-edge), an optional bottom bar such as a [tab bar](/components/tab-bar), an optional
floating action, and a body that scrolls **under** all of them. It is composition and nothing else: every pixel is
drawn by a widget you could place yourself. It writes the arrangement once, so you don't have to measure the bars and
pad the list by hand.

## When to use

- A screen with a scrolling list or grid under a top bar, with or without a tab bar.
- **Not** for a screen whose glass doesn't sit at the edges, such as a full-screen map with a floating card. Use a
  `Stack` there.
- **Not** instead of a host for dialogs and sheets: those are built in the navigator's overlay and need the host above
  the navigator (see below).

## Usage

```dart
GlassScaffold(
  topBar: const GlassBar(
    child: Row(
      children: <Widget>[Icon(Icons.arrow_back), SizedBox(width: 12), Text('Library')],
    ),
  ),
  bottomBar: GlassTabBar(
    items: const <GlassTabItem>[
      GlassTabItem(icon: Icons.home, label: 'Home'),
      GlassTabItem(icon: Icons.search, label: 'Search'),
    ],
    selectedIndex: tab,
    onSelected: (int i) => setState(() => tab = i),
  ),
  // No padding: the list takes it from the media query.
  body: ListView.builder(itemCount: 50, itemBuilder: buildRow),
)
```

## The body

The body is laid out under the whole scaffold, so content scrolls under the glass. It is told the bars' extents as
`MediaQuery.padding`, the way Flutter's `Scaffold` does with `extendBody`. A `ListView`, `GridView` or
`CustomScrollView` with no padding of its own takes it from there: its first row starts below the top bar and its last
ends above the bottom bar.

A body that isn't a scroll view can read the same padding, or wrap itself in a `SafeArea`. The keyboard is not handled:
the body sees `MediaQuery.viewInsets` as it is.

## The bars

- **The top bar** is laid out `topBarHeight` tall (`kGlassScaffoldBarHeight`, 56), inside `barMargin` and the safe
  area. It is declared rather than measured because the scroll edge is laid out from it. `scrollEdge: null` drops the
  edge and keeps the bar lifted.
- **The bottom bar** takes its own height, which is measured: a tab bar is 60 tall on a phone and 44 on a wide screen.
- **The floating action** sits `kGlassScaffoldActionGap` (16) from the end edge and above the bottom bar. It is on the
  left in a right-to-left app.
- All three are [lifted](/foundations/above), so glass cards scrolling under them show through.
- The screen is a `GlassTabBarMinimizer`: a [tab bar](/components/tab-bar) in `bottomBar` with
  `minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown` collapses when the body scrolls down and expands when it
  scrolls up. Its box keeps its height, so the body's padding does not move. A bar that does not ask is not told.

## The host

With `host: null`, the default, the scaffold mounts a [GlassHost](/foundations/host) only when there is none above it,
and that host takes every default. `host: true` always mounts one, `host: false` never does.

> [!WARNING]
> Dialogs, sheets, menus and popovers are built in the navigator's overlay, which a host inside the route does not
> reach. For an app that uses any of them, put your own host in `MaterialApp(builder: ...)`, as in
> [Installation](/start/installation), and the scaffold uses it. That is also where you declare the backdrop, the
> finish and the rest.

The demo above is inside the site, whose host is above, so the scaffold mounts none.

## Cost

It costs what the same screen built by hand costs. While the body scrolls, the content under the bars changes on every
frame, so every frame of a scroll is one capture, for every glass on the screen at once. A still screen keeps its
capture. Being lifted is free over plain content, and one more snapshot per recorded frame over glass cards.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const LibraryApp());

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(),
    // The app's host, above the navigator: the scaffold uses it, and so do
    // dialogs and sheets.
    builder: (BuildContext context, Widget? child) => GlassHost(
      backdrop: const Color(0xFF101014),
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      child: child!,
    ),
    home: const LibraryPage(),
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const List<GlassTabItem> _tabs = <GlassTabItem>[
    GlassTabItem(icon: Icons.photo_library, label: 'Library'),
    GlassTabItem(icon: Icons.favorite, label: 'Saved'),
    GlassTabItem(icon: Icons.search, label: 'Search'),
  ];

  int _tab = 0;
  int _count = 30;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101014),
    body: GlassScaffold(
      topBar: GlassBar(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(_tabs[_tab].label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.more_horiz),
          ],
        ),
      ),
      bottomBar: GlassTabBar(items: _tabs, selectedIndex: _tab, onSelected: (int i) => setState(() => _tab = i)),
      floatingAction: GlassButton(
        onPressed: () => setState(() => _count++),
        semanticLabel: 'Add',
        padding: const EdgeInsets.all(14),
        child: const Icon(Icons.add),
      ),
      // Starts below the top bar, ends above the tab bar, scrolls under both.
      body: ListView.builder(
        itemCount: _count,
        itemBuilder: (BuildContext context, int i) => Container(
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: <Color>[
                HSVColor.fromAHSV(1, (i * 37) % 360.0, 0.7, 0.9).toColor(),
                HSVColor.fromAHSV(1, (i * 37 + 60) % 360.0, 0.8, 0.5).toColor(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `body` | `Widget` | **required** | The content. Laid out under the whole scaffold and told the bars' extents through `MediaQuery.padding`. |
| `topBar` | `Widget?` | `null` | The bar at the top, usually a `GlassBar`. Null for no top bar and no scroll edge. |
| `topBarHeight` | `double` | `kGlassScaffoldBarHeight` (56) | The height the top bar is laid out in. Must be ≥ 0. |
| `scrollEdge` | `GlassScrollEdgeStyle?` | `GlassScrollEdgeStyle.soft` | The scroll edge under the top bar. Null for none: the bar is only lifted. |
| `bottomBar` | `Widget?` | `null` | The bar at the bottom, usually a `GlassTabBar`, at its own height. Lifted. |
| `floatingAction` | `Widget?` | `null` | A control at the end edge above the bottom bar, usually a `GlassButton`, at its own size. Lifted. |
| `barMargin` | `EdgeInsets` | `kGlassScaffoldBarMargin` | The space around each bar, inside the safe area. Under the bottom bar, the larger of this and the safe area. |
| `host` | `bool?` | `null` | Whether to mount a `GlassHost`: null when there is none above, `true` always, `false` never. |
| `key` | `Key?` | `null` | |

`double topExtentFor(EdgeInsets safe)`: the top bar's extent from the top of the screen, which the body is told as its
top padding: the safe area, `barMargin` above and below, and `topBarHeight`.

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassScaffoldBarHeight` | `56` | The default `topBarHeight`. Material's toolbar height. |
| `kGlassScaffoldBarMargin` | `EdgeInsets.fromLTRB(12, 8, 12, 8)` | The default `barMargin`. |
| `kGlassScaffoldActionGap` | `16` | How far the floating action stands from the end edge and from the bottom bar. |
''',
  ),
];
