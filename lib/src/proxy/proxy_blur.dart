// What `ImageFilter.blur` delivers, and what to ask of it for the sigma meant.
//
// The finishes were calibrated against Skia's blur, which delivers the sigma
// it is asked for, in steps of its own. Impeller's does not: it cuts its
// kernel at `(σ' − 0.5)·√3`, where `σ' = ScaleSigma(σ)`
// (`impeller/geometry/sigma.cc`, `gaussian_blur_filter_contents.cc`), so a
// Gaussian loses most of its tails, nothing under about 0.8 blurs at all, and
// the result moves in steps of the integer radius. On an M2 iPad Pro the
// calibrated `regular`, asked for 2.6 texels, delivered 2.13.
//
// So on Impeller the sigma asked for is the one whose kernel delivers the
// sigma meant: read off a table of what Impeller delivers for each sigma
// asked, measured with the MTF instrument of `test/proxy_blur_test.dart` on
// that iPad, Impeller/Metal, and on `flutter_tester --enable-impeller`, which
// agrees with the device to 0.02 on average and 0.11 at worst. The kernel is
// computed on the CPU, the same on every Impeller backend, and measured so: a
// Galaxy S22 Ultra on Vulkan and on GLES reads the same to the last digit,
// and 0.02 from the iPad. Skia is left as it is: the calibration is its.
//
// That correction gets the width right and not the shape: the kernel is still
// cut short and its steps still show, as a soft edge that reads 0.09 of its
// contrast where Skia's reads 0.17. So on Impeller the atlas is blurred by
// the package's own Gaussian, `glass_blur.frag` ([saveBlurLayers]), which
// delivers the sigma asked to 1-2% on Metal, Vulkan and GLES and costs up
// to 0.3 ms of GPU time a frame on an M2 iPad (FINDINGS D239). The
// correction is what is used until that program has loaded, and past
// [kGlassBlurMaxSigma], where the integer radius is a step of a few percent.
//
// The renderer is told apart by `ImageFilter.isShaderFilterSupported`, true
// on Impeller and false on Skia and on the web.

import 'dart:ui' as ui;

/// The Gaussian-equivalent sigma Impeller's `ImageFilter.blur` delivers, in
/// texels, for the sigma asked at index `i`, which is `i / 10`: 0 to 12.
///
/// Read off the MTF of a bar grating at seven periods, the median of them,
/// with the filter clamped and drawn at identity, as the pipeline draws it.
/// To 10.8 on the iPad; above that on `flutter_tester`, which the iPad agrees
/// with below it. The few readings a step lower than the one before are the
/// instrument's, a few hundredths.
const List<double> kImpellerBlurDelivered = <double>[
  0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, //
  0.688, 0.723, 0.742, 0.761, 0.772, 0.778, 1.171, 1.197, //
  1.223, 1.251, 1.270, 1.283, 1.660, 1.683, 1.723, 1.756, //
  1.769, 1.795, 2.127, 2.169, 2.183, 2.220, 2.253, 2.261, //
  2.622, 2.658, 2.696, 2.707, 2.737, 2.753, 3.103, 3.129, //
  3.143, 3.174, 3.210, 3.247, 3.578, 3.609, 3.640, 3.668, //
  3.707, 3.739, 4.070, 4.113, 4.152, 4.172, 4.304, 4.329, //
  4.590, 4.613, 4.778, 5.159, 5.122, 5.131, 5.182, 5.193, //
  5.260, 5.382, 5.392, 5.415, 5.476, 5.488, 5.494, 6.212, //
  6.266, 6.317, 6.378, 6.420, 6.426, 6.535, 6.388, 6.416, //
  6.440, 6.462, 6.528, 7.028, 7.070, 7.123, 7.142, 7.196, //
  7.222, 7.357, 7.394, 7.438, 7.451, 7.485, 7.533, 8.042, //
  8.114, 8.132, 8.171, 8.261, 8.286, 8.361, 8.413, 8.437, //
  8.471, 8.504, 8.555, 8.620, 9.152, 9.212, 9.308, 9.314, //
  9.360, 9.418, 9.467, 9.508, 9.552, 9.634, 10.508, 10.519, //
  10.234,
];

/// Whether this renderer's blur is Impeller's.
final bool _impeller = ui.ImageFilter.isShaderFilterSupported;

/// The sigma to give `ImageFilter.blur`, in texels, for a Gaussian of
/// [sigma] texels on the renderer this runs on — [impeller] says which, for
/// a test.
///
/// On Skia, [sigma]. On Impeller, the sigma asked whose delivery in
/// [kImpellerBlurDelivered] is nearest [sigma], to a tenth; past the table,
/// [sigma] scaled by the table's last ratio. Under about 0.35 the nearest is
/// no blur, which is also what Impeller would have drawn.
double engineBlurSigma(double sigma, {bool? impeller}) {
  if (sigma <= 0 || !(impeller ?? _impeller)) {
    return sigma;
  }
  const List<double> delivered = kImpellerBlurDelivered;
  final int last = delivered.length - 1;
  if (sigma > delivered[last]) {
    return sigma * (last / 10) / delivered[last];
  }
  var best = 0;
  var error = double.infinity;
  for (var i = 0; i <= last; i++) {
    final double e = (delivered[i] - sigma).abs();
    if (e < error) {
      error = e;
      best = i;
    }
  }
  return best / 10;
}

/// The separable Gaussian of `glass_blur.frag`, one pass a layer.
const String kGlassBlurShaderAsset = 'packages/g1455/shaders/glass_blur.frag';

/// The largest sigma, in texels, [saveBlurLayers] blurs through
/// [glassBlurProgram]: 13 texels a pass.
///
/// Past it the engine's blur is used, corrected. Its error is a step of the
/// integer radius, and above 4 texels that is 2-6% of the sigma and of its
/// spread over frequency, where under 3 it was up to 25%. And it downsamples:
/// `frosted` at its policy divisor on a Galaxy S22 Ultra is 12 texels, which
/// the shader drew at 52% more GPU time a frame and the engine at none.
const double kGlassBlurMaxSigma = 4;

/// The compiled Gaussian, once a host has loaded it (`GlassHost.precache`, or
/// the first host's own load); null on Skia, where `ImageFilter.shader` does
/// not exist and `ImageFilter.blur` is the Gaussian, and until it arrives.
ui.FragmentProgram? glassBlurProgram;

/// Whether the atlas is blurred through [glassBlurProgram] when there is one,
/// or always through `ImageFilter.blur` corrected by [engineBlurSigma]: the
/// comparison the bench's `glass_gauss` axis draws.
bool debugGlassBlurShader = true;

/// Opens the layers that blur what is drawn into them by [sigmaTexels] over
/// [bounds], and returns how many to restore.
///
/// Through [glassBlurProgram] on Impeller, once it is loaded and for a sigma
/// up to [kGlassBlurMaxSigma]; otherwise one layer of `ImageFilter.blur`,
/// asked [engineBlurSigma] of it and clamped.
///
/// Two nested layers, across and then down, rather than one layer of
/// `ImageFilter.compose`: the composed filter hands its outer pass an input
/// padded with transparency, so the second pass cannot clamp to the edge.
int saveBlurLayers(ui.Canvas canvas, ui.Rect bounds, double sigmaTexels) {
  final ui.FragmentProgram? program = debugGlassBlurShader ? glassBlurProgram : null;
  if (program == null || sigmaTexels > kGlassBlurMaxSigma) {
    final double asked = engineBlurSigma(sigmaTexels);
    canvas.saveLayer(
      bounds,
      ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: asked, sigmaY: asked, tileMode: ui.TileMode.clamp),
    );
    return 1;
  }
  ui.Paint pass(double dx, double dy) => ui.Paint()
    ..imageFilter = ui.ImageFilter.shader(
      program.fragmentShader()
        ..setFloat(2, dx)
        ..setFloat(3, dy)
        ..setFloat(4, sigmaTexels),
    );
  canvas
    ..saveLayer(bounds, pass(0, 1))
    ..saveLayer(bounds, pass(1, 0));
  return 2;
}
