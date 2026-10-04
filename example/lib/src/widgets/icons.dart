import 'package:flutter/material.dart';

/// The icons the catalog names, which is plain Dart and cannot hold an
/// [IconData] itself. Kept as one const map so the icon font is still
/// tree-shaken to the glyphs named here.
const Map<String, IconData> _kIcons = <String, IconData>{
  'rocket_launch': Icons.rocket_launch_outlined,
  'download': Icons.download_outlined,
  'lightbulb': Icons.lightbulb_outline,
  'devices': Icons.devices_outlined,
  'layers': Icons.layers_outlined,
  'crop_square': Icons.crop_square,
  'opacity': Icons.opacity,
  'contrast': Icons.contrast,
  'stairs': Icons.stairs_outlined,
  'waves': Icons.waves,
  'bubble_chart': Icons.bubble_chart_outlined,
  'open_with': Icons.open_with,
  'vertical_align_top': Icons.vertical_align_top,
  'insights': Icons.insights_outlined,
  'palette': Icons.palette_outlined,
  'thermostat': Icons.thermostat_outlined,
  'memory': Icons.memory_outlined,
  'smart_button': Icons.smart_button_outlined,
  'crop_7_5': Icons.crop_7_5,
  'web_asset': Icons.web_asset,
  'toggle_on': Icons.toggle_on_outlined,
  'tune': Icons.tune,
  'view_week': Icons.view_week_outlined,
  'tab': Icons.tab_outlined,
  'search': Icons.search,
  'build': Icons.build_outlined,
  'warning': Icons.warning_amber_outlined,
  'vertical_split': Icons.vertical_split_outlined,
  'menu_open': Icons.menu_open,
  'chat_bubble': Icons.chat_bubble_outline,
  'animation': Icons.animation,
  'view_agenda': Icons.view_agenda_outlined,
  'photo': Icons.photo_outlined,
  'widgets': Icons.widgets_outlined,
  'arrow_upward': Icons.arrow_upward,
  'speed': Icons.speed_outlined,
  'visibility': Icons.visibility_outlined,
};

/// The icon named [name], or a neutral one for a name the map lacks.
IconData iconFor(String name) => _kIcons[name] ?? Icons.blur_on;

/// The names [iconFor] knows; the catalog's test checks every page uses one.
Iterable<String> get knownIconNames => _kIcons.keys;
