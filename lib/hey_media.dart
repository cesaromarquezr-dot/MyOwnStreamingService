// FILE: `lib/hey_media.dart`.
// Purpose: User-facing Hey Media entry point for natural-language and voice
// requests about the signed-in profile's media library and Store catalog.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'app_core.dart';
import 'core/services/media_ai_assistant.dart';
import 'details.dart';
import 'shop.dart';
import 'smart_search.dart';

enum _HeyMediaResponseMode {
  textOnly,
  textAndVoice,
  voiceFocused,
}

extension on _HeyMediaResponseMode {
  String get label {
    switch (this) {
      case _HeyMediaResponseMode.textOnly:
        return 'Text only';
      case _HeyMediaResponseMode.textAndVoice:
        return 'Text + voice';
      case _HeyMediaResponseMode.voiceFocused:
        return 'Voice-focused';
    }
  }
}

class _HeyMediaVoicePreset {
  final String id;
  final String label;
  final String locale;
  final String gender;

  const _HeyMediaVoicePreset({
    required this.id,
    required this.label,
    required this.locale,
    required this.gender,
  });
}

class _HeyMediaInputLocale {
  final String id;
  final String label;
  final String? locale;

  const _HeyMediaInputLocale({
    required this.id,
    required this.label,
    required this.locale,
  });
}

const List<_HeyMediaVoicePreset> _heyMediaVoicePresets = [
  _HeyMediaVoicePreset(id: 'en-gb-female', label: 'British English — Female', locale: 'en-GB', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-gb-male', label: 'British English — Male', locale: 'en-GB', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-us-female', label: 'American English — Female', locale: 'en-US', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-us-male', label: 'American English — Male', locale: 'en-US', gender: 'male'),
  _HeyMediaVoicePreset(id: 'es-mx-female', label: 'Mexican Spanish — Female', locale: 'es-MX', gender: 'female'),
  _HeyMediaVoicePreset(id: 'es-mx-male', label: 'Mexican Spanish — Male', locale: 'es-MX', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-au-female', label: 'Australian English — Female', locale: 'en-AU', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-au-male', label: 'Australian English — Male', locale: 'en-AU', gender: 'male'),
  _HeyMediaVoicePreset(id: 'ko-kr-female', label: 'Korean — Female', locale: 'ko-KR', gender: 'female'),
  _HeyMediaVoicePreset(id: 'ko-kr-male', label: 'Korean — Male', locale: 'ko-KR', gender: 'male'),
  _HeyMediaVoicePreset(id: 'es-ar-female', label: 'Argentinian Spanish — Female', locale: 'es-AR', gender: 'female'),
  _HeyMediaVoicePreset(id: 'es-ar-male', label: 'Argentinian Spanish — Male', locale: 'es-AR', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-ca-female', label: 'Canadian English — Female', locale: 'en-CA', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-ca-male', label: 'Canadian English — Male', locale: 'en-CA', gender: 'male'),
  _HeyMediaVoicePreset(id: 'fr-ca-female', label: 'Canadian French — Female', locale: 'fr-CA', gender: 'female'),
  _HeyMediaVoicePreset(id: 'fr-ca-male', label: 'Canadian French — Male', locale: 'fr-CA', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-nz-female', label: 'New Zealand English — Female', locale: 'en-NZ', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-nz-male', label: 'New Zealand English — Male', locale: 'en-NZ', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-ie-female', label: 'Irish English — Female', locale: 'en-IE', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-ie-male', label: 'Irish English — Male', locale: 'en-IE', gender: 'male'),
  _HeyMediaVoicePreset(id: 'en-za-female', label: 'South African English — Female', locale: 'en-ZA', gender: 'female'),
  _HeyMediaVoicePreset(id: 'en-za-male', label: 'South African English — Male', locale: 'en-ZA', gender: 'male'),
  _HeyMediaVoicePreset(id: 'es-es-female', label: 'Spanish (Spain) — Female', locale: 'es-ES', gender: 'female'),
  _HeyMediaVoicePreset(id: 'es-es-male', label: 'Spanish (Spain) — Male', locale: 'es-ES', gender: 'male'),
  _HeyMediaVoicePreset(id: 'fr-fr-female', label: 'French — Female', locale: 'fr-FR', gender: 'female'),
  _HeyMediaVoicePreset(id: 'fr-fr-male', label: 'French — Male', locale: 'fr-FR', gender: 'male'),
  _HeyMediaVoicePreset(id: 'de-de-female', label: 'German — Female', locale: 'de-DE', gender: 'female'),
  _HeyMediaVoicePreset(id: 'de-de-male', label: 'German — Male', locale: 'de-DE', gender: 'male'),
  _HeyMediaVoicePreset(id: 'it-it-female', label: 'Italian — Female', locale: 'it-IT', gender: 'female'),
  _HeyMediaVoicePreset(id: 'it-it-male', label: 'Italian — Male', locale: 'it-IT', gender: 'male'),
  _HeyMediaVoicePreset(id: 'ja-jp-female', label: 'Japanese — Female', locale: 'ja-JP', gender: 'female'),
  _HeyMediaVoicePreset(id: 'ja-jp-male', label: 'Japanese — Male', locale: 'ja-JP', gender: 'male'),
  _HeyMediaVoicePreset(id: 'pt-br-female', label: 'Brazilian Portuguese — Female', locale: 'pt-BR', gender: 'female'),
  _HeyMediaVoicePreset(id: 'pt-br-male', label: 'Brazilian Portuguese — Male', locale: 'pt-BR', gender: 'male'),
  _HeyMediaVoicePreset(id: 'hi-in-female', label: 'Hindi — Female', locale: 'hi-IN', gender: 'female'),
  _HeyMediaVoicePreset(id: 'hi-in-male', label: 'Hindi — Male', locale: 'hi-IN', gender: 'male'),
];

const List<_HeyMediaInputLocale> _heyMediaInputLocales = [
  _HeyMediaInputLocale(id: 'system', label: 'Device default', locale: null),
  _HeyMediaInputLocale(id: 'en-GB', label: 'British English', locale: 'en-GB'),
  _HeyMediaInputLocale(id: 'en-US', label: 'American English', locale: 'en-US'),
  _HeyMediaInputLocale(id: 'es-MX', label: 'Mexican Spanish', locale: 'es-MX'),
  _HeyMediaInputLocale(id: 'en-AU', label: 'Australian English', locale: 'en-AU'),
  _HeyMediaInputLocale(id: 'ko-KR', label: 'Korean', locale: 'ko-KR'),
  _HeyMediaInputLocale(id: 'es-AR', label: 'Argentinian Spanish', locale: 'es-AR'),
  _HeyMediaInputLocale(id: 'en-CA', label: 'Canadian English', locale: 'en-CA'),
  _HeyMediaInputLocale(id: 'fr-CA', label: 'Canadian French', locale: 'fr-CA'),
  _HeyMediaInputLocale(id: 'en-NZ', label: 'New Zealand English', locale: 'en-NZ'),
  _HeyMediaInputLocale(id: 'en-IE', label: 'Irish English', locale: 'en-IE'),
  _HeyMediaInputLocale(id: 'en-ZA', label: 'South African English', locale: 'en-ZA'),
  _HeyMediaInputLocale(id: 'es-ES', label: 'Spanish (Spain)', locale: 'es-ES'),
  _HeyMediaInputLocale(id: 'fr-FR', label: 'French', locale: 'fr-FR'),
  _HeyMediaInputLocale(id: 'de-DE', label: 'German', locale: 'de-DE'),
  _HeyMediaInputLocale(id: 'it-IT', label: 'Italian', locale: 'it-IT'),
  _HeyMediaInputLocale(id: 'ja-JP', label: 'Japanese', locale: 'ja-JP'),
  _HeyMediaInputLocale(id: 'pt-BR', label: 'Brazilian Portuguese', locale: 'pt-BR'),
  _HeyMediaInputLocale(id: 'hi-IN', label: 'Hindi', locale: 'hi-IN'),
];

class HeyMediaScreen extends StatefulWidget {
  const HeyMediaScreen({super.key});

  @override
  State<HeyMediaScreen> createState() => _HeyMediaScreenState();
}

class _HeyMediaScreenState extends State<HeyMediaScreen> {
  final promptController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final MediaAiAssistantService _assistant = const MediaAiAssistantService();

  static const String _responseModePreferenceKey = 'hey_media_response_mode';
  static const String _outputVoicePreferenceKey = 'hey_media_output_voice';
  static const String _inputLocalePreferenceKey = 'hey_media_input_locale';
  List<Map<String, dynamic>> _availableTtsVoices = const [];
  _HeyMediaResponseMode _responseMode = _HeyMediaResponseMode.textAndVoice;
  String _selectedOutputVoiceId = 'en-us-female';
  String _selectedInputLocaleId = 'system';
  String? _voiceOutputStatus;
  bool _isSpeaking = false;

  List<MediaItem> results = const [];
  List<ShopProduct> productResults = const [];
  List<String> infoItems = const [];
  List<MediaAiPlanEntry> plan = const [];
  String? message;
  String? _voiceStatus;
  bool _isListening = false;
  bool _isAnswering = false;
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
    unawaited(_loadVoicePreferences());
  }

  @override
  void dispose() {
    promptController.dispose();
    if (_speech.isListening) unawaited(_speech.cancel());
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _loadVoicePreferences() async {
    String? savedMode;
    String? savedVoice;
    String? savedInputLocale;
    List<Map<String, dynamic>> parsedVoices = [];
    var ttsLookupFailed = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      savedMode = prefs.getString(_responseModePreferenceKey);
      savedVoice = prefs.getString(_outputVoicePreferenceKey);
      savedInputLocale = prefs.getString(_inputLocalePreferenceKey);
    } catch (_) {
      // The assistant can still be used without persistence.
    }

    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is Iterable) {
        for (final voice in rawVoices) {
          if (voice is Map) {
            parsedVoices.add(Map<String, dynamic>.from(voice));
          }
        }
      }
    } catch (_) {
      // Some platforms do not expose native text-to-speech voices.
      ttsLookupFailed = true;
    }

    final modes = _HeyMediaResponseMode.values.where(
      (value) => value.name == savedMode,
    );
    if (!mounted) return;
    setState(() {
      if (modes.isNotEmpty) _responseMode = modes.first;
      if (_heyMediaVoicePresets.any((voice) => voice.id == savedVoice)) {
        _selectedOutputVoiceId = savedVoice!;
      }
      if (_heyMediaInputLocales.any((locale) => locale.id == savedInputLocale)) {
        _selectedInputLocaleId = savedInputLocale!;
      }
      _availableTtsVoices = parsedVoices;
      if (ttsLookupFailed) {
        _voiceOutputStatus = 'This platform does not expose a selectable speech voice here. Text replies remain available.';
      }
    });
    await _configureOutputVoice(_selectedOutputVoice, announceStatus: true);
  }

  _HeyMediaVoicePreset get _selectedOutputVoice => _heyMediaVoicePresets.firstWhere(
        (voice) => voice.id == _selectedOutputVoiceId,
        orElse: () => _heyMediaVoicePresets.first,
      );

  String _normalizeLocale(String value) => value.replaceAll('_', '-').toLowerCase();

  String? _voiceGender(Map<String, dynamic> voice) {
    final declared = (voice['gender'] ?? '').toString().toLowerCase();
    if (declared.contains('female')) return 'female';
    if (declared.contains('male')) return 'male';
    final descriptor = '${voice['name'] ?? ''} ${voice['identifier'] ?? ''}'.toLowerCase();
    if (RegExp(r'\bfemale\b|\bwoman\b').hasMatch(descriptor)) return 'female';
    if (RegExp(r'\bmale\b|\bman\b').hasMatch(descriptor)) return 'male';
    return null;
  }

  bool _voiceSupportsLocale(Map<String, dynamic> voice, String locale) {
    final voiceLocale = _normalizeLocale(
      (voice['locale'] ?? voice['language'] ?? '').toString(),
    );
    final wanted = _normalizeLocale(locale);
    return voiceLocale == wanted || voiceLocale.startsWith('$wanted-');
  }

  Map<String, String> _ttsVoiceArguments(Map<String, dynamic> voice) {
    final result = <String, String>{};
    for (final key in const ['identifier', 'name', 'locale']) {
      final value = voice[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        result[key] = value.toString();
      }
    }
    return result;
  }

  Future<void> _configureOutputVoice(
    _HeyMediaVoicePreset preset, {
    bool announceStatus = true,
  }) async {
    try {
      if (_availableTtsVoices.isEmpty) {
        try {
          final rawVoices = await _tts.getVoices;
          if (rawVoices is Iterable) {
            _availableTtsVoices = rawVoices
                .whereType<Map>()
                .map((voice) => Map<String, dynamic>.from(voice))
                .toList();
          }
        } catch (_) {
          // Some platforms can speak but do not expose an installed-voice list.
        }
      }

      final localeVoices = _availableTtsVoices
          .where((voice) => _voiceSupportsLocale(voice, preset.locale))
          .toList();
      Map<String, dynamic>? selectedVoice;
      for (final voice in localeVoices) {
        if (_voiceGender(voice) == preset.gender) {
          selectedVoice = voice;
          break;
        }
      }

      var status = '';
      if (selectedVoice != null) {
        await _tts.setVoice(_ttsVoiceArguments(selectedVoice));
        final name = (selectedVoice['name'] ?? selectedVoice['identifier'] ?? preset.label).toString();
        status = 'Using installed voice: $name (${preset.locale}).';
      } else if (localeVoices.isNotEmpty && localeVoices.every((voice) => _voiceGender(voice) == null)) {
        selectedVoice = localeVoices.first;
        await _tts.setVoice(_ttsVoiceArguments(selectedVoice));
        status = 'Using an installed ${preset.locale} voice. This device does not report voice gender reliably, so the exact gender preference may not be available.';
      } else {
        await _tts.setLanguage(preset.locale);
        status = 'Preferred: ${preset.label}. If this exact voice is not installed, your device may use its default voice for ${preset.locale}. Add more voices in the device speech settings when available.';
      }
      if (announceStatus && mounted) setState(() => _voiceOutputStatus = status);
    } catch (_) {
      // A voice-selection API can be unavailable even when language-level TTS works.
      try {
        await _tts.setLanguage(preset.locale);
        if (announceStatus && mounted) {
          setState(() => _voiceOutputStatus = 'The exact voice could not be selected. The ${preset.locale} speech language was requested as a fallback; your device may use its default voice.');
        }
      } catch (_) {
        if (announceStatus && mounted) {
          setState(() => _voiceOutputStatus = 'Spoken output is not available on this platform. Text replies remain available.');
        }
      }
    }
  }

  Future<void> _saveVoicePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_responseModePreferenceKey, _responseMode.name);
    await prefs.setString(_outputVoicePreferenceKey, _selectedOutputVoiceId);
    await prefs.setString(_inputLocalePreferenceKey, _selectedInputLocaleId);
  }

  Future<void> _previewSelectedVoice() async {
    await _configureOutputVoice(_selectedOutputVoice);
    await _speakText(
      'Hello! I am Hey Media. This is a preview of your selected voice. What would you like to watch today?',
      reportErrors: true,
    );
  }

  Future<void> _speakText(String text, {bool reportErrors = false}) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text.trim());
    } catch (_) {
      if (reportErrors && mounted) {
        setState(() => _voiceOutputStatus = 'Speech playback failed on this device. You can continue using text replies.');
      }
    }
  }

  String _buildSpokenAnswer(
    String answer, {
    List<MediaItem> mediaItems = const [],
    List<ShopProduct> products = const [],
    List<String> infoItems = const [],
    List<MediaAiPlanEntry> schedule = const [],
  }) {
    final spoken = StringBuffer(answer.trim());
    if (schedule.isNotEmpty) {
      spoken.write(' Your schedule is. ');
      for (final entry in schedule) {
        spoken.write('Day ${entry.dayNumber}: ${entry.media.title}. ');
      }
    } else if (mediaItems.isNotEmpty) {
      spoken.write(' Here are the matching titles. ');
      for (final media in mediaItems.take(10)) {
        spoken.write('${media.title}. ');
      }
      if (mediaItems.length > 10) {
        spoken.write('I have displayed ${mediaItems.length - 10} more titles on screen.');
      }
    } else if (products.isNotEmpty) {
      spoken.write(' Here are related Store products. ');
      for (final product in products.take(6)) {
        spoken.write('${product.name}, ${product.price.toStringAsFixed(2)} ${product.currency}. ');
      }
      if (products.length > 6) spoken.write('More products are displayed on screen.');
    } else if (infoItems.isNotEmpty) {
      for (final item in infoItems.take(6)) {
        spoken.write('$item. ');
      }
    }
    return spoken.toString();
  }

  Future<void> _speakAnswer(
    String answer, {
    List<MediaItem> mediaItems = const [],
    List<ShopProduct> products = const [],
    List<String> infoItems = const [],
    List<MediaAiPlanEntry> schedule = const [],
  }) async {
    if (_responseMode == _HeyMediaResponseMode.textOnly) return;
    final text = _buildSpokenAnswer(
      answer,
      mediaItems: mediaItems,
      products: products,
      infoItems: infoItems,
      schedule: schedule,
    );
    await _configureOutputVoice(_selectedOutputVoice, announceStatus: false);
    await _speakText(text);
  }

  Future<void> _selectResponseMode(_HeyMediaResponseMode? mode) async {
    if (mode == null) return;
    setState(() => _responseMode = mode);
    await _saveVoicePreferences();
  }

  Future<void> _selectOutputVoice(String? voiceId) async {
    if (voiceId == null) return;
    setState(() {
      _selectedOutputVoiceId = voiceId;
      _voiceOutputStatus = 'Applying preferred voice…';
    });
    await _saveVoicePreferences();
    await _configureOutputVoice(_selectedOutputVoice);
  }

  Future<void> _selectInputLocale(String? localeId) async {
    if (localeId == null) return;
    setState(() => _selectedInputLocaleId = localeId);
    await _saveVoicePreferences();
  }

  Future<void> ask([String? suppliedPrompt]) async {
    final query = (suppliedPrompt ?? promptController.text).trim();
    if (query.isEmpty || _isAnswering) return;

    promptController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {
      _isAnswering = true;
      results = const [];
      productResults = const [];
      infoItems = const [];
      plan = const [];
      message = 'Checking your library and Store catalog…';
    });

    try {
      final reply = await _assistant.answer(query);
      if (!mounted) return;
      if (reply != null) {
        setState(() {
          results = reply.mediaItems;
          productResults = reply.products;
          infoItems = reply.infoItems;
          plan = reply.plan;
          message = reply.text;
          _isAnswering = false;
        });
        unawaited(_speakAnswer(
          reply.text,
          mediaItems: reply.mediaItems,
          products: reply.products,
          infoItems: reply.infoItems,
          schedule: reply.plan,
        ));
        return;
      }

      final matches = SmartSearch.search(query, AppController.instance.library);
      setState(() {
        results = matches;
        message = matches.isEmpty
            ? 'I didn’t find an exact match in the loaded account library. Try a title, actor, artist, album, genre, or a more specific question.'
            : 'I found ${matches.length} matching library item${matches.length == 1 ? '' : 's'}.';
        _isAnswering = false;
      });
      unawaited(_speakAnswer(
        matches.isEmpty
            ? 'I did not find an exact match in the loaded account library. Try a title, actor, artist, album, genre, or a more specific question.'
            : 'I found ${matches.length} matching library items.',
        mediaItems: matches,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        message = 'I couldn’t complete that request from the current catalog. $error';
        _isAnswering = false;
      });
      unawaited(_speakAnswer('I could not complete that request from the current catalog.'));
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isSpeaking) await _tts.stop();
    if (_speech.isListening || _isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _voiceStatus = 'Voice input stopped.';
        });
      }
      return;
    }

    setState(() => _voiceStatus = 'Requesting microphone access…');
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _speechInitialized = true;
            _isListening = status.toLowerCase() == 'listening';
            if (status.toLowerCase() == 'done' ||
                status.toLowerCase() == 'notlistening') {
              _isListening = false;
            }
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _voiceStatus = 'Voice input error: ${error.errorMsg}';
          });
        },
      );
      if (!mounted) return;
      _speechInitialized = available;
      if (!available) {
        setState(() {
          _isListening = false;
          _voiceStatus = 'Speech recognition is unavailable on this device or browser. You can still type your question.';
        });
        return;
      }

      String? recognitionLocaleId;
      final selectedInput = _heyMediaInputLocales.firstWhere(
        (locale) => locale.id == _selectedInputLocaleId,
        orElse: () => _heyMediaInputLocales.first,
      );
      var localeFallbackNotice = '';
      if (selectedInput.locale != null) {
        try {
          final installedLocales = await _speech.locales();
          final wanted = _normalizeLocale(selectedInput.locale!);
          for (final locale in installedLocales) {
            if (_normalizeLocale(locale.localeId) == wanted ||
                _normalizeLocale(locale.localeId).startsWith('$wanted-')) {
              recognitionLocaleId = locale.localeId;
              break;
            }
          }
        } catch (_) {
          // Continue with the default recognizer if locale enumeration is unsupported.
        }
        if (recognitionLocaleId == null) {
          localeFallbackNotice = ' ${selectedInput.label} recognition is not listed on this device, so I will use its default language.';
        }
      }

      setState(() {
        _isListening = true;
        _voiceStatus = 'Listening. Say “Hey Media…” followed by your question.$localeFallbackNotice';
      });
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final recognized = result.recognizedWords.trim();
          setState(() {
            if (recognized.isNotEmpty) {
              promptController.value = TextEditingValue(
                text: recognized,
                selection: TextSelection.collapsed(offset: recognized.length),
              );
            }
          });
          if (result.finalResult && recognized.isNotEmpty) {
            unawaited(_finishVoiceRequest(recognized));
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          localeId: recognitionLocaleId,
          contextualPhrases: const [
            'Hey Media',
            'movie marathon',
            'Christmas movies',
            'TV show',
            'latest album',
            'Store catalog',
            'How I Met Your Mother',
          ],
        ).copyWith(
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _voiceStatus = 'Could not start voice input: $error';
      });
    }
  }

  Future<void> _finishVoiceRequest(String recognized) async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _voiceStatus = 'Heard: “$recognized”';
    });
    await ask(recognized);
  }

  void usePrompt(String value) {
    promptController.text = value;
    ask(value);
  }

  void _openMedia(MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media)),
    );
  }

  void _addProductToBag(ShopProduct product) {
    ShopCatalog.instance.addToBag(product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${product.name} to your Store bag.')),
    );
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hey Media'),
        actions: [
          IconButton(
            tooltip: 'Open universal search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SmartSearchScreen()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 32),
                      SizedBox(width: 10),
                      Text('Hey Media', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Type a question or use the microphone. Ask what you have not watched, plan a movie marathon, find Store gifts, or ask about your music library. Choose text, spoken replies, and a preferred voice below. Answers use the data loaded for your account; missing information is not guessed.',
                    style: TextStyle(color: Colors.white60, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: promptController,
                    onSubmitted: (_) => ask(),
                    decoration: InputDecoration(
                      hintText: 'Ask Hey Media…',
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _isAnswering ? null : _toggleVoiceInput,
                            tooltip: _isListening ? 'Stop voice input' : 'Speak to Hey Media',
                            icon: Icon(
                              _isListening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                              color: _isListening ? Colors.redAccent : null,
                            ),
                          ),
                          IconButton(
                            onPressed: _isAnswering ? null : () => ask(),
                            tooltip: 'Ask Hey Media',
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_voiceStatus != null) ...[
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isListening ? Icons.mic_rounded : Icons.info_outline_rounded,
                          size: 17,
                          color: _isListening ? Colors.redAccent : Colors.white54,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _voiceStatus!,
                            style: TextStyle(
                              color: _isListening ? Colors.redAccent : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      leading: const Icon(Icons.record_voice_over_rounded),
                      title: const Text('Voice & response preferences'),
                      subtitle: const Text('Choose text, speech, accent, and microphone language'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        DropdownButtonFormField<_HeyMediaResponseMode>(
                          initialValue: _responseMode,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Response mode'),
                          items: _HeyMediaResponseMode.values
                              .map((mode) => DropdownMenuItem<_HeyMediaResponseMode>(
                                    value: mode,
                                    child: Text(mode.label),
                                  ))
                              .toList(),
                          onChanged: _selectResponseMode,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedOutputVoiceId,
                          isExpanded: true,
                          menuMaxHeight: 420,
                          decoration: const InputDecoration(labelText: 'Spoken response voice'),
                          items: _heyMediaVoicePresets
                              .map((voice) => DropdownMenuItem<String>(
                                    value: voice.id,
                                    child: Text(voice.label, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: _selectOutputVoice,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedInputLocaleId,
                          isExpanded: true,
                          menuMaxHeight: 420,
                          decoration: const InputDecoration(labelText: 'Microphone recognition accent/language'),
                          items: _heyMediaInputLocales
                              .map((locale) => DropdownMenuItem<String>(
                                    value: locale.id,
                                    child: Text(locale.label, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: _selectInputLocale,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _previewSelectedVoice,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Preview voice'),
                              ),
                            ),
                            if (_isSpeaking) ...[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'Stop speaking',
                                onPressed: () => unawaited(_tts.stop()),
                                icon: const Icon(Icons.stop_rounded),
                              ),
                            ],
                          ],
                        ),
                        if (_voiceOutputStatus != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _voiceOutputStatus!,
                              style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available voices depend on the operating system, installed speech packs, and browser. Hey Media chooses a matching installed voice where possible; missing gender/accent support may fall back to the device voice. The selected voice does not translate the answer text—full multilingual answers require a translation/AI service. Microphone language is set separately.',
                            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _promptChip('What movie or TV show haven’t I seen?'),
                      _promptChip('Make me a 31-day October movie marathon'),
                      _promptChip('Plan 25 days of Christmas movies'),
                      _promptChip('Find a gift for a How I Met Your Mother fan'),
                      _promptChip('What’s the latest album on my server?'),
                      _promptChip('Find horror movies'),
                    ],
                  ),
                  if (!_speechInitialized && _voiceStatus == null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Voice input is push-to-talk. Microphone support depends on the device and browser; always-on wake-word listening is not enabled.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message != null &&
              (_responseMode != _HeyMediaResponseMode.voiceFocused || _isAnswering)) ...[
            const SizedBox(height: 16),
            if (_isAnswering)
              const Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Checking your library and Store catalog…', style: TextStyle(color: Colors.white70))),
                ],
              )
            else
              Text(message!, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
          if (plan.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Text('Your marathon schedule', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                    for (final entry in plan)
                      ListTile(
                        leading: CircleAvatar(child: Text('${entry.dayNumber}')),
                        title: Text(entry.media.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if (entry.calendarDate != null) _formatDate(entry.calendarDate!),
                          if (entry.media.releaseYear != null) '${entry.media.releaseYear}',
                          entry.media.type,
                        ].join(' • ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openMedia(entry.media),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            for (final media in results) _mediaCard(media),
          ],
          if (productResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Related Store products', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            for (final product in productResults) _productCard(product),
          ],
          if (infoItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Albums found in your library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            for (final album in infoItems)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.album_rounded),
                  title: Text(album),
                ),
              ),
          ],
          if (results.isEmpty && productResults.isEmpty && infoItems.isEmpty && plan.isEmpty && message == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline_rounded),
                title: Text('Try asking for unwatched movies, a marathon, gift recommendations, or your latest album.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaCard(MediaItem media) => Card(
        child: ListTile(
          leading: media.imageUrl == null || media.imageUrl!.isEmpty
              ? const Icon(Icons.play_circle_outline_rounded)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    media.imageUrl!,
                    width: 44,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline_rounded),
                  ),
                ),
          title: Text(media.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            media.type,
            if (media.releaseYear != null) '${media.releaseYear}',
          ].join(' • ')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openMedia(media),
        ),
      );

  Widget _productCard(ShopProduct product) {
    final image = product.imageUrls.isEmpty ? '' : product.imageUrls.first;
    Widget leading;
    if (image.startsWith('data:image/')) {
      try {
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(image.substring(image.indexOf(',') + 1)),
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        leading = const Icon(Icons.shopping_bag_outlined);
      }
    } else if (image.startsWith('http://') || image.startsWith('https://')) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          image,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
        ),
      );
    } else {
      leading = const Icon(Icons.shopping_bag_outlined);
    }

    final storeName = ShopCatalog.instance.storeById(product.storeId)?.name ?? 'Store';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 62, height: 62, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('$storeName • ${product.category}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text('${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(product.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add to Store bag',
              onPressed: product.inventoryQuantity <= 0 ? null : () => _addProductToBag(product),
              icon: const Icon(Icons.add_shopping_cart_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promptChip(String value) => ActionChip(
        avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(value),
        onPressed: () => usePrompt(value),
      );
}
