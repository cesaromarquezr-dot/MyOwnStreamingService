import 'package:supabase_flutter/supabase_flutter.dart';
/// Optional Supabase configuration.
///
/// Pass values with:
/// --dart-define=SUPABASE_URL=https://your-project.supabase.co
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// Legacy SUPABASE_ANON_KEY is accepted as a fallback during migration.
class SupabaseConfig {
  /// Supabase project URL.
  ///
  /// Example:
  /// https://your-project.supabase.co
  ///
  /// Do not include `/rest/v1/`.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase publishable key.
  ///
  /// Falls back to the legacy SUPABASE_ANON_KEY environment variable
  /// during migration.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  /// Whether the required Supabase configuration is available.
  static bool get isConfigured =>
      url.isNotEmpty && publishableKey.isNotEmpty;

  /// Initialize Supabase when configuration is available.
  ///
  /// When no configuration is supplied, initialization is skipped so
  /// the application can continue operating without Supabase.
  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  /// Returns the initialized Supabase client when configured.
  ///
  /// Returns null when Supabase configuration has not been supplied.
  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
}