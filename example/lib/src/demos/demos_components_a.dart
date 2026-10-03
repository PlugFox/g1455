import 'bar_demo.dart';
import 'button_demo.dart';
import 'card_demo.dart';
import 'demos.dart';
import 'segmented_control_demo.dart';
import 'slider_demo.dart';
import 'switch_demo.dart';
import 'tab_bar_demo.dart';

/// The live demos of the pages in `catalog/entries/components_a.dart`, by page id.
final Map<String, DemoBuilder> kDemosComponentsA = <String, DemoBuilder>{
  'bar': () => const BarDemo(),
  'button': () => const ButtonDemo(),
  'card': () => const CardDemo(),
  'switch': () => const SwitchDemo(),
  'slider': () => const SliderDemo(),
  'segmented-control': () => const SegmentedControlDemo(),
  'tab-bar': () => const TabBarDemo(),
};
