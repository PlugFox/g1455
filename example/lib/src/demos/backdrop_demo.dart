import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:g1455/g1455.dart';
// The host's counters: read here to show whether it captures. An application
// has no reason to import this library.
import 'package:g1455/glass_diagnostics.dart' show GlassProxyHandle, GlassProxyScope;

import '../app/theme.dart';
import '../backdrops.dart';
import '../widgets/site_icon.dart';
import '../widgets/stage.dart';

/// Glass over a backdrop that does not change, captured as usual or declared
/// with [GlassBackdrop], with what the glass samples and what the host
/// captures read off underneath.
class BackdropDemo extends StatefulWidget {
  const BackdropDemo({super.key});

  @override
  State<BackdropDemo> createState() => _BackdropDemoState();
}

enum _Kind {
  color('Colour'),
  gradient('Gradient'),
  photo('Photo');

  const _Kind(this.label);

  final String label;
}

/// The colour of the colour backdrop.
const Color _kColour = Color(0xFF2C6E8F);

/// The size the photo is rendered at once, for [GlassBackdrop.texture].
const Size _kPhotoSize = Size(960, 600);

class _BackdropDemoState extends State<BackdropDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  final GlobalKey _glassKey = GlobalKey();

  /// A picture the app already holds: the case [GlassBackdrop.texture] is for.
  late final ui.Image _photo = _renderPhoto();

  _Kind _kind = _Kind.gradient;
  bool _declared = true;

  /// The declaration in force under the stage, as the glass there reads it.
  GlassBackdropDeclaration? _declaration;

  static ui.Image _renderPhoto() {
    final recorder = ui.PictureRecorder();
    photoPainter(11).paint(Canvas(recorder), _kPhotoSize);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(_kPhotoSize.width.toInt(), _kPhotoSize.height.toInt());
    picture.dispose();
    return image;
  }

  @override
  void dispose() {
    _motion.dispose();
    // The GlassBackdrop showing it was unmounted before this state.
    _photo.dispose();
    super.dispose();
  }

  void _setMotion(bool on) {
    if (on) {
      _motion.repeat();
    } else {
      _motion.stop();
    }
    setState(() {});
  }

  /// The backdrop as a painter: declared as it is, or painted by a
  /// [CustomPaint] for the host to capture. The same pixels either way.
  GlassProxyPainter get _painter => switch (_kind) {
    _Kind.color => const SolidProxyPainter(_kColour),
    _Kind.gradient => const GradientProxyPainter(
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF0A84FF), Color(0xFFBF5AF2), Color(0xFFFF9F0A)],
      ),
    ),
    _Kind.photo => _CoverPainter(_photo),
  };

  Widget _backdrop(Widget child) {
    if (!_declared) {
      return CustomPaint(painter: _Adapter(_painter), child: child);
    }
    return switch (_kind) {
      // Keyed by kind, so each declaration counts its own textures.
      _Kind.color => GlassBackdrop.color(
        _kColour,
        key: const ValueKey<_Kind>(_Kind.color),
        child: child,
      ),
      _Kind.gradient => GlassBackdrop.painter(_painter, key: const ValueKey<_Kind>(_Kind.gradient), child: child),
      _Kind.photo => GlassBackdrop.texture(_photo, key: const ValueKey<_Kind>(_Kind.photo), child: child),
    };
  }

  /// What the readout shows, read when it asks.
  _Reading _read() {
    var surfaces = 0;
    var declared = 0;
    void visit(RenderObject node) {
      if (node is RenderGlassSurface) {
        surfaces++;
        if (node.readsDeclaredBackdrop) {
          declared++;
        }
      }
      node.visitChildren(visit);
    }

    final RenderObject? root = _glassKey.currentContext?.findRenderObject();
    if (root != null) {
      visit(root);
    }
    return (surfaces: surfaces, declared: declared, renders: _declared ? _declaration?.renders : null);
  }

  // The stage, then the readout under it.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _stage(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: _Readout(read: _read),
      ),
    ],
  );

  Widget _stage() => DemoStage(
    height: 360,
    background: const ColoredBox(color: Color(0xFF000000)),
    knobs: <Widget>[
      KnobChoice<_Kind>(
        label: 'Backdrop',
        values: _Kind.values,
        selected: _kind,
        labelOf: (_Kind k) => k.label,
        onChanged: (_Kind k) => setState(() => _kind = k),
      ),
      KnobSwitch(label: 'Declared', value: _declared, onChanged: (bool v) => setState(() => _declared = v)),
      KnobSwitch(label: 'Motion under the glass', value: _motion.isAnimating, onChanged: _setMotion),
    ],
    hint: _declared
        ? 'Declared: the glass samples a texture made once, and the host captures nothing for it. '
              'Turn on the motion: the glass does not see the disc, because it shows the declaration.'
        : 'Captured: the host records the backdrop under the glass. '
              'Turn on the motion: the glass refracts the disc, and the host captures on every frame.',
    child: _backdrop(
      Builder(
        builder: (BuildContext context) {
          // Kept for the readout, which is outside the declaration's subtree.
          _declaration = GlassBackdrop.maybeOf(context);
          return Stack(
            key: _glassKey,
            children: <Widget>[
              // Between the backdrop and the glass: what a declaration does not show.
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (BuildContext context, Widget? disc) => Align(
                      alignment: Alignment(math.sin(_motion.value * 2 * math.pi) * 0.8, -0.05),
                      child: disc,
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
                      child: const SiteIcon(SFIcons.sf_star_fill, size: 28, color: Color(0xFFFF375F)),
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment(-0.45, -0.1),
                child: SizedBox.square(
                  dimension: 120,
                  child: GlassSurface(borderRadius: kGlassCapsule, finish: GlassFinish.clear, labelled: false),
                ),
              ),
              const Align(
                alignment: Alignment(0.5, -0.1),
                child: SizedBox(
                  width: 150,
                  height: 120,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SiteIcon(SFIcons.sf_sun_max, size: 22),
                        Spacer(),
                        Text('21°', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                        Text('Sunny', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment(0, 0.82),
                child: FractionallySizedBox(
                  widthFactor: 0.8,
                  child: GlassBar(child: Text('Over a backdrop that does not change', overflow: TextOverflow.ellipsis)),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// A [GlassProxyPainter] as a [CustomPainter], so the captured arm paints the
/// very pixels the declared one declares.
class _Adapter extends CustomPainter {
  const _Adapter(this.painter);

  final GlassProxyPainter painter;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, size);

  @override
  bool shouldRepaint(_Adapter oldDelegate) =>
      oldDelegate.painter.runtimeType != painter.runtimeType || painter.shouldRepaint(oldDelegate.painter);
}

/// The photo fitted as [GlassBackdrop.texture] fits it by default.
class _CoverPainter extends GlassProxyPainter {
  const _CoverPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) =>
      paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.cover);

  @override
  bool shouldRepaint(_CoverPainter oldPainter) => !identical(oldPainter.image, image);
}

typedef _Reading = ({int surfaces, int declared, int? renders});

/// What the glass on the stage samples, how many textures the declaration
/// made, and how many captures the host took in the last second.
///
/// The host is the site's, and its sidebar glass spans the page, so any
/// repaint on the page is a capture, the readout's own included. So it is
/// read once a second and repainted only when what it says changes, and a
/// rate below [_kAtRest] reads as at rest: otherwise its own repaint would be
/// the capture it reports, and the next second's reading would repaint it
/// again.
class _Readout extends StatefulWidget {
  const _Readout({required this.read});

  final _Reading Function() read;

  @override
  State<_Readout> createState() => _ReadoutState();
}

/// Captures a second that are the readout's own, not the glass's.
const int _kAtRest = 3;

class _ReadoutState extends State<_Readout> {
  GlassProxyHandle? _handle;
  Timer? _timer;
  int _last = 0;
  int _perSecond = 0;
  _Reading? _reading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final GlassProxyHandle? handle = GlassProxyScope.maybeOf(context);
    if (!identical(handle, _handle)) {
      _handle = handle;
      _last = handle?.generation ?? 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final int now = _handle?.generation ?? _last;
    final int perSecond = now - _last < _kAtRest ? 0 : now - _last;
    final _Reading reading = widget.read();
    _last = now;
    // Repainted only when it says something new: a still page stays still.
    if (perSecond != _perSecond || reading != _reading) {
      setState(() {
        _perSecond = perSecond;
        _reading = reading;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Reading? r = _reading;
    if (r == null) {
      return const SizedBox.shrink();
    }
    final String samples = r.declared == r.surfaces
        ? 'declaration ${r.declared}/${r.surfaces}'
        : r.declared == 0
        ? 'capture ${r.surfaces}/${r.surfaces}'
        : 'declaration ${r.declared}/${r.surfaces}, capture ${r.surfaces - r.declared}';
    final String text = <String>[
      'glass samples $samples',
      if (r.renders case final int renders) 'textures made $renders',
      if (_perSecond == 0) 'host at rest' else 'host captures/s $_perSecond',
    ].join(' · ');
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SiteIcon(SFIcons.sf_camera, size: 16, color: _perSecond > 0 ? kSiteAccent : kSiteTextMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kSiteText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
