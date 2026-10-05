// The agent skill in `skills/g1455/`: its references are what the catalog
// says today, and every link it holds goes somewhere.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:g1455_example/src/catalog/catalog.dart';
import 'package:g1455_example/src/catalog/markdown.dart';

const String _root = '../skills/g1455';

/// The links of a markdown file that point at another file of the skill.
Iterable<String> _localLinks(String markdown) => RegExp(
  r'\]\(([^)\s#]+\.md)(?:#[^)]*)?\)',
).allMatches(markdown).map((Match m) => m.group(1)!).where((String l) => !l.contains('://'));

void main() {
  final String skill = File('$_root/SKILL.md').readAsStringSync();

  test('the references are the catalog as it is: run `dart run tool/skill.dart`', () {
    final Map<String, String> expected = skillReferences();
    final references = Directory('$_root/references');
    final Set<String> found = <String>{
      for (final FileSystemEntity f in references.listSync(recursive: true))
        if (f is File) f.path.substring(references.path.length + 1).replaceAll(r'\', '/'),
    };
    expect(found, expected.keys.toSet());
    for (final MapEntry<String, String> e in expected.entries) {
      expect(File('${references.path}/${e.key}').readAsStringSync(), e.value, reason: e.key);
    }
  });

  test('the front matter follows the Agent Skills spec', () {
    final Match? front = RegExp(r'^---\n([\s\S]*?)\n---\n').firstMatch(skill);
    expect(front, isNotNull);
    final String yaml = front!.group(1)!;
    expect(RegExp(r'^name: g1455$', multiLine: true).hasMatch(yaml), isTrue, reason: 'the name is the folder');
    final String description = RegExp(
      r'^description: >-\n((?:  .*\n?)+)',
      multiLine: true,
    ).firstMatch(yaml)!.group(1)!.split('\n').map((String l) => l.trim()).where((String l) => l.isNotEmpty).join(' ');
    expect(description.length, inInclusiveRange(1, 1024));
    expect(skill.split('\n').length, lessThan(500), reason: 'the body an agent loads whole');
  });

  test('the skill names the package version it describes', () {
    final List<String> v = Site.version.split('.');
    expect(skill, contains('version: ${v[0]}.${v[1]}.x'), reason: 'a new minor version: review SKILL.md');
  });

  test('SKILL.md links every reference, and every link resolves', () {
    final Set<String> linked = _localLinks(skill).toSet();
    for (final String path in skillReferences().keys) {
      expect(linked, contains('references/$path'), reason: 'SKILL.md does not link $path');
    }
    for (final String l in linked) {
      expect(File('$_root/$l').existsSync(), isTrue, reason: 'SKILL.md links $l');
    }
    for (final MapEntry<String, String> e in skillReferences().entries) {
      final String dir = File('$_root/references/${e.key}').parent.path;
      for (final String l in _localLinks(e.value)) {
        expect(File('$dir/$l').existsSync(), isTrue, reason: '${e.key} links $l');
      }
    }
  });
}
