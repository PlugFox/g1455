import 'demos.dart';
import 'finishes_demo.dart';
import 'host_demo.dart';
import 'legibility_demo.dart';
import 'surface_demo.dart';
import 'tiers_demo.dart';

/// The live demos of the pages in `catalog/entries/foundations_a.dart`, by page id.
final Map<String, DemoBuilder> kDemosFoundationsA = <String, DemoBuilder>{
  'host': () => const HostDemo(),
  'surface': () => const SurfaceDemo(),
  'finishes': () => const FinishesDemo(),
  'legibility': () => const LegibilityDemo(),
  'tiers': () => const TiersDemo(),
};
