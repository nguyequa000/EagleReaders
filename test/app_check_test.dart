import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/app_check.dart';

void main() {
  test('a debug run without the token gets a loud warning', () {
    final warning = missingTokenWarning(hasToken: false, release: false);
    expect(warning, contains('APP CHECK TOKEN MISSING'));
    expect(warning, contains('--dart-define-from-file=app_check.json'));
  });

  test('runs with the token, and release builds, stay quiet', () {
    expect(missingTokenWarning(hasToken: true, release: false), isNull);
    expect(missingTokenWarning(hasToken: false, release: true), isNull);
    expect(missingTokenWarning(hasToken: true, release: true), isNull);
  });
}
