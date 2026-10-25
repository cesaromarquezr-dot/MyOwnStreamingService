import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central access to Flutter-side configuration.
///
/// Priority:
/// 1. Values from the local .env file.
/// 2. Values passed using --dart-define.
/// 3. Safe defaults, where available.
///
/// IMPORTANT: Flutter client configuration is extractable from a compiled app.
/// Never put server-only credentials in this file or the client .env file.
class AppEnv {
  AppEnv._();

  static String _fileValue(String key) {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env[key] ?? '').trim();
  }

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    return '';
  }

  /// TMDB API key.
  static String get tmdbApiKey => _firstNonEmpty([
        _fileValue('TMDB_API_KEY'),
        const String.fromEnvironment('TMDB_API_KEY'),
      ]);

  /// Supabase project API URL.
  static String get supabaseUrl => _firstNonEmpty([
        _fileValue('SUPABASE_URL'),
        const String.fromEnvironment('SUPABASE_URL'),
      ]);

  /// Supabase publishable key or legacy anon key.
  static String get supabasePublishableKey => _firstNonEmpty([
        _fileValue('SUPABASE_PUBLISHABLE_KEY'),
        _fileValue('SUPABASE_ANON_KEY'),
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      ]);

  /// MyOwnStreamingService backend base URL.
  static String get backendApiUrl => _firstNonEmpty([
        _fileValue('BACKEND_API_URL'),
        const String.fromEnvironment('BACKEND_API_URL'),
        'https://127.0.0.1:8080/api/v1',
      ]);
}
