import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  // Impostazioni di base del tema
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
  scaffoldBackgroundColor: Colors.white,

  // Personalizzazione specifica per la tua AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 4,
  ),

  // Personalizzazione specifica per gli ElevatedButton
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),

  // Stili per il testo predefiniti
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 16),
    titleLarge: TextStyle(fontWeight: FontWeight.bold),
  ),
);
