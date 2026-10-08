import 'package:flutter/material.dart';

const readingGreen = Color(0xFF2E7D32);
const readingPaper = Color(0xFFF7F5F0);
const readingDark = Color(0xFF1E1E1E);

ThemeData readingTheme(BuildContext context, {bool dark = false}) =>
    Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: readingGreen,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: dark ? readingDark : readingPaper,
      appBarTheme: const AppBarTheme(
        backgroundColor: readingPaper,
        foregroundColor: Color(0xFF243B28),
        elevation: 0,
      ),
    );
