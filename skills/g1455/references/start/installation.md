# Installation

> Add the package, put one GlassHost above the navigator, and lay the first glass over content.

- Live: https://g1455.plugfox.dev/start/installation
- API: [`GlassHost`](https://pub.dev/documentation/g1455/latest/g1455/GlassHost-class.html), [`GlassBar`](https://pub.dev/documentation/g1455/latest/g1455/GlassBar-class.html), [`kTextContrastAA`](https://pub.dev/documentation/g1455/latest/g1455/kTextContrastAA-constant.html)
- Source: [`lib/src/surface/glass_host.dart`](https://github.com/PlugFox/g1455/blob/master/lib/src/surface/glass_host.dart)

g1455 draws Liquid Glass in Flutter: refraction, blur, tint and a rim over whatever is painted behind it. Getting it on
screen takes three steps: add the package, put one `GlassHost` at the top of the app, and place glass over some content.

The package is pure Dart and shaders. It ships no platform code, so there is nothing to configure in Xcode or Gradle.

## Install

```bash
flutter pub add g1455
```

It needs Flutter 3.47 or later. Then import it wherever you use glass:

```dart
import 'package:g1455/g1455.dart';
```

## Add the host

Every piece of glass needs a [GlassHost](../foundations/host.md) above it. The host records what is painted under all the
glass of the screen into one shared image, and every surface samples its own slice of it. Without a host, a glass
surface draws **no glass at all**, only its child.

Put the host in the `builder:` of your `MaterialApp` (or `WidgetsApp`, `CupertinoApp`). That places it above the
navigator, which is also where dialogs, sheets, menus and popovers are built, so they find the host too:

```dart
MaterialApp(
  builder: (BuildContext context, Widget? child) => GlassHost(child: child!),
  home: const HomePage(),
)
```

One host per app is the normal setup. Don't nest a host around each widget.

## The first glass

Glass shows what is behind it, so it needs something behind it: lay it over content in a `Stack`.
[GlassBar](../components/bar.md) is a floating capsule for navigation that also picks a legible label colour for its
children:

```dart
Stack(
  children: <Widget>[
    Positioned.fill(child: content), // what the glass refracts
    const Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: GlassBar(child: Text('Library')),
    ),
  ],
)
```

The "Code" tab has a complete `main.dart` with a scrolling list under a bar.

> [!TIP]
> Tell the host what is behind the glass. For a list of photos or a feed, pass `richBackdrop: true` and
> `minLabelContrast: kTextContrastAA`; over a flat colour, pass `backdrop:`. Labels are then chosen and kept readable
> for that case. See [Legibility & theme](../foundations/legibility.md).

## The first frame has no glass

The host captures the backdrop after a frame has been painted, and the glass draws that capture on the next frame. So
the very first frame of a screen shows the glass's children without the glass itself. That is by design and is not
visible in practice, but it matters in widget tests: pump one more frame before you look for glass.

## Compile the shaders before the first frame

The host loads the package's shaders when it mounts, and a shader is compiled asynchronously. Until it lands, glass
that has a capture draws a stand-in: the captured, blurred backdrop clipped to its shape, with no tint, rim or bend.
Compile them before `runApp` and the first frame that has a capture is drawn through the optics:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlassHost.precache();
  runApp(const GlassApp());
}
```

`GlassHost.precache()` shares the loads a host starts on its own, so nothing is compiled twice, and once the programs
are in it costs nothing. `group: false` and `ripple: false` leave out the programs of [groups](../foundations/groups.md) and
the [ripple](../foundations/ripple.md) for an app that uses neither. It completes with the error of a load that fails, so
catch it if the app should start regardless.

## Next steps

- [How it works](../start/how-it-works.md): one capture for the whole screen, and only when something changed.
- [What the app declares](../start/declarations.md): the backdrop, reduce transparency, contrast, thermal state.
- [GlassHost](../foundations/host.md) and [GlassSurface](../foundations/surface.md): the two building blocks.
- [Finishes](../foundations/finishes.md): regular, clear and frosted glass.
- [Scaffold](../components/scaffold.md): a whole screen, a bar, a tab bar and a list scrolling under them, wired for you.
- The components: [Bar](../components/bar.md), [Button](../components/button.md), [Card](../components/card.md),
  [Switch](../components/switch.md), [Slider](../components/slider.md), [Tab bar](../components/tab-bar.md),
  [Alert](../components/alert.md), [Sheet](../components/sheet.md) and more.
- [Adaptive glass](../foundations/adaptive.md): glass that reads its backdrop, for screens over photographs.
- [Performance](../foundations/performance.md): what glass costs and how to keep it cheap.

## Complete example

```dart
import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compiles the shaders before the first frame, so the first glass on screen
  // is drawn through its optics.
  await GlassHost.precache();
  runApp(const GlassApp());
}

class GlassApp extends StatelessWidget {
  const GlassApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glass',
    theme: ThemeData.dark(),
    // One host for the whole app, above the navigator, so pages, dialogs,
    // sheets and menus are all under it.
    builder: (BuildContext context, Widget? child) => GlassHost(
      // A feed of colourful tiles scrolls under the glass: choose labels for
      // the worst case, and keep them at WCAG AA.
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      backdrop: const Color(0xFF101014),
      child: child!,
    ),
    home: const LibraryPage(),
  );
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Stack(
        children: <Widget>[
          // The content: what the glass refracts.
          ListView.builder(
            padding: EdgeInsets.fromLTRB(16, safe.top + 76, 16, safe.bottom + 16),
            itemCount: 30,
            itemBuilder: (BuildContext context, int i) => Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
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
          // The glass: a bar floating over the list.
          Positioned(
            top: safe.top + 8,
            left: 16,
            right: 16,
            child: const GlassBar(
              child: Row(
                children: <Widget>[
                  Icon(Icons.photo_library_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.search),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```
