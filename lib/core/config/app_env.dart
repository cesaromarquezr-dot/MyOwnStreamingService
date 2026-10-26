import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central access to Flutter-side configuration.
/// Values in the local .env file override --dart-define values.
/// Never put server-only credentials in this client config: Flutter assets are extractable.
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

  static String get supabaseUrl => _firstNonEmpty(<String>[
        _fileValue('SUPABASE_URL'),
        const String.fromEnvironment('SUPABASE_URL'),
      ]);

  static String get supabasePublishableKey => _firstNonEmpty(<String>[
        _fileValue('SUPABASE_PUBLISHABLE_KEY'),
        _fileValue('SUPABASE_ANON_KEY'),
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      ]);

  static String get backendApiUrl => _firstNonEmpty(<String>[
        _fileValue('BACKEND_API_URL'),
        const String.fromEnvironment('BACKEND_API_URL'),
        'https://127.0.0.1:8080/api/v1',
      ]);
}
