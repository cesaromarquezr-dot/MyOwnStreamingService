# Physical Collections module

The feature's public API is exported by `collections.dart`. Its canonical
models, repository, profile-aware store, collection screens and box widget
remain in the shared app layers (`models/`, `data/`, `stores/`, `screens/` and
`widgets/`).

A physical release groups discs; each disc groups ordered playable programs.
Programs remain individual library records, so a TV-special edition can
contain several independent specials without duplicating media metadata.
