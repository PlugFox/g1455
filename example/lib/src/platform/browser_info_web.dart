import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWasm;

import 'browser_info.dart';

// The few corners of the DOM this reads, as extension types: no package:web,
// and nothing typed that is not used.

@JS('document')
external _Document get _document;

@JS('navigator')
external _Navigator get _navigator;

@JS('screen')
external _Screen get _screen;

@JS('devicePixelRatio')
external double get _devicePixelRatio;

extension type _Document._(JSObject _) implements JSObject {
  external _Canvas createElement(String tag);
}

extension type _Canvas._(JSObject _) implements JSObject {
  external JSObject? getContext(String id);
}

extension type _Navigator._(JSObject _) implements JSObject {
  external int get hardwareConcurrency;

  /// Chromium only; gigabytes, rounded down to a power of two.
  external JSNumber? get deviceMemory;

  /// WebGPU, where the browser has it.
  external JSObject? get gpu;
}

extension type _Screen._(JSObject _) implements JSObject {
  external int get width;
  external int get height;
  external int get colorDepth;
}

extension type _WebGL2._(JSObject _) implements JSObject {
  external JSAny? getParameter(int name);
  external JSObject? getExtension(String name);
  external JSArray<JSString>? getSupportedExtensions();
  external JSObject? getContextAttributes();
}

// The WebGL2 enums read, by value: the context has them as properties, but a
// constant is one lookup fewer and cannot be misspelt at run time.
const int _kVendor = 0x1F00;
const int _kRenderer = 0x1F01;
const int _kVersion = 0x1F02;
const int _kShadingLanguageVersion = 0x8B8C;
const int _kMaxTextureSize = 0x0D33;
const int _kMaxRenderbufferSize = 0x84E8;
const int _kMaxViewportDims = 0x0D3A;
const int _kMaxSamples = 0x8D57;
const int _kMaxTextureImageUnits = 0x8872;
const int _kMaxFragmentUniformVectors = 0x8DFD;
const int _kMaxColorAttachments = 0x8CDF;
const int _kUnmaskedVendor = 0x9245;
const int _kUnmaskedRenderer = 0x9246;

BrowserInfo? readBrowserInfo() {
  final groups = <BrowserFacts>[];
  int? maxTexture;
  final _WebGL2? gl = _context();
  if (gl != null) {
    maxTexture = _int(gl.getParameter(_kMaxTextureSize));
    // The real GPU, where the browser still tells it: Firefox and Safari
    // answer with a generic name, or not at all.
    final bool unmasked = gl.getExtension('WEBGL_debug_renderer_info') != null;
    final String? viewport = switch (gl.getParameter(_kMaxViewportDims)) {
      final JSObject dims when dims.isA<JSInt32Array>() => (dims as JSInt32Array).toDart.join(' × '),
      _ => null,
    };
    groups
      ..add(
        BrowserFacts('GPU', <(String, String)>[
          ('Vendor', _string(gl.getParameter(unmasked ? _kUnmaskedVendor : _kVendor))),
          ('Renderer', _string(gl.getParameter(unmasked ? _kUnmaskedRenderer : _kRenderer))),
        ]),
      )
      ..add(
        BrowserFacts('WebGL2', <(String, String)>[
          ('Version', _string(gl.getParameter(_kVersion))),
          ('GLSL', _string(gl.getParameter(_kShadingLanguageVersion))),
          ('Max texture', _px(maxTexture)),
          ('Max renderbuffer', _px(_int(gl.getParameter(_kMaxRenderbufferSize)))),
          ('Max viewport', viewport == null ? '—' : '$viewport px'),
          ('MSAA samples', '${_int(gl.getParameter(_kMaxSamples)) ?? '—'}'),
          ('Texture units', '${_int(gl.getParameter(_kMaxTextureImageUnits)) ?? '—'}'),
          ('Fragment uniforms', '${_int(gl.getParameter(_kMaxFragmentUniformVectors)) ?? '—'} vec4'),
          ('Colour attachments', '${_int(gl.getParameter(_kMaxColorAttachments)) ?? '—'}'),
          ('Extensions', '${gl.getSupportedExtensions()?.length ?? 0}'),
          ('Float render targets', gl.getExtension('EXT_color_buffer_float') == null ? 'no' : 'yes'),
        ]),
      );
  } else {
    groups.add(const BrowserFacts('WebGL2', <(String, String)>[('Available', 'no')]));
  }
  final _Navigator nav = _navigator;
  final double ratio = _devicePixelRatio;
  final _Screen s = _screen;
  groups
    ..add(
      BrowserFacts('Display', <(String, String)>[
        ('Screen', '${s.width} × ${s.height} pt'),
        ('Device pixel ratio', ratio.toStringAsFixed(ratio.truncateToDouble() == ratio ? 0 : 2)),
        ('Physical', '${(s.width * ratio).round()} × ${(s.height * ratio).round()} px'),
        ('Colour depth', '${s.colorDepth} bit'),
      ]),
    )
    ..add(
      BrowserFacts('Runtime', <(String, String)>[
        // dart2wasm draws with Skwasm; dart2js with CanvasKit.
        ('Flutter renderer', kIsWasm ? 'Skwasm (WebAssembly)' : 'CanvasKit (JavaScript)'),
        ('Logical cores', '${nav.hardwareConcurrency}'),
        (
          'Memory',
          switch (nav.deviceMemory) {
            final JSNumber gb => '≥ ${gb.toDartDouble.toStringAsFixed(0)} GB',
            null => 'not told',
          },
        ),
        ('WebGPU', nav.gpu == null ? 'no' : 'yes'),
      ]),
    );
  return BrowserInfo(groups: groups, maxTextureSize: maxTexture);
}

/// A WebGL2 context of a canvas of its own, never attached to the page.
_WebGL2? _context() {
  try {
    final JSObject? context = _document.createElement('canvas').getContext('webgl2');
    return context == null ? null : _WebGL2._(context);
  } on Object {
    return null;
  }
}

String _string(JSAny? value) => value.isA<JSString>() ? (value as JSString).toDart : '—';

int? _int(JSAny? value) => value.isA<JSNumber>() ? (value as JSNumber).toDartInt : null;

String _px(int? value) => value == null ? '—' : '$value px';
