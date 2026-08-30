import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'models/word_entry.dart';
import 'services/dictionary_service.dart';
import 'services/speech_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: dissolve the system nav/status bars so there is no rigid
  // black strip cutting off the app. Colors flow behind the bars instead.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LinguaApp());
}

/// Flat, borderless palette — no shadows, no outlines, like a classic
/// file-manager UI. Everything is tinted blocks and typography.
class Palette {
  const Palette({
    required this.bg,
    required this.block,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
  });

  final Color bg;
  final Color block;
  final Color line;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color warn;
  final Color warnSoft;
  final Color bad;
  final Color badSoft;
}

const lightPalette = Palette(
  bg: Color(0xFFF4F3F0),
  block: Color(0xFFECEBE7),
  line: Color(0xFFDCDAD3),
  ink: Color(0xFF232527),
  muted: Color(0xFF8A8B85),
  accent: Color(0xFF5C6BC0),
  accentSoft: Color(0xFFE9EBF7),
  warn: Color(0xFFB57A2A),
  warnSoft: Color(0xFFF7EEDE),
  bad: Color(0xFFC0453A),
  badSoft: Color(0xFFF6E7E4),
);

const darkPalette = Palette(
  bg: Color(0xFF16181D),
  block: Color(0xFF20242B),
  line: Color(0xFF2E333C),
  ink: Color(0xFFE7E9ED),
  muted: Color(0xFF9AA0AB),
  accent: Color(0xFF9FA8DA),
  accentSoft: Color(0xFF2A3045),
  warn: Color(0xFFD9A35A),
  warnSoft: Color(0xFF3A2F1E),
  bad: Color(0xFFE07A6E),
  badSoft: Color(0xFF3D2422),
);

/// Current palette. Swaps between light and dark as the theme changes.
class K {
  K._();

  static Palette p = lightPalette;

  static bool get dark => identical(p, darkPalette);

  static Color get bg => p.bg;
  static Color get block => p.block;
  static Color get line => p.line;
  static Color get ink => p.ink;
  static Color get muted => p.muted;
  static Color get accent => p.accent;
  static Color get accentSoft => p.accentSoft;
  static Color get warn => p.warn;
  static Color get warnSoft => p.warnSoft;
  static Color get bad => p.bad;
  static Color get badSoft => p.badSoft;
}

ThemeData _theme({required bool dark}) {
  final palette = dark ? darkPalette : lightPalette;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: dark ? Brightness.dark : Brightness.light,
    surface: palette.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    highlightColor: Colors.transparent,
    focusColor: Colors.transparent,
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: palette.ink),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: palette.ink,
      ),
    ),
  );
}

class LinguaApp extends StatefulWidget {
  const LinguaApp({super.key});

  @override
  State<LinguaApp> createState() => _LinguaAppState();
}

class _LinguaAppState extends State<LinguaApp> {
  late final ThemeData _themeLight = _theme(dark: false);
  late final ThemeData _themeDark = _theme(dark: true);

  bool _dark = false;

  void _setDark(bool dark) {
    setState(() => _dark = dark);
  }

  @override
  Widget build(BuildContext context) {
    K.p = _dark ? darkPalette : lightPalette;
    return MaterialApp(
      title: 'Lingua',
      debugShowCheckedModeBanner: false,
      theme: _themeLight,
      darkTheme: _themeDark,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(dark: _dark, onToggleDark: _setDark),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.dark, required this.onToggleDark});

  final bool dark;
  final void Function(bool dark) onToggleDark;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _popular = [
    'wander',
    'whisper',
    'breeze',
    'glimpse',
    'wonder',
    'resilient',
    'ephemeral',
    'brave',
    'echo',
    'journey',
  ];

  final SpeechService _speech = SpeechService();
  final DictionaryService _dictionary = DictionaryService();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  Timer? _debounce;
  Timer? _hintTimer;
  Timer? _errorTimer;

  bool _listening = false;
  bool _searching = false;
  WordEntry? _entry;
  String? _searchedWord;
  bool _notFound = false;
  List<String> _suggestions = const [];
  List<String> _recent = const [];
  String? _voiceHint;
  String? _transientError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);

    _dictionary.warmup();

    _speech.onWordSpoken = (word) {
      if (!mounted) return;
      setState(() => _listening = false);
      _submit(word);
    };
    _speech.onStarted = () {
      if (mounted) setState(() => _listening = true);
    };
    _speech.onCanceled = () {
      if (!mounted) return;
      setState(() => _listening = false);
      _flashHint('Didn’t catch that — try typing it instead.');
    };
    _speech.onError = (message) {
      if (!mounted) return;
      setState(() => _listening = false);
      _flashError(message);
    };
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _entry = null;
      _notFound = false;
      _suggestions = const [];
    });
    if (value.trim().isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final results = await _dictionary.suggest(value.trim());
      if (!mounted || _search.text.trim() != value.trim()) return;
      setState(() => _suggestions = results);
    });
  }

  Future<void> _submit(String word) async {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return;

    _search.text = clean;
    _search.selection = TextSelection.collapsed(offset: _search.text.length);
    _searchFocus.unfocus();

    _debounce?.cancel();
    setState(() {
      _searching = true;
      _entry = null;
      _notFound = false;
      _suggestions = const [];
      _searchedWord = clean;
    });

    final entry = await _dictionary.lookup(clean);
    if (!mounted) return;

    setState(() {
      _searching = false;
      if (entry != null) {
        _entry = entry;
        _notFound = false;
        _suggestions = const [];
        _recent = _promoteRecent(_recent, clean);
      } else {
        _entry = null;
        _notFound = true;
        _suggestions = const [];
      }
    });

    if (entry == null) {
      final suggestions = await _dictionary.suggest(clean, limit: 6);
      if (!mounted || _searchedWord != clean) return;
      setState(() => _suggestions = suggestions);
    } else {
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _promoteRecent(List<String> list, String word) {
    return [word, ...list.where((e) => e != word)].take(8).toList();
  }

  Future<void> _openVoice() async {
    if (_listening || _searching) return;
    _searchFocus.unfocus();
    setState(() {
      _voiceHint = null;
      _transientError = null;
    });
    await _speech.listen();
  }

  void _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _flashHint(String message) {
    _hintTimer?.cancel();
    setState(() => _voiceHint = message);
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _voiceHint == message) {
        setState(() => _voiceHint = null);
      }
    });
  }

  void _flashError(String message) {
    _errorTimer?.cancel();
    setState(() => _transientError = message);
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _transientError == message) {
        setState(() => _transientError = null);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hintTimer?.cancel();
    _errorTimer?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _speech.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: K.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: K.dark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: K.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _searchFocus.unfocus(),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lingua',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: K.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '.',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: K.accent,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => widget.onToggleDark(!K.dark),
                        icon: Icon(
                          K.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: K.muted,
                          size: 22,
                        ),
                        tooltip: K.dark ? 'Use light mode' : 'Use dark mode',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Text(
                    'Speak or type a word — understand it instantly.',
                    style: TextStyle(fontSize: 14, color: K.muted),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildSearchBar(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildTransient(),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: K.block,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: K.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              style: TextStyle(fontSize: 16, color: K.ink),
              cursorColor: K.accent,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Search a word…',
                hintStyle: TextStyle(fontSize: 16, color: K.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _debounce?.cancel();
                _search.clear();
                setState(() => _suggestions = const []);
              },
              icon: Icon(Icons.close_rounded, size: 20, color: K.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 60),
              splashRadius: 18,
            ),
          const SizedBox(width: 4),
          _buildMicButton(),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return Material(
      color: _listening ? K.accent : K.ink,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: _listening ? null : _openVoice,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Icon(
              _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransient() {
    if (_transientError != null) {
      return _flash(
        key: ValueKey('e$_transientError'),
        bg: K.badSoft,
        fg: K.bad,
        icon: Icons.error_rounded,
        text: _transientError!,
      );
    }
    if (_voiceHint != null) {
      return _flash(
        key: ValueKey('h$_voiceHint'),
        bg: K.warnSoft,
        fg: K.warn,
        icon: Icons.voice_over_off_rounded,
        text: _voiceHint!,
      );
    }
    return const SizedBox(height: 1);
  }

  Widget _flash({
    required Key key,
    required Color bg,
    required Color fg,
    required IconData icon,
    required String text,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    Widget child;
    String key;

    if (_searching) {
      key = 'searching';
      child = _buildLoading();
    } else if (_entry != null) {
      key = 'entry:${_entry!.word}';
      child = _ResultView(
        entry: _entry!,
        searchedWord: _searchedWord,
        onSpeak: _speak,
        onOpen: _submit,
      );
    } else if (_notFound) {
      key = 'nf:$_searchedWord';
      child = _buildNotFound();
    } else if (_suggestions.isNotEmpty) {
      key = 'sug:${_suggestions.first}';
      child = _buildSuggestions();
    } else {
      key = 'home';
      child = _buildEmptyState();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: K.accent),
          ),
          const SizedBox(height: 14),
          Text(
            'Looking it up…',
            style: TextStyle(fontSize: 13.5, color: K.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.block,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _suggestions.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: K.line),
            _buildSuggestionTile(_suggestions[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(String word) {
    return InkWell(
      onTap: () => _submit(word),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.north_west_rounded, size: 16, color: K.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: K.ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: K.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: K.accentSoft,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(Icons.auto_stories_rounded, size: 40, color: K.accent),
          ),
          const SizedBox(height: 22),
          Text(
            'Speak it or type it',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: K.ink,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Look up any English word by voice or text and read its meaning right here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.5, color: K.muted),
            ),
          ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 30),
            _buildSectionLabel('Recently read'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in _recent)
                  _buildChip(word, bg: K.accentSoft, fg: K.accent),
              ],
            ),
          ],
          const SizedBox(height: 30),
          _buildSectionLabel('Try a word'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in _popular.take(6))
                _buildChip(word, bg: K.block, fg: K.ink),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '52,000+ words · works offline · instant',
            style: TextStyle(fontSize: 12, color: K.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: K.muted,
        ),
      ),
    );
  }

  Widget _buildChip(String label, {required Color bg, required Color fg}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _submit(label),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    final word = _searchedWord ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: K.badSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.search_off_rounded, size: 20, color: K.bad),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No entry for “$word”',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: K.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Check the spelling, or pick a word below.',
                style: TextStyle(fontSize: 13.5, color: K.muted),
              ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 22),
          _buildSectionLabel('Did you mean'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions)
                _buildChip(suggestion, bg: K.block, fg: K.ink),
            ],
          ),
        ],
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_rounded, size: 17, color: K.muted),
            const SizedBox(width: 8),
            Text(
              'Or tap the mic and say the word again.',
              style: TextStyle(fontSize: 13.5, color: K.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.entry,
    required this.searchedWord,
    required this.onSpeak,
    required this.onOpen,
  });

  final WordEntry entry;
  final String? searchedWord;
  final void Function(String text) onSpeak;
  final void Function(String word) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    entry.word,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: K.ink,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  if (entry.phonetic.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        entry.phonetic,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: K.accent,
                        ),
                      ),
                    ),
                  if (entry.ipa.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'IPA ${entry.ipa}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: K.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildSpeakButton(() => onSpeak(entry.word)),
          ],
        ),
        const SizedBox(height: 24),
        for (final meaning in entry.meanings) ...[
          _buildMeaning(meaning),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildSpeakButton(VoidCallback onPressed) {
    return Material(
      color: K.accentSoft,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.volume_up_rounded, size: 24, color: K.accent),
        ),
      ),
    );
  }

  Widget _buildMeaning(Meaning meaning) {
    final text = meaning.definitions
        .take(2)
        .map((d) => d.definition)
        .join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              meaning.partOfSpeech.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: K.accent,
              ),
            ),
            const Spacer(),
            if (text.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSpeak(text),
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 17,
                    color: K.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Divider(height: 1, thickness: 1, color: K.line),
        const SizedBox(height: 2),
        for (var i = 0; i < meaning.definitions.length; i++)
          _buildDefinition(meaning.definitions[i], i + 1),
      ],
    );
  }

  Widget _buildDefinition(Definition def, int index) {
    final synonyms = def.synonyms
        .where((s) => s.toLowerCase() != searchedWord)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: K.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: K.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  def.definition,
                  style: TextStyle(fontSize: 15.5, height: 1.5, color: K.ink),
                ),
              ),
            ],
          ),
          if (def.example != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Text(
                '“${def.example}”',
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color: K.muted,
                ),
              ),
            ),
          if (synonyms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final synonym in synonyms.take(5))
                    _buildSuggestionChip(synonym),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String word) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onOpen(word),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: K.block,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: K.ink,
            ),
          ),
        ),
      ),
    );
  }
}
