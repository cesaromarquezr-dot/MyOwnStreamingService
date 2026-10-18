# Home: Other Profiles' Recent Activity

The Home center keeps the active profile's Continue Watching and Recently Watched sections private and separate. Below them, it can show recent media activity from other profiles in the same account when those profiles have enabled activity sharing.

Each activity section and profile card uses the profile's actual display name, not ordinal labels such as "User 2". Display names are resolved from the profile/activity API response, with a fallback lookup against the current account's profile objects when the API omits a name. Profile IDs remain the stable identity key; names are display-only and may change.

Supported activity metadata includes movie titles, TV show/season/episode details, and song titles/artists when supplied by the activity API. The client checks profile sharing preferences, but the backend must independently enforce same-account access and activity-sharing permissions. If a profile has disabled sharing, its activity must not be returned by the server.

Validation: archive integrity can be checked, but Flutter/Dart analysis and runtime UI tests require a Flutter SDK environment.
