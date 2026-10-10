// Value semantics of the package's small immutable types.
//
// `flutter test test/glass_value_semantics_test.dart`
//
// These types are compared, not just read: a widget's `updateRenderObject`
// assigns a new one and the setter repaints only when `==` says it changed, a
// theme's `updateShouldNotify` compares them, and a memo is keyed by them. So
// the way they go wrong is an `==` that forgets a field — the change is then
// silently not applied — or a `hashCode` that disagrees with `==`.
//
// Every arm is therefore the same shape: equal to an independently built copy
// with an equal hash, and unequal to each variant that differs in exactly one
// field. The per-field list is the point; an `==` that compared nothing but
// identity would pass a single "different object" check.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_atlas.dart';

/// [same] is built separately from [base], so identity cannot satisfy `==`;
/// each of [variants] differs from [base] in one named field.
void _checkValue<T extends Object>(T base, T same, Map<String, T> variants) {
  expect(identical(base, same), isFalse, reason: 'the copy has to be a second object');
  expect(same, base);
  expect(same.hashCode, base.hashCode);
  for (final MapEntry<String, T> v in variants.entries) {
    expect(v.value == base, isFalse, reason: '== ignores ${v.key}');
    expect(base == v.value, isFalse, reason: '== ignores ${v.key} (other side)');
  }
  expect(base == Object(), isFalse);
}

void main() {
  test('GlassRipple: every field takes part in ==, copyWith replaces only what it names', () {
    final base = GlassRipple(
      amplitude: 4,
      speed: 300,
      width: 10,
      viscosity: 0.5,
      press: 0.7,
      pressRadius: 20,
      light: 0.1,
    );
    _checkValue(base, base.copyWith(), <String, GlassRipple>{
      'amplitude': base.copyWith(amplitude: 5),
      'speed': base.copyWith(speed: 301),
      'width': base.copyWith(width: 11),
      'viscosity': base.copyWith(viscosity: 0.6),
      'press': base.copyWith(press: 0.8),
      'pressRadius': base.copyWith(pressRadius: 21),
      'light': base.copyWith(light: 0.2),
    });
    final GlassRipple thick = base.copyWith(viscosity: 1);
    expect(thick.viscosity, 1);
    expect(thick.amplitude, base.amplitude);
    expect(thick.light, base.light);
    // The derived quantities follow the one knob, so a copy with only the
    // viscosity changed must move them and nothing else.
    expect(thick.ringing, 0, reason: 'honey does not ring');
    expect(thick.springZeta, 1, reason: 'honey settles critically damped');
    expect(base.ringing, greaterThan(0));
    expect(
      base.toString(),
      'GlassRipple(amplitude 4.0, speed 300.0, width 10.0, viscosity 0.5, '
      'press 0.7, pressRadius 20.0, light 0.1)',
    );
  });

  test('GlassMorphMotion: duration and bounce both take part in ==', () {
    // ignore: prefer_const_constructors
    final base = GlassMorphMotion(duration: const Duration(milliseconds: 300), bounce: 0.1);
    _checkValue(
      base,
      // ignore: prefer_const_constructors
      GlassMorphMotion(duration: const Duration(milliseconds: 300), bounce: 0.1),
      <String, GlassMorphMotion>{
        // ignore: prefer_const_constructors
        'duration': GlassMorphMotion(duration: const Duration(milliseconds: 301), bounce: 0.1),
        // ignore: prefer_const_constructors
        'bounce': GlassMorphMotion(duration: const Duration(milliseconds: 300), bounce: 0.2),
      },
    );
    expect(GlassMorphMotion.fluid == GlassMorphMotion.calm, isFalse);
    expect(GlassMorphMotion.calm.bounce, 0, reason: 'calm is documented as critically damped');
  });

  test('GlassDropMotion: copyWith replaces only what it names', () {
    const base = GlassDropMotion(
      maxStretch: 0.2,
      saturation: 20000,
      smoothing: Duration(milliseconds: 20),
      stiffness: 800,
      damping: 28,
    );
    _checkValue(base, base.copyWith(), <String, GlassDropMotion>{
      'maxStretch': base.copyWith(maxStretch: 0.3),
      'saturation': base.copyWith(saturation: 21000),
      'smoothing': base.copyWith(smoothing: const Duration(milliseconds: 21)),
      'stiffness': base.copyWith(stiffness: 801),
      'damping': base.copyWith(damping: 29),
    });
    final GlassDropMotion flat = base.copyWith(maxStretch: 0);
    expect(flat.isNone, isTrue);
    expect(flat.stiffness, base.stiffness);
    expect(flat.reach(const Size(100, 40)), Size.zero, reason: 'a motion that deforms nothing reaches nowhere');
  });

  test('GlassFade: begin and end both take part in ==', () {
    final base = GlassFade.vertical(from: 10, extent: 30);
    _checkValue(base, GlassFade(begin: const Offset(0, 10), end: const Offset(0, 40)), <String, GlassFade>{
      'begin': GlassFade(begin: const Offset(0, 11), end: const Offset(0, 40)),
      'end': GlassFade(begin: const Offset(0, 10), end: const Offset(1, 40)),
    });
  });

  test('GlassTabItemLook: every field takes part in ==, and toString names the flags that are set', () {
    GlassTabItemLook look({
      int index = 1,
      Color color = const Color(0xFF112233),
      double iconSize = 26,
      TextStyle labelStyle = const TextStyle(fontSize: 10),
      bool selected = false,
      bool highlighted = false,
      bool inline = false,
    }) => GlassTabItemLook(
      index: index,
      color: color,
      iconSize: iconSize,
      labelStyle: labelStyle,
      selected: selected,
      highlighted: highlighted,
      inline: inline,
    );
    _checkValue(look(), look(), <String, GlassTabItemLook>{
      'index': look(index: 2),
      'color': look(color: const Color(0xFF112234)),
      'iconSize': look(iconSize: 20),
      'labelStyle': look(labelStyle: const TextStyle(fontSize: 11)),
      'selected': look(selected: true),
      'highlighted': look(highlighted: true),
      'inline': look(inline: true),
    });
    expect(look().toString(), 'GlassTabItemLook(1, ${const Color(0xFF112233)})');
    expect(
      look(selected: true, highlighted: true, inline: true).toString(),
      'GlassTabItemLook(1, ${const Color(0xFF112233)}, selected, highlighted, inline)',
    );
  });

  test('GlassThermalPolicy: every allowance takes part in ==', () {
    // ignore: prefer_const_constructors
    final base = GlassThermalPolicy(fairDeltaE: 0.1, seriousDeltaE: 0.2, criticalDeltaE: 0.3);
    _checkValue(
      base,
      // ignore: prefer_const_constructors
      GlassThermalPolicy(fairDeltaE: 0.1, seriousDeltaE: 0.2, criticalDeltaE: 0.3),
      <String, GlassThermalPolicy>{
        // ignore: prefer_const_constructors
        'fairDeltaE': GlassThermalPolicy(fairDeltaE: 0.15, seriousDeltaE: 0.2, criticalDeltaE: 0.3),
        // ignore: prefer_const_constructors
        'seriousDeltaE': GlassThermalPolicy(fairDeltaE: 0.1, seriousDeltaE: 0.25, criticalDeltaE: 0.3),
        // ignore: prefer_const_constructors
        'criticalDeltaE': GlassThermalPolicy(fairDeltaE: 0.1, seriousDeltaE: 0.2, criticalDeltaE: 0.35),
      },
    );
    expect(base.allowanceFor(null), 0);
    expect(base.allowanceFor(GlassThermalState.fair), 0.1);
    expect(GlassThermalPolicy.never == const GlassThermalPolicy(), isFalse);
  });

  test('GlassTierPolicy: every input takes part in ==', () {
    // ignore: prefer_const_constructors
    final base = GlassTierPolicy(pinned: GlassTier.cheap, reduceTransparency: true, ceiling: GlassTier.opaque);
    _checkValue(
      base,
      // ignore: prefer_const_constructors
      GlassTierPolicy(pinned: GlassTier.cheap, reduceTransparency: true, ceiling: GlassTier.opaque),
      <String, GlassTierPolicy>{
        // ignore: prefer_const_constructors
        'pinned': GlassTierPolicy(pinned: GlassTier.full, reduceTransparency: true, ceiling: GlassTier.opaque),
        // ignore: prefer_const_constructors
        'reduceTransparency': GlassTierPolicy(pinned: GlassTier.cheap, ceiling: GlassTier.opaque),
        // ignore: prefer_const_constructors
        'ceiling': GlassTierPolicy(pinned: GlassTier.cheap, reduceTransparency: true, ceiling: GlassTier.cheap),
      },
    );
  });

  test('ProxyResolution: the named constructors are the divisors they name, and print as such', () {
    // Not const on purpose: a const constructor evaluated at compile time is
    // not the constructor a caller who builds one at runtime runs.
    // ignore: prefer_const_constructors
    final ProxyResolution full = ProxyResolution.full();
    // ignore: prefer_const_constructors
    final ProxyResolution half = ProxyResolution.half();
    // ignore: prefer_const_constructors
    final ProxyResolution quarter = ProxyResolution.quarter();
    expect(<int>[full.divisor, half.divisor, quarter.divisor], <int>[1, 2, 4]);
    // ignore: prefer_const_constructors
    _checkValue(half, ProxyResolution.divisor(2), <String, ProxyResolution>{'divisor': quarter});
    expect(full.toString(), 'ProxyResolution.full');
    expect(quarter.toString(), 'ProxyResolution.divisor(4)');
    expect(quarter.ratioFor(3), 0.75);
  });

  test('ProxyResolutionChoice prints every column, and a dash for the ones nobody measured', () {
    final ProxyResolutionChoice measured = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.frameCharged,
    );
    final String text = measured.toString();
    expect(text, startsWith('ProxyResolutionChoice(1/${measured.resolution.divisor}, ${measured.reason.name}, '));
    expect(text, contains('dE ${measured.damage!.deltaE.toStringAsFixed(3)}'));
    expect(text, contains('capture ${measured.captureCostFactor!.toStringAsFixed(2)}'));
    expect(text, contains('route ${measured.routeCostFactor!.factor.toStringAsFixed(2)}'));

    const blank = ProxyResolutionChoice(
      resolution: ProxyResolution.full(),
      reason: ProxyDivisorReason.damageBudget,
      damage: null,
      captureCostFactor: null,
      routeCostFactor: null,
    );
    expect(blank.toString(), 'ProxyResolutionChoice(1/1, damageBudget, dE —, capture —, route —)');
  });

  test('CaptureCost is C_pass per pass plus k per device pixel', () {
    // ignore: prefer_const_constructors
    final cost = CaptureCost(passes: 2, areaDevicePx: 1000);
    expect(cost.cycles(), 2 * CaptureCost.cPass + CaptureCost.kHeavy * 1000);
    expect(cost.cycles(k: CaptureCost.kFlat), 2 * CaptureCost.cPass + CaptureCost.kFlat * 1000);
    expect(cost.cycles(k: CaptureCost.kFlat), lessThan(cost.cycles()), reason: 'flat content is cheaper to capture');
  });

  test('GlassFusedTile prints its rectangle and the shapes it folds', () {
    const tile = GlassFusedTile(Rect.fromLTWH(0, 0, 10, 20), <int>[0, 2]);
    expect(tile.toString(), 'GlassFusedTile(${const Rect.fromLTWH(0, 0, 10, 20)}, [0, 2])');
  });

  test('GlassSurfaceRecord prints its rectangle, rounded shape area and rung', () {
    const record = GlassSurfaceRecord(rect: Rect.fromLTWH(1, 2, 30, 40), shapeArea: 1150.6, tier: GlassTier.cheap);
    expect(record.toString(), 'GlassSurfaceRecord(${const Rect.fromLTWH(1, 2, 30, 40)}, shape 1151 px², cheap)');
  });

  test('GlassLedger.bounds is the union of what its surfaces report, and null with none', () {
    final ledger = GlassLedger();
    expect(ledger.bounds, isNull);
    ledger
      ..register(_FixedSurface(const Rect.fromLTWH(10, 20, 30, 40)))
      ..register(_FixedSurface(const Rect.fromLTWH(100, 0, 10, 10)))
      ..register(_FixedSurface(null));
    expect(ledger.registeredCount, 3);
    expect(ledger.bounds, const Rect.fromLTRB(10, 0, 110, 60));
  });

  test('GlassLoad prints its count, screens and verdict, and the tax only when priced', () {
    final ledger = GlassLedger()..register(_FixedSurface(const Rect.fromLTWH(0, 0, 200, 400)));
    final GlassLoad priced = ledger.read(viewSize: const Size(400, 800), model: GlassSurfaceCostModel.adrenoCycles);
    expect(priced.taxCycles, isNotNull);
    expect(
      priced.toString(),
      'GlassLoad(1 surfaces, ${priced.screensOfGlass.toStringAsFixed(2)} screens, ${priced.verdict.name}, '
      '${(priced.taxCycles! / 1000).toStringAsFixed(1)}k cycles)',
    );
    final GlassLoad unpriced = ledger.read(viewSize: const Size(400, 800), model: GlassSurfaceCostModel.unmeasured);
    expect(unpriced.taxCycles, isNull);
    expect(unpriced.toString(), 'GlassLoad(1 surfaces, 0.25 screens, ${unpriced.verdict.name})');
  });

  testWidgets('GlassProxy describes its role and painter', (WidgetTester tester) async {
    const painter = SolidProxyPainter(Color(0xFF010203));
    const proxy = GlassProxy.replace(painter: painter, child: SizedBox());
    final String widgetText = proxy.toStringDeep();
    expect(widgetText, contains('role: replace'));
    expect(widgetText, contains('painter: '));
    expect(const GlassProxy.opaque(child: SizedBox()).toStringDeep(), isNot(contains('painter:')));

    await tester.pumpWidget(proxy);
    final RenderGlassProxy render = tester.renderObject(find.byType(GlassProxy));
    expect(render.role, GlassProxyRole.replace);
    expect(render.painter, same(painter));
    final String renderText = render.toStringDeep();
    expect(renderText, contains('role: replace'));
    expect(renderText, contains('painter: '));
  });

  test('the stand-in painters say when they are opaque and when they repaint', () {
    // ignore: prefer_const_constructors
    final opaque = SolidProxyPainter(const Color(0xFF000000));
    expect(opaque.isOpaque, isTrue);
    expect(const SolidProxyPainter(Color(0xFE000000)).isOpaque, isFalse);
    // ignore: prefer_const_constructors
    final gradient = GradientProxyPainter(
      const LinearGradient(colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)]),
    );
    expect(gradient.isOpaque, isFalse, reason: 'a gradient stub is never reported opaque');
    expect(gradient.shouldRepaint(GradientProxyPainter(gradient.gradient)), isFalse);
    expect(
      gradient.shouldRepaint(
        const GradientProxyPainter(LinearGradient(colors: <Color>[Color(0xFF000000), Color(0xFF808080)])),
      ),
      isTrue,
    );
  });
}

/// A surface that reports a fixed rectangle, or nothing.
class _FixedSurface implements GlassSurfaceGeometry {
  _FixedSurface(this.rect);

  final Rect? rect;

  @override
  Layer? get compositedLayer => null;

  @override
  Layer? get drawLayer => null;

  @override
  bool get excludedFromProxy => true;

  @override
  GlassSurfaceRecord? readGeometry() {
    final Rect? r = rect;
    return r == null ? null : GlassSurfaceRecord(rect: r, shapeArea: r.width * r.height);
  }
}
