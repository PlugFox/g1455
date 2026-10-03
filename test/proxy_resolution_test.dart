// Phase A, step 6 — the one who chooses the divisor, and the key its table has.
//
// `flutter test test/glass/proxy_resolution_test.dart`
//
// Steps 2 to 5 built the resolution lever and priced both of its sides: what a
// divisor saves (D28 on Adreno, nothing at all on Metal — D119) and what it
// costs (the M11 ladder, D117 and D118). What none of them did was *choose*,
// and the moment something has to, the table turns out to have been read by the
// wrong key all along.
//
// **The table's rungs are texel scales wearing divisor labels.** The ladder runs
// at a device pixel ratio of 2, so its `res4` rung is half a texel per logical
// pixel — and half a texel per logical pixel is what `res2` means on a dpr-1
// desktop and what `res8` means on a dpr-4 phone. Which of the two quantities
// the damage actually follows is not decidable from one density, and it is
// decidable from three: the same 84 arms at dpr 1, 2 and 4.
//
// So this file has three parts, in the order the answer was built:
//
//  1. the transport, re-derived from the five reports on disk rather than
//     restated — including the control that made one third of the residual go
//     away, and the arm that says the middle report *is* the recorded ladder;
//  2. the reading built on it, [ProxyResolution.damageAtTexelScale], with its
//     three refusals and the bound the dpr-4 run gets to check;
//  3. the chooser, which is arithmetic over measured tables plus three places it
//     declines — each with a negative control in the same arm, because a chooser
//     that always answered "full resolution" would pass every arm about safety
//     and none about usefulness;
//  4. the route's own price, re-derived from the two device runs on disk — added
//     after those runs said the chooser had been reading the wrong table (D128).
//     The capture's price and the route's are two different numbers on Metal,
//     and for one release the package spent the first as though it were the
//     second;
//  5. the family no model fits, re-derived from the two Xclipse runs on disk —
//     added after those runs said the fourth refusal, "unmeasured hardware gets
//     full resolution", had handed the default Android host the worst arm the
//     ladder had (D134, D136). The lever's sign is measured there and its size
//     is not, and the two arms below assert exactly that much.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/src/proxy/proxy_resolution.dart';
// For the finish's own sigma rather than a literal zero: the arm below is about
// what a finish with no blur gets from a divisor, and it has to notice if one of
// them stops having none.
import 'package:g1455/src/surface/glass_finish.dart';

/// One resolution arm of a ladder report.
typedef Arm = ({String scene, String finish, int divisor, double deltaE});

/// One step of the M7 ladder, out of a digested benchmark report.
typedef Step = ({double frameMs, double spread, int? divisor});

/// Least squares of `value = a·f + c`, with the worst residual as a fraction of
/// the largest value.
///
/// Written out here rather than imported because the point of these arms is that
/// the arithmetic a constant came from is in the repository: a fit hidden behind
/// a package is a number somebody remembered.
({double a, double c, double worst}) fitTwoTerm(List<(double, double)> points) {
  final int n = points.length;
  double sf = 0;
  double sv = 0;
  double sff = 0;
  double sfv = 0;
  for (final (double f, double v) in points) {
    sf += f;
    sv += v;
    sff += f * f;
    sfv += f * v;
  }
  final double a = (n * sfv - sf * sv) / (n * sff - sf * sf);
  final double c = (sv - a * sf) / n;
  double worst = 0;
  double scale = 0;
  for (final (double f, double v) in points) {
    final double r = (v - (a * f + c)).abs();
    if (r > worst) worst = r;
    if (v.abs() > scale) scale = v.abs();
  }
  return (a: a, c: c, worst: worst / scale);
}

/// The M7 ladder of one device run, distilled to `variant -> step`.
///
/// `digest.py` is what makes this checkable at all: a report is 15 MB and is not
/// in the repository, its digest is 6 KB and is.
Map<String, Step> readLadder(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('the digest a constant came from is gone: $path');
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  // The three caveats every iOS run carries — no thermal channel, no GPU
  // counters, a 5 s window — and no fourth. Asserted rather than ignored: on
  // this platform "no caveats" is unreachable, so the check has to name the
  // ones that are expected or it checks nothing.
  expect((report['caveats']! as List<Object?>).length, 3, reason: 'an unexpected caveat: $path');
  expect(report['metric'], 'frame_ms_per_frame');
  return <String, Step>{
    for (final Object? c in report['cells']! as List<Object?>)
      (c! as Map<String, Object?>)['variant']! as String: (
        frameMs: ((c as Map<String, Object?>)['frame_ms_per_frame']! as num).toDouble(),
        spread: (c['spread']! as num).toDouble(),
        // Null in the first block: the counter was added between the two runs,
        // so that block's divisor is *declared* and only the second one's is
        // observed. Said out loud rather than defaulted to 1.
        divisor: ((c['counters']! as Map<String, Object?>)['glass_proxy_divisor'] as num?)?.toInt(),
      ),
  };
}

/// The report's own view keys, plus its resolution arms.
class Ladder {
  Ladder(this.path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('the report a constant came from is gone: $path');
    }
    final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    view = report['view']! as Map<String, Object?>;
    optics = report['optics']! as Map<String, Object?>;
    arms = <Arm>[
      for (final Object? a in report['arms']! as List<Object?>)
        if ((a! as Map<String, Object?>)['axis'] == 'resolution' && (a as Map<String, Object?>)['delta_e_mean'] != null)
          (
            scene: a['scene']! as String,
            finish: packageName(a['finish']! as String),
            divisor: a['resolution_divisor']! as int,
            deltaE: a['delta_e_mean']! as double,
          ),
    ];
  }

  final String path;
  late final Map<String, Object?> view;
  late final Map<String, Object?> optics;
  late final List<Arm> arms;

  double get dpr => (view['device_pixel_ratio']! as num).toDouble();
  double get bakeDpr => (view['bake_device_pixel_ratio']! as num).toDouble();

  /// Damage of one arm, or null if this ladder did not run it.
  double? at(String scene, String finish, int divisor) {
    for (final Arm a in arms) {
      if (a.scene == scene && a.finish == finish && a.divisor == divisor) {
        return a.deltaE;
      }
    }
    return null;
  }

  Set<String> get scenes => <String>{for (final Arm a in arms) a.scene};
}

/// Scenes the corpus draws entirely in logical units — no baked photograph
/// anywhere in them, and no page of text either.
///
/// The known-answer group: content whose spectrum is fixed in logical space
/// cannot care what the screen's density is, so if the transport claim is true
/// anywhere it is true here, and if it fails here it is the reading that is
/// wrong rather than the content.
const List<String> kLogicalUnitScenes = <String>['over_animation', 'over_grid', 'scroll_under_bar'];

/// Scenes handed the baked photograph, whose finest layer is drawn one *device*
/// pixel wide — so they are not the same picture at two densities.
const List<String> kBakedPhotoScenes = <String>['over_photo', 'many_cluster', 'over_cards'];

/// Matched texel scales, as (scale, [(dpr, divisor)…]).
const List<(double, List<(int, int)>)> kTexelGroups = <(double, List<(int, int)>)>[
  (1.0, <(int, int)>[(2, 2), (4, 4)]),
  (0.5, <(int, int)>[(1, 2), (2, 4), (4, 8)]),
  (0.25, <(int, int)>[(1, 4), (2, 8)]),
];

double _median(List<double> xs) {
  final List<double> s = List<double>.of(xs)..sort();
  final int n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// The package's name for a finish the ladder graded: the ladder has called
/// the dark branch of `.regular` `regular` since before D230, and every
/// report keeps the name it was taken under.
String packageName(String ladder) => ladder == 'regular' ? 'regularDark' : ladder;

/// The finishes every ladder run before D230 graded, by the package's names:
/// the cross-run claims below are claims about these four. The light branch
/// has a run of its own, and its own arm.
const List<String> kRecordedFinishes = <String>['clear', 'thinLight', 'frosted', 'regularDark'];

void main() {
  final Map<int, Ladder> free = <int, Ladder>{
    for (final MapEntry<int, String> e in ProxyResolution.transportSources.entries) e.key: Ladder(e.value),
  };
  final Map<int, Ladder> pinned = <int, Ladder>{
    for (final MapEntry<int, String> e in ProxyResolution.transportControlSources.entries) e.key: Ladder(e.value),
    // The middle density needs no control: its bake already is the pinned one.
    2: free[2]!,
  };

  // -------------------------------------------------------------------------
  // 1. The transport, from the reports.
  // -------------------------------------------------------------------------

  test('the three ladders differ in the density and in nothing else', () {
    for (final MapEntry<int, Ladder> e in free.entries) {
      expect(e.value.dpr, e.key.toDouble(), reason: '${e.value.path} is not the density it claims');
      expect(
        e.value.bakeDpr,
        e.key.toDouble(),
        reason: '${e.value.path}: the asset was pinned, so it is the control and not the arm',
      );
      expect(e.value.scenes, hasLength(7));
      expect(e.value.arms, hasLength(84), reason: '${e.value.path} has a different shape');
      expect(
        e.value.optics,
        free[2]!.optics,
        reason: '${e.value.path} was taken on different optics',
      );
      expect(e.value.view['blur_corrected_for_resolution'], false);
      expect(e.value.view['logical'], free[2]!.view['logical']);
    }
    for (final MapEntry<int, Ladder> e in pinned.entries) {
      expect(e.value.bakeDpr, 2.0, reason: '${e.value.path} is not the pinned control');
      expect(e.value.dpr, e.key.toDouble());
    }
  });

  test('the dpr-2 ladder is the recorded ladder, arm for arm', () {
    // The arm that licenses everything below. Adding a density knob to the
    // runner could have moved the run it was added to — a different asset size,
    // a different reference — and then a "cross-density" comparison would be a
    // comparison of two ladders. It moved nothing: every arm is bit-identical
    // to the report `ProxyResolution`'s tables are re-derived from.
    final recorded = Ladder(ProxyResolution.damageSource);
    var compared = 0;
    for (final Arm a in free[2]!.arms) {
      final double? was = recorded.at(a.scene, a.finish, a.divisor);
      expect(was, isNotNull, reason: '${a.scene}/${a.finish}/${a.divisor} is not in the record');
      expect(
        a.deltaE,
        was,
        reason: '${a.scene}/${a.finish}/${a.divisor}: the knob moved the run it was added to',
      );
      compared++;
    }
    expect(compared, 84);
  });

  test('the light branch\'s rows are its own run, and that run is the recorded ladder', () {
    // D230. A row from another afternoon belongs in this table only if the
    // ladder it came from is the same ladder: its `regular` arms have to be
    // [damageSource]'s, arm for arm, before its `regularLight` arms mean
    // anything here.
    for (final (String light, String recorded, bool corrected) in <(String, String, bool)>[
      (ProxyResolution.lightDamageSource, ProxyResolution.damageSource, false),
      (ProxyResolution.lightDamageSourceCorrected, ProxyResolution.damageSourceCorrected, true),
    ]) {
      final run = Ladder(light);
      final was = Ladder(recorded);
      expect(run.view['blur_corrected_for_resolution'], corrected);
      expect(run.optics, was.optics, reason: 'the two runs are on different optics');
      // Not bit for bit, unlike D187's: 84 of 85 arms moved, by up to 0.36%,
      // and every one of the worst is a scene with text in it — the SDK's
      // glyph rasterization moved between the afternoons, not the ladder. A
      // thirty-fifth of [ProxyResolution.transportSpreadMedian].
      var compared = 0;
      for (final Arm a in run.arms.where((Arm a) => a.finish == 'regularDark')) {
        final double recordedArm = was.at(a.scene, a.finish, a.divisor)!;
        expect((a.deltaE - recordedArm).abs() / recordedArm, lessThan(0.005), reason: '$light: $a');
        compared++;
      }
      expect(compared, 35, reason: 'seven scenes by five rungs');
      for (final int divisor in const <int>[2, 3, 4, 6, 8]) {
        final List<double> arms = <double>[
          for (final String scene in run.scenes) run.at(scene, 'regularLight', divisor)!,
        ];
        expect(
          ProxyResolution.divisor(divisor).meanDamage('regularLight', blurCorrected: corrected),
          closeTo(arms.reduce((double a, double b) => a + b) / arms.length, 0.0005),
          reason: 'regularLight at $divisor, corrected $corrected',
        );
      }
    }
  });

  test('the damage follows the texel scale, and the divisor is the wrong key', () {
    // The whole finding, as a ratio between two rival readings of one set of
    // arms. Both are computed here; neither is quoted from the file header.
    List<double> spreadsBy(bool byTexel, List<String> scenes) {
      final out = <double>[];
      for (final String finish in kRecordedFinishes) {
        for (final String scene in scenes) {
          if (byTexel) {
            for (final (double _, List<(int, int)> group) in kTexelGroups) {
              final List<double> vs = <double>[
                for (final (int dpr, int divisor) in group) free[dpr]!.at(scene, finish, divisor)!,
              ];
              out.add(
                (vs.reduce((a, b) => a > b ? a : b) - vs.reduce((a, b) => a < b ? a : b)) /
                    (vs.reduce((a, b) => a + b) / vs.length),
              );
            }
          } else {
            for (final int divisor in const <int>[2, 4, 8]) {
              final List<double> vs = <double>[
                for (final int dpr in const <int>[1, 2, 4]) free[dpr]!.at(scene, finish, divisor)!,
              ];
              out.add(
                (vs.reduce((a, b) => a > b ? a : b) - vs.reduce((a, b) => a < b ? a : b)) /
                    (vs.reduce((a, b) => a + b) / vs.length),
              );
            }
          }
        }
      }
      return out;
    }

    final List<String> all = free[2]!.scenes.toList()..sort();
    final double byTexel = _median(spreadsBy(true, all));
    final double byDivisor = _median(spreadsBy(false, all));
    expect(
      byTexel,
      lessThan(0.20),
      reason: 'matched texel scales disagree by ${(byTexel * 100).toStringAsFixed(1)}%',
    );
    expect(
      byDivisor,
      greaterThan(0.60),
      reason: 'the rival key does not lose, so this run separates nothing',
    );
    expect(
      byDivisor / byTexel,
      greaterThan(4),
      reason: 'the two keys are not far enough apart for the answer to mean anything',
    );

    // The known-answer group: content fixed in logical units transports to
    // within a twentieth of a ΔE, which is what says the residual above belongs
    // to the content rather than to the reading.
    final List<double> logical = spreadsBy(true, kLogicalUnitScenes);
    expect(_median(logical), lessThan(0.12));
  });

  test('a denser screen is worse at a fixed texel scale, never better', () {
    // The direction a caller has to carry, and the reason it exists: glyph
    // antialiasing puts energy at the *device* grid, so a denser reference has
    // more detail for a fixed texel scale to lose. Asserted as a direction, not
    // as a constant — the size of it is one scene's property, the sign is the
    // mechanism's.
    double ratioAt(Ladder ladder, String scene, int divisor, int refDivisor) {
      final double mine = <double>[
        for (final String f in kRecordedFinishes) ladder.at(scene, f, divisor)!,
      ].reduce((a, b) => a + b);
      final double theirs = <double>[
        for (final String f in kRecordedFinishes) free[2]!.at(scene, f, refDivisor)!,
      ].reduce((a, b) => a + b);
      return mine / theirs;
    }

    // over_text at a texel scale of 0.5: dpr 1 (divisor 2) against dpr 2
    // (divisor 4) against dpr 4 (divisor 8).
    expect(ratioAt(free[1]!, 'over_text', 2, 4), lessThan(0.95));
    expect(ratioAt(free[4]!, 'over_text', 8, 4), greaterThan(1.05));
    // And the control that keeps this from being "any scene wanders": the
    // logical-unit scenes do not move in either direction.
    for (final String scene in kLogicalUnitScenes) {
      expect(ratioAt(free[1]!, scene, 2, 4), closeTo(1.0, 0.12), reason: '$scene at dpr 1');
      expect(ratioAt(free[4]!, scene, 8, 4), closeTo(1.0, 0.12), reason: '$scene at dpr 4');
    }
  });

  test('the corpus is not the same picture at two densities, and pinning it proves it', () {
    // The control that took a third of the residual away. Two scenes swung by a
    // factor of two across the density axis and the explanation — that the
    // baked photograph follows the *device* size, so its finest layer is a
    // quarter of a logical pixel at dpr 4 and a whole one at dpr 1 — was a
    // story until the bake was pinned and they came into line.
    double ratio(Map<int, Ladder> set, int dpr, String scene, int divisor) {
      final double mine = <double>[
        for (final String f in kRecordedFinishes) set[dpr]!.at(scene, f, divisor)!,
      ].reduce((a, b) => a + b);
      final double theirs = <double>[
        for (final String f in kRecordedFinishes) set[2]!.at(scene, f, 4)!,
      ].reduce((a, b) => a + b);
      return mine / theirs;
    }

    for (final String scene in const <String>['over_photo', 'many_cluster']) {
      // Free: the two ends of the density axis are a factor of two apart.
      expect(
        ratio(free, 1, scene, 2),
        greaterThan(1.5),
        reason: '$scene, asset following the view',
      );
      expect(ratio(free, 4, scene, 8), lessThan(0.85), reason: '$scene, asset following the view');
      // Pinned: they are not.
      expect(ratio(pinned, 1, scene, 2), lessThan(1.2), reason: '$scene, asset pinned');
      expect(ratio(pinned, 4, scene, 8), closeTo(1.0, 0.1), reason: '$scene, asset pinned');
    }
    // And the control on the control, both ways round. A scene that never
    // touches the asset must not move by a bit between the two recipes, or the
    // pin changed the run rather than the picture — and every scene that does
    // touch it must move somewhere, or the pin did nothing and the collapse
    // above belongs to something else.
    final moved = <String>{};
    for (final String scene in free[2]!.scenes) {
      final bool baked = kBakedPhotoScenes.contains(scene);
      for (final int dpr in const <int>[1, 4]) {
        for (final String finish in ProxyResolution.measuredFinishes) {
          for (final int divisor in const <int>[2, 4, 8]) {
            final double? a = free[dpr]!.at(scene, finish, divisor);
            final double? b = pinned[dpr]!.at(scene, finish, divisor);
            if (b == null) {
              continue;
            }
            if (baked) {
              if (a != b) {
                moved.add(scene);
              }
            } else {
              expect(b, a, reason: '$scene/$finish/$divisor moved when only the asset was pinned');
            }
          }
        }
      }
    }
    expect(
      moved,
      kBakedPhotoScenes.toSet(),
      reason: 'the pin did not reach a scene it should have',
    );
  });

  test('a magnification that is not a power of two costs what the texel scale says', () {
    // D187's discriminating run, re-derived from the report rather than
    // restated. The 3 and 6 rungs are the first the ladder has taken where one
    // texel is an odd number of device pixels — a texel is `divisor` device
    // pixels wide, so magnifying it back has three sub-texel phases instead of
    // two or four, one of them exactly on a texel centre. D120's transport
    // finding cannot speak to that: every arm it compared at a matched texel
    // scale magnified by a power of two (0.5 texels is divisor 2 at dpr 1, 4 at
    // dpr 2 and 8 at dpr 4), so "damage follows the texel" was established
    // only where the reconstruction was symmetric.
    //
    // The run that separates them is dpr 3, where the same texel scales come
    // from divisors 3 and 6. The prediction was written before it: if the
    // magnification matters, these arms land far above their dpr-2 twins by the
    // same +26…27% the 3 and 6 rungs exceeded the old interpolation by. They do
    // not — every one is inside the transport spread, and the odd-magnification
    // hypothesis is refuted rather than shaded.
    final dpr3 = Ladder(ProxyResolution.magnificationSource);
    final dpr2 = Ladder(ProxyResolution.damageSourceCorrected);
    expect(dpr3.dpr, 3.0, reason: 'the magnification arm is not at dpr 3');
    expect(dpr3.bakeDpr, 2.0, reason: 'the backdrop followed the view, so it is not the control');
    expect(dpr3.view['blur_corrected_for_resolution'], true);
    expect(dpr2.view['blur_corrected_for_resolution'], true);
    expect(dpr3.optics, dpr2.optics, reason: 'the two runs are on different optics');

    var worst = 0.0;
    for (final String finish in kRecordedFinishes) {
      // (texel scale, divisor at dpr 2, divisor at dpr 3) — the magnification
      // is the divisor, so these pairs are 2 against 3 and 4 against 6.
      for (final (int at2, int at3) in <(int, int)>[(2, 3), (4, 6)]) {
        final List<double> two = <double>[
          for (final String scene in dpr2.scenes) dpr2.at(scene, finish, at2)!,
        ];
        final List<double> three = <double>[
          for (final String scene in dpr2.scenes) dpr3.at(scene, finish, at3)!,
        ];
        final double a = two.reduce((double x, double y) => x + y) / two.length;
        final double b = three.reduce((double x, double y) => x + y) / three.length;
        final double off = (b / a - 1).abs();
        expect(
          off,
          lessThan(ProxyResolution.transportSpreadMedian),
          reason:
              '$finish at ${ProxyResolution.damageTableDevicePixelRatio / at2} texels: '
              'magnification $at3 costs ${b.toStringAsFixed(4)} against $at2\'s '
              '${a.toStringAsFixed(4)}',
        );
        worst = math.max(worst, off);
      }
    }
    // The number the refutation rests on, and the one the hypothesis needed to
    // beat: the rungs themselves came in 26…27% over the interpolation, and the
    // worst matched-magnification disagreement here is a fifth of that.
    expect(worst, closeTo(0.073, 0.005));
  });

  // -------------------------------------------------------------------------
  // 2. The reading.
  // -------------------------------------------------------------------------

  test('the rungs are the table, read by texel scale', () {
    for (final String finish in ProxyResolution.measuredFinishes) {
      for (final (int divisor, double scale) in const <(int, double)>[
        (2, 1.0),
        (4, 0.5),
        (8, 0.25),
      ]) {
        for (final bool corrected in const <bool>[false, true]) {
          final ProxyDamage? read = ProxyResolution.damageAtTexelScale(
            finish,
            scale,
            blurCorrected: corrected,
          );
          expect(read, isNotNull);
          expect(
            read!.deltaE,
            ProxyResolution.divisor(divisor).meanDamage(finish, blurCorrected: corrected),
            reason: '$finish at $scale texels is not the ladder rung it came from',
          );
          expect(read.measured, isTrue, reason: 'a rung of the table read as an estimate');
        }
      }
    }
  });

  test('the reading refuses past the measured end and bounds past the near one', () {
    // Refusals first: an unknown finish and a texel scale finer than anything
    // the ladder ran.
    expect(ProxyResolution.damageAtTexelScale('nosuchfinish', 0.5), isNull);
    expect(ProxyResolution.damageAtTexelScale('regularDark', 0.24), isNull);
    expect(ProxyResolution.damageAtTexelScale('regularDark', 0.0), isNull);

    // And the bound. The dpr-2 ladder cannot measure a texel scale of 2.0 at
    // all — that is its divisor-1 rung, which is the reference and scores 0.000
    // at every density by construction — so the reading hands back the top
    // rung's damage flagged as not measured. The dpr-4 run *did* measure that
    // point, with a real divisor under it, and every one of its arms has to sit
    // under the bound or monotonicity is not what it was taken for.
    for (final String finish in kRecordedFinishes) {
      final ProxyDamage bound = ProxyResolution.damageAtTexelScale(finish, 2.0)!;
      expect(bound.measured, isFalse, reason: 'a bound was reported as a reading');
      // Compared like with like: the table is a mean over the seven corpus
      // scenes, so the bound is a claim about that mean and is checked against
      // the dpr-4 run's mean at the same texel scale.
      final List<double> atTwoTexels = <double>[
        for (final String scene in free[4]!.scenes) free[4]!.at(scene, finish, 2)!,
      ];
      final double mean = atTwoTexels.reduce((double a, double b) => a + b) / atTwoTexels.length;
      expect(
        mean,
        lessThan(bound.deltaE),
        reason: '$finish at 2.0 texels is above the bound the table hands out',
      );
      // The definitional zero, for contrast: the same texel scale on the dpr-2
      // ladder is its own reference.
      expect(ProxyResolution.divisor(1).meanDamage(finish), 0.0);
    }
  });

  test('monotone is a statement about the corpus mean, and the cells say how much', () {
    // What the reading assumes and what the arms actually support are not the
    // same claim, and the difference is the instrument's own floor. Over 168
    // steps at three densities the corpus mean is strictly monotone every time;
    // **five individual cells invert**, by up to 9.4% — `scroll_under_bar` at
    // `regular`, whose whole damage is 0.09 ΔE, and `over_photo` at dpr 4,
    // where a proxy at a quarter and one at an eighth of a texel have the same
    // nothing left to lose. Recorded rather than tolerated: a fix that made
    // this arm pass by tightening the ladder would be hiding the scatter the
    // interpolation is quoted to.
    var inversions = 0;
    var worst = 0.0;
    var steps = 0;
    for (final Ladder ladder in free.values) {
      for (final String finish in kRecordedFinishes) {
        final means = <int, double>{
          for (final int divisor in const <int>[2, 4, 8])
            divisor:
                <double>[
                  for (final String scene in ladder.scenes) ladder.at(scene, finish, divisor)!,
                ].reduce((double a, double b) => a + b) /
                ladder.scenes.length,
        };
        expect(means[2]!, lessThan(means[4]!), reason: '${ladder.path}/$finish');
        expect(means[4]!, lessThan(means[8]!), reason: '${ladder.path}/$finish');
        for (final String scene in ladder.scenes) {
          for (final (int a, int b) in const <(int, int)>[(2, 4), (4, 8)]) {
            steps++;
            final double coarser = ladder.at(scene, finish, b)!;
            final double finer = ladder.at(scene, finish, a)!;
            if (coarser <= finer) {
              inversions++;
              worst = worst > (finer - coarser) / coarser ? worst : (finer - coarser) / coarser;
            }
          }
        }
      }
    }
    expect(steps, 168);
    expect(inversions, lessThanOrEqualTo(5));
    expect(worst, lessThan(0.10));
  });

  test('the reading is not monotone, and the inversions are small and real', () {
    // **This arm asserted monotonicity until D187 and the measurement refuted
    // it.** Two rungs between the old ones — 0.667 and 0.333 texels — invert
    // against their deeper neighbours on three of the eight finish-by-recipe
    // columns: `regular` costs 0.235 at 0.667 and 0.221 at 0.5, `frosted`
    // (corrected) 0.623 at 0.333 and 0.565 at 0.25. A coarser recording costing
    // *less* is not what a low-pass does, and nothing here explains it; what is
    // established is that it is not the magnification factor, which was the
    // obvious guess and which `magnificationSource` refutes at matched texel
    // scales.
    //
    // It is recorded rather than smoothed because two things downstream depend
    // on it: `ProxyResolutionPolicy.choose` may not stop its walk at the first
    // rung over the budget (the arm below), and a caller reading two rungs
    // cannot assume their order.
    var inversions = 0;
    var worst = 0.0;
    for (final bool corrected in <bool>[false, true]) {
      for (final String finish in ProxyResolution.measuredFinishes) {
        final List<int> divisors = ProxyResolution.measuredDivisors;
        for (var i = 0; i < divisors.length - 1; i++) {
          final double coarser = ProxyResolution.divisor(
            divisors[i + 1],
          ).meanDamage(finish, blurCorrected: corrected)!;
          final double finer = ProxyResolution.divisor(
            divisors[i],
          ).meanDamage(finish, blurCorrected: corrected)!;
          if (coarser < finer) {
            inversions++;
            worst = math.max(worst, (finer - coarser) / finer);
          }
        }
      }
    }
    // Nine of them, and they have a shape: **every one is a D187 rung against
    // the next power of two** — 1/3 against 1/4, 1/6 against 1/8 — and none is
    // between two of the rungs that were there before. Worst 9.3%
    // (`frosted` corrected, 0.623 at 1/6 against 0.565 at 1/8).
    //
    // Two mechanisms were tested against it and both are refuted. The
    // magnification factor: at matched texel scales, magnifying by 3 and by 6
    // costs what 2 and 4 cost (`magnificationSource`). One texel being a
    // power-of-two number of *logical* pixels: the dpr-3 run's 1.333 and 2.667
    // arms land at 0.88…1.13 of the dense dpr-2 curve, which is where its 1.0
    // and 2.0 arms land too. So this is measured, reproduced arm for arm
    // against the recorded ladder, and unexplained.
    //
    // Twelve since D230: the light branch's row adds three, of the same shape —
    // 1/3 against 1/4 on both recipes, 1/6 against 1/8 uncorrected.
    expect(inversions, 12, reason: 'the table changed shape: $inversions inversions, worst $worst');
    expect(worst, closeTo(0.093, 0.002));

    // What the interpolation still owes: a point between two rungs lands
    // between *their* values, whatever the neighbouring rungs do.
    for (final String finish in ProxyResolution.measuredFinishes) {
      final ProxyDamage between = ProxyResolution.damageAtTexelScale(finish, 0.75)!;
      expect(between.deltaE, greaterThan(ProxyResolution.divisor(2).meanDamage(finish)!));
      expect(between.deltaE, lessThan(ProxyResolution.divisor(3).meanDamage(finish)!));
      expect(between.measured, isFalse);
    }
  });

  test('the log-log interpolation is biased low, which is why the rungs were run', () {
    // D187's own reason for existing, re-derived from the two reports rather
    // than restated: rebuild the table without its 3 and 6 rungs, interpolate
    // where they are, and compare against what the ladder measured there. Every
    // one of the eight points comes out **under** the measurement, by 3…29%.
    //
    // The direction is the whole finding. A policy spending its budget against
    // an interpolation between rungs a factor of two apart was systematically
    // overspending it, and the fix was a denser ladder rather than a bolder or
    // a more timid walk.
    final Map<String, Object?> report =
        jsonDecode(File(ProxyResolution.damageSourceCorrected).readAsStringSync()) as Map<String, Object?>;
    final arms = (report['arms']! as List<Object?>).cast<Map<String, Object?>>();
    double measured(String finish, int divisor) {
      final List<double> mean = <double>[
        for (final Map<String, Object?> arm in arms)
          if (packageName(arm['finish']! as String) == finish &&
              arm['axis'] == 'resolution' &&
              arm['resolution_divisor'] == divisor &&
              arm['delta_e_mean'] != null)
            arm['delta_e_mean']! as double,
      ];
      return mean.reduce((double a, double b) => a + b) / mean.length;
    }

    var worstUnder = 0.0;
    var leastUnder = double.infinity;
    for (final String finish in kRecordedFinishes) {
      for (final (int divisor, int coarser, int finer) in <(int, int, int)>[
        (3, 2, 4),
        (6, 4, 8),
      ]) {
        // The old table's own log-log step, between the rungs that bracketed
        // this one before it existed.
        final double tNew = ProxyResolution.damageTableDevicePixelRatio / divisor;
        final double tCoarse = ProxyResolution.damageTableDevicePixelRatio / coarser;
        final double tFine = ProxyResolution.damageTableDevicePixelRatio / finer;
        final double yCoarse = measured(finish, coarser);
        final double yFine = measured(finish, finer);
        final double t = (math.log(tNew) - math.log(tFine)) / (math.log(tCoarse) - math.log(tFine));
        final double predicted = math.exp(
          math.log(yFine) + t * (math.log(yCoarse) - math.log(yFine)),
        );
        final double error = (measured(finish, divisor) - predicted) / predicted;
        expect(
          error,
          greaterThan(0),
          reason: '$finish at 1/$divisor: the interpolation was not low',
        );
        worstUnder = math.max(worstUnder, error);
        leastUnder = math.min(leastUnder, error);
      }
    }
    expect(leastUnder, closeTo(0.029, 0.002));
    expect(worstUnder, closeTo(0.291, 0.002));
  });

  test('the walk does not stop at the first rung over the budget, and that costs a step', () {
    // The consequence of the inversions above, with the arm written as the case
    // that separates the two walks rather than as a restatement.
    //
    // `thinLight` at dpr 2 under a budget of 0.443 — which is the composed
    // budget the staleness arm at the end of this file computes, so it is a
    // number this project already had a reason to hold. The rungs it meets are
    // 1.0 -> 0.264, 0.667 -> 0.462, 0.5 -> 0.443. A walk that breaks on the
    // first rung over the budget stops at a half and never looks at the
    // quarter, which fits exactly. A walk that scans keeps the quarter.
    const double budget = 0.443;
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'thinLight',
      finishSigmaLogical: 1.2,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: budget,
    );
    expect(
      choice.resolution,
      const ProxyResolution.quarter(),
      reason: 'the walk stopped at the rung that inverts',
    );
    expect(choice.damage!.deltaE, lessThanOrEqualTo(budget));
    // The rung it had to walk past, which is what makes this an arm rather than
    // an assertion that the answer did not change.
    expect(
      ProxyResolution.damageAtTexelScale('thinLight', 2 / 3, blurCorrected: true)!.deltaE,
      greaterThan(budget),
    );

    // And scanning never picks something a breaking walk would have picked
    // deeper: over every finish, density and both recipes, the chosen divisor
    // is the deepest candidate inside the budget and the optics ceiling.
    for (final bool corrected in <bool>[false, true]) {
      for (final String finish in ProxyResolution.measuredFinishes) {
        final double sigma = <String, double>{
          'clear': 0.0,
          'thinLight': 1.2,
          'frosted': 8.0,
          'regularDark': 2.6,
          'regularLight': 2.6,
        }[finish]!;
        for (final double dpr in <double>[1, 2, 3, 4]) {
          final ProxyResolutionChoice made = ProxyResolutionPolicy.choose(
            finish: finish,
            finishSigmaLogical: sigma,
            devicePixelRatio: dpr,
            costModel: ProxyCostModel.areaCharged,
            blurCorrected: corrected,
          );
          final int ceiling = sigma > 0
              ? ProxyResolution.maxDivisorFor(sigma, dpr)
              : ProxyResolutionPolicy.candidateDivisors.last;
          var deepest = 1;
          for (final int divisor in ProxyResolutionPolicy.candidateDivisors.skip(1)) {
            if (divisor > ceiling) {
              break;
            }
            final ProxyDamage? damage = ProxyResolution.damageAtTexelScale(
              finish,
              dpr / divisor,
              blurCorrected: corrected,
            );
            if (damage == null) {
              break;
            }
            if (damage.deltaE <= ProxyResolutionPolicy.defaultDamageBudgetDeltaE) {
              deepest = divisor;
            }
          }
          expect(
            made.resolution.divisor,
            deepest,
            reason: '$finish at dpr $dpr (corrected: $corrected) is not the deepest that fits',
          );
        }
      }
    }
  });

  test('the two keys disagree, so a reading by divisor would fail this file', () {
    // The negative control for part 2: if `damageAtTexelScale` quietly ignored
    // the density and read the divisor table, every arm above would still pass
    // at dpr 2 and only this one would fail.
    const resolution = ProxyResolution.quarter();
    final double atDpr2 = ProxyResolution.damageAtTexelScale(
      'clear',
      resolution.ratioFor(2),
    )!.deltaE;
    final double atDpr4 = ProxyResolution.damageAtTexelScale(
      'clear',
      resolution.ratioFor(4),
    )!.deltaE;
    expect(atDpr2 / atDpr4, greaterThan(1.8), reason: 'the same divisor costs the same everywhere');
  });

  // -------------------------------------------------------------------------
  // 3. The chooser.
  // -------------------------------------------------------------------------

  test('every family gets the same divisor, and only the price knows the hardware', () {
    // This arm has encoded a derivation twice and been wrong twice, in the
    // same shape. First for Metal, on D119: the capture is frame-charged
    // there, so a divisor was said to save nothing — it saves 40% of what our
    // glass costs (D128). Then for `unmeasured`: no model fitted, so "a
    // measured loss against an unmeasured gain is not a trade" and the
    // chooser returned full resolution — and the one unmeasured device anybody
    // ran got 37 fps from that where a quarter gets 115 (D134). Both arms were
    // right about the code and wrong about the device, because both encoded a
    // conclusion that held exactly until somebody measured its subject.
    //
    // What survives is the part that was never a derivation: the divisor is
    // chosen on quality, and quality does not know the hardware. So all three
    // families agree at every density, and the only thing the cost model is
    // allowed to change is whether the choice comes with a price.
    for (final double dpr in const <double>[1, 2, 3, 4]) {
      final Map<ProxyCostModel, ProxyResolutionChoice> byModel = <ProxyCostModel, ProxyResolutionChoice>{
        for (final ProxyCostModel model in ProxyCostModel.values)
          model: ProxyResolutionPolicy.choose(
            finish: 'regularDark',
            finishSigmaLogical: 2.6,
            devicePixelRatio: dpr,
            costModel: model,
          ),
      };
      final ProxyResolutionChoice metal = byModel[ProxyCostModel.frameCharged]!;
      for (final ProxyResolutionChoice choice in byModel.values) {
        expect(
          choice.resolution,
          metal.resolution,
          reason: 'dpr $dpr: the quality budget is the same on every family, so the divisor must be',
        );
        expect(choice.reason, metal.reason);
        expect(choice.reason, isNot(ProxyDivisorReason.pinnedByHost));
      }
      final ProxyResolutionChoice unmeasured = byModel[ProxyCostModel.unmeasured]!;
      expect(unmeasured.captureCostFactor, isNull, reason: 'an unmeasured model priced something');
      expect(unmeasured.routeCostFactor, isNull);
    }
    // The point that matters on a phone: at dpr 2 with the Apple-calibrated
    // finish a silent host now records at a quarter, which is the arm the
    // device measured at 115 fps against 37 (D134), and it gets there for the
    // quality reason and not a hardware one.
    final ProxyResolutionChoice silent = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.unmeasured,
    );
    expect(silent.resolution, const ProxyResolution.quarter());
    // `damageBudget`, not `offTheLadder`: since D137 the walk carries on to
    // the eighth and is turned back there by the budget (0.25 texels costs
    // 0.372 against 0.348). Same answer, and now for the reason the policy
    // claims to decide on — the old reason was the list running out, which is
    // what hid the defect at dpr 4 for a release.
    expect(silent.reason, ProxyDivisorReason.damageBudget);
    expect(silent.damage!.deltaE, lessThan(ProxyResolutionPolicy.defaultDamageBudgetDeltaE));
    // The negative control the fix needs, and it is the defect stated as a
    // number: at the point the chooser picks on Metal the *capture* is 6% more
    // expensive than at full resolution and the *route* is 55% cheaper. Anything
    // deciding on the first column returns full resolution and looks correct.
    final ProxyResolutionChoice metal = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.frameCharged,
    );
    expect(metal.resolution, const ProxyResolution.quarter());
    expect(metal.captureCostFactor, greaterThan(1.0));
    expect(metal.routeCostFactor!.factor, lessThan(0.5));
    expect(metal.routeCostFactor!.measured, isTrue);
  });

  test('the route table refuses where nobody ran, and labels the point nobody ran', () {
    const ProxyCostModel metal = ProxyCostModel.frameCharged;
    expect(const ProxyResolution.full().routeCostFactor(metal)!.factor, 1.0);
    expect(const ProxyResolution.full().routeCostFactor(metal)!.measured, isTrue);
    expect(const ProxyResolution.quarter().routeCostFactor(metal)!.measured, isTrue);
    // Taken since D138, and the reason it had to be: two points defined it
    // exactly, so it had no residual, and when it was measured it came back
    // 18.6% off. Every row of this table is a reading now.
    expect(const ProxyResolution.half().routeCostFactor(metal)!.measured, isTrue);
    // Taken since D139, and the reason that one had to be taken is the reason
    // this table has no formula in it: fitted on the first three points, every
    // family predicted this row and every one missed, from -10% to +20%.
    expect(const ProxyResolution.divisor(8).routeCostFactor(metal)!.measured, isTrue);
    // Three is inside the span and is still refused: interpolating between
    // families that disagree by 4x is not a reading either.
    expect(const ProxyResolution.divisor(3).routeCostFactor(metal), isNull);
    // And past the deepest divisor anybody ran there is nothing to read off. It
    // is a refusal by evidence rather than by caution now — the curve has a knee
    // inside the measured span, so an extrapolation past it has no shape to
    // follow.
    expect(const ProxyResolution.divisor(16).routeCostFactor(metal), isNull);
    // And the family where the route was never measured at all says so, at
    // every divisor including the one where the capture has a price.
    for (final int divisor in const <int>[1, 2, 4, 8]) {
      expect(
        ProxyResolution.divisor(divisor).routeCostFactor(ProxyCostModel.areaCharged),
        isNull,
        reason: 'Adreno priced the capture, not the route',
      );
      expect(ProxyResolution.divisor(divisor).routeCostFactor(ProxyCostModel.unmeasured), isNull);
    }
  });

  test('the default budget lands on the working point the cost budget assumed', () {
    // D63 estimated our glass at ×1.2…2.1 Material *with the proxy at a quarter
    // resolution*, which was an assumption nobody had checked from the quality
    // side. The default budget — 1% of the distance between two of Apple's own
    // materials — returns exactly that for the finish calibrated to one of
    // them, on the density the ladder was taken at.
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
    );
    expect(choice.resolution, const ProxyResolution.quarter());
    // Turned back by the budget at the eighth rather than by the end of the
    // ladder — see the `silent` arm above.
    expect(choice.reason, ProxyDivisorReason.damageBudget);
    expect(choice.captureCostFactor, 0.27);
    expect(choice.damage!.deltaE, lessThan(ProxyResolutionPolicy.defaultDamageBudgetDeltaE));
    expect(choice.damage!.measured, isTrue);
  });

  test('a clear finish gets no divisor at the default budget, and the budget is why', () {
    // Two criteria used to say so and the optics answered first, which made the
    // answer look robust and made it unmovable: the ceiling is 1 at sigma 0 on
    // every screen at every budget, so the policy could never divide a
    // transparent finish however much quality the host was willing to spend.
    // B13 measured what that cost on a device — full resolution is the only arm
    // on SM-S938B that misses vsync, ×2.15 of an opaque fill (D158) — and D164
    // took the ceiling out of the sigma-0 case. The divisor here does not move;
    // the *reason* does, and it is the reason a host reads.
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'clear',
      finishSigmaLogical: 0,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
    );
    expect(choice.resolution, const ProxyResolution.full());
    expect(choice.reason, ProxyDivisorReason.damageBudget);
    // The two numbers the refusal is made of, quoted rather than implied: the
    // first rung costs 0.646 ΔE and the default budget is 1% of the distance
    // between two of Apple's own materials.
    expect(
      ProxyResolution.damageAtTexelScale('clear', 1.0)!.deltaE,
      greaterThan(ProxyResolutionPolicy.defaultDamageBudgetDeltaE),
    );
    // And the ceiling still reads 1 — it is consulted no longer, not repaired.
    expect(ProxyResolution.maxDivisorFor(0, 2), 1);
  });

  test('and a host that pays for it gets the divisor, which is what D164 changed', () {
    // The lever B13 asked for, and the arm is keyed on the quantity that moves
    // rather than on the knob: 0.646 ΔE is the first rung's own price, so a
    // budget just above it buys exactly that rung and a budget just below it
    // buys nothing. Both sides are asserted, because "a budget of 0.7 divides"
    // alone would also pass on a policy that ignored the budget entirely.
    ProxyResolutionChoice at(double budget) => ProxyResolutionPolicy.choose(
      finish: 'clear',
      finishSigmaLogical: 0,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: budget,
    );
    final ProxyResolutionChoice paid = at(0.7);
    expect(paid.resolution, const ProxyResolution.half());
    expect(paid.damage!.deltaE, closeTo(0.646, 0.0005));
    expect(paid.damage!.measured, isTrue, reason: 'the rung was interpolated, not read');
    // The second rung is 1.279, so 0.7 stops there and says which criterion.
    expect(paid.reason, ProxyDivisorReason.damageBudget);

    expect(at(0.6).resolution, const ProxyResolution.full());

    // The whole ladder, for a host that has declared it can spend a material's
    // worth of quality. Nothing in the package chooses this; it is here because
    // the old ceiling made it unreachable even by declaration.
    final ProxyResolutionChoice generous = at(100);
    expect(generous.resolution, const ProxyResolution.divisor(8));
    expect(generous.reason, ProxyDivisorReason.offTheLadder);
  });

  test('the identity finish never divides, whatever the budget says', () {
    // The control finish reproduces the backdrop byte for byte (D64), which is
    // what every pixel comparison in this repository is read against, and it
    // also has sigma 0 — so the exemption D164 added must not reach it. What
    // stops it is that nobody graded `identity`: no damage table, so the walk
    // refuses to extrapolate at the first rung and says so.
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'identity',
      finishSigmaLogical: 0,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: 100,
    );
    expect(choice.resolution, const ProxyResolution.full());
    expect(choice.reason, ProxyDivisorReason.damageBudget);
    expect(choice.damage, isNull);
  });

  test('the screen is an input, and it moves the answer', () {
    // The same finish and the same budget on three screens. If the chooser read
    // the damage table by divisor these would all agree, which is the defect
    // this whole step exists to make impossible.
    ProxyResolutionChoice at(double dpr, String finish, double sigma) => ProxyResolutionPolicy.choose(
      finish: finish,
      finishSigmaLogical: sigma,
      devicePixelRatio: dpr,
      costModel: ProxyCostModel.areaCharged,
    );
    expect(at(1, 'regularDark', 2.6).resolution, const ProxyResolution.half());
    expect(at(2, 'regularDark', 2.6).resolution, const ProxyResolution.quarter());
    expect(at(2, 'frosted', 8).resolution, const ProxyResolution.half());
    // The pair that says the longer ladder is still the budget's ladder and not
    // a blanket deepening. Both are dpr 4, both may now reach the eighth, and
    // only one does: at 0.5 texels `regular` costs 0.222 and `frosted` costs
    // **0.500**, against a budget of 0.348. So the Apple-calibrated finish moves
    // to the same texel scale it settled on at dpr 2 — one working point wearing
    // two divisors — and the thick blur stays where it was.
    expect(at(4, 'frosted', 8).resolution, const ProxyResolution.quarter());
    expect(at(4, 'regularDark', 2.6).resolution, const ProxyResolution.divisor(8));
    // And the deepest screen still does not walk past the ladder, however much
    // room the budget leaves — the list ends, and the reason says so in its own
    // name rather than being mistaken for a verdict about the picture.
    final ProxyResolutionChoice generous = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 4,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: 100,
    );
    expect(generous.resolution, const ProxyResolution.divisor(8));
    expect(generous.reason, ProxyDivisorReason.offTheLadder);
    expect(ProxyResolutionPolicy.candidateDivisors.last, 8);
  });

  test('the optics ceiling binds before the budget when the finish is thin', () {
    // A finish whose own blur is small enough that the proxy would out-blur it
    // before the picture noticed. `maxDivisorFor` is the gate, and the arm is
    // built so the budget is not: it is set high enough to allow anything.
    //
    // This is also what the sigma-0 exemption (D164) is *not*: above zero the
    // ceiling keeps its work, and it is not the damage table saying the same
    // thing twice — the table is keyed by the finish's name, so it reads
    // `regular`'s numbers here while the sigma handed in is a fifth of
    // `regular`'s. Only at sigma 0 do the two criteria describe one quantity,
    // because there the table's own rungs were measured at that sigma.
    const double sigma = 0.5;
    expect(ProxyResolution.maxDivisorFor(sigma, 2), 3);
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: sigma,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: 100,
    );
    // **Exactly the ceiling, which it could not reach before D187**: the
    // candidate list was the powers of two, so a ceiling of 3 stopped the walk
    // at 2 and the arm read that as the ceiling binding. It was the list
    // binding at a number the ceiling had nothing to do with; now the two
    // coincide because 3 is a rung.
    expect(choice.resolution, const ProxyResolution.divisor(3));
    expect(choice.reason, ProxyDivisorReason.opticsCeiling);
  });

  test('a budget under the first rung leaves the proxy at full resolution', () {
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
      damageBudgetDeltaE: 0.01,
    );
    expect(choice.resolution, const ProxyResolution.full());
    expect(choice.reason, ProxyDivisorReason.damageBudget);
    expect(choice.damage, isNull, reason: 'the reference arm was given a damage figure');
  });

  test('an unknown finish refuses rather than guessing', () {
    final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
      finish: 'nosuchfinish',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.areaCharged,
    );
    expect(choice.resolution, const ProxyResolution.full());
    expect(choice.reason, ProxyDivisorReason.damageBudget);
  });

  // -------------------------------------------------------------------------
  // 4. The route's own price, from the pair of device runs.
  // -------------------------------------------------------------------------

  test('the pair is a comparison: five steps did not move and one did', () {
    final Map<String, Step> full = readLadder(ProxyResolution.metalRouteSources[1]!);
    final Map<String, Step> quarter = readLadder(ProxyResolution.metalRouteSources[4]!);

    // The control, and it is what makes two runs taken either side of a reboot
    // one measurement. Nothing but the `glass` step's proxy resolution differed,
    // so anything else moving is the device rather than the change.
    for (final String variant in const <String>[
      'plain',
      'material',
      'fake',
      'fakeOpaqueBacked',
      'backdrop',
    ]) {
      expect(
        quarter[variant]!.frameMs / full[variant]!.frameMs,
        closeTo(1.0, 0.02),
        reason: '$variant moved between the blocks, so the pair is two runs and not a comparison',
      );
    }
    expect(quarter['glass']!.frameMs / full['glass']!.frameMs, closeTo(0.604, 0.005));

    // And what the divisor actually was is read off the device's own counter in
    // the block that has one, not off the hardware the host declared.
    expect(quarter['glass']!.divisor, 4);
    expect(full['glass']!.divisor, isNull);
  });

  test('the route table in lib/ is the decomposition of those two runs', () {
    final Map<String, Step> full = readLadder(ProxyResolution.metalRouteSources[1]!);
    final Map<String, Step> quarter = readLadder(ProxyResolution.metalRouteSources[4]!);

    // The package's number is about the addition over the floor, because the
    // floor is the application's own UI: the package neither pays it nor moves
    // it, and a frame-relative figure would be as much about the scene.
    final double addFull = full['glass']!.frameMs - full['plain']!.frameMs;
    final double addQuarter = quarter['glass']!.frameMs - quarter['plain']!.frameMs;

    // Two unknowns, two equations: at a divisor of 4 on a dpr-2 screen the proxy
    // holds a sixteenth of the texels.
    final double a = (addFull - addQuarter) / (1 - 1 / 16);
    final double c = addFull - a;
    expect(a / addFull, closeTo(ProxyResolution.metalAdditionAreaShare, 0.001));

    // Two runs either side of a reboot, against four arms of one run: 2.3%
    // apart, which is the device's own reproducibility rather than a
    // disagreement. The table takes the four-point run, so this is the loosest
    // of the three comparisons on purpose — it says the old pair, the
    // three-point run and the four-point run are one measurement. The tolerance
    // is 3% because that is what the three runs actually span; tightening it
    // would be a claim about the device that no run supports.
    expect(
      const ProxyResolution.quarter().routeCostFactor(ProxyCostModel.frameCharged)!.factor,
      closeTo(addQuarter / addFull, 0.03),
      reason: 'the two blocks and the four-point run are not the same measurement',
    );
    expect(const ProxyResolution.full().routeCostFactor(ProxyCostModel.frameCharged)!.factor, 1.0);

    // The one number here that is a check rather than a fit. D56 measured, on
    // the capture grid and on a different content family, that a capture costs
    // about one more frame once: `C_frame` / baseline of 0.73…1.01 over four
    // blocks. Our route's area-independent term is 1.10 of its floor frame —
    // 8.8% above the top of that band rather than inside it, which is why it is
    // quoted as agreement to within a tenth and not as a reproduction.
    expect(c / full['plain']!.frameMs, closeTo(1.10, 0.02));
  });

  test('the divisor nobody had run came back 18.6% off the prediction (D138)', () {
    // The arm this file existed for. The number was written here **before** the
    // run so that taking it would be a comparison and not a fresh derivation,
    // and the comparison came out against the prediction: `A·f + C` fitted on
    // divisors 1 and 4 with `f = 1/k²` said the middle point would add 1.5675 ms
    // over the floor, and the device added 1.8587.
    //
    // Two points fit two parameters exactly, so the middle had no residual to be
    // judged by — which was said here at the time and is the whole reason the
    // third point was worth a reboot.
    final Map<String, Step> full = readLadder(ProxyResolution.metalRouteSources[1]!);
    final Map<String, Step> quarter = readLadder(ProxyResolution.metalRouteSources[4]!);
    final double floor = full['plain']!.frameMs;
    final double addFull = full['glass']!.frameMs - floor;
    final double addQuarter = quarter['glass']!.frameMs - quarter['plain']!.frameMs;

    // The prediction, re-derived from the two blocks it was made on rather than
    // copied, so that it stays checkable after the table stopped carrying it.
    final double a = (addFull - addQuarter) / (1 - 1 / 16);
    final double c = addFull - a;
    final double predictedAddition = a / 4 + c;
    expect(floor + predictedAddition, closeTo(2.626, 0.01));
    expect((floor + predictedAddition) / floor, closeTo(2.48, 0.01));

    // And what the device did. One binary, one shuffle, all three divisors as an
    // axis of the family, so they share a floor by construction.
    final Map<String, Step> three = readLadder(ProxyResolution.metalThreePointSource);
    final double measuredFloor = three['plain']!.frameMs;
    final double measuredAddition = three['glass_d2']!.frameMs - measuredFloor;
    expect(three['glass_d2']!.frameMs / measuredFloor, closeTo(2.763, 0.005));
    expect(measuredAddition / predictedAddition, closeTo(1.186, 0.005));

    // Which is a refutation only because the same run reproduced the two blocks
    // the prediction was built on. Without this the miss is equally consistent
    // with a device in another state — and 18.6% is 37x the agreement on the
    // anchor it shares with block A.
    expect(three['glass_d1']!.frameMs / full['glass']!.frameMs, closeTo(1.0, 0.005));
    expect(three['glass_d4']!.frameMs / quarter['glass']!.frameMs, closeTo(1.0, 0.01));
    for (final String rung in const <String>['plain', 'material', 'backdrop']) {
      expect(
        three[rung]!.frameMs / full[rung]!.frameMs,
        closeTo(1.0, 0.02),
        reason: '$rung moved, so the run is not comparable to the block',
      );
    }

    // What the miss says, and what it does not. Re-fitted over all three points
    // the area family leaves a worst residual of 6.4% of the largest addition,
    // and `f = 1/k` leaves 2.2% — so the points prefer the proxy's *linear* size
    // to its texel count, which is D28's finding about Adreno's capture arriving
    // on Metal for the whole route. It is one degree of freedom (three points,
    // two parameters), so it ranks families and does not resolve an exponent.
    final List<(int, double)> arms = <(int, double)>[
      (1, three['glass_d1']!.frameMs - measuredFloor),
      (2, measuredAddition),
      (4, three['glass_d4']!.frameMs - measuredFloor),
    ];
    double worstResidual(double Function(int) of) {
      final List<double> xs = arms.map((r) => of(r.$1)).toList();
      final List<double> ys = arms.map((r) => r.$2).toList();
      final int n = xs.length;
      final double sx = xs.reduce((p, q) => p + q);
      final double sy = ys.reduce((p, q) => p + q);
      double sxx = 0;
      double sxy = 0;
      for (var i = 0; i < n; i++) {
        sxx += xs[i] * xs[i];
        sxy += xs[i] * ys[i];
      }
      final double slope = (n * sxy - sx * sy) / (n * sxx - sx * sx);
      final double intercept = (sy - slope * sx) / n;
      double worst = 0;
      for (var i = 0; i < n; i++) {
        final double r = (ys[i] - (slope * xs[i] + intercept)).abs();
        if (r > worst) worst = r;
      }
      return worst / ys.reduce(math.max);
    }

    final double area = worstResidual((int k) => 1 / (k * k));
    final double linear = worstResidual((int k) => 1 / k);
    expect(area, closeTo(0.064, 0.002));
    expect(linear, closeTo(0.022, 0.002));
    expect(
      area / linear,
      greaterThan(2.0),
      reason: 'the family comparison has no resolving power, so it settles nothing',
    );
  });

  test('the fourth divisor refuted the shape, not the exponent (D139)', () {
    // D138 ended with "a fourth divisor would settle it". It was taken, and it
    // did not settle the exponent — it removed the question: no `A·k^-p + C` at
    // any exponent describes the four points.
    final Map<String, Step> four = readLadder(ProxyResolution.metalRouteCostSource);
    final double floor = four['plain']!.frameMs;
    final Map<int, double> add = <int, double>{
      for (final int k in const <int>[1, 2, 4, 8]) k: four['glass_d$k']!.frameMs - floor,
    };
    // The axis has an observable trace rather than only a name: the arm keyed
    // `glass_d8` recorded a proxy at a divisor of 8, which is what separates a
    // fourth point from a duplicate of the third under a different label.
    for (final int k in const <int>[1, 2, 4, 8]) {
      expect(four['glass_d$k']!.divisor, k, reason: 'the pin did not reach the recorder');
    }

    // The comparison is licensed by the three arms this run shares with D138's,
    // across a reboot and a different shuffle seed. As *ratios* — which is what
    // the table stores — the two runs agree to about a percent; a run-wide
    // offset cancels out of a ratio and does not cancel out of an absolute.
    final Map<String, Step> three = readLadder(ProxyResolution.metalThreePointSource);
    final double threeFloor = three['plain']!.frameMs;
    final Map<int, double> addThree = <int, double>{
      for (final int k in const <int>[1, 2, 4]) k: three['glass_d$k']!.frameMs - threeFloor,
    };
    for (final int k in const <int>[2, 4]) {
      expect(
        (addThree[k]! / addThree[1]!) / (add[k]! / add[1]!),
        closeTo(1.0, 0.02),
        reason: 'the two runs are not the same measurement at a divisor of $k',
      );
    }

    // What D138's own fits predicted for the point nobody had run. Re-fitted
    // here from that run's digest rather than copied, so the prediction stays a
    // prediction rather than a number somebody typed.
    double predictEighth(double Function(int) of) {
      final ({double a, double c, double worst}) f = fitTwoTerm(<(double, double)>[
        for (final int k in const <int>[1, 2, 4]) (of(k), addThree[k]!),
      ]);
      return f.a * of(8) + f.c;
    }

    double missOf(double Function(int) of) => (add[8]! - predictEighth(of)) / predictEighth(of);

    double area(int k) => 1 / (k * k);
    double linear(int k) => 1 / k;
    double threeQuarter(int k) => math.pow(1 / (k * k), 0.75).toDouble();
    double d28(int k) => math.pow(1 / k, 0.9).toDouble();

    expect(missOf(area), closeTo(-0.082, 0.01));
    expect(missOf(threeQuarter), closeTo(0.004, 0.01));
    expect(missOf(linear), closeTo(0.167, 0.01));
    expect(missOf(d28), closeTo(0.218, 0.01));

    // And the inversion that is the transferable half: the family that fitted
    // the three points BEST predicted the fourth WORST. One residual over three
    // points is one degree of freedom, and ranking by it ranks the wrong thing.
    double residualOnThree(double Function(int) of) => fitTwoTerm(<(double, double)>[
      for (final int k in const <int>[1, 2, 4]) (of(k), addThree[k]!),
    ]).worst;
    expect(
      residualOnThree(d28),
      lessThan(residualOnThree(threeQuarter)),
      reason: 'D28 was not the best in-sample family, so the inversion is not the one recorded',
    );
    expect(
      missOf(d28).abs(),
      greaterThan(missOf(threeQuarter).abs() * 5),
      reason: 'the best in-sample family did not predict worst, so D139 says something else',
    );

    // Why it is the shape and not the exponent. A power law's successive drops
    // fall by a constant ratio, so the exponent each adjacent pair implies has
    // to be one number. Here the first pair says 0.53 and the second says 3.66.
    final double dropA = add[1]! - add[2]!;
    final double dropB = add[2]! - add[4]!;
    final double dropC = add[4]! - add[8]!;
    final double pFirst = math.log(dropA / dropB) / math.log(2);
    final double pSecond = math.log(dropB / dropC) / math.log(2);
    expect(pFirst, closeTo(0.53, 0.03));
    expect(pSecond, closeTo(3.66, 0.05));
    expect(
      pSecond / pFirst,
      greaterThan(5.0),
      reason: 'one exponent describes both intervals, so there is no knee to report',
    );

    // The consequence the package acts on: past half a texel per logical pixel
    // the lever has run out. 4.1% of the addition and 1.3% of the
    // full-resolution frame, against a between-run reproducibility of about 1%.
    expect((add[4]! - add[8]!) / add[4]!, closeTo(0.041, 0.005));
    expect((add[4]! - add[8]!) / four['glass_d1']!.frameMs, closeTo(0.013, 0.003));

    // And the table in `lib/` is these four readings, not a curve through them.
    const ProxyCostModel metal = ProxyCostModel.frameCharged;
    for (final int k in const <int>[1, 2, 4, 8]) {
      expect(
        ProxyResolution.divisor(k).routeCostFactor(metal)!.factor,
        closeTo(add[k]! / add[1]!, 0.0005),
        reason: 'the row for a divisor of $k is not what the run it names measured',
      );
    }
  });

  test('what the divisor buys is the blur pass and nothing else (D140)', () {
    // D139 left one hypothesis for its knee and it was arithmetic over the
    // source rather than a measurement. This is the measurement: the same two
    // divisors with the residual blur pass switched off, in the same binary
    // under the same shuffle.
    final Map<String, Step> split = readLadder(ProxyResolution.metalBlurSplitSource);
    final double floor = split['plain']!.frameMs;
    double add(String arm) => split[arm]!.frameMs - floor;

    // The arms differ in one thing, and this is what says so: every one of them
    // recorded a proxy on every frame and painted through the optics. A `noblur`
    // arm that had quietly stopped capturing would show the same saving for a
    // completely different reason.
    for (final String arm in const <String>[
      'glass_d1',
      'glass_d1_noblur',
      'glass_d8',
      'glass_d8_noblur',
    ]) {
      expect(split[arm]!.divisor, arm.startsWith('glass_d1') ? 1 : 8);
    }

    // What the pass costs, where it is largest: nearly three quarters of
    // everything the package adds to the frame at full resolution.
    final double blurAtFull = add('glass_d1') - add('glass_d1_noblur');
    final double blurAtEighth = add('glass_d8') - add('glass_d8_noblur');
    expect(blurAtFull, closeTo(2.068, 0.01));
    expect(blurAtFull / add('glass_d1'), closeTo(0.728, 0.005));
    expect(blurAtEighth, closeTo(0.126, 0.01));

    // And the sentence the whole run exists for. With the pass on, an eighth is
    // 1.69 ms cheaper than full resolution. With it off, an eighth is *dearer*.
    expect(add('glass_d1') - add('glass_d8'), closeTo(1.694, 0.01));
    expect(
      add('glass_d1_noblur') - add('glass_d8_noblur'),
      closeTo(-0.249, 0.01),
      reason: 'the divisor bought something other than the blur, so D140 says less than it does',
    );
    expect(
      (blurAtFull - blurAtEighth) / (add('glass_d1') - add('glass_d8')),
      closeTo(1.15, 0.02),
      reason: 'the pass does not account for the whole fall',
    );

    // What is left reproduces D56's band with no fit in it. That band was
    // measured on the capture grid, on another content family, in another
    // experiment: `C_frame` / baseline of 0.73…1.01, i.e. a capture costs about
    // one more frame, once. Three fitted decompositions had been trying to land
    // on it — D128 got 1.10 and called it agreement to within a tenth, D138's
    // re-fit got 0.63…0.75, D139 showed there was no fit to have.
    expect(add('glass_d1_noblur') / floor, closeTo(0.731, 0.005));
    expect(add('glass_d8_noblur') / floor, closeTo(0.967, 0.005));
    for (final String arm in const <String>['glass_d1_noblur', 'glass_d8_noblur']) {
      expect(add(arm) / floor, greaterThanOrEqualTo(0.73));
      expect(add(arm) / floor, lessThanOrEqualTo(1.01));
    }

    // Licensed by the tie to the run the four divisors came from: same scene,
    // same window, same finish, a reboot apart.
    final Map<String, Step> four = readLadder(ProxyResolution.metalRouteCostSource);
    for (final String arm in const <String>['plain', 'glass_d1']) {
      expect(
        split[arm]!.frameMs / four[arm]!.frameMs,
        closeTo(1.0, 0.01),
        reason: '$arm moved, so the two runs are not the same measurement',
      );
    }
    // The eighth ties looser — 3.0% — and it is quoted rather than hidden: that
    // arm carried an 8.5% spread here and 3.9% there.
    expect(split['glass_d8']!.frameMs / four['glass_d8']!.frameMs, closeTo(1.0, 0.035));

    // And the consequence with a shipping edge: a finish with no sigma is the
    // `noblur` arm by construction (`_blurred` returns the atlas untouched), so
    // a divisor buys it nothing but damage — and the damage is what refuses it,
    // since D164 took the optics ceiling out of the sigma-0 case. Which
    // criterion answers matters here rather than elsewhere: this arm reads the
    // ladder, and the ladder's `clear` rungs were measured on exactly this path,
    // with no residual blur to correct them.
    expect(ProxyResolution.maxDivisorFor(GlassFinish.clear.blurSigmaLogical, 2), 1);
    final ProxyResolutionChoice clear = ProxyResolutionPolicy.choose(
      finish: 'clear',
      finishSigmaLogical: GlassFinish.clear.blurSigmaLogical,
      devicePixelRatio: 2,
      costModel: ProxyCostModel.frameCharged,
    );
    expect(clear.resolution, const ProxyResolution.full());
    expect(clear.reason, ProxyDivisorReason.damageBudget);
  });

  test('the knee belongs to the blur pass, against a prediction (D141)', () {
    // D140 had two points and therefore a ratio rather than a law. The middle
    // was the discriminating cell and both answers were written down before the
    // run: a power law through those two points gives 0.814 ms for the pass at a
    // divisor of 2, and the knee hypothesis needs about 1.06 to reconstruct
    // D139's total there. Taking it was a comparison, not a fresh derivation.
    final Map<String, Step> curve = readLadder(ProxyResolution.metalBlurCurveSource);
    final double floor = curve['plain']!.frameMs;
    double add(String arm) => curve[arm]!.frameMs - floor;
    double blurAt(int k) => add('glass_d$k') - add('glass_d${k}_noblur');

    expect(blurAt(2), closeTo(1.108, 0.01));
    // The power law's prediction, re-derived from D140's own digest rather than
    // copied, so it stays a prediction after this file stops quoting it.
    final Map<String, Step> split = readLadder(ProxyResolution.metalBlurSplitSource);
    final double splitFloor = split['plain']!.frameMs;
    final double blurFull =
        (split['glass_d1']!.frameMs - splitFloor) - (split['glass_d1_noblur']!.frameMs - splitFloor);
    final double blurEighth =
        (split['glass_d8']!.frameMs - splitFloor) - (split['glass_d8_noblur']!.frameMs - splitFloor);
    final double exponent = math.log(blurFull / blurEighth) / math.log(8);
    expect(exponent, closeTo(1.345, 0.005));
    final double powerLaw = blurFull * math.pow(0.5, exponent);
    expect(powerLaw, closeTo(0.814, 0.005));
    expect(
      (blurAt(2) - powerLaw) / powerLaw,
      closeTo(0.36, 0.02),
      reason: 'the pass followed the power law after all, so the knee is not its',
    );

    // And the pass's own curve is not a power law either: one exponent has to
    // describe every adjacent pair, and the middle interval is the steepest.
    final List<double> pairwise = <double>[
      math.log(blurAt(1) / blurAt(2)) / math.log(2),
      math.log(blurAt(2) / blurAt(4)) / math.log(2),
    ];
    expect(pairwise[0], closeTo(0.83, 0.03));
    expect(pairwise[1], closeTo(1.94, 0.03));
    expect(
      pairwise[1] / pairwise[0],
      greaterThan(2.0),
      reason: 'one exponent describes both intervals, so the pass has no knee to report',
    );

    // The half that is not the blur, over four divisors now and all of it inside
    // D56's band. Flat to a divisor of 2 and rising after — which is the same
    // boundary the blur collapses across, and neither has a mechanism.
    expect(add('glass_d1_noblur') / floor, closeTo(0.763, 0.005));
    expect(add('glass_d2_noblur') / floor, closeTo(0.764, 0.005));
    expect(add('glass_d4_noblur') / floor, closeTo(0.903, 0.005));
    for (final int k in const <int>[1, 2, 4]) {
      final double share = add('glass_d${k}_noblur') / floor;
      expect(share, greaterThanOrEqualTo(0.73));
      expect(share, lessThanOrEqualTo(1.01));
    }

    // The number a budget should carry, which is not D140's headline: at the
    // divisor the policy picks on a dpr-2 screen the pass is under a quarter of
    // the addition, not three quarters.
    expect(blurAt(1) / add('glass_d1'), closeTo(0.709, 0.005));
    expect(blurAt(4) / add('glass_d4'), closeTo(0.232, 0.005));

    // Licensed by the ties. `glass_d2` reproduces the four-point run to a
    // ten-thousandth here, which is the tightest agreement any two runs on this
    // device have produced.
    final Map<String, Step> four = readLadder(ProxyResolution.metalRouteCostSource);
    expect(curve['glass_d2']!.frameMs / four['glass_d2']!.frameMs, closeTo(1.0, 0.001));
    expect(curve['plain']!.frameMs / four['plain']!.frameMs, closeTo(1.0, 0.005));
    expect(curve['glass_d4']!.frameMs / four['glass_d4']!.frameMs, closeTo(1.0, 0.015));
    // And the loosest one is quoted rather than hidden: the full-resolution
    // arms carried 16-24% spread in this run, and the pass's price there differs
    // between the two runs by 5.0%. That is the accuracy of any divisor-1
    // number here.
    expect((blurFull - blurAt(1)) / blurAt(1), closeTo(0.053, 0.01));
  });

  test('a pin is the host answering, and it answers where the chooser refuses', () {
    // The pin exists so the prediction above can be *taken*. The chooser will
    // never return a divisor of 2 — at dpr 2 `regular` fits inside the budget
    // all the way to 4 — so without this the third point is unreachable except
    // through the quality budget, which moves the retake ceiling with it (D131)
    // and would have made the new point differ along two axes.
    const ProxyCostModel metal = ProxyCostModel.frameCharged;
    final ProxyResolutionChoice pinned = ProxyResolutionPolicy.pin(
      const ProxyResolution.half(),
      finish: 'regularDark',
      devicePixelRatio: 2,
      costModel: metal,
    );
    expect(pinned.resolution, const ProxyResolution.half());
    expect(pinned.reason, ProxyDivisorReason.pinnedByHost);
    expect(
      ProxyResolutionPolicy.choose(
        finish: 'regularDark',
        finishSigmaLogical: 2.6,
        devicePixelRatio: 2,
        costModel: metal,
      ).resolution,
      const ProxyResolution.quarter(),
      reason: 'the pin would be indistinguishable from the choice',
    );

    // It still reads the tables rather than replacing them: the damage is the
    // one the ladder measured at that texel scale, and the route factor is the
    // one the device returned.
    expect(pinned.damage, isNotNull);
    expect(pinned.routeCostFactor!.measured, isTrue);
    expect(pinned.damage!.deltaE, ProxyResolution.damageAtTexelScale('regularDark', 1.0)!.deltaE);

    // And on hardware nobody measured the pin still answers — with a divisor
    // the chooser would not have returned there either, so the two can be
    // told apart. That is the case the benchmark runs in on Android, and it
    // is the difference between "the policy was overridden" and "the policy
    // was consulted twice". Until D136 this half of the arm used the pin to
    // reach a *quarter* on `unmeasured`, because the chooser refused it; now
    // the chooser returns the quarter itself, and the pin's job on that
    // family is the same as on Metal — the rung the walk skips.
    expect(
      ProxyResolutionPolicy.choose(
        finish: 'regularDark',
        finishSigmaLogical: 2.6,
        devicePixelRatio: 2,
        costModel: ProxyCostModel.unmeasured,
      ).resolution,
      const ProxyResolution.quarter(),
    );
    final ProxyResolutionChoice onUnknown = ProxyResolutionPolicy.pin(
      const ProxyResolution.full(),
      finish: 'regularDark',
      devicePixelRatio: 2,
      costModel: ProxyCostModel.unmeasured,
    );
    expect(onUnknown.resolution, const ProxyResolution.full());
    expect(onUnknown.reason, ProxyDivisorReason.pinnedByHost);
    // The price is still unknown — pinning a divisor does not price it. Only
    // the run does, which is the entire point of the knob.
    expect(onUnknown.routeCostFactor, isNull);
    expect(onUnknown.captureCostFactor, isNull);
  });

  test('a pin off the measured end reports no damage rather than a number', () {
    // The refusal the tables already have has to survive the override, or the
    // knob would turn "nobody graded this" into a plausible-looking ΔE. The
    // ladder measured 2, 4 and 8; at dpr 1 a divisor of 16 is a texel scale of
    // 1/16 and off the end of the curve in both directions of extrapolation.
    final ProxyResolutionChoice deep = ProxyResolutionPolicy.pin(
      const ProxyResolution.divisor(16),
      finish: 'regularDark',
      devicePixelRatio: 1,
      costModel: ProxyCostModel.frameCharged,
    );
    expect(deep.resolution.divisor, 16);
    expect(deep.damage, isNull);
    expect(deep.routeCostFactor, isNull);

    // Full resolution is the reference rather than a graded rung, so its damage
    // is null for a different reason and must not read as "off the end".
    expect(
      ProxyResolutionPolicy.pin(
        const ProxyResolution.full(),
        finish: 'regularDark',
        devicePixelRatio: 2,
        costModel: ProxyCostModel.frameCharged,
      ).damage,
      isNull,
    );
  });

  test('every divisor the chooser can return is one the quality table answers for', () {
    // This arm used to require the opposite half — that the divisor have a
    // measured *price* — and it passed for a year because on a dpr-2 screen the
    // priced ladder and the quality ladder happen to stop in the same place. It
    // was the derivation "no price, therefore no candidate" written down as a
    // test, and D137 measured the thing the derivation was about: at dpr 4 the
    // walk ran out one rung short of a **measured** quality point that the same
    // budget accepts. What the chooser owes its caller is a damage figure for
    // what it picked, because damage is the only quantity it decides on; the
    // price is reported, and at divisor 8 there is not one yet.
    for (final double dpr in const <double>[1, 2, 2.625, 3, 4]) {
      for (final String finish in ProxyResolution.measuredFinishes) {
        final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
          finish: finish,
          finishSigmaLogical: finish == 'clear' ? 0 : (finish == 'frosted' ? 8 : 2.6),
          devicePixelRatio: dpr,
          costModel: ProxyCostModel.areaCharged,
          damageBudgetDeltaE: 100,
        );
        expect(ProxyResolutionPolicy.candidateDivisors, contains(choice.resolution.divisor));
        expect(
          choice.damage,
          choice.resolution.divisor == 1 ? isNull : isNotNull,
          reason: 'the chooser spent a budget on a rung it has no damage figure for',
        );
      }
    }
  });

  test('the ladder reaches the rung a dense screen needs, and moves nothing below it', () {
    // The four densities, at the shipping budget, with the two that must not
    // move stated as their own expectations rather than left implied. dpr 1 and
    // 2 are unchanged *by construction*: the rung past their answer is off the
    // budget (0.25 texels costs 0.372 against 0.348), not off the list — so
    // lengthening the list cannot have moved them, and if it did, the stop
    // condition is not the one this claims.
    const List<(double, int, double)> expected = <(double, int, double)>[
      (1, 2, 0.5),
      (2, 4, 0.5),
      (3, 8, 0.375),
      (4, 8, 0.5),
    ];
    for (final (double dpr, int divisor, double texels) in expected) {
      final ProxyResolutionChoice choice = ProxyResolutionPolicy.choose(
        finish: 'regularDark',
        finishSigmaLogical: 2.6,
        devicePixelRatio: dpr,
        costModel: ProxyCostModel.unmeasured,
      );
      expect(choice.resolution.divisor, divisor, reason: 'dpr $dpr');
      expect(choice.resolution.ratioFor(dpr), closeTo(texels, 1e-9), reason: 'dpr $dpr');
      expect(
        choice.damage!.deltaE,
        lessThanOrEqualTo(ProxyResolutionPolicy.defaultDamageBudgetDeltaE),
      );
    }

    // The claim underneath the table: dpr 2 and dpr 4 land on **one working
    // point wearing two divisors**, so their damage has to be the same number
    // and not merely a similar one. Asserted as equality between the two
    // readings rather than against a literal, because a literal would pass on a
    // chooser that was keyed by the knob and happened to agree to three digits.
    final List<ProxyResolutionChoice> dense = <double>[2, 4]
        .map(
          (double dpr) => ProxyResolutionPolicy.choose(
            finish: 'regularDark',
            finishSigmaLogical: 2.6,
            devicePixelRatio: dpr,
            costModel: ProxyCostModel.unmeasured,
          ),
        )
        .toList();
    expect(dense[0].damage!.deltaE, dense[1].damage!.deltaE);
    expect(dense[0].resolution.divisor, isNot(dense[1].resolution.divisor));
    for (final ProxyResolutionChoice choice in dense) {
      expect(choice.damage!.measured, isTrue, reason: 'picked an interpolated rung');
    }

    // dpr 3 is the one row spending the budget against a bound, and it says so.
    final ProxyResolutionChoice three = ProxyResolutionPolicy.choose(
      finish: 'regularDark',
      finishSigmaLogical: 2.6,
      devicePixelRatio: 3,
      costModel: ProxyCostModel.unmeasured,
    );
    expect(three.damage!.measured, isFalse);
    expect(three.resolution.divisor, 8);
    // Adreno priced the capture at three divisors and never the eighth, so the
    // capture column is still a refusal here.
    expect(three.resolution.captureCostFactor(ProxyCostModel.areaCharged), isNull);
    // The route column stopped being one on 2026-09-09 (D139), and what it
    // reports is worth reading rather than only having: 0.4258 against the
    // quarter's 0.4439 is a saving of 4% of the addition, at the deepest rung
    // the quality ladder has. Measured at dpr 2, so at a texel scale of 0.25 —
    // and this row is dpr 3, where a divisor of 8 is 0.375 and therefore still
    // on the falling side of the knee. That is the whole reason the ladder
    // reaching 8 is not a defect: the price is keyed by texel scale, not by the
    // knob (D120), and the two coincide only at dpr 2.
    expect(
      three.resolution.routeCostFactor(ProxyCostModel.frameCharged)!.factor,
      closeTo(0.4258, 0.0005),
    );
  });

  // -------------------------------------------------------------------------
  // 5. The family no model fits, and exactly what its two runs license.
  // -------------------------------------------------------------------------

  test(
    'on unmeasured hardware the lever\'s sign is measured on two seeds, and its size is not',
    () {
      // The whole licence for walking the divisor ladder on `unmeasured` is two
      // runs of one scene on one Xclipse, and this arm reads them rather than
      // restating them: what the host declared (nothing), what was pinned, what
      // the counters say ran, and what the wall clock read. Every one of those
      // is a way the number could have meant something else — a declared
      // family, a held proxy, a pin the recorder ignored — and each has cost a
      // wrong reading somewhere in this repository already.
      expect(
        ProxyResolution.xclipseRouteSources,
        hasLength(2),
        reason: 'one shuffle is not an effect',
      );
      expect(ProxyResolution.xclipseRouteSources.keys.toSet(), hasLength(2));
      for (final MapEntry<int, String> entry in ProxyResolution.xclipseRouteSources.entries) {
        final WallLadder ladder = readWallLadder(entry.value, seed: entry.key);
        final WallStep full = ladder.steps['glass_d1']!;
        final WallStep quarter = ladder.steps['glass_d4']!;
        final WallStep floor = ladder.steps['plain']!;

        // The host said nothing — the case the default is for — and the divisor
        // that ran is the one that was pinned, by the recorder's own counter.
        for (final WallStep step in <WallStep>[full, quarter]) {
          expect(
            step.hardware,
            'detect',
            reason: 'seed ${entry.key}: a declared family is not the default',
          );
          expect(
            step.generations,
            greaterThan(1000),
            reason: 'seed ${entry.key}: a held proxy is not the route',
          );
        }
        expect(full.pinned, '1');
        expect(full.divisor, 1);
        expect(quarter.pinned, '4');
        expect(quarter.divisor, 4);
        expect(floor.divisor, 0, reason: 'the floor has no proxy');

        // The floor holds vsync, so its frame time is the display's period and
        // the two glass arms are read against a real floor.
        expect(floor.fps, greaterThan(0.98 * ladder.hz));

        // The sign. Full resolution is off vsync by a factor of two or more;
        // the quarter is within 6% of the display.
        expect(full.fps, lessThan(55), reason: 'seed ${entry.key}');
        expect(quarter.fps, greaterThan(0.93 * ladder.hz), reason: 'seed ${entry.key}');
        expect(quarter.fps / full.fps, greaterThan(2.0), reason: 'seed ${entry.key}');

        // And the size refuses. The two-term decomposition `A·f + C` over these
        // two points returns a negative `C` on both seeds, because the quarter
        // arm sits within 4% of a floor that vsync pins from below — which is why
        // `routeCostFactor` is still null here rather than a number read off the
        // same runs. If a run ever makes `C` positive, this arm is what says the
        // refusal can be lifted.
        final double addFull = full.ms - floor.ms;
        final double addQuarter = quarter.ms - floor.ms;
        final double a = (addFull - addQuarter) / (1 - 1 / 16);
        final double c = addFull - a;
        expect(c, lessThan(0), reason: 'seed ${entry.key}: the decomposition stopped refusing');
        expect(
          addFull / addQuarter,
          greaterThan(15),
          reason: 'seed ${entry.key}: the write is charged by area',
        );
      }
      for (final int divisor in const <int>[1, 2, 4]) {
        expect(ProxyResolution.divisor(divisor).routeCostFactor(ProxyCostModel.unmeasured), isNull);
        expect(
          ProxyResolution.divisor(divisor).captureCostFactor(ProxyCostModel.unmeasured),
          isNull,
        );
      }
    },
  );

  test('a silent host lands on the pinned quarter, not on the pinned full resolution', () {
    // The arm the whole change was measured by, read back from the run that
    // took it. The two pinned arms are the ends the default could land on,
    // in the same binary under the same shuffle — so if the policy had still
    // returned full resolution on `unmeasured`, the `glass` row would sit
    // beside `glass_d1` at 39 fps and this arm would say so.
    final WallLadder ladder = readWallLadder(ProxyResolution.xclipseDefaultSource, seed: 20260910);
    final WallStep silent = ladder.steps['glass']!;
    final WallStep quarter = ladder.steps['glass_d4']!;
    final WallStep full = ladder.steps['glass_d1']!;
    final WallStep floor = ladder.steps['plain']!;

    expect(silent.hardware, 'detect', reason: 'the host declared something');
    expect(silent.pinned, 'policy', reason: 'the host pinned the divisor');
    expect(silent.divisor, 4, reason: 'the policy did not choose a quarter on unmeasured hardware');
    expect(silent.generations, greaterThan(1000), reason: 'the proxy was held, not recorded');

    // On the display's period, beside the pinned quarter and the floor — and
    // the ends it did not land on are three times slower in the same run.
    expect(silent.fps, greaterThan(0.98 * ladder.hz));
    expect(quarter.fps, greaterThan(0.98 * ladder.hz));
    expect((silent.ms - quarter.ms).abs() / floor.ms, lessThan(0.01));
    expect((silent.ms - floor.ms).abs() / floor.ms, lessThan(0.01));
    expect(full.fps, lessThan(45));
    expect(full.ms / silent.ms, greaterThan(2.9));
  });

  test(
    'the budget stays at 1%: one stale frame is worth 2% of a frame and costs 27% more budget',
    () {
      // The second lever the problem statement named, priced on the same runs
      // and declined. On `bank_home` at a quarter the recording adds 0.34 and
      // 0.51 ms to an 8.36 ms frame on the two seeds — 4…6% — and a ceiling of
      // one stale frame can at most halve that, because the oracle would then
      // record every other frame on a scene whose content moves every frame.
      // Buying it means admitting `regular` one frame behind on top of the
      // quarter it already spends: 0.384 composed with 0.221 is 0.443 ΔE, 27%
      // over the 1% budget. And the same 27% moves `thinLight` from a half to a
      // quarter (0.443 < 0.452) as a side effect nobody asked for.
      const double budget = ProxyResolutionPolicy.defaultDamageBudgetDeltaE;
      const double quarter = 0.221;
      const double oneFrame = 0.384;
      final double composed = math.sqrt(quarter * quarter + oneFrame * oneFrame);
      final double needed = composed / ProxyResolution.kMaterialScaleDeltaE;
      expect(needed, closeTo(0.0127, 0.0002));
      expect(composed / budget, closeTo(1.27, 0.01));

      var worstShare = 0.0;
      for (final MapEntry<int, String> entry in ProxyResolution.xclipseRouteSources.entries) {
        final WallLadder ladder = readWallLadder(entry.value, seed: entry.key);
        final double share = (ladder.steps['glass_d4']!.ms - ladder.steps['plain']!.ms) / ladder.steps['plain']!.ms;
        expect(
          share,
          lessThan(0.07),
          reason: 'seed ${entry.key}: the quarter arm costs more than 7% of a frame',
        );
        if (share > worstShare) {
          worstShare = share;
        }
      }
      // Half of the worst case is what the whole second lever can return at this
      // working point, and it is under 3.1% of a frame.
      expect(worstShare / 2, lessThan(0.031));

      // The side effect, as the chooser sees it.
      ProxyResolution at(String finish, double budgetDeltaE) => ProxyResolutionPolicy.choose(
        finish: finish,
        finishSigmaLogical: 2.6,
        devicePixelRatio: 2,
        costModel: ProxyCostModel.unmeasured,
        damageBudgetDeltaE: budgetDeltaE,
      ).resolution;
      expect(at('thinLight', budget), const ProxyResolution.half());
      expect(at('thinLight', composed), const ProxyResolution.quarter());
      expect(at('regularDark', budget), const ProxyResolution.quarter());
    },
  );
}

/// One arm of a wall-clock digest.
typedef WallStep = ({
  double ms,
  double fps,
  double spread,
  String? hardware,
  String? pinned,
  int divisor,
  int generations,
});

/// A wall-clock digest of one `bank_home` ladder on the Xclipse phone.
class WallLadder {
  WallLadder(this.steps, {required this.hz, required this.caveats});

  final Map<String, WallStep> steps;
  final double hz;
  final List<String> caveats;
}

/// Reads a wall-clock digest and refuses one that is not the run it claims to
/// be: the metric, the seed, the window and the caveats are all checked,
/// because a digest that carries a `THROTTLED` line for the arms being read is
/// a number and not a measurement.
WallLadder readWallLadder(String path, {required int seed}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('the digest a decision came from is gone: $path');
  }
  final report = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  expect(report['metric'], 'micros_per_frame');
  final config = report['config']! as Map<String, Object?>;
  expect(config['shuffle_seed'], seed, reason: '$path is not the seed it is filed under');
  expect(config['measure_ms'], 30000, reason: 'a smoke window is not a measurement');
  expect(config['repeats'], 3);
  final environment = report['environment']! as Map<String, Object?>;
  expect(environment['device_pixel_ratio'], 2.0);
  final caveats = <String>[
    for (final Object? c in report['caveats']! as List<Object?>) c! as String,
  ];
  for (final String caveat in caveats) {
    for (final String arm in const <String>['glass_d1', 'glass_d4', 'plain']) {
      if (caveat.startsWith('THROTTLED') && caveat.contains('bank_home.$arm ')) {
        fail('$path: $arm ran throttled — $caveat');
      }
    }
  }
  final steps = <String, WallStep>{};
  for (final Object? c in report['cells']! as List<Object?>) {
    final cell = c! as Map<String, Object?>;
    final axes = cell['axes']! as Map<String, Object?>;
    final counters = cell['counters']! as Map<String, Object?>;
    steps[cell['variant']! as String] = (
      ms: (cell['micros_per_frame']! as num).toDouble() / 1000,
      fps: (cell['frames_per_second']! as num).toDouble(),
      spread: (cell['spread']! as num).toDouble(),
      hardware: axes['glass_hardware'] as String?,
      pinned: axes['glass_pinned_divisor'] as String?,
      divisor: ((counters['glass_proxy_divisor'] ?? 0) as num).toInt(),
      generations: ((counters['glass_proxy_generations'] ?? 0) as num).toInt(),
    );
  }
  return WallLadder(
    steps,
    hz: (environment['display_refresh_rate_hz']! as num).toDouble(),
    caveats: caveats,
  );
}
