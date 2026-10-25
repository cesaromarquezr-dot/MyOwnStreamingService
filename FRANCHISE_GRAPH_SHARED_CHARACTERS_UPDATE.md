# Franchise Graph: Shared Character Connections

The franchise/universe detail page exposes separate **Full connections graph** and **Timeline** buttons. The graph now includes title-to-title arrows for explicit narrative prerequisite metadata and additional links when two catalog titles contain the same normalized character name in their `characters` metadata. Selecting a shared-character link lists the matched characters and offers navigation to both titles' detail pages.

Important data boundary: the graph only draws shared-character links when character names are present in the catalog. It does not infer fictional-character identity from actors' names, and it does not treat shared franchise membership as proof of a direct story dependency. If the metadata is missing, the UI explains why no direct links are shown.

Validation: ZIP structure/integrity can be checked locally, but run `flutter analyze` and `flutter test` in a Flutter SDK environment before merging; the current environment does not have Flutter/Dart available.
