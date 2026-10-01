import 'dart:convert';

import 'package:flutter/services.dart';

import '../screens/comprehension_screen.dart';

/// Hand-written placeholder questions for end-of-chapter quizzes, from
/// `assets/data/comprehension_questions.json`.
///
/// Only some books have questions (currently the bundled Alice sample); every
/// other book falls back to the quiz screen's generic demo questions.
class QuestionBank {
  QuestionBank({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static QuestionBank instance = QuestionBank();

  static const assetPath = 'assets/data/comprehension_questions.json';

  final AssetBundle _bundle;

  /// Normalised book title -> chapter number -> questions.
  Map<String, Map<int, List<ComprehensionQuestion>>>? _books;

  /// The questions for chapter [chapter] (1 = first chapter) of the book whose
  /// EPUB title is [bookTitle], or null if there are none.
  Future<List<ComprehensionQuestion>?> chapterQuestions({
    required String? bookTitle,
    required int chapter,
  }) async {
    if (bookTitle == null) return null;
    final books = _books ??= await _load();
    final questions = books[normalizeTitle(bookTitle)]?[chapter];
    return questions == null || questions.isEmpty ? null : questions;
  }

  Future<Map<String, Map<int, List<ComprehensionQuestion>>>> _load() async {
    try {
      final json =
          jsonDecode(await _bundle.loadString(assetPath))
              as Map<String, dynamic>;
      return {
        for (final book in json['books'] as List<dynamic>)
          normalizeTitle(book['title'] as String): {
            for (final entry
                in (book['chapters'] as Map<String, dynamic>).entries)
              int.parse(entry.key): [
                for (final q in entry.value as List<dynamic>)
                  ComprehensionQuestion.fromJson(q as Map<String, dynamic>),
              ],
          },
      };
    } catch (_) {
      // A broken questions file shouldn't stop anyone reading; quizzes fall
      // back to the generic questions.
      return {};
    }
  }

  /// Lower-case letters and digits only, so "Alice's Adventures in
  /// Wonderland" matches regardless of apostrophe style or punctuation.
  static String normalizeTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
