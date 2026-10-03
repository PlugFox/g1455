import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';

/// Content scrolling under the bars, and a few controls floating over it.
///
/// The commonest screen there is, and the one the capture policy is about: a
/// scroll changes what is under every glass on every frame, and a still list
/// changes nothing, so nothing is retaken.
///
/// The lens is clear glass that magnifies. It moves inside a [GlassTravel]
/// over the whole page, so dragging it over a still list samples the proxy
/// already held. It is a sibling of the other glass, not a child of it, so it
/// shows what is under *them* — glass on glass is written inside the glass it
/// stands on (see the tab bar's drop).
class ScrollPage extends StatefulWidget {
  const ScrollPage({required this.insets, super.key});

  /// What the bars cover, top and bottom.
  final EdgeInsets insets;

  @override
  State<ScrollPage> createState() => _ScrollPageState();
}

class _ScrollPageState extends State<ScrollPage> {
  double _level = 0.4;
  bool _lens = false;
  Offset _lensAt = const Offset(110, 360);

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: ListView.builder(
          padding: EdgeInsets.only(top: widget.insets.top + 8, bottom: widget.insets.bottom + 8),
          itemCount: 40,
          itemBuilder: (BuildContext context, int i) => GradientTile(index: i),
        ),
      ),
      if (_lens)
        Positioned.fill(
          child: GlassTravel(
            child: RepaintBoundary(
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: _lensAt.dx - _kLens / 2,
                    top: _lensAt.dy - _kLens / 2,
                    width: _kLens,
                    height: _kLens,
                    child: GestureDetector(
                      onPanUpdate: (DragUpdateDetails d) => setState(() => _lensAt += d.delta),
                      child: GlassSurface(
                        borderRadius: kGlassCapsule,
                        labelled: false,
                        finish: GlassFinish.clear.copyWith(optics: const GlassOptics(zoom: 1.5)),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      Positioned(
        right: 16,
        bottom: widget.insets.bottom + 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: GlassSlider(
                value: _level,
                onChanged: (double v) => setState(() => _level = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GlassButton(
                  onPressed: () => setState(() => _lens = !_lens),
                  child: Icon(_lens ? Icons.zoom_out : Icons.zoom_in),
                ),
                const SizedBox(width: 12),
                GlassButton(onPressed: () {}, child: Text('${(_level * 100).round()}%')),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// The lens's diameter, logical px.
const double _kLens = 132;
