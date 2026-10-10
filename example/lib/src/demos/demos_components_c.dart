import 'badge_demo.dart';
import 'demos.dart';
import 'page_control_demo.dart';
import 'search_bar_demo.dart';
import 'stepper_demo.dart';

/// The live demos of the pages in `catalog/entries/components_c.dart`, by page id.
final Map<String, DemoBuilder> kDemosComponentsC = <String, DemoBuilder>{
  'stepper': () => const StepperDemo(),
  'page-control': () => const PageControlDemo(),
  'search-bar': () => const SearchBarDemo(),
  'badge': () => const BadgeDemo(),
};
