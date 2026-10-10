# Hey Media — smarter library and voice requests

Hey Media now resolves several common natural-language requests locally against the signed-in profile's loaded catalog:

- **Unwatched movies and TV shows** — checks the current profile's watched list and playback progress, and respects explicit profile access rules.
- **Movie marathons** — creates a dated calendar plan when a month is named (for example, October). October/Halloween requests prioritize horror, thriller, supernatural and related titles while still using only movies in the library.
- **Christmas marathons** — searches the actual library for titles whose metadata/title identifies Christmas or holiday content. It never invents titles or repeats films to fill a 25-day plan; it explains when fewer matches exist.
- **Gift ideas** — matches requested fandoms to active, in-stock products in the Store catalog and shows actual prices/inventory. It does not make up external retailer products.
- **Latest album** — uses recorded album release years when available. Otherwise it can identify the album folder with the newest file-modified timestamp if the scanner has album folder information; it labels that as file freshness, not an official release date.
- **General title/genre searches** — continue to use the existing local Smart Search.

## Example prompts

- `Hey Media, what movie or TV show haven't I seen?`
- `Hey Media, make me a 31-day movie marathon for October.`
- `Hey Media, plan 25 days of Christmas movies.`
- `Hey Media, find a gift for a friend who's a big fan of How I Met Your Mother.`
- `Hey Media, what's the latest album on my server?`

## Voice input

The Hey Media screen includes a microphone button for **push-to-talk** short commands. The recognized text is inserted into the prompt field and then handled by the same local resolver. The Android manifest already contained microphone permission; the update adds speech-recognition discovery and internet permission. iOS/macOS usage descriptions and the macOS audio-input entitlement are also configured.

This is not an always-listening wake-word service. The user taps the microphone first and may then say “Hey Media” plus a request. The `speech_to_text` plugin uses the host platform's recognition service and has platform/browser limitations; Linux speech recognition is not supported by this plugin, and browser support varies. A TV remote's built-in microphone is not automatically exposed to every Flutter TV app: platform-specific remote/OS integration may be required.

## Server album metadata

The home-server scanner now includes each file's UTC modification timestamp. For music, it conservatively infers album/artist names from common folder layouts such as `Artist/Album/Track.ext` (also beneath roots such as `Music/Artist/Album/Track.ext`). It does not infer a release year from a filesystem timestamp. Re-run the server library sync to load these fields into the client.

If the music directory is flat or the album/artist folder structure is missing, the assistant will say it cannot reliably identify the newest album rather than selecting one at random.

## Install and run

After updating the project files:

```powershell
flutter pub get
flutter analyze
```

For macOS, refresh the native dependencies as required by your local Flutter setup, then build/run from Xcode when testing microphone permission prompts. On web, grant microphone permission and use a browser that implements the Web Speech API; local development should use `localhost` or HTTPS.

## Scope and privacy

These behaviors are a local intent resolver, not a connection to a hosted large language model. Queries use the current in-memory library and locally loaded Store catalog; no additional third-party AI request is made. For current catalog accuracy, sync the server library before asking. A future generative-model integration should remain behind an explicit provider boundary and must keep profile permissions and the “do not invent catalog facts” policy.

## Text replies, spoken replies, and accent preferences

Hey Media supports typed prompts and push-to-talk microphone prompts. The response preference can be set to:

- **Text only** — answers and result cards remain on screen.
- **Text + voice** — answer text and result cards are shown, and the answer is read aloud.
- **Voice-focused** — the spoken response is emphasized while useful result cards and schedules remain visible.

The **Voice & response preferences** control saves the response mode, preferred spoken voice, and microphone recognition language using device-local preferences. The output voice menu includes British, American, Mexican Spanish, Australian, Korean, Argentinian Spanish, Canadian, and other regional voice preferences, with female/male variants. The input-language menu separately chooses the speech-recognition locale. The selected output voice is not itself a translation system: full responses in another language require a translation-capable AI/provider or localized answer templates, which have not been connected yet.

Voice choices are preferences rather than guaranteed built-in recordings. Hey Media asks the operating system/browser for installed voices and selects a matching region/gender when that metadata is exposed. If a device lacks the selected voice or does not provide gender metadata, it tries the selected language and explains that the system may use its default voice. Install additional voices in the device's speech settings when available. The **Preview voice** control tests the selected output voice.

Text-to-speech is provided by `flutter_tts` and supports Android, iOS, macOS, web, and Windows; Linux is not supported by that plugin, so the app remains usable in text mode there. Microphone recognition support is separately platform-dependent. A TV app cannot assume the physical remote's microphone is available without the TV platform's permission and remote-input integration. This is push-to-talk, not always-listening wake-word detection.

After updating dependencies, run:

```powershell
flutter pub get
flutter analyze
```

Test the exact accents on each target device because the available native voices vary by operating system, browser, locale, installed speech packs, and TTS engine.
