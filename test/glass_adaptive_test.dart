// Glass that reads its own backdrop (`GlassHost.adaptive`).
//
// `flutter test test/glass_adaptive_test.dart`
//
//  1. **The verdict does not flicker.** [GlassBackdropVerdict] is the whole
//     rule, driven without a frame: a reading inside the band never moves it,
//     one outside it inside the hold waits and is taken when the hold ends,
//     and a backdrop see-sawing across a threshold by less than the band
//     moves it never — by more than the band, at most once per hold.
//  2. **The pieces it is made of.** The read-back's decode (a mean weighted by
//     coverage, nothing for an empty cell), `GlassFinish.levelOf` against the
//     thresholds `.regular` switches on, `GlassFinish.lerp`, and the theme's
//     precedence — a named finish held, a rich backdrop's label left to the
//     worst case.
//  3. **On a screen.** One host over a black half and a white half, a bar on
//     each: with the reading on, the bar over black is dark glass with a white
//     label and the bar over white light glass with a black one, in either
//     appearance; with it off, both wear the appearance's branch. A finish the
//     bar names is kept and only its label follows; one the host names, the
//     same; a rich backdrop keeps the worst-case label.
//  4. **What it costs.** Off, a screen captured on every frame reads nothing
//     back and the handle carries no verdicts. On, a still screen reads once
//     and never again, and a screen captured on every frame reads at most once
//     per interval.
//  5. **How it moves.** A verdict that moves tweens the glass and the label;
//     under reduced motion it does not. A reading the hold turns away is
//     taken when the hold ends, with no further read-back. Turning the
//     reading off keeps the state of what the bar holds.
//
// Breaks, each failing its arm and undone by swapping the string back:
//  - in `GlassBackdropVerdict.offer`, `<= adaptive.band` -> `< 0`: a reading
//    inside the band moves the verdict, and the see-saw arm of (1) fails;
//  - in `GlassBackdropVerdict.offer`, `now - _keptAt! < adaptive.hold` ->
//    `false`: the hold is gone, and the hold arms of (1) fail;
//  - in `_GlassHostState._capture`, `if (reader != null && reader.hungry) {`
//    -> `if (reader != null) {`: a held frame reads, and the still-screen arm
//    of (4) fails, with the hold arm of (5) and the screens of (3), which count
//    their reads;
//  - in `GlassThemeData.adaptedTo`, `GlassFinish.regular(appearance:
//    appearance, backdrop: reading.mean)` -> `finish`: the branch never
//    follows, and (3) fails;
//  - in `_GlassPanelState._onReadings`, `_reduceMotion ||` deleted: the
//    reduced-motion arm of (5) fails.

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:g1455/glass_diagnostics.dart';
import 'package:g1455/src/proxy/proxy_reading.dart';

const Size kScreen = Size(400, 200);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);

GlassBackdropReading _grey(double level) {
  final double v = level / 255;
  return GlassBackdropReading(Color.from(alpha: 1, red: v, green: v, blue: v));
}

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  // -------------------------------------------------------------------------
  // 1. The verdict does not flicker.
  // -------------------------------------------------------------------------

  group('the verdict', () {
    test('takes the first reading, and nothing inside the band', () {
      final verdict = GlassBackdropVerdict(const GlassAdaptive(band: 12, hold: Duration.zero));
      expect(verdict.kept, isNull);
      expect(verdict.offer(_grey(50), Duration.zero), isTrue);
      expect(verdict.kept, _grey(50));
      // At the band exactly, and inside it on either side: kept.
      for (final double level in <double>[62, 38, 55, 45]) {
        expect(verdict.offer(_grey(level), _ms(1000)), isFalse, reason: 'level $level');
        expect(verdict.kept, _grey(50));
      }
      expect(verdict.offer(_grey(62.5), _ms(1000)), isTrue);
      expect(verdict.kept, _grey(62.5));
    });

    test('waits out the hold, and takes the reading when it ends', () {
      final verdict = GlassBackdropVerdict(const GlassAdaptive(band: 12, hold: Duration(milliseconds: 600)));
      expect(verdict.offer(_grey(20), Duration.zero), isTrue);
      expect(verdict.due, isNull);
      expect(verdict.offer(_grey(200), _ms(100)), isFalse);
      expect(verdict.pending, _grey(200));
      expect(verdict.due, _ms(600));
      // Not yet.
      expect(verdict.settle(_ms(599)), isFalse);
      expect(verdict.kept, _grey(20));
      // A newer reading replaces the one waiting.
      expect(verdict.offer(_grey(180), _ms(300)), isFalse);
      expect(verdict.pending, _grey(180));
      expect(verdict.settle(_ms(600)), isTrue);
      expect(verdict.kept, _grey(180));
      expect(verdict.pending, isNull);
      expect(verdict.settle(_ms(2000)), isFalse);
    });

    test('a reading back inside the band drops the one waiting', () {
      final verdict = GlassBackdropVerdict(const GlassAdaptive(band: 12, hold: Duration(milliseconds: 600)));
      verdict.offer(_grey(20), Duration.zero);
      verdict.offer(_grey(200), _ms(100));
      expect(verdict.pending, isNotNull);
      // The backdrop went back before the hold ended: nothing should move.
      expect(verdict.offer(_grey(25), _ms(200)), isFalse);
      expect(verdict.pending, isNull);
      expect(verdict.due, isNull);
      expect(verdict.settle(_ms(700)), isFalse);
      expect(verdict.kept, _grey(20));
    });

    test('a see-saw across the threshold by less than the band never moves it', () {
      // `.regular` switches at 54 in the light appearance; rows of 48 and 58
      // under a bar, read every 50 ms for ten seconds.
      final verdict = GlassBackdropVerdict(const GlassAdaptive());
      final branches = <GlassFinish>{};
      var moves = 0;
      for (var i = 0; i < 200; i++) {
        if (verdict.offer(_grey(i.isEven ? 48 : 58), _ms(i * 50))) {
          moves++;
        }
        verdict.settle(_ms(i * 50));
        branches.add(GlassFinish.regular(appearance: Brightness.light, backdrop: verdict.kept!.mean));
      }
      expect(moves, 1, reason: 'only the first reading may be taken');
      expect(branches, hasLength(1), reason: 'the glass flickered between branches');
    });

    test('a see-saw by more than the band moves it at most once per hold', () {
      const adaptive = GlassAdaptive(hold: Duration(milliseconds: 600));
      final verdict = GlassBackdropVerdict(adaptive);
      final moves = <Duration>[];
      for (var i = 0; i < 200; i++) {
        final Duration now = _ms(i * 50);
        if (verdict.offer(_grey(i.isEven ? 30 : 90), now) | verdict.settle(now)) {
          moves.add(now);
        }
      }
      expect(moves.length, greaterThan(1));
      for (var i = 1; i < moves.length; i++) {
        expect(moves[i] - moves[i - 1], greaterThanOrEqualTo(adaptive.hold), reason: 'moves at $moves');
      }
    });

    test('a new band or hold applies from the next offer', () {
      final verdict = GlassBackdropVerdict(const GlassAdaptive(band: 12, hold: Duration.zero));
      verdict.offer(_grey(50), Duration.zero);
      expect(verdict.offer(_grey(55), _ms(10)), isFalse);
      verdict.adaptive = const GlassAdaptive(band: 2, hold: Duration.zero);
      expect(verdict.offer(_grey(55), _ms(20)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 2. The pieces it is made of.
  // -------------------------------------------------------------------------

  test('the read-back decodes a coverage-weighted mean per cell', () {
    const count = 3;
    final Size size = ProxyReading.sizeFor(count);
    expect(size, const Size(3.0 * ProxyReading.cell, ProxyReading.cell * 1.0));
    expect(ProxyReading.sizeFor(ProxyReading.columns + 1).height, 2.0 * ProxyReading.cell);
    final int width = size.width.toInt();
    final data = ByteData(width * size.height.toInt() * 4);
    void put(int x, int y, int r, int g, int b, int a) {
      final int o = (y * width + x) * 4;
      data
        ..setUint8(o, r)
        ..setUint8(o + 1, g)
        ..setUint8(o + 2, b)
        ..setUint8(o + 3, a);
    }

    for (var y = 0; y < ProxyReading.cell; y++) {
      for (var x = 0; x < ProxyReading.cell; x++) {
        // Cell 0: opaque mid grey.
        put(x, y, 128, 128, 128, 255);
        // Cell 1: half of it white and opaque, half transparent — premultiplied,
        // so the mean of what is there is white, not grey.
        if (x < ProxyReading.cell / 2) {
          put(ProxyReading.cell + x, y, 255, 255, 255, 255);
        }
        // Cell 2: nothing at all.
      }
    }
    final List<Color?> means = ProxyReading.decode(data, count);
    expect(means[0], isNotNull);
    expect(GlassFinish.levelOf(means[0]!), closeTo(128, 1e-9));
    expect(GlassFinish.levelOf(means[1]!), closeTo(255, 1e-9));
    expect(means[2], isNull);
  });

  test('the level is the one .regular switches on', () {
    expect(_grey(53).level, closeTo(53, 1e-9));
    expect(GlassFinish.regular(appearance: Brightness.light, backdrop: _grey(53).mean), GlassFinish.regularDark);
    expect(GlassFinish.regular(appearance: Brightness.light, backdrop: _grey(55).mean), GlassFinish.regularLight);
    expect(_grey(10).brightness, Brightness.dark);
    expect(_grey(240).brightness, Brightness.light);
    expect(_grey(240).luminance, closeTo(_grey(240).mean.computeLuminance(), 0));
    expect(_grey(240).toString(), contains('240.0'));
  });

  test('a finish between two is between them, and keeps a name it has', () {
    const a = GlassFinish.regularDark;
    const b = GlassFinish.regularLight;
    expect(GlassFinish.lerp(a, b, 0), a);
    expect(GlassFinish.lerp(a, b, 1), b);
    expect(GlassFinish.lerp(a, a, 0.5), a);
    final GlassFinish early = GlassFinish.lerp(a, b, 0.25);
    final GlassFinish late = GlassFinish.lerp(a, b, 0.75);
    expect(early.name, a.name);
    expect(late.name, b.name);
    expect(early.blurSigmaLogical, a.blurSigmaLogical, reason: 'a move between branches re-blurs nothing');
    expect(early.tint.r, inExclusiveRange(a.tint.r, b.tint.r));
    final GlassFinish optics = GlassFinish.lerp(GlassFinish.clear, GlassFinish.identity, 0.5);
    expect(optics.optics.strength, closeTo(GlassFinish.clear.optics.strength / 2, 1e-9));
  });

  test('the theme over a reading: the branch follows, a named finish holds', () {
    final GlassBackdropReading dark = _grey(10);
    const follows = GlassThemeData(
      finish: GlassFinish.regularLight,
      adaptive: GlassAdaptive(),
      regularAppearance: Brightness.light,
    );
    final GlassThemeData over = follows.adaptedTo(dark);
    expect(over.finish, GlassFinish.regularDark);
    expect(over.backdrop, dark.mean);
    expect(over.reading, dark);
    expect(over.legibility().label, kWhite);
    // Named — by a theme built with a finish, or one given one by copyWith.
    expect(const GlassThemeData(finish: GlassFinish.regularLight).adaptedTo(dark).finish, GlassFinish.regularLight);
    expect(follows.copyWith(finish: GlassFinish.regularLight).regularAppearance, isNull);
    expect(follows.copyWith(tier: GlassTierChoice.byDefault).regularAppearance, Brightness.light);
    // A rich backdrop keeps the declared one, and the label its worst case.
    final GlassThemeData rich = follows.copyWith(richBackdrop: true, backdrop: kWhite).adaptedTo(dark);
    expect(rich.finish, GlassFinish.regularDark);
    expect(rich.backdrop, kWhite);
    // And the switch can be taken away, which copyWith cannot say.
    expect(follows.withAdaptive(null).adaptive, isNull);
    expect(follows.withAdaptive(null).regularAppearance, Brightness.light);
    expect(over, isNot(follows));
    expect(over.hashCode, isNot(follows.hashCode));
    expect(over.toString(), allOf(contains('reads its backdrop'), contains('GlassBackdropReading')));
    expect(const GlassAdaptive(), const GlassAdaptive());
    expect(const GlassAdaptive().hashCode, const GlassAdaptive().hashCode);
    expect(const GlassAdaptive(band: 3), isNot(const GlassAdaptive()));
    expect(const GlassAdaptive().toString(), contains('band 12'));
  });

  // -------------------------------------------------------------------------
  // 3. On a screen.
  // -------------------------------------------------------------------------

  group('on a screen', () {
    for (final Brightness appearance in Brightness.values) {
      testWidgets('each bar wears the branch of what is under it, in the ${appearance.name} appearance', (
        WidgetTester tester,
      ) async {
        final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive(), appearance: appearance);
        // The first frames go by what is declared: the appearance's branch.
        final GlassFinish declared = GlassFinish.regular(appearance: appearance);
        expect(scene.seen['dark']!.finish, declared);
        expect(scene.seen['light']!.finish, declared);
        await _land(tester);
        expect(scene.seen['dark']!.finish, GlassFinish.regularDark);
        expect(scene.seen['light']!.finish, GlassFinish.regularLight);
        expect(scene.label['dark'], kWhite);
        expect(scene.label['light'], kBlack);
        expect(scene.seen['dark']!.reading!.level, lessThan(1));
        expect(scene.seen['light']!.reading!.level, greaterThan(254));
        expect(scene.seen['dark']!.reading!.brightness, Brightness.dark);
        // What the glass draws, and not only what the theme says.
        expect(_surface(tester, 'dark').effectiveFinish, GlassFinish.regularDark);
        expect(_surface(tester, 'light').effectiveFinish, GlassFinish.regularLight);
        expect(scene.handle.readBacks, 1);
      });
    }

    testWidgets('off, both bars wear the appearance\'s branch', (WidgetTester tester) async {
      final _Scene scene = await _mount(tester);
      await _land(tester);
      expect(scene.seen['dark']!.finish, GlassFinish.regularLight);
      expect(scene.seen['light']!.finish, GlassFinish.regularLight);
      expect(scene.label['dark'], kBlack);
      expect(scene.seen['dark']!.reading, isNull);
      expect(scene.seen['dark']!.adaptive, isNull);
    });

    testWidgets('a finish the bar names is kept, and its label follows the reading', (WidgetTester tester) async {
      // `clear` over an undeclared screen is black at its worst case; over a
      // measured black it shows 55 of 255, and white is the label there.
      expect(GlassFinish.clear.foregroundOverAny(), kBlack);
      final _Scene on = await _mount(tester, adaptive: const GlassAdaptive(), barFinish: GlassFinish.clear);
      await _land(tester);
      expect(_surface(tester, 'dark').effectiveFinish, GlassFinish.clear);
      expect(on.label['dark'], kWhite);
      expect(on.label['light'], kBlack);
    });

    testWidgets('a finish the host names is kept, and its label follows the reading', (WidgetTester tester) async {
      final _Scene scene = await _mount(
        tester,
        adaptive: const GlassAdaptive(),
        hostFinish: GlassFinish.frosted,
      );
      await _land(tester);
      expect(scene.seen['light']!.finish, GlassFinish.frosted);
      expect(scene.seen['dark']!.finish, GlassFinish.frosted);
      expect(scene.label['dark'], GlassFinish.frosted.foregroundOver(kBlack));
      expect(scene.label['light'], GlassFinish.frosted.foregroundOver(kWhite));
      expect(scene.label['dark'], isNot(scene.label['light']));
    });

    testWidgets('a rich backdrop moves the branch and keeps the worst-case label', (WidgetTester tester) async {
      final _Scene scene = await _mount(
        tester,
        adaptive: const GlassAdaptive(),
        barFinish: GlassFinish.clear,
        richBackdrop: true,
      );
      await _land(tester);
      expect(scene.label['dark'], GlassFinish.clear.foregroundOverAny());
      expect(scene.seen['dark']!.backdrop, isNull);
      expect(scene.seen['dark']!.reading, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 4. What it costs.
  // -------------------------------------------------------------------------

  testWidgets('off, a screen captured on every frame reads nothing back', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, content: GlassContentDeclaration.undeclared);
    await _run(tester, frames: 20);
    expect(scene.handle.generation, greaterThan(10), reason: 'the arm has to capture to mean anything');
    expect(scene.handle.readBacks, 0);
    expect(scene.handle.readings, isNull);
  });

  testWidgets('a still screen reads once', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await _run(tester, frames: 20);
    expect(scene.handle.readBacks, 1);
    expect(scene.handle.readings!.length, 2);
  });

  testWidgets('a screen captured on every frame reads at most once per interval', (WidgetTester tester) async {
    const interval = Duration(milliseconds: 250);
    final _Scene scene = await _mount(
      tester,
      adaptive: const GlassAdaptive(interval: interval),
      content: GlassContentDeclaration.undeclared,
    );
    const frames = 40;
    const step = Duration(milliseconds: 50);
    await _run(tester, frames: frames, step: step);
    final int generations = scene.handle.generation;
    final int allowed = (step * frames).inMilliseconds ~/ interval.inMilliseconds + 1;
    expect(generations, greaterThan(frames ~/ 2));
    expect(scene.handle.readBacks, inInclusiveRange(2, allowed));
  });

  // -------------------------------------------------------------------------
  // 5. How it moves.
  // -------------------------------------------------------------------------

  testWidgets('a move tweens the glass, and the label is the one that reads on it', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await _land(tester, settle: false);
    // The verdict landed: the theme is the new branch, and the glass is on its
    // way there from the old one.
    expect(scene.seen['dark']!.finish, GlassFinish.regularDark);
    await tester.pump(const Duration(milliseconds: 150));
    final Color tint = _surface(tester, 'dark').effectiveFinish.tint;
    expect(tint.r, inExclusiveRange(GlassFinish.regularDark.tint.r, GlassFinish.regularLight.tint.r));
    // Not a lerp of the two ends' labels, which halfway is grey on grey: the
    // label the in-between glass reads with, over what is under it.
    final Color label = scene.label['dark']!;
    final GlassFinish between = _surface(tester, 'dark').effectiveFinish;
    expect(label, between.foregroundOver(scene.seen['dark']!.backdrop!));
    expect(
      GlassFinish.contrastRatio(between.opaqueFillOver(kBlack), label),
      greaterThanOrEqualTo(kTextContrastAA),
      reason: 'the label mid-move does not read on the glass it is on',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_surface(tester, 'dark').effectiveFinish, GlassFinish.regularDark);
    expect(scene.label['dark'], kWhite);
  });

  testWidgets('under reduced motion the move is a cut', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive(), disableAnimations: true);
    await _land(tester, settle: false);
    expect(_surface(tester, 'dark').effectiveFinish, GlassFinish.regularDark);
    expect(scene.label['dark'], kWhite);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a reading the hold turns away is taken when it ends, with no new read', (WidgetTester tester) async {
    final left = ValueNotifier<Color>(kBlack);
    addTearDown(left.dispose);
    final _Scene scene = await _mount(
      tester,
      adaptive: const GlassAdaptive(hold: Duration(seconds: 2), interval: Duration.zero),
      left: left,
    );
    await _land(tester);
    expect(scene.seen['dark']!.finish, GlassFinish.regularDark);
    // The backdrop turns light inside the hold: read, and kept waiting.
    left.value = kWhite;
    await tester.pump();
    await _land(tester);
    final int reads = scene.handle.readBacks;
    expect(reads, 2);
    expect(scene.seen['dark']!.finish, GlassFinish.regularDark, reason: 'moved inside the hold');
    // Past the hold, with nothing under the glass changing again.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(scene.seen['dark']!.finish, GlassFinish.regularLight);
    expect(scene.handle.readBacks, reads);
  });

  testWidgets('turning it off keeps what the bar holds, and its verdicts go', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await _land(tester);
    final State held = tester.state(find.byType(_Held).first);
    expect(scene.seen['dark']!.finish, GlassFinish.regularDark);
    await _mount(tester);
    await tester.pump();
    expect(tester.state(find.byType(_Held).first), same(held));
    expect(scene.seen['dark']!.finish, GlassFinish.regularLight);
    expect(scene.handle.readings, isNull);
    // And on again: read afresh.
    await _mount(tester, adaptive: const GlassAdaptive(band: 4));
    await _land(tester);
    expect(scene.seen['dark']!.finish, GlassFinish.regularDark);
    expect(tester.state(find.byType(_Held).first), same(held));
  });

  testWidgets('a bar that leaves takes its verdict with it', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await _land(tester);
    expect(scene.handle.readings!.length, 2);
    // A new declaration on the same host keeps its reader and its verdicts.
    final GlassBackdropReadings readings = scene.handle.readings!;
    await _mount(tester, adaptive: const GlassAdaptive(band: 4), onlyDark: true);
    await _run(tester, frames: 4);
    expect(scene.handle.readings, same(readings));
    expect(readings.length, 1);
    expect(scene.seen['dark']!.adaptive, const GlassAdaptive(band: 4));
  });

  testWidgets('the last bars that go with a read in flight take their verdicts', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await tester.pump();
    expect(scene.handle.readBacks, 1, reason: 'no read was in flight when the bars went');
    // Same host, no glass at all: the capture publishes nothing, and the read
    // lands after the bars have left.
    await _mount(tester, adaptive: const GlassAdaptive(), bars: false);
    await _land(tester);
    expect(scene.handle.readings!.length, 0, reason: 'a read that landed late gave a gone bar a verdict');
  });

  testWidgets('a bar that falls to a rung that reads nothing drops its verdict', (WidgetTester tester) async {
    final _Scene scene = await _mount(tester, adaptive: const GlassAdaptive());
    await _land(tester);
    expect(scene.handle.readings!.length, 2);
    // Still registered, no longer in the capture: back on the declarations.
    await _mount(
      tester,
      adaptive: const GlassAdaptive(),
      tier: const GlassTierChoice(GlassTier.cheap, GlassTierReason.pinnedByHost),
    );
    await _run(tester, frames: 3);
    expect(
      scene.handle.readings!.length,
      0,
      reason: 'a bar on the cheap rung kept a reading of what it no longer reads',
    );
    expect(scene.seen['dark']!.reading, isNull);
  });

  testWidgets('a host that goes with a read in flight leaves nothing behind', (WidgetTester tester) async {
    await _mount(tester, adaptive: const GlassAdaptive());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await _run(tester, frames: 3);
  });
}

class _Scene {
  _Scene(this.handle, this.seen, this.label);

  final GlassProxyHandle handle;

  /// The theme each bar's content sees, by name.
  final Map<String, GlassThemeData> seen;

  /// The label colour each bar's content is given, by name.
  final Map<String, Color?> label;
}

final _seen = <String, GlassThemeData>{};
final _label = <String, Color?>{};

Future<_Scene> _mount(
  WidgetTester tester, {
  GlassAdaptive? adaptive,
  Brightness appearance = Brightness.light,
  GlassFinish? hostFinish,
  GlassFinish? barFinish,
  bool richBackdrop = false,
  bool disableAnimations = false,
  GlassContentDeclaration content = GlassContentDeclaration.byDefault,
  ValueListenable<Color>? left,
  bool onlyDark = false,
  bool bars = true,
  GlassTierChoice tier = GlassTierChoice.byDefault,
}) async {
  tester.view
    ..physicalSize = kScreen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget bar(String name) => GlassBar(
    finish: barFinish,
    child: _Held(
      child: Builder(
        builder: (BuildContext context) {
          _seen[name] = GlassTheme.of(context);
          _label[name] = DefaultTextStyle.of(context).style.color;
          return Text(name);
        },
      ),
    ),
  );
  final Widget leftHalf = left == null
      ? const ColoredBox(color: kBlack)
      : ValueListenableBuilder<Color>(
          valueListenable: left,
          builder: (BuildContext context, Color c, Widget? _) => ColoredBox(color: c),
        );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: kScreen,
        platformBrightness: appearance,
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GlassHost(
          hardware: GlassHardware.appleMetal,
          adaptive: adaptive,
          tier: tier,
          finish: hostFinish,
          richBackdrop: richBackdrop,
          content: content,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: leftHalf),
                    const Expanded(child: ColoredBox(color: kWhite)),
                  ],
                ),
              ),
              if (bars) Positioned(left: 20, top: 70, width: 160, height: 60, child: bar('dark')),
              if (bars && !onlyDark) Positioned(left: 220, top: 70, width: 160, height: 60, child: bar('light')),
              // Moves on every frame under the undeclared content, so the
              // host captures every frame.
              if (content == GlassContentDeclaration.undeclared) const _Ticking(),
            ],
          ),
        ),
      ),
    ),
  );
  return _Scene(tester.widget<GlassProxyScope>(find.byType(GlassProxyScope)).handle, _seen, _label);
}

/// Lets the engine finish a read-back, and the frames after it apply it.
///
/// The fake clock never completes an engine future, so the rasterization and
/// the copy back each need a real turn of the event loop, and then a pump to
/// run what they completed.
Future<void> _land(WidgetTester tester, {bool settle = true}) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  if (settle) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// [frames] frames [step] apart, each with a real turn for a read-back to land.
Future<void> _run(WidgetTester tester, {required int frames, Duration step = const Duration(milliseconds: 16)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

RenderGlassSurface _surface(WidgetTester tester, String name) =>
    tester.renderObject<RenderGlassSurface>(find.ancestor(of: find.text(name), matching: find.byType(GlassSurface)));

/// Something with state inside the bar, to see whether it survives.
class _Held extends StatefulWidget {
  const _Held({required this.child});

  final Widget child;

  @override
  State<_Held> createState() => _HeldState();
}

class _HeldState extends State<_Held> {
  @override
  Widget build(BuildContext context) => widget.child;
}

/// A box that repaints on every frame, outside the glass.
class _Ticking extends StatefulWidget {
  const _Ticking();

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (BuildContext context, Widget? _) => Positioned(
      left: 0,
      top: 0,
      width: kScreen.width,
      height: kScreen.height,
      child: ColoredBox(color: Color.from(alpha: 0.02, red: _c.value, green: 0, blue: 0)),
    ),
  );
}
