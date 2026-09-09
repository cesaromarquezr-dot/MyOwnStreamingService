import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'app_core.dart';
import 'player.dart';
import 'group_watch.dart';

class MediaDetailsScreen extends StatefulWidget {
  final MediaItem media;

  const MediaDetailsScreen({
    super.key,
    required this.media,
  });

  @override
  State<MediaDetailsScreen> createState() =>
      _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  bool pressedPlay = false;
  bool pressedTrailer = false;

  String selectedAudio = 'Default';
  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  int selectedSeasonIndex = 0;

  MediaItem get media => widget.media;

  /// Details customization belongs to the currently selected profile.
  ///
  /// P1, P2 and P3 are profiles.
  /// They are NOT layout choices.
  DetailsCustomization get customization {
    return DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFF090909),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: Text(
                media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildDetailsPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPage() {
    if (AppController.instance.currentProfile == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No profile selected.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in customization.sectionOrder)
            _buildSection(section),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION ROUTER
  // ===========================================================================

  Widget _buildSection(String section) {
    switch (section) {
      case 'Poster':
        if (!customization.showPoster) {
          return const SizedBox.shrink();
        }
        return _buildPoster();

      case 'Title':
        if (!customization.showTitle) {
          return const SizedBox.shrink();
        }
        return _buildTitle();

      case 'Metadata':
        if (!customization.showMetadata) {
          return const SizedBox.shrink();
        }
        return _buildMetadata();

      case 'Ownership':
        if (!customization.showOwnership) {
          return const SizedBox.shrink();
        }
        return _buildOwnership();

      case 'Description':
        if (!customization.showDescription) {
          return const SizedBox.shrink();
        }
        return _buildDescription();

      case 'Seasons':
        if (!isTvShow || !customization.showSeasons) {
          return const SizedBox.shrink();
        }
        return _buildSeasonsSection();

      case 'Play':
        if (!customization.showPlay) {
          return const SizedBox.shrink();
        }
        return _buildPlay();

      case 'Trailer':
        if (!customization.showTrailer || !hasTrailer) {
          return const SizedBox.shrink();
        }
        return _buildTrailer();

      case 'Group Watch':
        if (!customization.showGroupWatch) {
          return const SizedBox.shrink();
        }
        return _buildGroupWatch();

      case 'Audio & Subtitles':
        if (!customization.showAudioSubtitles) {
          return const SizedBox.shrink();
        }
        return _buildAudioSubtitles();

      case 'Reactions':
        if (!customization.showReactions) {
          return const SizedBox.shrink();
        }
        return _buildReactions();

      case 'Information':
        if (!customization.showInformation) {
          return const SizedBox.shrink();
        }
        return _buildInformation();

      case 'Library':
        if (!customization.showLibrary) {
          return const SizedBox.shrink();
        }
        return _buildLibrary();

      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // TV SHOW DETECTION
  // ===========================================================================

  bool get isTvShow {
    final type = media.type.toLowerCase().trim();

    return type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show';
  }

  // ===========================================================================
  // SEASONS / EPISODES
  // ===========================================================================

  List<Map<String, dynamic>> get seasons {
    return media.seasons
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _orderedSeasons() {
    final result = List<Map<String, dynamic>>.from(seasons);

    if (customization.seasonOrder == 'Bottom to Top') {
      return result.reversed.toList();
    }

    return result;
  }

  List<Map<String, dynamic>> _episodesForSeason(
    Map<String, dynamic> season,
  ) {
    final raw = season['episodes'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(
          Map<String, dynamic>.from(item),
        );
      }
    }

    return result;
  }

  Widget _buildSeasonsSection() {
    final orderedSeasons = _orderedSeasons();

    if (orderedSeasons.isEmpty) {
      return const SizedBox.shrink();
    }

    if (selectedSeasonIndex >= orderedSeasons.length) {
      selectedSeasonIndex = 0;
    }

    final selectedSeason = orderedSeasons[selectedSeasonIndex];

    final episodes = _episodesForSeason(selectedSeason);

    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 30,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          18,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seasons',
              textAlign: _textAlignment(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _buildSeasonSelector(
              orderedSeasons,
            ),
            const SizedBox(height: 20),
            Text(
              _seasonTitle(selectedSeason),
              textAlign: _textAlignment(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (episodes.isEmpty)
              _buildNoEpisodes()
            else
              _buildEpisodes(
                episodes,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonSelector(
    List<Map<String, dynamic>> orderedSeasons,
  ) {
    if (customization.seasonSelectorStyle == 'Dropdown') {
      return Align(
        alignment: _seasonAlignment(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DropdownButtonFormField<int>(
            initialValue: selectedSeasonIndex,
            decoration: const InputDecoration(
              labelText: 'Season',
            ),
            items: List.generate(
              orderedSeasons.length,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Text(
                  _seasonTitle(orderedSeasons[index]),
                ),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedSeasonIndex = value;
                });
              }
            },
          ),
        ),
      );
    }

    return Align(
      alignment: _seasonAlignment(),
      child: Wrap(
        alignment: _seasonWrapAlignment(),
        spacing: 9,
        runSpacing: 9,
        children: List.generate(
          orderedSeasons.length,
          (index) {
            final season = orderedSeasons[index];
            final selected = index == selectedSeasonIndex;

            return _SeasonButton(
              label: _seasonTitle(season),
              selected: selected,
              onTap: () {
                setState(() {
                  selectedSeasonIndex = index;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEpisodes(
    List<Map<String, dynamic>> episodes,
  ) {
    final orderedEpisodes = List<Map<String, dynamic>>.from(
      episodes,
    );

    return Column(
      children: List.generate(
        orderedEpisodes.length,
        (index) {
          final episode = orderedEpisodes[index];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == orderedEpisodes.length - 1
                  ? 0
                  : 10,
            ),
            child: _EpisodeCard(
              episode: episode,
              onPlay: () {
                _playEpisode(episode);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoEpisodes() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Text(
        'No episodes are available for this season yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),
    );
  }

  String _seasonTitle(
    Map<String, dynamic> season,
  ) {
    final name = season['name'] ??
        season['title'] ??
        season['seasonName'];

    if (name != null &&
        name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    final number = _integerValue(
          season['number'],
        ) ??
        _integerValue(
          season['seasonNumber'],
        );

    if (number != null) {
      return 'Season $number';
    }

    return 'Season';
  }

  int? _integerValue(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  Alignment _seasonAlignment() {
    switch (customization.seasonPlacement) {
      case 'Left':
        return Alignment.centerLeft;

      case 'Right':
        return Alignment.centerRight;

      case 'Center':
      default:
        return Alignment.center;
    }
  }

  WrapAlignment _seasonWrapAlignment() {
    switch (customization.seasonPlacement) {
      case 'Left':
        return WrapAlignment.start;

      case 'Right':
        return WrapAlignment.end;

      case 'Center':
      default:
        return WrapAlignment.center;
    }
  }

  void _playEpisode(
    Map<String, dynamic> episode,
  ) {
    final episodeMedia = _mediaFromEpisode(episode);

    if (episodeMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This episode does not contain enough information to play.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return PlayerScreen(
            media: episodeMedia,
          );
        },
      ),
    );
  }

  MediaItem? _mediaFromEpisode(
    Map<String, dynamic> episode,
  ) {
    final id = episode['id']?.toString();

    final title = episode['title']?.toString() ??
        episode['name']?.toString();

    if (id == null ||
        id.trim().isEmpty ||
        title == null ||
        title.trim().isEmpty) {
      return null;
    }

    final imageUrl = episode['imageUrl']?.toString() ??
        episode['posterUrl']?.toString();

    final description =
        episode['description']?.toString();

    final year = _integerValue(
      episode['releaseYear'] ?? episode['year'],
    );

    double? rating;

    final rawRating = episode['rating'];

    if (rawRating is num) {
      rating = rawRating.toDouble();
    } else if (rawRating != null) {
      rating = double.tryParse(
        rawRating.toString(),
      );
    }

    final trailerUrl =
        episode['trailerUrl']?.toString();

    final ratingReason =
        episode['ratingReason']?.toString();

    return MediaItem(
      id: id,
      title: title,
      type: 'episode',
      imageUrl: imageUrl,
      description: description,
      releaseYear: year,
      rating: rating,
      ratingReason: ratingReason,
      trailerUrl: trailerUrl,
    );
  }

  // ===========================================================================
  // POSTER
  // ===========================================================================

  Widget _buildPoster() {
    switch (customization.posterStyle) {
      case 'Full Screen':
        return _buildFullScreenPoster();

      case 'Compact':
        return _buildCompactPoster();

      case 'Side':
        return _buildSidePoster();

      case 'Standard':
      default:
        return _buildStandardPoster();
    }
  }

  Widget _buildStandardPoster() {
    final width = customization.posterSize == 'Small'
        ? 220.0
        : customization.posterSize == 'Large'
            ? 390.0
            : 300.0;

    final alignment = customization.posterPosition == 'Left'
        ? Alignment.centerLeft
        : customization.posterPosition == 'Right'
            ? Alignment.centerRight
            : Alignment.center;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: _posterImage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenPoster() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .62,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _posterImage(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .15),
                      Colors.black.withValues(alpha: .90),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Text(
                  media.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPoster() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SizedBox(
          width: 210,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _posterImage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePoster() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _posterImage(),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _buildSidePosterInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePosterInfo() {
    final alignment = _textAlignment();

    return Column(
      crossAxisAlignment: _crossAxisAlignment(),
      children: [
        Text(
          media.title,
          textAlign: alignment,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        _buildSmallMetadata(),
      ],
    );
  }

  Widget _posterImage() {
    final url = media.imageUrl;

    if (url == null || url.trim().isEmpty) {
      return _posterPlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return _posterPlaceholder();
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            _posterPlaceholder(),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        );
      },
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF171717),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white30,
          size: 70,
        ),
      ),
    );
  }

  // ===========================================================================
  // TITLE
  // ===========================================================================

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        media.title,
        textAlign: _textAlignment(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
      ),
    );
  }

  // ===========================================================================
  // METADATA
  // ===========================================================================

  Widget _buildMetadata() {
    final pills = <Widget>[];

    if (customization.showReleaseYear &&
        media.releaseYear != null) {
      pills.add(
        _metadataPill(
          Icons.calendar_today_outlined,
          media.releaseYear.toString(),
        ),
      );
    }

    if (customization.showRating &&
        media.rating != null) {
      pills.add(
        _metadataPill(
          Icons.star_rounded,
          media.rating!.toStringAsFixed(1),
        ),
      );
    }

    if (customization.showContentRating &&
        contentRating != null) {
      pills.add(
        _metadataPill(
          Icons.shield_outlined,
          contentRating!,
        ),
      );
    }

    if (customization.showRuntime &&
        runtime != null) {
      pills.add(
        _metadataPill(
          Icons.schedule_outlined,
          runtime!,
        ),
      );
    }

    if (pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Wrap(
        alignment: _wrapAlignment(),
        spacing: 8,
        runSpacing: 8,
        children: pills,
      ),
    );
  }

  Widget _buildSmallMetadata() {
    final items = <String>[];

    if (customization.showReleaseYear &&
        media.releaseYear != null) {
      items.add(
        media.releaseYear.toString(),
      );
    }

    if (customization.showRating &&
        media.rating != null) {
      items.add(
        '★ ${media.rating!.toStringAsFixed(1)}',
      );
    }

    if (customization.showContentRating &&
        contentRating != null) {
      items.add(contentRating!);
    }

    if (customization.showRuntime &&
        runtime != null) {
      items.add(runtime!);
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      items.join(' • '),
      textAlign: _textAlignment(),
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 13,
        height: 1.4,
      ),
    );
  }

  Widget _metadataPill(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OWNERSHIP
  // ===========================================================================

  Widget _buildOwnership() {
    final controller = AppController.instance;
    final owned = controller.isOwned(media.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              owned
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: owned
                  ? Colors.greenAccent
                  : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                owned
                    ? 'This title is in your library.'
                    : 'This title is not in your library.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DESCRIPTION
  // ===========================================================================

  Widget _buildDescription() {
    final description = media.description;

    if (description == null ||
        description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        description,
        textAlign: _textAlignment(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
  }

  // ===========================================================================
  // PLAY
  // ===========================================================================

  Alignment _buttonAlignment() {
    switch (customization.buttonAlignment) {
      case 'Center':
        return Alignment.center;

      case 'Right':
        return Alignment.centerRight;

      case 'Left':
      default:
        return Alignment.centerLeft;
    }
  }

  Widget _buildPlay() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: _buttonAlignment(),
        child: SizedBox(
          width: 420,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: pressedPlay ? null : playMedia,
            icon: const Icon(
              Icons.play_arrow_rounded,
            ),
            label: const Text(
              'Play',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TRAILER
  // ===========================================================================

  Widget _buildTrailer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: pressedTrailer ? null : watchTrailer,
          icon: const Icon(
            Icons.ondemand_video_outlined,
          ),
          label: const Text(
            'Watch Trailer',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // GROUP WATCH
  // ===========================================================================

  Widget _buildGroupWatch() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: startGroupWatch,
          icon: const Icon(
            Icons.groups_outlined,
          ),
          label: const Text(
            'Watch Together',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // AUDIO / SUBTITLES
  // ===========================================================================

  Widget _buildAudioSubtitles() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _openAudioSubtitleOptions,
          icon: const Icon(
            Icons.closed_caption_outlined,
          ),
          label: const Text(
            'Audio & Subtitles',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _openAudioSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      builder: (_) {
        return AudioSubtitleOptions(
          selectedAudio: selectedAudio,
          subtitlesEnabled: subtitlesEnabled,
          selectedSubtitle: selectedSubtitle,
          onAudioChanged: (value) {
            setState(() {
              selectedAudio = value;
            });
          },
          onSubtitleChanged: (value) {
            setState(() {
              selectedSubtitle = value;
              subtitlesEnabled = value != null;
            });
          },
        );
      },
    );
  }

  // ===========================================================================
  // REACTIONS
  // ===========================================================================

  Widget _buildReactions() {
    final controller = AppController.instance;

    final liked = controller.isLiked(media.id);
    final disliked = controller.isDisliked(media.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  if (liked) {
                    controller.clearReaction(
                      media.id,
                    );
                  } else {
                    controller.likeMedia(
                      media,
                    );
                  }
                });
              },
              icon: Icon(
                liked
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_up_outlined,
              ),
              label: const Text('Like'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  if (disliked) {
                    controller.clearReaction(
                      media.id,
                    );
                  } else {
                    controller.dislikeMedia(
                      media,
                    );
                  }
                });
              },
              icon: Icon(
                disliked
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
              ),
              label: const Text('Dislike'),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INFORMATION
  // ===========================================================================

  Widget _buildInformation() {
    final rows = <Widget>[];

    if (customization.showReleaseYear &&
        media.releaseYear != null) {
      rows.add(
        _infoRow(
          'Release Year',
          media.releaseYear.toString(),
        ),
      );
    }

    if (customization.showRating &&
        media.rating != null) {
      rows.add(
        _infoRow(
          'Rating',
          media.rating!.toStringAsFixed(1),
        ),
      );

      if (media.ratingReason != null &&
          media.ratingReason!.trim().isNotEmpty) {
        rows.add(
          _infoRow(
            'Why this rating',
            media.ratingReason!,
          ),
        );
      }
    }

    if (customization.showContentRating &&
        contentRating != null) {
      rows.add(
        _infoRow(
          'Content Rating',
          contentRating!,
        ),
      );
    }

    if (customization.showRuntime &&
        runtime != null) {
      rows.add(
        _infoRow(
          'Runtime',
          runtime!,
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Information',
              textAlign: _informationTextAlign(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIBRARY
  // ===========================================================================

  Widget _buildLibrary() {
    final controller = AppController.instance;
    final owned = controller.isOwned(media.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              if (owned) {
                controller.removeFromLibrary(
                  media.id,
                );
              } else {
                controller.addToLibrary(
                  media,
                );
              }
            });
          },
          icon: Icon(
            owned
                ? Icons.remove_circle_outline
                : Icons.add_circle_outline,
          ),
          label: Text(
            owned
                ? 'Remove from Library'
                : 'Add to Library',
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void playMedia() {
    setState(() {
      pressedPlay = true;
    });

    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) {
          return PlayerScreen(
            media: media,
          );
        },
        transitionsBuilder: (
          _,
          animation,
          __,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          pressedPlay = false;
        });
      }
    });
  }

  void startGroupWatch() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Watch Together'),
        content: const Text(
          'Who do you want to watch with?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchGroupWatch();
            },
            child: const Text(
              'People in this account',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareGroupWatch();
            },
            icon: const Icon(
              Icons.share_outlined,
            ),
            label: const Text(
              'Other people',
            ),
          ),
        ],
      ),
    );
  }

  void _launchGroupWatch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupWatchScreen(
          media: media,
        ),
      ),
    );
  }

  void _shareGroupWatch() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Invite with…',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              for (final app in [
                'Messenger',
                'WhatsApp',
                'Telegram',
                'Instagram',
                'iMessage',
              ])
                ActionChip(
                  label: Text(app),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Group Watch invite ready for $app.',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void watchTrailer() {
    final url = media.trailerUrl;

    if (url == null || url.trim().isEmpty) {
      return;
    }

    setState(() {
      pressedTrailer = true;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) {
          return TrailerPlayerScreen(
            trailerUrl: url,
            title: '${media.title} Trailer',
          );
        },
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          pressedTrailer = false;
        });
      }
    });
  }

  // ===========================================================================
  // ALIGNMENT
  // ===========================================================================

  TextAlign _textAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return TextAlign.center;

      case 'Right':
        return TextAlign.right;

      case 'Left':
      default:
        return TextAlign.left;
    }
  }

  CrossAxisAlignment _crossAxisAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return CrossAxisAlignment.center;

      case 'Right':
        return CrossAxisAlignment.end;

      case 'Left':
      default:
        return CrossAxisAlignment.start;
    }
  }

  TextAlign _informationTextAlign() {
    switch (customization.informationAlignment) {
      case 'Center':
        return TextAlign.center;

      case 'Right':
        return TextAlign.right;

      case 'Left':
      default:
        return TextAlign.left;
    }
  }

  WrapAlignment _wrapAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return WrapAlignment.center;

      case 'Right':
        return WrapAlignment.end;

      case 'Left':
      default:
        return WrapAlignment.start;
    }
  }

  // ===========================================================================
  // MEDIA METADATA
  // ===========================================================================

  Map<String, dynamic> get mediaJson {
    try {
      return media.toJson();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? firstMetadataValue(
    List<String> keys,
  ) {
    final json = mediaJson;

    for (final key in keys) {
      final value = json[key];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  String? get contentRating {
    return firstMetadataValue([
      'contentRating',
      'content_rating',
      'ratingCode',
      'ageRating',
      'certificate',
      'certification',
    ]);
  }

  String? get runtime {
    final value = firstMetadataValue([
      'runtime',
      'runtimeMinutes',
      'duration',
      'durationMinutes',
    ]);

    if (value == null) {
      return null;
    }

    final minutes = int.tryParse(value);

    if (minutes == null) {
      return value;
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  bool get hasTrailer {
    final url = media.trailerUrl;

    return url != null && url.trim().isNotEmpty;
  }
}

// =============================================================================
// SEASON BUTTON
// =============================================================================

class _SeasonButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SeasonButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? Colors.white
              : Colors.white.withValues(
                  alpha: .045,
                ),
          foregroundColor: selected
              ? Colors.black
              : Colors.white,
          side: BorderSide(
            color: selected
                ? Colors.white
                : Colors.white.withValues(
                    alpha: .12,
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EPISODE CARD
// =============================================================================

class _EpisodeCard extends StatefulWidget {
  final Map<String, dynamic> episode;
  final VoidCallback onPlay;

  const _EpisodeCard({
    required this.episode,
    required this.onPlay,
  });

  @override
  State<_EpisodeCard> createState() =>
      _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool hovering = false;

  String get title {
    return widget.episode['title']?.toString() ??
        widget.episode['name']?.toString() ??
        'Episode';
  }

  String? get description {
    final value =
        widget.episode['description']?.toString();

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  String? get imageUrl {
    final value =
        widget.episode['imageUrl']?.toString() ??
            widget.episode['posterUrl']?.toString();

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  String? get episodeNumber {
    final number =
        widget.episode['number'] ??
            widget.episode['episodeNumber'];

    if (number == null) {
      return null;
    }

    return number.toString();
  }

  String? get runtime {
    final value =
        widget.episode['runtime'] ??
            widget.episode['runtimeMinutes'] ??
            widget.episode['duration'];

    if (value == null) {
      return null;
    }

    final minutes = int.tryParse(
      value.toString(),
    );

    if (minutes == null) {
      return value.toString();
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  bool _showEpisodeLabel() {
    final mode =
        DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    ).episodeNaming;

    return mode != 'Actual Title';
  }

  String _episodeLabel() {
    final seasonNumber =
        widget.episode['seasonNumber'] ??
            widget.episode['season'];

    final n = episodeNumber;

    switch (
        DetailsCustomizationStore.settingsFor(
          AppController.instance.currentProfile,
        ).episodeNaming) {
      case 'Season X, Episode Y':
        return 'SEASON ${seasonNumber ?? '?'} • EPISODE ${n ?? '?'}';

      case 'Both':
        return 'S${seasonNumber ?? '?'}E${n ?? '?'}';

      case 'Actual Title':
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hovering
                ? Colors.white.withValues(
                    alpha: .075,
                  )
                : Colors.white.withValues(
                    alpha: .035,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering
                  ? Colors.white.withValues(
                      alpha: .15,
                    )
                  : Colors.white.withValues(
                      alpha: .06,
                    ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                height: 85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: imageUrl == null
                      ? Container(
                          color: const Color(0xFF202020),
                          child: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white38,
                            size: 34,
                          ),
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: const Color(0xFF202020),
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white38,
                                size: 34,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (_showEpisodeLabel())
                      Text(
                        _episodeLabel(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (runtime != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        runtime!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: hovering ? .16 : .09,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TRAILER PLAYER
// =============================================================================

class TrailerPlayerScreen extends StatefulWidget {
  final String trailerUrl;
  final String title;

  const TrailerPlayerScreen({
    super.key,
    required this.trailerUrl,
    required this.title,
  });

  @override
  State<TrailerPlayerScreen> createState() =>
      _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState
    extends State<TrailerPlayerScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();

    final videoId =
        YoutubePlayerController.convertUrlToId(
      widget.trailerUrl,
    );

    if (videoId != null && videoId.isNotEmpty) {
      _controller =
          YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _controller == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to play this trailer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              )
            : YoutubePlayer(
                controller: _controller!,
                aspectRatio: 16 / 9,
              ),
      ),
    );
  }
}