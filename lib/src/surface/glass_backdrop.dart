// A backdrop the application declares, so the glass over it captures nothing.
//
// The host's capture exists because the package cannot know what is behind the
// glass: it records the live tree into an atlas, once per change, and every
// surface samples its own slot. When the application *does* know — a page whose
// background is one colour, a wallpaper that never changes, a gradient — that
// capture is a snapshot of something already in hand. A declaration replaces
// it with a texture made once from what was declared: the glass below samples
// it through the same shader and the same map, and the host leaves those
// surfaces out of the atlas altogether. A screen whose glass is all declared
// takes no snapshot at all.
//
// The price is the declaration's truth. Glass over a declared backdrop shows
// the declaration, not the screen: a list scrolling under it is not refracted,
// and a backdrop that changes without saying so is shown as it was. That is why
// the widget paints what it declares under its child by default — the
// declaration is then true by construction for everything that sits directly
// on it — and why it is scoped to a subtree rather than set on the host: a page
// can declare its wallpaper and still let the one bar over its list capture.
//
// Nothing changes in the shader. A declared texture is an `AtlasSlot` like any
// other — a source rect on the screen, a rect in the texture, a ratio — so the
// map, the clamp to the slot and the optics are the ones every captured slot
// already goes through, and the blur is the pipeline's own arithmetic: the
// same divisor ceiling (`ProxyResolution.maxDivisorFor`) and the same residual
// in quadrature, paid once per declaration and finish rather than per capture.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../proxy/proxy_atlas.dart';
import '../proxy/proxy_pipeline.dart';
import '../proxy/proxy_resolution.dart';
import '../proxy/proxy_role.dart';

/// The longest side a declared texture is rendered at, in texels.
///
/// Well inside every GPU's limit (16384 on all measured, and Impeller crops past
/// it while reporting the size it was asked for). A backdrop larger than this
/// is rendered at a coarser divisor, which is a blur it was going to get anyway
/// at any finish with one.
const int _kMaxTextureSide = 4096;

/// The deepest divisor a declared texture is rendered at for its blur.
///
/// The pipeline's own ceiling for a finish ([ProxyResolution.maxDivisorFor]) is
/// the sharpest it allows; this caps it from the other side, because a
/// declared texture is rendered once and kept, so memory is all it saves.
const int _kMaxDivisor = 4;

/// How many blurred textures a declaration keeps, one per finish sigma.
///
/// A screen wears one to three finishes; a surface materializing animates its
/// sigma, and each frame of that asks for a texture no other frame will, so
/// the oldest go first. Leaving the cache does not release a texture a glass
/// is still drawn with: that draw holds it ([DeclaredTextureHold]) until it
/// is painted again, so the textures alive are at most these and one per
/// glass.
const int _kKeptTextures = 4;

/// What a [GlassBackdrop] declared, as the surfaces below it read it.
///
/// Made and owned by [GlassBackdrop]; found through [GlassBackdrop.maybeOf]. A
/// surface listens to it and repaints when what it declares changes — an image
/// that arrived, a painter that was replaced, a box that was resized.
///
/// What a report reads off it is [renders]: how many textures were made. A
/// declaration renders once per finish sigma and size, never per frame, and
/// a count that grows with frames says it is being re-rendered.
///
/// {@category Capture control}
class GlassBackdropDeclaration extends ChangeNotifier {
  GlassBackdropDeclaration._();

  GlassProxyPainter? _painter;
  Color? _solid;
  double _devicePixelRatio = 1;
  RenderBox? _box;
  final LinkedHashMap<double, _DeclaredTexture> _textures = LinkedHashMap<double, _DeclaredTexture>();
  bool _disposed = false;

  /// How many textures this declaration has rendered.
  int get renders => _renders;
  int _renders = 0;

  /// Whether the glass below can sample this declaration now.
  ///
  /// False while an image is still loading and before the widget is laid out;
  /// glass below captures as it would without a declaration until then, so a
  /// declared wallpaper that has not decoded yet is not a hole.
  bool get ready {
    final RenderBox? box = _box;
    return !_disposed &&
        _painter != null &&
        box != null &&
        box.attached &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0;
  }

  /// Where the declared backdrop is, in global logical pixels, or null when it
  /// is not laid out.
  ///
  /// Read at the moment of asking, like every geometry in the register: a
  /// backdrop inside a scrolled list moves without repainting.
  Rect? get globalRect {
    final RenderBox? box = _box;
    if (box == null || !box.attached || !box.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
  }

  GlassSampleSource? _textureFor(double sigma) {
    if (!ready) {
      return null;
    }
    final Size size = _box!.size;
    // Quantized, so a surface materializing — whose sigma moves every frame —
    // renders a texture per step rather than per frame. A quarter of a logical
    // pixel of blur is below what the eye separates at the sigmas finishes use.
    final double sigmaLogical = (sigma * 4).roundToDouble() / 4;
    // A colour is the same texel under every blur and at every size.
    final double key = _solid != null ? -1 : sigmaLogical;
    final _DeclaredTexture? kept = _textures.remove(key);
    if (kept != null && (_solid != null || (kept.size == size && kept.devicePixelRatio == _devicePixelRatio))) {
      _textures[key] = kept;
      return kept;
    }
    kept?._release();
    final _DeclaredTexture made = _solid != null ? _renderSolid(_solid!) : _render(_painter!, size, sigmaLogical);
    _renders++;
    _textures[key] = made;
    while (_textures.length > _kKeptTextures) {
      _textures.remove(_textures.keys.first)!._release();
    }
    return made;
  }

  _DeclaredTexture _renderSolid(Color color) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()
        ..color = color
        ..blendMode = BlendMode.src,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(1, 1);
    picture.dispose();
    return _DeclaredTexture(this, image, null, _devicePixelRatio, 0);
  }

  _DeclaredTexture _render(GlassProxyPainter painter, Size size, double sigmaLogical) {
    final double dpr = _devicePixelRatio;
    var divisor = sigmaLogical <= 0 ? 1 : ProxyResolution.maxDivisorFor(sigmaLogical, dpr).clamp(1, _kMaxDivisor);
    while (size.longestSide * dpr / divisor > _kMaxTextureSide) {
      divisor *= 2;
    }
    final double ratio = dpr / divisor;
    final int width = math.max(1, (size.width * ratio).ceil());
    final int height = math.max(1, (size.height * ratio).ceil());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..clipRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()))
      ..scale(ratio);
    painter.paint(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    ui.Image image = picture.toImageSync(width, height);
    picture.dispose();

    // The pipeline's arithmetic: what the divisor has already low-passed is
    // subtracted in quadrature, and only the rest is asked of the filter.
    final double? residual = sigmaLogical <= 0
        ? null
        : ProxyResolution.divisor(divisor).residualSigmaFor(sigmaLogical, dpr);
    if (residual != null && residual > 0) {
      final blurRecorder = ui.PictureRecorder();
      Canvas(blurRecorder).drawImage(
        image,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: residual * ratio,
            sigmaY: residual * ratio,
            // Clamped, as the atlas is: the edge of a declared backdrop is
            // where the declaration stops, not where the world goes dark.
            tileMode: TileMode.clamp,
          ),
      );
      final ui.Picture blurred = blurRecorder.endRecording();
      final ui.Image sharp = image;
      image = blurred.toImageSync(width, height);
      blurred.dispose();
      sharp.dispose();
    }
    return _DeclaredTexture(this, image, size, dpr, ratio);
  }

  void _update({GlassProxyPainter? painter, Color? solid, required double devicePixelRatio}) {
    final GlassProxyPainter? old = _painter;
    final bool changed =
        (old == null) != (painter == null) ||
        solid != _solid ||
        (old != null && painter != null && (old.runtimeType != painter.runtimeType || painter.shouldRepaint(old))) ||
        devicePixelRatio != _devicePixelRatio;
    _painter = painter;
    _solid = solid;
    _devicePixelRatio = devicePixelRatio;
    if (changed) {
      _invalidate();
    }
  }

  /// The box was laid out for the first time: the glass below can stop
  /// waiting on the capture.
  void _laidOut() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _invalidate() {
    for (final _DeclaredTexture texture in _textures.values) {
      texture._release();
    }
    _textures.clear();
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    super.dispose();
  }
}

/// The texture [declaration] holds for a finish blurred by [sigmaLogical],
/// rendered now if it is not held, or null when the declaration is not ready.
///
/// A function of the library rather than a member, so it is not API: what it
/// returns is the pipeline's own type, which an application has no use for.
GlassSampleSource? declaredTextureFor(GlassBackdropDeclaration declaration, double sigmaLogical) =>
    declaration._textureFor(sigmaLogical);

/// Keeps alive the declared texture a glass draw was recorded with.
///
/// A glass's draw is recorded again at composite time when the glass moved
/// without being painted, and it has to draw from the texture it was painted
/// with: asking the declaration again then could find it evicted — a surface
/// materializing nearby asks for a new blur step every frame — and would
/// render a new one in the middle of compositing. So the texture is held by
/// the draw rather than looked up, and the declaration's cache only decides
/// what is kept for the *next* paint. One per glass; released when the glass
/// paints from something else and when it is disposed.
final class DeclaredTextureHold {
  _DeclaredTexture? _texture;

  /// Holds [source] if it is a declared texture, and lets go of the one held
  /// before. A captured frame is the pipeline's to dispose and is not held.
  void hold(GlassSampleSource? source) {
    final _DeclaredTexture? next = source is _DeclaredTexture ? source : null;
    if (identical(next, _texture)) {
      return;
    }
    next?._retain();
    _texture?._release();
    _texture = next;
  }

  /// Lets go of the texture held, if any.
  void release() => hold(null);
}

/// One rendered texture of a declaration, and the slot that maps the screen
/// into it — computed when asked, because the backdrop may have moved since
/// the texture was made and the texture does not care.
///
/// Counted, not owned: the declaration's cache holds it once, and every glass
/// draw recorded with it once more ([DeclaredTextureHold]); the image goes
/// when the last of those lets go.
class _DeclaredTexture implements GlassSampleSource {
  _DeclaredTexture(this._owner, this.image, this.size, this.devicePixelRatio, this.ratio) {
    _alive++;
  }

  int _holds = 1;

  final GlassBackdropDeclaration _owner;

  @override
  final ui.Image image;

  /// The box size it was rendered for, or null for a colour, which fits any.
  final Size? size;

  final double devicePixelRatio;

  /// Texels per local logical pixel; zero for a colour.
  final double ratio;

  @override
  AtlasSlot? slotForKey(Object key) {
    final RenderBox? box = _owner._box;
    if (box == null || !box.attached || !box.hasSize) {
      return null;
    }
    final Matrix4 transform = box.getTransformTo(null);
    if (size == null) {
      final Rect source = MatrixUtils.transformRect(transform, Offset.zero & box.size);
      if (source.width <= 0) {
        return null;
      }
      // One texel, and the shader's clamp to its centre makes every sample it.
      return AtlasSlot(
        index: 0,
        members: const <int>[0],
        source: source,
        rect: const Rect.fromLTWH(0, 0, 1, 1),
        pixelRatio: 1 / source.width,
      );
    }
    // What the texture covers is its whole texel extent, a fraction of a pixel
    // past the box where the size was rounded up; the ratio is read back off
    // the screen so a scaled ancestor maps as it draws.
    final Rect covered = Rect.fromLTWH(0, 0, image.width / ratio, image.height / ratio);
    final Rect source = MatrixUtils.transformRect(transform, covered);
    if (source.width <= 0) {
      return null;
    }
    return AtlasSlot(
      index: 0,
      members: const <int>[0],
      source: source,
      rect: Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      pixelRatio: image.width / source.width,
    );
  }

  void _retain() {
    assert(_holds > 0, 'a released declared texture was held again');
    _holds++;
  }

  void _release() {
    assert(_holds > 0);
    if (--_holds == 0) {
      _alive--;
      image.dispose();
    }
  }
}

int _alive = 0;

/// How many declared textures exist, across every declaration: what a test
/// reads to see that none outlives both its declaration and its glass.
@visibleForTesting
int get debugDeclaredTexturesAlive => _alive;

/// Declares what is behind the glass in [child], so that glass samples the
/// declaration instead of a capture of the screen.
///
/// For a backdrop the application already knows and that does not change: a
/// page of one colour, a wallpaper, a gradient. The glass below draws through
/// the same shader and optics as captured glass, but the [GlassHost] leaves it
/// out of its capture — a screen whose glass is all declared takes no snapshot
/// at all, and a still one pays nothing per frame either way. The texture is
/// made once per finish blur and size, not per frame.
///
/// ```dart
/// GlassBackdrop.image(
///   const AssetImage('assets/wallpaper.jpg'),
///   child: Center(
///     child: GlassCard(child: Text('Over a wallpaper, captured never')),
///   ),
/// )
/// ```
///
/// **What it costs is truth, not time.** Glass in [child] shows the
/// declaration and nothing else: content between the backdrop and the glass —
/// a list scrolling under a bar, text under a card — is not refracted, and a
/// backdrop that changes without the declaration changing is shown as it was.
/// So the widget paints what it declares under [child] by default
/// ([paintBackdrop]), which makes it true for glass sitting straight on it; set
/// that to false only when something else already paints the same pixels at
/// the same place.
///
/// Scoped to the subtree, and the innermost declaration wins: a
/// [GlassBackdrop.live] inside one hands its own subtree back to the capture,
/// so a page can declare its wallpaper and still let the bar over its list
/// refract the list.
///
/// The map from the screen into the texture is a translation and a uniform
/// scale, read off the widget's box as it is on the screen. A declaration under
/// a rotation or a skew is mapped by its bounding box, which is not where it
/// is drawn: declare it outside the transform.
///
/// A [GlassHost] is still required above: it carries the shader and the
/// ledger. While an [ImageProvider] is loading the glass below captures as if
/// nothing were declared, so a declared wallpaper is never a hole.
///
/// See also:
///
///  * [GlassProxy], which says what a subtree is *inside* the capture; this
///    says the capture is not needed at all.
///  * [GlassBackdropDeclaration.renders], the counter a test reads to see the
///    texture was made once.
///
/// {@category Capture control}
class GlassBackdrop extends StatefulWidget {
  /// A backdrop of one colour.
  ///
  /// The cheapest declaration there is: a single texel, the same at every blur
  /// and every size. [color] should be opaque — glass samples it as the whole
  /// of what is behind.
  const GlassBackdrop.color(Color this.color, {super.key, this.paintBackdrop = true, required this.child})
    : painter = null,
      image = null,
      texture = null,
      fit = BoxFit.cover,
      alignment = Alignment.center,
      _live = false;

  /// A backdrop of [gradient] across this widget's box: the commonest painter,
  /// [GradientProxyPainter], by name.
  GlassBackdrop.gradient(Gradient gradient, {Key? key, bool paintBackdrop = true, required Widget child})
    : this.painter(GradientProxyPainter(gradient), key: key, paintBackdrop: paintBackdrop, child: child);

  /// A backdrop drawn by [painter] over this widget's box — a gradient
  /// ([GradientProxyPainter]), or anything a [GlassProxyPainter] can draw.
  ///
  /// The painter's `shouldRepaint` decides when the texture is made again.
  const GlassBackdrop.painter(
    GlassProxyPainter this.painter, {
    super.key,
    this.paintBackdrop = true,
    required this.child,
  }) : color = null,
       image = null,
       texture = null,
       fit = BoxFit.cover,
       alignment = Alignment.center,
       _live = false;

  /// A backdrop of [image], placed in this widget's box by [fit] and
  /// [alignment] as `DecorationImage` places one.
  ///
  /// Until the image has loaded the glass below captures the screen. So it
  /// does when [image] is replaced, until the new one has loaded; the old one
  /// stays painted under [child] meanwhile.
  const GlassBackdrop.image(
    ImageProvider this.image, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.paintBackdrop = true,
    required this.child,
  }) : color = null,
       painter = null,
       texture = null,
       _live = false;

  /// A backdrop of a texture the application already holds: a decoded image,
  /// a frame it rendered, a picture it rasterized.
  ///
  /// The caller keeps ownership and must not dispose [texture] while this
  /// widget shows it. Replace it with a new `ui.Image` to make the glass
  /// re-render; drawing into the same one is not a change anything can see.
  const GlassBackdrop.texture(
    ui.Image this.texture, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.paintBackdrop = true,
    required this.child,
  }) : color = null,
       painter = null,
       image = null,
       _live = false;

  /// Undoes a declaration above: glass in [child] captures the screen again.
  const GlassBackdrop.live({super.key, required this.child})
    : color = null,
      painter = null,
      image = null,
      texture = null,
      fit = BoxFit.cover,
      alignment = Alignment.center,
      paintBackdrop = false,
      _live = true;

  /// The colour of [GlassBackdrop.color], or null.
  final Color? color;

  /// The painter of [GlassBackdrop.painter], or null.
  final GlassProxyPainter? painter;

  /// The image of [GlassBackdrop.image], or null.
  final ImageProvider? image;

  /// The texture of [GlassBackdrop.texture], or null.
  final ui.Image? texture;

  /// How an image or texture is fitted into this widget's box.
  final BoxFit fit;

  /// Where an image or texture is aligned inside this widget's box.
  final AlignmentGeometry alignment;

  /// Whether this widget paints the declared backdrop under [child].
  ///
  /// True by default, which makes the declaration true by construction. False
  /// when the same pixels are already painted by something else — a
  /// `Scaffold.backgroundColor` declared again here — so they are not painted
  /// twice.
  final bool paintBackdrop;

  final bool _live;

  /// The subtree the declaration applies to.
  final Widget child;

  /// The declaration in force at [context], or null where glass captures.
  static GlassBackdropDeclaration? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassBackdropScope>()?.declaration;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('live', value: _live, ifTrue: 'live'))
      ..add(ColorProperty('color', color, defaultValue: null))
      ..add(DiagnosticsProperty<GlassProxyPainter>('painter', painter, defaultValue: null))
      ..add(DiagnosticsProperty<ImageProvider>('image', image, defaultValue: null))
      ..add(DiagnosticsProperty<ui.Image>('texture', texture, defaultValue: null))
      ..add(FlagProperty('paintBackdrop', value: paintBackdrop, ifFalse: 'declared only'));
  }
}

class _GlassBackdropState extends State<GlassBackdrop> {
  final GlassBackdropDeclaration _declaration = GlassBackdropDeclaration._();

  ImageStream? _stream;
  ImageInfo? _info;
  ImageStreamListener? _listener;

  /// Whether [_info] is the image of the provider in force, rather than the
  /// one it replaced and that is still painted while the new one loads.
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(GlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _resolve();
    }
  }

  void _resolve() {
    final ImageProvider? provider = widget.image;
    if (provider == null) {
      _stopListening();
      _setInfo(null);
      return;
    }
    final ImageStream stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) {
      return;
    }
    _stopListening();
    // Until the new image arrives the glass captures, as it does before the
    // first one: declaring the old image would be a declaration of something
    // no longer asked for. The old image stays painted under the child
    // meanwhile, so the screen does not flash, and the capture shows it.
    _loaded = false;
    _stream = stream;
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) => setState(() {
        _setInfo(info);
        _loaded = true;
      }),
      onError: (Object error, StackTrace? stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'g1455',
            context: ErrorDescription('while loading the image of a GlassBackdrop'),
          ),
        );
      },
    );
    stream.addListener(_listener!);
  }

  void _setInfo(ImageInfo? info) {
    final ImageInfo? old = _info;
    if (old != null && info != null && old.isCloneOf(info)) {
      info.dispose();
      return;
    }
    _info = info;
    old?.dispose();
  }

  void _stopListening() {
    final ImageStreamListener? listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  /// What the declaration samples: [_painter], except while a new image is
  /// still loading.
  GlassProxyPainter? get _declared {
    if (widget.image != null && widget.texture == null && !_loaded) {
      return null;
    }
    return _painter;
  }

  /// What is painted under the child, from the widget and whatever has loaded.
  GlassProxyPainter? get _painter {
    final ui.Image? image = widget.texture ?? _info?.image;
    if (image != null) {
      return _ImageBackdropPainter(image, widget.fit, widget.alignment.resolve(Directionality.maybeOf(context)));
    }
    if (widget.color != null) {
      return SolidProxyPainter(widget.color!);
    }
    return widget.painter;
  }

  void _sync() {
    _declaration._update(
      painter: widget._live ? null : _declared,
      solid: widget._live ? null : widget.color,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.maybeOf(context)?.devicePixelRatio ?? 1,
    );
  }

  @override
  void dispose() {
    _stopListening();
    _info?.dispose();
    _info = null;
    _declaration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return _GlassBackdropScope(
      declaration: widget._live ? null : _declaration,
      child: _GlassBackdropBox(
        declaration: _declaration,
        painter: widget._live || !widget.paintBackdrop ? null : _painter,
        child: widget.child,
      ),
    );
  }
}

class _GlassBackdropScope extends InheritedWidget {
  const _GlassBackdropScope({required this.declaration, required super.child});

  final GlassBackdropDeclaration? declaration;

  @override
  bool updateShouldNotify(_GlassBackdropScope oldWidget) => !identical(declaration, oldWidget.declaration);
}

class _GlassBackdropBox extends SingleChildRenderObjectWidget {
  const _GlassBackdropBox({required this.declaration, required this.painter, super.child});

  final GlassBackdropDeclaration declaration;
  final GlassProxyPainter? painter;

  @override
  _RenderGlassBackdrop createRenderObject(BuildContext context) => _RenderGlassBackdrop(declaration, painter);

  @override
  void updateRenderObject(BuildContext context, _RenderGlassBackdrop renderObject) {
    renderObject.painter = painter;
  }
}

/// Paints the declared backdrop under the child, and is the box the
/// declaration maps the screen into.
class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this._declaration, this._painter);

  final GlassBackdropDeclaration _declaration;

  GlassProxyPainter? _painter;
  set painter(GlassProxyPainter? value) {
    final GlassProxyPainter? old = _painter;
    _painter = value;
    if ((old == null) != (value == null) ||
        (old != null && value != null && (old.runtimeType != value.runtimeType || value.shouldRepaint(old)))) {
      markNeedsPaint();
    }
  }

  Size? _laidOut;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _declaration._box = this;
  }

  @override
  void detach() {
    if (identical(_declaration._box, this)) {
      _declaration._box = null;
    }
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (size != _laidOut) {
      final bool first = _laidOut == null;
      _laidOut = size;
      // The textures were rendered for the old box. The first layout has none,
      // but it is when the declaration becomes ready, and the glass below has
      // to stop waiting on the capture.
      if (first) {
        _declaration._laidOut();
      } else {
        _declaration._invalidate();
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final GlassProxyPainter? painter = _painter;
    if (painter != null && !size.isEmpty) {
      final Canvas canvas = context.canvas
        ..save()
        ..clipRect(offset & size)
        ..translate(offset.dx, offset.dy);
      painter.paint(canvas, size);
      canvas.restore();
    }
    super.paint(context, offset);
  }
}

/// An image placed in a box as `DecorationImage` places one.
class _ImageBackdropPainter extends GlassProxyPainter {
  const _ImageBackdropPainter(this.image, this.fit, this.alignment);

  final ui.Image image;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) => paintImage(
    canvas: canvas,
    rect: Offset.zero & size,
    image: image,
    fit: fit,
    alignment: alignment,
    filterQuality: FilterQuality.medium,
  );

  @override
  bool shouldRepaint(_ImageBackdropPainter oldPainter) =>
      !identical(oldPainter.image, image) && !oldPainter.image.isCloneOf(image) ||
      oldPainter.fit != fit ||
      oldPainter.alignment != alignment;
}
