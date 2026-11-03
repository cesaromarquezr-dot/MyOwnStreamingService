# Franchise Story Graph & Timeline

This patch adds story-graph and timeline navigation to the franchise/universe browse flow.

## UI entry points

- **Franchises / Cinematic Universes** browse hub: `Connections Graph & Timeline` opens global search.
- A franchise, saga, universe, or continuity details screen: `Full connections graph` and `Timeline` open the selected group.

## Explorer behavior

- Search by character, franchise, title, or universe.
- Switch between graph and timeline views.
- Choose **All continuities**, **MCU**, **Multiverse**, or **Spider-Verse** for Spider-Man examples.
- Timeline can use **Release order** or **Story chronology**. Catalog story-order fields are used when they exist; otherwise release/order metadata is a fallback.
- Select a title node to open its catalog detail page when a matching accessible catalog record exists.
- Example nodes not present in the catalog remain visible but explain that they cannot yet open a local detail page.
- Generic franchise graphs use the active profile's catalog and explicit `narrativePrerequisiteIds` relationships where available. Shared franchise membership is not represented as proof that two titles have a direct plot dependency.
- User-defined connections saved from the Details page are loaded into the graph as labeled manual edges. Catalog title search and group views follow accessible manual links transitively; links without an unambiguous accessible target remain in Details but are not drawn as catalog edges.
- Details supports a separate manual story placement (year, order, label, and note). Timeline story chronology prefers that placement, then verified catalog chronology, and labels manual placements separately from release order.
- Matching character metadata remains a suggested overlap section, not a user-authored relationship.

The included curated examples are Wanda Maximoff's MCU path and Spider-Man paths for the live-action multiverse, the animated Spider-Verse, and the MCU. They are starter paths, not an exhaustive provider-verified filmography. Full coverage depends on catalog/provider metadata being populated and verified.

## Verification

Validation performed from the project root:

```powershell
flutter analyze --no-fatal-infos
flutter test
```

Both commands passed. Hot restart could not be exercised because no Flutter app was connected to the Dart Tooling Daemon.
