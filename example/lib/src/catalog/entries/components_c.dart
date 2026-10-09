import '../catalog.dart';

/// The small controls: a stepper, page dots, a search bar and a badge.
const List<Entry> kComponentEntriesC = <Entry>[
  // ---------------------------------------------------------------- stepper
  Entry(
    section: Section.components,
    id: 'stepper',
    title: 'Stepper',
    icon: 'exposure',
    summary:
        'GlassStepper is a minus and a plus in one glass capsule, as UIStepper: a held half repeats, the end at a '
        'limit is disabled, and a press costs no capture.',
    api: <String>['GlassStepper', 'kGlassStepperSize', 'kGlassStepperRepeatDelay', 'kGlassStepperRepeatInterval'],
    source: 'lib/src/surface/glass_stepper.dart',
    guide: r'''
`GlassStepper` is iOS's `UIStepper` on glass: one capsule split by a hairline into a minus and a plus. A press steps the
value at once; held, the half repeats, half a second after the press and then ten times a second, until the finger lifts
or the value reaches a limit. At a limit the half that would pass it is disabled and its glyph dims, unless the stepper
`wraps`.

The stepper shows no number. As on iOS, the value goes in a label beside it, which you rebuild from `onChanged`.

## When to use

- A small count changed one step at a time: copies to print, guests, a quantity in a cart, a font size.
- **Not** for a wide range, where tapping a hundred times is no way to get there. Use a [slider](/components/slider),
  with `divisions` if the value is whole.
- **Not** as two [GlassButton](/components/button)s side by side. Two buttons are two surfaces; the stepper is one, and
  draws the divider and the pressed half inside it.

## Usage

```dart
Row(
  children: <Widget>[
    Expanded(child: Text('Copies: $copies')),
    GlassStepper(
      value: copies.toDouble(),
      min: 1,
      max: 10,
      semanticLabel: 'Copies',
      onChanged: (double v) => setState(() => copies = v.round()),
    ),
  ],
)
```

The value is a `double`, so a fractional `step` works too: `step: 0.5` for a font size. `onChanged: null` disables both
halves.

## Behaviour

- `autorepeat` (on by default) repeats a held half after
  [kGlassStepperRepeatDelay](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatDelay-constant.html)
  (500 ms), every [kGlassStepperRepeatInterval](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperRepeatInterval-constant.html)
  (100 ms). The repeat stops at a limit.
- `wraps` goes from `max` to `min` and back instead of stopping, and keeps both halves enabled.
- A held half brightens its own cell by the finish's rim colour, clipped to the capsule, as a
  [toolbar](/components/toolbar) cell does. `pressedOverlay` replaces that colour.

## Size

The capsule is [kGlassStepperSize](https://pub.dev/documentation/g1455/latest/g1455/kGlassStepperSize-constant.html),
94 × 32: `UIStepper`'s width and the [segmented control](/components/segmented-control)'s track. The control is laid
out 44 tall around it, so a tap a little above or below still lands. **Layout, not a reading**: the iOS 26 stepper was
not among the controls measured for the package.

## Cost

One surface, whatever is held. A press, the repeat and a glyph dimming at a limit are drawn inside the glass, so none
of them is a capture. Keep the label you change beside the stepper on glass too, as the demo does on a card, and a
press repaints nothing under any glass: the count under the stage stays where it was.

## Accessibility

A screen reader hears one adjustable control: its `semanticLabel` and the value, which it increases or decreases by
`step`. `semanticFormatterCallback` says the value your way, "12.5 points" rather than "12.5".

A focused stepper steps with the arrow keys: up and the arrow toward the plus increase, down and the other decrease. The
focus ring is drawn inside the glass, so it takes no capture, and a disabled stepper takes no focus. Under a
right-to-left `Directionality` the stepper is mirrored, with the minus at the end, and so are the left and right arrows.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A print dialog's options on a glass card.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class PrintOptions extends StatefulWidget {
  const PrintOptions({super.key});

  @override
  State<PrintOptions> createState() => _PrintOptionsState();
}

class _PrintOptionsState extends State<PrintOptions> {
  int _copies = 1;
  double _scale = 100;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Copies: $_copies')),
              GlassStepper(
                value: _copies.toDouble(),
                min: 1,
                max: 99,
                semanticLabel: 'Copies',
                onChanged: (double v) => setState(() => _copies = v.round()),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(child: Text('Scale: ${_scale.round()}%')),
              GlassStepper(
                value: _scale,
                min: 25,
                max: 400,
                step: 25,
                semanticLabel: 'Scale',
                semanticFormatterCallback: (double v) => '${v.round()} percent',
                onChanged: (double v) => setState(() => _scale = v),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `value` | `double` | **required** | The value shown. The stepper holds none of its own. |
| `onChanged` | `ValueChanged<double>?` | **required** | Called with the new value. Null disables both halves. |
| `min` | `double` | `0` | The lowest value. At most `max`. |
| `max` | `double` | `100` | The highest value. |
| `step` | `double` | `1` | How far one press moves the value. Above 0. |
| `wraps` | `bool` | `false` | Past `max` goes to `min` and back, instead of stopping. |
| `autorepeat` | `bool` | `true` | A held half repeats until the finger lifts or a limit is reached. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `pressedOverlay` | `Color?` | `null` | Added over the held half. Null takes the finish's rim colour. |
| `semanticLabel` | `String?` | `null` | What a screen reader calls the control. |
| `semanticFormatterCallback` | `String Function(double)?` | `null` | How a screen reader says the value. |
| `focusNode` | `FocusNode?` | `null` | The stepper's focus. Null makes one the stepper owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the stepper is built. |
| `key` | `Key?` | `null` | |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassStepperSize` | `Size(94, 32)` | The capsule. Laid out at least 44 tall. Layout, not a reading. |
| `kGlassStepperRepeatDelay` | `Duration(milliseconds: 500)` | How long a held half waits before it repeats. |
| `kGlassStepperRepeatInterval` | `Duration(milliseconds: 100)` | How often it repeats after that. |
''',
  ),

  // ----------------------------------------------------------- page-control
  Entry(
    section: Section.components,
    id: 'page-control',
    title: 'Page control',
    icon: 'more_horiz',
    summary:
        'GlassPageControl is the row of page dots on a glass capsule: it follows a PageView as it scrolls, a tap '
        'steps toward its side, and a drag scrubs.',
    api: <String>['GlassPageControl', 'kGlassPageDot', 'kGlassPageDotGap', 'kGlassPageControlHeight'],
    source: 'lib/src/surface/glass_page_control.dart',
    guide: r'''
`GlassPageControl` is iOS's `UIPageControl` with its platter: a dot per page on a small glass capsule. The current dot is
wider and in the full label colour, the others round and dimmed, and between two pages the two dots trade width and
brightness continuously, so the control follows a swipe rather than jumping when it ends.

A tap moves **one page toward the side tapped**, as iOS's does, not to the dot under the finger: an 8 px dot is not a
target anyone can hit. A drag along the capsule scrubs, the page following the dot under the finger.

## When to use

- The pages of a carousel, an onboarding flow or a photo gallery, over the pages themselves.
- **Not** for more than a dozen or so pages: the row grows with the count, and iOS's shrinking of the end dots is not
  here.
- **Not** for choosing among labelled views. That is a [segmented control](/components/segmented-control).

## Usage

Give it the `PageView`'s controller, and the two follow each other with nothing else to wire:

```dart
Stack(
  children: <Widget>[
    PageView(controller: pages, children: photos),
    Align(
      alignment: Alignment.bottomCenter,
      child: GlassPageControl(count: photos.length, controller: pages),
    ),
  ],
)
```

Without a controller, it shows `currentPage` and reports a tap or a drag to `onPageChanged`, for you to pass back.
`onPageChanged` is called with a controller too, with each page the view settles on.

## Layout

- The capsule is [kGlassPageControlHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageControlHeight-constant.html)
  (26) tall and as wide as its dots: [kGlassPageDot](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageDot-constant.html)
  (8) each, [kGlassPageDotGap](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageDotGap-constant.html) (8) apart,
  and the current one `currentDotWidth` (20) wide. `currentDotWidth: kGlassPageDot` tells the page by brightness alone.
- The control is laid out at least 44 × 44, so the taps around a short row land.
- **Layout, not a reading**: iOS 26's page control was not among the controls measured for the package.

## Cost

One surface. The dots are drawn inside the glass from the controller's position, without a build, so a page turning, a
tap and a scrub repaint the glass and nothing else, and none of that is a capture.

The `PageView` is another matter. Pages moving under glass are content changing, and the host captures every frame they
move: 43 captures a swipe in the package's tests, the same with the dots following and with dots that stay put. That is
the price of glass over a moving page, not of the control. The count under the demo shows it.

## Accessibility

A screen reader hears one adjustable control, "Page 2 of 5" by default, and turns the page with increase and decrease.
`semanticLabel` names what the pages are; `semanticFormatterCallback` says the page your way.

A focused page control turns the page with the arrow keys; a control with no `onPageChanged` and no `controller` is a
display and takes no focus. Under a right-to-left `Directionality` the first page's dot is at the right, and taps, drags
and the left and right arrows follow it. When `count` shrinks below the current page, the control shows the last page.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// An onboarding carousel with page dots over it.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  static const List<(String, Color)> _pages = <(String, Color)>[
    ('Welcome', Color(0xFF0A84FF)),
    ('Sync everywhere', Color(0xFFBF5AF2)),
    ('Share with friends', Color(0xFFFF9F0A)),
  ];

  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      PageView(
        controller: _controller,
        children: <Widget>[
          for (final (String title, Color colour) in _pages)
            ColoredBox(
              color: colour,
              child: Center(
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 28)),
              ),
            ),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
        child: Center(
          // Follows the swipe, and a tap or a drag turns the view.
          child: GlassPageControl(count: _pages.length, controller: _controller, semanticLabel: 'Onboarding'),
        ),
      ),
    ],
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `count` | `int` | **required** | How many pages. At least 1. |
| `currentPage` | `int` | `0` | The current page, when there is no `controller`. |
| `onPageChanged` | `ValueChanged<int>?` | `null` | Called with the page a tap, a drag or a screen reader picks, and with a controller, each page the view settles on. Null with no controller makes the control a display. |
| `controller` | `PageController?` | `null` | The page view to follow and turn. Null makes `currentPage` the page. |
| `currentDotWidth` | `double` | `20` | The current dot's width. At least `kGlassPageDot`. |
| `duration` | `Duration` | `Duration(milliseconds: 300)` | How long a tap takes to turn the page. |
| `curve` | `Curve` | `Curves.easeInOut` | The curve of that turn. |
| `finish` | `GlassFinish?` | `null` | The glass. Null takes the theme's. |
| `semanticLabel` | `String?` | `null` | What a screen reader says the control is for. |
| `semanticFormatterCallback` | `String Function(int page, int count)?` | `null` | How a screen reader says the page, from 0, of `count`. Null says "Page 2 of 5". |
| `focusNode` | `FocusNode?` | `null` | The page control's focus. Null makes one the page control owns. |
| `autofocus` | `bool` | `false` | Take the focus as soon as the page control is built. |
| `key` | `Key?` | `null` | |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassPageDot` | `8` | A dot's diameter. Layout, not a reading. |
| `kGlassPageDotGap` | `8` | The space between two dots. |
| `kGlassPageControlHeight` | `26` | The capsule's height. Laid out at least 44 tall. |
''',
  ),

  // ------------------------------------------------------------- search-bar
  Entry(
    section: Section.components,
    id: 'search-bar',
    title: 'Search bar',
    icon: 'manage_search',
    summary:
        'GlassSearchBar is the glass search field with a clear button and a Cancel that slides in on focus. One '
        'surface; the slide is its one cost, a capture a frame for 250 ms.',
    api: <String>['GlassSearchBar', 'GlassTextField.search', 'kGlassFieldHeight'],
    source: 'lib/src/surface/glass_search_bar.dart',
    guide: r'''
`GlassSearchBar` is `UISearchBar` with `showsCancelButton`, as an iPhone shows it: the glass search field of
[GlassTextField.search](/components/text-field), a clear button inside it while there is text, and a Cancel beside it
that slides in while the field has the focus.

The clear button, a filled circle with a cross at the field's end, empties the field and keeps the focus. Cancel empties
it, lets go of the focus and calls `onCancel`. Cancel is plain text in `cancelColor`, beside the glass rather than on
it, as iOS draws it.

## When to use

- The search at the top of a list or a screen, in a [bar](/components/bar) or floating on its own.
- **Not** for a field that is not a search: use a [GlassTextField](/components/text-field), which has no Cancel.
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
''',
    code: r'''
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
''',
    properties: r'''
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
''',
  ),

  // ------------------------------------------------------------------ badge
  Entry(
    section: Section.components,
    id: 'badge',
    title: 'Badge',
    icon: 'notifications',
    summary:
        'GlassBadge puts a count, a label or a dot on the corner of an icon or a tab: an opaque red capsule, not glass, '
        'as iOS 26 draws one. It costs no surface.',
    api: <String>['GlassBadge', 'kGlassBadgeRed', 'kGlassBadgeHeight', 'kGlassBadgeDot'],
    source: 'lib/src/surface/glass_badge.dart',
    guide: r'''
`GlassBadge` marks the corner of its child with a count, a short label or a dot, the way iOS 26 marks a tab, an app icon
or a toolbar button. **It is not glass, and that is Apple's call rather than a saving**: a badge has to read at a glance
over any backdrop, and a translucent red would be a different colour over every one. So it is an opaque capsule of
`systemRed` with white text, on the glass and not of it.

## When to use

- An unread count on a [tab](/components/tab-bar), a [toolbar](/components/toolbar) icon or a [button](/components/button).
- A dot for "something new" where the number does not matter.
- **Not** as a glass pill of your own: that would be one more surface, and a red that changes with the backdrop.

## Usage

On a tab, through `iconBuilder`, so the icon keeps the colour the bar gives it:

```dart
GlassTabItem(
  label: 'Mail',
  iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
    count: unread,
    child: Icon(Icons.mail, color: look.color, size: look.iconSize),
  ),
)
```

On a toolbar icon:

```dart
GlassToolbarItem(
  icon: GlassBadge(count: notifications, child: const Icon(Icons.notifications_none)),
  label: 'Notifications',
  onPressed: openNotifications,
)
```

## What it shows

- With `count`, the number, or "99+" past `maxCount`, and **nothing at all at 0**, as an app icon's badge disappears.
- With `label`, that text. A badge takes a count or a label, not both.
- With neither, a dot [kGlassBadgeDot](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeDot-constant.html)
  (10) across.
- `isVisible: false` hides it and leaves the child.
- Its centre sits on the child's top trailing corner; `offset` moves it. Without a child it is the badge alone, for a row
  or a cell to place.

## Colour

[kGlassBadgeRed](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeRed-constant.html) is UIKit's documented
`systemRed` in the light appearance, (255, 59, 48). The dark appearance's is (255, 69, 58); the package has no
appearance of its own, so pass that as `color` where your app is dark. The height,
[kGlassBadgeHeight](https://pub.dev/documentation/g1455/latest/g1455/kGlassBadgeHeight-constant.html) (18), the dot and
the type size are layout, not readings.

## Cost

None in the glass. A badge takes no slot in the atlas and does not count in the ledger, and a count changing on a glass
bar is a repaint inside the glass, which is no capture. On a [tab bar](/components/tab-bar) the count reaches the badge
through the bar's items, so changing it rebuilds the bar, which costs one capture for now.

## Accessibility

A screen reader hears `semanticLabel`, or the count or label as written. Give a dot a `semanticLabel` ("New"), or it says
nothing, since nothing is all it shows.
''',
    code: r'''
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

/// A mail app's tab bar, the unread count on the Mail tab.
/// Assumes a GlassHost above the navigator (MaterialApp.builder).
class MailTabs extends StatelessWidget {
  const MailTabs({required this.unread, required this.tab, required this.onTab, super.key});

  final int unread;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: <GlassTabItem>[
      GlassTabItem(
        label: 'Mail',
        iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
          // Nothing at 0; "99+" past 99.
          count: unread,
          semanticLabel: '$unread unread',
          child: Icon(Icons.mail, color: look.color, size: look.iconSize),
        ),
      ),
      const GlassTabItem(icon: Icons.people, label: 'Contacts'),
      GlassTabItem(
        label: 'Settings',
        // A dot: an update waits.
        iconBuilder: (BuildContext context, GlassTabItemLook look) => GlassBadge(
          semanticLabel: 'Update available',
          child: Icon(Icons.settings, color: look.color, size: look.iconSize),
        ),
      ),
    ],
    selectedIndex: tab,
    onSelected: onTab,
  );
}
''',
    properties: r'''
| Parameter | Type | Default | Description |
|---|---|---|---|
| `count` | `int?` | `null` | The number shown; nothing at 0, "`maxCount`+" past it. Not with `label`. |
| `label` | `String?` | `null` | A short text instead of a number. Not with `count`. |
| `maxCount` | `int` | `99` | The largest number shown as it is. Above 0. |
| `isVisible` | `bool` | `true` | Whether the badge is drawn. The child always is. |
| `color` | `Color` | `kGlassBadgeRed` | The capsule's fill. |
| `textColor` | `Color` | `Color(0xFFFFFFFF)` | The count's or label's colour. |
| `offset` | `Offset` | `Offset.zero` | Moves the badge from the child's top trailing corner. |
| `semanticLabel` | `String?` | `null` | What a screen reader says. Null says the count or label; a dot then says nothing. |
| `child` | `Widget?` | `null` | What the badge marks. Null is the badge alone. |
| `key` | `Key?` | `null` | |

## Constants

| Name | Value | Description |
|---|---|---|
| `kGlassBadgeRed` | `Color(0xFFFF3B30)` | `systemRed` in the light appearance. |
| `kGlassBadgeHeight` | `18` | The height with a count, and the smallest width. Layout, not a reading. |
| `kGlassBadgeDot` | `10` | A dot's diameter. Layout, not a reading. |
''',
  ),
];
