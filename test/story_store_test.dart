import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/story_store.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late StoryStore store;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = StoryStore(
      firestore: firestore,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'parent-1'),
      ),
    );
  });

  Future<Map<String, dynamic>> read(String id) async =>
      (await firestore
              .collection('parents')
              .doc('parent-1')
              .collection('children')
              .doc('kid-1')
              .collection('stories')
              .doc(id)
              .get())
          .data()!;

  StoryDraft free(String text, {String title = 'The Big Day'}) =>
      StoryDraft.free(
        title: title,
        text: text,
        hero: 'robot',
        heroName: 'Robin',
        mood: 'Calm',
        setting: 'Ocean',
        ideasShown: 2,
      );

  test('complete() saves the whole story under the child (TC-FB003)', () async {
    final saved = await store.complete('kid-1', free('Robin swam down deep.'));

    final doc = await read(saved.id);
    expect(doc['title'], 'The Big Day');
    expect(doc['mode'], 'free');
    expect(doc['writerLevel'], 'advanced');
    expect(doc['hero'], 'robot');
    expect(doc['heroName'], 'Robin');
    expect(doc['mood'], 'Calm');
    expect(doc['setting'], 'Ocean');
    expect(doc['text'], 'Robin swam down deep.');
    expect(doc['beginning'], isNull);
    expect(doc['totalWords'], 4);
    expect(doc['ideasShown'], 2);
    expect(doc['createdAt'], isNotNull);
    expect(doc['updatedAt'], isNotNull);
    expect(doc['completedAt'], isNotNull);
    expect(saved.title, 'The Big Day');
    expect(saved.text, 'Robin swam down deep.');
  });

  test('guided stories keep their parts and join them for text', () async {
    final draft = StoryDraft.guided(
      title: '',
      beginning: 'Once a robot lived by the sea.',
      middle: ' It found a shell. ',
      end: '',
      hero: 'robot',
    );
    final saved = await store.complete('kid-1', draft);

    final doc = await read(saved.id);
    expect(doc['title'], StoryDraft.defaultTitle);
    expect(doc['mode'], 'guided');
    expect(doc['beginning'], 'Once a robot lived by the sea.');
    expect(doc['middle'], 'It found a shell.');
    expect(doc['end'], '');
    expect(doc['text'], 'Once a robot lived by the sea.\n\nIt found a shell.');
    expect(doc['totalWords'], 11);
  });

  test(
    'drafts have no completedAt, and saving again updates the same doc',
    () async {
      final id = await store.saveDraft('kid-1', free('Once'));
      expect((await read(id))['completedAt'], isNull);

      final again = await store.saveDraft('kid-1', free('Once upon'), id: id);
      expect(again, id);
      expect((await read(id))['text'], 'Once upon');

      final saved = await store.complete(
        'kid-1',
        free('Once upon a time'),
        id: id,
      );
      expect(saved.id, id);
      expect((await read(id))['completedAt'], isNotNull);
      expect((await read(id))['createdAt'], isNotNull);

      final all = await firestore
          .collection('parents/parent-1/children/kid-1/stories')
          .get();
      expect(all.docs, hasLength(1));
    },
  );

  test('signed out → StateError', () async {
    final signedOut = StoryStore(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: false),
    );
    expect(
      () => signedOut.complete('kid-1', free('Hi')),
      throwsA(isA<StateError>()),
    );
    expect(
      () => signedOut.saveDraft('kid-1', free('Hi')),
      throwsA(isA<StateError>()),
    );
  });

  test('word counts ignore extra spaces', () {
    expect(StoryDraft.countWords(''), 0);
    expect(StoryDraft.countWords('   '), 0);
    expect(StoryDraft.countWords(' a  b\n\nc '), 3);
  });
}
