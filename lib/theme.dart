import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFF86A789); // Sage Green
const Color secondaryColor = Color(0xFFEAD0C0); // Blush Peach
const Color backgroundColorLight = Color(0xFFF5F4F0); // Warm Off-White
const Color backgroundColorDark = Color(0xFF242A26); // Dark Greenish-Grey
const Color cardColorLight = Color(0xFFFFFFFF);
const Color cardColorDark = Color(0xFF333A35);      // Dark Card
const Color textColorLight = Color(0xFF2C3E2D); // Dark Green-Tinted Grey
const Color textColorDark = Color(0xFFE8ECE9);   // Light Off-White

// Standaard tekstthema met Nunito voor body en Quicksand voor titels
final TextTheme lightTextTheme = GoogleFonts.nunitoTextTheme(
  TextTheme(
    displayLarge: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.quicksand(color: textColorLight, fontWeight: FontWeight.w600),
    bodyLarge: const TextStyle(color: textColorLight),
    bodyMedium: const TextStyle(color: textColorLight),
    bodySmall: const TextStyle(color: textColorLight),
  ),
);

final TextTheme darkTextTheme = GoogleFonts.nunitoTextTheme(
  TextTheme(
    displayLarge: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.quicksand(color: textColorDark, fontWeight: FontWeight.w600),
    bodyLarge: const TextStyle(color: textColorDark),
    bodyMedium: const TextStyle(color: textColorDark),
    bodySmall: const TextStyle(color: textColorDark),
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
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: textColorLight),
    titleTextStyle: GoogleFonts.quicksand(color: textColorLight, fontSize: 24, fontWeight: FontWeight.bold),
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 2),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
      elevation: 2,
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
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2),
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
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: textColorDark),
    titleTextStyle: GoogleFonts.quicksand(color: textColorDark, fontSize: 24, fontWeight: FontWeight.bold),
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 2),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
      elevation: 2,
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
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
  ),
);
