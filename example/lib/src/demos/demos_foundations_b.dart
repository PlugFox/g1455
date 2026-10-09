import 'above_demo.dart';
import 'backdrop_demo.dart';
import 'capture_demo.dart';
import 'demos.dart';
import 'drop_motion_demo.dart';
import 'groups_demo.dart';
import 'performance_demo.dart';
import 'ripple_demo.dart';
import 'scroll_edge_demo.dart';
import 'travel_demo.dart';

/// The live demos of the pages in `catalog/entries/foundations_b.dart`, by page id.
final Map<String, DemoBuilder> kDemosFoundationsB = <String, DemoBuilder>{
  'ripple': () => const RippleDemo(),
  'drop-motion': () => const DropMotionDemo(),
  'groups': () => const GroupsDemo(),
  'travel': () => const TravelDemo(),
  'above': () => const AboveDemo(),
  'capture': () => const CaptureDemo(),
  'backdrop': () => const BackdropDemo(),
  'scroll-edge': () => const ScrollEdgeDemo(),
  'performance': () => const PerformanceDemo(),
};
