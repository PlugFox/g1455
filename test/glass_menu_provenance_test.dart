// The menu's constants against the run they came from.
//
// `flutter test test/glass_menu_provenance_test.dart`
//
// `provenance/menu/views.txt` is `ComponentReference`'s dump of iOS 26.5's
// `UIMenu` open from a button, a line per view with its frame in points. The
// width and the row height are read off it here, so that a constant edited
// in `lib/` without a new run fails rather than drifting from its source.
// The corner (31.5) was fitted on `top_open.png` by eye and is checked by
// nothing here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

void main() {
  test('the menu is as wide, and its rows as tall, as the dump says', () {
    final List<String> lines = File('provenance/menu/views.txt').readAsLinesSync();
    final frame = RegExp(r'\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}');
    ({double w, double h}) sizeOf(String line) {
      final RegExpMatch m = frame.firstMatch(line)!;
      return (w: double.parse(m.group(3)!), h: double.parse(m.group(4)!));
    }

    final menus = <({double w, double h})>[
      for (final String l in lines)
        if (l.contains(' _UIContextMenuView ')) sizeOf(l),
    ];
    final cells = <({double w, double h})>[
      for (final String l in lines)
        if (l.contains(' _UIContextMenuCell ')) sizeOf(l),
    ];
    expect(menus, isNotEmpty, reason: 'the dump has no menu: the wrong run');
    expect(cells, isNotEmpty);
    for (final ({double w, double h}) m in menus) {
      expect(m.w, kGlassMenuWidth);
      // Three rows and 10 pt above and below them.
      expect(m.h, 3 * kGlassMenuRowHeight + 20);
    }
    for (final ({double w, double h}) c in cells) {
      expect(c.h, kGlassMenuRowHeight);
    }
  });
}
