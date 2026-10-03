import 'above_demo.dart';
import 'demos.dart';
import 'groups_demo.dart';
import 'performance_demo.dart';
import 'ripple_demo.dart';
import 'scroll_edge_demo.dart';
import 'travel_demo.dart';

/// The live demos of the pages in `catalog/entries/foundations_b.dart`, by page id.
final Map<String, DemoBuilder> kDemosFoundationsB = <String, DemoBuilder>{
  'ripple': () => const RippleDemo(),
  'groups': () => const GroupsDemo(),
  'travel': () => const TravelDemo(),
  'above': () => const AboveDemo(),
  'scroll-edge': () => const ScrollEdgeDemo(),
  'performance': () => const PerformanceDemo(),
};
