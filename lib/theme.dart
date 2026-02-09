import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFFEDD9B7); // Warm zandkleur
const Color secondaryColor = Color(0xFFFDE047); // Geel voor accenten
const Color backgroundColorLight = Color(0xFFFAF8F2); // Gebroken wit achtergrond
const Color backgroundColorDark = Color(0xFF2C2A25); // Diepbruine achtergrond
const Color cardColorLight = Color(0xFFFFFFFF);
const Color cardColorDark = Color(0xFF403C35);      // Donkere kaartkleur
const Color textColorLight = Color(0xFF3D3B35); // Donkerdere tekst voor contrast
const Color textColorDark = Color(0xFFF5F3EF);   // Lichte tekst voor donkere modus

// Standaard tekstthema met Lato
final TextTheme lightTextTheme = GoogleFonts.latoTextTheme(
  const TextTheme(
    displayLarge: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: textColorLight),
    titleLarge: TextStyle(color: textColorLight, fontWeight: FontWeight.bold),
    bodyMedium: TextStyle(color: textColorLight),
  ),
);

final TextTheme darkTextTheme = GoogleFonts.latoTextTheme(
  const TextTheme(
    displayLarge: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: textColorDark),
    titleLarge: TextStyle(color: textColorDark, fontWeight: FontWeight.bold),
    bodyMedium: TextStyle(color: textColorDark),
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
    onPrimary: textColorLight, // Zwarte tekst op lichte primaire kleur
    onSecondary: Colors.black,
    onSurface: textColorLight,
  ),
  textTheme: lightTextTheme,
  cardTheme: CardThemeData(
    color: cardColorLight,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: Color(0xFFB0926C)),
    titleTextStyle: GoogleFonts.pacifico(color: const Color(0xFF8C6D4A), fontSize: 24, fontWeight: FontWeight.bold), // Pacifico voor titels
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFC7A87F), // Iets donkerdere knop
      foregroundColor: Colors.white, // Witte tekst op knop
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFC7A87F),
      foregroundColor: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: Color(0xFF8C6D4A),
    unselectedItemColor: Colors.grey,
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
    onPrimary: textColorLight, // Zwarte tekst op lichte primaire kleur
    onSecondary: Colors.black,
    onSurface: textColorDark,
  ),
  textTheme: darkTextTheme,
  cardTheme: CardThemeData(
    color: cardColorDark,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: primaryColor),
    titleTextStyle: GoogleFonts.pacifico(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold), // Pacifico voor titels
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: textColorLight, // Zwarte tekst op knop
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: textColorLight,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
  ),
);
