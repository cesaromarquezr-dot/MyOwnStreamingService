// FILE: `lib/supabase_config.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains application logic, UI, or API coordination.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional Supabase configuration.
/// Pass values with:
/// --dart-define=SUPABASE_URL=https://...
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=...
/// Legacy SUPABASE_ANON_KEY is accepted as a fallback during migration.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
}
