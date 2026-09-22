// FILE: `Backend/arm/arm_service.dart`.
// Purpose: Coordinates ARM communication, disc detection, ripping,
// verification, and conversion of ARM results into the streaming service's
// physical-release/disc/content model.
//
// This file is part of the documented Flutter/home-server architecture.
//
// Important media-identity rules:
//
//   Physical Release
//       -> Physical Disc
//           -> Disc Content
//
// A disc can contain multiple pieces of content. A bonus disc is therefore
// never automatically treated as another movie.
//
// Music follows:
//
//   Music Release
//       -> Music Medium
//           -> Music Track
//               -> Music Recording
//
// The canonical recording identity is intentionally separate from the
// physical/specific release so that the same song can be discovered first
// from an album and later from a movie soundtrack, or vice versa.

import 'dart:io';
import 'dart:math';

import 'arm_client.dart';
import 'arm_models.dart';
import 'arm_title_resolver.dart';
import 'arm_verifier.dart';

class ArmService {
  final ArmClient client;
  final ArmVerifier verifier;

  final Random _random = Random();

  final Map<String, ArmRipJob> _jobs = {};
  final Map<String, String> _armJobIds = {};

  final ArmTitleResolver titleResolver = const ArmTitleResolver();

  ArmService({
    required this.client,
    this.verifier = const ArmVerifier(),
  });

  String _generateId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(100000)}';

  Future<bool> isConnected() => client.checkConnection();

  /// Finds optical drives known to ARM.
  ///
  /// ARM normally detects disc insertion automatically. The service therefore
  /// uses configured drives plus device paths reported by ARM jobs rather than
  /// inventing a drive-control API that ARM does not expose.
  Future<List<ArmDrive>> findDrives() async {
    final configured = (
      Platform.environment['ARM_DRIVES'] ??
          const String.fromEnvironment(
            'ARM_DRIVES',
            defaultValue: '',
          )
    ).trim();

    final drives = <ArmDrive>[];

    for (final raw in configured.split(',')) {
      final path = raw.trim();

      if (path.isEmpty) {
        continue;
      }

      drives.add(
        ArmDrive(
          id: path,
          path: path,
          name: path,
          available: true,
          discInserted: false,
        ),
      );
    }

    final jobs = await _getArmJobs();

    final seen = <String>{
      ...drives.map((drive) => drive.id),
    };

    for (final job in jobs) {
      final path = _string(
        job,
        [
          'devpath',
          'device',
          'drive',
          'drive_path',
        ],
      );

      if (path == null ||
          path.isEmpty ||
          seen.contains(path)) {
        continue;
      }

      seen.add(path);

      drives.add(
        ArmDrive(
          id: path,
          path: path,
          name: path,
          available: true,
          discInserted: !_isFinishedArmStatus(
            _string(job, ['status', 'state']),
          ),
        ),
      );
    }

    if (drives.isEmpty) {
      drives.add(
        ArmDrive(
          id: 'arm-auto',
          path: '',
          name: 'ARM automatic drive monitor',
          available: true,
          discInserted: false,
        ),
      );
    }

    return drives;
  }

  /// Scans ARM's current job information and builds a normalized disc model.
  ///
  /// This remains compatible with ARM's job-list based workflow. A richer
  /// ArmPhysicalDisc can subsequently be created from the returned ArmDisc.
  Future<ArmDisc> scanDisc({
    required String driveId,
  }) async {
    final jobs = await _getArmJobs();

    final matching = jobs.where((job) {
      final path = _string(
        job,
        [
          'devpath',
          'device',
          'drive',
          'drive_path',
        ],
      );

      return driveId == 'arm-auto' || path == driveId;
    }).toList();

    if (matching.isEmpty) {
      return ArmDisc(
        driveId: driveId,
        detected: false,
      );
    }

    final job = matching.last;

    return ArmDisc(
      driveId: driveId,
      title: _string(
        job,
        ['title', 'name'],
      ),
      mediaType: _string(
        job,
        ['videotype', 'mediaType', 'type'],
      ),
      discType: _normalizeDiscType(
        _string(
          job,
          ['disctype', 'discType'],
        ),
      ),
      region: _string(
        job,
        ['region'],
      ),
      detected: true,
      titles: _extractDiscTitles(job),
    );
  }

  /// Converts a detected disc into an automatic import plan.
  ///
  /// The plan now carries explicit physical-disc/content provenance instead
  /// of treating every detected title as an independent top-level movie.
  ///
  /// A title such as:
  ///
  ///   Back to the Future
  ///
  /// can therefore become:
  ///
  ///   Physical Release
  ///     -> Disc 1
  ///       -> Feature -> Back to the Future
  ///
  /// while a bonus disc can contain:
  ///
  ///   Disc 4
  ///     -> Deleted Scene
  ///     -> Interview
  ///     -> Trailer
  ///
  /// without those extras becoming normal movie-library entries.
  List<Map<String, dynamic>> buildAutomaticImportPlan(
    ArmDisc disc,
  ) {
    final physicalDisc = disc.toPhysicalDisc(
      id: _generateId('disc'),
      releaseId: _generateId('release'),
      discNumber: 1,
    );

    return disc.titles.asMap().entries.map((entry) {
      final index = entry.key;
      final title = entry.value;

      final content = title.toDiscContent(
        discId: physicalDisc.id,
        contentId: '${physicalDisc.id}_content_${index + 1}',
      );

      return {
        'titleId': title.id,
        'title': title.title,
        'mediaType': title.mediaType,
        'classification': title.classification,
        'outputPath': title.outputPath,

        // Legacy compatibility.
        'discId': disc.driveId,
        'discTitle': disc.title,
        'discType': disc.discType,

        // New physical-media provenance.
        'physicalDiscId': physicalDisc.id,
        'physicalReleaseId': physicalDisc.releaseId,
        'discNumber': physicalDisc.discNumber,
        'contentId': content.id,
        'contentType': content.contentType.name,
        'isPrimaryContent': content.primary,
        'isBonusContent': content.isBonus,

        'region': title.detectedRegion ?? disc.region,
        'marketCountry': title.discMarketCountry,
        'archiveFormat': title.preferredArchiveFormat,

        // Music is archived losslessly when represented as music content.
        'losslessAudio': title.isMusic,

        'artwork': title.metadata['artwork'] ??
            title.metadata['poster'],
        'description': title.metadata['description'] ??
            title.metadata['overview'],
        'cast': title.metadata['cast'] ??
            title.metadata['actors'],

        'artist': title.artist,
        'album': title.album,
        'trackNumber': title.trackNumber,
        'sourceDiscNumber': title.discNumber,
      };
    }).toList(growable: false);
  }

  /// Creates a local import job representing ARM's automatic workflow.
  ///
  /// ARM normally starts ripping after disc insertion. We therefore snapshot
  /// the newest relevant ARM job instead of calling an undocumented "start"
  /// endpoint.
  Future<ArmRipJob> startImport({
    required String driveId,
  }) async {
    final local = ArmRipJob(
      id: _generateId('rip'),
      driveId: driveId,
      status: ArmJobStatus.detecting.name,
      progress: 0,
      createdAt: DateTime.now(),
      message:
          'ARM is monitoring the optical drive. Insert the disc; ARM will detect and start the rip automatically.',
    );

    _jobs[local.id] = local;

    final jobs = await _getArmJobs();

    if (jobs.isNotEmpty) {
      final armJob = _selectRelevantJob(
        jobs,
        driveId,
      );

      if (armJob != null) {
        final armId = _string(
          armJob,
          ['job_id', 'jobId', 'id'],
        );

        if (armId != null) {
          _armJobIds[local.id] = armId;
        }

        _applyArmJob(
          local,
          armJob,
        );
      }
    }

    return local;
  }

  /// Refreshes a locally tracked rip job from ARM.
  Future<ArmRipJob> refreshJob(
    String jobId,
  ) async {
    final local = _jobs[jobId];

    if (local == null) {
      throw Exception('Rip job not found.');
    }

    final jobs = await _getArmJobs();

    Map<String, dynamic>? selected;

    final armId = _armJobIds[jobId];

    if (armId != null) {
      for (final job in jobs) {
        if (_string(
              job,
              ['job_id', 'jobId', 'id'],
            ) ==
            armId) {
          selected = job;
          break;
        }
      }
    }

    selected ??= _selectRelevantJob(
      jobs,
      local.driveId,
    );

    if (selected != null) {
      final foundArmId = _string(
        selected,
        ['job_id', 'jobId', 'id'],
      );

      if (foundArmId != null) {
        _armJobIds[jobId] = foundArmId;
      }

      _applyArmJob(
        local,
        selected,
      );

      if (_isCompleted(local.status) &&
          local.outputPath != null &&
          local.verification == null) {
        local.status = ArmJobStatus.verifying.name;

        local.verification = await verifier.verify(
          outputPath: local.outputPath!,
          expectedDurationSeconds: _double(
            selected,
            [
              'duration',
              'runtime',
              'length',
            ],
          ),
          expectedChapterCount: _int(
            selected,
            [
              'chapter_count',
              'chapterCount',
              'chapters',
            ],
          ),
        );

        if (local.verification!.passed) {
          local.status = ArmJobStatus.readyForReview.name;
          local.message =
              'Rip verified. Review the metadata before adding it to your library.';
        } else {
          local.status = ArmJobStatus.rejected.name;
          local.message = local.verification!.reason;
        }
      }
    }

    return local;
  }

  /// Cancels the local representation of a rip.
  ///
  /// ARM exposes an "abandon" action through its UI, but unless a stable
  /// authenticated endpoint is explicitly configured we do not pretend that
  /// this service can safely terminate ARM's underlying process.
  Future<ArmRipJob> cancelJob(
    String jobId,
  ) async {
    final job = _jobs[jobId];

    if (job == null) {
      throw Exception('Rip job not found.');
    }

    if (job.isFinished) {
      return job;
    }

    job.status = ArmJobStatus.cancelled.name;
    job.message = 'Import cancelled.';
    job.completedAt = DateTime.now();

    return job;
  }

  /// Returns a richer physical release representation for a detected disc.
  ///
  /// This does not persist anything yet. Persistence belongs to the database
  /// and import services that will consume this model later in the ARM stack.
  ArmPhysicalRelease buildPhysicalRelease(
    ArmDisc disc, {
    String? releaseId,
    String? edition,
    String? barcode,
    String? country,
    int? releaseYear,
  }) {
    final id = releaseId ?? _generateId('release');

    final physicalDisc = disc.toPhysicalDisc(
      id: _generateId('disc'),
      releaseId: id,
      discNumber: 1,
    );

    final inferredReleaseType =
        _inferReleaseType(
      disc,
    );

    return ArmPhysicalRelease(
      id: id,
      title: disc.title?.trim().isNotEmpty == true
          ? disc.title!.trim()
          : 'ARM physical release',
      releaseType: inferredReleaseType,
      edition: edition,
      barcode: barcode,
      country: country,
      region: disc.region,
      releaseYear: releaseYear,
      discs: [
        physicalDisc,
      ],
      metadata: {
        'armDriveId': disc.driveId,
        'detected': disc.detected,
        'source': 'arm',
      },
    );
  }

  /// Builds a richer physical disc model from a detected ARM disc.
  ArmPhysicalDisc buildPhysicalDisc(
    ArmDisc disc, {
    required String releaseId,
    String? discId,
    int discNumber = 1,
  }) {
    return disc.toPhysicalDisc(
      id: discId ?? _generateId('disc'),
      releaseId: releaseId,
      discNumber: discNumber,
    );
  }

  /// Converts ARM's music-like titles into a release/track representation.
  ///
  /// This is deliberately a normalization step only. It does not claim that
  /// two tracks are identical. Canonical recording matching belongs to the
  /// music-ingestion layer, where ISRC/fingerprints/metadata can be compared.
  ArmMusicRelease? buildMusicRelease(
    ArmDisc disc, {
    String? releaseId,
    String? artist,
    String? releaseType,
  }) {
    final musicTitles = disc.titles
        .where(
          (title) => title.isMusic,
        )
        .toList(growable: false);

    if (musicTitles.isEmpty) {
      return null;
    }

    final id = releaseId ?? _generateId('music_release');

    final tracks = <ArmMusicTrack>[];

    for (var index = 0;
        index < musicTitles.length;
        index++) {
      final title = musicTitles[index];

      tracks.add(
        ArmMusicTrack(
          id: '${id}_track_${index + 1}',
          releaseId: id,
          mediumId: '${id}_medium_1',
          trackNumber: title.trackNumber ?? index + 1,
          title: title.title,
          artist: title.artist ?? artist,
          durationSeconds: title.durationSeconds,
          outputPath: title.outputPath,
          metadata: {
            ...title.metadata,
            'sourceDiscId': disc.driveId,
            'sourceDiscTitle': disc.title,
            'sourceDiscNumber': title.discNumber,
          },
        ),
      );
    }

    final mediumId = '${id}_medium_1';

    return ArmMusicRelease(
      id: id,
      title: disc.title?.trim().isNotEmpty == true
          ? disc.title!.trim()
          : musicTitles.first.album ??
              'Unknown music release',
      artist: artist ?? musicTitles.first.artist,
      releaseType: releaseType ?? _inferMusicReleaseType(disc),
      mediums: [
        ArmMusicMedium(
          id: mediumId,
          releaseId: id,
          mediumNumber: 1,
          title: disc.title,
          mediumType: 'disc',
          tracks: tracks,
          metadata: {
            'sourceDiscId': disc.driveId,
            'sourceDiscType': disc.discType,
          },
        ),
      ],
      metadata: {
        'source': 'arm',
        'sourceDriveId': disc.driveId,
        'sourceDiscTitle': disc.title,
        'sourceDiscRegion': disc.region,
      },
    );
  }

  /// Extracts a canonical recording candidate from an ARM music track.
  ///
  /// This does not assign a new recording ID when one is already available.
  /// The eventual recording-resolution service can use ISRC, fingerprint,
  /// normalized title/artist and duration to find an existing recording.
  ArmMusicRecording buildRecordingCandidate(
    ArmMusicTrack track, {
    String? recordingId,
  }) {
    return ArmMusicRecording(
      id: recordingId ?? '',
      title: track.title,
      artists: track.artist == null
          ? const []
          : [track.artist!],
      durationSeconds: track.durationSeconds,
      isrc: track.isrc,
      audioFingerprint: track.fingerprint,
      metadata: {
        ...track.metadata,
        'sourceTrackId': track.id,
        'sourceReleaseId': track.releaseId,
        'sourceMediumId': track.mediumId,
      },
    );
  }

  /// Applies the latest ARM job state to our local job.
  void _applyArmJob(
    ArmRipJob local,
    Map<String, dynamic> arm,
  ) {
    local.title = _string(
      arm,
      ['title', 'name'],
    );

    local.mediaType = _string(
      arm,
      ['videotype', 'mediaType', 'type'],
    );

    local.discType = _normalizeDiscType(
      _string(
        arm,
        ['disctype', 'discType'],
      ),
    );

    local.region = _string(
      arm,
      ['region'],
    );

    local.collectionTitle = _string(
      arm,
      [
        'disc_title',
        'discTitle',
        'collectionTitle',
        'collection',
        'title',
      ],
    );

    local.titles = _extractDiscTitles(arm);

    local.outputPath = _string(
      arm,
      [
        'outputPath',
        'output_path',
        'path',
        'destination',
        'destination_path',
      ],
    );

    local.progress = _double(
          arm,
          [
            'progress_round',
            'progress',
            'percent',
          ],
        ) ??
        0;

    final rawStatus =
        (_string(
              arm,
              ['status', 'state'],
            ) ??
            'active')
            .toLowerCase();

    local.status = _mapStatus(rawStatus);

    local.message = _string(
      arm,
      [
        'message',
        'stage',
        'status',
      ],
    );

    _applyPhysicalMediaModels(
      local,
      arm,
    );

    if (_isCompleted(local.status)) {
      local.completedAt ??= DateTime.now();
    }
  }

  /// Creates the richer physical release/disc representation on the local
  /// rip job without changing the existing legacy fields.
  void _applyPhysicalMediaModels(
    ArmRipJob local,
    Map<String, dynamic> arm,
  ) {
    if (local.titles.isEmpty &&
        local.title?.trim().isEmpty != false) {
      return;
    }

    final releaseId = _string(
          arm,
          [
            'physicalReleaseId',
            'releaseId',
            'release_id',
          ],
        ) ??
        _generateId('release');

    final discId = _string(
          arm,
          [
            'physicalDiscId',
            'discId',
            'disc_id',
          ],
        ) ??
        _generateId('disc');

    final discType = ArmDiscTypeExtension.fromValue(
      local.discType,
    );

    final contents = local.titles.asMap().entries.map(
      (entry) {
        final index = entry.key;
        final title = entry.value;

        return title.toDiscContent(
          discId: discId,
          contentId: '${discId}_content_${index + 1}',
        );
      },
    ).toList(growable: false);

    local.physicalDisc = ArmPhysicalDisc(
      id: discId,
      releaseId: releaseId,
      discNumber: _int(
            arm,
            [
              'discNumber',
              'disc_number',
              'disc',
            ],
          ) ??
          1,
      title: local.collectionTitle ?? local.title,
      discType: discType,
      region: local.region,
      outputPath: local.outputPath,
      contents: contents,
      metadata: {
        'source': 'arm',
        'driveId': local.driveId,
        'armJobId': _string(
          arm,
          ['job_id', 'jobId', 'id'],
        ),
      },
    );

    local.physicalRelease = ArmPhysicalRelease(
      id: releaseId,
      title: local.collectionTitle ??
          local.title ??
          'ARM physical release',
      releaseType: _inferReleaseTypeFromJob(
        arm,
        local.titles,
      ),
      edition: _string(
        arm,
        ['edition', 'releaseEdition'],
      ),
      barcode: _string(
        arm,
        ['barcode', 'upc', 'ean'],
      ),
      country: _string(
        arm,
        ['country', 'countryOfOrigin'],
      ),
      region: local.region,
      releaseYear: _int(
        arm,
        ['releaseYear', 'year'],
      ),
      discs: [
        local.physicalDisc!,
      ],
      metadata: {
        'source': 'arm',
        'driveId': local.driveId,
        'armJobId': _string(
          arm,
          ['job_id', 'jobId', 'id'],
        ),
      },
    );

    local.recordings = _buildRecordingCandidates(
      local.titles,
    );
  }

  /// Converts music titles into recording candidates.
  ///
  /// At this stage these are candidates, not newly-created canonical
  /// recordings. The database/music service will decide whether each one
  /// matches an existing recording.
  List<ArmMusicRecording> _buildRecordingCandidates(
    List<ArmDiscTitle> titles,
  ) {
    final candidates = <ArmMusicRecording>[];

    for (final title in titles) {
      if (!title.isMusic) {
        continue;
      }

      final metadata = title.metadata;

      candidates.add(
        ArmMusicRecording(
          id: '',
          title: title.title,
          artists: title.artist == null
              ? const []
              : [title.artist!],
          durationSeconds: title.durationSeconds,
          isrc: _metadataString(
            metadata,
            [
              'isrc',
              'ISRC',
            ],
          ),
          audioFingerprint: _metadataString(
            metadata,
            [
              'audioFingerprint',
              'fingerprint',
              'contentFingerprint',
            ],
          ),
          metadata: {
            ...metadata,
            'source': 'arm',
            'sourceTitleId': title.id,
            'sourceOutputPath': title.outputPath,
            'sourceAlbum': title.album,
          },
        ),
      );
    }

    return candidates;
  }

  /// Gets the ARM job list.
  Future<List<Map<String, dynamic>>> _getArmJobs() async {
    final response = await client.getJsonMode(
      'joblist',
    );

    final results = response['results'];

    if (results is Map) {
      return results.values
          .whereType<Map>()
          .map(
            (entry) => Map<String, dynamic>.from(entry),
          )
          .toList();
    }

    if (results is List) {
      return results
          .whereType<Map>()
          .map(
            (entry) => Map<String, dynamic>.from(entry),
          )
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _selectRelevantJob(
    List<Map<String, dynamic>> jobs,
    String driveId,
  ) {
    if (jobs.isEmpty) {
      return null;
    }

    if (driveId == 'arm-auto' ||
        driveId.isEmpty) {
      return jobs.last;
    }

    for (final job in jobs.reversed) {
      final path = _string(
        job,
        [
          'devpath',
          'device',
          'drive',
          'drive_path',
        ],
      );

      if (path == driveId) {
        return job;
      }
    }

    return jobs.last;
  }

  String _mapStatus(
    String raw,
  ) {
    if (raw.contains('fail') ||
        raw.contains('error')) {
      return ArmJobStatus.failed.name;
    }

    if (raw.contains('success') ||
        raw.contains('complete') ||
        raw == 'finished') {
      return ArmJobStatus.completed.name;
    }

    if (raw.contains('verify')) {
      return ArmJobStatus.verifying.name;
    }

    if (raw.contains('transcod') ||
        raw.contains('process')) {
      return ArmJobStatus.processing.name;
    }

    if (raw.contains('rip')) {
      return ArmJobStatus.ripping.name;
    }

    if (raw.contains('ident')) {
      return ArmJobStatus.identifying.name;
    }

    if (raw.contains('detect') ||
        raw.contains('insert') ||
        raw.contains('disc')) {
      return ArmJobStatus.detecting.name;
    }

    return ArmJobStatus.processing.name;
  }

  bool _isCompleted(
    String status,
  ) =>
      status == ArmJobStatus.completed.name ||
      status == ArmJobStatus.failed.name;

  bool _isFinishedArmStatus(
    String? status,
  ) {
    final value = (status ?? '').toLowerCase();

    return value.contains('success') ||
        value.contains('finish') ||
        value.contains('complete') ||
        value.contains('fail') ||
        value.contains('error');
  }

  String? _string(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();

      if (value != null &&
          value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  double? _double(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];

      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(
              value?.toString() ?? '',
            );

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  int? _int(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];

      final parsed = value is num
          ? value.toInt()
          : int.tryParse(
              value?.toString() ?? '',
            );

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  String? _metadataString(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key]?.toString().trim();

      if (value != null &&
          value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  /// Extracts all title/content candidates ARM exposes for a job.
  ///
  /// ARM installations can expose titles as a list, map, features,
  /// playlists, or a single top-level title.
  List<ArmDiscTitle> _extractDiscTitles(
    Map<String, dynamic> arm,
  ) {
    final raw = arm['titles'] ??
        arm['discTitles'] ??
        arm['features'] ??
        arm['playlists'] ??
        arm['titleList'] ??
        arm['title_list'];

    final values = <dynamic>[];

    if (raw is List) {
      values.addAll(raw);
    } else if (raw is Map) {
      values.addAll(raw.values);
    }

    final titles = <ArmDiscTitle>[];

    for (var i = 0;
        i < values.length;
        i++) {
      final value = values[i];

      if (value is! Map) {
        continue;
      }

      final title = titleResolver.resolve(
        ArmDiscTitle.fromJson(
          Map<String, dynamic>.from(value),
          fallbackId: 'title_${i + 1}',
        ),
      );

      if (title.title.trim().isEmpty ||
          title.title.toLowerCase() ==
              'unknown title') {
        continue;
      }

      titles.add(title);
    }

    // Some ARM integrations expose only one feature directly on the job.
    if (titles.isEmpty) {
      final title = _string(
        arm,
        ['title', 'name'],
      );

      if (title != null) {
        titles.add(
          titleResolver.resolve(
            ArmDiscTitle(
              id: _string(
                    arm,
                    [
                      'title_id',
                      'titleId',
                      'id',
                    ],
                  ) ??
                  'title_1',
              title: title,
              mediaType: _string(
                    arm,
                    [
                      'videotype',
                      'mediaType',
                      'type',
                    ],
                  ) ??
                  'movie',
              classification: _string(
                    arm,
                    [
                      'classification',
                      'kind',
                      'contentType',
                    ],
                  ) ??
                  'feature',
              year: _int(
                arm,
                [
                  'year',
                  'releaseYear',
                ],
              ),
              durationSeconds: _double(
                arm,
                [
                  'durationSeconds',
                  'duration',
                  'runtime',
                  'length',
                ],
              ),
              confidence: _double(
                    arm,
                    [
                      'confidence',
                      'matchConfidence',
                    ],
                  ) ??
                  0,
              outputPath: _string(
                arm,
                [
                  'outputPath',
                  'output_path',
                  'path',
                  'destination',
                  'destination_path',
                ],
              ),
              metadata: Map<String, dynamic>.from(arm),
              discTitle: title,
              detectedRegion: _string(
                arm,
                ['region'],
              ),
            ),
          ),
        );
      }
    }

    return titles;
  }

  ArmReleaseType _inferReleaseType(
    ArmDisc disc,
  ) {
    final normalized =
        '${disc.mediaType ?? ''} ${disc.discType ?? ''}'
            .toLowerCase();

    if (normalized.contains('soundtrack') ||
        normalized.contains('ost')) {
      return ArmReleaseType.soundtrack;
    }

    if (normalized.contains('album') ||
        normalized.contains('music')) {
      return ArmReleaseType.album;
    }

    if (normalized.contains('tv') ||
        normalized.contains('episode') ||
        normalized.contains('television')) {
      return ArmReleaseType.tv;
    }

    if (normalized.contains('movie') ||
        normalized.contains('film') ||
        normalized.contains('dvd') ||
        normalized.contains('bluray') ||
        normalized.contains('blu-ray') ||
        normalized.contains('uhd') ||
        normalized.contains('4k')) {
      return ArmReleaseType.movie;
    }

    if (disc.titles.any(
      (title) => title.isMusic,
    )) {
      return ArmReleaseType.musicVideo;
    }

    return ArmReleaseType.other;
  }

  ArmReleaseType _inferReleaseTypeFromJob(
    Map<String, dynamic> arm,
    List<ArmDiscTitle> titles,
  ) {
    final type = _string(
      arm,
      [
        'releaseType',
        'release_type',
        'mediaType',
        'videotype',
        'type',
      ],
    );

    if (type != null) {
      final inferred =
          ArmReleaseTypeExtension.fromValue(type);

      if (inferred != ArmReleaseType.other) {
        return inferred;
      }
    }

    if (titles.any(
      (title) => title.isMusic,
    )) {
      return ArmReleaseType.soundtrack;
    }

    return ArmReleaseType.movie;
  }

  String _inferMusicReleaseType(
    ArmDisc disc,
  ) {
    final normalized =
        '${disc.title ?? ''} ${disc.discType ?? ''}'
            .toLowerCase();

    if (normalized.contains('soundtrack') ||
        normalized.contains('ost')) {
      return 'soundtrack';
    }

    if (normalized.contains('compilation')) {
      return 'compilation';
    }

    if (normalized.contains('single')) {
      return 'single';
    }

    if (normalized.contains('ep')) {
      return 'ep';
    }

    return 'album';
  }

  String? _normalizeDiscType(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final v = value.toLowerCase();

    if (v.contains('4k') ||
        v.contains('uhd')) {
      return '4K Ultra HD';
    }

    if (v.contains('bluray') ||
        v.contains('blu-ray')) {
      return 'Blu-ray';
    }

    if (v.contains('dvd')) {
      return 'DVD';
    }

    return value;
  }
}
