import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/child_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load returns an empty list when nothing is stored', () async {
    expect(await ChildProfileStore.load(), isEmpty);
  });

  test('save then load round-trips every field', () async {
    final profiles = [
      const ChildProfile(id: 'a', name: 'Emma', pin: '1111', emoji: '👧'),
      const ChildProfile(id: 'b', name: 'Noah', pin: '2222'),
    ];
    await ChildProfileStore.save(profiles);

    final loaded = await ChildProfileStore.load();
    expect(loaded.length, 2);
    expect(loaded[0].id, 'a');
    expect(loaded[0].name, 'Emma');
    expect(loaded[0].pin, '1111');
    expect(loaded[0].emoji, '👧');
    expect(loaded[1].name, 'Noah');
    expect(loaded[1].emoji, '🧒'); // default
  });

  test('save overwrites the previous list', () async {
    await ChildProfileStore.save([
      const ChildProfile(id: 'a', name: 'Emma', pin: '1111'),
    ]);
    await ChildProfileStore.save([
      const ChildProfile(id: 'c', name: 'Mia', pin: '3333'),
    ]);

    final loaded = await ChildProfileStore.load();
    expect(loaded.single.name, 'Mia');
  });
}
