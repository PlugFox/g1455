// The label-contrast floor over a declared flat backdrop.
//
// `flutter test test/glass_theme_flat_floor_test.dart`
//
// `glass_legibility_test.dart` covers the floor where the theme knows nothing
// about the backdrop and has to meet it against the worst level the finish can
// land on. A screen that declares one flat colour takes another route: the dim
// is solved against that one level, which needs less of it. This file pins that
// route as a sweep, because its failure is a contrast that is met on some
// backdrops and silently not on others:
//
//  1. **Met where meetable.** Over every grey and every stock finish, the label
//     the theme hands out reaches the floor against the fill it is drawn on —
//     the fill as stored, a code value at a time, which is what the eye gets.
//  2. **No more dim than needed.** A dim a little smaller would miss the floor,
//     so the solver is not just returning "everything".
//  3. **Approached where not meetable.** A floor nobody can reach is still
//     approached with the most dim there is, not ignored.

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

const List<GlassFinish> _finishes = <GlassFinish>[
  GlassFinish.regularDark,
  GlassFinish.regularLight,
  GlassFinish.frosted,
  GlassFinish.clear,
];

/// What the screen stores: every channel rounded to a code value.
Color _stored(Color c) => Color.from(
  alpha: 1,
  red: (c.r * 255).roundToDouble() / 255,
  green: (c.g * 255).roundToDouble() / 255,
  blue: (c.b * 255).roundToDouble() / 255,
);

/// The dim that turns [base]'s tint alpha into [drawn]'s: inverts
/// `a2 = 1 - (1 - a)(1 - dim)`.
double _dimBetween(GlassFinish base, GlassFinish drawn) => 1 - (1 - drawn.tint.a) / (1 - base.tint.a);

void main() {
  test('over every flat grey, the floor is met where a dim can meet it, with the least dim that does', () {
    var dimmed = 0;
    var undimmed = 0;
    for (final double floor in <double>[3, 4.5, 7]) {
      for (final GlassFinish finish in _finishes) {
        for (var code = 0; code <= 255; code += 15) {
          final Color backdrop = Color.fromARGB(255, code, code, code);
          final theme = GlassThemeData(finish: finish, backdrop: backdrop, minLabelContrast: floor);
          final GlassLegibility l = theme.legibility();
          final String where = '${finish.name} over grey $code at $floor';
          final double reached = GlassFinish.contrastRatio(_stored(l.finish.opaqueFillOver(backdrop)), l.label);
          final double best = math.max(
            GlassFinish.contrastRatio(_stored(finish.dimmed(1).opaqueFillOver(backdrop)), const Color(0xFFFFFFFF)),
            GlassFinish.contrastRatio(finish.opaqueFillOver(backdrop), l.label),
          );
          if (best < floor) {
            continue;
          }
          expect(reached, greaterThanOrEqualTo(floor - 1e-9), reason: '$where: reached $reached');
          if (identical(l.finish, finish) || l.finish == finish) {
            undimmed++;
            continue;
          }
          dimmed++;
          // Least: a dim 2% smaller than the one chosen falls short with a
          // white label, which is the label a dimmed finish hands out.
          final double dim = _dimBetween(finish, l.finish);
          expect(dim, inInclusiveRange(0, 1), reason: where);
          expect(l.label, const Color(0xFFFFFFFF), reason: '$where: a dimmed finish handed out a dark label');
          final double less = math.max(0, dim - 0.02);
          expect(
            GlassFinish.contrastRatio(_stored(finish.dimmed(less).opaqueFillOver(backdrop)), const Color(0xFFFFFFFF)),
            lessThan(floor),
            reason: '$where: dim $dim is more than the floor needs',
          );
        }
      }
    }
    // The sweep has to have exercised both branches, or half of it proved
    // nothing.
    expect(dimmed, greaterThan(10));
    expect(undimmed, greaterThan(10));
  });

  test('a floor no dim can reach is approached with the whole dim, not ignored', () {
    const Color backdrop = Color(0xFFFFFFFF);
    final GlassLegibility l = const GlassThemeData(
      finish: GlassFinish.clear,
      backdrop: backdrop,
      minLabelContrast: 21,
    ).legibility();
    expect(l.finish == GlassFinish.clear, isFalse, reason: 'an unreachable floor left the finish alone');
    expect(_dimBetween(GlassFinish.clear, l.finish), closeTo(1, 1e-9));
  });

  test('a rich backdrop takes the worst-case route even with a flat colour declared', () {
    const Color backdrop = Color(0xFF808080);
    final GlassLegibility flat = const GlassThemeData(
      finish: GlassFinish.clear,
      backdrop: backdrop,
      minLabelContrast: 4.5,
    ).legibility();
    final GlassLegibility rich = const GlassThemeData(
      finish: GlassFinish.clear,
      backdrop: backdrop,
      richBackdrop: true,
      minLabelContrast: 4.5,
    ).legibility();
    // The worst case has to hold against every level the finish can land on,
    // so it can never need less dim than one known level does.
    expect(rich.finish.tint.a, greaterThanOrEqualTo(flat.finish.tint.a));
    expect(rich.finish.worstContrast(rich.label), greaterThanOrEqualTo(4.5 - 1e-9));
  });

  test('glass that carries no label keeps its finish whatever the floor', () {
    // Grey 0x77 is where neither black (4.7) nor white (4.5) reaches 7, so a
    // labelled glass has to dim and the unlabelled one's refusal is visible.
    const theme = GlassThemeData(finish: GlassFinish.clear, backdrop: Color(0xFF777777), minLabelContrast: 7);
    expect(theme.legibility(null, false).finish, GlassFinish.clear);
    expect(theme.legibility().finish == GlassFinish.clear, isFalse, reason: 'the control: labelled, it dims');
  });
}
