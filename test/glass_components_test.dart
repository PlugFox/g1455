// Level 3 — `GlassBar`, `GlassCard`, `GlassButton`.
//
// `flutter test test/glass_components_test.dart`
//
// The components are three default sets over one body, so most of what could go
// wrong in them is not theirs. What *is* theirs is one piece of arithmetic and
// one shape, and both of them have a measurable answer:
//
//  1. **The level under a label is the same at all three rungs, and it is the
//     declared law.** Over a
//     declared backdrop the full rung shows `mix(backdrop, tint, a)` because a
//     low-pass of a level is that level, the cheap rung shows it by
//     construction, and the opaque one by declaration. Read in pixels at the
//     centre of the panel, where the refraction is exactly zero, across two
//     finishes and two themes.
//  2. **So one label colour is legible at every rung — and it has to be chosen
//     against that level and not against the tint.** Twelve cells, each
//     required to clear WCAG AA against the level actually drawn. The break is
//     choosing off the tint. It fires on
//     `frosted` over a dark screen and **not** on `regular`, which is why the
//     arm carries two finishes.
//  3. **The capsule, and what declaring one found.** `RSuperellipse.contains`
//     does not scale radii and every draw does, so an oversized radius reads as
//     an ellipse and draws as a stadium: 9425 px² of declared glass against
//     11 214 drawn. The register's own control is `contains`, so the register
//     could not have caught it.
//  4. **A component is one surface, and a component holding components is not.**
//     The register counts what the tree declares; the fragmentation excess is
//     charged per draw and grows as the square of the count, so a bar of
//     five glass buttons carries thirty-six times one panel's excess term. Not
//     forbidden — counted.
//  5. **The press adds exactly the rim, and it adds rather than covers** — and
//     an enclosing `saveLayer` costs it twelve times its size. The rim is the
//     one additive quantity in the package that was measured, spent
//     over the shape instead of along its edge; where the sum happens matters
//     more than where the overlay sits, and both readings are in the arm.
//  6. **And the same arithmetic says the cheap rung's rim is not
//     `saveLayer`-safe, while the full rung's is.** The rim is additive on the
//     canvas below the top rung and inside the fragment above it, so one
//     `Opacity` anywhere above a panel takes a cheap panel's edge contrast from
//     35 code values to 3 and leaves a full panel's at 40. "Same shape, same
//     rim" across the rungs is conditional on the widget tree, and the other
//     two rungs are the arm's own control.
//  7. **With nothing declared about the backdrop the label is chosen against
//     every backdrop, and it says so only where that is not enough.** Both
//     available guesses (the tint, an assumed theme) were measured wrong; the
//     worst case over every backdrop is not a guess, and on `regular` it is
//     white at AA over any image.
//  8. **Disabled, a button keeps its glass and dims its label to iOS's
//     `tertiaryLabel` of the polarity it would have drawn** — and takes
//     no press. Disabled under a finger is the edge: the framework cancels the
//     tap from inside the build that removed the handlers, and the button has
//     to have let go already or that cancel is a `setState` during build.
//
// Four breaks, each failing its own arm: the level replaced by the tint in
// `foregroundOver` (1); `scaleRadii` dropped from `RenderGlassSurface.shapeAt`
// (3, and 1 as well, because the shader is handed the same radius);
// `BlendMode.plus` replaced by `srcOver`, so the overlay covers instead of
// adding (5); the missing-backdrop branch made to fall back to the tint instead
// of the worst case (7).
//
// **And one break that failed to break, which is a finding rather than a spare
// test.** The overlay was put behind a `RepaintBoundary` of its own on
// the theory that `plus` would then add to transparency. Every arm passed: a
// repaint boundary lowers to `SceneBuilder.pushOffset`, and that engine layer
// paints its children onto the same canvas rather than into a texture of their
// own. What does cut an additive draw off is a `saveLayer` — opacity, colour
// filter, image filter, backdrop — and the arm that replaced the boundary with
// an `Opacity` measured the size of it.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/src/surface/glass_components.dart' show debugResetGlassBackdropReport;

// The arms print the levels and the contrast ratios; a person reads them once.
// ignore_for_file: avoid_print

const Size kScreen = Size(360, 220);
const Size kPanel = Size(200, 60);

/// A light screen and a dark one. Both are levels an application would actually
/// declare — a `ColorScheme.surface` at either end — rather than 0 and 255,
/// which would make every contrast ratio flatter.
const Color kLight = Color(0xFFE8E8E8);
const Color kDark = Color(0xFF101014);

void main() {
  // -------------------------------------------------------------------------
  // 1 and 2. The level, and the colour chosen against it.
  // -------------------------------------------------------------------------

  testWidgets('the level under a label is the same at all three rungs, and the '
      'label colour clears AA against it', (WidgetTester tester) async {
    for (final GlassFinish finish in <GlassFinish>[GlassFinish.regularDark, GlassFinish.frosted]) {
      for (final Color backdrop in <Color>[kLight, kDark]) {
        final Color predicted = finish.opaqueFillOver(backdrop);
        final Color foreground = finish.foregroundOver(backdrop);
        final levels = <GlassTier, _Rgb>{};
        for (final GlassTier tier in GlassTier.values) {
          levels[tier] = await _levelUnderPanel(
            tester,
            finish: finish,
            backdrop: backdrop,
            tier: tier,
          );
        }
        final double ratio = GlassFinish.contrastRatio(
          levels[GlassTier.full]!.color,
          foreground,
        );
        print(
          '${finish.name} over ${_hex(backdrop)}: predicted ${_hex(predicted)}, drawn '
          '${levels.entries.map((e) => '${e.key.name} ${e.value}').join(', ')}; '
          'label ${_hex(foreground)} at ${ratio.toStringAsFixed(2)}:1',
        );

        // The law, in pixels. Two code values is the floor for this
        // measurement: an 8-bit composite reads a transmission of 0.307 back as
        // 0.3045 and 0.3023.
        for (final GlassTier tier in GlassTier.values) {
          expect(
            levels[tier]!.distanceTo(predicted),
            lessThanOrEqualTo(2),
            reason:
                '${finish.name}/${_hex(backdrop)}/${tier.name}: drawn ${levels[tier]} '
                'against the law\'s ${_hex(predicted)}',
          );
        }
        // And the rungs against each other, which is what licenses one colour
        // for all three. Stated separately from the line above because two
        // arms that each miss the law by two code values in opposite
        // directions are four apart from one another.
        for (final GlassTier tier in <GlassTier>[GlassTier.cheap, GlassTier.opaque]) {
          expect(
            levels[tier]!.distanceTo(levels[GlassTier.full]!.color),
            lessThanOrEqualTo(2),
            reason:
                '${finish.name}/${_hex(backdrop)}: ${tier.name} and full disagree about '
                'the level a label sits on',
          );
        }
        // WCAG AA for body text, against the level that was actually drawn
        // rather than against the one that was predicted.
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${finish.name} over ${_hex(backdrop)}: the label it picked reads at '
              '${ratio.toStringAsFixed(2)}:1 on the glass it picked it for',
        );
      }
    }

    // The axis is real, and this is what says so: the same arithmetic answers
    // differently for the two finishes. `frosted` transmits 0.78 and therefore
    // follows the theme; `regular` transmits 0.307 and is dark over either
    // screen, so its label is white on both — the measured fact read
    // forward ("`.regular` is dark not because it lays something dark over the
    // backdrop but because it barely transmits it").
    expect(GlassFinish.frosted.foregroundOver(kLight), const Color(0xFF000000));
    expect(GlassFinish.frosted.foregroundOver(kDark), const Color(0xFFFFFFFF));
    expect(GlassFinish.regularDark.foregroundOver(kLight), const Color(0xFFFFFFFF));
    expect(GlassFinish.regularDark.foregroundOver(kDark), const Color(0xFFFFFFFF));
  });

  // -------------------------------------------------------------------------
  // 3. The capsule.
  // -------------------------------------------------------------------------

  testWidgets('a capsule is scaled once, and the register reads the shape that is drawn', (
    WidgetTester tester,
  ) async {
    await _mount(
      tester,
      finish: GlassFinish.regularDark,
      backdrop: kLight,
      tier: GlassTier.cheap,
      content: SizedBox.fromSize(
        size: kPanel,
        child: const GlassButton(padding: EdgeInsets.zero, child: SizedBox.shrink()),
      ),
    );
    final surface = tester.renderObject<RenderGlassSurface>(find.byType(GlassSurface));

    // Half the shorter side, which is what the engine's own `scaleRadii` makes
    // of a radius that does not fit, and what both shaders therefore have to be
    // given.
    // `closeTo` rather than equality: `scaleRadii` reaches half the shorter side
    // by multiplying by `height / (2 * 1e9)`, which is one rounding short of it.
    expect(surface.effectiveRadius, closeTo(kPanel.height / 2, 1e-9));
    expect(surface.shape.tlRadiusY, closeTo(kPanel.height / 2, 1e-9));

    final double declared = surface.readGeometry()!.shapeArea;
    // What the same declaration says without the scaling — an ellipse, because
    // `contains` clamps each axis on its own instead of scaling both. This is
    // the defect the capsule made reachable, and the register's own control
    // could not see it: `glass_ledger_test.dart` checks the area against
    // `contains`, and `contains` agrees with the wrong number.
    final double unscaled = GlassLedger.shapeAreaOf(
      kGlassCapsule.toRSuperellipse(Offset.zero & kPanel),
    );
    final double drawn = await _coverageOf(
      tester,
      kGlassCapsule.toRSuperellipse(Offset.zero & kPanel).scaleRadii(),
    );
    print(
      'capsule ${kPanel.width}x${kPanel.height}: register $declared, drawn $drawn, '
      'unscaled $unscaled (${(100 * (1 - unscaled / drawn)).toStringAsFixed(1)}% low)',
    );

    // 0.4% is the gap the register's own dartdoc records and declines to fit: a
    // stadium's corner fills one half-extent and not the other, so it sits
    // between the superellipse constant and the circular one.
    expect((declared - drawn).abs() / drawn, lessThan(0.004));
    expect(
      1 - unscaled / drawn,
      closeTo(0.16, 0.005),
      reason: 'the unscaled radius stopped being wrong, so this arm measures nothing',
    );
  });

  // -------------------------------------------------------------------------
  // 4. What the register counts.
  // -------------------------------------------------------------------------

  testWidgets('a bar is one surface and a bar of buttons is six, and the excess says so', (
    WidgetTester tester,
  ) async {
    Future<GlassLoad> mountBar({required bool glassItems}) async {
      await _mount(
        tester,
        finish: GlassFinish.regularDark,
        backdrop: kLight,
        tier: GlassTier.full,
        content: SizedBox(
          width: 320,
          child: GlassBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 0; i < 5; i++)
                  if (glassItems)
                    GlassButton(onPressed: () {}, child: const SizedBox(width: 12, height: 12))
                  else
                    const SizedBox(width: 44, height: 44),
              ],
            ),
          ),
        ),
      );
      final GlassLedger ledger = tester.widget<GlassScope>(find.byType(GlassScope)).ledger;
      expect(ledger.clusters, isEmpty, reason: 'a component declared a blend group');
      return ledger.read(
        viewSize: kScreen,
        model: GlassSurfaceCostModel.adrenoCycles,
      );
    }

    final GlassLoad plain = await mountBar(glassItems: false);
    final GlassLoad nested = await mountBar(glassItems: true);
    print(
      'bar of plain items: ${plain.surfaceCount} surfaces, excess '
      '${plain.fragmentationExcessCycles!.toStringAsFixed(1)} cycles; '
      'bar of glass buttons: ${nested.surfaceCount}, '
      '${nested.fragmentationExcessCycles!.toStringAsFixed(1)}',
    );
    expect(plain.surfaceCount, 1);
    expect(nested.surfaceCount, 6);
    // The excess is quadratic in the count, so the ratio is 36 exactly. The
    // point of asserting it is that the number reaches the application at all:
    // the decision is taken in the widget tree and paid for on the GPU.
    expect(
      nested.fragmentationExcessCycles! / plain.fragmentationExcessCycles!,
      closeTo(36, 1e-9),
    );
  });

  // -------------------------------------------------------------------------
  // 5. The press.
  // -------------------------------------------------------------------------

  testWidgets('holding a button adds the rim over the whole shape, additively', (
    WidgetTester tester,
  ) async {
    Future<_Rgb> centre({required bool held, Color? overlay, bool inALayer = false}) async {
      Widget button = GlassButton(
        onPressed: () {},
        pressedOverlay: overlay,
        padding: EdgeInsets.zero,
        child: const SizedBox.shrink(),
      );
      if (inALayer) {
        // 0.99 rather than 1.0: the framework skips the layer entirely at one,
        // and what is under test is the layer.
        button = Opacity(opacity: 0.99, child: button);
      }
      await _mount(
        tester,
        finish: GlassFinish.regularDark,
        backdrop: kLight,
        tier: GlassTier.cheap,
        content: SizedBox.fromSize(size: kPanel, child: button),
      );
      TestGesture? gesture;
      if (held) {
        gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
        await tester.pump();
      }
      final _Rgb read = await _readCentre(tester);
      await gesture?.up();
      return read;
    }

    final _Rgb resting = await centre(held: false);
    final _Rgb pressed = await centre(held: true);
    final _Rgb inert = await centre(held: true, overlay: const Color(0x00000000));
    final int added = pressed.r - resting.r;
    print('resting $resting, held $pressed (+$added), held with no overlay $inert');

    // 50.2 of 255, neutral, and *added*: the rim is the one additive quantity
    // here that was measured rather than chosen, and the press spends
    // it over the shape instead of along the edge. A `plus` of a premultiplied
    // white at alpha 50.2/255 adds exactly that many code values.
    expect(added, closeTo(50, 2));
    expect(pressed.g - resting.g, closeTo(50, 2));
    expect(pressed.b - resting.b, closeTo(50, 2));
    // The control: with nothing to add, holding changes nothing. Without it the
    // arm above would pass on a press that redrew the panel brighter for any
    // reason at all.
    expect(inert.distanceTo(resting.color), lessThanOrEqualTo(1));

    // And the rule about *where* the sum happens, which is not where it was
    // first written down. `plus` adds to whatever is on the canvas it is
    // recorded on; an enclosing `saveLayer` makes that the layer's own
    // contents, and on a flat rung those are a fill at alpha 0.693 rather than
    // an opaque panel — so the addition lands on almost nothing and is then
    // diluted again on composite. One `Opacity` above the control costs the
    // press **twelve times its size**, and it does not have to be between the
    // overlay and the glass: around the whole thing is enough.
    final _Rgb layeredResting = await centre(held: false, inALayer: true);
    final _Rgb layeredPressed = await centre(held: true, inALayer: true);
    final int layeredAdded = layeredPressed.r - layeredResting.r;
    print(
      'inside a saveLayer: $layeredResting -> $layeredPressed (+$layeredAdded), '
      'against +$added bare',
    );
    expect(layeredAdded, lessThan(10));
    expect(added / layeredAdded, greaterThan(8));
  });

  // -------------------------------------------------------------------------
  // 6. The same arithmetic, applied to the rim the ladder promised to keep.
  // -------------------------------------------------------------------------

  testWidgets('a saveLayer takes the cheap rung\'s rim and leaves the full rung\'s', (
    WidgetTester tester,
  ) async {
    // Found by the press and not aimed at: the rim is drawn with the same
    // additive blend, so it is exposed the same way — and only on the rungs that
    // draw it on the canvas. Above the top rung it is a term inside the
    // fragment, which no enclosing layer can reach.
    final contrast = <GlassTier, List<int>>{};
    for (final GlassTier tier in GlassTier.values) {
      final readings = <int>[];
      for (final bool layered in <bool>[false, true]) {
        Widget panel = SizedBox.fromSize(
          size: kPanel,
          child: const GlassCard(padding: EdgeInsets.zero, child: SizedBox.shrink()),
        );
        if (layered) {
          panel = Opacity(opacity: 0.99, child: panel);
        }
        await _mount(
          tester,
          finish: GlassFinish.regularDark,
          backdrop: kLight,
          tier: tier,
          content: KeyedSubtree(key: ValueKey<bool>(layered), child: panel),
        );
        // The first column inside the panel's box, against the fill six columns
        // in. Inside rather than across the edge, because the column outside it
        // is the backdrop, which is brighter than the rim and would swamp the
        // reading.
        final int left = ((kScreen.width - kPanel.width) / 2).round();
        final List<int> row = await _readRow(
          tester,
          y: (kScreen.height / 2).round(),
          from: left,
          to: left + 7,
        );
        readings.add(row.first - row.last);
      }
      contrast[tier] = readings;
    }
    print(
      'edge contrast, bare then inside a saveLayer: '
      '${contrast.entries.map((e) => '${e.key.name} ${e.value}').join(', ')}',
    );

    // The full rung's rim is a term in the fragment and cannot be reached.
    expect((contrast[GlassTier.full]![0] - contrast[GlassTier.full]![1]).abs(), lessThanOrEqualTo(3));
    // The opaque rung draws it on the canvas, but over an opaque fill, so what
    // it adds to is still there. (The outer half of the stroke, which straddles
    // outside the shape over transparency, is lost on both flat rungs.)
    expect(
      (contrast[GlassTier.opaque]![0] - contrast[GlassTier.opaque]![1]).abs(),
      lessThanOrEqualTo(3),
    );
    // And the cheap rung, which adds to a fill at alpha 0.693 inside a layer
    // that holds nothing else, loses almost all of it.
    expect(contrast[GlassTier.cheap]![0], greaterThanOrEqualTo(30));
    expect(contrast[GlassTier.cheap]![1], lessThanOrEqualTo(6));
  });

  // -------------------------------------------------------------------------
  // 7. Nothing declared.
  // -------------------------------------------------------------------------

  testWidgets('with no backdrop declared the label is chosen against every backdrop', (
    WidgetTester tester,
  ) async {
    // The two available guesses were both measured wrong; the worst case over
    // every backdrop is not a guess, and needs only the finish. So the arm asks three
    // things — that the bound is spent, that it is quiet where the bound is AA
    // (regular), and that it says so where the bound is not (frosted).
    debugResetGlassBackdropReport();
    // Collects this file's own report and **forwards** everything else.
    // Replacing the handler outright swallows `flutter_test`'s own failure
    // reporting, and then a failing arm hangs instead of failing.
    final errors = <String>[];
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if ('${details.exception}'.contains('GlassThemeData.backdrop')) {
        errors.add('${details.exception}');
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    Color? recorded;
    Color? recordedIcon;
    Widget probe() => Builder(
      builder: (BuildContext context) {
        recorded = DefaultTextStyle.of(context).style.color;
        recordedIcon = IconTheme.of(context).color;
        return const SizedBox(width: 40, height: 20);
      },
    );

    const Color ambient = Color(0xFF3366CC);
    Widget card() => DefaultTextStyle(
      style: const TextStyle(color: ambient),
      child: IconTheme(
        data: const IconThemeData(color: ambient),
        child: GlassCard(child: probe()),
      ),
    );

    await _mount(tester, finish: GlassFinish.regularDark, backdrop: null, tier: GlassTier.cheap, content: card());
    print('no backdrop, regular: label ${_hex(recorded!)}, ${errors.length} report(s)');
    expect(recorded, const Color(0xFFFFFFFF));
    expect(recordedIcon, const Color(0xFFFFFFFF));
    expect(GlassFinish.regularDark.worstContrast(recorded!), greaterThanOrEqualTo(kTextContrastAA));
    expect(errors, isEmpty, reason: 'regular is AA over every backdrop; there is nothing to say');

    await _mount(tester, finish: GlassFinish.frosted, backdrop: null, tier: GlassTier.cheap, content: card());
    print('no backdrop, frosted: label ${_hex(recorded!)}, ${errors.length} report(s)');
    expect(recorded, GlassFinish.frosted.foregroundOverAny());
    expect(errors, hasLength(1));
    expect(errors.single, contains('no GlassThemeData.backdrop'));
    expect(errors.single, contains('1.76'));

    // The twin, in the same arm: told what is behind the glass, it chooses
    // against that and complains no further.
    errors.clear();
    await _mount(tester, finish: GlassFinish.frosted, backdrop: kLight, tier: GlassTier.cheap, content: card());
    expect(recorded, GlassFinish.frosted.foregroundOver(kLight));
    expect(errors, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 8. Disabled.
  // -------------------------------------------------------------------------

  testWidgets('disabled, a button keeps its glass, dims its label and takes no press', (
    WidgetTester tester,
  ) async {
    // The simulator's frames: tertiaryLabel, (60, 60, 67) and (235, 235, 245)
    // at 0.3.
    expect(kGlassDisabledDarkLabel, const Color(0x4D3C3C43));
    expect(kGlassDisabledLightLabel, const Color(0x4DEBEBF5));

    Color? recorded;
    Color? recordedIcon;
    Widget probe() => Builder(
      builder: (BuildContext context) {
        recorded = DefaultTextStyle.of(context).style.color;
        recordedIcon = IconTheme.of(context).color;
        return const SizedBox(width: 40, height: 20);
      },
    );
    Widget button({required bool enabled}) => SizedBox.fromSize(
      size: kPanel,
      child: GlassButton(onPressed: enabled ? () {} : null, child: probe()),
    );

    // Both polarities: `regular` is white over anything, `frosted` over a
    // light screen is black — and the arm checks it got both.
    final labels = <Color>{};
    for (final (GlassFinish finish, Color backdrop) in <(GlassFinish, Color)>[
      (GlassFinish.regularDark, kDark),
      (GlassFinish.frosted, kLight),
    ]) {
      await _mount(tester, finish: finish, backdrop: backdrop, tier: GlassTier.cheap, content: button(enabled: true));
      final Color label = recorded!;
      labels.add(label);
      final _Rgb glassOn = await _readCentre(tester);
      await _mount(tester, finish: finish, backdrop: backdrop, tier: GlassTier.cheap, content: button(enabled: false));
      final _Rgb glassOff = await _readCentre(tester);
      final Color want = label.computeLuminance() < 0.5 ? kGlassDisabledDarkLabel : kGlassDisabledLightLabel;
      print(
        '${finish.name} over ${_hex(backdrop)}: label ${_hex(label)} -> ${_hex(recorded!)}, glass $glassOn -> $glassOff',
      );
      expect(recorded, want, reason: 'over ${_hex(backdrop)}');
      expect(recordedIcon, want, reason: 'over ${_hex(backdrop)}');
      expect(glassOff.distanceTo(glassOn.color), lessThanOrEqualTo(1), reason: 'the glass moved');

      // No press: a finger on a disabled button adds nothing.
      final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
      await tester.pump();
      expect((await _readCentre(tester)).distanceTo(glassOff.color), lessThanOrEqualTo(1));
      await gesture.up();
    }
    expect(labels, <Color>{const Color(0xFFFFFFFF), const Color(0xFF000000)});

    // Disabled under a finger: the held overlay goes, and nothing complains.
    await _mount(
      tester,
      finish: GlassFinish.regularDark,
      backdrop: kLight,
      tier: GlassTier.cheap,
      content: button(enabled: true),
    );
    final _Rgb resting = await _readCentre(tester);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(GlassButton)));
    await tester.pump();
    expect((await _readCentre(tester)).r - resting.r, closeTo(50, 2), reason: 'never held');
    await _mount(
      tester,
      finish: GlassFinish.regularDark,
      backdrop: kLight,
      tier: GlassTier.cheap,
      content: button(enabled: false),
    );
    expect(tester.takeException(), isNull);
    expect((await _readCentre(tester)).distanceTo(resting.color), lessThanOrEqualTo(1), reason: 'still held');
    await gesture.up();
    await tester.pump();
  });
}

// ---------------------------------------------------------------------------
// The fixture.
// ---------------------------------------------------------------------------

final GlobalKey _shotKey = GlobalKey();

/// Mounts one component over a solid declared backdrop, at one rung.
///
/// The backdrop is a child of the host and not its sibling: a proxy is a
/// snapshot of the **host's** subtree, so a fill laid beside it is not in the
/// capture and every glass panel samples black.
Future<void> _mount(
  WidgetTester tester, {
  required GlassFinish finish,
  required Color? backdrop,
  required GlassTier tier,
  required Widget content,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kScreen, devicePixelRatio: 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: GlassHost(
            hardware: GlassHardware.appleMetal,
            resolution: const ProxyResolution.full(),
            finish: finish,
            backdrop: backdrop,
            tier: GlassTierChoice(tier, GlassTierReason.pinnedByHost),
            child: RepaintBoundary(
              key: _shotKey,
              child: SizedBox.fromSize(
                size: kScreen,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: ColoredBox(color: backdrop ?? const Color(0xFF808080))),
                    // Keyed on the rung: two arms differing in one value get the
                    // **same** render object when the tree is structurally the
                    // same, and then a counter or a retained layer quietly
                    // belongs to the previous one.
                    Center(
                      child: KeyedSubtree(key: ValueKey<GlassTier>(tier), child: content),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// The colour at the centre of the panel, which is where the refraction is
/// exactly zero: `t` saturates at 1 well inside the shape and the bend is
/// `(1 - 1^0.6)^1.9`.
Future<_Rgb> _readCentre(WidgetTester tester) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
  late _Rgb read;
  await tester.runAsync(() async {
    final Uint8List px = (await shot.toByteData())!.buffer.asUint8List();
    final int x = (kScreen.width / 2).round();
    final int y = (kScreen.height / 2).round();
    final int i = (y * kScreen.width.toInt() + x) * 4;
    read = _Rgb(px[i], px[i + 1], px[i + 2]);
  });
  shot.dispose();
  return read;
}

/// One row of the shot, red channel, columns `[from, to)`.
Future<List<int>> _readRow(
  WidgetTester tester, {
  required int y,
  required int from,
  required int to,
}) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // ignore: invalid_use_of_protected_member
  final layer = boundary.layer! as OffsetLayer;
  final ui.Image shot = layer.toImageSync(Offset.zero & kScreen);
  final out = <int>[];
  await tester.runAsync(() async {
    final Uint8List px = (await shot.toByteData())!.buffer.asUint8List();
    for (var x = from; x < to; x++) {
      out.add(px[(y * kScreen.width.toInt() + x) * 4]);
    }
  });
  shot.dispose();
  return out;
}

Future<_Rgb> _levelUnderPanel(
  WidgetTester tester, {
  required GlassFinish finish,
  required Color backdrop,
  required GlassTier tier,
}) async {
  await _mount(
    tester,
    finish: finish,
    backdrop: backdrop,
    tier: tier,
    // A bar with nothing in it: the claim is about the level a label would sit
    // on, and `flutter_tester` has no fonts, so real text would measure the
    // absence of a typeface.
    content: SizedBox.fromSize(
      size: kPanel,
      child: const GlassBar(padding: EdgeInsets.zero, child: SizedBox.shrink()),
    ),
  );
  return _readCentre(tester);
}

/// The fraction of a box the shape covers, rasterized.
///
/// Against the drawing rather than against `contains`, deliberately: the two
/// disagree for an oversized radius and the drawing is the one on the screen.
Future<double> _coverageOf(WidgetTester tester, RSuperellipse shape) async {
  final int w = shape.width.round();
  final int h = shape.height.round();
  late double covered;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & Size(w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF000000));
    canvas.drawRSuperellipse(shape, Paint()..color = const Color(0xFFFFFFFF));
    final ui.Image image = recorder.endRecording().toImageSync(w, h);
    final Uint8List px = (await image.toByteData())!.buffer.asUint8List();
    var sum = 0;
    for (var i = 0; i < px.length; i += 4) {
      sum += px[i];
    }
    covered = sum / 255;
    image.dispose();
  });
  return covered;
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  Color get color => Color.fromARGB(255, r, g, b);

  int distanceTo(Color other) {
    int channel(double v) => (v * 255).round();
    final int dr = (r - channel(other.r)).abs();
    final int dg = (g - channel(other.g)).abs();
    final int db = (b - channel(other.b)).abs();
    return dr > dg ? (dr > db ? dr : db) : (dg > db ? dg : db);
  }

  @override
  String toString() => '($r,$g,$b)';
}

String _hex(Color c) =>
    '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0')}';
