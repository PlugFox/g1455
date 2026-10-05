import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

/// One scene of the home page's gallery: glass in something that looks like
/// an app, over something worth refracting.
///
/// Each scene is still until it is touched: a still screen costs the host no
/// capture, so a gallery scrolled past costs only the frames of the scroll.
final class Showcase {
  const Showcase({
    required this.title,
    required this.blurb,
    required this.section,
    required this.page,
    required this.builder,
    required this.semantics,
  });

  final String title;
  final String blurb;

  /// The page the scene links to: `/<section>/<page>`.
  final String section;
  final String page;

  final WidgetBuilder builder;

  /// What a screen reader is told the scene is.
  final String semantics;
}

/// The gallery, in order.
final List<Showcase> kShowcases = <Showcase>[
  Showcase(
    title: 'Now playing',
    blurb: 'A player card over album art. Skip a track and the glass picks up the new colours.',
    section: 'components',
    page: 'card',
    semantics: 'A music player on a glass card over album art, with a progress slider and playback buttons.',
    builder: (_) => const _NowPlayingScene(),
  ),
  Showcase(
    title: 'Weather',
    blurb: 'The sky changes under a segmented control and a forecast card.',
    section: 'components',
    page: 'segmented-control',
    semantics: 'A weather forecast on glass over a painted sky; a segmented control switches day, dusk and night.',
    builder: (_) => const _WeatherScene(),
  ),
  Showcase(
    title: 'Messages',
    blurb: 'A conversation scrolls under a glass header and a glass composer.',
    section: 'components',
    page: 'bar',
    semantics: 'A chat: coloured message bubbles scroll under a glass header and a glass message field.',
    builder: (_) => const _MessagesScene(),
  ),
  Showcase(
    title: 'Smart home',
    blurb: 'Switch the lamp and slide its brightness: the room behind the glass lights up.',
    section: 'components',
    page: 'switch',
    semantics: 'A lamp control on glass: a switch, a brightness slider and colour swatches light the room behind it.',
    builder: (_) => const _SmartHomeScene(),
  ),
  Showcase(
    title: 'Photos',
    blurb: 'A caption, a toolbar and a shuffle button over a photograph.',
    section: 'components',
    page: 'toolbar',
    semantics: 'A photo viewer: a glass caption and a glass toolbar over a painted landscape.',
    builder: (_) => const _PhotoScene(),
  ),
  Showcase(
    title: 'Morph',
    blurb: 'Tap “+”: one piece of glass flows from a button into a menu, with a liquid neck.',
    section: 'components',
    page: 'morph',
    semantics: 'A plus button that flows into a glass menu of actions.',
    builder: (_) => const _MorphScene(),
  ),
  Showcase(
    title: 'Maps',
    blurb: 'A search bar and a place card float over the streets.',
    section: 'components',
    page: 'button',
    semantics: 'A painted map with a glass search bar and a glass card for a café.',
    builder: (_) => const _MapScene(),
  ),
  Showcase(
    title: 'Tabs with badges',
    blurb: 'Drag the drop along the bar: it stretches as it sets off. Icons can be any widget, badges included.',
    section: 'components',
    page: 'tab-bar',
    semantics: 'A glass tab bar with a badge on one tab, over a backdrop that changes colour with the tab.',
    builder: (_) => const _TabsScene(),
  ),
];

/// The label colour the glass around [context] chose for its content.
Color _label(BuildContext context) => DefaultTextStyle.of(context).style.color ?? Colors.white;

/// A tappable icon on glass, in the glass's label colour, with a tap target
/// of the size the package asks for.
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 24,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.fromSize(
        size: kGlassMinTapTarget,
        child: SiteIcon(icon, size: size, color: color ?? _label(context)),
      ),
    ),
  );
}

Color _hsv(double h, double s, double v, [double a = 1]) => HSVColor.fromAHSV(a, h % 360, s, v).toColor();

// ------------------------------------------------------------- Now playing

const List<(String, String, double)> _kTracks = <(String, String, double)>[
  ('Midnight Bloom', 'Neon Orchard', 320),
  ('Saltwater Hymn', 'The Low Tides', 190),
  ('Paper Suns', 'Mira Vale', 28),
  ('Velvet Static', 'Night Transit', 260),
];

class _NowPlayingScene extends StatefulWidget {
  const _NowPlayingScene();

  @override
  State<_NowPlayingScene> createState() => _NowPlayingSceneState();
}

class _NowPlayingSceneState extends State<_NowPlayingScene> {
  int _track = 0;
  bool _playing = true;
  bool _loved = false;
  double _progress = 0.34;

  void _skip(int by) => setState(() {
    _track = (_track + by) % _kTracks.length;
    _progress = 0;
    _loved = false;
  });

  @override
  Widget build(BuildContext context) {
    final (String title, String artist, double hue) = _kTracks[_track];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(child: CustomPaint(painter: _AlbumPainter(hue))),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Builder(
              builder: (BuildContext context) {
                final Color label = _label(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(colors: <Color>[_hsv(hue, 0.8, 0.95), _hsv(hue + 50, 0.9, 0.6)]),
                          ),
                          child: const SiteIcon(SFIcons.sf_waveform, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: label, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: label.withValues(alpha: 0.7), fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                        _GlassIcon(
                          icon: _loved ? SFIcons.sf_heart_fill : SFIcons.sf_heart,
                          label: _loved ? 'Unlove' : 'Love',
                          color: _loved ? const Color(0xFFFF375F) : null,
                          onTap: () => setState(() => _loved = !_loved),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GlassSlider(
                      value: _progress,
                      activeColor: _hsv(hue, 0.6, 1),
                      semanticLabel: 'Position in the track',
                      onChanged: (double v) => setState(() => _progress = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        _GlassIcon(icon: SFIcons.sf_shuffle, label: 'Shuffle', size: 20, onTap: () => _skip(2)),
                        _GlassIcon(
                          icon: SFIcons.sf_backward_end_fill,
                          label: 'Previous',
                          size: 30,
                          onTap: () => _skip(-1),
                        ),
                        _GlassIcon(
                          icon: _playing ? SFIcons.sf_pause_fill : SFIcons.sf_play_fill,
                          label: _playing ? 'Pause' : 'Play',
                          size: 38,
                          onTap: () => setState(() => _playing = !_playing),
                        ),
                        _GlassIcon(icon: SFIcons.sf_forward_end_fill, label: 'Next', size: 30, onTap: () => _skip(1)),
                        _GlassIcon(icon: SFIcons.sf_repeat, label: 'Repeat', size: 20, onTap: () {}),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Album art: a vinyl's grooves in a gradient, with light spilling across.
class _AlbumPainter extends CustomPainter {
  _AlbumPainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_hsv(hue, 0.85, 0.95), _hsv(hue + 40, 0.9, 0.55), _hsv(hue + 90, 0.8, 0.3)],
        ).createShader(all),
    );
    final Offset centre = Offset(size.width * 0.62, size.height * 0.36);
    final double r = size.shortestSide * 0.62;
    canvas.drawCircle(centre, r, Paint()..color = const Color(0xF0101014));
    final rings = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double g = r * 0.38; g < r; g += 5) {
      canvas.drawCircle(centre, g, rings..color = Color.fromRGBO(255, 255, 255, 0.05 + 0.05 * ((g ~/ 5) % 3)));
    }
    canvas
      ..drawCircle(
        centre,
        r * 0.34,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[_hsv(hue + 180, 0.7, 1), _hsv(hue + 220, 0.9, 0.7)],
          ).createShader(Rect.fromCircle(center: centre, radius: r * 0.34)),
      )
      ..drawCircle(centre, 5, Paint()..color = const Color(0xFF101014))
      ..drawCircle(
        Offset(size.width * 0.15, size.height * 0.2),
        size.shortestSide * 0.35,
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[_hsv(hue + 30, 0.4, 1, 0.75), _hsv(hue + 30, 0.4, 1, 0)],
              ).createShader(
                Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.2), radius: size.shortestSide * 0.35),
              ),
      );
  }

  @override
  bool shouldRepaint(_AlbumPainter oldDelegate) => oldDelegate.hue != hue;
}

// ------------------------------------------------------------------ Weather

enum _Sky { day, dusk, night }

class _WeatherScene extends StatefulWidget {
  const _WeatherScene();

  @override
  State<_WeatherScene> createState() => _WeatherSceneState();
}

class _WeatherSceneState extends State<_WeatherScene> {
  _Sky _sky = _Sky.day;

  static const Map<_Sky, (String, String, IconData)> _kNow = <_Sky, (String, String, IconData)>{
    _Sky.day: ('24°', 'Sunny', SFIcons.sf_sun_max_fill),
    _Sky.dusk: ('19°', 'Clear evening', SFIcons.sf_sun_horizon_fill),
    _Sky.night: ('14°', 'Starry', SFIcons.sf_moon_fill),
  };

  @override
  Widget build(BuildContext context) {
    final (String temperature, String condition, IconData icon) = _kNow[_sky]!;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(child: CustomPaint(painter: _SkyPainter(_sky))),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 250,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                child: GlassSegmentedControl(
                  segments: const <Widget>[Text('Day'), Text('Dusk'), Text('Night')],
                  selectedIndex: _sky.index,
                  onSelected: (int i) => setState(() => _sky = _Sky.values[i]),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Builder(
              builder: (BuildContext context) {
                final Color label = _label(context);
                final TextStyle small = TextStyle(color: label.withValues(alpha: 0.75), fontSize: 12.5);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          temperature,
                          style: TextStyle(color: label, fontSize: 44, fontWeight: FontWeight.w300, height: 1),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Lisbon',
                                style: TextStyle(color: label, fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              Text(condition, style: small),
                            ],
                          ),
                        ),
                        SiteIcon(icon, color: label, size: 32),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        for (var h = 0; h < 5; h++)
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  '${(h * 2 + 13 + _sky.index * 5) % 24}:00',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  style: small,
                                ),
                                const SizedBox(height: 4),
                                SiteIcon(
                                  (_sky == _Sky.night || h == 4) ? SFIcons.sf_cloud : SFIcons.sf_sun_max,
                                  color: label,
                                  size: 18,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${24 - _sky.index * 5 - h}°',
                                  style: TextStyle(color: label, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A sky for each time of day: a sun or a moon, clouds, stars, and hills.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.sky);

  final _Sky sky;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    final List<Color> colours = switch (sky) {
      _Sky.day => const <Color>[Color(0xFF1E88E5), Color(0xFF64B5F6), Color(0xFFB3E5FC)],
      _Sky.dusk => const <Color>[Color(0xFF3949AB), Color(0xFFEC407A), Color(0xFFFFB74D)],
      _Sky.night => const <Color>[Color(0xFF050818), Color(0xFF1A237E), Color(0xFF4A148C)],
    };
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colours,
        ).createShader(all),
    );
    final random = math.Random(3);
    if (sky == _Sky.night) {
      for (var i = 0; i < 70; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width, random.nextDouble() * size.height * 0.7),
          random.nextDouble() * 1.6 + 0.4,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.4 + random.nextDouble() * 0.6),
        );
      }
    }
    final Offset sun = switch (sky) {
      _Sky.day => Offset(size.width * 0.74, size.height * 0.3),
      _Sky.dusk => Offset(size.width * 0.3, size.height * 0.56),
      _Sky.night => Offset(size.width * 0.78, size.height * 0.26),
    };
    final double r = size.shortestSide * (sky == _Sky.night ? 0.09 : 0.13);
    final Color glow = switch (sky) {
      _Sky.day => const Color(0xFFFFF59D),
      _Sky.dusk => const Color(0xFFFF8A65),
      _Sky.night => const Color(0xFFE8EAF6),
    };
    canvas
      ..drawCircle(
        sun,
        r * 3,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[glow.withValues(alpha: 0.55), glow.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: sun, radius: r * 3)),
      )
      ..drawCircle(sun, r, Paint()..color = glow);
    final cloud = Paint()..color = Color.fromRGBO(255, 255, 255, sky == _Sky.night ? 0.12 : 0.75);
    for (final Offset c in <Offset>[
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.55, size.height * 0.45),
    ]) {
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(c + Offset(i * 22.0 - 33, (i.isEven ? 0 : -12)), 22 + (i % 2) * 8, cloud);
      }
    }
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, size.height);
      final double base = size.height * (0.72 + layer * 0.1);
      for (double x = 0; x <= size.width + 1; x += size.width / 8) {
        path.lineTo(x, base - math.sin(x / size.width * math.pi * (2 + layer) + layer) * 18);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = switch (sky) {
            _Sky.day => layer == 0 ? const Color(0xFF43A047) : const Color(0xFF2E7D32),
            _Sky.dusk => layer == 0 ? const Color(0xFF6A1B9A) : const Color(0xFF4A148C),
            _Sky.night => layer == 0 ? const Color(0xFF0D1030) : const Color(0xFF05061A),
          },
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.sky != sky;
}

// ----------------------------------------------------------------- Messages

const List<(bool, String)> _kChat = <(bool, String)>[
  (false, 'Are you coming tonight? 🎉'),
  (true, 'Wouldn’t miss it'),
  (false, 'Rooftop at 8, bring the speaker'),
  (true, 'Which one, the orange one?'),
  (false, 'The orange one. It’s the loud one'),
  (true, 'On my way after work'),
  (false, 'I’ll save you a slice'),
  (true, 'Two slices. It’s been a week'),
  (false, 'Deal 🍕'),
  (true, 'See you there!'),
];

const List<String> _kReplies = <String>['🙌', 'Can’t wait', 'Bringing snacks too', 'Leaving now!', '🎶🎶🎶'];

class _MessagesScene extends StatefulWidget {
  const _MessagesScene();

  @override
  State<_MessagesScene> createState() => _MessagesSceneState();
}

class _MessagesSceneState extends State<_MessagesScene> {
  final List<(bool, String)> _chat = List<(bool, String)>.of(_kChat);
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // A message sent scrolls the conversation under the glass: the way to see
  // it move on a phone, where a drag here scrolls the page instead.
  void _send() {
    setState(() => _chat.add((true, _kReplies[(_chat.length - _kChat.length) % _kReplies.length])));
    if (_scroll.hasClients) {
      _scroll
        ..jumpTo(-58)
        ..animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const RepaintBoundary(child: CustomPaint(painter: _WallpaperPainter())),
      // The conversation scrolls under both bars: by wheel, trackpad or mouse,
      // and not by a finger, which would trap the page's own scroll here.
      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: <PointerDeviceKind>{PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        ),
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 78, 14, 78),
          itemCount: _chat.length,
          itemBuilder: (BuildContext context, int i) {
            final (bool mine, String text) = _chat[_chat.length - 1 - i];
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: mine
                      ? const LinearGradient(colors: <Color>[Color(0xFF0A84FF), Color(0xFF5E5CE6)])
                      : const LinearGradient(colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE9E3FF)]),
                ),
                child: Text(
                  text,
                  style: TextStyle(color: mine ? Colors.white : const Color(0xFF1C1C1E), fontSize: 14.5),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        top: 12,
        child: GlassBar(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Builder(
            builder: (BuildContext context) {
              final Color label = _label(context);
              return Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: <Color>[Color(0xFFFF9F0A), Color(0xFFFF375F)]),
                    ),
                    child: const Text(
                      'M',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mia',
                          style: TextStyle(color: label, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text('online', style: TextStyle(color: label.withValues(alpha: 0.65), fontSize: 12)),
                      ],
                    ),
                  ),
                  SiteIcon(SFIcons.sf_video, color: label),
                  const SizedBox(width: 12),
                  SiteIcon(SFIcons.sf_phone, color: label, size: 22),
                  const SizedBox(width: 6),
                ],
              );
            },
          ),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Row(
          children: <Widget>[
            Expanded(
              child: GlassBar(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Builder(
                  builder: (BuildContext context) => Row(
                    children: <Widget>[
                      SiteIcon(SFIcons.sf_plus_circle, color: _label(context), size: 22),
                      const SizedBox(width: 10),
                      Text('Message', style: TextStyle(color: _label(context).withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GlassButton(
              padding: EdgeInsets.zero,
              semanticLabel: 'Send',
              onPressed: _send,
              child: const SiteIcon(SFIcons.sf_arrow_up),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A chat wallpaper: soft colour blobs and a scatter of small shapes.
class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
        ).createShader(all),
    );
    final random = math.Random(11);
    final Paint shape = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x33FFFFFF);
    for (var i = 0; i < 40; i++) {
      final Offset c = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      if (i.isEven) {
        canvas.drawCircle(c, 6 + random.nextDouble() * 8, shape);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 16, height: 16), const Radius.circular(4)),
          shape,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) => false;
}

// --------------------------------------------------------------- Smart home

const List<double> _kLampHues = <double>[38, 330, 175, 265];

class _SmartHomeScene extends StatefulWidget {
  const _SmartHomeScene();

  @override
  State<_SmartHomeScene> createState() => _SmartHomeSceneState();
}

class _SmartHomeSceneState extends State<_SmartHomeScene> {
  bool _on = true;
  double _brightness = 0.7;
  double _hue = _kLampHues.first;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      RepaintBoundary(child: CustomPaint(painter: _RoomPainter(_on ? _brightness : 0, _hue))),
      Positioned(
        left: 14,
        right: 14,
        bottom: 14,
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Builder(
            builder: (BuildContext context) {
              final Color label = _label(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SiteIcon(_on ? SFIcons.sf_lightbulb_fill : SFIcons.sf_lightbulb, color: label),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Living room',
                              style: TextStyle(color: label, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _on ? 'Floor lamp · ${(_brightness * 100).round()}%' : 'Floor lamp · off',
                              style: TextStyle(color: label.withValues(alpha: 0.7), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      GlassSwitch(
                        value: _on,
                        semanticLabel: 'Floor lamp',
                        onChanged: (bool v) => setState(() => _on = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GlassSlider(
                    value: _brightness,
                    activeColor: _hsv(_hue, 0.65, 1),
                    semanticLabel: 'Brightness',
                    onChanged: _on ? (double v) => setState(() => _brightness = v) : null,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      for (final double hue in _kLampHues)
                        Semantics(
                          button: true,
                          selected: hue == _hue,
                          label: 'Lamp colour',
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _hue = hue;
                              _on = true;
                            }),
                            child: Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hsv(hue, 0.6, 1),
                                border: Border.all(color: hue == _hue ? label : Colors.transparent, width: 2.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// A dark room with a lamp whose light fills it by [light], in [hue].
class _RoomPainter extends CustomPainter {
  _RoomPainter(this.light, this.hue);

  final double light;
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF14161F), Color(0xFF272A3A)],
        ).createShader(all),
    );
    // The floor and a window.
    canvas
      ..drawRect(
        Rect.fromLTRB(0, size.height * 0.5, size.width, size.height),
        Paint()..color = const Color(0xFF3A2E28),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.26, size.height * 0.24),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF1B2A4A),
      );
    final Offset lamp = Offset(size.width * 0.72, size.height * 0.14);
    final Color glow = _hsv(hue, 0.7, 1);
    if (light > 0) {
      final double r = size.longestSide * (0.25 + 0.55 * light);
      canvas.drawCircle(
        lamp,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              glow.withValues(alpha: 0.9 * light),
              glow.withValues(alpha: 0.25 * light),
              glow.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: lamp, radius: r)),
      );
    }
    // A sofa, to have edges for the glass to bend.
    final Paint sofa = Paint()..color = _hsv(hue + 180, 0.45, 0.25 + 0.4 * light);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.06, size.height * 0.36, size.width * 0.5, size.height * 0.16),
          const Radius.circular(16),
        ),
        sofa,
      )
      ..drawLine(
        Offset(lamp.dx, lamp.dy + 20),
        Offset(lamp.dx, size.height * 0.52),
        Paint()
          ..color = const Color(0xFF8D8D99)
          ..strokeWidth = 3,
      );
    final Path shade = Path()
      ..moveTo(lamp.dx - 22, lamp.dy + 22)
      ..lineTo(lamp.dx + 22, lamp.dy + 22)
      ..lineTo(lamp.dx + 14, lamp.dy - 10)
      ..lineTo(lamp.dx - 14, lamp.dy - 10)
      ..close();
    canvas.drawPath(shade, Paint()..color = light > 0 ? Color.lerp(glow, Colors.white, 0.5)! : const Color(0xFF55576A));
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) => oldDelegate.light != light || oldDelegate.hue != hue;
}

// ------------------------------------------------------------------- Photos

const List<String> _kPlaces = <String>['Dolomites', 'Lofoten', 'Atacama', 'Hokkaido', 'Patagonia', 'Faroe Islands'];

class _PhotoScene extends StatefulWidget {
  const _PhotoScene();

  @override
  State<_PhotoScene> createState() => _PhotoSceneState();
}

class _PhotoSceneState extends State<_PhotoScene> {
  int _seed = 4;
  bool _loved = false;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      RepaintBoundary(child: PhotoBackdrop(seed: _seed)),
      Positioned(
        left: 14,
        top: 14,
        right: 76,
        child: Align(
          alignment: Alignment.centerLeft,
          child: GlassBar(
            child: Builder(
              builder: (BuildContext context) => Text(
                'Day ${_seed + 8} · ${_kPlaces[_seed % _kPlaces.length]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _label(context), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 14,
        right: 14,
        child: GlassButton(
          padding: EdgeInsets.zero,
          semanticLabel: 'Another photo',
          onPressed: () => setState(() {
            _seed++;
            _loved = false;
          }),
          child: const SiteIcon(SFIcons.sf_shuffle),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Center(
          child: GlassButtonGroup(
            items: <GlassToolbarItem>[
              GlassToolbarItem(
                icon: SiteIcon(
                  _loved ? SFIcons.sf_heart_fill : SFIcons.sf_heart,
                  color: _loved ? const Color(0xFFFF375F) : null,
                ),
                label: _loved ? 'Unlove' : 'Love',
                onPressed: () => setState(() => _loved = !_loved),
              ),
              GlassToolbarItem(icon: const SiteIcon(SFIcons.sf_square_and_arrow_up), label: 'Share', onPressed: () {}),
              GlassToolbarItem(icon: const SiteIcon(SFIcons.sf_info_circle), label: 'Info', onPressed: () {}),
              GlassToolbarItem(icon: const SiteIcon(SFIcons.sf_trash), label: 'Delete', onPressed: () {}),
            ],
          ),
        ),
      ),
    ],
  );
}

// -------------------------------------------------------------------- Morph

const List<(IconData, String, Color)> _kActions = <(IconData, String, Color)>[
  (SFIcons.sf_square_and_pencil, 'Note', Color(0xFFFFD60A)),
  (SFIcons.sf_checklist, 'List', Color(0xFF30D158)),
  (SFIcons.sf_camera_fill, 'Photo', Color(0xFF64D2FF)),
  (SFIcons.sf_microphone_fill, 'Voice memo', Color(0xFFFF375F)),
];

class _MorphScene extends StatefulWidget {
  const _MorphScene();

  @override
  State<_MorphScene> createState() => _MorphSceneState();
}

class _MorphSceneState extends State<_MorphScene> {
  bool _open = false;
  int _chosen = 0;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String name, Color colour) = _kActions[_chosen];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const RepaintBoundary(child: GridBackdrop(hue: 140)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SiteIcon(icon, size: 72, color: colour, shadows: const <Shadow>[Shadow(blurRadius: 18)]),
              const SizedBox(height: 8),
              Text(
                'New $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  shadows: <Shadow>[Shadow(blurRadius: 12)],
                ),
              ),
            ],
          ),
        ),
        // The morph changes size inside a box that does not: declared, its
        // motion draws from the capture already held.
        GlassTravel(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.topRight,
              child: GlassMorph(
                alignment: Alignment.topRight,
                borderRadius: _open ? const BorderRadius.all(Radius.circular(26)) : kGlassCapsule,
                child: _open
                    ? Builder(
                        key: const ValueKey<String>('menu'),
                        builder: (BuildContext context) {
                          final Color label = _label(context);
                          return SizedBox(
                            width: 200,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  for (var i = 0; i < _kActions.length; i++)
                                    Semantics(
                                      button: true,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(() {
                                          _chosen = i;
                                          _open = false;
                                        }),
                                        child: SizedBox(
                                          height: 44,
                                          child: Row(
                                            children: <Widget>[
                                              const SizedBox(width: 16),
                                              SiteIcon(_kActions[i].$1, color: _kActions[i].$3, size: 20),
                                              const SizedBox(width: 12),
                                              Text(_kActions[i].$2, style: TextStyle(color: label, fontSize: 16)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : _GlassIcon(
                        key: const ValueKey<String>('plus'),
                        icon: SFIcons.sf_plus,
                        label: 'New',
                        size: 28,
                        onTap: () => setState(() => _open = true),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- Maps

class _MapScene extends StatefulWidget {
  const _MapScene();

  @override
  State<_MapScene> createState() => _MapSceneState();
}

class _MapSceneState extends State<_MapScene> {
  bool _going = false;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      RepaintBoundary(
        child: CustomPaint(painter: _MapPainter(route: _going)),
      ),
      Positioned(
        left: 14,
        right: 14,
        top: 14,
        child: GlassBar(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Builder(
            builder: (BuildContext context) {
              final Color label = _label(context);
              return Row(
                children: <Widget>[
                  SiteIcon(SFIcons.sf_magnifyingglass, color: label, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Search Maps', style: TextStyle(color: label.withValues(alpha: 0.6))),
                  ),
                  SiteIcon(SFIcons.sf_microphone, color: label, size: 20),
                ],
              );
            },
          ),
        ),
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: 14,
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Builder(
            builder: (BuildContext context) {
              final Color label = _label(context);
              return Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Color(0xFFFF9F0A), shape: BoxShape.circle),
                    child: const SiteIcon(SFIcons.sf_cup_and_saucer_fill, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Café Lumen',
                          style: TextStyle(color: label, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _going ? 'Route · 6 min walk' : '★ 4.8 · Open until 22:00',
                          style: TextStyle(color: label.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onPressed: () => setState(() => _going = !_going),
                    child: Text(_going ? 'End' : 'Go', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// A city: blocks, parks, a river, streets, pins — and a route when asked.
class _MapPainter extends CustomPainter {
  _MapPainter({required this.route});

  final bool route;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF2EBDD));
    final random = math.Random(5);
    final Paint park = Paint()..color = const Color(0xFF9ED68B);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
            70 + random.nextDouble() * 60,
            50 + random.nextDouble() * 50,
          ),
          const Radius.circular(14),
        ),
        park,
      );
    }
    final Path river = Path()..moveTo(-10, size.height * 0.62);
    river.cubicTo(
      size.width * 0.3,
      size.height * 0.4,
      size.width * 0.6,
      size.height * 0.9,
      size.width + 10,
      size.height * 0.55,
    );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..color = const Color(0xFF7CC4F2),
    );
    final Paint street = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-0.25);
    for (double d = -size.longestSide; d < size.longestSide; d += 46) {
      final double w = (d ~/ 46) % 3 == 0 ? 9 : 4;
      canvas
        ..drawLine(
          Offset(d, -size.longestSide),
          Offset(d, size.longestSide),
          street
            ..strokeWidth = w
            ..color = const Color(0xFFFFFFFF),
        )
        ..drawLine(Offset(-size.longestSide, d), Offset(size.longestSide, d), street);
    }
    canvas.restore();
    final Offset cafe = Offset(size.width * 0.68, size.height * 0.42);
    final Offset you = Offset(size.width * 0.24, size.height * 0.52);
    if (route) {
      final Path path = Path()
        ..moveTo(you.dx, you.dy)
        ..quadraticBezierTo(size.width * 0.42, size.height * 0.3, cafe.dx, cafe.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF0A84FF),
      );
    }
    for (final (Offset at, Color colour) in <(Offset, Color)>[
      (cafe, const Color(0xFFFF9F0A)),
      (Offset(size.width * 0.85, size.height * 0.22), const Color(0xFFFF375F)),
      (Offset(size.width * 0.4, size.height * 0.3), const Color(0xFF30D158)),
    ]) {
      canvas
        ..drawCircle(at, 13, Paint()..color = Colors.white)
        ..drawCircle(at, 10, Paint()..color = colour);
    }
    canvas
      ..drawCircle(you, 18, Paint()..color = const Color(0x330A84FF))
      ..drawCircle(you, 9, Paint()..color = Colors.white)
      ..drawCircle(you, 7, Paint()..color = const Color(0xFF0A84FF));
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.route != route;
}

// --------------------------------------------------------------------- Tabs

const List<(IconData, String, double)> _kTabs = <(IconData, String, double)>[
  (SFIcons.sf_house_fill, 'Home', 210),
  (SFIcons.sf_tray, 'Inbox', 280),
  (SFIcons.sf_safari, 'Explore', 150),
  (SFIcons.sf_person_fill, 'Profile', 20),
];

class _TabsScene extends StatefulWidget {
  const _TabsScene();

  @override
  State<_TabsScene> createState() => _TabsSceneState();
}

class _TabsSceneState extends State<_TabsScene> {
  int _tab = 0;
  int _unread = 3;

  void _select(int i) => setState(() {
    _tab = i;
    if (i == 1) {
      _unread = 0;
    }
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String name, double hue) = _kTabs[_tab];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(child: CustomPaint(painter: _GlowPainter(hue))),
        Positioned.fill(
          bottom: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SiteIcon(icon, size: 64, color: Colors.white, shadows: const <Shadow>[Shadow(blurRadius: 16)]),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    shadows: <Shadow>[Shadow(blurRadius: 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: GlassTabBar(
            selectedIndex: _tab,
            onSelected: _select,
            items: <GlassTabItem>[
              for (final (IconData icon, String label, _) in _kTabs)
                GlassTabItem(
                  label: label,
                  // Any widget for the icon: here a badge, in the colour the
                  // bar chose for the item.
                  iconBuilder: label == 'Inbox' && _unread > 0
                      ? (BuildContext context, GlassTabItemLook look) => Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            SiteIcon(icon, size: look.iconSize, color: look.color),
                            Positioned(
                              // Clear of the label beside the icon on a wide bar.
                              right: look.inline ? -4 : -8,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '$_unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                  icon: icon,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft colour: a diagonal gradient with three glowing discs, in [hue].
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_hsv(hue, 0.85, 0.55), _hsv(hue + 60, 0.9, 0.35)],
        ).createShader(all),
    );
    for (final (double x, double y, double r, double dh) in const <(double, double, double, double)>[
      (0.18, 0.22, 0.5, -40),
      (0.85, 0.3, 0.42, 50),
      (0.5, 0.95, 0.55, 110),
    ]) {
      final Offset c = Offset(size.width * x, size.height * y);
      final double radius = size.shortestSide * r;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[_hsv(hue + dh, 0.7, 1, 0.95), _hsv(hue + dh, 0.7, 1, 0)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
    paintDraftingGrid(canvas, size, cell: 24, minor: const Color(0x14FFFFFF), major: const Color(0x33FFFFFF));
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.hue != hue;
}
