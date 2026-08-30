class Definition {
  final String definition;
  final String? example;
  final List<String> synonyms;

  Definition({
    required this.definition,
    this.example,
    this.synonyms = const [],
  });

  factory Definition.fromJson(Map<String, dynamic> json) {
    List<String> syns = [];
    if (json['synonyms'] is List) {
      syns = (json['synonyms'] as List)
          .whereType<String>()
          .take(5)
          .toList();
    }
    return Definition(
      definition: json['definition'] as String? ?? '',
      example: json['example'] as String?,
      synonyms: syns,
    );
  }
}

class Meaning {
  final String partOfSpeech;
  final List<Definition> definitions;

  Meaning({required this.partOfSpeech, required this.definitions});

  factory Meaning.fromJson(Map<String, dynamic> json) {
    List<Definition> defs = [];
    if (json['definitions'] is List) {
      defs = (json['definitions'] as List)
          .whereType<Map>()
          .map((e) => Definition.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return Meaning(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      definitions: defs,
    );
  }
}

class WordEntry {
  final String word;
  final String phonetic;
  final String? audioUrl;
  final List<Meaning> meanings;

  WordEntry({
    required this.word,
    required this.phonetic,
    this.audioUrl,
    required this.meanings,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    String phonetic = json['phonetic'] as String? ?? '';
    String? audioUrl;
    if (json['phonetics'] is List) {
      final phonetics = json['phonetics'] as List;
      if (phonetic.isEmpty) {
        for (final p in phonetics.whereType<Map>()) {
          final ph = p['text'];
          if (ph is String && ph.isNotEmpty) {
            phonetic = ph;
            break;
          }
        }
      }
      for (final p in phonetics.whereType<Map>()) {
        final url = p['audio'];
        if (url is String && url.isNotEmpty) {
          audioUrl = url;
          break;
        }
      }
    }

    List<Meaning> meaningsList = [];
    if (json['meanings'] is List) {
      meaningsList = (json['meanings'] as List)
          .whereType<Map>()
          .map((e) => Meaning.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    return WordEntry(
      word: json['word'] as String? ?? '',
      phonetic: phonetic,
      audioUrl: audioUrl,
      meanings: meaningsList,
    );
  }
}
