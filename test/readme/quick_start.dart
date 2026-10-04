import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // The host goes above the navigator, so dialogs, sheets and menus are
    // under it as well as the screens.
    builder: (BuildContext context, Widget? navigator) => GlassHost(
      // The backdrop is a feed of colours rather than one flat colour: pick
      // the labels against any backdrop, and dim the glass if they need it.
      richBackdrop: true,
      minLabelContrast: kTextContrastAA,
      child: navigator!,
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: <Widget>[
        // What the glass refracts: coloured tiles, scrolling under both bars.
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
          itemCount: 40,
          itemBuilder: (BuildContext context, int i) => Container(
            height: 96,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: HSLColor.fromAHSL(1, i * 27.0 % 360, 0.7, 0.55).toColor(),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 16,
          right: 16,
          child: SafeArea(
            child: GlassBar(child: Text('Library')),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: SafeArea(
            child: GlassTabBar(
              items: const <GlassTabItem>[
                GlassTabItem(icon: Icons.photo_library_outlined, label: 'Library'),
                GlassTabItem(icon: Icons.favorite_border, label: 'For You'),
                GlassTabItem(icon: Icons.search, label: 'Search'),
              ],
              selectedIndex: _tab,
              onSelected: (int i) => setState(() => _tab = i),
            ),
          ),
        ),
      ],
    ),
  );
}
