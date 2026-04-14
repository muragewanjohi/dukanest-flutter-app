import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // DukaNest Commerce brand colors
  static const Color primary = Color(0xFF0025CC);
  static const Color primaryDark = Color(0xFF001790);
  static const Color secondary = Color(0xFF0C0528);
  static const Color tertiary = Color(0xFF3A5AFF);
  static const Color neutral = Color(0xFF8D8D8D);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  
  // Surfaces
  static const Color surface = Color(0xFFFAF9F9);
  static const Color surfaceContainerLow = Color(0xFFF4F3F3);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF444655);
  static const Color outlineVariant = Color(0xFFC5C5D8);
  
  // Ghost Border
  static const Color ghostBorder = Color(0x26C5C5D8); // 15% opacity

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryDark,
      onPrimaryContainer: Color(0xFFDDE1FF),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE6DEFF),
      onSecondaryContainer: Color(0xFF1D1639),
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFDEE0FF),
      onTertiaryContainer: Color(0xFF00105C),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: Color(0xFF1B1C1C),
      onSurfaceVariant: onSurfaceVariant,
      outline: Color(0xFF757687),
      outlineVariant: outlineVariant,
      shadow: Color(0x1A0C0528),
      scrim: Colors.black54,
      inverseSurface: Color(0xFF2F3031),
      onInverseSurface: Color(0xFFF2F0F0),
      inversePrimary: Color(0xFFBCC2FF),
      surfaceTint: primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      
      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: secondary,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: neutral,
        ),
      ),

      // Card Theme (No lines rule, ambient shadows)
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        titleSpacing: NavigationToolbar.kMiddleSpacing,
        iconTheme: const IconThemeData(color: primaryDark, size: 24),
        actionsIconTheme: const IconThemeData(color: primaryDark, size: 24),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.25,
          color: primaryDark,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0x330025CC), // 20% opacity primary ghost border
            width: 2,
          ),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: neutral,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: neutral,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, // Handled roughly, gradients require custom Container
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.all(8),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondary,
          side: const BorderSide(color: ghostBorder, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainerLowest,
        indicatorColor: const Color(0x1A0025CC),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}
