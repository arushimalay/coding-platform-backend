import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const bg0 = Color(0xFF0A0A0F);       // deepest bg
  static const bg1 = Color(0xFF111118);       // card bg
  static const bg2 = Color(0xFF1A1A26);       // elevated card
  static const bg3 = Color(0xFF242436);       // hover / border
  static const surface = Color(0xFF1E1E2E);   // editor bg

  static const accent = Color(0xFF7C6AF7);    // violet primary
  static const accentGlow = Color(0x337C6AF7);
  static const accentLight = Color(0xFFB8AFFE);

  static const green = Color(0xFF4ADE80);
  static const red = Color(0xFFF87171);
  static const yellow = Color(0xFFFBBF24);
  static const blue = Color(0xFF60A5FA);
  static const orange = Color(0xFFFB923C);

  static const text0 = Color(0xFFF1F0FF);     // primary text
  static const text1 = Color(0xFFADADCC);     // secondary text
  static const text2 = Color(0xFF6B6B8A);     // muted text

  static const divider = Color(0xFF2A2A3C);

  // ── Difficulty colors ─────────────────────────────────────────────────────
  static Color difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':   return green;
      case 'medium': return yellow;
      case 'hard':   return red;
      default:       return text1;
    }
  }

  // ── Status colors ─────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    if (status == 'Accepted') return green;
    if (status.contains('Error') || status == 'Wrong Answer') return red;
    if (status.contains('Time')) return yellow;
    return text1;
  }

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg0,
      colorScheme: const ColorScheme.dark(
        background: bg0,
        surface: bg1,
        primary: accent,
        secondary: accentLight,
        error: red,
        onPrimary: Colors.white,
        onSurface: text0,
        outline: divider,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
        bodyColor: text0,
        displayColor: text0,
      ).merge(TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 48, fontWeight: FontWeight.w700, color: text0,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 36, fontWeight: FontWeight.w700, color: text0,
        ),
        displaySmall: GoogleFonts.spaceGrotesk(
          fontSize: 28, fontWeight: FontWeight.w600, color: text0,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w600, color: text0,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w600, color: text0,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600, color: text0,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: text0),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: text1),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: text2),
        labelLarge: GoogleFonts.spaceGrotesk(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
      )),
      cardTheme: CardThemeData(
        color: bg1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: text2, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700, color: text0,
        ),
        iconTheme: const IconThemeData(color: text0),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bg2,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: text1),
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }
}