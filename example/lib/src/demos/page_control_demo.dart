import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/capture_meter.dart';
import '../widgets/stage.dart';

/// A gallery: photos in a `PageView`, and a page control over them that
/// follows the swipe and turns the page.
class PageControlDemo extends StatefulWidget {
  const PageControlDemo({super.key});

  @override
  State<PageControlDemo> createState() => _PageControlDemoState();
}

class _PageControlDemoState extends State<PageControlDemo> {
  final PageController _pages = PageController();
  int _count = 5;
  int _page = 0;
  bool _wide = true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _setCount(int count) {
    setState(() => _count = count);
    if (_page >= count) {
      _pages.jumpToPage(count - 1);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DemoStage(
        height: 340,
        background: const ColoredBox(color: Color(0xFF000000)),
        knobs: <Widget>[
          KnobChoice<int>(label: 'Pages', values: const <int>[3, 5, 8], selected: _count, onChanged: _setCount),
          KnobChoice<bool>(
            label: 'Current dot',
            values: const <bool>[true, false],
            selected: _wide,
            labelOf: (bool w) => w ? 'Wide' : 'Round',
            onChanged: (bool w) => setState(() => _wide = w),
          ),
        ],
        hint:
            'Swipe the photos, tap beside the current dot, or drag along the dots. '
            'The count under the stage is the page view moving under the glass, not the dots.',
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: _count,
                onPageChanged: (int i) => setState(() => _page = i),
                itemBuilder: (BuildContext context, int i) => PhotoBackdrop(seed: 50 + i),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: GlassPageControl(
                  count: _count,
                  controller: _pages,
                  currentDotWidth: _wide ? 20 : kGlassPageDot,
                  semanticLabel: 'Photo',
                ),
              ),
            ),
          ],
        ),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: CaptureMeter()),
    ],
  );
}
