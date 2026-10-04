import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'backdrop.dart';
import 'harness.dart';

/// Whole app screens, shot apart from the grid: each is its own size and its
/// own backdrop, so none is cut from the grid's canvas, none counts against
/// its ten, and none is one of pub's screenshots. `tool/showcase.sh <name>`
/// shoots one into `doc/showcase/<name>.webp`.
final List<ShowcaseScene> kShowcaseScreens = <ShowcaseScene>[
  ShowcaseScene.screen(
    name: 'screen',
    size: kScreen,
    builder: (BuildContext context, ValueListenable<double> _) => const _Screen(),
    seconds: 7,
    strokes: <Stroke>[
      // The list scrolled up under the bar. The finger comes to rest before
      // it lifts: a fling coasts for two seconds of sub-pixel steps, and
      // every one of them is a whole frame of the webp.
      Stroke.drag(0.3, 1.45, _list, const Alignment(0.15, 0.75), const Alignment(0.15, -0.5), hold: 0.12),
      // The bar's menu grows out of its button, and an item closes it.
      Stroke.tap(2.0, 2.2, find.byKey(_menuButton)),
      Stroke.tap(3.0, 3.2, find.text('Select')),
      // The selection dragged to the next tab, which is another page.
      Stroke.drag(3.7, 4.8, _tabs, _tab(0), _tab(1), hold: 0.25),
      // And tapped home, where the list is back at its top: the loop's seam.
      Stroke.tap(5.7, 5.9, _tabs, _tab(0)),
    ],
  ),
];

/// A phone of 2016 to 2022 — iPhone SE, 8 — in logical px: 9:16, and at the
/// showcase's density of 2 the 750 x 1334 it was. Shown 360 wide in a README
/// it is 640 tall, which a laptop still shows whole; a 19.5:9 phone of today
/// would be 780, taller than the window it is read in.
const Size kScreen = Size(375, 667);

const Key _menuButton = ValueKey<String>('screen menu');
final Finder _tabs = find.byType(GlassTabBar);
final Finder _list = find.byKey(const ValueKey<String>('home list'));

Alignment _tab(int i) => Alignment(-1 + (2 * i + 1) / _kTabs.length, 0);

const List<GlassTabItem> _kTabs = <GlassTabItem>[
  GlassTabItem(icon: Icons.home_rounded, label: 'Home'),
  GlassTabItem(icon: Icons.explore, label: 'Explore'),
  GlassTabItem(icon: Icons.favorite, label: 'Saved'),
  GlassTabItem(icon: Icons.person, label: 'Profile'),
];

/// Where the bars reach in from the screen's edges: the scroll edges' extents.
const double _kTop = 68;
const double _kBottom = 76;

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: kShowcaseBase,
    child: Stack(
      children: <Widget>[
        // A page is built new each time its tab is chosen, as a tab's root
        // is in most apps: home comes back at its top, and that is the seam.
        Positioned.fill(
          child: _tab == 0 ? const _Home(key: ValueKey<int>(0)) : const _Explore(key: ValueKey<int>(1)),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.top,
            extent: _kTop,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: _Bar(title: _kTabs[_tab].label),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GlassScrollEdge(
            side: GlassScrollEdgeSide.bottom,
            extent: _kBottom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GlassTabBar(
                  items: _kTabs,
                  selectedIndex: _tab,
                  onSelected: (int i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => GlassBar(
    padding: const EdgeInsets.only(left: 18, right: 4),
    child: SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.search, size: 22)),
          GlassMenuAnchor(
            items: <GlassMenuItem>[
              GlassMenuItem(label: 'Select', icon: const Icon(Icons.check_circle_outline, size: 20), onPressed: () {}),
              GlassMenuItem(label: 'Sort by date', icon: const Icon(Icons.schedule, size: 20), onPressed: () {}),
              GlassMenuItem(label: 'Share', icon: const Icon(Icons.ios_share, size: 20), onPressed: () {}),
              GlassMenuItem(
                label: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 20),
                isDestructive: true,
                onPressed: () {},
              ),
            ],
            // Not a glass button: a control inside the bar would be glass on
            // glass, a second capture level for a tap target.
            builder: (BuildContext context, GlassMenuController menu) => GestureDetector(
              key: _menuButton,
              behavior: HitTestBehavior.opaque,
              onTap: menu.open,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Icon(Icons.more_horiz, size: 24),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A colour of the showcase's palette, by index.
Color _hue(int i) => const <Color>[
  Color(0xFFFF2D95), // pink
  Color(0xFF00D1FF), // cyan
  Color(0xFFFFB020), // amber
  Color(0xFF7C4DFF), // violet
  Color(0xFF00E676), // green
  Color(0xFFFF5A36), // orange
][i % 6];

const List<(String, String, IconData)> _kItems = <(String, String, IconData)>[
  ('Northern lights', 'Tromsø · 48 photos', Icons.auto_awesome),
  ('Coral reef', 'Great Barrier Reef · 112 photos', Icons.water),
  ('Desert dunes', 'Sahara · 36 photos', Icons.wb_sunny),
  ('City at night', 'Tokyo · 87 photos', Icons.location_city),
  ('Spring meadow', 'Provence · 54 photos', Icons.local_florist),
  ('Volcano', 'Iceland · 23 photos', Icons.terrain),
  ('Lagoon', 'Bora Bora · 65 photos', Icons.beach_access),
  ('Old town', 'Prague · 41 photos', Icons.account_balance),
  ('Rainforest', 'Borneo · 76 photos', Icons.park),
  ('Ice fields', 'Patagonia · 29 photos', Icons.ac_unit),
  ('Canyon', 'Arizona · 58 photos', Icons.landscape),
  ('Harbour', 'Lisbon · 33 photos', Icons.sailing),
  ('Tea hills', 'Darjeeling · 47 photos', Icons.emoji_food_beverage),
  ('Fjord', 'Geiranger · 39 photos', Icons.directions_boat),
  ('Night market', 'Taipei · 92 photos', Icons.storefront),
  ('Glacier', 'Alaska · 26 photos', Icons.filter_hdr),
];

class _Home extends StatelessWidget {
  const _Home({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey<String>('home list'),
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, _kTop + 6, 16, _kBottom + 12),
    itemCount: _kItems.length + 1,
    itemBuilder: (BuildContext context, int i) => i == 0 ? const _Feature() : _Row(index: i - 1),
  );
}

/// The card at the top: a field of the palette's colours, as the grid's
/// backdrop is, under a title.
class _Feature extends StatelessWidget {
  const _Feature();

  @override
  Widget build(BuildContext context) => Container(
    height: 196,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(26))),
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const CustomPaint(painter: _FieldsPainter()),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(
                'FEATURED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Colours of the year',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FieldsPainter extends CustomPainter {
  const _FieldsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A1440));
    final random = math.Random(7);
    for (var i = 0; i < 7; i++) {
      final c = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final double r = 70 + random.nextDouble() * 60;
      final Rect rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[_hue(i).withValues(alpha: 0.9), _hue(i).withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_FieldsPainter oldDelegate) => false;
}

/// A row of the list: artwork in two of the palette's colours, a title and
/// a line under it.
class _Row extends StatelessWidget {
  const _Row({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle, IconData icon) = _kItems[index];
    final Color a = _hue(index), b = _hue(index + 3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          gradient: LinearGradient(colors: <Color>[a.withValues(alpha: 0.28), b.withValues(alpha: 0.12)]),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[a, b]),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

/// The second tab: tiles of colour, two to a row.
class _Explore extends StatelessWidget {
  const _Explore({super.key});

  static const List<(String, IconData)> _kTopics = <(String, IconData)>[
    ('Nature', Icons.park),
    ('Cities', Icons.location_city),
    ('Ocean', Icons.water),
    ('Night sky', Icons.nightlight_round),
    ('Food', Icons.restaurant),
    ('Travel', Icons.flight),
    ('Art', Icons.palette),
    ('Music', Icons.music_note),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, _kTop + 6, 16, _kBottom + 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
    ),
    itemCount: _kTopics.length,
    itemBuilder: (BuildContext context, int i) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_hue(i + 1), _hue(i + 4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_kTopics[i].$2, color: Colors.white, size: 30),
          const Spacer(),
          Text(
            _kTopics[i].$1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}
