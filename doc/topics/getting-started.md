Liquid Glass for Flutter: refraction, blur, tint and a rim over the live
backdrop, in the shape the engine already draws. Every name in this reference
is live on the site, with its guide, its code and a demo:
[g1455.plugfox.dev](https://g1455.plugfox.dev).

## Install

```bash
flutter pub add g1455
```

Flutter 3.47 or later. Optionally compile the shaders before the first frame,
so the first glass on screen does not wait for them:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GlassHost.precache();
  runApp(const App());
}
```

## One host, then glass anywhere under it

A [GlassHost](../g1455/GlassHost-class.html) captures what is painted under all of its glass, once, into one
shared atlas; every surface below it samples its own slot of that capture. Put
it above the navigator, so dialogs, sheets and menus are under it as well as
the screens:

```dart
MaterialApp(
  builder: (BuildContext context, Widget? navigator) => GlassHost(
    // A feed of colours rather than one flat colour: pick the labels against
    // any backdrop, and dim the glass if they need it.
    richBackdrop: true,
    minLabelContrast: kTextContrastAA,
    child: navigator!,
  ),
  home: const Home(),
)
```

Then use the glass like any widget. A bar over a list that scrolls under it:

```dart
Stack(
  children: <Widget>[
    ListView.builder(
      padding: const EdgeInsets.only(top: 120),
      itemCount: 40,
      itemBuilder: (BuildContext context, int i) => ListTile(title: Text('Row $i')),
    ),
    const Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(child: GlassBar(child: Text('Library'))),
    ),
  ],
)
```

A frame the list moves is one capture for every glass on the screen; a frame
it rests is none.

## Where to go next

| To… | Read |
|---|---|
| understand the host, the surface and the finishes | [Foundations](../topics/Foundations-topic.html) |
| put bars, buttons, switches, sliders and tab bars on screen | [Panels and controls](../topics/Panels%20and%20controls-topic.html) |
| open an alert, a sheet, a menu or a popover | [Modals](../topics/Modals-topic.html) |
| fuse glass, move it for free, morph it, stack it | [Composition](../topics/Composition-topic.html) |
| put glass over a video, a map or a platform view | [Capture control](../topics/Capture%20control-topic.html) |
| keep the cost down and honour the device | [Cost and policy](../topics/Cost%20and%20policy-topic.html) |

> **Note:** the API is 0.x and still changes between minor versions. Every
> change is in the [changelog](https://pub.dev/packages/g1455/changelog).
