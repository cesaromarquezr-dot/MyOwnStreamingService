import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
/// Optional Supabase configuration.
///
/// Primary configuration is the project-root .env file:
/// SUPABASE_URL=https://your-project.supabase.co
/// SUPABASE_PUBLISHABLE_KEY=...
///
/// Existing --dart-define settings and legacy SUPABASE_ANON_KEY remain supported.
class SupabaseConfig {
  /// Project URL loaded from .env, with dart-define as a fallback.
  static String get url => AppEnv.supabaseUrl;

  /// Client publishable/anon key. Never use a service-role key in Flutter.
  static String get publishableKey => AppEnv.supabasePublishableKey;

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