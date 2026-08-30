import 'package:flutter_test/flutter_test.dart';

import 'package:lingua/main.dart';
import 'package:lingua/models/word_entry.dart';

Map<String, dynamic> _meaning(String pos, List<String> defs, List<String> syns) {
  return {
    'partOfSpeech': pos,
    'definitions': defs
        .map((d) => {'definition': d, 'synonyms': syns})
        .toList(),
  };
}

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const LinguaApp());
    await tester.pump();

    expect(find.text('Lingua'), findsWidgets);
  });

  test('Definition/Meaning model parses offline-style entry', () {
    final meaning = Meaning.fromJson(_meaning('Adjective', ['full of joy'],
        ['cheerful', 'glad']));

    expect(meaning.partOfSpeech, 'Adjective');
    expect(meaning.definitions, hasLength(1));
    expect(meaning.definitions.first.definition, 'full of joy');
    expect(meaning.definitions.first.synonyms, contains('cheerful'));
  });

  test('WordEntry parses from full API-style JSON', () {
    final entry = WordEntry.fromJson({
      'word': 'bright',
      'phonetic': '/braɪt/',
      'phonetics': [
        {'text': '/braɪt/', 'audio': 'https://example.com/a.mp3'}
      ],
      'meanings': [
        {
          'partOfSpeech': 'adjective',
          'definitions': [
            {
              'definition': 'giving out much light',
              'example': 'a bright room',
              'synonyms': ['shiny'],
            }
          ],
        }
      ],
    });

    expect(entry.word, 'bright');
    expect(entry.phonetic, '/braɪt/');
    expect(entry.audioUrl, 'https://example.com/a.mp3');
    expect(entry.meanings, hasLength(1));
    expect(entry.meanings.first.definitions.first.example, 'a bright room');
  });
}
