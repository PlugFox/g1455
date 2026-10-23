// What the package asks of `ImageFilter.blur` for the sigma it means, on each
// renderer.
//
// `flutter test test/proxy_blur_sigma_test.dart`
//
// The table is a measurement (`lib/src/proxy/proxy_blur.dart`); this file
// checks the arithmetic on it. That the asked sigma delivers the meant one is
// `proxy_blur_test.dart`'s instrument arm, under `--enable-impeller`.
//
// Breaks, each undone by swapping the string back:
//  - in `engineBlurSigma`, `!(impeller ?? _impeller)` -> `false`: the Skia arm
//    finds its sigma changed;
//  - `final double e = (delivered[i] - sigma).abs();` -> `(i / 10 - sigma)
//    .abs();`: the Impeller arm asks for the sigma meant, and delivers less.

import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_blur.dart';

void main() {
  test('on Skia the sigma meant is the sigma asked', () {
    for (final double sigma in <double>[0, 0.5, 1.6, 2.6, 8, 20]) {
      expect(engineBlurSigma(sigma, impeller: false), sigma);
    }
  });

  test('on Impeller the sigma asked is the one whose kernel delivers the sigma meant', () {
    // The finishes' sigmas in texels, at ratios 1 to 3.
    for (final double sigma in <double>[1.6, 2.6, 3.2, 4.8, 5.2, 7.8, 8]) {
      final double asked = engineBlurSigma(sigma, impeller: true);
      final double delivered = kImpellerBlurDelivered[(asked * 10).round()];
      expect(asked, greaterThan(sigma), reason: 'Impeller under-delivers everywhere, so the ask is larger');
      expect(delivered, closeTo(sigma, sigma * 0.08), reason: 'asked $asked for $sigma delivers $delivered');
    }
    // The calibrated `regular` at a ratio of 1: 3.2 delivers 2.62.
    expect(engineBlurSigma(2.6, impeller: true), 3.2);
  });

  test('on Impeller a sigma below what any kernel delivers asks for none, and past the table it scales', () {
    expect(engineBlurSigma(0.2, impeller: true), 0, reason: 'nothing under 0.8 blurs; no blur is nearer');
    expect(engineBlurSigma(0, impeller: true), 0);
    final double ratio = 12 / kImpellerBlurDelivered.last;
    expect(engineBlurSigma(20, impeller: true), closeTo(20 * ratio, 1e-9));
  });
}
