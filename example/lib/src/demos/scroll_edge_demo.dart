import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A list scrolling under a bar held by a [GlassScrollEdge], its style, side,
/// appearance and extent live.
class ScrollEdgeDemo extends StatefulWidget {
  const ScrollEdgeDemo({super.key});

  @override
  State<ScrollEdgeDemo> createState() => _ScrollEdgeDemoState();
}

/// The edge's style, or none at all for comparison.
enum _Style { soft, hard, none }

/// The edge's appearance, or the one read from the host's backdrop.
enum _Look { auto, light, dark }

class _ScrollEdgeDemoState extends State<ScrollEdgeDemo> {
  _Style _style = _Style.soft;
  GlassScrollEdgeSide _side = GlassScrollEdgeSide.top;
  _Look _look = _Look.auto;
  double _extent = 72;

  bool get _top => _side == GlassScrollEdgeSide.top;

  @override
  Widget build(BuildContext context) {
    // The bar, laid at the inner edge of the extent.
    final Widget bar = Padding(
      padding: EdgeInsets.fromLTRB(14, _top ? 0 : 8, 14, _top ? 8 : 0),
      child: Align(
        alignment: _top ? Alignment.bottomCenter : Alignment.topCenter,
        child: GlassBar(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(_top ? Icons.arrow_back_ios_new : Icons.home, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _top ? 'Library' : 'Home',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(_top ? Icons.search : Icons.person, size: 20),
            ],
          ),
        ),
      ),
    );
    final Widget edge = switch (_style) {
      _Style.none => SizedBox(
        height: _extent,
        child: GlassAbove(child: bar),
      ),
      _Style.soft || _Style.hard => GlassScrollEdge(
        side: _side,
        extent: _extent,
        style: _style == _Style.hard ? GlassScrollEdgeStyle.hard : GlassScrollEdgeStyle.soft,
        appearance: switch (_look) {
          _Look.auto => null,
          _Look.light => GlassScrollEdgeAppearance.light,
          _Look.dark => GlassScrollEdgeAppearance.dark,
        },
        child: bar,
      ),
    };
    return DemoStage(
      height: 400,
      knobs: <Widget>[
        KnobChoice<_Style>(
          label: 'Style',
          values: _Style.values,
          selected: _style,
          labelOf: (_Style s) => s.name,
          onChanged: (_Style s) => setState(() => _style = s),
        ),
        KnobChoice<GlassScrollEdgeSide>(
          label: 'Side',
          values: GlassScrollEdgeSide.values,
          selected: _side,
          labelOf: (GlassScrollEdgeSide s) => s.name,
          onChanged: (GlassScrollEdgeSide s) => setState(() => _side = s),
        ),
        KnobChoice<_Look>(
          label: 'Appearance',
          values: _Look.values,
          selected: _look,
          labelOf: (_Look l) => l.name,
          onChanged: (_Look l) => setState(() => _look = l),
        ),
        KnobSlider(
          label: 'Extent',
          value: _extent,
          min: 60,
          max: 140,
          format: (double v) => '${v.round()}',
          onChanged: (double v) => setState(() => _extent = v),
        ),
      ],
      hint:
          'Scroll the list under the bar. Soft blurs and fades the content at the top (only tints at the bottom); '
          'hard meets it with an opaque band.',
      background: const ColoredBox(color: Color(0xFF0B0E16)),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView.builder(
              padding: EdgeInsets.only(top: _top ? _extent : 8, bottom: _top ? 8 : _extent),
              itemCount: 30,
              itemBuilder: (BuildContext context, int i) => GradientTile(index: i, height: 84),
            ),
          ),
          Positioned(top: _top ? 0 : null, bottom: _top ? null : 0, left: 0, right: 0, child: edge),
        ],
      ),
    );
  }
}
