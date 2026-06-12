import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFFF38B4B); // Warm Peach/Orange
const Color secondaryColor = Color(0xFFEAD0C0); // Blush Peach Accent
const Color backgroundColorLight = Color(0xFFFFF9EE); // Cream/Beige Background
const Color backgroundColorDark = Color(0xFF23201F); // Deep Charcoal/Warm Dark Brown
const Color cardColorLight = Color(0xFFFFFFFF);
const Color cardColorDark = Color(0xFF2E2A29);
const Color textColorLight = Color(0xFF2D2B2A); // Dark charcoal
const Color textColorDark = Color(0xFFEFEBE9); // Soft off-white

// Global font is Plus Jakarta Sans for a modern, rounded, clean and friendly aesthetic
final TextTheme lightTextTheme = GoogleFonts.plusJakartaSansTextTheme(
  const TextTheme(
    displayLarge: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(color: textColorLight, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: textColorLight, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(color: textColorLight, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: textColorLight),
    bodyMedium: TextStyle(color: textColorLight),
    bodySmall: TextStyle(color: textColorLight),
  ),
);

final TextTheme darkTextTheme = GoogleFonts.plusJakartaSansTextTheme(
  const TextTheme(
    displayLarge: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(color: textColorDark, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: textColorDark, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(color: textColorDark, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: textColorDark),
    bodyMedium: TextStyle(color: textColorDark),
    bodySmall: TextStyle(color: textColorDark),
  ),
);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: primaryColor,
  scaffoldBackgroundColor: backgroundColorLight,
  colorScheme: const ColorScheme.light(
    primary: primaryColor,
    secondary: secondaryColor,
    surface: cardColorLight,
    onPrimary: Colors.white,
    onSecondary: textColorLight,
    onSurface: textColorLight,
  ),
  textTheme: lightTextTheme,
  cardTheme: CardThemeData(
    color: cardColorLight,
    elevation: 0, // Shadows will be custom sketchy in redesigned widgets
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: textColorLight),
    titleTextStyle: GoogleFonts.plusJakartaSans(
        color: textColorLight, fontSize: 22, fontWeight: FontWeight.bold),
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    shape: CircleBorder(),
    elevation: 0,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
    backgroundColor: cardColorLight,
    elevation: 8,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: cardColorLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: textColorLight, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: textColorLight, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2.5),
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: primaryColor,
  scaffoldBackgroundColor: backgroundColorDark,
  colorScheme: const ColorScheme.dark(
    primary: primaryColor,
    secondary: secondaryColor,
    surface: cardColorDark,
    onPrimary: Colors.white,
    onSecondary: textColorDark,
    onSurface: textColorDark,
  ),
  textTheme: darkTextTheme,
  cardTheme: CardThemeData(
    color: cardColorDark,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: textColorDark),
    titleTextStyle: GoogleFonts.plusJakartaSans(
        color: textColorDark, fontSize: 22, fontWeight: FontWeight.bold),
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    shape: CircleBorder(),
    elevation: 0,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
    backgroundColor: cardColorDark,
    elevation: 8,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: cardColorDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: textColorDark, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: textColorDark, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2.5),
    ),
  ),
);
