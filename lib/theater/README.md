# Private Theater module

The feature's public API is exported by `theater.dart`. Its screens, models,
repository, profile-scoped store, seat map and private screening pass widgets
live in the app's shared `screens/`, `models/`, `data/`, `stores/` and
`widgets/` layers so existing routing and playback services remain canonical.

Theater sessions reference titles already owned by the selected profile.
Showtimes and seats are at-home planning tools; there are no paid admissions.
