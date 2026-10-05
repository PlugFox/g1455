import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

/// A grid of photographs with glass captions.
///
/// The captions are the content layer, which Apple's guidelines keep glass out
/// of and the package allows with a warning ([GlassCard]): each one is a
/// surface, and the price follows their count and area — sixteen of them
/// scrolling is the screen the host's register is there to count.
class CardsPage extends StatelessWidget {
  const CardsPage({required this.insets, super.key});

  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      const Positioned.fill(child: ColoredBox(color: Color(0xFF101522))),
      Positioned.fill(
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(12, insets.top + 8, 12, insets.bottom + 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: _kPlaces.length,
          itemBuilder: (BuildContext context, int i) => _Photo(index: i),
        ),
      ),
    ],
  );
}

const List<String> _kPlaces = <String>[
  'Lisbon',
  'Kyoto',
  'Reykjavík',
  'Atacama',
  'Tbilisi',
  'Lofoten',
  'Hoi An',
  'Patagonia',
  'Dolomites',
  'Marrakesh',
  'Faroe',
  'Bagan',
  'Tasmania',
  'Yukon',
  'Sintra',
  'Hokkaido',
];

class _Photo extends StatelessWidget {
  const _Photo({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(child: PhotoBackdrop(seed: index * 13 + 5)),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: GlassBar(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: <Widget>[
                const SiteIcon(SFIcons.sf_mappin_and_ellipse, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _kPlaces[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
