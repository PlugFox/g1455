# Page control

> GlassPageControl is the row of page dots on a glass capsule: it follows a PageView as it scrolls, a tap steps toward its side, and a drag scrubs.

- Live: https://g1455.plugfox.dev/components/page-control
- API: [`GlassPageControl`](https://pub.dev/documentation/g1455/latest/g1455/GlassPageControl-class.html), [`kGlassPageDot`](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageDot-constant.html), [`kGlassPageDotGap`](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageDotGap-constant.html), [`kGlassPageControlHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassPageControlHeight-constant.html)
- Source: [`lib/src/surface/glass_page_control.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_page_control.dart)

`GlassPageControl` is iOS's `UIPageControl` with its platter: a dot per page on a small glass capsule. The current dot is
wider and in the full label colour, the others round and dimmed, and between two pages the two dots trade width and
brightness continuously, so the control follows a swipe rather than jumping when it ends.

A tap moves **one page toward the side tapped**, as iOS's does, not to the dot under the finger: an 8 px dot is not a
target anyone can hit. A drag along the capsule scrubs, the page following the dot under the finger.

## When to use

- The pages of a carousel, an onboarding flow or a photo gallery, over the pages themselves.
- **Not** for more than a dozen or so pages: the row grows with the count, and iOS's shrinking of the end dots is not
  here.
- **Not** for choosing among labelled views. That is a [segmented control](../components/segmented-control.md).

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

## Complete example

```dart
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
```

## API

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
| `key` | `Key?` | `null` | |

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassPageDot` | `8` | A dot's diameter. Layout, not a reading. |
| `kGlassPageDotGap` | `8` | The space between two dots. |
| `kGlassPageControlHeight` | `26` | The capsule's height. Laid out at least 44 tall. |
