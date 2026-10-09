// Whose measurements apply — the one thing the host declares that decides
// every cost answer this package gives.
//
// The package prices two questions, the capture and the translucency tax, and
// both were measured on the same two devices only. Their answers differ in
// shape, not just in a constant: the capture is charged by area on Adreno and by
// the frame on Metal (almost a factor of four on one knob), and the translucency
// tax is a linear law over a third of a screen on Adreno and a flat stretch with
// a cliff at 19 screens on Metal. Two enums name those model *shapes*; this one
// names the *device family*, because that is what an application can know.
//
// **The capture model is not the cost of the route.** On Metal the two are 40%
// apart: the capture is scale-free there and the route is not, because the
// residual blur, the texture's bandwidth and the shader's sampling all pay by
// area. Hence the name [captureCostModel]: the resolution policy reads it as
// evidence that a lever exists and then decides on quality, and the merge
// criterion, which really is a capture question, reads it as a price.
//
// **It cannot be detected.** `defaultTargetPlatform` separates Apple from
// everything else, and Metal is the only backend Flutter ships on Apple
// platforms, so that half is answerable. Android is not: the capture model was
// fitted on Adreno 830, the same grid on Xclipse 920 fitted nothing, and no
// Flutter API names the GPU. kgsl's sysfs nodes would identify an Adreno, but
// that probe has not been validated, so it does not ship. The host declares
// instead, as it declares occlusion, reduced transparency and proxy roles.

import 'package:flutter/foundation.dart';

import 'proxy/proxy_resolution.dart';
import 'surface/glass_ledger.dart';

/// The device family whose measurements apply.
///
/// One declaration, two questions. Declaring the wrong one is not a crash: it
/// makes the package quote a price that belongs to another device. The
/// *choices* — the proxy's divisor, whether slots merge — do not depend on it:
/// they are made on quality, and the lever they pull has the same sign on every
/// family measured.
///
/// Handed to [GlassHost.hardware]; null there means [detect]. The same value
/// reads the glass ledger through [surfaceCostModel]:
///
/// ```dart
/// final GlassHardware hardware = GlassHardware.detect();
/// final GlassLoad? load = GlassScope.maybeOf(context)?.read(
///   viewSize: MediaQuery.sizeOf(context),
///   model: hardware.surfaceCostModel,
/// );
/// ```
///
/// A host that knows it runs on an Adreno 830 says so, because nothing in Dart
/// can tell it:
///
/// ```dart
/// GlassHost(hardware: GlassHardware.adrenoVulkan, child: const MyScreen())
/// ```
///
/// See also:
///
///  * [ProxyCostModel] and [GlassSurfaceCostModel], the two model shapes this
///    one name selects.
///  * [ProxyBlurPass.defaultFor], the one default keyed on it.
///  * <https://g1455.plugfox.dev/start/declarations> and
///    <https://g1455.plugfox.dev/foundations/performance>.
///
/// {@category Cost and policy}
enum GlassHardware {
  /// Adreno 830 / Impeller-Vulkan, where every cycle number in this package
  /// was measured (Galaxy S25 Ultra SM-S938B, Snapdragon 8 Elite, Android 16,
  /// cycles read off kgsl as busy × frequency).
  ///
  /// Declaring this on another Adreno is an extrapolation the host owns: the
  /// laws were fitted on one chip. Declaring it on a Mali or an Xclipse is
  /// wrong in a way that shows up as a proxy recorded at a quarter of the
  /// resolution for a saving nobody has seen.
  adrenoVulkan,

  /// Apple Metal, measured on an M2 iPad Pro (11" 4th generation, iPad14,3) on
  /// iPadOS 26.6.1.
  ///
  /// The one family where the whole route was measured end to end rather than
  /// assembled from per-pass estimates.
  appleMetal,

  /// Anything else, which is most things — every Android device a silent host
  /// runs on. Every price refuses; the choices do not.
  ///
  /// The conservative end of the divisor lever is the *pulled* end, because its
  /// sign is the same on every device measured: on a Galaxy S22 Ultra (Xclipse
  /// 920), full resolution ran at 37 fps where a quarter ran at 115.
  unmeasured;

  /// What can be told without the host saying anything.
  ///
  /// Apple platforms are [appleMetal] — Flutter ships no other backend there —
  /// and everything else is [unmeasured], including every Android device,
  /// because no Dart API names the GPU. This is a floor, not a guess: a host
  /// that knows better declares better.
  static GlassHardware detect() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return GlassHardware.appleMetal;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return GlassHardware.unmeasured;
    }
  }

  /// How this hardware charges for a capture — the input
  /// [ProxyResolutionPolicy.choose] needs.
  ProxyCostModel get captureCostModel {
    switch (this) {
      case GlassHardware.adrenoVulkan:
        return ProxyCostModel.areaCharged;
      case GlassHardware.appleMetal:
        return ProxyCostModel.frameCharged;
      case GlassHardware.unmeasured:
        return ProxyCostModel.unmeasured;
    }
  }

  /// The largest texture this family is *guaranteed* to allocate, in device
  /// pixels a side — the bound the atlas is checked against before it is
  /// recorded (`AtlasLayout.fitsTexture`).
  ///
  /// **Every number here is a specification floor, not a measurement**: Vulkan
  /// guarantees `maxImageDimension2D >= 4096`, and Metal's feature-set tables
  /// put the oldest family Flutter still runs on at 8192. Real devices are far
  /// above both (16384 on the Apple, Xclipse and Adreno GPUs measured), so a
  /// host that knows its device should say so: [GlassHost.maxTextureSide]
  /// overrides this, and raising it buys quality back, because the pipeline's
  /// only response to the ceiling is a deeper divisor.
  ///
  /// The limit cannot be asked for, but it can be observed: `GetSize()` reports
  /// the size that was requested rather than the texture's, so a cropped
  /// snapshot is invisible to arithmetic but visible in pixels. Snapshot
  /// `side x 8` and check, through a second ordinary snapshot (never
  /// `toByteData` on the suspect image itself), whether the texel at
  /// `(side - 1, 0)` was drawn.
  ///
  /// The Apple floor stays at 8192 although measured devices report 16384:
  /// Flutter's app template deploys to iOS 15, which still runs on the A8
  /// iPad mini 4 and iPad Air 2 — Apple GPU family 2, whose tables say 8192.
  int get maxTextureSide {
    switch (this) {
      case GlassHardware.appleMetal:
        return 8192;
      case GlassHardware.adrenoVulkan:
      case GlassHardware.unmeasured:
        return 4096;
    }
  }

  /// Which measurements the glass ledger reads itself against — the `model`
  /// [GlassLedger.read] takes.
  GlassSurfaceCostModel get surfaceCostModel {
    switch (this) {
      case GlassHardware.adrenoVulkan:
        return GlassSurfaceCostModel.adrenoCycles;
      case GlassHardware.appleMetal:
        return GlassSurfaceCostModel.metalThroughput;
      case GlassHardware.unmeasured:
        return GlassSurfaceCostModel.unmeasured;
    }
  }
}
