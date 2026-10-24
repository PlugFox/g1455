// One pass of a separable Gaussian, for `ImageFilter.shader` on Impeller,
// where `ImageFilter.blur` cuts its kernel at `(σ' − 0.5)·√3` and moves in
// steps of the integer radius (`lib/src/proxy/proxy_blur.dart`). Two of these,
// across and then down, are the blur the finishes were calibrated with.
//
// Texel by texel, `ceil(3σ)` either side and the centre. Not in bilinear
// pairs, which would halve the fetches: the engine binds a filter's input
// nearest-sampled, so a fetch between two texels reads one of them. The edge
// is clamped to the texture's last texel, as `TileMode.clamp` does.

#version 460 core

#include <flutter/runtime_effect.glsl>

// Set by the engine: the size of the bound input, in texels.
uniform vec2 uSize;
// xy the direction of the pass, one texel long; z the sigma, in texels.
uniform vec3 uPass;
uniform sampler2D uInput;

out vec4 fragColor;

// Taps either side: 3σ for a sigma of up to `kGlassBlurMaxSigma`, 4.
const int kMaxTaps = 12;

vec4 tap(vec2 p) {
    vec2 uv = clamp(p, vec2(0.5), uSize - vec2(0.5)) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    return texture(uInput, uv);
}

void main() {
    vec2 p = FlutterFragCoord().xy;
    vec2 dir = uPass.xy;
    float sigma = uPass.z;
    float k = -0.5 / (sigma * sigma);
    float reach = ceil(3.0 * sigma);
    vec4 sum = tap(p);
    float total = 1.0;
    for (int i = 1; i <= kMaxTaps; i++) {
        float x = float(i);
        if (x > reach) {
            break;
        }
        float w = exp(x * x * k);
        sum += w * (tap(p + dir * x) + tap(p - dir * x));
        total += 2.0 * w;
    }
    fragColor = sum / total;
}
