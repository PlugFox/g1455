// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455_example/src/widgets/doc_view.dart';

void main() {
  // flutter_md sets code in Menlo on iOS and macOS and Consolas on Windows
  // unless the theme names a family; the site names its bundled face, which
  // the pubspec registers as `monospace`, so code looks alike everywhere.
  testWidgets('the site sets code in its bundled monospace face on every platform', (WidgetTester tester) async {
    late MarkdownThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            theme = siteMarkdownTheme(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(theme.monospaceFontFamily, 'monospace');
  }, variant: TargetPlatformVariant.all());

  group('unwrapMarkdown', () {
    test('joins a paragraph wrapped in the source into one line', () {
      expect(unwrapMarkdown('One line\nand the next,\nand a third.'), 'One line and the next, and a third.');
    });

    test('keeps blocks apart: headings, items, quotes, tables, fences, blank lines', () {
      const String source = '''
## Heading
A paragraph
that wraps.

- an item
  that wraps
- another item
1. a numbered one

> [!NOTE]
> A note
> that wraps.

| a | b |
|---|---|
| 1 | 2 |

```dart
final a = 1;
final b = 2;
```''';
      expect(unwrapMarkdown(source), '''
## Heading
A paragraph that wraps.

- an item that wraps
- another item
1. a numbered one

> [!NOTE]
> A note that wraps.

| a | b |
|---|---|
| 1 | 2 |

```dart
final a = 1;
final b = 2;
```''');
    });

    test('takes the backticks off a link\'s text, which flutter_md would draw', () {
      expect(unwrapMarkdown('See [`GlassHost`](/foundations/host).'), 'See [GlassHost](/foundations/host).');
      expect(unwrapMarkdown('Code `a` and [a link](/x).'), 'Code `a` and [a link](/x).');
    });

    test('keeps a hard break', () {
      expect(unwrapMarkdown('One line  \nthe next'), 'One line  \nthe next');
      expect(unwrapMarkdown('One line\\\\\nthe next'), 'One line\\\\\nthe next');
    });
  });
}
