import 'package:supabase_flutter/supabase_flutter.dart';
/// Optional Supabase configuration.
///
/// Pass values with:
/// --dart-define=SUPABASE_URL=https://...
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// Legacy SUPABASE_ANON_KEY is accepted as a fallback during migration.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'https://kpznsbxxgziynqpxydki.supabase.co/rest/v1/',
    defaultValue: '',
  );

  static const publishableKey = String.fromEnvironment(
    'sb_publishable_0-VjCDmWz7XDUCWQFipTdA_FE_3qGn5',
    defaultValue: String.fromEnvironment(
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtwem5zYnh4Z3ppeW5xcHh5ZGtpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyNjg2NTksImV4cCI6MjEwNDg0NDY1OX0.dmxigYpcf_O0D_ajw3uSVigZ-LwVUhgkBnHRAfRzmvM',
      defaultValue: '',
    ),
  );

  static bool get isConfigured =>
      url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
}