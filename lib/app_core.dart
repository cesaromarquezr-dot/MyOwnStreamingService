// FILE: `lib/app_core.dart`.
// Purpose: Implements the app core portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';
import 'offline_sync_queue.dart';
import 'offline_metadata_cache.dart';
import 'library_membership_store.dart';
import './supabase/supabase_service.dart';
import 'localization.dart';
import 'genre_system.dart';
import 'cinematic_seed_examples.dart';
import 'demo_catalog_metadata.dart';
import 'core/models/profile_governance.dart';
import 'core/models/platform_server.dart';

/// Keeps legacy or externally supplied metadata outside this product's media scope.
/// MyOwnStreamingService supports movies, series, episodes, and music tracks/albums;
/// podcasts, audiobooks, and internet radio are intentionally not product categories.
bool isExcludedEntertainmentType(String rawType) {
  final normalized = rawType
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ', '');
  return normalized.contains('podcast') ||
      normalized.contains('audiobook') ||
      normalized.contains('radio');
}

enum SubscriptionPlan {
  monthly,
  yearly,
}

enum SubscriptionStatus {
  active,
  expired,
}

/// Implements the `Subscription` class for this feature or UI component.
class Subscription {
  final SubscriptionPlan plan;
  SubscriptionStatus status;

  Subscription({
    required this.plan,
    this.status = SubscriptionStatus.active,
  });

  double get price {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 54.99;
      case SubscriptionPlan.yearly:
        return 599.99;
    }
  }

  String get displayName {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return '\$54.99/month';
      case SubscriptionPlan.yearly:
        return '\$599.99/year';
    }
  }
}

/// Implements the `MediaItem` class for this feature or UI component.
class MediaItem {
  final String id;
  final String title;
  final String type;
  final String? imageUrl;
  final String? description;

  /// Optional authorized title-logo/key-art asset. It is not extracted from a trailer.
  final String? titleLogoUrl;
  /// Provenance for the title-logo asset (provider/catalog/rights note).
  final String? titleLogoSource;
  /// False by default: only display title-logo artwork when catalog metadata says it is authorized.
  final bool titleLogoAuthorized;
  /// Presentation mode: auto, logo, trailer_title_card, movie_title_card, or case_cover.
  final String titleArtworkMode;
  /// Optional fallback style key: cinematic, horror, sciFi, fantasy, western, romance, retro, animation.
  final String? titleStyleKey;
  /// Optional #RRGGBB or #AARRGGBB accent for the styled-text fallback.
  final String? titleAccentColor;
  /// Optional persisted per-title typography overrides from external_media_catalog.
  final String? titleFontFamily;
  final String? titleFontFallbackFamily;
  final double? titleFontSize;
  final int? titleFontWeight;
  final double? titleFontLetterSpacing;
  final String? titleFontColor;
  final String? titleFontShadowColor;
  final double? titleFontShadowBlur;
  /// Controls cinematic reveal animation; reduced-motion OS settings still take priority.
  final bool titleRevealAnimation;

  /// Per-screen title-artwork choices. `inherit` preserves the shared setting.
  final String heroTitleArtworkMode;
  final String detailTitleArtworkMode;
  final String? heroTitleArtworkUrl;
  final String? detailTitleArtworkUrl;
  final String? heroTitleArtworkSource;
  final String? detailTitleArtworkSource;
  final bool heroTitleArtworkAuthorized;
  final bool detailTitleArtworkAuthorized;

  /// Original release year for a movie, or the first-air year for a series.
  final int? releaseYear;

  /// Full original release date when supplied by trusted catalog metadata.
  /// Stored as a date-only value for reliable chronological sorting.
  final DateTime? releaseDate;

  /// Optional edition-specific release year (e.g. a later theatrical re-release).
  final int? editionReleaseYear;

  /// Full release date for the selected edition/version, when known.
  final DateTime? editionReleaseDate;

  /// Display name for a cut/version, e.g. `Encore Edition` or `Director's Cut`.
  final String? editionName;

  /// Normalized edition category, e.g. `theatrical`, `extended`, `director-cut`, `rerelease`.
  final String? editionType;

  /// Shared work ID across distinct editions of the same underlying movie.
  final String? canonicalWorkId;

  /// Explicit edition-only additions, such as extra scenes or alternate endings.
  final List<String> editionFeatures;

  /// Explicit TV series run years. If absent, season/episode dates are used as fallbacks.
  final int? seriesStartYear;

  /// Exact first-air/premiere date of a series, when catalog metadata provides it.
  final DateTime? seriesStartDate;

  final int? seriesEndYear;

  /// True when the series has not concluded; displays `Present` as the end year.
  /// Kept for compatibility with older catalog records.
  final bool seriesOngoing;

  /// Explicit lifecycle state: `upcoming`, `ongoing`, `ended`, or `unknown`.
  /// This disambiguates an ended series from a title whose status is not known.
  final String? seriesStatus;

  /// Official/provider/critic rating (IMDb, Rotten Tomatoes, etc.).
  final double? rating;
  final String? ratingReason;

  /// Optional explicit audience/community rating maintained separately from the official rating.
  final double? audienceRating;
  final int audienceReviewCount;

  /// Provider ratings are kept as separate source records; they are not combined.
  final List<Map<String, dynamic>> externalRatings;
  final double? userRatingStars;

  /// Authorized media-gateway URL for adaptive HLS/DASH or progressive playback.
  /// Never set this to a raw NAS filesystem path.
  final String? playbackUrl;
  final String? trailerUrl;
  final DateTime addedAt;
  final String? addedByProfileId;
  final String? addedByProfileName;
  final String addedSource;
  final List<Map<String, dynamic>> seasons;

  // Disc/archive metadata populated by the ARM import workflow.
  final String? discType;
  final String? discRegion;
  final String? discCollectionId;
  final String? discCollectionTitle;
  final int? discNumber;
  final String? discTitleId;
  final String? discTitle;
  final String? discMarketCountry;
  final String? originalTitle;
  final String? originalLanguage;
  final String? countryOfOrigin;
  final String? canonicalTitle;
  final String? language;
  final String? adaptationGroupId;
  final String? adaptationGroupName;
  final List<String> relationshipTypes;

  // Profile-level access. An empty list means the account's legacy library
  // visibility rules apply; a populated list is an explicit access allow-list.
  final List<String> accessibleProfileIds;

  // Actual merchant relationships. An empty list means no Shop/Merchandise action.
  final List<String> eligibleMerchandiseProductIds;

  // Franchise/collection metadata. A franchise is different from a physical disc collection.
  final String? franchiseId;
  final String? franchiseName;
  final String? franchiseType;
  final int? franchiseOrder;
  final List<String> franchiseNames;

  /// Optional global catalog totals supplied by trusted metadata providers.
  /// These describe the complete franchise, not just the titles the user owns.
  final int? franchiseTotalTitles;
  final int? franchiseTotalMovies;
  final int? franchiseTotalShows;

  /// Optional global catalog totals for each explicitly named cinematic universe.
  final int? cinematicUniverseTotalTitles;
  final int? cinematicUniverseTotalMovies;
  final int? cinematicUniverseTotalShows;

  /// Explicit cross-universe membership and continuity relationships.
  final List<Map<String, dynamic>> universeMemberships;
  final String? continuityId;
  final String? continuityName;

  /// Verified, explicit cinematic-universe ordering metadata.
  final List<String> cinematicUniverseIds;
  final List<String> cinematicUniverseNames;
  final String? cinematicUniverseSaga;
  final String? cinematicUniversePhase;
  final int? cinematicUniverseReleaseOrder;
  final int? cinematicUniverseTimelineOrder;
  final String? cinematicUniverseTimelineLabel;
  final String? cinematicUniverseCanonStatus;
  final String? cinematicUniverseContinuityId;
  final int? postCreditSceneCount;
  final List<String> narrativePrerequisiteIds;
  final String? universeMetadataSource;
  final DateTime? universeMetadataVerifiedAt;

  // Catalog entities and technical metadata discovered during import.
  final List<String> actors;
  final List<String> characters;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;
  final List<String> genres;
  final String? primaryGenre;
  final String? genreBlendLabelOverride;
  final List<String> tags;

  /// Production studios and companies discovered by the content intelligence/import pipeline.
  final List<String> studios;
  final List<String> companies;
  final List<String> chapters;
  final List<String> audioTracks;
  final List<String> subtitles;
  final List<String> extras;
  final List<Map<String, dynamic>> xrayEvents;

  /// Indexed TV opening sequences; offsets are bound to the exact media version.
  final List<Map<String, dynamic>> tvIntros;

  /// Version/edition identity that anchors version-specific X-Ray offsets.
  final String? mediaVersionId;

  MediaItem({
    this.playbackUrl,
    this.trailerUrl,
    DateTime? addedAt,
    this.addedByProfileId,
    this.addedByProfileName,
    this.addedSource = 'unknown',
    List<Map<String, dynamic>>? seasons,
    this.discType,
    this.discRegion,
    this.discCollectionId,
    this.discCollectionTitle,
    this.discNumber,
    this.discTitleId,
    this.discTitle,
    this.discMarketCountry,
    this.originalTitle,
    this.originalLanguage,
    this.countryOfOrigin,
    this.canonicalTitle,
    this.language,
    this.adaptationGroupId,
    this.adaptationGroupName,
    List<String>? relationshipTypes,
    List<String>? accessibleProfileIds,
    List<String>? eligibleMerchandiseProductIds,
    this.franchiseId,
    this.franchiseName,
    this.franchiseType,
    this.franchiseOrder,
    List<String>? franchiseNames,
    this.franchiseTotalTitles,
    this.franchiseTotalMovies,
    this.franchiseTotalShows,
    this.cinematicUniverseTotalTitles,
    this.cinematicUniverseTotalMovies,
    this.cinematicUniverseTotalShows,
    List<Map<String, dynamic>>? universeMemberships,
    this.continuityId,
    this.continuityName,
    List<String>? cinematicUniverseIds,
    List<String>? cinematicUniverseNames,
    this.cinematicUniverseSaga,
    this.cinematicUniversePhase,
    this.cinematicUniverseReleaseOrder,
    this.cinematicUniverseTimelineOrder,
    this.cinematicUniverseTimelineLabel,
    this.cinematicUniverseCanonStatus,
    this.cinematicUniverseContinuityId,
    this.postCreditSceneCount,
    List<String>? narrativePrerequisiteIds,
    this.universeMetadataSource,
    this.universeMetadataVerifiedAt,
    List<String>? actors,
    List<String>? characters,
    List<String>? directors,
    List<String>? writers,
    List<String>? music,
    List<String>? genres,
    String? primaryGenre,
    String? genreBlendLabelOverride,
    List<String>? tags,
    List<String>? studios,
    List<String>? companies,
    List<String>? chapters,
    List<String>? audioTracks,
    List<String>? subtitles,
    List<String>? extras,
    List<Map<String, dynamic>>? xrayEvents,
    List<Map<String, dynamic>>? tvIntros,
    this.mediaVersionId,
    required this.id,
    required this.title,
    required this.type,
    this.imageUrl,
    this.description,
    this.titleLogoUrl,
    this.titleLogoSource,
    this.titleLogoAuthorized = false,
    this.titleArtworkMode = 'auto',
    this.titleStyleKey,
    this.titleAccentColor,
    this.titleFontFamily,
    this.titleFontFallbackFamily,
    this.titleFontSize,
    this.titleFontWeight,
    this.titleFontLetterSpacing,
    this.titleFontColor,
    this.titleFontShadowColor,
    this.titleFontShadowBlur,
    this.titleRevealAnimation = true,
    this.heroTitleArtworkMode = 'inherit',
    this.detailTitleArtworkMode = 'inherit',
    this.heroTitleArtworkUrl,
    this.detailTitleArtworkUrl,
    this.heroTitleArtworkSource,
    this.detailTitleArtworkSource,
    this.heroTitleArtworkAuthorized = false,
    this.detailTitleArtworkAuthorized = false,
    this.releaseYear,
    this.releaseDate,
    this.editionReleaseYear,
    this.editionReleaseDate,
    this.editionName,
    this.editionType,
    this.canonicalWorkId,
    List<String>? editionFeatures,
    this.seriesStartYear,
    this.seriesStartDate,
    this.seriesEndYear,
    this.seriesOngoing = false,
    this.seriesStatus,
    this.rating,
    this.ratingReason,
    this.audienceRating,
    this.audienceReviewCount = 0,
    List<Map<String, dynamic>>? externalRatings,
    this.userRatingStars,
  })  : externalRatings = externalRatings ?? const <Map<String, dynamic>>[],
        editionFeatures = editionFeatures ?? const <String>[],
        addedAt = addedAt ?? DateTime.now(),
        seasons = seasons ?? <Map<String, dynamic>>[],
        actors = actors ?? <String>[],
        directors = directors ?? <String>[],
        writers = writers ?? <String>[],
        music = music ?? <String>[],
        genres = _normalizeMediaGenres(genres, primaryGenre),
        primaryGenre = _normalizePrimaryGenre(
          primaryGenre,
          _normalizeMediaGenres(genres, primaryGenre),
        ),
        genreBlendLabelOverride = _normalizeGenreBlendLabel(genreBlendLabelOverride),
        tags = tags ?? <String>[],
        studios = studios ?? <String>[],
        companies = companies ?? <String>[],
        chapters = chapters ?? <String>[],
        audioTracks = audioTracks ?? <String>[],
        subtitles = subtitles ?? <String>[],
        extras = extras ?? <String>[],
        xrayEvents = xrayEvents ?? <Map<String, dynamic>>[],
        tvIntros = tvIntros ?? <Map<String, dynamic>>[],
        relationshipTypes = relationshipTypes ?? <String>[],
        accessibleProfileIds = accessibleProfileIds ?? <String>[],
        eligibleMerchandiseProductIds =
            eligibleMerchandiseProductIds ?? <String>[],
        franchiseNames = franchiseNames ?? <String>[],
        universeMemberships = universeMemberships ?? <Map<String, dynamic>>[],
        cinematicUniverseIds = cinematicUniverseIds ?? <String>[],
        cinematicUniverseNames = cinematicUniverseNames ?? <String>[],
        narrativePrerequisiteIds = narrativePrerequisiteIds ?? <String>[],
        characters = characters ?? <String>[];

  static List<String> _normalizeMediaGenres(
    List<String>? rawGenres,
    String? rawPrimaryGenre,
  ) {
    final values = <String>[...?rawGenres];
    final primary = rawPrimaryGenre?.trim() ?? '';
    if (primary.isNotEmpty) values.add(primary);
    return GenreSystem.normalizeGenres(values);
  }

  static String? _normalizePrimaryGenre(
    String? rawPrimaryGenre,
    List<String> normalizedGenres,
  ) {
    final raw = rawPrimaryGenre?.trim() ?? '';
    if (raw.isEmpty) return null;
    final canonical = GenreSystem.canonicalize(raw).toLowerCase();
    for (final genre in normalizedGenres) {
      if (genre.toLowerCase() == canonical) return genre;
    }
    return null;
  }

  static String? _normalizeGenreBlendLabel(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  String get genreDisplayLabel => GenreSystem.displayLabel(
        genres,
        primaryGenre: primaryGenre,
        overrideLabel: genreBlendLabelOverride,
      );

  /// Returns whether the current profile has explicit access to this library item.
  bool isAccessibleTo(Profile? profile) {
    if (profile == null) return false;
    if (accessibleProfileIds.isEmpty) return true;
    return accessibleProfileIds.contains(profile.id);
  }

  /// Returns whether a real merchant/product relationship exists for Shop.
  bool get hasEligibleMerchandise => eligibleMerchandiseProductIds.isNotEmpty;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // Some server/catalog endpoints wrap extended fields inside `metadata`.
    // Merge nested metadata first so explicit top-level values remain authoritative.
    final data = <String, dynamic>{
      if (json['metadata'] is Map)
        ...Map<String, dynamic>.from(json['metadata'] as Map),
      ...json,
    };
    // Normalize flexible catalog credit shapes before constructing the model.
    // Providers may use top-level actors/directors or nested credits.cast/crew.
    final credits = _creditMap(data['credits']);
    final rawCast = _firstNonEmptyCreditValue([
      data['actors'],
      data['cast'],
      data['castMembers'],
      data['cast_members'],
      data['performers'],
      data['topCast'],
      data['top_cast'],
      credits['cast'],
      credits['actors'],
    ]);
    final rawCrew = _firstNonEmptyCreditValue([
      data['crew'],
      credits['crew'],
    ]);
    final rawCharacters = _firstNonEmptyCreditValue([
      data['characters'],
      data['characterNames'],
      data['character_names'],
      credits['characters'],
    ]);
    final actorNames = _creditNameList(rawCast);
    final characterNames = _creditNameList(rawCharacters).isNotEmpty
        ? _creditNameList(rawCharacters)
        : _creditCharacterNames(rawCast);
    final directorNames = _firstCreditNameList([
      data['directors'],
      data['director'],
      credits['directors'],
      _crewNamesForRole(rawCrew, 'director'),
    ]);
    final writerNames = _firstCreditNameList([
      data['writers'],
      data['screenwriters'],
      data['screenWriters'],
      data['screen_writers'],
      data['writingCredits'],
      data['writing_credits'],
      credits['writers'],
      credits['writing'],
      _crewNamesForRole(rawCrew, 'writer'),
    ]);
    final musicNames = _firstCreditNameList([
      data['music'],
      data['composers'],
      data['composer'],
      credits['music'],
      _crewNamesForRole(rawCrew, 'music'),
    ]);

    // Different catalog providers use different field names. Normalize their
    // date values once here so Release Order can sort movies, shows, and albums
    // by full date instead of guessing from the year or title.
    final parsedReleaseDate = _dateValue(
      data['releaseDate'] ??
          data['release_date'] ??
          data['originalReleaseDate'] ??
          data['original_release_date'] ??
          data['firstReleaseDate'] ??
          data['first_release_date'] ??
          data['first-release-date'] ??
          data['release-date'] ??
          data['albumReleaseDate'] ??
          data['album_release_date'] ??
          data['theatricalReleaseDate'] ??
          data['theatrical_release_date'] ??
          data['dateReleased'] ??
          data['date_released'] ??
          data['datePublished'] ??
          data['date_published'] ??
          data['date'],
    );
    final parsedEditionReleaseDate = _dateValue(
      data['editionReleaseDate'] ??
          data['edition_release_date'] ??
          data['reReleaseDate'] ??
          data['re_release_date'] ??
          data['physicalReleaseDate'] ??
          data['physical_release_date'],
    );
    final parsedSeriesStartDate = _dateValue(
      data['seriesStartDate'] ??
          data['series_start_date'] ??
          data['firstAirDate'] ??
          data['first_air_date'] ??
          data['firstAired'] ??
          data['first_aired'] ??
          data['premiereDate'] ??
          data['premiere_date'],
    );
    return MediaItem(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      type: data['type']?.toString() ?? 'movie',
      imageUrl: (data['imageUrl'] ?? data['posterUrl'])?.toString(),
      description: data['description']?.toString(),
      titleLogoUrl: (data['titleLogoUrl'] ?? data['title_logo_url'] ?? data['logoUrl'])?.toString(),
      titleLogoSource: (data['titleLogoSource'] ?? data['title_logo_source'])?.toString(),
      titleLogoAuthorized: _boolValue(data['titleLogoAuthorized'] ?? data['title_logo_authorized']),
      titleArtworkMode: (data['titleArtworkMode'] ?? data['title_artwork_mode'] ?? 'auto').toString(),
      titleStyleKey: (data['titleStyleKey'] ?? data['title_style_key'])?.toString(),
      titleAccentColor: (data['titleAccentColor'] ?? data['title_accent_color'])?.toString(),
      titleFontFamily: (data['titleFontFamily'] ?? data['title_font_family'])?.toString(),
      titleFontFallbackFamily: (data['titleFontFallbackFamily'] ?? data['title_font_fallback_family'])?.toString(),
      titleFontSize: _doubleValue(data['titleFontSize'] ?? data['title_font_size']),
      titleFontWeight: _intValue(data['titleFontWeight'] ?? data['title_font_weight']),
      titleFontLetterSpacing: _doubleValue(data['titleFontLetterSpacing'] ?? data['title_font_letter_spacing']),
      titleFontColor: (data['titleFontColor'] ?? data['title_font_color'])?.toString(),
      titleFontShadowColor: (data['titleFontShadowColor'] ?? data['title_font_shadow_color'])?.toString(),
      titleFontShadowBlur: _doubleValue(data['titleFontShadowBlur'] ?? data['title_font_shadow_blur']),
      titleRevealAnimation: (data.containsKey('titleRevealAnimation') || data.containsKey('title_reveal_animation'))
          ? _boolValue(data['titleRevealAnimation'] ?? data['title_reveal_animation'])
          : true,
      heroTitleArtworkMode: (
        data['heroTitleArtworkMode'] ??
        data['hero_title_artwork_mode'] ??
        'inherit'
      ).toString(),
      detailTitleArtworkMode: (
        data['detailTitleArtworkMode'] ??
        data['detail_title_artwork_mode'] ??
        'inherit'
      ).toString(),
      heroTitleArtworkUrl: (
        data['heroTitleArtworkUrl'] ?? data['hero_title_artwork_url']
      )?.toString(),
      detailTitleArtworkUrl: (
        data['detailTitleArtworkUrl'] ?? data['detail_title_artwork_url']
      )?.toString(),
      heroTitleArtworkSource: (
        data['heroTitleArtworkSource'] ?? data['hero_title_artwork_source']
      )?.toString(),
      detailTitleArtworkSource: (
        data['detailTitleArtworkSource'] ?? data['detail_title_artwork_source']
      )?.toString(),
      heroTitleArtworkAuthorized: _boolValue(
        data['heroTitleArtworkAuthorized'] ??
        data['hero_title_artwork_authorized'],
      ),
      detailTitleArtworkAuthorized: _boolValue(
        data['detailTitleArtworkAuthorized'] ??
        data['detail_title_artwork_authorized'],
      ),
      releaseYear: _intValue(
            data['releaseYear'] ?? data['release_year'] ?? data['year'],
          ) ??
          parsedReleaseDate?.year,
      releaseDate: parsedReleaseDate,
      editionReleaseYear: _intValue(
            data['editionReleaseYear'] ?? data['edition_release_year'],
          ) ??
          parsedEditionReleaseDate?.year,
      editionReleaseDate: parsedEditionReleaseDate,
      editionName: (data['editionName'] ?? data['edition_name'])?.toString(),
      editionType: (data['editionType'] ?? data['edition_type'])?.toString(),
      canonicalWorkId:
          (data['canonicalWorkId'] ?? data['canonical_work_id'])?.toString(),
      editionFeatures:
          _stringList(data['editionFeatures'] ?? data['edition_features']),
      seriesStartYear: _intValue(
            data['seriesStartYear'] ?? data['series_start_year'],
          ) ??
          parsedSeriesStartDate?.year,
      seriesStartDate: parsedSeriesStartDate,
      seriesEndYear:
          _intValue(data['seriesEndYear'] ?? data['series_end_year']),
      seriesOngoing: _boolValue(data['seriesOngoing'] ?? data['series_ongoing']),
      seriesStatus:
          (data['seriesStatus'] ?? data['series_status'])?.toString(),
      rating: data['rating'] is num
          ? (data['rating'] as num).toDouble()
          : double.tryParse(
              data['rating']?.toString() ?? '',
            ),
      ratingReason: data['ratingReason']?.toString(),
      audienceRating: data['audienceRating'] is num
          ? (data['audienceRating'] as num).toDouble()
          : double.tryParse(data['audienceRating']?.toString() ?? ''),
      audienceReviewCount: data['audienceReviewCount'] is num
          ? (data['audienceReviewCount'] as num).toInt()
          : int.tryParse(data['audienceReviewCount']?.toString() ?? '') ?? 0,
      externalRatings: data['externalRatings'] is List
          ? (data['externalRatings'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[],
      userRatingStars: data['userRatingStars'] is num
          ? (data['userRatingStars'] as num).toDouble()
          : double.tryParse(data['userRatingStars']?.toString() ?? ''),
      playbackUrl:
          data['playbackUrl']?.toString() ?? data['streamingUrl']?.toString(),
      trailerUrl: data['trailerUrl']?.toString(),
      addedAt: DateTime.tryParse(data['addedAt']?.toString() ?? ''),
      addedByProfileId: data['addedByProfileId']?.toString(),
      addedByProfileName: data['addedByProfileName']?.toString(),
      addedSource: data['addedSource']?.toString() ?? 'unknown',
      discType: data['discType']?.toString(),
      discRegion: data['discRegion']?.toString(),
      discCollectionId: data['discCollectionId']?.toString(),
      discCollectionTitle: data['discCollectionTitle']?.toString(),
      discNumber: data['discNumber'] is num
          ? (data['discNumber'] as num).toInt()
          : int.tryParse(data['discNumber']?.toString() ?? ''),
      discTitleId: data['discTitleId']?.toString(),
      discTitle: data['discTitle']?.toString(),
      discMarketCountry: data['discMarketCountry']?.toString(),
      originalTitle: data['originalTitle']?.toString(),
      originalLanguage: data['originalLanguage']?.toString(),
      countryOfOrigin: data['countryOfOrigin']?.toString(),
      canonicalTitle: data['canonicalTitle']?.toString(),
      language: data['language']?.toString(),
      adaptationGroupId: data['adaptationGroupId']?.toString(),
      adaptationGroupName: data['adaptationGroupName']?.toString(),
      relationshipTypes: _stringList(data['relationshipTypes']),
      accessibleProfileIds: _stringList(data['accessibleProfileIds']),
      eligibleMerchandiseProductIds:
          _stringList(data['eligibleMerchandiseProductIds']),
      franchiseId: data['franchiseId']?.toString(),
      franchiseName: data['franchiseName']?.toString(),
      franchiseType: data['franchiseType']?.toString(),
      franchiseOrder: data['franchiseOrder'] is num
          ? (data['franchiseOrder'] as num).toInt()
          : int.tryParse(data['franchiseOrder']?.toString() ?? ''),
      franchiseNames: _stringList(data['franchiseNames'] ?? data['franchises']),
      franchiseTotalTitles: _intValue(
        data['franchiseTotalTitles'] ??
            data['franchise_total_titles'] ??
            data['franchiseCatalogTotal'] ??
            data['franchise_catalog_total'] ??
            data['totalFranchiseTitles'] ??
            data['total_franchise_titles'],
      ),
      franchiseTotalMovies: _intValue(
        data['franchiseTotalMovies'] ??
            data['franchise_total_movies'] ??
            data['franchiseCatalogMovies'] ??
            data['franchise_catalog_movies'] ??
            data['totalFranchiseMovies'] ??
            data['total_franchise_movies'],
      ),
      franchiseTotalShows: _intValue(
        data['franchiseTotalShows'] ??
            data['franchise_total_shows'] ??
            data['franchiseCatalogShows'] ??
            data['franchise_catalog_shows'] ??
            data['totalFranchiseShows'] ??
            data['total_franchise_shows'],
      ),
      cinematicUniverseTotalTitles: _intValue(
        data['cinematicUniverseTotalTitles'] ??
            data['cinematic_universe_total_titles'] ??
            data['universeTotalTitles'] ??
            data['universe_total_titles'] ??
            data['cinematicUniverseCatalogTotal'] ??
            data['cinematic_universe_catalog_total'],
      ),
      cinematicUniverseTotalMovies: _intValue(
        data['cinematicUniverseTotalMovies'] ??
            data['cinematic_universe_total_movies'] ??
            data['universeTotalMovies'] ??
            data['universe_total_movies'] ??
            data['cinematicUniverseCatalogMovies'] ??
            data['cinematic_universe_catalog_movies'],
      ),
      cinematicUniverseTotalShows: _intValue(
        data['cinematicUniverseTotalShows'] ??
            data['cinematic_universe_total_shows'] ??
            data['universeTotalShows'] ??
            data['universe_total_shows'] ??
            data['cinematicUniverseCatalogShows'] ??
            data['cinematic_universe_catalog_shows'],
      ),
      universeMemberships:
          (data['universeMemberships'] ?? data['universe_memberships']) is List
              ? ((data['universeMemberships'] ?? data['universe_memberships']) as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
              : <Map<String, dynamic>>[],
      continuityId: (data['continuityId'] ?? data['continuity_id'])?.toString(),
      continuityName: (data['continuityName'] ?? data['continuity_name'])?.toString(),
      cinematicUniverseIds: _stringList(data['cinematicUniverseIds'] ?? data['cinematic_universe_ids']),
      cinematicUniverseNames: _stringList(data['cinematicUniverseNames'] ?? data['cinematic_universe_names']),
      cinematicUniverseSaga: (data['cinematicUniverseSaga'] ?? data['cinematic_universe_saga'])?.toString(),
      cinematicUniversePhase: (data['cinematicUniversePhase'] ?? data['cinematic_universe_phase'])?.toString(),
      cinematicUniverseReleaseOrder: _intValue(data['cinematicUniverseReleaseOrder'] ?? data['cinematic_universe_release_order']),
      cinematicUniverseTimelineOrder: _intValue(data['cinematicUniverseTimelineOrder'] ?? data['cinematic_universe_timeline_order']),
      cinematicUniverseTimelineLabel: (data['cinematicUniverseTimelineLabel'] ?? data['cinematic_universe_timeline_label'])?.toString(),
      cinematicUniverseCanonStatus: (data['cinematicUniverseCanonStatus'] ?? data['cinematic_universe_canon_status'])?.toString(),
      cinematicUniverseContinuityId: (data['cinematicUniverseContinuityId'] ?? data['cinematic_universe_continuity_id'])?.toString(),
      postCreditSceneCount: _intValue(data['postCreditSceneCount'] ?? data['post_credit_scene_count']),
      narrativePrerequisiteIds: _stringList(data['narrativePrerequisiteIds'] ?? data['narrative_prerequisite_ids']),
      universeMetadataSource: (data['universeMetadataSource'] ?? data['universe_metadata_source'])?.toString(),
      universeMetadataVerifiedAt: DateTime.tryParse((data['universeMetadataVerifiedAt'] ?? data['universe_metadata_verified_at'])?.toString() ?? ''),
      actors: actorNames,
      characters: characterNames,
      directors: directorNames,
      writers: writerNames,
      music: musicNames,
      genres: _stringList(data['genres']),
      primaryGenre: (data['primaryGenre'] ?? data['primary_genre'])?.toString(),
      genreBlendLabelOverride: (data['genreBlendLabelOverride'] ?? data['genre_blend_label_override'])?.toString(),
      tags: _stringList(data['tags']),
      studios: _combinedCreditNameList([
        data['studios'],
        data['productionStudios'],
        data['production_studios'],
      ]),
      companies: _combinedCreditNameList([
        data['companies'],
        data['productionCompanies'],
        data['production_companies'],
        data['company'],
      ]),
      chapters: _stringList(data['chapters']),
      audioTracks: _stringList(data['audioTracks']),
      subtitles: _stringList(data['subtitles']),
      extras: _stringList(data['extras']),
      tvIntros: data['tvIntros'] is List
          ? (data['tvIntros'] as List)
              .whereType<Map>()
              .map((event) => Map<String, dynamic>.from(event))
              .toList()
          : <Map<String, dynamic>>[],
      xrayEvents: data['xrayEvents'] is List
          ? (data['xrayEvents'] as List)
              .whereType<Map>()
              .map((event) => Map<String, dynamic>.from(event))
              .toList()
          : <Map<String, dynamic>>[],
      mediaVersionId: (data['mediaVersionId'] ?? data['versionId'])?.toString(),
      seasons: (data['seasons'] is List)
          ? (data['seasons'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[],
    );
  }

  static double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : double.tryParse(text);
  }

  static int? _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Parses the calendar date exactly as the provider wrote it. Release-order
  /// values are dates, not instants, so an ISO timestamp's timezone must not
  /// move the item to the previous/next calendar day.
  static DateTime? _dateValue(dynamic value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final datePrefix =
        RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text)?.group(1);
    // Year-only and year-month fields are intentionally not promoted to a
    // full date: assigning the first day of a month would invent chronology.
    if (datePrefix == null) return null;
    final parsed = DateTime.tryParse(datePrefix);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      default:
        return false;
    }
  }

  bool get isSeries {
    final normalized = type.toLowerCase().trim();
    return normalized == 'tv' ||
        normalized == 'show' ||
        normalized == 'tv show' ||
        normalized == 'tvshow' ||
        normalized == 'television' ||
        normalized.startsWith('tv ') ||
        normalized.contains('series');
  }

  static const List<String> _yearMetadataKeys = <String>[
    'releaseYear', 'release_year', 'firstAirYear', 'first_air_year',
    'airYear', 'air_year', 'year', 'startYear', 'start_year',
    'endYear', 'end_year', 'firstAirDate', 'first_air_date',
    'airDate', 'air_date', 'releaseDate', 'release_date',
    'premiereDate', 'premiere_date', 'firstAired', 'first_aired',
    'lastAirYear', 'last_air_year', 'lastAirDate', 'last_air_date',
    'finalAirDate', 'final_air_date', 'endDate', 'end_date',
    'lastAired', 'last_aired', 'finaleDate', 'finale_date',
    'firstEpisodeAirDate', 'first_episode_air_date',
    'lastEpisodeAirDate', 'last_episode_air_date', 'date',
  ];

  static int? _yearFromValue(dynamic raw) {
    if (raw is DateTime) return raw.year;
    if (raw is num) {
      final year = raw.toInt();
      return year >= 1800 && year <= 2200 ? year : null;
    }
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final direct = int.tryParse(value);
    if (direct != null) return direct >= 1800 && direct <= 2200 ? direct : null;
    final date = DateTime.tryParse(value);
    if (date != null) return date.year;
    final match = RegExp(r'\b((?:18|19|20|21|22)\d{2})\b')
        .firstMatch(value);
    final parsed = int.tryParse(match?.group(1) ?? '');
    return parsed != null && parsed >= 1800 && parsed <= 2200 ? parsed : null;
  }

  static List<int> _yearsFromMap(Map<String, dynamic> map) {
    final years = <int>[];
    for (final key in _yearMetadataKeys) {
      if (!map.containsKey(key)) continue;
      final year = _yearFromValue(map[key]);
      if (year != null) years.add(year);
    }
    return years;
  }

  List<int> get _knownSeriesYears {
    final years = <int>[];
    for (final season in seasons) {
      years.addAll(_yearsFromMap(season));
      final episodes = season['episodes'];
      if (episodes is List) {
        for (final episode in episodes.whereType<Map>()) {
          years.addAll(_yearsFromMap(Map<String, dynamic>.from(episode)));
        }
      }
    }
    years.sort();
    return years.toSet().toList(growable: false);
  }

  String get _normalizedSeriesStatus => (seriesStatus ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool get isSeriesOngoing => seriesOngoing || const <String>{
        'ongoing', 'airing', 'returning', 'returning series',
      }.contains(_normalizedSeriesStatus);

  bool get isSeriesUpcoming => const <String>{
        'upcoming', 'announced', 'in development', 'coming soon',
      }.contains(_normalizedSeriesStatus);

  /// Derives a single season's run from the season metadata and episode air dates.
  /// For example, `Season 1 • 2005–2006`; returns null if no year is known.
  String? displaySeasonYearLabel(Map<String, dynamic> season) {
    final years = _yearsFromMap(season);
    final episodes = season['episodes'];
    if (episodes is List) {
      for (final episode in episodes.whereType<Map>()) {
        years.addAll(_yearsFromMap(Map<String, dynamic>.from(episode)));
      }
    }
    if (years.isEmpty) return null;
    years.sort();
    final start = years.first;
    final end = years.last;
    return end > start ? '$start–$end' : '$start';
  }

  /// Label used by hero banners, cards, search, and detail metadata.
  /// Series use their complete run; movie editions use their own release year.
  String? get displayYearLabel {
    if (isSeries) {
      final years = _knownSeriesYears;
      if (isSeriesUpcoming) {
        final comingYear = seriesStartYear ?? releaseYear ??
            (years.isNotEmpty ? years.first : null);
        return comingYear == null ? 'Coming soon' : 'Coming $comingYear';
      }
      final start = seriesStartYear ??
          (years.isNotEmpty ? years.first : releaseYear);
      final end = seriesEndYear ?? (years.isNotEmpty ? years.last : null);
      if (isSeriesOngoing) return start == null ? 'Ongoing' : '$start–Present';
      if (start == null) return end?.toString();
      if (end != null && end > start) return '$start–$end';
      return '$start';
    }
    final year = editionReleaseYear ?? releaseYear;
    return year?.toString();
  }

  /// Original movie year shown alongside a later edition/re-release.
  String? get displayOriginalReleaseYearLabel {
    if (isSeries ||
        releaseYear == null ||
        editionReleaseYear == null ||
        editionReleaseYear == releaseYear) {
      return null;
    }
    return 'Original release $releaseYear';
  }

  String? get displayEditionLabel {
    final name = editionName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final kind = (editionType ?? '').trim().toLowerCase()
        .replaceAll(RegExp(r'[_\s]+'), '-');
    if (kind.isEmpty) return null;
    return switch (kind) {
      'theatrical' || 'theatrical-edition' || 'theatrical-cut' => 'Theatrical Version',
      'extended' || 'extended-edition' || 'extended-cut' => 'Extended Version',
      'director-cut' || 'directors-cut' || 'director-s-cut' || 'directors-edition' => "Director's Cut",
      'editor-cut' || 'editors-cut' || 'editor-s-cut' || 'editor-cut-edition' => "Editor's Cut",
      'unrated' || 'unrated-edition' || 'unrated-cut' => 'Unrated Version',
      'theatrical-rerelease' || 'theatrical-re-release' => 'Theatrical Re-release',
      'rerelease' || 're-release' || 're-release-edition' => 'Re-release',
      'encore' || 'encore-edition' => 'Encore Edition',
      'imax' || 'imax-edition' || 'imax-version' => 'IMAX Version',
      'roadshow' || 'roadshow-version' || 'roadshow-edition' => 'Roadshow Version',
      'tv-cut' || 'television-cut' || 'broadcast-cut' => 'TV Cut',
      'international-cut' || 'international-version' => 'International Version',
      'final-cut' => 'Final Cut',
      'special-edition' => 'Special Edition',
      'collector-edition' || 'collectors-edition' => "Collector's Edition",
      'remastered' || 'remastered-edition' => 'Remastered Edition',
      'alternate-cut' || 'alternate-version' => 'Alternate Cut',
      _ => kind.replaceAll('-', ' '),
    };
  }

  int? get displaySeasonCount =>
      isSeries && seasons.isNotEmpty ? seasons.length : null;

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _creditMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static dynamic _firstNonEmptyCreditValue(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is List && value.isNotEmpty) return value;
      if (value is Map && value.isNotEmpty) return value;
    }
    return null;
  }

  static List<String> _firstCreditNameList(List<dynamic> values) {
    for (final value in values) {
      final names = _creditNameList(value);
      if (names.isNotEmpty) return names;
    }
    return <String>[];
  }

  /// Combines alternate catalog fields while preserving order and avoiding
  /// duplicates. Production-company providers commonly return objects instead
  /// of strings (for example, {"id": 1, "name": "Example Studio"}).
  static List<String> _combinedCreditNameList(List<dynamic> values) {
    final seen = <String>{};
    final names = <String>[];
    for (final value in values) {
      for (final rawName in _creditNameList(value)) {
        final name = rawName.trim();
        final key = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (name.isNotEmpty && seen.add(key)) names.add(name);
      }
    }
    return names;
  }

  static List<String> _creditNameList(dynamic value) {
    final names = <String>[];
    final seen = <String>{};

    void addName(String raw) {
      final name = raw.trim();
      final key = name.toLowerCase();
      if (name.isNotEmpty && seen.add(key)) names.add(name);
    }

    void visit(dynamic item) {
      if (item == null) return;
      if (item is String || item is num) {
        addName(item.toString());
        return;
      }
      if (item is List) {
        for (final entry in item) {
          visit(entry);
        }
        return;
      }
      if (item is! Map) return;

      final map = Map<String, dynamic>.from(item);
      for (final key in <String>[
        'name', 'fullName', 'full_name', 'personName', 'person_name',
        'displayName', 'display_name', 'creditedName', 'credited_name',
        'actor', 'artist', 'writer', 'director', 'performer',
        'person', 'member', 'crewMember', 'crew_member',
      ]) {
        final candidate = map[key];
        if (candidate is String || candidate is num) {
          addName(candidate.toString());
          return;
        }
        if (candidate is Map) {
          final nested = _creditNameList(candidate);
          if (nested.isNotEmpty) {
            for (final name in nested) {
              addName(name);
            }
            return;
          }
        }
      }

      for (final key in <String>['items', 'results', 'people', 'members', 'cast', 'crew', 'credits']) {
        if (map[key] is List || map[key] is Map) {
          visit(map[key]);
          return;
        }
      }
    }

    visit(value);
    return names;
  }

  static List<String> _creditCharacterNames(dynamic value) {
    final names = <String>[];
    final seen = <String>{};
    final rows = value is List ? value : <dynamic>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final raw = map['character'] ?? map['characterName'] ??
          map['character_name'] ?? map['roleName'] ?? map['role_name'];
      if (raw is! String && raw is! num) continue;
      final name = raw.toString().trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) names.add(name);
    }
    return names;
  }

  static List<String> _crewNamesForRole(dynamic value, String kind) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final roleKeys = switch (kind) {
        'director' => <String>['directors', 'director', 'directing'],
        'writer' => <String>['writers', 'screenwriters', 'screen_writers', 'writing', 'screenplay'],
        'music' => <String>['composers', 'composer', 'music', 'score', 'soundtrack'],
        _ => <String>[],
      };
      final directNames = _firstCreditNameList(
        roleKeys.map((key) => map[key]).toList(growable: false),
      );
      if (directNames.isNotEmpty) return directNames;
      value = map['items'] ?? map['results'] ?? map['people'] ??
          map['members'] ?? map['crew'] ?? map['credits'];
    }
    final rows = value is List ? value : <dynamic>[];
    final matches = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final roleText = <String>[
        map['job']?.toString() ?? '',
        map['role']?.toString() ?? '',
        map['department']?.toString() ?? '',
        map['known_for_department']?.toString() ?? '',
      ].join(' ').toLowerCase();
      final isMatch = switch (kind) {
        'director' => roleText.contains('director') || roleText.contains('directing'),
        'writer' => roleText.contains('writer') || roleText.contains('writing') ||
            roleText.contains('screenplay') || roleText.contains('script') ||
            roleText.contains('story') || roleText.contains('author'),
        'music' => roleText.contains('composer') || roleText.contains('music') ||
            roleText.contains('score') || roleText.contains('songwriter'),
        _ => false,
      };
      if (isMatch) matches.add(map);
    }
    return _creditNameList(matches);
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'imageUrl': imageUrl,
      'description': description,
      'titleLogoUrl': titleLogoUrl,
      'titleLogoSource': titleLogoSource,
      'titleLogoAuthorized': titleLogoAuthorized,
      'titleArtworkMode': titleArtworkMode,
      'titleStyleKey': titleStyleKey,
      'titleAccentColor': titleAccentColor,
      'titleFontFamily': titleFontFamily,
      'titleFontFallbackFamily': titleFontFallbackFamily,
      'titleFontSize': titleFontSize,
      'titleFontWeight': titleFontWeight,
      'titleFontLetterSpacing': titleFontLetterSpacing,
      'titleFontColor': titleFontColor,
      'titleFontShadowColor': titleFontShadowColor,
      'titleFontShadowBlur': titleFontShadowBlur,
      'titleRevealAnimation': titleRevealAnimation,
      'heroTitleArtworkMode': heroTitleArtworkMode,
      'detailTitleArtworkMode': detailTitleArtworkMode,
      'heroTitleArtworkUrl': heroTitleArtworkUrl,
      'detailTitleArtworkUrl': detailTitleArtworkUrl,
      'heroTitleArtworkSource': heroTitleArtworkSource,
      'detailTitleArtworkSource': detailTitleArtworkSource,
      'heroTitleArtworkAuthorized': heroTitleArtworkAuthorized,
      'detailTitleArtworkAuthorized': detailTitleArtworkAuthorized,
      'releaseYear': releaseYear,
      'releaseDate': releaseDate?.toIso8601String().substring(0, 10),
      'editionReleaseYear': editionReleaseYear,
      'editionReleaseDate':
          editionReleaseDate?.toIso8601String().substring(0, 10),
      'editionName': editionName,
      'editionType': editionType,
      'canonicalWorkId': canonicalWorkId,
      'editionFeatures': editionFeatures,
      'seriesStartYear': seriesStartYear,
      'seriesStartDate':
          seriesStartDate?.toIso8601String().substring(0, 10),
      'seriesEndYear': seriesEndYear,
      'seriesOngoing': seriesOngoing,
      'seriesStatus': seriesStatus,
      'rating': rating,
      'ratingReason': ratingReason,
      'audienceRating': audienceRating,
      'audienceReviewCount': audienceReviewCount,
      'externalRatings': externalRatings,
      'userRatingStars': userRatingStars,
      'trailerUrl': trailerUrl,
      'addedAt': addedAt.toIso8601String(),
      'addedByProfileId': addedByProfileId,
      'addedByProfileName': addedByProfileName,
      'addedSource': addedSource,
      'discType': discType,
      'discRegion': discRegion,
      'discCollectionId': discCollectionId,
      'discCollectionTitle': discCollectionTitle,
      'discNumber': discNumber,
      'discTitleId': discTitleId,
      'discTitle': discTitle,
      'discMarketCountry': discMarketCountry,
      'originalTitle': originalTitle,
      'originalLanguage': originalLanguage,
      'countryOfOrigin': countryOfOrigin,
      'canonicalTitle': canonicalTitle,
      'language': language,
      'adaptationGroupId': adaptationGroupId,
      'adaptationGroupName': adaptationGroupName,
      'relationshipTypes': relationshipTypes,
      'accessibleProfileIds': accessibleProfileIds,
      'eligibleMerchandiseProductIds': eligibleMerchandiseProductIds,
      'franchiseId': franchiseId,
      'franchiseName': franchiseName,
      'franchiseType': franchiseType,
      'franchiseOrder': franchiseOrder,
      'franchiseNames': franchiseNames,
      'franchises': franchiseNames,
      'franchiseTotalTitles': franchiseTotalTitles,
      'franchiseTotalMovies': franchiseTotalMovies,
      'franchiseTotalShows': franchiseTotalShows,
      'cinematicUniverseTotalTitles': cinematicUniverseTotalTitles,
      'cinematicUniverseTotalMovies': cinematicUniverseTotalMovies,
      'cinematicUniverseTotalShows': cinematicUniverseTotalShows,
      'universeMemberships': universeMemberships,
      'continuityId': continuityId,
      'continuityName': continuityName,
      'cinematicUniverseIds': cinematicUniverseIds,
      'cinematicUniverseNames': cinematicUniverseNames,
      'cinematicUniverseSaga': cinematicUniverseSaga,
      'cinematicUniversePhase': cinematicUniversePhase,
      'cinematicUniverseReleaseOrder': cinematicUniverseReleaseOrder,
      'cinematicUniverseTimelineOrder': cinematicUniverseTimelineOrder,
      'cinematicUniverseTimelineLabel': cinematicUniverseTimelineLabel,
      'cinematicUniverseCanonStatus': cinematicUniverseCanonStatus,
      'cinematicUniverseContinuityId': cinematicUniverseContinuityId,
      'postCreditSceneCount': postCreditSceneCount,
      'narrativePrerequisiteIds': narrativePrerequisiteIds,
      'universeMetadataSource': universeMetadataSource,
      'universeMetadataVerifiedAt': universeMetadataVerifiedAt?.toIso8601String(),
      'actors': actors,
      'characters': characters,
      'directors': directors,
      'writers': writers,
      'music': music,
      'genres': genres,
      'primaryGenre': primaryGenre,
      'genreBlendLabelOverride': genreBlendLabelOverride,
      'tags': tags,
      'studios': studios,
      'companies': companies,
      'chapters': chapters,
      'audioTracks': audioTracks,
      'subtitles': subtitles,
      'extras': extras,
      'xrayEvents': xrayEvents,
      'tvIntros': tvIntros,
      'mediaVersionId': mediaVersionId,
      'seasons': seasons,
    };
  }
}

/// Builds the conversational, streaming-service-style synopses used when a
/// description is not supplied manually. Story notes can be entered during
/// import when a more title-specific synopsis is desired.
/// Normalizes the backend recommendation envelope into the media JSON shape
/// expected by [MediaItem.fromJson]. The recommendation API returns
/// { media: {...}, score, matchPercentage, reasons }; older or local providers
/// may return the media object at the top level. This function supports both.
Map<String, dynamic>? normalizeRecommendationMediaPayload(dynamic value) {
  if (value is! Map) return null;
  final wrapper = Map<String, dynamic>.from(value);
  final nested = wrapper['media'];
  final media = nested is Map
      ? Map<String, dynamic>.from(nested)
      : Map<String, dynamic>.from(wrapper);

  final rawType = (media['type'] ?? media['mediaType'] ?? 'movie')
      .toString()
      .trim();
  final compactType = rawType.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  final String normalizedType = switch (compactType) {
    'tv' || 'tvshow' || 'television' || 'series' || 'episode' => 'tv show',
    'music_album' || 'musicalbum' || 'album' || 'soundtrack' => 'album',
    'track' || 'song' || 'musictrack' => 'song',
    _ => rawType.isEmpty ? 'movie' : rawType,
  };

  final normalized = <String, dynamic>{
    ...media,
    'type': normalizedType,
    if (media['releaseYear'] == null && media['release_year'] == null && media['year'] != null)
      'releaseYear': media['year'],
    if (media['imageUrl'] == null && media['posterUrl'] != null)
      'imageUrl': media['posterUrl'],
    if (media['franchiseNames'] == null && media['franchises'] != null)
      'franchiseNames': media['franchises'],
    if (media['genres'] == null && media['subgenres'] != null)
      'genres': media['subgenres'],
    if (media['tags'] == null && media['themes'] != null)
      'tags': media['themes'],
  };
  final franchises = normalized['franchiseNames'];
  if ((normalized['franchiseName'] == null ||
          normalized['franchiseName'].toString().trim().isEmpty) &&
      franchises is List &&
      franchises.isNotEmpty) {
    normalized['franchiseName'] = franchises.first.toString();
  }
  if ((normalized['id']?.toString().trim().isNotEmpty ?? false) == false ||
      (normalized['title']?.toString().trim().isNotEmpty ?? false) == false) {
    return null;
  }
  return normalized;
}

class DescriptionGenerator {
  static String movie({
    required String title,
    int? year,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return '$title${year == null ? '' : ' ($year)'}: $notes';
    }
    return '$title${year == null ? '' : ' ($year)'}: Step into this movie and follow the characters as an unexpected challenge changes everything. With memorable moments, rising stakes, and a story that keeps moving forward, it is ready for another watch in your personal streaming library.';
  }

  static String show({
    required String title,
    int? year,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return '$title${year == null ? '' : ' ($year)'}: $notes';
    }
    return '$title${year == null ? '' : ' ($year)'}: Meet the characters at the center of this series as their lives, friendships, challenges, and adventures unfold across the seasons. Settle in and follow the story episode by episode.';
  }

  static String season({
    required String showTitle,
    required int seasonNumber,
    String? seasonName,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    final label = seasonName?.trim().isNotEmpty == true
        ? seasonName!.trim()
        : 'Season $seasonNumber';
    if (notes != null && notes.isNotEmpty) {
      return '$showTitle $label: $notes';
    }
    return '$showTitle $label: The story continues with new situations, character moments, and episodes that build the season from beginning to end.';
  }

  static String episode({
    required String showTitle,
    required int seasonNumber,
    required int episodeNumber,
    required String episodeTitle,
    String? alternateTitle,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    final alt = alternateTitle?.trim();
    final displayTitle = alt != null && alt.isNotEmpty
        ? '$episodeTitle — "$alt"'
        : '"$episodeTitle"';
    if (notes != null && notes.isNotEmpty) {
      return '$showTitle Season $seasonNumber Episode $episodeNumber $displayTitle: $notes';
    }
    return '$showTitle Season $seasonNumber Episode $episodeNumber $displayTitle: Join the characters for another chapter as their plans, relationships, and problems take an unexpected turn.';
  }
}

/// Implements the `Profile` class for this feature or UI component.
class Profile {
  final String id;
  String name;
  String username;
  String? avatarUrl;
  ProfileGovernance governance;

  Profile({
    required this.id,
    required this.name,
    String? username,
    this.avatarUrl,
    this.governance = const ProfileGovernance(),
  }) : username = _resolveProfileUsername(username, name);

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Profile',
      username: json['username']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      governance: ProfileGovernance.fromJson(
        json['governance'] is Map
            ? Map<String, dynamic>.from(json['governance'])
            : null,
      ),
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'governance': governance.toJson(),
    };
  }
}

String _resolveProfileUsername(String? username, String name) {
  final supplied = username?.trim() ?? '';
  if (supplied.isNotEmpty) return supplied;
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'profile' : normalized;
}

/// Implements the `UserAccount` class for this feature or UI component.
class UserAccount {
  /// Backend account identifier used to correlate this client with Supabase.
  final String id;
  final String username;
  final String email;
  Subscription subscription;
  final List<Profile> profiles;
  int storageLimitBytes;
  int storageUsedBytes;
  bool storageRequestPending;
  DateTime? storageRequestAt;
  int storageRequestedTerabytes;
  double storageRequestFeeUsd;
  String storageRequestStatus;
  bool allowMembersToManageOwnProfiles;

  UserAccount({
    this.id = '',
    required this.username,
    required this.email,
    required this.subscription,
    List<Profile>? profiles,
    this.storageLimitBytes = 1000000000000,
    this.storageUsedBytes = 0,
    this.storageRequestPending = false,
    this.storageRequestAt,
    this.storageRequestedTerabytes = 0,
    this.storageRequestFeeUsd = 0,
    this.storageRequestStatus = 'none',
    this.allowMembersToManageOwnProfiles = false,
  }) : profiles = profiles ?? [];

  bool get hasActiveSubscription =>
      subscription.status == SubscriptionStatus.active;

  Profile? get firstProfile => profiles.isEmpty ? null : profiles.first;

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'subscription': {
        'plan': subscription.plan.name,
        'status': subscription.status.name,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'storageLimitBytes': storageLimitBytes,
      'storageUsedBytes': storageUsedBytes,
      'storageRequestPending': storageRequestPending,
      'storageRequestAt': storageRequestAt?.toIso8601String(),
      'storageRequestedTerabytes': storageRequestedTerabytes,
      'storageRequestFeeUsd': storageRequestFeeUsd,
      'storageRequestStatus': storageRequestStatus,
      'allowMembersToManageOwnProfiles': allowMembersToManageOwnProfiles,
    };
  }
}

class PageContentCustomization {
  final List<String> sectionOrder;
  final Set<String> hiddenSections;

  PageContentCustomization({
    required List<String> sectionOrder,
    Set<String>? hiddenSections,
  })  : sectionOrder = List<String>.from(sectionOrder),
        hiddenSections = Set<String>.from(hiddenSections ?? const <String>{});

  List<String> get visibleSections => sectionOrder
      .where((section) => !hiddenSections.contains(section))
      .toList();

  PageContentCustomization copy() => PageContentCustomization(
        sectionOrder: sectionOrder,
        hiddenSections: hiddenSections,
      );
}

class PageContentCustomizationStore {
  static const Map<String, List<String>> _defaults = {
    'library': [
      'summary',
      'movies',
      'tv-shows',
      'music',
      'collections',
      'my-tv',
      'favorites',
      'coming-soon',
      'storage',
    ],
    'shop': ['featured', 'related', 'stores', 'media', 'products'],
    'friends': [
      'feed',
      'reels',
      'messages',
      'friends',
      'communities',
      'my-page'
    ],
  };

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, PageContentCustomization> _cache = {};
  static SharedPreferences? _preferences;

  static Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  static List<String> sectionsFor(String pageId) =>
      List<String>.from(_defaults[pageId] ?? const <String>[]);

  static PageContentCustomization settingsFor(
    String pageId, {
    Profile? profile,
  }) {
    final defaults = sectionsFor(pageId);
    if (defaults.isEmpty) {
      return PageContentCustomization(sectionOrder: const <String>[]);
    }
    final profileId =
        profile?.id ?? AppController.instance.currentProfile?.id ?? 'default';
    final cacheKey = '$profileId:$pageId';
    return _cache.putIfAbsent(cacheKey, () {
      final raw = _preferences?.getString('page_content_$cacheKey');
      if (raw == null) {
        return PageContentCustomization(sectionOrder: defaults);
      }
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final storedOrder = (map['sectionOrder'] as List? ?? const [])
            .map((item) => item.toString())
            .where(defaults.contains)
            .toSet();
        final order = <String>[
          ...storedOrder,
          ...defaults.where((item) => !storedOrder.contains(item)),
        ];
        final hidden = (map['hiddenSections'] as List? ?? const [])
            .map((item) => item.toString())
            .where(defaults.contains)
            .toSet();
        if (hidden.length == defaults.length) hidden.remove(hidden.first);
        return PageContentCustomization(
          sectionOrder: order,
          hiddenSections: hidden,
        );
      } catch (_) {
        return PageContentCustomization(sectionOrder: defaults);
      }
    }).copy();
  }

  static Future<void> apply(
    String pageId,
    PageContentCustomization customization, {
    Profile? profile,
  }) async {
    final defaults = sectionsFor(pageId);
    if (defaults.isEmpty) return;
    final profileId =
        profile?.id ?? AppController.instance.currentProfile?.id ?? 'default';
    final allowed = defaults.toSet();
    final order = <String>{
      ...customization.sectionOrder.where(allowed.contains),
      ...defaults,
    }.toList();
    final hidden = customization.hiddenSections.where(allowed.contains).toSet();
    if (hidden.length == order.length) hidden.remove(hidden.first);

    final normalized = PageContentCustomization(
      sectionOrder: order,
      hiddenSections: hidden,
    );
    final cacheKey = '$profileId:$pageId';
    _cache[cacheKey] = normalized;
    await _preferences?.setString(
      'page_content_$cacheKey',
      jsonEncode({
        'sectionOrder': normalized.sectionOrder,
        'hiddenSections': normalized.hiddenSections.toList(),
      }),
    );
    revision.value++;
  }
}

/// Implements the `MediaCollection` class for this feature or UI component.
class MediaCollection {
  final String id;
  String name;
  String description;
  String? createdByProfileId;
  bool isShared;
  bool isOfficial;
  bool isAutomatic;
  bool isFeatured;
  String posterMode;
  String? customPosterUrl;
  String? automaticFranchiseId;
  String? automaticFranchiseType;

  /// Optional live query used by user-created smart collections.
  /// Supported values: liked_movies, liked_shows, liked_media, watched, unwatched.
  String? smartRule;
  String sortMode;
  bool autoPlayEnabled;
  bool autoPlayNextEnabled;
  String autoPlayVersionPreference;
  String autoPlayNextTiming;
  final List<String> mediaIds;
  final List<String> episodeKeys;
  final Set<String> likedByProfileIds;
  final Set<String> contributorProfileIds;
  DateTime createdAt;

  MediaCollection({
    required this.id,
    required this.name,
    this.description = '',
    this.createdByProfileId,
    this.isShared = true,
    this.isOfficial = false,
    this.isAutomatic = false,
    this.isFeatured = false,
    this.posterMode = 'First 4 Posters',
    this.customPosterUrl,
    this.automaticFranchiseId,
    this.automaticFranchiseType,
    this.smartRule,
    this.sortMode = 'Collection order',
    this.autoPlayEnabled = true,
    this.autoPlayNextEnabled = true,
    this.autoPlayVersionPreference = 'Preferred version',
    this.autoPlayNextTiming = 'End credits',
    List<String>? mediaIds,
    List<String>? episodeKeys,
    Set<String>? likedByProfileIds,
    Set<String>? contributorProfileIds,
    DateTime? createdAt,
  })  : mediaIds = mediaIds ?? <String>[],
        episodeKeys = episodeKeys ?? <String>[],
        likedByProfileIds = likedByProfileIds ?? <String>{},
        contributorProfileIds = contributorProfileIds ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  bool get isLikedByCurrentProfile {
    final id = AppController.instance.currentProfile?.id;
    return id != null && likedByProfileIds.contains(id);
  }

  /// Performs `canCurrentProfileEdit` for this feature. Update this documentation when its contract changes.
  bool canCurrentProfileEdit() {
    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null) return false;
    return profileId == createdByProfileId ||
        contributorProfileIds.contains(profileId);
  }

  /// Performs `canCurrentProfileAdd` for this feature. Update this documentation when its contract changes.
  bool canCurrentProfileAdd() {
    if (!isShared) {
      return AppController.instance.currentProfile?.id == createdByProfileId;
    }
    return canCurrentProfileEdit();
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdByProfileId': createdByProfileId,
        'isShared': isShared,
        'isOfficial': isOfficial,
        'isAutomatic': isAutomatic,
        'isFeatured': isFeatured,
        'posterMode': posterMode,
        'customPosterUrl': customPosterUrl,
        'automaticFranchiseId': automaticFranchiseId,
        'automaticFranchiseType': automaticFranchiseType,
        'smartRule': smartRule,
        'sortMode': sortMode,
        'autoPlayEnabled': autoPlayEnabled,
        'autoPlayNextEnabled': autoPlayNextEnabled,
        'autoPlayVersionPreference': autoPlayVersionPreference,
        'autoPlayNextTiming': autoPlayNextTiming,
        'mediaIds': mediaIds,
        'episodeKeys': episodeKeys,
        'likedByProfileIds': likedByProfileIds.toList(),
        'contributorProfileIds': contributorProfileIds.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory MediaCollection.fromJson(Map<String, dynamic> json) =>
      MediaCollection(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Collection',
        description: json['description']?.toString() ?? '',
        createdByProfileId: json['createdByProfileId']?.toString(),
        isShared: json['isShared'] != false,
        isOfficial: json['isOfficial'] == true,
        isAutomatic: json['isAutomatic'] == true,
        isFeatured: json['isFeatured'] == true,
        posterMode: json['posterMode']?.toString() ?? 'First 4 Posters',
        customPosterUrl: json['customPosterUrl']?.toString(),
        automaticFranchiseId: json['automaticFranchiseId']?.toString(),
        automaticFranchiseType: json['automaticFranchiseType']?.toString(),
        smartRule: json['smartRule']?.toString(),
        sortMode: json['sortMode']?.toString() ?? 'Collection order',
        autoPlayEnabled: json['autoPlayEnabled'] != false,
        autoPlayNextEnabled: json['autoPlayNextEnabled'] != false,
        autoPlayVersionPreference:
            json['autoPlayVersionPreference']?.toString() ??
                'Preferred version',
        autoPlayNextTiming:
            json['autoPlayNextTiming']?.toString() ?? 'End credits',
        // Accept the older titleIds field when loading existing collection data.
        // The current MediaCollection model uses mediaIds.
        mediaIds: ((json['mediaIds'] ?? json['titleIds']) as List?)
            ?.map((e) => e.toString())
            .toList(),
        episodeKeys:
            (json['episodeKeys'] as List?)?.map((e) => e.toString()).toList(),
        likedByProfileIds: (json['likedByProfileIds'] as List?)
            ?.map((e) => e.toString())
            .toSet(),
        contributorProfileIds: (json['contributorProfileIds'] as List?)
            ?.map((e) => e.toString())
            .toSet(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

/// Implements the `CollectionPreferences` class for this feature or UI component.
class CollectionPreferences {
  String collectionOrder;
  String layout;
  String automaticPosition;
  String customPosition;
  String itemLayout;
  String itemSort;

  CollectionPreferences({
    this.collectionOrder = 'Automatic first',
    this.layout = 'Grid',
    this.automaticPosition = 'Top',
    this.customPosition = 'Bottom',
    this.itemLayout = 'Grid',
    this.itemSort = 'Collection order',
  });

  CollectionPreferences copy() => CollectionPreferences(
        collectionOrder: collectionOrder,
        layout: layout,
        automaticPosition: automaticPosition,
        customPosition: customPosition,
        itemLayout: itemLayout,
        itemSort: itemSort,
      );
}

/// Implements the `ActivityItem` class for this feature or UI component.
class ActivityItem {
  final String id;
  final String title;
  final String action;
  final DateTime timestamp;
  bool read;

  ActivityItem({
    required this.id,
    required this.title,
    required this.action,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'MyOwnStreamingService',
        action: json['action']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        read: json['read'] == true,
      );
}

/// Implements the `BackendGroupChatMessage` class for this feature or UI component.
class BackendGroupChatMessage {
  final String id;
  final String profileId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String? badgeName;

  BackendGroupChatMessage(
      {required this.id,
      required this.profileId,
      required this.senderName,
      required this.message,
      required this.timestamp,
      this.badgeName});

  factory BackendGroupChatMessage.fromJson(Map<String, dynamic> json) =>
      BackendGroupChatMessage(
        id: json['id']?.toString() ?? '',
        profileId: json['profileId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'Profile',
        message: json['message']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        badgeName: json['badgeName']?.toString(),
      );
}

/// Implements the `BackendGroupChatRoom` class for this feature or UI component.
class BackendGroupChatRoom {
  final String id;
  final String name;
  final List<Map<String, dynamic>> members;
  final List<BackendGroupChatMessage> messages;
  BackendGroupChatRoom(
      {required this.id,
      required this.name,
      required this.members,
      required this.messages});

  factory BackendGroupChatRoom.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final rawMessages = json['messages'];
    return BackendGroupChatRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Group Room',
      members: rawMembers is List
          ? rawMembers
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : <Map<String, dynamic>>[],
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((m) => BackendGroupChatMessage.fromJson(
                  Map<String, dynamic>.from(m)))
              .toList()
          : <BackendGroupChatMessage>[],
    );
  }
}

/// Implements the `ChatMessage` class for this feature or UI component.
class ChatMessage {
  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}

/// Implements the `WishlistItem` class for this feature or UI component.
class WishlistItem {
  final String id;
  final String title;
  final String type;

  WishlistItem({
    required this.id,
    required this.title,
    required this.type,
  });
}

/// Frontend representation of one participant in a Group Watch session.
///
/// Audio and subtitle selections are stored independently for every
/// participant. Playback position and play/pause state are shared by the
/// entire Group Watch session.
class GroupWatchParticipant {
  final String profileId;
  String profileName;
  String invitationStatus;
  String? audioTrackId;
  String? subtitleTrackId;
  DateTime? joinedAt;

  GroupWatchParticipant({
    required this.profileId,
    required this.profileName,
    this.invitationStatus = 'pending',
    this.audioTrackId,
    this.subtitleTrackId,
    this.joinedAt,
  });

  bool get isAccepted => invitationStatus.toLowerCase() == 'accepted';

  bool get isPending => invitationStatus.toLowerCase() == 'pending';

  bool get isDeclined => invitationStatus.toLowerCase() == 'declined';

  bool get isExpired => invitationStatus.toLowerCase() == 'expired';

  factory GroupWatchParticipant.fromJson(
    Map<String, dynamic> json, {
    String? fallbackProfileName,
  }) {
    final profileId = json['profileId']?.toString() ?? '';

    return GroupWatchParticipant(
      profileId: profileId,
      profileName:
          json['profileName']?.toString() ?? fallbackProfileName ?? 'Profile',
      invitationStatus: json['invitationStatus']?.toString() ?? 'pending',
      audioTrackId: json['audioTrackId']?.toString(),
      subtitleTrackId: json['subtitleTrackId']?.toString(),
      joinedAt: _dateTimeFromJson(
        json['joinedAt'],
      ),
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'invitationStatus': invitationStatus,
      'audioTrackId': audioTrackId,
      'subtitleTrackId': subtitleTrackId,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }
}

/// Backend-connected Group Watch session.
///
/// Playback state is global to the session while audio and subtitle
/// selections remain participant-specific.
class GroupWatchSession {
  final String id;
  final String title;
  final String mediaId;
  final String type;
  final String hostProfileId;

  final List<String> participants;

  final Map<String, GroupWatchParticipant> participantStates;

  String status;
  DateTime createdAt;
  DateTime? invitationExpiresAt;
  DateTime? startedAt;
  DateTime? endedAt;

  Duration playbackPosition;
  bool isPlaying;

  String? pausedByProfileId;
  String? pauseReason;

  /// Compatibility property retained for older UI code.
  ///
  /// Actual synchronization is controlled by the backend.
  bool synchronized;

  GroupWatchSession({
    required this.id,
    required this.title,
    this.mediaId = '',
    this.type = 'movie',
    this.hostProfileId = '',
    required this.participants,
    Map<String, GroupWatchParticipant>? participantStates,
    this.status = 'waiting',
    DateTime? createdAt,
    this.invitationExpiresAt,
    this.startedAt,
    this.endedAt,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
    this.pausedByProfileId,
    this.pauseReason,
    this.synchronized = true,
  })  : participantStates =
            participantStates ?? <String, GroupWatchParticipant>{},
        createdAt = createdAt ?? DateTime.now();

  bool get isWaiting => status.toLowerCase() == 'waiting';

  bool get isReady => status.toLowerCase() == 'ready';

  bool get isPlayingStatus => status.toLowerCase() == 'playing';

  bool get isPaused => status.toLowerCase() == 'paused';

  bool get isEnded => status.toLowerCase() == 'ended';

  bool get invitationsExpired {
    final currentStatus = status.toLowerCase();

    if (currentStatus != 'waiting' && currentStatus != 'ready') {
      return true;
    }

    final expiry = invitationExpiresAt;

    if (expiry == null) {
      return false;
    }

    return DateTime.now().isAfter(expiry);
  }

  /// Performs `canResume` for this feature. Update this documentation when its contract changes.
  bool canResume(String profileId) {
    return pausedByProfileId == profileId;
  }

  GroupWatchParticipant? participantForProfile(
    String profileId,
  ) {
    return participantStates[profileId];
  }

  factory GroupWatchSession.fromJson(
    Map<String, dynamic> json, {
    List<Profile> knownProfiles = const <Profile>[],
  }) {
    final participantStates = <String, GroupWatchParticipant>{};

    final participantData = json['participants'];

    if (participantData is Map) {
      participantData.forEach(
        (key, value) {
          if (value is! Map) {
            return;
          }

          final participantMap = Map<String, dynamic>.from(
            value,
          );

          final profileId =
              participantMap['profileId']?.toString() ?? key.toString();

          if (profileId.isEmpty) {
            return;
          }

          final knownProfile = _profileFromList(
            knownProfiles,
            profileId,
          );

          participantStates[profileId] = GroupWatchParticipant.fromJson(
            participantMap,
            fallbackProfileName: knownProfile?.name,
          );
        },
      );
    } else if (participantData is List) {
      for (final item in participantData) {
        if (item is! Map) {
          continue;
        }

        final participantMap = Map<String, dynamic>.from(
          item,
        );

        final profileId = participantMap['profileId']?.toString() ?? '';

        if (profileId.isEmpty) {
          continue;
        }

        final knownProfile = _profileFromList(
          knownProfiles,
          profileId,
        );

        participantStates[profileId] = GroupWatchParticipant.fromJson(
          participantMap,
          fallbackProfileName: knownProfile?.name,
        );
      }
    }

    final participantNames = <String>[];

    for (final participant in participantStates.values) {
      participantNames.add(
        participant.profileName,
      );
    }

    final positionSeconds = _doubleFromJson(
      json['playbackPosition'],
    );

    return GroupWatchSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'movie',
      hostProfileId: json['hostProfileId']?.toString() ?? '',
      participants: participantNames,
      participantStates: participantStates,
      status: json['status']?.toString() ?? 'waiting',
      createdAt: _dateTimeFromJson(
            json['createdAt'],
          ) ??
          DateTime.now(),
      invitationExpiresAt: _dateTimeFromJson(
        json['invitationExpiresAt'],
      ),
      startedAt: _dateTimeFromJson(
        json['startedAt'],
      ),
      endedAt: _dateTimeFromJson(
        json['endedAt'],
      ),
      playbackPosition: Duration(
        milliseconds: (positionSeconds * 1000).round(),
      ),
      isPlaying: json['isPlaying'] == true,
      pausedByProfileId: json['pausedByProfileId']?.toString(),
      pauseReason: json['pauseReason']?.toString(),
      synchronized: true,
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaId': mediaId,
      'type': type,
      'hostProfileId': hostProfileId,
      'participants': participantStates.map(
        (key, value) => MapEntry(
          key,
          value.toJson(),
        ),
      ),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'invitationExpiresAt': invitationExpiresAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'playbackPosition': playbackPosition.inMilliseconds / 1000.0,
      'isPlaying': isPlaying,
      'pausedByProfileId': pausedByProfileId,
      'pauseReason': pauseReason,
    };
  }
}

/// Keep the curated international catalog visible before the rest of a long
/// local library while preserving the original order inside each group.
List<MediaItem> internationalCatalogFirst(Iterable<MediaItem> items) {
  final values = items.toList(growable: false);
  return <MediaItem>[
    ...values.where((item) => item.tags.contains('international-catalog')),
    ...values.where((item) => !item.tags.contains('international-catalog')),
  ];
}

/// Implements the `AppController` class for this feature or UI component.
/// True for files created by the ARM mock worker, which are text placeholders
/// rather than real video/audio assets.
bool isArmMockServerMediaId(String id) => id
    .replaceAll('\\', '/')
    .toLowerCase()
    .startsWith('arm_mock/');

/// Normalizes scanner-derived display titles without inventing catalog metadata.
String normalizeHomeServerMediaTitle(String raw) {
  var value = raw.trim().replaceFirst(RegExp(r'\.[^.]+$'), '');
  value = value
      .replaceFirst(RegExp(r'^\d{10,}[_\s-]+'), '')
      .replaceAll(RegExp(r'[._]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return value.isEmpty ? 'Imported Media' : value;
}

class AppController extends ChangeNotifier {
  Map<String, dynamic>? lastLoginSecurity;

  AppController._();

  static final AppController instance = AppController._();

  final BackendApi backendApi = BackendApi();

  bool get isBackendAuthenticated => backendApi.isAuthenticated;

  String? get backendToken => backendApi.token;

  UserAccount? currentAccount;
  Profile? currentProfile;
  PlatformServer? currentServer;
  String? currentDeviceId;
  String? activePlaybackSessionId;

  final List<MediaItem> library = <MediaItem>[];

  // Profile-scoped removals survive server scans, app restarts, and login
  // restoration. Media files are never deleted by Remove from Library.
  String? _loadedLibraryMembershipScope;
  final Set<String> _hiddenLibraryMediaIds = <String>{};

  String get _libraryMembershipScope {
    final accountId = currentAccount?.id.trim();
    final profileId = currentProfile?.id.trim();
    final accountScope =
        accountId != null && accountId.isNotEmpty ? accountId : 'local';
    final profileScope =
        profileId != null && profileId.isNotEmpty ? profileId : 'guest';
    return '$accountScope::$profileScope';
  }

  bool _isHiddenFromCurrentProfile(String mediaId) {
    return _loadedLibraryMembershipScope == _libraryMembershipScope &&
        _hiddenLibraryMediaIds.contains(mediaId.trim());
  }

  Future<void> _ensureLibraryMembershipLoaded() async {
    final scope = _libraryMembershipScope;
    if (_loadedLibraryMembershipScope == scope) return;

    final hiddenIds = await LibraryMembershipStore(scopeId: scope)
        .loadHiddenMediaIds();
    // A profile switch may happen while the preferences read is pending.
    if (_libraryMembershipScope != scope) return;

    _hiddenLibraryMediaIds
      ..clear()
      ..addAll(hiddenIds);
    _loadedLibraryMembershipScope = scope;

    final oldLength = library.length;
    library.removeWhere((item) => hiddenIds.contains(item.id.trim()));
    if (library.length != oldLength) {
      _refreshAutomaticCollections();
      notifyListeners();
    }
  }

  Future<void> _saveLibraryMembership(Set<String> hiddenIds,
      {required String scope}) async {
    await LibraryMembershipStore(scopeId: scope).saveHiddenMediaIds(hiddenIds);
    if (_libraryMembershipScope != scope) {
      throw StateError('The active profile changed before the library update completed.');
    }
    _hiddenLibraryMediaIds
      ..clear()
      ..addAll(hiddenIds);
    _loadedLibraryMembershipScope = scope;
  }

  // Catalog sections populated when a confirmed ARM import is added.
  final List<String> actorsCatalog = <String>[];
  final List<String> directorsCatalog = <String>[];
  final List<String> writersCatalog = <String>[];
  final List<String> musicCatalog = <String>[];
  final List<String> genresCatalog = <String>[];
  final List<String> tagsCatalog = <String>[];

  final List<MediaCollection> collections = <MediaCollection>[];
  final List<String> collectionSectionOrder = <String>[
    'Featured Collections',
    'My Collections',
    'Liked Collections',
  ];
  final List<String> featuredCollectionOrder = <String>[];
  final Map<String, CollectionPreferences> collectionPreferencesByProfile =
      <String, CollectionPreferences>{};

  final List<MediaItem> watched = <MediaItem>[];

  final List<MediaItem> liked = <MediaItem>[];

  final List<MediaItem> disliked = <MediaItem>[];

  final List<ActivityItem> activity = <ActivityItem>[];
  String? _loadedActivityStorageKey;
  int _activityLoadGeneration = 0;
  int _activityRevision = 0;
  bool _activityNeedsMerge = false;
  Future<void> _activityPersistenceQueue = Future<void>.value();

  String get _activityStorageKey {
    final profileId = currentProfile?.id;
    final accountId = currentAccount?.id;
    final scope = (profileId != null && profileId.isNotEmpty)
        ? 'profile_$profileId'
        : (accountId != null && accountId.isNotEmpty
            ? 'account_$accountId'
            : 'guest');
    return 'moss_activity_feed_$scope';
  }

  int get unreadActivityCount => activity.where((item) => !item.read).length;

  final List<ChatMessage> groupMessages = <ChatMessage>[];

  // Monthly profile viewing activity used to award the profile's current badge.
  // Events are retained locally so the badge can change automatically when a
  // new calendar month begins.
  final Map<String, List<Map<String, dynamic>>> _monthlyWatchEvents =
      <String, List<Map<String, dynamic>>>{};
  SharedPreferences? _badgePrefs;
  bool _badgeDataLoaded = false;

  BackendGroupChatRoom? activeGroupChatRoom;
  bool groupChatLoading = false;
  String? groupChatError;

  final List<WishlistItem> wishlist = <WishlistItem>[];

  final List<GroupWatchSession> groupWatchSessions = <GroupWatchSession>[];

  final Map<String, double> playbackProgress = <String, double>{};

  final Map<String, String> nextEpisodes = <String, String>{};

  final Set<String> activeProfileIds = <String>{};

  List<MediaItem> recommendations = <MediaItem>[];

  bool recommendationsLoading = false;

  String? recommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> groupRecommendations = <Map<String, dynamic>>[];

  bool groupRecommendationsLoading = false;

  String? groupRecommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  bool groupWishlistLoading = false;

  String? groupWishlistError;

  // ---------------------------------------------------------------------------
  // GROUP WATCH STATE
  // ---------------------------------------------------------------------------

  bool groupWatchLoading = false;

  String? groupWatchError;

  String? activeGroupWatchSessionId;

  GroupWatchSession? get activeGroupWatchSession {
    final id = activeGroupWatchSessionId;

    if (id == null || id.isEmpty) {
      return null;
    }

    return getGroupWatchSession(id);
  }

  // ---------------------------------------------------------------------------
  // MONTHLY BADGES
  // ---------------------------------------------------------------------------

  Future<void> initializeBadges() async {
    if (_badgeDataLoaded) return;
    _badgePrefs = await SharedPreferences.getInstance();
    for (final key in _badgePrefs!.getKeys()) {
      if (!key.startsWith('monthly_watch_events_')) continue;
      final profileId = key.substring('monthly_watch_events_'.length);
      final raw = _badgePrefs!.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _monthlyWatchEvents[profileId] = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Ignore malformed legacy badge data.
      }
    }
    _badgeDataLoaded = true;
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _saveMonthlyWatchEvents(String profileId) async {
    final prefs = _badgePrefs;
    if (prefs == null) return;
    await prefs.setString(
      'monthly_watch_events_$profileId',
      jsonEncode(_monthlyWatchEvents[profileId] ?? <Map<String, dynamic>>[]),
    );
  }

  void _recordMonthlyWatch(MediaItem media) {
    final profileId = currentProfile?.id;
    if (profileId == null || profileId.isEmpty) return;
    final now = DateTime.now();
    final events = _monthlyWatchEvents.putIfAbsent(
        profileId, () => <Map<String, dynamic>>[]);
    final month = _monthKey(now);
    // Watching the same title more than once in a month counts once toward the
    // monthly title badge, while the watched list still controls overall state.
    if (events.any((e) => e['month'] == month && e['mediaId'] == media.id)) {
      return;
    }
    events.add({
      'month': month,
      'mediaId': media.id,
      'title': media.title,
      'type': media.type,
      'genres': media.genres,
      'timestamp': now.toIso8601String(),
    });
    // Keep a reasonable local history while preserving enough months to show
    // the current badge and future badge history.
    if (events.length > 5000) events.removeRange(0, events.length - 5000);
    _saveMonthlyWatchEvents(profileId);
  }

  String badgeForProfile(String profileId, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final month = _monthKey(date);
    final events = (_monthlyWatchEvents[profileId] ?? <Map<String, dynamic>>[])
        .where((e) => e['month'] == month)
        .toList();
    if (events.isEmpty) return 'The Explorer';

    final movieCount = events
        .where((e) => (e['type']?.toString().toLowerCase() ?? '') == 'movie')
        .length;
    final showCount = events.where((e) {
      final type = e['type']?.toString().toLowerCase() ?? '';
      return type == 'tvshow' ||
          type == 'tv_show' ||
          type == 'tv show' ||
          type == 'series';
    }).length;
    final genres = <String>{};
    for (final event in events) {
      final rawGenres = event['genres'];
      if (rawGenres is List) {
        genres.addAll(rawGenres
            .map((g) => g.toString().trim().toLowerCase())
            .where((g) => g.isNotEmpty));
      }
    }

    if (events.length >= 20) return 'Binge Master';
    if (genres.length >= 6) return 'Genre Explorer';
    if (movieCount >= 10) return 'Movie Buff';
    if (showCount >= 8) return 'Series Fan';
    if (events.length >= 5) return 'Regular Viewer';
    return 'The Explorer';
  }

  String currentProfileBadge() {
    final id = currentProfile?.id;
    return id == null || id.isEmpty ? 'The Explorer' : badgeForProfile(id);
  }

  // ---------------------------------------------------------------------------
  // LOCAL ACCOUNT CREATION
  // ---------------------------------------------------------------------------

  UserAccount createAccount({
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    // Internal username for compatibility.
    //// The user does not enter or choose this username.
    final username = cleanEmail.split('@').first;
    final cleanedFirstProfileName = firstProfileName.trim();
    final firstProfile = Profile(
      id: _generateId('profile'),
      name: cleanedFirstProfileName.isEmpty
          ? 'Profile 1'
          : cleanedFirstProfileName,
    );
    final account = UserAccount(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      username: username,
      email: email.trim(),
      subscription: Subscription(
        plan: plan,
        status: SubscriptionStatus.active,
      ),
      profiles: <Profile>[firstProfile],
    );

    currentAccount = account;
    currentProfile = firstProfile;
    activeProfileIds
      ..clear()
      ..add(firstProfile.id);
    unawaited(_ensureLibraryMembershipLoaded());
    collections.clear();
    seedCollections();

    groupWatchSessions.clear();
    activeGroupWatchSessionId = null;
    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return account;
  }

  // ---------------------------------------------------------------------------
  // BACKEND SIGNUP
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createAccountWithBackend({
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final planValue = plan == SubscriptionPlan.yearly ? 'yearly' : 'monthly';

    final response = await backendApi.signup(
      email: email.trim(),
      password: password,
      plan: planValue,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      termsVersion: '2026-09-10',
      privacyVersion: '2026-09-10',
      acceptableUseVersion: '2026-09-10',
    );

    final accountData = response['account'];

    final subscriptionData = response['subscription'];

    String accountUsername = email.trim();

    String accountEmail = email.trim();

    if (accountData is Map) {
      final backendUsername = accountData['username']?.toString();

      final backendEmail = accountData['email']?.toString();

      if (backendUsername != null && backendUsername.isNotEmpty) {
        accountUsername = backendUsername;
      }

      if (backendEmail != null && backendEmail.isNotEmpty) {
        accountEmail = backendEmail;
      }
    }

    SubscriptionStatus subscriptionStatus = SubscriptionStatus.expired;

    if (subscriptionData is Map) {
      final statusValue = subscriptionData['status']?.toString().toLowerCase();

      if (statusValue == 'active') {
        subscriptionStatus = SubscriptionStatus.active;
      }
    }

    final localSubscription = Subscription(
      plan: plan,
      status: subscriptionStatus,
    );

    final List<Profile> profiles = <Profile>[];

    if (accountData is Map) {
      final profilesData = accountData['profiles'];

      if (profilesData is List) {
        for (final item in profilesData) {
          if (item is Map) {
            profiles.add(
              Profile.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }
    }

    // New backend accounts are allowed to have zero profiles.

    final account = UserAccount(
      username: accountUsername,
      email: accountEmail,
      subscription: localSubscription,
      profiles: profiles,
      storageLimitBytes:
          accountData is Map && accountData['storageLimitBytes'] is num
              ? (accountData['storageLimitBytes'] as num).toInt()
              : 1000000000000,
      storageUsedBytes:
          accountData is Map && accountData['storageUsedBytes'] is num
              ? (accountData['storageUsedBytes'] as num).toInt()
              : 0,
      storageRequestPending:
          accountData is Map && accountData['storageRequestPending'] == true,
      storageRequestAt:
          accountData is Map && accountData['storageRequestAt'] != null
              ? DateTime.tryParse(accountData['storageRequestAt'].toString())
              : null,
      storageRequestedTerabytes:
          accountData is Map && accountData['storageRequestedTerabytes'] is num
              ? (accountData['storageRequestedTerabytes'] as num).toInt()
              : 0,
      storageRequestFeeUsd:
          accountData is Map && accountData['storageRequestFeeUsd'] is num
              ? (accountData['storageRequestFeeUsd'] as num).toDouble()
              : 0,
      storageRequestStatus: accountData is Map
          ? accountData['storageRequestStatus']?.toString() ?? 'none'
          : 'none',
    );

    currentAccount = account;
    currentProfile = profiles.isEmpty ? null : profiles.first;
    _loadedLibraryMembershipScope = null;
    _hiddenLibraryMediaIds.clear();
    await _ensureLibraryMembershipLoaded();

    activeProfileIds.clear();
    if (profiles.isNotEmpty) {
      activeProfileIds.add(profiles.first.id);
    }

    backendApi.clearToken();

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError = null;
    groupRecommendationsLoading = false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return response;
  }

  // ---------------------------------------------------------------------------
  // SUPABASE SYNCHRONIZATION
  // ---------------------------------------------------------------------------

  /// Uploads the current account's sanitized application metadata to Supabase
  /// through the authenticated backend service.
  ///
  /// Passwords, security hashes, session tokens, and physical media files are
  /// never included in this synchronization payload.
  Future<Map<String, dynamic>> syncCurrentAccountToSupabase() async {
    final account = currentAccount;
    if (account == null) {
      throw BackendApiException('No account is currently loaded.');
    }
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
          'You must be logged in before synchronizing account data.');
    }

    final snapshot = <String, dynamic>{
      'account': account.toJson(),
      'currentProfileId': currentProfile?.id,
      'activeProfileIds': List<String>.from(activeProfileIds),
      'libraryMediaIds': library.map((m) => m.id).toList(),
      'watchedMediaIds': watched.map((m) => m.id).toList(),
      'playbackProgress': Map<String, double>.from(playbackProgress),
      'likedMediaIds': liked.map((m) => m.id).toList(),
      'collections': collections.map((c) => c.toJson()).toList(),
      'groupWatchSessions': groupWatchSessions.map((s) => s.toJson()).toList(),
    };

    return backendApi.syncAccountToSupabase(snapshot: snapshot);
  }

  /// Synchronizes after a storage change without making UI code know about
  /// the persistence transport. A sync failure is deliberately rethrown so
  /// callers can show a retry message when appropriate.
  Future<void> syncStorageStateToSupabase() async {
    await syncCurrentAccountToSupabase();
  }

  // ---------------------------------------------------------------------------
  // SERVER / DEVICE CONTEXT
  // ---------------------------------------------------------------------------

  Future<ServerContext> loadServerContext() async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException('You are not logged in.');
    }
    final data = await backendApi.getServerContext();
    final context = ServerContext.fromJson(data);
    currentServer = context.currentServer;
    notifyListeners();
    return context;
  }

  Future<void> claimServer(
      {required String serverId, required String displayName}) async {
    final data = await backendApi.claimServer(
        serverId: serverId, displayName: displayName);
    final server = data['server'];
    if (server is! Map) {
      throw BackendApiException('The server assignment response was invalid.');
    }
    currentServer = PlatformServer.fromJson(Map<String, dynamic>.from(server));
    notifyListeners();
  }

  Future<void> renameCurrentServer(String displayName) async {
    final data = await backendApi.renameServer(displayName: displayName);
    final server = data['server'];
    if (server is Map) {
      currentServer =
          PlatformServer.fromJson(Map<String, dynamic>.from(server));
    }
    notifyListeners();
  }

  Future<String> ensureDeviceId() async {
    if (currentDeviceId != null && currentDeviceId!.isNotEmpty) {
      return currentDeviceId!;
    }
    final prefs = await SharedPreferences.getInstance();
    currentDeviceId = prefs.getString('platform_device_id');
    if (currentDeviceId == null || currentDeviceId!.isEmpty) {
      currentDeviceId =
          'device_${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('platform_device_id', currentDeviceId!);
    }
    return currentDeviceId!;
  }

  Future<void> activateProfile(String profileId) async {
    switchProfile(profileId);
    final profile = currentProfile;
    if (profile == null || !backendApi.isAuthenticated) return;
    final deviceId = await ensureDeviceId();
    await backendApi.registerMediaDevice(
      profileId: profile.id,
      deviceId: deviceId,
      name: 'This device',
      type: kIsWeb ? 'web' : 'mobile',
    );
  }

  // ---------------------------------------------------------------------------
  // BACKEND SESSION RESTORE
  // ---------------------------------------------------------------------------

  /// Restores a previously authenticated account from the encrypted device session.
  Future<bool> restoreBackendSession() async {
    try {
      final restored = await backendApi.restoreToken();
      if (!restored) return false;

      final response = await backendApi.getCurrentAccount();
      final accountData = response['account'];
      if (accountData is! Map) {
        throw BackendApiException(
            'The saved session returned an invalid account.');
      }

      _applyBackendAccount(Map<String, dynamic>.from(accountData));
      await _ensureLibraryMembershipLoaded();
      final restoredProfileId = currentProfile?.id;
      if (library.isEmpty && restoredProfileId != null) {
        await restoreOfflineMetadataCache(profileId: restoredProfileId);
      }
      notifyListeners();
      return true;
    } catch (_) {
      await backendApi.clearToken();
      currentAccount = null;
      currentProfile = null;
      _loadedLibraryMembershipScope = null;
      _hiddenLibraryMediaIds.clear();
      return false;
    }
  }

  /// Applies backend account data to the local account/profile model.
  void _applyBackendAccount(Map<String, dynamic> accountMap) {
    final username = accountMap['username']?.toString() ?? '';
    final accountEmail = accountMap['email']?.toString() ?? '';
    if (username.isEmpty || accountEmail.isEmpty) {
      throw BackendApiException(
          'The server returned incomplete account information.');
    }

    final subscriptionData = accountMap['subscription'];
    var plan = SubscriptionPlan.monthly;
    if (subscriptionData is Map &&
        subscriptionData['plan']?.toString().toLowerCase() == 'yearly') {
      plan = SubscriptionPlan.yearly;
    }
    var subscriptionStatus = SubscriptionStatus.expired;
    if (subscriptionData is Map &&
        subscriptionData['status']?.toString().toLowerCase() == 'active') {
      subscriptionStatus = SubscriptionStatus.active;
    }

    final profiles = <Profile>[];
    final profilesData = accountMap['profiles'];
    if (profilesData is List) {
      for (final item in profilesData) {
        if (item is Map) {
          profiles.add(Profile.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    currentAccount = UserAccount(
      id: accountMap['id']?.toString() ?? '',
      username: username,
      email: accountEmail,
      subscription: Subscription(plan: plan, status: subscriptionStatus),
      profiles: profiles,
      storageLimitBytes: accountMap['storageLimitBytes'] is num
          ? (accountMap['storageLimitBytes'] as num).toInt()
          : 1000000000000,
      storageUsedBytes: accountMap['storageUsedBytes'] is num
          ? (accountMap['storageUsedBytes'] as num).toInt()
          : 0,
      storageRequestPending: accountMap['storageRequestPending'] == true,
      storageRequestAt: accountMap['storageRequestAt'] != null
          ? DateTime.tryParse(accountMap['storageRequestAt'].toString())
          : null,
      storageRequestedTerabytes: accountMap['storageRequestedTerabytes'] is num
          ? (accountMap['storageRequestedTerabytes'] as num).toInt()
          : 0,
      storageRequestFeeUsd: accountMap['storageRequestFeeUsd'] is num
          ? (accountMap['storageRequestFeeUsd'] as num).toDouble()
          : 0,
      storageRequestStatus:
          accountMap['storageRequestStatus']?.toString() ?? 'none',
      allowMembersToManageOwnProfiles:
          accountMap['allowMembersToManageOwnProfiles'] == true,
    );
    currentProfile = profiles.isEmpty ? null : profiles.first;
    activeProfileIds
      ..clear()
      ..addAll(
          currentProfile == null ? <String>[] : <String>[currentProfile!.id]);

    if (_loadedLibraryMembershipScope != _libraryMembershipScope) {
      _loadedLibraryMembershipScope = null;
      _hiddenLibraryMediaIds.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGIN
  // ---------------------------------------------------------------------------

  /// Performs `loginWithBackend` for this feature. Update this documentation when its contract changes.
  Future<Map<String, dynamic>> loginWithBackend({
    required String email,
    required String password,
  }) async {
    final response = await backendApi.login(
      email: email.trim().toLowerCase(),
      password: password,
    );

    lastLoginSecurity = response['security'] is Map
        ? Map<String, dynamic>.from(response['security'] as Map)
        : null;

    if (response['requiresMfa'] == true) {
      return response;
    }

    final accountData = response['account'];
    if (accountData is! Map) {
      throw BackendApiException(
          'The server returned an invalid account response.');
    }

    _applyBackendAccount(Map<String, dynamic>.from(accountData));
    await _ensureLibraryMembershipLoaded();

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError = null;
    groupRecommendationsLoading = false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    if (SupabaseService.instance.isConfigured) {
      try {
        await syncCurrentAccountToSupabase();
      } catch (_) {
        // Supabase is persistence-enhancing; a temporary outage must not block login.
      }
    }

    await loadRecommendations();
    await loadGroupWishlist();
    await loadGroupRecommendations();
    await loadGroupWatchSessions();
    return response;
  }

  // ---------------------------------------------------------------------------
  // BACKEND ACCOUNT REFRESH
  // ---------------------------------------------------------------------------

  void applyBackendAccountFromResponse(Map<String, dynamic> response) {
    final accountData = response['account'];
    if (accountData is! Map) {
      throw BackendApiException(
          'The server returned an invalid account response.');
    }
    _applyBackendAccount(Map<String, dynamic>.from(accountData));
    unawaited(_ensureLibraryMembershipLoaded());
    notifyListeners();
  }

  Future<Map<String, dynamic>> refreshBackendAccount() async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You are not logged in.',
      );
    }

    if (currentAccount == null) {
      throw BackendApiException(
        'No account is currently loaded.',
      );
    }

    final response = await backendApi.getCurrentAccount();
    final accountData = response['account'];
    if (accountData is! Map) {
      throw BackendApiException(
          'The server returned an invalid account response.');
    }
    _applyBackendAccount(Map<String, dynamic>.from(accountData));
    await _ensureLibraryMembershipLoaded();
    notifyListeners();
    return response;
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGOUT
  // ---------------------------------------------------------------------------

  /// Performs `logoutFromBackend` for this feature. Update this documentation when its contract changes.
  Future<void> logoutFromBackend() async {
    try {
      if (backendApi.isAuthenticated) {
        await backendApi.logout();
      }
    } finally {
      await backendApi.clearToken();

      currentAccount = null;
      currentProfile = null;
      _loadedLibraryMembershipScope = null;
      _hiddenLibraryMediaIds.clear();
      currentServer = null;
      activePlaybackSessionId = null;

      activeProfileIds.clear();

      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;

      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading = false;

      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      groupWatchSessions.clear();
      groupWatchError = null;
      groupWatchLoading = false;
      activeGroupWatchSessionId = null;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // LOCAL LOGIN
  // ---------------------------------------------------------------------------

  /// Performs `login` for this feature. Update this documentation when its contract changes.
  bool login(
    String usernameOrEmail,
    String password,
  ) {
    if (currentAccount == null) {
      return false;
    }

    final matchesUsername = currentAccount!.username.toLowerCase() ==
        usernameOrEmail.trim().toLowerCase();

    final matchesEmail = currentAccount!.email.toLowerCase() ==
        usernameOrEmail.trim().toLowerCase();

    if (!matchesUsername && !matchesEmail) {
      return false;
    }

    if (!currentAccount!.hasActiveSubscription) {
      return false;
    }

    if (currentAccount!.profiles.isNotEmpty) {
      currentProfile = currentAccount!.profiles.first;
      unawaited(_ensureLibraryMembershipLoaded());

      activeProfileIds
        ..clear()
        ..add(currentProfile!.id);
    }

    notifyListeners();

    return true;
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  /// Performs `logout` for this feature. Update this documentation when its contract changes.
  void logout() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;
    _loadedLibraryMembershipScope = null;
    _hiddenLibraryMediaIds.clear();

    activeProfileIds.clear();

    recommendations.clear();
    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendations.clear();
    groupRecommendationsError = null;
    groupRecommendationsLoading = false;

    wishlist.clear();
    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchSessions.clear();
    groupWatchError = null;
    groupWatchLoading = false;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION
  // ---------------------------------------------------------------------------

  Subscription? get subscription => currentAccount?.subscription;

  bool get hasActiveSubscription =>
      currentAccount?.hasActiveSubscription ?? false;

  SubscriptionPlan? get subscriptionPlan => currentAccount?.subscription.plan;

  /// Performs `subscribe` for this feature. Update this documentation when its contract changes.
  void subscribe(
    SubscriptionPlan plan,
  ) {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.subscription = Subscription(
      plan: plan,
      status: SubscriptionStatus.active,
    );

    notifyListeners();
  }

  /// Performs `expireSubscription` for this feature. Update this documentation when its contract changes.
  void expireSubscription() {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.subscription.status = SubscriptionStatus.expired;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PROFILES
  // ---------------------------------------------------------------------------

  Profile addProfile(
    String name, {
    String? username,
    String? avatarUrl,
  }) {
    if (currentAccount == null) {
      throw StateError(
        'No account is currently signed in.',
      );
    }

    if (currentAccount!.profiles.length >= 7) {
      throw StateError(
        'You can have a maximum of 7 profiles.',
      );
    }

    final cleanedName = name.trim();

    final profile = Profile(
      id: _generateId('profile'),
      name: cleanedName.isEmpty
          ? 'Profile ${currentAccount!.profiles.length + 1}'
          : cleanedName,
      username: username,
      avatarUrl: avatarUrl,
    );

    currentAccount!.profiles.add(profile);

    notifyListeners();

    return profile;
  }

  /// Performs `removeProfile` for this feature. Update this documentation when its contract changes.
  void removeProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.profiles.removeWhere((profile) => profile.id == profileId);
    activeProfileIds.remove(profileId);
    unawaited(OfflineMetadataCache(profileId: profileId).clear());

    if (currentProfile?.id == profileId) {
      currentProfile = currentAccount!.profiles.isEmpty
          ? null
          : currentAccount!.profiles.first;
      if (currentProfile != null) {
        activeProfileIds.add(currentProfile!.id);
      }
    }
    notifyListeners();

    notifyListeners();
  }

  /// Performs `switchProfile` for this feature. Update this documentation when its contract changes.
  void switchProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    Profile? profile;

    for (final item in currentAccount!.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }

    if (profile == null) {
      return;
    }

    currentProfile = profile;
    unawaited(_ensureLibraryMembershipLoaded());

    activeProfileIds
      ..clear()
      ..add(profile.id);

    // Reset the visible feed immediately, then restore this profile's own feed.
    activity.clear();
    _loadedActivityStorageKey = null;
    _activityNeedsMerge = false;
    _activityRevision++;
    unawaited(loadActivity(force: true));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ARM DRIVES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getArmDrives() async {
    final drives = await backendApi.getArmDrives();

    return drives
        .whereType<Map>()
        .map(
          (drive) => Map<String, dynamic>.from(
            drive,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LIBRARY
  // ---------------------------------------------------------------------------

  /// Performs `isOwned` for this feature. Update this documentation when its contract changes.
  bool isOwned(String mediaId) {
    if (_isHiddenFromCurrentProfile(mediaId)) return false;
    return library.any(
      (item) => item.id == mediaId &&
          !_isHiddenFromCurrentProfile(item.id) &&
          item.isAccessibleTo(currentProfile),
    );
  }

  String _homeServerStreamUrl(String relativeMediaId) {
    final base = backendApi.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/library/stream')
        .replace(queryParameters: <String, String>{'path': relativeMediaId})
        .toString();
  }

  bool _looksLikeServerMediaFileId(String id) => RegExp(
        r'\.(mkv|mp4|m4v|avi|mov|webm|mp3|flac|m4a|aac|wav)$',
        caseSensitive: false,
      ).hasMatch(id.trim());

  /// Scans the authenticated home server and merges its media into Home.
  /// Real file paths receive the authenticated media-gateway URL. Files under
  /// arm_mock/ are grouped as explicit, non-playable demo placeholders.
  Future<int> syncHomeServerLibrary() async {
    if (!backendApi.isAuthenticated) return 0;
    await _ensureLibraryMembershipLoaded();
    final result = await backendApi.scanServerLibrary();
    final raw = result['media'];
    if (raw is! List) return 0;

    final scanned = <MediaItem>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final row = Map<String, dynamic>.from(value);
      final id = (row['id']?.toString() ?? '').replaceAll('\\', '/').trim();
      if (id.isEmpty || row['type']?.toString().toLowerCase() == 'music') {
        continue;
      }
      final isMock = isArmMockServerMediaId(id) || row['isDemoArtifact'] == true;
      final tags = <String>{
        if (row['tags'] is List)
          ...(row['tags'] as List).map((tag) => tag.toString()),
      };
      row['id'] = id;
      row['title'] = normalizeHomeServerMediaTitle(row['title']?.toString() ?? '');
      row['addedSource'] = isMock ? 'arm-mock-placeholder' : 'home-server-scanner';
      if (isMock) {
        tags.addAll(<String>{'arm-mock-placeholder', 'demo-placeholder', 'not-playable'});
        row['playbackUrl'] = null;
        row['description'] =
            'ARM mock placeholder only. The file contains text, not playable video/audio. Replace it with a real media file to enable playback.';
      } else {
        row['playbackUrl'] = _homeServerStreamUrl(id);
      }
      row['tags'] = tags.toList(growable: false);
      scanned.add(MediaItem.fromJson(row));
    }
    return mergeServerScanIntoLibrary(scanned);
  }

  /// Merges scan results without discarding metadata-only catalog items,
  /// preserving richer imported metadata for matching server file IDs.
  int mergeServerScanIntoLibrary(List<MediaItem> serverMedia) {
    final existingById = <String, MediaItem>{
      for (final item in library) item.id: item,
    };
    final merged = <String, MediaItem>{
      for (final item in library)
        if (!_looksLikeServerMediaFileId(item.id) &&
            item.addedSource != 'home-server-scanner' &&
            item.addedSource != 'arm-mock-placeholder')
          item.id: item,
    };
    final placeholderGroups = <String, List<MediaItem>>{};

    for (final scanned in serverMedia) {
      final id = scanned.id.trim();
      if (id.isEmpty || _isHiddenFromCurrentProfile(id)) continue;
      final isMock = isArmMockServerMediaId(id) ||
          scanned.addedSource == 'arm-mock-placeholder' ||
          scanned.tags.contains('not-playable');
      if (isMock) {
        final cleanTitle = normalizeHomeServerMediaTitle(scanned.title);
        final key = '${scanned.type.toLowerCase()}:${cleanTitle.toLowerCase()}';
        (placeholderGroups[key] ??= <MediaItem>[]).add(scanned);
        continue;
      }

      final existing = existingById[id];
      final mergedTags = <String>{
        ...scanned.tags,
        if (existing != null) ...existing.tags,
      };
      final keepExistingSource = existing != null &&
          existing.addedSource != 'unknown' &&
          existing.addedSource != 'home-server-scanner';
      final playUrl = existing?.playbackUrl?.trim().isNotEmpty == true
          ? existing!.playbackUrl
          : (scanned.playbackUrl?.trim().isNotEmpty == true
              ? scanned.playbackUrl
              : _homeServerStreamUrl(id));
      merged[id] = MediaItem.fromJson(<String, dynamic>{
        ...scanned.toJson(),
        if (existing != null) ...existing.toJson(),
        'id': id,
        'title': keepExistingSource
            ? existing.title
            : normalizeHomeServerMediaTitle(scanned.title),
        'type': keepExistingSource ? existing.type : scanned.type,
        'description': keepExistingSource &&
                existing.description?.trim().isNotEmpty == true
            ? existing.description
            : scanned.description,
        'imageUrl': existing?.imageUrl?.trim().isNotEmpty == true
            ? existing!.imageUrl
            : scanned.imageUrl,
        'playbackUrl': playUrl,
        'addedSource': keepExistingSource
            ? existing.addedSource
            : 'home-server-scanner',
        'tags': mergedTags.toList(growable: false),
      });
    }

    for (final entry in placeholderGroups.entries) {
      final first = entry.value.first;
      final title = normalizeHomeServerMediaTitle(first.title);
      final slug = entry.key
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final placeholderId = 'arm-mock-demo:$slug';
      if (_isHiddenFromCurrentProfile(placeholderId)) continue;
      merged[placeholderId] = MediaItem(
        id: placeholderId,
        title: '$title (Demo placeholder)',
        type: first.type,
        description:
            'Found ${entry.value.length} ARM mock artifact file(s). These files contain placeholder text, not the actual movie/show or a playable stream.',
        addedSource: 'arm-mock-placeholder',
        tags: <String>['arm-mock-placeholder', 'demo-placeholder', 'not-playable'],
      );
    }

    library
      ..clear()
      ..addAll(merged.values.where(
        (item) => !_isHiddenFromCurrentProfile(item.id),
      ));
    _refreshAutomaticCollections();
    notifyListeners();
    return serverMedia.length;
  }

  /// Makes clearly labeled, local-only demo titles available while browsing
  /// and using Smart Search, even before a home-server scan has completed.
  /// These entries have no playback URLs and are not uploaded as media files.
  void ensureDemoPreviewMedia({bool notify = true}) {
    var changed = false;

    List<String> mergeNames(Iterable<String> current, Iterable<String> additions) {
      final seen = <String>{};
      final output = <String>[];
      for (final raw in <String>[...current, ...additions]) {
        final name = raw.trim();
        if (name.isNotEmpty && seen.add(name.toLowerCase())) output.add(name);
      }
      return output;
    }

    void addOrNormalizePreview(MediaItem item) {
      if (_isHiddenFromCurrentProfile(item.id)) return;
      final index = library.indexWhere((existing) => existing.id == item.id);
      if (index < 0) {
        library.add(item);
        changed = true;
        return;
      }

      final existing = library[index];
      // Never overwrite imported/user records. Only enrich the local preview
      // records created by this feature, retaining user-edited fields/artwork.
      if (existing.addedSource != 'demo-preview') return;
      final tags = <String>{...existing.tags, ...item.tags, 'not-playable', 'preview-only'};
      final merged = MediaItem.fromJson(<String, dynamic>{
        ...existing.toJson(),
        'playbackUrl': null,
        'addedSource': 'demo-preview',
        'tags': tags.toList(growable: false),
        'releaseYear': existing.releaseYear ?? item.releaseYear,
        'seriesStartYear': existing.seriesStartYear ?? item.seriesStartYear,
        'originalTitle': existing.originalTitle?.trim().isNotEmpty == true
            ? existing.originalTitle
            : item.originalTitle,
        'countryOfOrigin': existing.countryOfOrigin?.trim().isNotEmpty == true
            ? existing.countryOfOrigin
            : item.countryOfOrigin,
        'description': existing.description?.trim().isNotEmpty == true
            ? existing.description
            : item.description,
        'actors': mergeNames(existing.actors, item.actors),
        'characters': mergeNames(existing.characters, item.characters),
        'directors': mergeNames(existing.directors, item.directors),
        'writers': mergeNames(existing.writers, item.writers),
        'music': mergeNames(existing.music, item.music),
        'genres': mergeNames(existing.genres, item.genres),
        'franchiseId': existing.franchiseId?.trim().isNotEmpty == true ? existing.franchiseId : item.franchiseId,
        'franchiseName': existing.franchiseName?.trim().isNotEmpty == true ? existing.franchiseName : item.franchiseName,
        'franchiseType': existing.franchiseType?.trim().isNotEmpty == true ? existing.franchiseType : item.franchiseType,
        'franchiseOrder': existing.franchiseOrder ?? item.franchiseOrder,
        'franchiseNames': mergeNames(existing.franchiseNames, item.franchiseNames),
        'cinematicUniverseIds': mergeNames(existing.cinematicUniverseIds, item.cinematicUniverseIds),
        'cinematicUniverseNames': mergeNames(existing.cinematicUniverseNames, item.cinematicUniverseNames),
        'universeMemberships': existing.universeMemberships.isNotEmpty
            ? existing.universeMemberships
            : item.universeMemberships,
        'continuityId': existing.continuityId ?? item.continuityId,
        'continuityName': existing.continuityName ?? item.continuityName,
        'universeMetadataSource': existing.universeMetadataSource ?? item.universeMetadataSource,
      });
      if (jsonEncode(merged.toJson()) != jsonEncode(existing.toJson())) {
        library[index] = merged;
        changed = true;
      }
    }

    addOrNormalizePreview(MediaItem(
      id: 'demo-preview-movie',
      title: 'The Ember Protocol (Preview Movie)',
      type: 'movie',
      description:
          'A fictional sci-fi action movie used to preview the Home carousel, movie details, and Smart Search. This is demo metadata only; no video file is attached and playback is unavailable.',
      releaseYear: 2024,
      rating: 7.8,
      genres: const ['Science Fiction', 'Action', 'Adventure'],
      tags: const ['demo-preview', 'not-playable', 'preview-only'],
      addedSource: 'demo-preview',
    ));

    addOrNormalizePreview(MediaItem(
      id: 'demo-preview-tv-show',
      title: 'The Last Signal (Preview Show)',
      type: 'tvShow',
      description:
          'A fictional sci-fi mystery series used to preview show details, seasons, and episode layouts. No video files are attached.',
      releaseYear: 2026,
      rating: 8.1,
      genres: const ['Science Fiction', 'Mystery'],
      tags: const ['demo-preview', 'not-playable', 'preview-only'],
      addedSource: 'demo-preview',
      seasons: const [
        {
          'seasonNumber': 1,
          'title': 'Season 1',
          'episodes': [
            {'episodeNumber': 1, 'title': 'The First Pulse', 'duration': 42, 'description': 'A strange signal interrupts a quiet night.'},
            {'episodeNumber': 2, 'title': 'Dead Air', 'duration': 44, 'description': 'The team traces the signal to an abandoned relay station.'},
            {'episodeNumber': 3, 'title': 'Echoes', 'duration': 46, 'description': 'A second transmission reveals a troubling pattern.'},
          ],
        },
      ],
    ));

    addOrNormalizePreview(MediaItem(
      id: 'demo-preview-album',
      title: 'Midnight Signals (Preview Album)',
      type: 'album',
      description:
          'A fictional album used to preview album artwork, metadata, and details layouts. No audio files are attached.',
      releaseYear: 2025,
      genres: const ['Electronic', 'Ambient'],
      tags: const ['demo-preview', 'not-playable', 'preview-only'],
      addedSource: 'demo-preview',
    ));

    // Put the cinematic starter examples into the actual local browse catalog,
    // not only inside the Intelligence screen. Exact titles are preserved so
    // configured provider lookup can find the correct work.
    for (var index = 0; index < CinematicSeedExamples.all.length; index++) {
      final example = CinematicSeedExamples.all[index];
      final titleKey = DemoCatalogMetadata.normalizeTitle(example.title);
      // Non-Latin original titles can normalize to an empty ASCII key. Give
      // each such entry a stable unique ID without changing its display title.
      final slug = titleKey.isEmpty
          ? 'international-${example.year ?? 'unknown'}-$index'
          : titleKey.replaceAll(' ', '-');
      final isMcu = example.universe == CinematicSeedExamples.mcu;
      final isInternational =
          CinematicSeedExamples.isInternationalExample(example);
      final isSpiderNoir = titleKey == 'spider noir';
      final mcuMovieOrder = CinematicSeedExamples.movies.indexOf(example);
      final franchise = isMcu
          ? DemoFranchiseMetadata(
              id: 'marvel-cinematic-universe',
              name: CinematicSeedExamples.mcu,
              type: 'Cinematic Universe',
              order: mcuMovieOrder >= 0 ? mcuMovieOrder + 1 : null,
            )
          : DemoCatalogMetadata.franchiseFor(example.title);
      final cast = DemoCatalogMetadata.castFor(example.title);
      final genres = DemoCatalogMetadata.genresFor(
        example.title,
        isTv: example.isTv,
        isMcu: isMcu,
      );
      final mediaKindLabel = example.isTv ? 'series' : 'movie';
      addOrNormalizePreview(MediaItem(
        id: 'demo-catalog-$slug',
        title: example.title,
        type: example.isTv ? 'tvShow' : 'movie',
        description: isInternational
            ? 'International catalog preview from ${example.universe}. The display title is intentionally preserved exactly as curated. This is metadata only and has no playable stream.'
            : 'Catalog example only. This is not an owned video file and has no playable stream. Use it to preview title metadata, $mediaKindLabel details, and actor/crew profiles. TMDB can enrich these sample credits when configured.',
        releaseYear: example.year,
        seriesStartYear: example.isTv ? example.year : null,
        originalTitle: isInternational ? example.title : null,
        countryOfOrigin: isInternational ? example.universe : null,
        actors: cast,
        directors: DemoCatalogMetadata.directorsFor(example.title),
        writers: DemoCatalogMetadata.writersFor(example.title),
        genres: genres,
        tags: <String>[
          'demo-preview', 'preview-only', 'not-playable', 'catalog-example',
          if (isInternational) 'international-catalog',
          if (isMcu) ...['action', 'superhero', 'marvel-cinematic-universe'],
          if (example.universe.toLowerCase().contains('wizarding')) 'wizarding-world',
          if (example.universe.toLowerCase().contains('pixar')) 'pixar',
        ],
        addedSource: 'demo-preview',
        franchiseId: franchise?.id,
        franchiseName: franchise?.name,
        franchiseType: franchise?.type,
        franchiseOrder: franchise?.order,
        franchiseNames: franchise == null ? const <String>[] : <String>[franchise.name],
        cinematicUniverseIds: isMcu ? const ['marvel-cinematic-universe'] : const <String>[],
        cinematicUniverseNames: isMcu ? const [CinematicSeedExamples.mcu] : <String>[if (isSpiderNoir) CinematicSeedExamples.spiderNoirContinuity],
        cinematicUniverseSaga: isMcu ? 'Marvel Cinematic Universe examples' : null,
        cinematicUniverseCanonStatus: isMcu ? 'sample-catalog-metadata' : null,
        continuityId: isSpiderNoir ? 'spider-noir-separate-continuity' : (isMcu ? 'mcu' : null),
        continuityName: isSpiderNoir ? 'Spider-Noir separate continuity' : (isMcu ? CinematicSeedExamples.mcu : null),
        universeMetadataSource: 'local-demo-seed',
        universeMemberships: isMcu
            ? const <Map<String, dynamic>>[
                {'id': 'marvel-cinematic-universe', 'name': 'Marvel Cinematic Universe', 'relationship': 'example-membership', 'source': 'local-demo-seed'}
              ]
            : (isSpiderNoir
                ? const <Map<String, dynamic>>[
                    {'id': 'spider-noir-separate-continuity', 'name': 'Spider-Noir separate continuity', 'relationship': 'separate-continuity', 'source': 'local-demo-seed'}
                  ]
                : const <Map<String, dynamic>>[]),
      ));
    }

    const albumExamples = <Map<String, dynamic>>[
      {'title': '1989', 'artist': 'Taylor Swift', 'year': 2014, 'genres': ['Pop']},
      {'title': 'Rare', 'artist': 'Selena Gomez', 'year': 2020, 'genres': ['Pop', 'Dance Pop']},
      {'title': 'YHLQMDLG', 'artist': 'Bad Bunny', 'year': 2020, 'genres': ['Latin', 'Reggaeton', 'Latin Trap']},
      {'title': 'Colores', 'artist': 'J Balvin', 'year': 2020, 'genres': ['Latin', 'Reggaeton']},
    ];
    for (final album in albumExamples) {
      final title = album['title']! as String;
      final artist = album['artist']! as String;
      addOrNormalizePreview(MediaItem(
        id: 'demo-catalog-album-${DemoCatalogMetadata.normalizeTitle(title).replaceAll(' ', '-')}',
        title: title,
        type: 'album',
        description: 'Music catalog example for $artist. No audio files are attached and playback is unavailable until you import your own audio. Use this item to preview artist/performer credit links.',
        releaseYear: album['year']! as int,
        music: <String>[artist],
        genres: (album['genres']! as List).cast<String>(),
        tags: const ['demo-preview', 'preview-only', 'not-playable', 'catalog-example', 'music-artist-example'],
        addedSource: 'demo-preview',
      ));
    }

    if (!changed) return;
    _refreshAutomaticCollections();
    if (notify) notifyListeners();
  }

  /// Replaces the client library with media discovered on the home server.
  Future<void> replaceLibraryFromServer(List<MediaItem> media) async {
    await _ensureLibraryMembershipLoaded();
    library
      ..clear()
      ..addAll(media.where(
        (item) => !_isHiddenFromCurrentProfile(item.id),
      ));

    // Clearly labeled local preview entries are kept local and are never
    // sent to the media server as imported files.
    ensureDemoPreviewMedia(notify: false);
    _refreshAutomaticCollections();
    final profile = currentProfile;
    if (profile != null) {
      final snapshotProfileId = profile.id;
      final visibleMetadata = library
          .where((item) => item.isAccessibleTo(profile))
          .map((item) => item.toJson())
          .toList(growable: false);
      unawaited(OfflineMetadataCache(profileId: snapshotProfileId)
          .save(visibleMetadata)
          .catchError((_) {}));
    }
    notifyListeners();
  }

  /// Restores only sanitized catalog metadata, and only when no online library
  /// is already available. Playback/trailer URLs are never stored by the cache.
  Future<void> restoreOfflineMetadataCache({String? profileId}) async {
    await _ensureLibraryMembershipLoaded();
    final profile = currentProfile;
    final requestedId = profileId?.trim();
    if (profile == null ||
        requestedId == null ||
        requestedId.isEmpty ||
        profile.id != requestedId ||
        library.isNotEmpty) {
      return;
    }
    try {
      final rows = await OfflineMetadataCache(profileId: requestedId).load();
      if (rows.isEmpty ||
          currentProfile?.id != requestedId ||
          library.isNotEmpty) {
        return;
      }
      final restored = rows
          .map(MediaItem.fromJson)
          .where((item) =>
              item.id.isNotEmpty &&
              item.title.isNotEmpty &&
              !_isHiddenFromCurrentProfile(item.id) &&
              item.isAccessibleTo(currentProfile))
          .toList(growable: false);
      if (restored.isEmpty) return;
      library
        ..clear()
        ..addAll(restored);
      _refreshAutomaticCollections();
      notifyListeners();
    } catch (_) {
      // Cached metadata is an enhancement only; never block startup on it.
    }
  }

  /// Adds the title to the active profile's library and clears any saved
  /// removal marker. The original server file is not re-ripped or copied.
  Future<void> addToLibrary(MediaItem media) async {
    await _ensureLibraryMembershipLoaded();
    if (isOwned(media.id)) return;

    final scope = _libraryMembershipScope;
    final updatedHiddenIds = Set<String>.from(_hiddenLibraryMediaIds)
      ..remove(media.id.trim());
    await _saveLibraryMembership(updatedHiddenIds, scope: scope);

    library.removeWhere((item) => item.id == media.id);
    library.add(media);

    _mergeCatalog(actorsCatalog, media.actors);
    _mergeCatalog(directorsCatalog, media.directors);
    _mergeCatalog(writersCatalog, media.writers);
    _mergeCatalog(musicCatalog, media.music);
    _mergeCatalog(genresCatalog, media.genres);
    _mergeCatalog(tagsCatalog, media.tags);

    addNotification(
      action: 'added ${_mediaTypeLabel(media)} "${media.title}"',
    );

    _autoAssignFranchiseMetadata(media);
    _refreshAutomaticCollections();

    // Best-effort profile-scoped catalog persistence. The cache has an explicit
    // privacy preference and field allow-list; playback URLs, signed URLs, and
    // filesystem paths are intentionally excluded. This also keeps disc-import
    // metadata available after restart when offline metadata is enabled.
    final profile = currentProfile;
    if (profile != null) {
      try {
        final visibleItems = library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        // Keep the newest catalog entries within the bounded offline snapshot.
        final start = visibleItems.length > OfflineMetadataCache.maxItems
            ? visibleItems.length - OfflineMetadataCache.maxItems
            : 0;
        await OfflineMetadataCache(profileId: profile.id).save(
          visibleItems.skip(start).map((item) => item.toJson()),
        );
      } catch (_) {
        // Cache failures must never turn a successful library add into a failure.
      }
    }
    notifyListeners();
  }

  /// Merge verified provider credits and fill missing poster artwork on an
  /// existing catalog record. Existing user/catalog artwork is never replaced.
  /// This never creates a new library item or changes playback paths. Offline
  /// persistence still obeys the profile's existing privacy setting.
  Future<void> mergeProviderTitleCredits({
    required String mediaId,
    String? posterUrl,
    List<String> actors = const <String>[],
    List<String> characters = const <String>[],
    List<String> directors = const <String>[],
    List<String> writers = const <String>[],
    List<String> music = const <String>[],
  }) async {
    final index = library.indexWhere((item) => item.id == mediaId);
    if (index < 0) return;

    List<String> merge(Iterable<String> current, Iterable<String> incoming) {
      final seen = <String>{};
      final values = <String>[];
      for (final raw in <String>[...current, ...incoming]) {
        final value = raw.trim();
        if (value.isNotEmpty && seen.add(value.toLowerCase())) values.add(value);
      }
      return values;
    }

    final current = library[index];
    final mergedActors = merge(current.actors, actors);
    final mergedCharacters = merge(current.characters, characters);
    final mergedDirectors = merge(current.directors, directors);
    final mergedWriters = merge(current.writers, writers);
    final mergedMusic = merge(current.music, music);
    final currentPoster = current.imageUrl?.trim() ?? '';
    final incomingPoster = posterUrl?.trim() ?? '';
    // Keep any existing poster selection; use TMDB only when the catalog has
    // no image at all. A catalog may intentionally use custom/title-card art.
    final shouldFillPoster = currentPoster.isEmpty && incomingPoster.isNotEmpty;
    bool equal(List<String> a, List<String> b) =>
        a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
    if (!shouldFillPoster &&
        equal(mergedActors, current.actors) &&
        equal(mergedCharacters, current.characters) &&
        equal(mergedDirectors, current.directors) &&
        equal(mergedWriters, current.writers) &&
        equal(mergedMusic, current.music)) {
      return;
    }

    final enriched = MediaItem.fromJson(<String, dynamic>{
      ...current.toJson(),
      if (shouldFillPoster) 'imageUrl': incomingPoster,
      'actors': mergedActors,
      'characters': mergedCharacters,
      'directors': mergedDirectors,
      'writers': mergedWriters,
      'music': mergedMusic,
    });
    library[index] = enriched;
    _mergeCatalog(actorsCatalog, mergedActors);
    _mergeCatalog(directorsCatalog, mergedDirectors);
    _mergeCatalog(writersCatalog, mergedWriters);
    _mergeCatalog(musicCatalog, mergedMusic);
    _refreshAutomaticCollections();

    final profile = currentProfile;
    if (profile != null) {
      try {
        final visibleItems = library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        final start = visibleItems.length > OfflineMetadataCache.maxItems
            ? visibleItems.length - OfflineMetadataCache.maxItems
            : 0;
        await OfflineMetadataCache(profileId: profile.id).save(
          visibleItems.skip(start).map((item) => item.toJson()),
        );
      } catch (_) {
        // Credits remain available in the active session if offline caching fails.
      }
    }
    notifyListeners();
  }

  /// Performs `_mergeCatalog` for this feature. Update this documentation when its contract changes.
  void _mergeCatalog(List<String> target, List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty &&
          !target.any((item) => item.toLowerCase() == clean.toLowerCase())) {
        target.add(clean);
      }
    }
  }

  /// Removes the title from this profile's library persistently. The server
  /// file and its catalog metadata are not deleted; later scans respect the
  /// saved marker until Add to Library explicitly clears it.
  Future<void> removeFromLibrary(String mediaId) async {
    final normalizedId = mediaId.trim();
    if (normalizedId.isEmpty) return;

    await _ensureLibraryMembershipLoaded();
    final scope = _libraryMembershipScope;
    final updatedHiddenIds = Set<String>.from(_hiddenLibraryMediaIds)
      ..add(normalizedId);
    // Persist first so a failed write cannot make the UI claim the removal is
    // durable when the server scan would otherwise put it back.
    await _saveLibraryMembership(updatedHiddenIds, scope: scope);

    library.removeWhere((item) => item.id.trim() == normalizedId);
    _refreshAutomaticCollections();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // WATCHED / PLAYBACK
  // ---------------------------------------------------------------------------

  /// Performs `isWatched` for this feature. Update this documentation when its contract changes.
  bool isWatched(String mediaId) {
    return watched.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `getPlaybackProgress` for this feature. Update this documentation when its contract changes.
  double getPlaybackProgress(
    String mediaId,
  ) {
    return playbackProgress[mediaId] ?? 0;
  }

  /// Performs `updatePlaybackProgress` for this feature. Update this documentation when its contract changes.
  void updatePlaybackProgress(
    String mediaId,
    double progress,
  ) {
    final clamped = progress.clamp(0.0, 1.0);

    playbackProgress[mediaId] = clamped.toDouble();
    final profileId = currentProfile?.id;
    if (profileId != null && profileId.isNotEmpty) {
      // Coalesces repeated player progress ticks into one durable pending update
      // per profile/title. The queue contains no media bytes or credentials.
      unawaited(OfflineSyncQueue(
        scopeId: currentAccount?.id ?? 'local',
      )
          .enqueuePlaybackProgress(
            profileId: profileId,
            mediaId: mediaId,
            progress: clamped.toDouble(),
          )
          .catchError((_) {}));
    }

    notifyListeners();
  }

  /// Performs `markWatched` for this feature. Update this documentation when its contract changes.
  /// Adds a profile-scoped playback completion event for Wrapped. This is a
  /// compact activity record only: it stores metadata and timestamps, never
  /// media bytes, credentials, or a raw storage path.
  Future<void> recordWrappedActivity(MediaItem media) => recordWrappedActivityDetails(
        mediaId: media.id,
        canonicalWorkId: media.canonicalWorkId ?? media.id,
        title: media.title,
        type: media.type,
        genres: media.genres,
      );

  /// Shared recorder used by video completions and completed music tracks.
  /// Only profile-scoped metadata is kept; files and server paths are not copied.
  Future<void> recordWrappedActivityDetails({
    required String mediaId,
    String? canonicalWorkId,
    required String title,
    required String type,
    List<String> genres = const <String>[],
    String? artist,
    String? album,
    String? profileIdOverride,
  }) async {
    final profileId = (profileIdOverride ?? currentProfile?.id ?? '').trim();
    if (profileId.isEmpty || mediaId.trim().isEmpty || title.trim().isEmpty) return;

    try {
      final prefs = _badgePrefs ?? await SharedPreferences.getInstance();
      _badgePrefs ??= prefs;
      final key = 'moss_wrapped_activity_$profileId';
      final raw = prefs.getString(key);
      final records = <Map<String, dynamic>>[];
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            records.addAll(decoded.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ));
          }
        } catch (_) {
          // Start a fresh bounded journal if an old local cache is malformed.
        }
      }
      final occurredAt = DateTime.now();
      records.add(<String, dynamic>{
        'eventId': '${mediaId}_${occurredAt.microsecondsSinceEpoch}',
        'profileId': profileId,
        'mediaId': mediaId,
        'canonicalWorkId': (canonicalWorkId?.trim().isNotEmpty == true)
            ? canonicalWorkId!.trim()
            : mediaId,
        'title': title.trim(),
        'type': type.trim(),
        'genres': genres,
        if (artist?.trim().isNotEmpty == true) 'artist': artist!.trim(),
        if (album?.trim().isNotEmpty == true) 'album': album!.trim(),
        'occurredAt': occurredAt.toIso8601String(),
        'action': 'completed',
      });
      if (records.length > 10000) {
        records.removeRange(0, records.length - 10000);
      }
      await prefs.setString(key, jsonEncode(records));
    } catch (_) {
      // Wrapped is best-effort and must never interrupt playback.
    }
  }

  /// Performs `markWatched` for this feature. Update this documentation when its contract changes.
  void markWatched(
    MediaItem media,
  ) {
    if (!isWatched(media.id)) {
      watched.add(media);
      _recordMonthlyWatch(media);
      unawaited(recordWrappedActivity(media));

      _addActivity(
        title: media.title,
        action: 'Watched',
      );
    }

    playbackProgress[media.id] = 1.0;
    _refreshAutomaticCollections();

    notifyListeners();
  }

  /// Marks the title as complete and records repeat completions separately for
  /// period-aware Wrapped statistics.
  void finishWatching(
    MediaItem media,
  ) {
    final alreadyWatched = isWatched(media.id);
    markWatched(media);
    if (alreadyWatched) unawaited(recordWrappedActivity(media));
  }

  // ---------------------------------------------------------------------------
  // LIKES / DISLIKES
  // ---------------------------------------------------------------------------

  /// Performs `isLiked` for this feature. Update this documentation when its contract changes.
  bool isLiked(String mediaId) {
    return liked.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `isDisliked` for this feature. Update this documentation when its contract changes.
  bool isDisliked(String mediaId) {
    return disliked.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `likeMedia` for this feature. Update this documentation when its contract changes.
  void likeMedia(
    MediaItem media,
  ) {
    disliked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isLiked(media.id)) {
      liked.add(media);
    }

    _refreshAutomaticCollections();
    notifyListeners();
  }

  /// Performs `dislikeMedia` for this feature. Update this documentation when its contract changes.
  void dislikeMedia(
    MediaItem media,
  ) {
    liked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isDisliked(media.id)) {
      disliked.add(media);
    }

    _refreshAutomaticCollections();
    notifyListeners();
  }

  /// Performs `clearReaction` for this feature. Update this documentation when its contract changes.
  void clearReaction(
    String mediaId,
  ) {
    liked.removeWhere(
      (item) => item.id == mediaId,
    );

    disliked.removeWhere(
      (item) => item.id == mediaId,
    );

    _refreshAutomaticCollections();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void> loadRecommendations() async {
    if (!backendApi.isAuthenticated) {
      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;
      notifyListeners();
      return;
    }

    recommendationsLoading = true;
    recommendationsError = null;

    notifyListeners();

    try {
      final response = await backendApi.getRecommendations();

      final List<MediaItem> loaded = <MediaItem>[];

      final data = response['recommendations'];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              MediaItem.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }

      loaded.removeWhere((item) => isExcludedEntertainmentType(item.type));
      recommendations = loaded;
    } catch (error) {
      recommendationsError = error.toString();
    } finally {
      recommendationsLoading = false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY
  // ---------------------------------------------------------------------------

  /// Performs `_addActivity` for this feature. Update this documentation when its contract changes.
  void _addActivity({
    required String title,
    required String action,
  }) {
    activity.insert(
      0,
      ActivityItem(
        id: _generateId('activity'),
        title: title,
        action: action,
        timestamp: DateTime.now(),
      ),
    );

    if (activity.length > 100) {
      activity.removeLast();
    }
    _activityRevision++;
    _persistOrRestoreActivity();
    notifyListeners();
  }

  void _persistOrRestoreActivity() {
    final key = _activityStorageKey;
    if (_loadedActivityStorageKey == key) {
      unawaited(_persistActivity());
      return;
    }
    // Preserve older stored events if an action arrives before the profile's
    // local feed has finished loading. Multiple actions are merged together.
    _activityNeedsMerge = true;
    unawaited(loadActivity(force: true));
  }

  /// Restores the current profile's notification feed from local device storage.
  /// Profile-scoped keys prevent activity from leaking between household profiles.
  Future<void> loadActivity({bool force = false}) async {
    final key = _activityStorageKey;
    if (!force && _loadedActivityStorageKey == key) return;
    final generation = ++_activityLoadGeneration;
    final revision = _activityRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (generation != _activityLoadGeneration || key != _activityStorageKey) {
        return;
      }
      final loaded = <ActivityItem>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded.whereType<Map>()) {
            final item = ActivityItem.fromJson(Map<String, dynamic>.from(row));
            if (item.id.isNotEmpty) loaded.add(item);
            if (loaded.length >= 100) break;
          }
        }
      }
      final needsMerge = _activityNeedsMerge || revision != _activityRevision;
      if (needsMerge) {
        final byId = <String, ActivityItem>{
          for (final item in loaded) item.id: item,
        };
        // Current in-memory versions win so read-state changes made while the
        // storage request was pending are not overwritten by older cached data.
        for (final item in activity) {
          byId[item.id] = item;
        }
        final merged = byId.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        activity
          ..clear()
          ..addAll(merged.take(100));
        _activityNeedsMerge = false;
        _loadedActivityStorageKey = key;
        unawaited(_persistActivity());
      } else {
        activity
          ..clear()
          ..addAll(loaded);
        _loadedActivityStorageKey = key;
      }
      notifyListeners();
    } catch (_) {
      // Local notifications are optional state. A corrupt cache never blocks Home.
      if (generation != _activityLoadGeneration || key != _activityStorageKey) {
        return;
      }
      _loadedActivityStorageKey = key;
      if (_activityNeedsMerge) {
        _activityNeedsMerge = false;
        unawaited(_persistActivity());
      }
    }
  }

  Future<void> _persistActivity() {
    final key = _activityStorageKey;
    final payload = jsonEncode(
        activity.map((item) => item.toJson()).toList(growable: false));
    // Serialize snapshots so an earlier write cannot finish after Clear all and
    // accidentally resurrect notifications that the user already removed.
    final write = _activityPersistenceQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, payload);
      } catch (_) {
        // Notification persistence must never interrupt a media or social action.
      }
    });
    _activityPersistenceQueue = write;
    return write;
  }

  void markActivityRead(String activityId) {
    final index = activity.indexWhere((entry) => entry.id == activityId);
    if (index < 0 || activity[index].read) return;
    activity[index].read = true;
    _activityRevision++;
    _persistOrRestoreActivity();
    notifyListeners();
  }

  void markAllActivityRead() {
    var changed = false;
    for (final item in activity) {
      if (!item.read) {
        item.read = true;
        changed = true;
      }
    }
    if (!changed) return;
    _activityRevision++;
    _persistOrRestoreActivity();
    notifyListeners();
  }

  void clearActivity() {
    if (activity.isEmpty) return;
    // Cancel an in-flight restore so cleared entries cannot reappear afterward.
    _activityLoadGeneration++;
    _activityNeedsMerge = false;
    _loadedActivityStorageKey = _activityStorageKey;
    activity.clear();
    _activityRevision++;
    unawaited(_persistActivity());
    notifyListeners();
  }

  /// Adds a user-facing notification to the activity center.
  ///
  /// This is public so features outside AppController, such as Music, can
  /// create the same notification style without duplicating activity logic.
  void addNotification({required String action, String? profileName}) {
    final name = (profileName ??
            currentProfile?.name ??
            currentAccount?.username ??
            'User')
        .trim();
    _addActivity(
      title: name.isEmpty ? 'User' : name,
      action: action.trim(),
    );
  }

  String _mediaTypeLabel(MediaItem media) {
    final type =
        media.type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (type == 'tvshow' || type == 'series') return 'TV show';
    if (type == 'album') return 'album';
    return 'movie';
  }

  // ---------------------------------------------------------------------------
  // BACKEND CROSS-ACCOUNT GROUP CHAT
  // ---------------------------------------------------------------------------

  /// Performs `loadGroupChatRoom` for this feature. Update this documentation when its contract changes.
  Future<void> loadGroupChatRoom({String? roomId}) async {
    if (!backendApi.isAuthenticated) return;
    groupChatLoading = true;
    groupChatError = null;
    notifyListeners();
    try {
      Map<String, dynamic> response;
      if (roomId != null && roomId.isNotEmpty) {
        response = await backendApi.getGroupChatRoom(roomId);
      } else {
        final rooms = await backendApi.getGroupChatRooms();
        final data = rooms['rooms'];
        if (data is! List || data.isEmpty) {
          activeGroupChatRoom = null;
          return;
        }
        response = {'room': data.first};
      }
      final raw = response['room'];
      if (raw is Map) {
        activeGroupChatRoom =
            BackendGroupChatRoom.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (error) {
      groupChatError = error.toString();
    } finally {
      groupChatLoading = false;
      notifyListeners();
    }
  }

  /// Performs `createCrossAccountGroupChat` for this feature. Update this documentation when its contract changes.
  Future<void> createCrossAccountGroupChat(
      {required String name,
      required String profileId,
      Set<String>? invitedProfiles}) async {
    final response = await backendApi.createGroupChatRoom(
        name: name, profileId: profileId, invitedProfiles: invitedProfiles);
    final raw = response['room'];
    if (raw is Map) {
      activeGroupChatRoom =
          BackendGroupChatRoom.fromJson(Map<String, dynamic>.from(raw));
    }
    notifyListeners();
  }

  /// Performs `sendCrossAccountGroupMessage` for this feature. Update this documentation when its contract changes.
  Future<void> sendCrossAccountGroupMessage(
      {required String roomId,
      required String profileId,
      required String message}) async {
    await backendApi.sendGroupChatMessage(
        roomId: roomId,
        profileId: profileId,
        message: message,
        badgeName: badgeForProfile(profileId));
    addNotification(
        action: 'sent a message', profileName: _profileNameForId(profileId));
    await loadGroupChatRoom(roomId: roomId);
  }

  // ---------------------------------------------------------------------------
  // GROUP CHAT
  // ---------------------------------------------------------------------------

  /// Performs `sendGroupMessage` for this feature. Update this documentation when its contract changes.
  void sendGroupMessage({
    required String message,
  }) {
    final cleanedMessage = message.trim();

    if (cleanedMessage.isEmpty) {
      return;
    }

    groupMessages.add(
      ChatMessage(
        id: _generateId('message'),
        sender: currentProfile?.name ?? currentAccount?.username ?? 'You',
        message: cleanedMessage,
        timestamp: DateTime.now(),
      ),
    );

    addNotification(action: 'sent a message');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void> loadGroupRecommendations() async {
    if (!backendApi.isAuthenticated) {
      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading = false;

      notifyListeners();
      return;
    }

    groupRecommendationsLoading = true;

    groupRecommendationsError = null;

    notifyListeners();

    try {
      final response = await backendApi.getGroupRecommendations();

      final data = response['recommendations'];

      final loaded = <Map<String, dynamic>>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              Map<String, dynamic>.from(
                item,
              ),
            );
          }
        }
      }

      groupRecommendations = loaded;
    } catch (error) {
      groupRecommendationsError = error.toString();
    } finally {
      groupRecommendationsLoading = false;

      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createGroupRecommendation({
    required String title,
    required String type,
    required String profileId,
    String? mediaId,
    Set<String>? activeParticipants,
    int? votingDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a group recommendation.',
      );
    }

    final String cleanedTitle = title.trim();

    final String cleanedType = type.trim();

    final String cleanedProfileId = profileId.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Recommendation title cannot be empty.',
      );
    }

    if (cleanedType != 'movie' && cleanedType != 'tvShow') {
      throw ArgumentError(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (votingDurationHours != null && votingDurationHours <= 0) {
      throw ArgumentError(
        'Voting duration must be greater than zero.',
      );
    }

    String? cleanedMediaId = mediaId?.trim();

    if (cleanedMediaId != null && cleanedMediaId.isEmpty) {
      cleanedMediaId = null;
    }

    // Recommendation voting is account-wide for normal profiles.  The
    // creator may still supply a participant list, but every profile on the
    // current account is always eligible so one profile cannot accidentally
    // create a recommendation that other profiles cannot vote on.
    final Set<String> participants = <String>{
      ...?activeParticipants,
      ...?currentAccount?.profiles.map((profile) => profile.id),
    };

    participants.removeWhere((id) => id.trim().isEmpty);
    participants.add(cleanedProfileId);

    final response = await backendApi.createGroupRecommendation(
      title: cleanedTitle,
      type: cleanedType,
      profileId: cleanedProfileId,
      mediaId: cleanedMediaId,
      activeParticipants: participants,
      votingDurationHours: votingDurationHours,
    );

    final recommendation = response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap = Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations.removeWhere(
        (item) => item['id']?.toString() == recommendationMap['id']?.toString(),
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String titleForMessage =
          recommendationMap['title']?.toString() ?? cleanedTitle;

      final String icon = cleanedType == 'tvShow' ? '📺' : '🎬';

      final String typeLabel = cleanedType == 'tvShow' ? 'TV show' : 'movie';

      sendGroupMessage(
        message: tr(
            "$icon ${currentProfile?.name ?? 'You'} recommended the $typeLabel \"$titleForMessage\""),
      );
      addNotification(
        action: 'added a $typeLabel recommendation "$titleForMessage"',
      );

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?> getGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId = recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response = await backendApi.getGroupRecommendation(
      recommendationId: cleanedId,
    );

    final recommendation = response['recommendation'];

    if (recommendation is! Map) {
      return null;
    }

    final recommendationMap = Map<String, dynamic>.from(
      recommendation,
    );

    groupRecommendations.removeWhere(
      (item) => item['id']?.toString() == cleanedId,
    );

    groupRecommendations.insert(
      0,
      recommendationMap,
    );

    notifyListeners();

    return recommendationMap;
  }

  Future<Map<String, dynamic>?> voteOnGroupRecommendation({
    required String recommendationId,
    required String profileId,
    required String vote,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedRecommendationId = recommendationId.trim();

    final cleanedProfileId = profileId.trim();

    final cleanedVote = vote.trim().toLowerCase();

    if (cleanedRecommendationId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (cleanedVote != 'yes' && cleanedVote != 'no') {
      throw ArgumentError(
        'Vote must be either "yes" or "no".',
      );
    }

    final response = await backendApi.voteOnGroupRecommendation(
      recommendationId: cleanedRecommendationId,
      profileId: cleanedProfileId,
      vote: cleanedVote,
    );

    final recommendation = response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap = Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations.removeWhere(
        (item) => item['id']?.toString() == cleanedRecommendationId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String title =
          recommendationMap['title']?.toString() ?? 'this recommendation';

      final String voterName = _profileNameForId(
        cleanedProfileId,
      );

      final int yesVotes = _intFromValue(
        recommendationMap['yesVotes'],
      );

      final int noVotes = _intFromValue(
        recommendationMap['noVotes'],
      );

      final double yesPercentage = _doubleFromValue(
        recommendationMap['yesPercentage'],
        fallback: _percentage(
          yesVotes,
          yesVotes + noVotes,
        ),
      );

      final double noPercentage = _doubleFromValue(
        recommendationMap['noPercentage'],
        fallback: _percentage(
          noVotes,
          yesVotes + noVotes,
        ),
      );

      sendGroupMessage(
        message: '$voterName voted ${cleanedVote.toUpperCase()} on "$title" — '
            'YES ${_formatPercentage(yesPercentage)}% '
            'NO ${_formatPercentage(noPercentage)}%',
      );

      final status = recommendationMap['status']?.toString().toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?> closeGroupRecommendationVoting({
    required String recommendationId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId = recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response = await backendApi.closeGroupRecommendationVoting(
      recommendationId: cleanedId,
    );

    final recommendation = response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap = Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations.removeWhere(
        (item) => item['id']?.toString() == cleanedId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final status = recommendationMap['status']?.toString().toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<void> deleteGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId = recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    await backendApi.deleteGroupRecommendation(
      recommendationId: cleanedId,
    );

    groupRecommendations.removeWhere(
      (item) => item['id']?.toString() == cleanedId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  Future<void> loadGroupWishlist() async {
    if (!backendApi.isAuthenticated) {
      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      notifyListeners();
      return;
    }

    groupWishlistLoading = true;
    groupWishlistError = null;

    notifyListeners();

    try {
      final response = await backendApi.getGroupWishlist();

      final data = response['wishlist'];

      final loaded = <WishlistItem>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final map = Map<String, dynamic>.from(
            item,
          );

          final id = map['id']?.toString() ?? '';

          if (id.isEmpty) {
            continue;
          }

          loaded.add(
            WishlistItem(
              id: id,
              title: map['title']?.toString() ?? id,
              type: map['type']?.toString() ?? 'unknown',
            ),
          );
        }
      }

      wishlist
        ..clear()
        ..addAll(loaded);
    } catch (error) {
      groupWishlistError = error.toString();
    } finally {
      groupWishlistLoading = false;

      notifyListeners();
    }
  }

  /// Performs `isInGroupWishlist` for this feature. Update this documentation when its contract changes.
  bool isInGroupWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  Future<void> removeFromGroupWishlist(
    String mediaId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId = mediaId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    await backendApi.removeFromGroupWishlist(
      mediaId: cleanedId,
    );

    wishlist.removeWhere(
      (item) => item.id == cleanedId,
    );

    notifyListeners();
  }

  Future<void> acquireGroupWishlistItem({
    required String mediaId,
    required String profileId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }
    await _ensureLibraryMembershipLoaded();

    final cleanedMediaId = mediaId.trim();

    final cleanedProfileId = profileId.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    final response = await backendApi.acquireGroupWishlistItem(
      mediaId: cleanedMediaId,
      profileId: cleanedProfileId,
    );

    wishlist.removeWhere(
      (item) => item.id == cleanedMediaId,
    );

    final mediaData = response['media'];

    if (mediaData is Map) {
      final media = MediaItem.fromJson(
        Map<String, dynamic>.from(
          mediaData,
        ),
      );

      if (media.id.isNotEmpty &&
          !isOwned(media.id) &&
          !_isHiddenFromCurrentProfile(media.id)) {
        library.add(media);

        _addActivity(
          title: media.title,
          action: 'Added from group wishlist',
        );
      }
    }

    notifyListeners();

    await loadGroupWishlist();
  }

  // ---------------------------------------------------------------------------
  // BACKWARD-COMPATIBLE LOCAL WISHLIST API
  // ---------------------------------------------------------------------------

  /// Performs `isInWishlist` for this feature. Update this documentation when its contract changes.
  bool isInWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `addToWishlist` for this feature. Update this documentation when its contract changes.
  void addToWishlist(
    MediaItem media,
  ) {
    if (isInWishlist(media.id)) {
      return;
    }

    wishlist.add(
      WishlistItem(
        id: media.id,
        title: media.title,
        type: media.type,
      ),
    );

    notifyListeners();
  }

  /// Performs `removeFromWishlist` for this feature. Update this documentation when its contract changes.
  void removeFromWishlist(
    String mediaId,
  ) {
    wishlist.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  /// Loads every Group Watch session belonging to the authenticated account.
  Future<void> loadGroupWatchSessions() async {
    if (!backendApi.isAuthenticated) {
      groupWatchSessions.clear();
      activeGroupWatchSessionId = null;
      groupWatchError = null;
      groupWatchLoading = false;

      notifyListeners();
      return;
    }

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response = await backendApi.getGroupWatchSessions();

      final data = response['sessions'];

      final loaded = <GroupWatchSession>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final session = GroupWatchSession.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
            knownProfiles: currentAccount?.profiles ?? const <Profile>[],
          );

          if (session.id.isNotEmpty) {
            loaded.add(session);
          }
        }
      }

      groupWatchSessions
        ..clear()
        ..addAll(loaded);

      final activeId = activeGroupWatchSessionId;

      if (activeId != null &&
          !groupWatchSessions.any(
            (session) => session.id == activeId,
          )) {
        activeGroupWatchSessionId = null;
      }
    } catch (error) {
      groupWatchError = error.toString();

      debugPrint(
        'Failed to load Group Watch sessions: $error',
      );
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Returns a locally cached Group Watch session by ID.
  GroupWatchSession? getGroupWatchSession(
    String sessionId,
  ) {
    final cleanedId = sessionId.trim();

    if (cleanedId.isEmpty) {
      return null;
    }

    for (final session in groupWatchSessions) {
      if (session.id == cleanedId) {
        return session;
      }
    }

    return null;
  }

  /// Marks a Group Watch session as the session currently being watched.
  void setActiveGroupWatchSession(
    String? sessionId,
  ) {
    final cleanedId = sessionId?.trim();

    if (cleanedId == null || cleanedId.isEmpty) {
      activeGroupWatchSessionId = null;
    } else {
      activeGroupWatchSessionId = cleanedId;
    }

    notifyListeners();
  }

  /// Refreshes one Group Watch session from the backend.
  Future<GroupWatchSession?> refreshGroupWatchSession(
    String sessionId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId = sessionId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.getGroupWatchSession(
      sessionId: cleanedId,
    );

    final sessionData = response['session'];

    if (sessionData is! Map) {
      return null;
    }

    final session = GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles: currentAccount?.profiles ?? const <Profile>[],
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Creates a local Group Watch session for backwards compatibility with
  /// older UI code.
  ///
  /// The real backend-connected implementation is
  /// [createBackendGroupWatchSession].
  ///
  /// This compatibility method does not claim that the backend session was
  /// created. The player will be migrated to the backend method in the next
  /// implementation step.
  GroupWatchSession createGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    final invited = invitedProfileIds == null
        ? <String>{}
        : Set<String>.from(
            invitedProfileIds,
          );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    final sessionId = _generateId('group-watch');

    final participantStates = <String, GroupWatchParticipant>{};

    if (selectedProfileId.isNotEmpty) {
      participantStates[selectedProfileId] = GroupWatchParticipant(
        profileId: selectedProfileId,
        profileName: _profileNameForId(
          selectedProfileId,
        ),
        invitationStatus: 'accepted',
        joinedAt: DateTime.now(),
      );
    }

    for (final invitedId in invited) {
      final cleanId = invitedId.trim();

      participantStates[cleanId] = GroupWatchParticipant(
        profileId: cleanId,
        profileName: _profileNameForId(
          cleanId,
        ),
        invitationStatus: 'pending',
      );
    }

    DateTime? invitationExpiresAt;

    if (invitationDurationHours != null && invitationDurationHours > 0) {
      invitationExpiresAt = DateTime.now().add(
        Duration(
          hours: invitationDurationHours,
        ),
      );
    } else if (invited.isNotEmpty) {
      invitationExpiresAt = DateTime.now().add(
        const Duration(
          hours: 24,
        ),
      );
    }

    final session = GroupWatchSession(
      id: sessionId,
      title: media.title,
      mediaId: media.id,
      type: _backendMediaType(
        media.type,
      ),
      hostProfileId: selectedProfileId,
      participants: participantStates.values
          .map(
            (participant) => participant.profileName,
          )
          .toList(),
      participantStates: participantStates,
      status: 'waiting',
      invitationExpiresAt: invitationExpiresAt,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId = session.id;

    notifyListeners();

    return session;
  }

  /// Creates a real backend Group Watch session.
  ///
  /// The selected profile becomes the host. Invited identifiers may belong to
  /// other accounts; the backend resolves and authorizes them against the
  /// participant's own account and server.
  Future<GroupWatchSession> createBackendGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a Group Watch.',
      );
    }

    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A host profile is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected host profile does not belong to the current account.',
      );
    }

    final cleanedMediaId = media.id.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    final cleanedTitle = media.title.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Media title cannot be empty.',
      );
    }

    if (invitationDurationHours != null && invitationDurationHours <= 0) {
      throw ArgumentError(
        'Invitation duration must be greater than zero.',
      );
    }

    final invited = invitedProfileIds == null
        ? <String>{}
        : Set<String>.from(
            invitedProfileIds,
          );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    // Invited identifiers may refer to profiles in other accounts. The backend
    // resolves usernames/emails/profile IDs and then verifies each participant
    // against that account's server and media ownership.

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response = await backendApi.createGroupWatchSession(
        mediaId: cleanedMediaId,
        title: cleanedTitle,
        type: _backendMediaType(
          media.type,
        ),
        profileId: selectedProfileId,
        invitedProfileIds: invited,
        invitationDurationHours: invitationDurationHours,
      );

      final sessionData = response['session'];

      if (sessionData is! Map) {
        throw BackendApiException(
          'The server returned an invalid Group Watch session.',
        );
      }

      final session = GroupWatchSession.fromJson(
        Map<String, dynamic>.from(
          sessionData,
        ),
        knownProfiles: currentAccount?.profiles ?? const <Profile>[],
      );

      _upsertGroupWatchSession(
        session,
      );

      activeGroupWatchSessionId = session.id;

      groupWatchError = null;

      return session;
    } catch (error) {
      groupWatchError = error.toString();
      rethrow;
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Accepts an invitation for a profile.
  ///
  /// If the invitation has expired or the session has already started, the
  /// backend rejects the request. The UI can surface the backend's exact
  /// "This invite has expired" message.
  Future<GroupWatchSession> acceptGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.acceptGroupWatchInvitation(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    sendGroupMessage(
      message:
          '${_profileNameForId(selectedProfileId)} joined the Group Watch — "${session.title}"',
    );

    notifyListeners();

    return session;
  }

  /// Declines an invitation for a profile.
  Future<GroupWatchSession> declineGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.declineGroupWatchInvitation(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's audio track.
  ///
  /// This changes audio only for the specified participant.
  Future<GroupWatchSession> setGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
    String? audioTrackId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId = audioTrackId?.trim();

    final response = await backendApi.setGroupWatchAudioTrack(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
      audioTrackId: cleanedTrackId?.isEmpty == true ? null : cleanedTrackId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's subtitle track.
  ///
  /// This changes subtitles only for the specified participant.
  Future<GroupWatchSession> setGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
    String? subtitleTrackId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId = subtitleTrackId?.trim();

    final response = await backendApi.setGroupWatchSubtitleTrack(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
      subtitleTrackId: cleanedTrackId?.isEmpty == true ? null : cleanedTrackId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Starts Group Watch playback for everyone.
  Future<GroupWatchSession> startGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.startGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId = session.id;

    notifyListeners();

    return session;
  }

  /// Starts global playback.
  Future<GroupWatchSession> playGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.playGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId = session.id;

    notifyListeners();

    return session;
  }

  /// Pauses playback for EVERYONE.
  ///
  /// The backend stores the pausing profile and reason. The same reason is
  /// posted to the local group chat.
  Future<GroupWatchSession> pauseGroupWatchSession({
    required String sessionId,
    required String reason,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    final cleanedReason = reason.trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (cleanedReason.isEmpty) {
      throw ArgumentError(
        'A pause reason is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.pauseGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
      reason: cleanedReason,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    final profileName = _profileNameForId(
      selectedProfileId,
    );

    sendGroupMessage(
      message: tr(
          '$profileName paused the Group Watch — ${_pauseReasonDisplay(cleanedReason)}'),
    );

    notifyListeners();

    return session;
  }

  /// Resumes global playback.
  ///
  /// Only the profile that paused the session is permitted to resume.
  Future<GroupWatchSession> resumeGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final localSession = getGroupWatchSession(
      cleanedSessionId,
    );

    if (localSession != null &&
        localSession.pausedByProfileId != null &&
        localSession.pausedByProfileId != selectedProfileId) {
      throw BackendApiException(
        'Only the person who paused the Group Watch can resume it.',
      );
    }

    final response = await backendApi.resumeGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Updates the shared playback position.
  Future<GroupWatchSession> updateGroupWatchPosition({
    required String sessionId,
    required Duration position,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (position.isNegative) {
      throw ArgumentError(
        'Playback position cannot be negative.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.updateGroupWatchPosition(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
      position: position,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Ends Group Watch for everyone.
  Future<GroupWatchSession> endGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response = await backendApi.endGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    final session = _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    if (activeGroupWatchSessionId == session.id) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();

    return session;
  }

  /// Deletes a Group Watch session.
  Future<void> deleteGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) async {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId = sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    await backendApi.deleteGroupWatchSession(
      sessionId: cleanedSessionId,
      profileId: selectedProfileId,
    );

    groupWatchSessions.removeWhere(
      (session) => session.id == cleanedSessionId,
    );

    if (activeGroupWatchSessionId == cleanedSessionId) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();
  }

  /// Returns whether the specified profile can resume the session.
  bool canResumeGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    final session = getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return false;
    }

    return session.canResume(
      selectedProfileId,
    );
  }

  /// Returns the participant state for a profile.
  GroupWatchParticipant? getGroupWatchParticipant({
    required String sessionId,
    String? profileId,
  }) {
    final selectedProfileId = (profileId ?? currentProfile?.id ?? '').trim();

    final session = getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return null;
    }

    return session.participantForProfile(
      selectedProfileId,
    );
  }

  String? getGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.audioTrackId;
  }

  String? getGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.subtitleTrackId;
  }

  Duration getGroupWatchPosition(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.playbackPosition ??
        Duration.zero;
  }

  /// Performs `isGroupWatchPlaying` for this feature. Update this documentation when its contract changes.
  bool isGroupWatchPlaying(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.isPlaying ??
        false;
  }

  /// Returns whether a Group Watch invitation is no longer joinable.
  bool isGroupWatchInvitationExpired(
    String sessionId,
  ) {
    final session = getGroupWatchSession(
      sessionId,
    );

    return session?.invitationsExpired ?? true;
  }

  /// Returns the exact UI message used when an invitation is no longer
  /// joinable.
  String groupWatchInvitationExpiredMessage(
    String sessionId,
  ) {
    if (isGroupWatchInvitationExpired(
      sessionId,
    )) {
      return 'This invite has expired';
    }

    return '';
  }

  /// Compatibility method retained for older UI code.
  ///
  /// Real Group Watch synchronization is always controlled by the backend.
  void toggleGroupWatchSync(
    String sessionId,
  ) {
    final session = getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return;
    }

    session.synchronized = !session.synchronized;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // MUSIC ACTIVITY
  // ---------------------------------------------------------------------------

  /// Performs `recordMusicActivity` for this feature. Update this documentation when its contract changes.
  void recordMusicActivity(
    String title,
  ) {
    _addActivity(
      title: title,
      action: 'Played music',
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // NEXT EPISODE
  // ---------------------------------------------------------------------------

  String? getNextEpisode(
    String mediaId,
  ) {
    return nextEpisodes[mediaId];
  }

  /// Performs `setNextEpisode` for this feature. Update this documentation when its contract changes.
  void setNextEpisode(
    String mediaId,
    String episodeTitle,
  ) {
    nextEpisodes[mediaId] = episodeTitle;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RESET
  // ---------------------------------------------------------------------------

  /// Performs `reset` for this feature. Update this documentation when its contract changes.
  void reset() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;
    _loadedLibraryMembershipScope = null;
    _hiddenLibraryMediaIds.clear();

    library.clear();
    watched.clear();
    liked.clear();
    disliked.clear();

    _activityLoadGeneration++;
    _loadedActivityStorageKey = null;
    _activityNeedsMerge = false;
    _activityRevision++;
    activity.clear();
    groupMessages.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    playbackProgress.clear();
    nextEpisodes.clear();
    activeProfileIds.clear();

    recommendations.clear();
    recommendationsLoading = false;
    recommendationsError = null;

    groupRecommendations.clear();
    groupRecommendationsLoading = false;
    groupRecommendationsError = null;

    wishlist.clear();
    groupWishlistLoading = false;
    groupWishlistError = null;

    groupWatchLoading = false;
    groupWatchError = null;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATION HELPERS
  // ---------------------------------------------------------------------------

  /// Performs `_profileNameForId` for this feature. Update this documentation when its contract changes.
  String _profileNameForId(
    String profileId,
  ) {
    final account = currentAccount;

    if (account != null) {
      for (final profile in account.profiles) {
        if (profile.id == profileId) {
          return profile.name;
        }
      }
    }

    if (currentProfile?.id == profileId) {
      return currentProfile!.name;
    }

    return 'Profile';
  }

  /// Performs `_accountHasProfile` for this feature. Update this documentation when its contract changes.
  bool _accountHasProfile(
    String profileId,
  ) {
    final account = currentAccount;

    if (account == null) {
      return false;
    }

    return account.profiles.any(
      (profile) => profile.id == profileId,
    );
  }

  /// Performs `_intFromValue` for this feature. Update this documentation when its contract changes.
  int _intFromValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  /// Performs `_doubleFromValue` for this feature. Update this documentation when its contract changes.
  double _doubleFromValue(
    dynamic value, {
    required double fallback,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(
      value?.toString() ?? '',
    );

    return parsed ?? fallback;
  }

  /// Performs `_percentage` for this feature. Update this documentation when its contract changes.
  double _percentage(
    int votes,
    int total,
  ) {
    if (total <= 0) {
      return 0;
    }

    return (votes / total) * 100;
  }

  /// Performs `_formatPercentage` for this feature. Update this documentation when its contract changes.
  String _formatPercentage(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchSession _sessionFromResponse(
    Map<String, dynamic> response,
  ) {
    final sessionData = response['session'];

    if (sessionData is! Map) {
      throw BackendApiException(
        'The server returned an invalid Group Watch session.',
      );
    }

    return GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles: currentAccount?.profiles ?? const <Profile>[],
    );
  }

  /// Performs `_upsertGroupWatchSession` for this feature. Update this documentation when its contract changes.
  void _upsertGroupWatchSession(
    GroupWatchSession session,
  ) {
    if (session.id.isEmpty) {
      return;
    }

    final index = groupWatchSessions.indexWhere(
      (item) => item.id == session.id,
    );

    if (index == -1) {
      groupWatchSessions.insert(
        0,
        session,
      );
      return;
    }

    groupWatchSessions[index] = session;
  }

  /// Performs `_backendMediaType` for this feature. Update this documentation when its contract changes.
  String _backendMediaType(
    String type,
  ) {
    final cleaned = type.trim().toLowerCase();

    if (cleaned == 'tvshow' ||
        cleaned == 'tv_show' ||
        cleaned == 'tv show' ||
        cleaned == 'series' ||
        cleaned == 'episode') {
      return 'tvShow';
    }

    return 'movie';
  }

  /// Performs `_pauseReasonDisplay` for this feature. Update this documentation when its contract changes.
  String _pauseReasonDisplay(
    String reason,
  ) {
    final cleaned = reason.trim();

    switch (cleaned.toLowerCase()) {
      case 'voy a cargar':
        return '🔋 Voy a cargar';

      case 'voy por un snack':
        return '🍿 Voy por un snack';

      case 'otro':
        return '💬 Otro';

      default:
        return '💬 $cleaned';
    }
  }

  // ---------------------------------------------------------------------------
  // COLLECTIONS
  // ---------------------------------------------------------------------------

  CollectionPreferences get currentCollectionPreferences {
    final profileId = currentProfile?.id ?? 'default';
    return collectionPreferencesByProfile.putIfAbsent(
        profileId, () => CollectionPreferences());
  }

  /// Performs `updateCollectionPreferences` for this feature. Update this documentation when its contract changes.
  void updateCollectionPreferences(CollectionPreferences preferences) {
    final profileId = currentProfile?.id ?? 'default';
    collectionPreferencesByProfile[profileId] = preferences;
    notifyListeners();
  }

  /// Performs `seedCollections` for this feature. Update this documentation when its contract changes.
  void seedCollections() {
    _refreshAutomaticCollections();
  }

  MediaCollection createCollection({
    required String name,
    String description = '',
    bool shared = true,
    bool featured = false,
    bool automatic = false,
    String? smartRule,
    String posterMode = 'First 4 Posters',
    String? customPosterUrl,
    Iterable<String> mediaIds = const <String>[],
  }) {
    final collection = MediaCollection(
      id: _generateId('collection'),
      name: name.trim(),
      description: description.trim(),
      createdByProfileId: currentProfile?.id,
      isShared: shared,
      isFeatured: featured,
      isAutomatic: automatic,
      smartRule: smartRule,
      posterMode: posterMode,
      customPosterUrl: customPosterUrl,
      mediaIds: mediaIds.toSet().toList(),
      contributorProfileIds: shared
          ? <String>{...?currentAccount?.profiles.map((p) => p.id)}
          : <String>{},
    );
    // The creator always has edit/add rights.
    if (currentProfile?.id != null) {
      collection.contributorProfileIds.add(currentProfile!.id);
    }
    collections.add(collection);
    if (featured) featuredCollectionOrder.add(collection.id);
    _refreshAutomaticCollections();
    addNotification(action: 'created collection "${collection.name}"');
    notifyListeners();
    return collection;
  }

  /// Performs `deleteCollection` for this feature. Update this documentation when its contract changes.
  void deleteCollection(String id) {
    collections.removeWhere(
        (c) => c.id == id && !c.isOfficial && c.canCurrentProfileEdit());
    featuredCollectionOrder.remove(id);
    notifyListeners();
  }

  /// Performs `addToCollection` for this feature. Update this documentation when its contract changes.
  void addToCollection(String collectionId, String mediaId) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileAdd()) return;
    if (!c.mediaIds.contains(mediaId)) {
      c.mediaIds.add(mediaId);
      notifyListeners();
    }
  }

  void addEpisodeToCollection(String collectionId, String episodeKey) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileAdd() || episodeKey.trim().isEmpty) return;
    if (!c.episodeKeys.contains(episodeKey)) c.episodeKeys.add(episodeKey);
    notifyListeners();
  }

  /// Performs `removeFromCollection` for this feature. Update this documentation when its contract changes.
  void removeFromCollection(String collectionId, String mediaId) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileEdit() || c.isAutomatic) return;
    c.mediaIds.remove(mediaId);
    notifyListeners();
  }

  /// Performs `addCollectionContributor` for this feature. Update this documentation when its contract changes.
  void addCollectionContributor(String collectionId, String profileId) {
    final c = collections.where((x) => x.id == collectionId).isEmpty
        ? null
        : collections.where((x) => x.id == collectionId).first;
    if (c == null || !c.canCurrentProfileEdit() || !c.isShared) {
      return;
    }
    c.contributorProfileIds.add(profileId);
    notifyListeners();
  }

  /// Performs `removeCollectionContributor` for this feature. Update this documentation when its contract changes.
  void removeCollectionContributor(String collectionId, String profileId) {
    final c = collections.where((x) => x.id == collectionId).isEmpty
        ? null
        : collections.where((x) => x.id == collectionId).first;
    if (c == null ||
        !c.canCurrentProfileEdit() ||
        profileId == c.createdByProfileId) {
      return;
    }
    c.contributorProfileIds.remove(profileId);
    notifyListeners();
  }

  /// Performs `toggleCollectionLike` for this feature. Update this documentation when its contract changes.
  void toggleCollectionLike(String collectionId) {
    final profileId = currentProfile?.id;
    if (profileId == null) {
      return;
    }
    final c = collections.where((x) => x.id == collectionId).isEmpty
        ? null
        : collections.where((x) => x.id == collectionId).first;
    if (c == null) {
      return;
    }
    if (!c.likedByProfileIds.add(profileId)) {
      c.likedByProfileIds.remove(profileId);
    }
    notifyListeners();
  }

  /// Performs `reorderCollectionSections` for this feature. Update this documentation when its contract changes.
  void reorderCollectionSections(List<String> order) {
    collectionSectionOrder
      ..clear()
      ..addAll(order);
    notifyListeners();
  }

  /// Performs `reorderFeaturedCollections` for this feature. Update this documentation when its contract changes.
  void reorderFeaturedCollections(List<String> order) {
    featuredCollectionOrder
      ..clear()
      ..addAll(order);
    notifyListeners();
  }

  /// Performs `_autoAssignFranchiseMetadata` for this feature. Update this documentation when its contract changes.
  void _autoAssignFranchiseMetadata(MediaItem media) {
    // Prefer authoritative metadata from an importer/provider when present.
    if (media.franchiseId != null && media.franchiseName != null) {
      return;
    }
    final detected = _knownFranchiseFor(media.title, media.releaseYear);
    if (detected == null) {
      return;
    }
    // MediaItem is intentionally immutable; automatic collection matching therefore
    // uses title/year matching too. Future provider metadata can populate these fields.
  }

  Map<String, dynamic>? _knownFranchiseFor(String title, int? year) {
    final t = _normalizeCollectionTitle(title);
    if (t.contains('back to the future')) {
      return {
        'id': 'back-to-the-future',
        'name': 'Back to the Future Trilogy',
        'type': 'Trilogy',
        'expected': 3
      };
    }
    if (t == 'ted' || t.startsWith('ted ')) {
      return {
        'id': 'ted',
        'name': 'Ted Collection',
        'type': 'Duology',
        'expected': 2
      };
    }
    if (RegExp(r'^harry potter').hasMatch(t)) {
      return {
        'id': 'harry-potter',
        'name': 'Harry Potter Collection',
        'type': 'Saga',
        'expected': 8
      };
    }
    if (t.contains('twilight')) {
      return {
        'id': 'twilight',
        'name': 'Twilight Saga Collection',
        'type': 'Saga',
        'expected': 5
      };
    }
    if (t.contains('jurassic park') || t.contains('jurassic world')) {
      return {
        'id': 'jurassic',
        'name': 'Jurassic Park / Jurassic World Collection',
        'type': 'Franchise',
        'expected': 7
      };
    }
    return null;
  }

  /// Performs `_normalizeCollectionTitle` for this feature. Update this documentation when its contract changes.
  String _normalizeCollectionTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Performs `_refreshAutomaticCollections` for this feature. Update this documentation when its contract changes.
  ///
  /// Automatic collections are created as soon as authoritative franchise or
  /// adaptation metadata identifies at least one library title. The previous
  /// implementation waited for the complete franchise count, which meant a
  /// partially owned franchise could never appear on the Collections screen.
  void _refreshAutomaticCollections() {
    // User-created smart collections are recalculated from the current profile's
    // authoritative library/reaction/history state whenever that state changes.
    for (final collection
        in collections.where((item) => item.smartRule != null)) {
      final matches = library
          .where((media) {
            final isShow = _isShowType(media.type);
            switch (collection.smartRule) {
              case 'liked_movies':
                return !isShow && isLiked(media.id);
              case 'liked_shows':
                return isShow && isLiked(media.id);
              case 'liked_media':
                return isLiked(media.id);
              case 'watched':
                return isWatched(media.id);
              case 'unwatched':
                return !isWatched(media.id);
              default:
                return false;
            }
          })
          .map((media) => media.id)
          .toList();
      collection.mediaIds
        ..clear()
        ..addAll(matches);
    }

    final definitions = <Map<String, dynamic>>[
      {
        // The same theme that Home previously generated as a virtual card is
        // now part of the shared collection index, so Watch > Collections sees it.
        'id': 'action-movies',
        'name': 'Action Movies Collection',
        'type': 'Theme',
        'match': (MediaItem m) {
          final normalizedType = m.type.toLowerCase();
          if (_isShowType(normalizedType) ||
              normalizedType.contains('album') ||
              normalizedType.contains('track') ||
              normalizedType.contains('song')) {
            return false;
          }
          final text = <String>[
            m.title,
            m.description ?? '',
            ...m.genres,
            ...m.tags,
            ...m.actors,
            if (m.franchiseName != null) m.franchiseName!,
          ].join(' ').toLowerCase();
          return const <String>['action', 'adventure', 'martial arts', 'spy', 'superhero']
              .any((keyword) => text.contains(keyword));
        },
      },
      {
        'id': 'back-to-the-future',
        'name': 'Back to the Future Trilogy',
        'type': 'Trilogy',
        'match': (MediaItem m) =>
            _normalizeCollectionTitle(m.title).contains('back to the future'),
      },
      {
        'id': 'ted',
        'name': 'Ted Collection',
        'type': 'Duology',
        'match': (MediaItem m) =>
            _normalizeCollectionTitle(m.title) == 'ted' ||
            _normalizeCollectionTitle(m.title).startsWith('ted '),
      },
      {
        'id': 'harry-potter',
        'name': 'Harry Potter Collection',
        'type': 'Saga',
        'match': (MediaItem m) =>
            m.franchiseId?.trim().isNotEmpty != true &&
            RegExp(r'^harry potter')
                .hasMatch(_normalizeCollectionTitle(m.title)),
      },
      {
        'id': 'twilight',
        'name': 'Twilight Saga Collection',
        'type': 'Saga',
        'match': (MediaItem m) =>
            _normalizeCollectionTitle(m.title).contains('twilight'),
      },
      {
        'id': 'jurassic',
        'name': 'Jurassic Park / Jurassic World Collection',
        'type': 'Franchise',
        'match': (MediaItem m) =>
            _normalizeCollectionTitle(m.title).contains('jurassic park') ||
            _normalizeCollectionTitle(m.title).contains('jurassic world'),
      },
    ];

    final automaticIds = <String>{};

    // Prefer importer/provider franchise metadata over title heuristics.
    final byFranchise = <String, List<MediaItem>>{};
    for (final media in library) {
      final franchiseId = media.franchiseId?.trim();
      final franchiseName = media.franchiseName?.trim();
      if (franchiseId == null ||
          franchiseId.isEmpty ||
          franchiseName == null ||
          franchiseName.isEmpty) {
        continue;
      }
      byFranchise.putIfAbsent(franchiseId, () => <MediaItem>[]).add(media);
    }
    for (final entry in byFranchise.entries) {
      final collectionId = 'franchise:${entry.key}';
      automaticIds.add(collectionId);
      final collection = _ensureAutomaticCollection(
        id: collectionId,
        name: entry.value.first.franchiseName!,
        type: entry.value.first.franchiseType ?? 'Franchise',
      );
      collection.mediaIds
        ..clear()
        ..addAll(entry.value.map((m) => m.id));
    }

    // Fallback rules keep existing local/demo libraries useful until an
    // authoritative metadata provider has populated franchiseId.
    for (final definition in definitions) {
      final matches = library
          .where((m) => (definition['match'] as bool Function(MediaItem))(m))
          .toList();
      if (matches.isEmpty) continue;
      final id = definition['id'] as String;
      automaticIds.add(id);
      final collection = _ensureAutomaticCollection(
        id: id,
        name: definition['name'] as String,
        type: definition['type'] as String,
      );
      collection.mediaIds
        ..clear()
        ..addAll(matches.map((m) => m.id));
    }

    // Keep automatic collections synchronized with the library. Custom
    // collections are never touched by this cleanup.
    collections.removeWhere((collection) =>
        collection.isAutomatic &&
        collection.automaticFranchiseId != null &&
        !automaticIds.contains(collection.automaticFranchiseId));
    featuredCollectionOrder.removeWhere(
        (id) => !collections.any((collection) => collection.id == id));
  }

  bool _isShowType(String type) {
    final value = type.toLowerCase();
    return value.contains('tv') ||
        value.contains('show') ||
        value.contains('series') ||
        value.contains('episode');
  }

  /// Creates or retrieves one authoritative automatic franchise collection.
  MediaCollection _ensureAutomaticCollection({
    required String id,
    required String name,
    required String type,
  }) {
    final existing = collections.where(
      (collection) =>
          collection.isAutomatic && collection.automaticFranchiseId == id,
    );
    if (existing.isNotEmpty) return existing.first;

    final collection = MediaCollection(
      id: _generateId('collection'),
      name: name,
      isOfficial: true,
      isAutomatic: true,
      isFeatured: true,
      isShared: true,
      automaticFranchiseId: id,
      automaticFranchiseType: type,
      contributorProfileIds: <String>{
        ...?currentAccount?.profiles.map((p) => p.id)
      },
    );
    collections.add(collection);
    if (!featuredCollectionOrder.contains(collection.id)) {
      featuredCollectionOrder.add(collection.id);
    }
    return collection;
  }

  // ---------------------------------------------------------------------------
  // ID GENERATION
  // ---------------------------------------------------------------------------

  /// Performs `_generateId` for this feature. Update this documentation when its contract changes.
  String _generateId(
    String prefix,
  ) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// -----------------------------------------------------------------------------
// GROUP WATCH / JSON HELPERS
// -----------------------------------------------------------------------------

DateTime? _dateTimeFromJson(
  dynamic value,
) {
  if (value is DateTime) {
    return value;
  }

  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}

double _doubleFromJson(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

Profile? _profileFromList(
  List<Profile> profiles,
  String profileId,
) {
  for (final profile in profiles) {
    if (profile.id == profileId) {
      return profile;
    }
  }

  return null;
}
// -----------------------------------------------------------------------------
// DETAILS CUSTOMIZATION
// -----------------------------------------------------------------------------

class DetailsCustomization {
  bool showPoster;
  bool showTitle;
  bool showMetadata;
  bool showOwnership;
  bool showDescription;
  bool showSeasons;
  bool showPlay;
  bool showTrailer;
  bool showGroupWatch;
  bool showAudioSubtitles;
  bool showReactions;
  bool showInformation;
  bool showLibrary;
  bool showRecommendations;
  bool showShop;

  bool showReleaseYear;
  bool showRating;
  bool showContentRating;
  bool showRuntime;

  String posterStyle;
  String posterPosition;
  String posterSize;
  String titleAlignment;
  String buttonAlignment;
  String informationAlignment;
  String seasonPlacement;
  String seasonOrder;
  String seasonSelectorStyle;
  String episodeNaming;

  List<String> sectionOrder;

  DetailsCustomization({
    this.showPoster = true,
    this.showTitle = true,
    this.showMetadata = true,
    this.showOwnership = true,
    this.showDescription = true,
    this.showSeasons = true,
    this.showPlay = true,
    this.showTrailer = true,
    this.showGroupWatch = true,
    this.showAudioSubtitles = true,
    this.showReactions = true,
    this.showInformation = true,
    this.showLibrary = true,
    this.showRecommendations = true,
    this.showShop = true,
    this.showReleaseYear = true,
    this.showRating = true,
    this.showContentRating = true,
    this.showRuntime = true,
    this.posterStyle = 'Standard',
    this.posterPosition = 'Center',
    this.posterSize = 'Medium',
    this.titleAlignment = 'Left',
    this.buttonAlignment = 'Left',
    this.informationAlignment = 'Left',
    this.seasonPlacement = 'Center',
    this.seasonOrder = 'Top to Bottom',
    this.seasonSelectorStyle = 'Buttons',
    this.episodeNaming = 'Actual Title',
    List<String>? sectionOrder,
  }) : sectionOrder = sectionOrder ??
            [
              'Poster',
              'Title',
              'Metadata',
              'Ownership',
              'Description',
              'Cast & Crew',
              'Seasons',
              'Collection Items',
              'Play',
              'Trailer',
              'Group Watch',
              'Shop',
              'Platform Actions',
              'Reviews',
              'Recommendations',
              'Audio & Subtitles',
              'Reactions',
              'Information',
              'Library',
            ];

  DetailsCustomization copy() {
    return DetailsCustomization(
      showPoster: showPoster,
      showTitle: showTitle,
      showMetadata: showMetadata,
      showOwnership: showOwnership,
      showDescription: showDescription,
      showSeasons: showSeasons,
      showPlay: showPlay,
      showTrailer: showTrailer,
      showGroupWatch: showGroupWatch,
      showAudioSubtitles: showAudioSubtitles,
      showReactions: showReactions,
      showInformation: showInformation,
      showLibrary: showLibrary,
      showRecommendations: showRecommendations,
      showShop: showShop,
      showReleaseYear: showReleaseYear,
      showRating: showRating,
      showContentRating: showContentRating,
      showRuntime: showRuntime,
      posterStyle: posterStyle,
      posterPosition: posterPosition,
      posterSize: posterSize,
      titleAlignment: titleAlignment,
      buttonAlignment: buttonAlignment,
      informationAlignment: informationAlignment,
      seasonPlacement: seasonPlacement,
      seasonOrder: seasonOrder,
      seasonSelectorStyle: seasonSelectorStyle,
      episodeNaming: episodeNaming,
      sectionOrder: List<String>.from(sectionOrder),
    );
  }
}

/// Implements the `DetailsCustomizationStore` class for this feature or UI component.
class DetailsCustomizationStore {
  DetailsCustomizationStore._();

  static final Map<String, DetailsCustomization> _settings =
      <String, DetailsCustomization>{};
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    const prefix = 'details_customization_';
    for (final key in _prefs!.getKeys().where((k) => k.startsWith(prefix))) {
      final raw = _prefs!.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _settings[key.substring(prefix.length)] = _fromJson(map);
      } catch (_) {}
    }
  }

  static DetailsCustomization settingsFor(Profile? profile) {
    final key = profile?.id ?? 'default';
    final value = _settings.putIfAbsent(key, () => DetailsCustomization());
    if (!value.sectionOrder.contains('Cast & Crew')) {
      final descriptionIndex = value.sectionOrder.indexOf('Description');
      if (descriptionIndex >= 0) {
        value.sectionOrder.insert(descriptionIndex + 1, 'Cast & Crew');
      } else {
        value.sectionOrder.insert(0, 'Cast & Crew');
      }
    }
    if (!value.sectionOrder.contains('Collection Items')) {
      value.sectionOrder.add('Collection Items');
    }
    if (!value.sectionOrder.contains('Recommendations')) {
      value.sectionOrder.add('Recommendations');
    }
    return value.copy();
  }

  static void apply(Profile? profile, DetailsCustomization value) {
    final key = profile?.id ?? 'default';
    final copy = value.copy();
    _settings[key] = copy;
    _prefs?.setString('details_customization_$key', jsonEncode(_toJson(copy)));
  }

  static Map<String, dynamic> snapshotFor(Profile? profile) {
    final value = settingsFor(profile);
    return _toJson(value);
  }

  static void removeProfile(Profile profile) {
    _settings.remove(profile.id);
    _prefs?.remove('details_customization_${profile.id}');
  }

  static void clear() {
    for (final key in _settings.keys) {
      _prefs?.remove('details_customization_$key');
    }
    _settings.clear();
  }

  static Map<String, dynamic> _toJson(DetailsCustomization v) => {
        'showPoster': v.showPoster,
        'showTitle': v.showTitle,
        'showMetadata': v.showMetadata,
        'showOwnership': v.showOwnership,
        'showDescription': v.showDescription,
        'showSeasons': v.showSeasons,
        'showPlay': v.showPlay,
        'showTrailer': v.showTrailer,
        'showGroupWatch': v.showGroupWatch,
        'showAudioSubtitles': v.showAudioSubtitles,
        'showReactions': v.showReactions,
        'showInformation': v.showInformation,
        'showLibrary': v.showLibrary,
        'showRecommendations': v.showRecommendations,
        'showShop': v.showShop,
        'showReleaseYear': v.showReleaseYear,
        'showRating': v.showRating,
        'showContentRating': v.showContentRating,
        'showRuntime': v.showRuntime,
        'posterStyle': v.posterStyle,
        'posterPosition': v.posterPosition,
        'posterSize': v.posterSize,
        'titleAlignment': v.titleAlignment,
        'buttonAlignment': v.buttonAlignment,
        'informationAlignment': v.informationAlignment,
        'seasonPlacement': v.seasonPlacement,
        'seasonOrder': v.seasonOrder,
        'seasonSelectorStyle': v.seasonSelectorStyle,
        'episodeNaming': v.episodeNaming,
        'sectionOrder': v.sectionOrder,
      };

  static DetailsCustomization _fromJson(Map<String, dynamic> m) =>
      DetailsCustomization(
        showPoster: m['showPoster'] == false ? false : true,
        showTitle: m['showTitle'] == false ? false : true,
        showMetadata: m['showMetadata'] == false ? false : true,
        showOwnership: m['showOwnership'] == false ? false : true,
        showDescription: m['showDescription'] == false ? false : true,
        showSeasons: m['showSeasons'] == false ? false : true,
        showPlay: m['showPlay'] == false ? false : true,
        showTrailer: m['showTrailer'] == false ? false : true,
        showGroupWatch: m['showGroupWatch'] == false ? false : true,
        showAudioSubtitles: m['showAudioSubtitles'] == false ? false : true,
        showReactions: m['showReactions'] == false ? false : true,
        showInformation: m['showInformation'] == false ? false : true,
        showLibrary: m['showLibrary'] == false ? false : true,
        showRecommendations: m['showRecommendations'] == false ? false : true,
        showShop: m['showShop'] == false ? false : true,
        showReleaseYear: m['showReleaseYear'] == false ? false : true,
        showRating: m['showRating'] == false ? false : true,
        showContentRating: m['showContentRating'] == false ? false : true,
        showRuntime: m['showRuntime'] == false ? false : true,
        posterStyle: m['posterStyle']?.toString() ?? 'Standard',
        posterPosition: m['posterPosition']?.toString() ?? 'Center',
        posterSize: m['posterSize']?.toString() ?? 'Medium',
        titleAlignment: m['titleAlignment']?.toString() ?? 'Left',
        buttonAlignment: m['buttonAlignment']?.toString() ?? 'Left',
        informationAlignment: m['informationAlignment']?.toString() ?? 'Left',
        seasonPlacement: m['seasonPlacement']?.toString() ?? 'Center',
        seasonOrder: m['seasonOrder']?.toString() ?? 'Top to Bottom',
        seasonSelectorStyle: m['seasonSelectorStyle']?.toString() ?? 'Buttons',
        episodeNaming: m['episodeNaming']?.toString() ?? 'Actual Title',
        sectionOrder: (m['sectionOrder'] is List)
            ? List<String>.from(m['sectionOrder'] as List)
            : null,
      );
}
