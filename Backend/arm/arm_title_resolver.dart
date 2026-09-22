// FILE: `Backend/arm/arm_title_resolver.dart`.
// Purpose: Resolves ARM-detected/localized disc titles into canonical media
// identities while preserving the original physical-disc title.
//
// This file is part of the documented Flutter/home-server architecture.
//
// Identity rule:
//
//   Physical Disc Title
//          |
//          v
//   Canonical Media Title
//
// The physical disc title is never discarded. It remains available through
// ArmDiscTitle.discTitle and metadata so that the physical release/edition can
// still be represented accurately.
//
// This resolver intentionally does not decide whether a disc is a movie,
// bonus disc, soundtrack, album, or compilation. Those decisions belong to
// the ARM media models/service layer.

import 'arm_models.dart';

class ArmCanonicalTitle {
  final String canonicalTitle;
  final String originalLanguage;
  final String countryOfOrigin;

  const ArmCanonicalTitle(
    this.canonicalTitle,
    this.originalLanguage,
    this.countryOfOrigin,
  );
}

class ArmTitleResolver {
  /// Known localized or alternate physical-disc titles.
  ///
  /// The key is normalized before lookup, so differences in capitalization,
  /// surrounding whitespace, and common punctuation do not prevent a match.
  static const _aliases = <String, ArmCanonicalTitle>{
    'vecinos invasores': ArmCanonicalTitle(
      'Over the Hedge',
      'English',
      'United States',
    ),
    'over the hedge': ArmCanonicalTitle(
      'Over the Hedge',
      'English',
      'United States',
    ),
  };

  const ArmTitleResolver();

  /// Resolves a title into its canonical media identity.
  ///
  /// The original ARM/disc title remains available in [ArmDiscTitle.discTitle]
  /// and in metadata. This prevents a localized physical release from being
  /// mistaken for a completely different title.
  ArmDiscTitle resolve(
    ArmDiscTitle title,
  ) {
    final discTitle = _resolveDiscTitle(title);

    final key = _normalizeTitle(discTitle);

    if (key.isEmpty) {
      return title;
    }

    final known = _aliases[key];

    if (known == null) {
      return _preserveOriginalTitle(
        title,
        discTitle,
      );
    }

    return _applyCanonicalResolution(
      title,
      discTitle,
      known,
    );
  }

  /// Returns the physical/disc title that should be used for alias lookup.
  ///
  /// ARM may provide the physical title separately from the interpreted
  /// media title. Prefer the physical title because that is the information
  /// we want to normalize.
  String _resolveDiscTitle(
    ArmDiscTitle title,
  ) {
    final value = title.discTitle?.trim();

    if (value != null &&
        value.isNotEmpty) {
      return value;
    }

    return title.title.trim();
  }

  /// Normalizes a title for alias matching.
  ///
  /// This intentionally does not perform aggressive fuzzy matching. A
  /// localized title should only be mapped when the application has an
  /// explicit known alias, avoiding accidental identity collisions.
  String _normalizeTitle(
    String value,
  ) {
    var normalized = value.trim().toLowerCase();

    normalized = normalized
        .replaceAll(RegExp(r'[“”„‟]'), '"')
        .replaceAll(RegExp(r"[‘’‚‛]"), "'")
        .replaceAll(RegExp(r'[\u2010-\u2015]'), '-');

    normalized = normalized
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  /// Preserves an unresolved ARM title while making sure the physical title
  /// is retained consistently.
  ArmDiscTitle _preserveOriginalTitle(
    ArmDiscTitle title,
    String discTitle,
  ) {
    final metadata = <String, dynamic>{
      ...title.metadata,
      'discTitle': discTitle,
      'canonicalResolved':
          title.canonicalTitle != null &&
          title.canonicalTitle!.trim().isNotEmpty,
    };

    return ArmDiscTitle(
      id: title.id,
      title: title.title,
      mediaType: title.mediaType,
      classification: title.classification,
      year: title.year,
      durationSeconds: title.durationSeconds,
      confidence: title.confidence,
      outputPath: title.outputPath,
      metadata: metadata,
      canonicalTitle: title.canonicalTitle,
      originalTitle: title.originalTitle,
      originalLanguage: title.originalLanguage,
      countryOfOrigin: title.countryOfOrigin,
      discTitle: discTitle,
      discMarketCountry: title.discMarketCountry,
      detectedRegion: title.detectedRegion,
      audioCodec: title.audioCodec,
      archiveFormat: title.archiveFormat,
      losslessAudio: title.losslessAudio,
      trackNumber: title.trackNumber,
      discNumber: title.discNumber,
      artist: title.artist,
      album: title.album,
    );
  }

  /// Applies an explicit canonical alias.
  ArmDiscTitle _applyCanonicalResolution(
    ArmDiscTitle title,
    String discTitle,
    ArmCanonicalTitle known,
  ) {
    final metadata = <String, dynamic>{
      ...title.metadata,
      'discTitle': discTitle,
      'canonicalResolved': true,
      'canonicalResolutionReason':
          'Localized disc title alias',
      'canonicalResolutionSource':
          'ArmTitleResolver',
    };

    return ArmDiscTitle(
      id: title.id,
      title: known.canonicalTitle,
      mediaType: title.mediaType,
      classification: title.classification,
      year: title.year ?? _knownYear(known),
      durationSeconds: title.durationSeconds,
      confidence: title.confidence,
      outputPath: title.outputPath,
      metadata: metadata,
      canonicalTitle: known.canonicalTitle,
      originalTitle: title.originalTitle ??
          known.canonicalTitle,
      originalLanguage: known.originalLanguage,
      countryOfOrigin: known.countryOfOrigin,
      discTitle: discTitle,
      discMarketCountry: title.discMarketCountry,
      detectedRegion: title.detectedRegion,
      audioCodec: title.audioCodec,
      archiveFormat: title.archiveFormat,
      losslessAudio: title.losslessAudio,
      trackNumber: title.trackNumber,
      discNumber: title.discNumber,
      artist: title.artist,
      album: title.album,
    );
  }

  int? _knownYear(
    ArmCanonicalTitle known,
  ) {
    switch (known.canonicalTitle.toLowerCase()) {
      case 'over the hedge':
        return 2006;
      default:
        return null;
    }
  }
}