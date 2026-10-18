# Public Live TV: per-profile personalization

Public Live TV preferences are stored in `SharedPreferences` using the active `AppController` profile ID. Profiles on the same device therefore keep separate country and preferred-genre selections, as well as the existing per-profile channel favorites.

## User controls
- Choose a default country playlist.
- Select preferred genres such as news, sports, movies, music, documentary, kids, education, weather, entertainment, culture, business, science, travel and general.
- Save country and genre preferences for the active profile.
- Use genre quick-browse chips to load the matching IPTV-org category playlist.
- Return to the selected country's channel list with Browse my country.
- Continue to search channels, filter groups and maintain channel favorites.

## Data and limitations
Preferences and favorites are device-local `SharedPreferences`, not synchronized between devices or stored in a server account. IPTV-org is a public directory of external stream addresses; channel availability, regional restrictions, playback support and rights vary. The app does not host channels or bypass paywalls/access controls. Country and genre options are curated UI options and can be expanded as the upstream directory evolves.
