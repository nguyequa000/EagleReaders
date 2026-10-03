import 'package:flutter/material.dart';

/// The "+5 coins!" toast shown when a quiz or story earns coins (CR #2).
///
/// Shown on the app's root ScaffoldMessenger, so it stays up over whichever
/// screen comes next (the reader after a quiz, the story after the wizard).
SnackBar coinsEarnedSnackBar(int coins) => SnackBar(
  backgroundColor: Colors.amber.shade700,
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 2),
  content: Text(
    '🪙 +$coins coins!',
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
);
