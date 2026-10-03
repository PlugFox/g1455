import 'alert_demo.dart';
import 'demos.dart';
import 'menu_demo.dart';
import 'popover_demo.dart';
import 'sheet_demo.dart';
import 'text_field_demo.dart';
import 'toolbar_demo.dart';

/// The live demos of the pages in `catalog/entries/components_b.dart`, by page id.
final Map<String, DemoBuilder> kDemosComponentsB = <String, DemoBuilder>{
  'text-field': () => const TextFieldDemo(),
  'toolbar': () => const ToolbarDemo(),
  'alert': () => const AlertDemo(),
  'sheet': () => const SheetDemo(),
  'menu': () => const MenuDemo(),
  'popover': () => const PopoverDemo(),
};
