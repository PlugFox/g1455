import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

// More scenes for the home page's gallery, each something to play with rather
// than to look at: a calculator that counts, notifications that are swiped
// away, a pond that ripples, and a lens to drag over a page.

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
  (SFIcons.sf_envelope_fill, Color(0xFF0A84FF), 'Mail', 'pub.dev', 'g1455 0.1.4 is published'),
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
