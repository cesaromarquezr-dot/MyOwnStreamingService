import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'localization.dart';

/// Localizes imported/ripped media metadata without overwriting the source.
///
/// The client calls the optional Supabase Edge Function `translate-text`.
/// When it is not deployed or the translation provider is unavailable, the
/// original metadata is returned so the library remains usable offline.
class MediaTextLocalizer {
  MediaTextLocalizer._();
  static final instance = MediaTextLocalizer._();

  final Map<String, String> _memoryCache = <String, String>{};
  final Map<String, Future<String>> _inFlightTranslations =
      <String, Future<String>>{};
  final Queue<Completer<void>> _requestWaiters = Queue<Completer<void>>();
  int _activeRequests = 0;
  static const int _maxConcurrentRequests = 4;

  String _cacheKey(String text, String language) =>
      'media_translation_v1_${language}_${base64Url.encode(utf8.encode(text))}';

  Future<String> translate(
    String original, {
    String? sourceLanguage,
    String? targetLanguage,
  }) async {
    final text = original.trim();
    if (text.isEmpty) return original;

    final target = targetLanguage ?? LanguageController.instance.current.code;
    if (target == 'en' && (sourceLanguage == null || sourceLanguage == 'en')) {
      return original;
    }
    if (sourceLanguage == target) return original;

    final key = _cacheKey(text, target);
    final inMemory = _memoryCache[key];
    if (inMemory != null) return inMemory;

    final pending = _inFlightTranslations[key];
    if (pending != null) return pending;

    final future = _translateUncached(
      original: original,
      text: text,
      key: key,
      sourceLanguage: sourceLanguage,
      targetLanguage: target,
    );
    _inFlightTranslations[key] = future;
    try {
      return await future;
    } finally {
      _inFlightTranslations.remove(key);
    }
  }

  Future<String> _translateUncached({
    required String original,
    required String text,
    required String key,
    required String? sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(key);
      if (saved != null && saved.isNotEmpty) {
        _memoryCache[key] = saved;
        return saved;
      }
    } catch (_) {
      // Preferences are an optimization; translation may still proceed.
    }

    try {
      final response = await _withRequestLimit(() =>
          Supabase.instance.client.functions.invoke(
            'translate-text',
            body: <String, dynamic>{
              'text': text,
              'source': sourceLanguage ?? 'auto',
              'target': targetLanguage,
            },
          ));
      final data = response.data;
      if (data is Map) {
        final translated = data['translatedText']?.toString().trim();
        if (translated != null && translated.isNotEmpty) {
          _memoryCache[key] = translated;
          try {
            final preferences = await SharedPreferences.getInstance();
            await preferences.setString(key, translated);
          } catch (_) {
            // Keep the in-memory result even if disk caching is unavailable.
          }
          return translated;
        }
      }
    } catch (_) {
      // No network, no function deployment, or provider failure: preserve text.
    }

    return original;
  }

  /// Bound translation traffic so switching to a language with an empty cache
  /// cannot fan out hundreds of simultaneous requests from a large screen.
  Future<T> _withRequestLimit<T>(Future<T> Function() action) async {
    if (_activeRequests >= _maxConcurrentRequests) {
      final waiter = Completer<void>();
      _requestWaiters.addLast(waiter);
      await waiter.future;
    } else {
      _activeRequests++;
    }

    try {
      return await action();
    } finally {
      if (_requestWaiters.isNotEmpty) {
        _requestWaiters.removeFirst().complete();
      } else {
        _activeRequests--;
      }
    }
  }

  /// Clears cached translations when the user requests a fresh translation.
  Future<void> clearMemoryCache() async => _memoryCache.clear();
}

/// A metadata field that refreshes when the app language changes.
/// Use for disc-imported titles, synopses, episode names, chapters, genres,
/// and other human-readable metadata. Pass the original value, never a prior
/// translated value, to avoid translating a translation repeatedly.
class LocalizedMediaText extends StatefulWidget {
  final String original;
  final String? sourceLanguage;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const LocalizedMediaText(
    this.original, {
    super.key,
    this.sourceLanguage,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<LocalizedMediaText> createState() => _LocalizedMediaTextState();
}

class _LocalizedMediaTextState extends State<LocalizedMediaText> {
  late Future<String> _translation;
  String _language = '';

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_languageChanged);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LocalizedMediaText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.original != widget.original ||
        oldWidget.sourceLanguage != widget.sourceLanguage) {
      _refresh();
    }
  }

  void _languageChanged() {
    if (_language != LanguageController.instance.current.code) {
      setState(_refresh);
    }
  }

  void _refresh() {
    _language = LanguageController.instance.current.code;
    _translation = MediaTextLocalizer.instance.translate(
      widget.original,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: _language,
    );
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_languageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _translation,
        builder: (context, snapshot) => Text(
          snapshot.data ?? widget.original,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
        ),
      );
}
