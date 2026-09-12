// FILE: `Backend/arm/arm_title_resolver.dart`.
// Purpose: Implements the arm title resolver portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'arm_models.dart';

class ArmCanonicalTitle {
  final String canonicalTitle;
  final String originalLanguage;
  final String countryOfOrigin;
  const ArmCanonicalTitle(this.canonicalTitle, this.originalLanguage, this.countryOfOrigin);
}

class ArmTitleResolver {
  static const _aliases = <String, ArmCanonicalTitle>{
    'vecinos invasores': ArmCanonicalTitle('Over the Hedge', 'English', 'United States'),
    'over the hedge': ArmCanonicalTitle('Over the Hedge', 'English', 'United States'),
  };

  const ArmTitleResolver();

  ArmDiscTitle resolve(ArmDiscTitle title) {
    final discTitle = title.discTitle ?? title.title;
    final key = discTitle.trim().toLowerCase();
    final known = _aliases[key];
    if (known == null) return title;
    return ArmDiscTitle(
      id: title.id,
      title: known.canonicalTitle,
      mediaType: title.mediaType,
      classification: title.classification,
      year: title.year ?? 2006,
      durationSeconds: title.durationSeconds,
      confidence: title.confidence,
      outputPath: title.outputPath,
      metadata: {...title.metadata, 'discTitle': discTitle, 'canonicalResolved': true, 'canonicalResolutionReason': 'Localized disc title alias'},
      canonicalTitle: known.canonicalTitle,
      originalTitle: known.canonicalTitle,
      originalLanguage: known.originalLanguage,
      countryOfOrigin: known.countryOfOrigin,
      discTitle: discTitle,
      discMarketCountry: title.discMarketCountry,
      detectedRegion: title.detectedRegion,
    );
  }
}
