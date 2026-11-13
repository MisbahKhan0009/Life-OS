import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colour tokens from the Life OS design canvas.
/// Core: warm greys, ink, sage and one Nothing-style red for actions.
/// Money hub: navy, steel and ice blue.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.chip,
    required this.line,
    required this.ink,
    required this.muted,
    required this.inverseInk,
    required this.action,
    required this.sage,
    required this.stone,
    required this.mist,
    required this.glass,
    required this.glassEdge,
    required this.shadow,
    required this.isDark,
  });

  final Color ground;
  final Color surface;
  final Color raised;
  final Color chip;
  final Color line;
  final Color ink;
  final Color muted;
  final Color inverseInk;
  final Color action;
  final Color sage;
  final Color stone;
  final Color mist;
  final Color glass;
  final Color glassEdge;
  final Color shadow;
  final bool isDark;

  static const light = AppColors(
    ground: Color(0xFFECEBE7),
    surface: Color(0xFFF8F8F6),
    raised: Color(0xFFFFFFFF),
    chip: Color(0xFFE1E0DA),
    line: Color(0xFFDAD9D3),
    ink: Color(0xFF151515),
    muted: Color(0xFF6F6E6A),
    inverseInk: Color(0xFFF8F8F6),
    action: Color(0xFFD71921),
    sage: Color(0xFF7D8E7E),
    stone: Color(0xFFC9C3B5),
    mist: Color(0xFFDDE0D5),
    glass: Color(0xD1F8F8F6),
    glassEdge: Color(0xB3FFFFFF),
    shadow: Color(0x1A151515),
    isDark: false,
  );

  static const dark = AppColors(
    ground: Color(0xFF0E0E0F),
    surface: Color(0xFF1A1A1B),
    raised: Color(0xFF242425),
    chip: Color(0xFF222223),
    line: Color(0xFF2B2B2C),
    ink: Color(0xFFEDEDEA),
    muted: Color(0xFF8D8C88),
    inverseInk: Color(0xFF0E0E0F),
    action: Color(0xFFE5262E),
    sage: Color(0xFF7D8E7E),
    stone: Color(0xFF3A372F),
    mist: Color(0xFF263028),
    glass: Color(0xC7222223),
    glassEdge: Color(0x14FFFFFF),
    shadow: Color(0x80000000),
    isDark: true,
  );

  @override
  AppColors copyWith({Color? ground, Color? surface, Color? ink}) => AppColors(
        ground: ground ?? this.ground,
        surface: surface ?? this.surface,
        raised: raised,
        chip: chip,
        line: line,
        ink: ink ?? this.ink,
        muted: muted,
        inverseInk: inverseInk,
        action: action,
        sage: sage,
        stone: stone,
        mist: mist,
        glass: glass,
        glassEdge: glassEdge,
        shadow: shadow,
        isDark: isDark,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      ground: c(ground, other.ground),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      chip: c(chip, other.chip),
      line: c(line, other.line),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      inverseInk: c(inverseInk, other.inverseInk),
      action: c(action, other.action),
      sage: c(sage, other.sage),
      stone: c(stone, other.stone),
      mist: c(mist, other.mist),
      glass: c(glass, other.glass),
      glassEdge: c(glassEdge, other.glassEdge),
      shadow: c(shadow, other.shadow),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Money hub palette (the Navy, Steel Blue and Ice Blue set from the mood board).
class MoneyColors {
  static const navy = Color(0xFF0D1B2A);
  static const deepNavy = Color(0xFF1B263B);
  static const steel = Color(0xFF3D5A80);
  static const teal = Color(0xFF4B6B7C);
  static const airy = Color(0xFF9BB4C7);
  static const sky = Color(0xFFC8D9E6);
  static const paleBlue = Color(0xFFD8E6F2);
  static const ice = Color(0xFFEAF2F8);
  static const beige = Color(0xFFF2EFE7);
  static const deposit = Color(0xFF4E7D5B);
  static const expense = Color(0xFFB5523F);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// Spacing and radius scale.
class Space {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 20, xxl = 24;
}

class Radii {
  static const double s = 12, m = 18, l = 24, xl = 32, pill = 999;
}

/// Typography. The bundled fonts are variable, so weight is also passed
/// as a `wght` font variation.
class AppText {
  static List<FontVariation> _w(FontWeight w) => [FontVariation('wght', w.value.toDouble())];

  static TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: 'InterTight',
        fontSize: size,
        fontWeight: weight,
        fontVariations: _w(weight),
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Dot-matrix numerals for counters, timers and money (Nothing OS feel).
  static TextStyle dot(double size, {Color? color, FontWeight weight = FontWeight.w900, double height = 1}) => TextStyle(
        fontFamily: 'Doto',
        fontSize: size,
        fontWeight: weight,
        fontVariations: _w(weight),
        color: color,
        height: height,
      );

  /// Uppercase mono labels.
  static TextStyle label(double size, {Color? color, double tracking = 0.14}) => TextStyle(
        fontFamily: 'GeistMono',
        fontSize: size,
        fontWeight: FontWeight.w500,
        fontVariations: _w(FontWeight.w500),
        color: color,
        letterSpacing: size * tracking,
      );

  static double? lerp(double? a, double? b, double t) => lerpDouble(a, b, t);
}
