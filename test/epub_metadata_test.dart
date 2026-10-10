import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/epub_metadata.dart';

void main() {
  test('reads the title and author an EPUB gives itself', () async {
    const path = 'assets/books/alice_in_wonderland.epub';
    for (final info in [
      readEpubInfo(File(path).readAsBytesSync()),
      await readEpubInfoOffThread(path),
    ]) {
      expect(info!.title, "Alice's Adventures in Wonderland");
      expect(info.author, 'Lewis Carroll');
    }
    expect(readEpubInfo(Uint8List.fromList([1, 2])), isNull);
  });

  test('decodes and tidies the package metadata', () {
    final info = epubInfoFromOpf('''
<package><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title id="t">  The Cat &amp;
     the &#8220;Hat&#x201D; </dc:title>
  <dc:title>A subtitle</dc:title>
  <dc:creator opf:role="aut">Dr. Seuss</dc:creator>
</metadata></package>''');
    expect(info.title, 'The Cat & the “Hat”');
    expect(info.author, 'Dr. Seuss');
    expect(epubInfoFromOpf('<package/>').title, isEmpty);
  });

  test('makes a title from a file name', () {
    expect(
      titleFromFileName('alice_in_wonderland.epub'),
      'Alice In Wonderland',
    );
    expect(titleFromFileName('/books/The-Hobbit.v2.EPUB'), 'The Hobbit V2');
    expect(titleFromFileName('NASA facts.epub'), 'NASA Facts');
  });
}
