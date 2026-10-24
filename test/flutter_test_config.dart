// The Gaussian the atlas is blurred with on Impeller is loaded before any
// test, as an application's `GlassHost.precache` loads it: a host that loads
// it itself captures its first proxies through `ImageFilter.blur` while it
// arrives, and a golden of those frames would depend on when it did.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:g1455/src/proxy/proxy_blur.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (ui.ImageFilter.isShaderFilterSupported) {
    glassBlurProgram = await ui.FragmentProgram.fromAsset(kGlassBlurShaderAsset);
  }
  await testMain();
}
