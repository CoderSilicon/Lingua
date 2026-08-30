import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/word_entry.dart';

class DictionaryService {
  static const String _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en/';
  static const String _dictDir = 'assets/dict';

  final Map<String, WordEntry> _memoryCache = {};
  final Map<String, Map<String, dynamic>> _letterCache = {};

  /// Pre-loads the bundled offline dictionary so the first lookup is instant.
  Future<void> warmup() async {
    await _loadLetter('a');
  }

  /// Looks up a word, preferring the fast local dictionary, then a cached
  /// result, and finally the online API (with retry). Returns null only when
  /// the word truly has no definition anywhere.
  Future<WordEntry?> lookup(String word) async {
    final clean = word.trim().toLowerCase();
    final headword = clean.split(RegExp(r'\s+')).first;
    if (headword.isEmpty) return null;

    // 1. In-memory cache (instant).
    final cached = _memoryCache[headword];
    if (cached != null) return cached;

    // 2. Bundled offline dictionary (instant, no network).
    final offline = await _offlineLookup(headword);
    if (offline != null) {
      _memoryCache[headword] = offline;
      return offline;
    }

    // 3. Online API with retry.
    for (var attempt = 0; attempt < 2; attempt++) {
      final entry = await _onlineLookup(headword);
      if (entry != null) {
        _memoryCache[headword] = entry;
        return entry;
      }
    }

    return null;
  }

  /// Returns up to [limit] words from the offline dictionary that start with
  /// [prefix]. Used for autocomplete and "did you mean" suggestions.
  Future<List<String>> suggest(String prefix, {int limit = 8}) async {
    final clean = prefix.trim().toLowerCase();
    if (clean.isEmpty) return const [];
    final code = clean.codeUnitAt(0);
    if (code < 97 || code > 122) return const [];

    final dict = await _loadLetter(clean[0]);
    if (dict == null) return const [];

    final results = <String>[];
    for (final key in dict.keys) {
      if (key.startsWith(clean)) {
        results.add(key);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  Future<Map<String, dynamic>?> _loadLetter(String letter) async {
    final cached = _letterCache[letter];
    if (cached != null) return cached;

    try {
      final raw = await rootBundle
          .loadString('$_dictDir/$letter.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _letterCache[letter] = data;
      return data;
    } catch (_) {
      _letterCache[letter] = {};
      return {};
    }
  }

  Future<WordEntry?> _offlineLookup(String word) async {
    if (word.isEmpty) return null;
    final letter = word[0];
    final dict = await _loadLetter(letter);
    if (dict == null) return null;
    final raw = dict[word];
    if (raw == null) return null;

    try {
      final m = (raw as Map).cast<String, dynamic>();
      final meaningsJson = m['meanings'] as List? ?? [];
      final meanings = meaningsJson
          .whereType<Map>()
          .map((e) => Meaning.fromJson(_offlineMeaning(e.cast<String, dynamic>())))
          .toList();

      return WordEntry(
        word: word,
        phonetic: (m['phon'] as String? ?? '').isNotEmpty
            ? '/${m['phon']}/'
            : '',
        ipa: (m['ipa'] as String? ?? '').isNotEmpty
            ? '[${m['ipa']}]'
            : '',
        meanings: meanings,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _offlineMeaning(Map<String, dynamic> m) {
    final syns = (m['syn'] as List? ?? []).whereType<String>().toList();
    final defs = (m['defs'] as List? ?? [])
        .whereType<Map>()
        .map((e) => {
              'definition': e['d'] ?? '',
              if (e['e'] != null) 'example': e['e'],
              'synonyms': syns,
            })
        .toList();
    return {
      'partOfSpeech': m['pos'] ?? '',
      'definitions': defs,
    };
  }

  Future<WordEntry?> _onlineLookup(String word) async {
    final uri = Uri.parse('$_baseUrl${Uri.encodeComponent(word)}');
    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return WordEntry.fromJson(
            (data.first as Map).cast<String, dynamic>(),
          );
        }
      }
    } catch (_) {
      // fall through, try again
    }
    return null;
  }
}
