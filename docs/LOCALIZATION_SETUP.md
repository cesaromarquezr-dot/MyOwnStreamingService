# App-wide language and media metadata localization

## What this patch changes

- The root `MaterialApp` now tracks `LanguageController` changes and updates its Flutter locale/delegates immediately.
- Existing `UniversalText` widgets first use the built-in phrase translations, then request a cached translation from the optional `translate-text` Supabase Edge Function. If the function/provider is unavailable, the original/built-in fallback is shown.
- Disc-imported movie titles and music track/album titles in the main playback/library paths use `LocalizedMediaText`. The original imported metadata is never overwritten; translations are cached separately per target language on the device. Additional catalog surfaces use this component where their titles are rendered.
- Most simple, app-authored static `Text('...')` labels in `lib/` have been migrated to `UniversalText`, which reacts to language changes. Dynamic interpolated text, metadata/user-generated text, form-field decoration labels, some semantic/accessibility strings, and server-provided messages require explicit review rather than a blind string rewrite.
- Language selection remains profile-specific in local SharedPreferences, with a global fallback before a profile is selected.

## Enable automatic translation

1. Deploy a trusted translation provider such as a self-hosted LibreTranslate service on TrueNAS. Restrict its network access and configure authentication/rate limits as appropriate.
2. Deploy `supabase/functions/translate-text/index.ts` as a Supabase Edge Function named `translate-text` with JWT verification enabled.
3. Configure function secrets:

   ```sh
   supabase secrets set TRANSLATE_API_URL=https://your-private-translation-service.example
   supabase secrets set TRANSLATE_API_KEY=your-provider-key
   supabase functions deploy translate-text
   ```

   Omit `TRANSLATE_API_KEY` only if the translation service is private and does not require one. Never place provider secrets in Flutter/client code.
4. Test a language switch with network access and confirm a missing translation falls back safely.

## Important metadata rules

- Keep source title/description, source language, and translated text as distinct fields in the catalog. Never replace the only copy of the ripped disc's original metadata.
- Prefer licensed/trusted metadata-provider translations where available. Machine translation is a fallback and may mistranslate proper nouns, artist names, franchise titles, or technical track labels.
- Use `LocalizedMediaText(original, sourceLanguage: 'ja')` when the source language is known. Leave `sourceLanguage` null when it is unknown.
- Use `UniversalText` for app-authored labels and messages. The app-wide static-label migration is broad but not complete: review `TextField`/`InputDecoration` labels, validation messages, interpolation-heavy strings, menu semantics, and server-provided text. Keep usernames, creator text, artist names, and original media metadata separate from app UI translations.
- Keep subtitle/audio-track selection based on the actual track language; translate only the UI labels around those tracks, not the media itself.

## Validation

`flutter analyze` should be run in a Flutter-enabled development environment after applying this patch. This workspace did not have the Flutter CLI available, so no successful analyzer/build result is claimed.
