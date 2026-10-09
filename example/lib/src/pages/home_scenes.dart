import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

// More scenes for the home page's gallery, each something to play with rather
// than to look at: a calculator that counts, notifications that are swiped
// away, a pond that ripples, a lens to drag over a page, a shop with a bag that
// counts, an onboarding to swipe through, and a library whose tab bar folds
// away as it scrolls.

/// The label colour the glass around [context] chose for its content.
Color _label(BuildContext context) => DefaultTextStyle.of(context).style.color ?? Colors.white;

// --------------------------------------------------------------- Calculator

/// A calculator of glass keys over a wallpaper, and it counts.
class CalculatorScene extends StatefulWidget {
  const CalculatorScene({super.key});

  @override
  State<CalculatorScene> createState() => _CalculatorSceneState();
}

class _CalculatorSceneState extends State<CalculatorScene> {
  String _display = '0';
  double? _left;
  String? _operator;
  bool _fresh = true;

  static const List<List<String>> _keys = <List<String>>[
    <String>['C', '±', '%', '÷'],
    <String>['7', '8', '9', '×'],
    <String>['4', '5', '6', '−'],
    <String>['1', '2', '3', '+'],
    <String>['0', '.', '='],
  ];

  double get _value => double.tryParse(_display) ?? 0;

  String _format(double v) {
    if (v.isNaN || v.isInfinite) {
      return 'Error';
    }
    if (v == v.roundToDouble() && v.abs() < 1e12) {
      return v.toInt().toString();
    }
    final String s = v.toStringAsPrecision(9);
    return s.contains('e') ? s : s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double _apply(double a, String op, double b) => switch (op) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    '÷' => a / b,
    _ => b,
  };

  void _press(String key) => setState(() {
    switch (key) {
      case 'C':
        _display = '0';
        _left = null;
        _operator = null;
        _fresh = true;
      case '±':
        _display = _format(-_value);
      case '%':
        _display = _format(_value / 100);
      case '+' || '−' || '×' || '÷':
        if (_left != null && _operator != null && !_fresh) {
          _display = _format(_apply(_left!, _operator!, _value));
        }
        _left = _value;
        _operator = key;
        _fresh = true;
      case '=':
        if (_left != null && _operator != null) {
          _display = _format(_apply(_left!, _operator!, _value));
          _left = null;
          _operator = null;
          _fresh = true;
        }
      case '.':
        if (_fresh) {
          _display = '0.';
          _fresh = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      default:
        if (_fresh || _display == '0' || _display == 'Error') {
          _display = key;
          _fresh = false;
        } else if (_display.length < 12) {
          _display += key;
        }
    }
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const RepaintBoundary(child: GridBackdrop(hue: 300, phase: 0.35)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 8;
            // Five rows of keys and the display above them, whatever the tile.
            final double key = math.min(
              (constraints.maxWidth - 3 * gap) / 4,
              (constraints.maxHeight - 64 - 4 * gap) / 5,
            );
            final double width = key * 4 + gap * 3;
            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    SizedBox(
                      height: 56,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _display,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w300,
                              shadows: <Shadow>[Shadow(color: Color(0x80000000), blurRadius: 10)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (int r, List<String> row) in _keys.indexed) ...<Widget>[
                      if (r > 0) const SizedBox(height: gap),
                      Row(
                        children: <Widget>[
                          for (final (int c, String k) in row.indexed) ...<Widget>[
                            if (c > 0) const SizedBox(width: gap),
                            SizedBox(width: k == '0' ? key * 2 + gap : key, height: key, child: _key(k, key)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _key(String k, double size) {
    final bool operator = '÷×−+='.contains(k);
    final bool chosen = operator && k == _operator && _fresh;
    final GlassFinish finish = GlassTheme.of(context).finish;
    return GlassButton(
      padding: EdgeInsets.zero,
      minSize: Size.square(math.min(size, kGlassMinTapTarget.width)),
      semanticLabel: switch (k) {
        'C' => 'Clear',
        '±' => 'Change sign',
        '÷' => 'Divide',
        '×' => 'Multiply',
        '−' => 'Subtract',
        '+' => 'Add',
        '=' => 'Equals',
        '.' => 'Decimal point',
        _ => null,
      },
      // The operators are orange glass, as on the phone: the theme's
      // finish with the colour laid in it. The chosen one is lighter.
      finish: operator
          ? finish.copyWith(tint: (chosen ? const Color(0xFFFFC56B) : const Color(0xFFFF9F0A)).withValues(alpha: 0.8))
          : null,
      onPressed: () => _press(k),
      child: Text(
        k,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: operator ? FontWeight.w600 : FontWeight.w400,
          color: operator ? Colors.white : null,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Notifications

const List<(IconData, Color, String, String, String)> _kNotes = <(IconData, Color, String, String, String)>[
  (SFIcons.sf_message_fill, Color(0xFF30D158), 'Messages', 'Mia', 'On my way, ten minutes'),
  (SFIcons.sf_calendar, Color(0xFFFF453A), 'Calendar', 'Design review', 'Today at 15:00 · Room 4'),
  (SFIcons.sf_envelope_fill, Color(0xFF0A84FF), 'Mail', 'pub.dev', 'g1455 0.2.0 is published'),
  (SFIcons.sf_bell_fill, Color(0xFFFF9F0A), 'Reminders', 'Water the plants', 'The fern first'),
];

/// A lock screen: the time over a photograph, and glass notifications that
/// are swiped away.
class NotificationsScene extends StatefulWidget {
  const NotificationsScene({super.key});

  @override
  State<NotificationsScene> createState() => _NotificationsSceneState();
}

class _NotificationsSceneState extends State<NotificationsScene> {
  List<int> _shown = <int>[for (var i = 0; i < _kNotes.length; i++) i];

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const RepaintBoundary(child: PhotoBackdrop(seed: 2)),
      Positioned(
        left: 0,
        right: 0,
        top: 18,
        child: Column(
          children: <Widget>[
            const Text(
              'Monday 5 October',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 8)],
              ),
            ),
            Text(
              '9:41',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 56,
                fontWeight: FontWeight.w700,
                height: 1.05,
                shadows: const <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 12)],
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_shown.isEmpty)
              GlassButton(
                onPressed: () => setState(() => _shown = <int>[for (var i = 0; i < _kNotes.length; i++) i]),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SiteIcon(SFIcons.sf_arrow_counterclockwise, size: 16),
                    SizedBox(width: 8),
                    Text('Bring them back'),
                  ],
                ),
              ),
            // The newest at the bottom, nearest the thumb; three at most.
            for (final int i in _shown.take(3).toList().reversed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Dismissible(
                  key: ValueKey<int>(i),
                  onDismissed: (_) => setState(() => _shown = <int>[..._shown]..remove(i)),
                  child: _note(i),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _note(int i) {
    final (IconData icon, Color colour, String app, String title, String body) = _kNotes[i];
    return Semantics(
      label: '$app: $title. $body. Swipe to dismiss.',
      excludeSemantics: true,
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Builder(
          builder: (BuildContext context) {
            final Color label = _label(context);
            return Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(9)),
                  child: SiteIcon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: label, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text('now', style: TextStyle(color: label.withValues(alpha: 0.6), fontSize: 12)),
                        ],
                      ),
                      Text(
                        body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: label.withValues(alpha: 0.8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- Pond

/// A pane of clear glass over a pond: a touch sends a wave across it.
class PondScene extends StatefulWidget {
  const PondScene({super.key});

  @override
  State<PondScene> createState() => _PondSceneState();
}

class _PondSceneState extends State<PondScene> {
  double _viscosity = 0.15;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const RepaintBoundary(child: GridBackdrop(hue: 160, phase: 0.6)),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 70),
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          finish: GlassFinish.clear,
          labelled: false,
          ripple: GlassRipple(viscosity: _viscosity, amplitude: 8),
          child: const Center(
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SiteIcon(
                    SFIcons.sf_hand_tap,
                    size: 30,
                    color: Colors.white,
                    shadows: <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 8)],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap or drag',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: 14,
        child: GlassSegmentedControl(
          segments: const <Widget>[Text('Water'), Text('Jelly'), Text('Honey')],
          selectedIndex: _viscosity < 0.3 ? 0 : (_viscosity < 0.8 ? 1 : 2),
          onSelected: (int i) => setState(() => _viscosity = const <double>[0.15, 0.5, 1][i]),
        ),
      ),
    ],
  );
}

// --------------------------------------------------------------------- Lens

/// A drop of glass to drag over a page of text, in the finish chosen under it.
class LensScene extends StatefulWidget {
  const LensScene({super.key});

  @override
  State<LensScene> createState() => _LensSceneState();
}

class _LensSceneState extends State<LensScene> {
  Offset? _at;
  int _finish = 1;

  static const List<(String, GlassFinish)> _finishes = <(String, GlassFinish)>[
    ('Regular', GlassFinish.regularDark),
    ('Clear', GlassFinish.clear),
    ('Frosted', GlassFinish.frosted),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Size size = constraints.biggest;
      const double radius = 64;
      final Offset at = _at ?? Offset(size.width * 0.62, size.height * 0.4);
      void move(Offset p) => setState(
        () => _at = Offset(
          p.dx.clamp(radius, size.width - radius),
          p.dy.clamp(radius, size.height - 70 - radius * 0.5),
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RepaintBoundary(child: _Page()),
          // A tap anywhere puts the lens there; a drag on the lens moves it.
          // Only on the lens: a drag elsewhere still scrolls the page.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (TapDownDetails d) => move(d.localPosition),
          ),
          // The lens moves inside a travel region: the page under it is
          // captured once, and dragging costs no capture at all.
          GlassTravel(
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: at.dx - radius,
                  top: at.dy - radius,
                  width: radius * 2,
                  height: radius * 2,
                  child: Semantics(
                    label: 'A glass lens. Drag it over the page.',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: GestureDetector(
                        onPanUpdate: (DragUpdateDetails d) => move(at + d.delta),
                        child: GlassSurface(
                          borderRadius: kGlassCapsule,
                          finish: _finishes[_finish].$2,
                          labelled: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: GlassSegmentedControl(
              segments: <Widget>[for (final (String name, _) in _finishes) Text(name)],
              selectedIndex: _finish,
              onSelected: (int i) => setState(() => _finish = i),
            ),
          ),
        ],
      );
    },
  );
}

/// A page of a magazine: a headline, columns of text and a coloured picture,
/// the things refraction and blur show best.
class _Page extends StatelessWidget {
  const _Page();

  static const String _text =
      'Glass that bends the light under it has to know what is under it. This package records the screen '
      'under every glass once a frame, at a fraction of its size, and every surface samples the same '
      'picture: ten panels cost about what one does. A still screen records nothing, and glass that only '
      'moves over still content records nothing either. ';

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF4EFE6),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'THE GLASS ISSUE',
            style: TextStyle(color: Color(0xFFD7263D), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          const Text(
            'How light finds\nits way through',
            style: TextStyle(color: Color(0xFF15171C), fontSize: 26, fontWeight: FontWeight.w800, height: 1.05),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      _text + _text,
                      overflow: TextOverflow.clip,
                      style: TextStyle(color: Color(0xFF2B2F38), fontSize: 11.5, height: 1.45),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Container(
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: <Color>[Color(0xFF5E5CE6), Color(0xFFFF375F), Color(0xFFFF9F0A)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: Text(
                            _text,
                            overflow: TextOverflow.clip,
                            style: TextStyle(color: Color(0xFF2B2F38), fontSize: 11.5, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Color _hsv(double h, double s, double v, [double a = 1]) => HSVColor.fromAHSV(a, h % 360, s, v).toColor();

// --------------------------------------------------------------------- Shop

const List<(String, double)> _kFinishes = <(String, double)>[('Coral', 8), ('Mint', 160), ('Indigo', 240)];

/// A product page: headphones over a declared backdrop, a stepper for how
/// many are in the bag, and a badge on the bag that counts them.
class ShopScene extends StatefulWidget {
  const ShopScene({super.key});

  @override
  State<ShopScene> createState() => _ShopSceneState();
}

class _ShopSceneState extends State<ShopScene> {
  int _inBag = 1;
  int _finish = 0;

  static const int _price = 129;

  @override
  Widget build(BuildContext context) {
    final (String name, double hue) = _kFinishes[_finish];
    // Declared, not captured: every piece of glass here sits straight on the
    // painting, so the host takes no snapshot for this scene at all. A new
    // colour is a new texture, once.
    return GlassBackdrop.painter(
      _ShopPainter(hue),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            left: 14,
            top: 14,
            right: 76,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GlassBar(
                child: Builder(
                  builder: (BuildContext context) => Text(
                    'Audio · Studio Buds',
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
              semanticLabel: _inBag == 0 ? 'Bag, empty' : 'Bag, $_inBag items: check out',
              onPressed: _inBag == 0 ? null : () => setState(() => _inBag = 0),
              // A count changing on glass is a repaint inside the glass.
              child: GlassBadge(count: _inBag, child: const SiteIcon(SFIcons.sf_bag)),
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Studio Buds · $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: label, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '€$_price',
                            style: TextStyle(color: label, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          for (var i = 0; i < _kFinishes.length; i++)
                            Semantics(
                              button: true,
                              selected: i == _finish,
                              label: _kFinishes[i].$1,
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: () => setState(() => _finish = i),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _hsv(_kFinishes[i].$2, 0.6, 0.95),
                                    border: Border.all(color: i == _finish ? label : Colors.transparent, width: 2.5),
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          GlassStepper(
                            value: _inBag.toDouble(),
                            max: 9,
                            semanticLabel: 'Quantity',
                            onChanged: (double v) => setState(() => _inBag = v.round()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _inBag == 0 ? 'Not in your bag' : '$_inBag in bag · €${_inBag * _price}',
                        style: TextStyle(
                          color: label.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A studio wall and a pair of headphones in [hue]: what the glass samples,
/// as a texture made from this painter rather than a capture.
class _ShopPainter extends GlassProxyPainter {
  const _ShopPainter(this.hue);

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
          colors: <Color>[_hsv(hue + 200, 0.35, 0.95), _hsv(hue + 170, 0.55, 0.6)],
        ).createShader(all),
    );
    final Offset c = Offset(size.width * 0.5, size.height * 0.4);
    final double r = math.min(size.width, size.height) * 0.26;
    canvas.drawCircle(
      c,
      r * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[_hsv(hue, 0.5, 1, 0.7), _hsv(hue, 0.5, 1, 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.8)),
    );
    // The band, then the two cups.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 1.05,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round
        ..color = _hsv(hue, 0.55, 0.45),
    );
    for (final double side in <double>[-1, 1]) {
      final Rect cup = Rect.fromCenter(
        center: c + Offset(side * r * 0.92, r * 0.25),
        width: r * 0.55,
        height: r * 0.95,
      );
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(cup, Radius.circular(r * 0.24)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_hsv(hue, 0.55, 1), _hsv(hue + 15, 0.75, 0.6)],
            ).createShader(cup),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(cup.deflate(r * 0.1), Radius.circular(r * 0.16)),
          Paint()..color = _hsv(hue, 0.3, 1, 0.35),
        );
    }
  }

  @override
  bool shouldRepaint(_ShopPainter oldPainter) => oldPainter.hue != hue;
}

// --------------------------------------------------------------- Onboarding

const List<(IconData, String, String, double)> _kOnboarding = <(IconData, String, String, double)>[
  (SFIcons.sf_hand_wave_fill, 'Welcome', 'Glass that bends what is under it.', 200),
  (SFIcons.sf_drop_fill, 'Swipe', 'The dots follow the page, and turn it.', 280),
  (SFIcons.sf_bolt_fill, 'Still is free', 'A screen at rest captures nothing.', 30),
  (SFIcons.sf_checkmark_circle_fill, 'Ready', 'Start, and it begins again.', 150),
];

/// Onboarding: painted pages in a [PageView], and a page control that
/// follows the swipe and turns the page.
class OnboardingScene extends StatefulWidget {
  const OnboardingScene({super.key});

  @override
  State<OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<OnboardingScene> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final bool last = _page == _kOnboarding.length - 1;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // A page moving under the glass is retaken while it moves: that is
        // the view's price, and the dots add nothing to it.
        PageView.builder(
          controller: _pages,
          itemCount: _kOnboarding.length,
          onPageChanged: (int i) => setState(() => _page = i),
          itemBuilder: (BuildContext context, int i) {
            final (IconData icon, String title, String line, double hue) = _kOnboarding[i];
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RepaintBoundary(child: CustomPaint(painter: _OnboardingPainter(hue, i))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 84),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SiteIcon(icon, size: 64, color: Colors.white, shadows: const <Shadow>[Shadow(blurRadius: 16)]),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          shadows: <Shadow>[Shadow(blurRadius: 12)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          shadows: <Shadow>[Shadow(blurRadius: 10)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: last
                      ? const SizedBox.shrink()
                      : GlassButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onPressed: () => _go(_kOnboarding.length - 1),
                          child: const Text('Skip'),
                        ),
                ),
              ),
              GlassPageControl(count: _kOnboarding.length, controller: _pages, semanticLabel: 'Page'),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onPressed: () => _go(last ? 0 : _page + 1),
                    child: Text(last ? 'Start' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A page of the onboarding: a gradient in [hue] and soft discs placed by
/// [index], so a swipe has edges for the glass to bend.
class _OnboardingPainter extends CustomPainter {
  _OnboardingPainter(this.hue, this.index);

  final double hue;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_hsv(hue, 0.75, 0.75), _hsv(hue + 50, 0.85, 0.35)],
        ).createShader(all),
    );
    final random = math.Random(index + 7);
    for (var i = 0; i < 6; i++) {
      final Offset c = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final double r = size.shortestSide * (0.12 + random.nextDouble() * 0.22);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[_hsv(hue + 40 * (i - 2), 0.6, 1, 0.8), _hsv(hue + 40 * (i - 2), 0.6, 1, 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    paintDraftingGrid(canvas, size, cell: 28, minor: const Color(0x10FFFFFF), major: const Color(0x2AFFFFFF));
  }

  @override
  bool shouldRepaint(_OnboardingPainter oldDelegate) => oldDelegate.hue != hue || oldDelegate.index != index;
}

// ------------------------------------------------------------------ Library

const List<(String, String, double)> _kSongs = <(String, String, double)>[
  ('Midnight Bloom', 'Neon Orchard', 320),
  ('Saltwater Hymn', 'The Low Tides', 190),
  ('Paper Suns', 'Mira Vale', 28),
  ('Velvet Static', 'Night Transit', 260),
  ('Glasshouse', 'Juniper Lane', 140),
  ('Slow Comet', 'Atlas & Fern', 50),
  ('Harbour Lights', 'The Low Tides', 210),
  ('Northern Line', 'Kite Season', 300),
  ('Amber Hour', 'Mira Vale', 35),
  ('Static Bloom', 'Neon Orchard', 340),
  ('Low Orbit', 'Night Transit', 230),
  ('Wildflower FM', 'Juniper Lane', 100),
];

/// A music library: songs scroll under a search bar and a tab bar that
/// collapses to a circle on a scroll down, with the song playing beside it.
class LibraryScene extends StatefulWidget {
  const LibraryScene({super.key});

  @override
  State<LibraryScene> createState() => _LibrarySceneState();
}

class _LibrarySceneState extends State<LibraryScene> {
  final FocusNode _search = FocusNode();
  String _query = '';
  int _tab = 0;
  int _playing = 0;
  bool _paused = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _tab = i);
    if (i == 2) {
      _search.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.toLowerCase();
    final List<int> shown = <int>[
      for (var i = 0; i < _kSongs.length; i++)
        if ('${_kSongs[i].$1} ${_kSongs[i].$2}'.toLowerCase().contains(q)) i,
    ];
    final (String playing, String artist, double hue) = _kSongs[_playing];
    // Above the list and the bar both: the list's scrolls bubble up to it, and
    // the bar, which is not inside the list, reads it.
    return GlassTabBarMinimizer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RepaintBoundary(child: CustomPaint(painter: _LibraryPainter())),
          // By wheel, trackpad or mouse, not by a finger, which would trap the
          // page's own scroll here, as in the chat.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: <PointerDeviceKind>{PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
            ),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 72, 14, 150),
              itemCount: shown.length,
              itemBuilder: (BuildContext context, int n) {
                final int i = shown[n];
                final (String title, String by, double h) = _kSongs[i];
                return Semantics(
                  button: true,
                  selected: i == _playing,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _playing = i;
                      _paused = false;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: <Widget>[
                          _Artwork(hue: h, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: i == _playing ? _hsv(h, 0.5, 1) : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  by,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (i == _playing) SiteIcon(SFIcons.sf_waveform, size: 18, color: _hsv(h, 0.5, 1)),
                        ],
                      ),
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
            child: GlassSearchBar(
              focusNode: _search,
              placeholder: 'Songs and artists',
              onChanged: (String v) => setState(() => _query = v),
              onCancel: () => setState(() => _query = ''),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: GlassTabBar(
              items: const <GlassTabItem>[
                GlassTabItem(icon: SFIcons.sf_music_note_list, label: 'Library'),
                GlassTabItem(icon: SFIcons.sf_radio, label: 'Radio'),
                GlassTabItem(icon: SFIcons.sf_magnifyingglass, label: 'Search'),
              ],
              selectedIndex: _tab,
              onSelected: _select,
              minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown,
              // Above the bar, and beside its circle once it collapses: the
              // song changing is a repaint inside the glass.
              bottomAccessory: Builder(
                builder: (BuildContext context) {
                  final Color label = _label(context);
                  return Row(
                    children: <Widget>[
                      _Artwork(hue: hue, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$playing · $artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: label, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: _paused ? 'Play' : 'Pause',
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _paused = !_paused),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: SiteIcon(
                              _paused ? SFIcons.sf_play_fill : SFIcons.sf_pause_fill,
                              size: 18,
                              color: label,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A song's cover: a gradient in [hue] with a note.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.hue, required this.size});

  final double hue;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[_hsv(hue, 0.75, 0.95), _hsv(hue + 50, 0.85, 0.5)],
      ),
    ),
    child: SiteIcon(SFIcons.sf_music_note, size: size * 0.5, color: Colors.white),
  );
}

/// A dark stage with two coloured lights, so the glass has something to bend
/// where the list ends.
class _LibraryPainter extends CustomPainter {
  const _LibraryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawRect(
      all,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1A1030), Color(0xFF0B0B12)],
        ).createShader(all),
    );
    for (final (double x, double y, Color colour) in const <(double, double, Color)>[
      (0.15, 0.1, Color(0xAAFF375F)),
      (0.9, 0.95, Color(0xAA5E5CE6)),
    ]) {
      final Offset c = Offset(size.width * x, size.height * y);
      final double r = size.longestSide * 0.5;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_LibraryPainter oldDelegate) => false;
}
