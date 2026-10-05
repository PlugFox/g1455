// The agent skill's references: one markdown file per page of the site, from
// the catalog the site draws, into `skills/g1455/references/`.
//
//   dart run tool/skill.dart
//
// `SKILL.md` itself is written by hand; what it points to is generated, so a
// guide changed in the catalog is changed for agents too. The files are
// committed, because `npx skills add` and Claude Code's marketplace read the
// repository, not a build; `test/skill_test.dart` fails when they are stale.

import 'dart:io';

import 'package:g1455_example/src/catalog/markdown.dart';

// ignore_for_file: avoid_print

void main() {
  final Directory references = Directory('../skills/g1455/references');
  if (references.existsSync()) {
    references.deleteSync(recursive: true);
  }
  for (final MapEntry<String, String> file in skillReferences().entries) {
    final f = File('${references.path}/${file.key}')..createSync(recursive: true);
    f.writeAsStringSync(file.value);
    print('${f.path}  ${file.value.length} B');
  }
}
