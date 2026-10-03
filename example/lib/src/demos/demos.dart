import 'package:flutter/widgets.dart';

import '../catalog/catalog.dart';
import 'demos_components_a.dart';
import 'demos_components_b.dart';
import 'demos_foundations_a.dart';
import 'demos_foundations_b.dart';
import 'demos_start.dart';

/// Builds a page's live demo: `() => const SwitchDemo()`.
typedef DemoBuilder = Widget Function();

/// Every live demo, by page id.
final Map<String, DemoBuilder> _kDemos = <String, DemoBuilder>{
  ...kDemosStart,
  ...kDemosFoundationsA,
  ...kDemosFoundationsB,
  ...kDemosComponentsA,
  ...kDemosComponentsB,
};

/// The live demo of [entry]'s page, or null for a page without one.
Widget? demoFor(Entry entry) => entry.section == Section.demos ? null : _kDemos[entry.id]?.call();

/// Whether [entry]'s page has a live demo.
bool hasDemo(Entry entry) => entry.section != Section.demos && _kDemos.containsKey(entry.id);
