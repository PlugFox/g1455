import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A list of places, and a glass button whose popover sorts and filters it:
/// the popover stays open while the list behind it follows every change.
class PopoverDemo extends StatefulWidget {
  const PopoverDemo({super.key});

  @override
  State<PopoverDemo> createState() => _PopoverDemoState();
}

/// What the popover sets: the sort, two filters and a distance.
typedef _Filter = ({int sort, bool openNow, bool favourites, double within});

typedef _Place = ({String name, double km, double rating, bool open, bool favourite});

const List<_Place> _kPlaces = <_Place>[
  (name: 'Café Lumière', km: 0.4, rating: 4.6, open: true, favourite: true),
  (name: 'Tasca do Chico', km: 1.2, rating: 4.8, open: true, favourite: false),
  (name: 'Mercado da Ribeira', km: 2.5, rating: 4.4, open: true, favourite: true),
  (name: 'Pastéis de Belém', km: 6.1, rating: 4.9, open: false, favourite: true),
  (name: 'Miradouro Bar', km: 3.3, rating: 4.1, open: false, favourite: false),
  (name: 'Jardim Café', km: 0.9, rating: 4.2, open: true, favourite: false),
  (name: 'O Velho Eurico', km: 1.8, rating: 4.7, open: false, favourite: true),
];

const List<String> _kSorts = <String>['Name', 'Distance', 'Rating'];

class _PopoverDemoState extends State<PopoverDemo> {
  // One value that the popover and the list both listen to.
  final ValueNotifier<_Filter> _filter = ValueNotifier<_Filter>(
    (sort: 1, openNow: false, favourites: false, within: 5),
  );
  double _width = 300;
  double _radius = 26;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _set(_Filter f) => _filter.value = f;

  List<_Place> _visible(_Filter f) {
    final List<_Place> places = _kPlaces
        .where((_Place p) => p.km <= f.within && (!f.openNow || p.open) && (!f.favourites || p.favourite))
        .toList();
    switch (f.sort) {
      case 0:
        places.sort((_Place a, _Place b) => a.name.compareTo(b.name));
      case 1:
        places.sort((_Place a, _Place b) => a.km.compareTo(b.km));
      default:
        places.sort((_Place a, _Place b) => b.rating.compareTo(a.rating));
    }
    return places;
  }

  @override
  Widget build(BuildContext context) {
    // Never wider than the window, less a margin on each side.
    final double width = math.min(_width, MediaQuery.sizeOf(context).width - 32);
    return DemoStage(
      height: 420,
      knobs: <Widget>[
        KnobSlider(
          width: 120,
          label: 'Width',
          value: _width,
          min: 260,
          max: 360,
          format: (double v) => v.round().toString(),
          onChanged: (double v) => setState(() => _width = v),
        ),
        KnobSlider(
          width: 120,
          label: 'Radius',
          value: _radius,
          min: 12,
          max: kGlassMenuRadius,
          format: (double v) => v.toStringAsFixed(1),
          onChanged: (double v) => setState(() => _radius = v),
        ),
      ],
      hint:
          'Open “Sort & filter” and change things: the popover stays open and the list follows. Tap outside to close.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Places',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      shadows: <Shadow>[Shadow(blurRadius: 8)],
                    ),
                  ),
                ),
                GlassPopoverAnchor(
                  width: width,
                  radius: _radius,
                  popoverBuilder: (BuildContext context) => ValueListenableBuilder<_Filter>(
                    valueListenable: _filter,
                    builder: (BuildContext context, _Filter f, Widget? _) => _Panel(filter: f, onChanged: _set),
                  ),
                  builder: (BuildContext context, GlassMenuController popover) => GlassButton(
                    onPressed: popover.open,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SiteIcon(SFIcons.sf_slider_horizontal_3, size: 20),
                        SizedBox(width: 6),
                        Text('Sort & filter'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<_Filter>(
                valueListenable: _filter,
                builder: (BuildContext context, _Filter f, Widget? _) {
                  final List<_Place> places = _visible(f);
                  if (places.isEmpty) {
                    return const Center(
                      child: Text('Nothing matches', style: TextStyle(color: Colors.white, fontSize: 15)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: <Widget>[for (final _Place p in places) _Row(place: p)],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The popover's content: sort, filters, distance. Text and icons take the
/// label colour the popover sets.
class _Panel extends StatelessWidget {
  const _Panel({required this.filter, required this.onChanged});

  final _Filter filter;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filter;
    const TextStyle heading = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4);
    Widget toggle(String label, bool value, ValueChanged<bool> changed) => MergeSemantics(
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            GlassSwitch(value: value, onChanged: changed),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('SORT BY', style: heading),
          const SizedBox(height: 8),
          GlassSegmentedControl(
            segments: <Widget>[for (final String s in _kSorts) Text(s, style: const TextStyle(fontSize: 14))],
            selectedIndex: f.sort,
            onSelected: (int i) => onChanged((sort: i, openNow: f.openNow, favourites: f.favourites, within: f.within)),
          ),
          const SizedBox(height: 14),
          const Text('SHOW', style: heading),
          toggle(
            'Open now',
            f.openNow,
            (bool v) => onChanged((sort: f.sort, openNow: v, favourites: f.favourites, within: f.within)),
          ),
          toggle(
            'Favourites only',
            f.favourites,
            (bool v) => onChanged((sort: f.sort, openNow: f.openNow, favourites: v, within: f.within)),
          ),
          const SizedBox(height: 6),
          Text('Within ${f.within.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          GlassSlider(
            // 0.5 to 7 km.
            value: (f.within - 0.5) / 6.5,
            semanticLabel: 'Distance',
            onChanged: (double v) => onChanged(
              (sort: f.sort, openNow: f.openNow, favourites: f.favourites, within: 0.5 + v * 6.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// One place: plain content, not glass.
class _Row extends StatelessWidget {
  const _Row({required this.place});

  final _Place place;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0x8C000000),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            SiteIcon(place.favourite ? SFIcons.sf_heart_fill : SFIcons.sf_mappin, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: Text(
                '${place.km.toStringAsFixed(1)} km · ★ ${place.rating}',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: place.open ? 'Open' : 'Closed',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: place.open ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
