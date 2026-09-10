import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One child on the account: a display name plus a 4-digit PIN.
///
/// The PIN is stored in plaintext — acceptable for this local prototype, and no
/// worse than the hardcoded `1234` it replaces. When child profiles move to
/// Firestore (`parents/{uid}/children`) this is where hashing would be added.
class ChildProfile {
  final String id;
  final String name;
  final String pin;
  final String emoji;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.pin,
    this.emoji = '🧒',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pin': pin,
    'emoji': emoji,
  };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    pin: json['pin'] as String,
    emoji: (json['emoji'] as String?) ?? '🧒',
  );
}

/// Local-only store for child profiles, backed by a single `shared_preferences`
/// key. Not namespaced per parent yet — two parent accounts on one device share
/// the list until this moves to a per-`uid` Firestore collection.
class ChildProfileStore {
  static const String _key = 'child_profiles';

  static Future<List<ChildProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChildProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChildProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }
}
