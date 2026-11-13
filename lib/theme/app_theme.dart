import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  static ThemeData build(AppColors c) {
    final brightness = c.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.sage,
      brightness: brightness,
    ).copyWith(
      surface: c.surface,
      onSurface: c.ink,
      primary: c.ink,
      onPrimary: c.inverseInk,
      error: c.action,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ground,
      fontFamily: 'InterTight',
      // No ripples or ink: the app should feel calm, not Material.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: c.ink.withValues(alpha: 0.04),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.sage.withValues(alpha: 0.35),
        selectionHandleColor: c.ink,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      dividerColor: c.line,
      extensions: [c],
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.ink, brightness: brightness),
    );
  }
}
