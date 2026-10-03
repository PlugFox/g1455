import 'package:flutter/material.dart';

/// The page under everything, and the colour the browser paints before the
/// first frame (`theme-color` in `web/index.html` is the same).
const Color kSiteBackground = Color(0xFF070A12);

/// The accent: links, the selected page, focus.
const Color kSiteAccent = Color(0xFF8AB4FF);

/// Text that is read, and text that is secondary to it.
const Color kSiteText = Color(0xF2FFFFFF);
const Color kSiteTextMuted = Color(0xA6FFFFFF);

/// Hairlines and the fills of things that are not glass.
const Color kSiteLine = Color(0x1FFFFFFF);
const Color kSiteFill = Color(0x0FFFFFFF);

/// Wide enough for the side panel next to the page.
const double kSidebarBreakpoint = 840;

/// The side panel's width, when there is one.
const double kSidebarWidth = 272;

/// The widest a column of prose is set.
const double kContentMaxWidth = 920;

ThemeData buildSiteTheme() {
  final ThemeData base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5AFE),
      brightness: Brightness.dark,
      surface: kSiteBackground,
    ),
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kSiteBackground,
    visualDensity: VisualDensity.standard,
  );
  final TextTheme text = base.textTheme.apply(bodyColor: kSiteText, displayColor: kSiteText);
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.55, fontSize: 15),
    ),
    dividerColor: kSiteLine,
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Color(0xF01B2236), borderRadius: BorderRadius.all(Radius.circular(8))),
      textStyle: TextStyle(color: kSiteText, fontSize: 12),
      waitDuration: Duration(milliseconds: 400),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
