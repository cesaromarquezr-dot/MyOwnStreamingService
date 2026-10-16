# Hey Marathon

Hey Marathon helps a profile build a timed movie or TV marathon from the existing media library.

## Current feature set

- Select library titles and expand TV series into episode entries from imported season metadata.
- Keep known episodes in canonical season/episode order; show titles with missing numbering as needing review and block saving until those entries are corrected or removed.
- Use known episode runtime metadata where available and clearly mark default/guessed runtimes. Runtimes can be edited in the planner.
- Schedule a local start date/time and configurable breaks, including an estimated finish time.
- Save plans on-device per profile using SharedPreferences.
- Share an invitation/schedule through the platform share sheet.
- Open Hey Eats with the marathon title/theme passed as order context; the customer still chooses items and confirms checkout in the food flow.
- Use the existing backend Group Watch API to create a synchronized session for the first library title. The current Group Watch model synchronizes a single title, not an entire multi-title playlist.
- Suggest fan-inspired food ideas for wizarding-fantasy, superhero, anime, cozy-cinema, and custom themes. Suggestions are not represented as official/licensed items. Restaurants remain the source of truth for ingredients/allergen answers.

## Entry point

Open **More → Hey Marathon**.

## Validation

Run from the Flutter project root:

```powershell
flutter test test/hey_marathon_logic_test.dart
flutter analyze
```

Saved plans are currently local to a profile/device; cross-device plan sync and structured invitations are follow-up work. The planner only has exact runtime when the source metadata provides it or a user corrects the estimate.
