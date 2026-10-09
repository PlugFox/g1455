import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

/// The icons the catalog names, which is plain Dart and cannot hold an
/// [IconData] itself. Kept as one const map so the icon font is still
/// tree-shaken to the glyphs named here.
const Map<String, IconData> _kIcons = <String, IconData>{
  'rocket_launch': SFIcons.sf_paperplane,
  'download': SFIcons.sf_arrow_down_circle,
  'lightbulb': SFIcons.sf_lightbulb,
  'devices': SFIcons.sf_laptopcomputer,
  'layers': SFIcons.sf_square_3_layers_3d,
  'crop_square': SFIcons.sf_square,
  'opacity': SFIcons.sf_drop_halffull,
  'contrast': SFIcons.sf_circle_righthalf_filled,
  'stairs': SFIcons.sf_stairs,
  'waves': SFIcons.sf_water_waves,
  'bubble_chart': SFIcons.sf_circle_grid_3x3,
  'open_with': SFIcons.sf_arrow_up_and_down_and_arrow_left_and_right,
  'vertical_align_top': SFIcons.sf_arrow_up_to_line,
  'insights': SFIcons.sf_chart_line_uptrend_xyaxis,
  'palette': SFIcons.sf_paintpalette,
  'thermostat': SFIcons.sf_thermometer_medium,
  'memory': SFIcons.sf_cpu,
  'smart_button': SFIcons.sf_capsule,
  'crop_7_5': SFIcons.sf_rectangle,
  'web_asset': SFIcons.sf_macwindow,
  'toggle_on': SFIcons.sf_switch_2,
  'tune': SFIcons.sf_slider_horizontal_3,
  'view_week': SFIcons.sf_rectangle_split_3x1,
  'tab': SFIcons.sf_menubar_dock_rectangle,
  'search': SFIcons.sf_magnifyingglass,
  'build': SFIcons.sf_wrench_and_screwdriver,
  'warning': SFIcons.sf_exclamationmark_triangle,
  'vertical_split': SFIcons.sf_rectangle_split_2x1,
  'menu_open': SFIcons.sf_sidebar_left,
  'chat_bubble': SFIcons.sf_bubble_left,
  'animation': SFIcons.sf_wand_and_sparkles,
  'view_agenda': SFIcons.sf_rectangle_grid_1x2,
  'photo': SFIcons.sf_photo,
  'widgets': SFIcons.sf_square_grid_2x2,
  'arrow_upward': SFIcons.sf_arrow_up,
  'speed': SFIcons.sf_gauge_with_dots_needle_67percent,
  'visibility': SFIcons.sf_eye,
  'brightness_6': SFIcons.sf_circle_lefthalf_filled,
  'water_drop': SFIcons.sf_drop,
  'space_dashboard': SFIcons.sf_rectangle_3_group,
  'capture': SFIcons.sf_camera_viewfinder,
  'wallpaper': SFIcons.sf_photo_artframe,
  'auto_awesome': SFIcons.sf_sparkles,
  'healing': SFIcons.sf_bandage,
  'exposure': SFIcons.sf_plusminus,
  'more_horiz': SFIcons.sf_ellipsis,
  'manage_search': SFIcons.sf_text_magnifyingglass,
  'notifications': SFIcons.sf_app_badge,
};

/// The icon named [name], or a neutral one for a name the map lacks.
IconData iconFor(String name) => _kIcons[name] ?? SFIcons.sf_circle_hexagongrid;

/// The names [iconFor] knows; the catalog's test checks every page uses one.
Iterable<String> get knownIconNames => _kIcons.keys;
