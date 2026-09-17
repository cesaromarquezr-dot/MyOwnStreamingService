// FILE: `lib/media_ai.dart`.
// Purpose: Defines the privacy-first AI feature contract used by the UI.

class MediaAiIntent {
  final String prompt;
  final String scope;
  final bool mayModifyData;
  const MediaAiIntent({required this.prompt, this.scope = 'personal-library', this.mayModifyData = false});
  Map<String, dynamic> toJson() => {'prompt': prompt, 'scope': scope, 'mayModifyData': mayModifyData};
}

class MediaAiPolicy {
  static const String principle = 'AI explains and suggests; destructive or consequential library changes require explicit user approval.';
  static const List<String> supportedIntents = [
    'recommend', 'explain-similarity', 'search-library', 'complete-collection',
    'build-media-session', 'discover-connections', 'surprise-me', 'summarize-history',
  ];
}
