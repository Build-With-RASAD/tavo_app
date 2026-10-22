// test/i18n_parity_test.dart
//
// The two locales must carry EXACTLY the same key set: a key that exists in
// one language and not the other falls back to the raw key at runtime (a
// visible English string inside an Arabic screen).
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> _translations(String locale) async {
  final raw = await rootBundle.loadString('assets/translations/$locale.json');
  return json.decode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('en and ar carry exactly the same key set', () async {
    final en = await _translations('en');
    final ar = await _translations('ar');

    expect(
      ar.keys.toSet(),
      en.keys.toSet(),
      reason: 'the locales must not drift — a missing key renders the raw key',
    );
  });

  test('every value is a non-empty string', () async {
    for (final locale in ['en', 'ar']) {
      final map = await _translations(locale);
      for (final entry in map.entries) {
        expect(entry.value, isA<String>(), reason: '$locale.${entry.key}');
        expect(
          (entry.value as String).trim(),
          isNotEmpty,
          reason: '$locale.${entry.key} is empty',
        );
      }
    }
  });
}
