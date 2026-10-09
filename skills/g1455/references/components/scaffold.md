# Scaffold

> GlassScaffold is a whole screen wired the recommended way: a top bar in a scroll edge, an optional bottom bar and floating action, and a body that scrolls under them.

- Live: https://g1455.plugfox.dev/components/scaffold
- API: [`GlassScaffold`](https://pub.dev/documentation/g1455/latest/g1455/GlassScaffold-class.html), [`kGlassScaffoldBarHeight`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScaffoldBarHeight-constant.html), [`kGlassScaffoldBarMargin`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScaffoldBarMargin-constant.html), [`kGlassScaffoldActionGap`](https://pub.dev/documentation/g1455/latest/g1455/kGlassScaffoldActionGap-constant.html)
- Source: [`lib/src/surface/glass_scaffold.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_scaffold.dart)

`GlassScaffold` lays out a screen of glass: a [bar](../components/bar.md) at the top in a soft
[scroll edge](../foundations/scroll-edge.md), an optional bottom bar such as a [tab bar](../components/tab-bar.md), an optional
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
- All three are [lifted](../foundations/above.md), so glass cards scrolling under them show through.
- The screen is a `GlassTabBarMinimizer`: a [tab bar](../components/tab-bar.md) in `bottomBar` with
  `minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown` collapses when the body scrolls down and expands when it
  scrolls up. Its box keeps its height, so the body's padding does not move. A bar that does not ask is not told.

## The host

With `host: null`, the default, the scaffold mounts a [GlassHost](../foundations/host.md) only when there is none above it,
and that host takes every default. `host: true` always mounts one, `host: false` never does.

> [!WARNING]
> Dialogs, sheets, menus and popovers are built in the navigator's overlay, which a host inside the route does not
> reach. For an app that uses any of them, put your own host in `MaterialApp(builder: ...)`, as in
> [Installation](../start/installation.md), and the scaffold uses it. That is also where you declare the backdrop, the
> finish and the rest.

The demo above is inside the site, whose host is above, so the scaffold mounts none.

## Cost

It costs what the same screen built by hand costs. While the body scrolls, the content under the bars changes on every
frame, so every frame of a scroll is one capture, for every glass on the screen at once. A still screen keeps its
capture. Being lifted is free over plain content, and one more snapshot per recorded frame over glass cards.

## Complete example

```dart
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
```

## API

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

### Constants

| Name | Value | Description |
|---|---|---|
| `kGlassScaffoldBarHeight` | `56` | The default `topBarHeight`. Material's toolbar height. |
| `kGlassScaffoldBarMargin` | `EdgeInsets.fromLTRB(12, 8, 12, 8)` | The default `barMargin`. |
| `kGlassScaffoldActionGap` | `16` | How far the floating action stands from the end edge and from the bottom bar. |
