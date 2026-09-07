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
  State<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  bool pressedPlay = false;
  bool pressedTrailer = false;
  bool pressedLike = false;
  bool pressedDislike = false;

  MediaItem get media => widget.media;

  void playMedia(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => PlayerScreen(
          media: media,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void startGroupWatch(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => GroupWatchScreen(
          media: media,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: .97,
                end: 1,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void watchTrailer(BuildContext context) {
    final trailerUrl = media.trailerUrl?.trim();

    if (trailerUrl == null || trailerUrl.isEmpty) {
      return;
    }

    String? videoId;

    try {
      final uri = Uri.parse(trailerUrl);

      if (uri.host.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];

        if (videoId == null &&
            uri.pathSegments.length >= 2 &&
            uri.pathSegments.first == 'shorts') {
          videoId = uri.pathSegments[1];
        }

        if (videoId == null &&
            uri.pathSegments.length >= 2 &&
            uri.pathSegments.first == 'embed') {
          videoId = uri.pathSegments[1];
        }
      }

      if (videoId == null && uri.host == 'youtu.be') {
        if (uri.pathSegments.isNotEmpty) {
          videoId = uri.pathSegments.first;
        }
      }
    } catch (_) {
      videoId = null;
    }

    if (videoId == null || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The YouTube trailer URL is invalid.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) => TrailerPlayerScreen(
          title: media.title,
          videoId: videoId!,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void toggleLike(BuildContext context) {
    final controller = AppController.instance;

    if (controller.isLiked(media.id)) {
      controller.clearReaction(media.id);
    } else {
      controller.likeMedia(media);
    }

    setState(() {});
  }

  void toggleDislike(BuildContext context) {
    final controller = AppController.instance;

    if (controller.isDisliked(media.id)) {
      controller.clearReaction(media.id);
    } else {
      controller.dislikeMedia(media);
    }

    setState(() {});
  }

  String getMediaTypeName() {
    final value = media.type.trim().toLowerCase();

    switch (value) {
      case 'movie':
        return 'Movie';

      case 'series':
      case 'tv':
      case 'show':
      case 'tvshow':
      case 'tv_show':
      case 'tv show':
        return 'TV Show';

      case 'episode':
        return 'Episode';

      case 'special':
        return 'Special';

      case 'documentary':
        return 'Documentary';

      default:
        if (value.isEmpty) {
          return 'Title';
        }

        return value[0].toUpperCase() + value.substring(1);
    }
  }

  bool get hasTrailer {
    return media.trailerUrl != null &&
        media.trailerUrl!.trim().isNotEmpty;
  }

  Widget buildHeroImage() {
    final imageUrl = media.imageUrl?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return buildHeroPlaceholder();
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return buildHeroPlaceholder();
      },
    );
  }

  Widget buildHeroPlaceholder() {
    return Container(
      color: const Color(0xFF151515),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 100,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget buildPoster() {
    final imageUrl = media.imageUrl?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return buildPosterPlaceholder();
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 420,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return buildPosterPlaceholder();
      },
    );
  }

  Widget buildPosterPlaceholder() {
    return Container(
      width: double.infinity,
      height: 420,
      color: const Color(0xFF151515),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.grey.shade700,
          size: 80,
        ),
      ),
    );
  }

  Widget buildRating() {
    if (media.rating == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          color: Colors.amber,
          size: 19,
        ),
        const SizedBox(width: 5),
        Text(
          media.rating!.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget buildMetadataPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: .08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade200,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOwnershipMessage(bool owned) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: owned
            ? Colors.green.withValues(alpha: .08)
            : Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: owned
              ? Colors.green.withValues(alpha: .25)
              : Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: owned
                  ? Colors.green.withValues(alpha: .14)
                  : Colors.white.withValues(alpha: .07),
            ),
            child: Icon(
              owned
                  ? Icons.check_rounded
                  : Icons.info_outline_rounded,
              color: owned
                  ? Colors.greenAccent
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owned
                      ? 'In your library'
                      : 'Not in your library',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  owned
                      ? 'This title is available to watch.'
                      : 'This title is not currently part of your collection.',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: .14),
          ),
          backgroundColor:
              Colors.white.withValues(alpha: .045),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget buildGroupWatchButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => startGroupWatch(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF171717),
          side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: .42),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(
          Icons.groups_rounded,
        ),
        label: const Text(
          'GROUP WATCH',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget buildReactionButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: .12)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .45)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                      : Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInfoRow(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w500,
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

  Widget buildSectionTitle(
    String title, {
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget buildActionButtons({
    required bool owned,
    required bool hasTrailer,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (owned)
          buildPrimaryButton(
            icon: Icons.play_arrow_rounded,
            label: 'WATCH NOW',
            onPressed: () => playMedia(context),
          ),

        if (owned) ...[
          const SizedBox(height: 10),
          buildGroupWatchButton(),
        ],

        if (owned && hasTrailer)
          const SizedBox(height: 10),

        if (hasTrailer)
          buildSecondaryButton(
            icon: Icons.ondemand_video_rounded,
            label: 'WATCH TRAILER',
            onPressed: () => watchTrailer(context),
          ),

        if (!owned)
          buildPrimaryButton(
            icon: Icons.library_add_rounded,
            label: 'ADD TO LIBRARY',
            onPressed: () {
              final controller =
                  AppController.instance;

              controller.addToLibrary(media);

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Added to your library.',
                  ),
                ),
              );

              setState(() {});
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    final owned = controller.isOwned(media.id);
    final liked = controller.isLiked(media.id);
    final disliked =
        controller.isDisliked(media.id);

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 570,
            backgroundColor: const Color(0xFF070707),
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: AnimatedOpacity(
              duration:
                  const Duration(milliseconds: 200),
              opacity: 1,
              child: Text(
                media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode:
                  CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildHeroImage(),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:
                              Alignment.topCenter,
                          end:
                              Alignment.center,
                          colors: [
                            Colors.black.withValues(
                              alpha: .72,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin:
                              Alignment.center,
                          end:
                              Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: .15,
                            ),
                            const Color(0xFF070707),
                          ],
                          stops: const [
                            0,
                            .55,
                            1,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 30,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: 1,
                      ),
                      duration:
                          const Duration(milliseconds: 650),
                      curve:
                          Curves.easeOutCubic,
                      builder:
                          (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child:
                              Transform.translate(
                            offset: Offset(
                              0,
                              24 * (1 - value),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            media.title,
                            maxLines: 3,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 38,
                              height: 1.02,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: -1,
                              shadows: [
                                Shadow(
                                  blurRadius: 18,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 13),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              if (media.releaseYear !=
                                  null)
                                buildMetadataPill(
                                  icon: Icons
                                      .calendar_today_outlined,
                                  text: media
                                      .releaseYear!
                                      .toString(),
                                ),
                              buildMetadataPill(
                                icon: media.type
                                            .toLowerCase() ==
                                        'movie'
                                    ? Icons
                                        .movie_outlined
                                    : Icons
                                        .tv_outlined,
                                text:
                                    getMediaTypeName(),
                              ),
                              if (media.rating != null)
                                buildMetadataPill(
                                  icon:
                                      Icons.star_rounded,
                                  text: media.rating!
                                      .toStringAsFixed(
                                    1,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              50,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: 1,
                    ),
                    duration:
                        const Duration(milliseconds: 500),
                    curve:
                        Curves.easeOutCubic,
                    builder:
                        (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            15 * (1 - value),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        buildOwnershipMessage(
                          owned,
                        ),

                        const SizedBox(height: 18),

                        buildActionButtons(
                          owned: owned,
                          hasTrailer: hasTrailer,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            buildReactionButton(
                              icon: liked
                                  ? Icons.thumb_up_rounded
                                  : Icons
                                      .thumb_up_outlined,
                              label: 'Like',
                              selected: liked,
                              onPressed: () =>
                                  toggleLike(context),
                            ),
                            const SizedBox(width: 10),
                            buildReactionButton(
                              icon: disliked
                                  ? Icons
                                      .thumb_down_rounded
                                  : Icons
                                      .thumb_down_outlined,
                              label: 'Dislike',
                              selected: disliked,
                              onPressed: () =>
                                  toggleDislike(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (media.description != null &&
                      media.description!
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(height: 32),
                    buildSectionTitle(
                      'About this title',
                      icon:
                          Icons.description_outlined,
                    ),
                    const SizedBox(height: 13),
                    Text(
                      media.description!,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                  ],

                  const SizedBox(height: 34),

                  if (!owned)
                    Container(
                      padding:
                          const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: .035),
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: .07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons
                                    .library_add_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Build your library',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'Add this title to your personal collection when it becomes available through your media collection.',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade400,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (owned) ...[
                    const SizedBox(height: 30),
                    Container(
                      padding:
                          const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: .035),
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: .07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          buildSectionTitle(
                            'Library',
                            icon: Icons
                                .video_library_outlined,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'This title is part of your personal media collection.',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                controller
                                    .removeFromLibrary(
                                  media.id,
                                );

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Removed from your library.',
                                    ),
                                  ),
                                );

                                setState(() {});
                              },
                              icon: const Icon(
                                Icons
                                    .remove_circle_outline,
                              ),
                              label: const Text(
                                'REMOVE FROM LIBRARY',
                              ),
                              style: OutlinedButton
                                  .styleFrom(
                                foregroundColor:
                                    Colors.grey.shade300,
                                side: BorderSide(
                                  color: Colors.white
                                      .withValues(
                                    alpha: .12,
                                  ),
                                ),
                                minimumSize:
                                    const Size(
                                  double.infinity,
                                  48,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 34),

                  buildSectionTitle(
                    'Title information',
                    icon: Icons.info_outline_rounded,
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: .025),
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: .06),
                      ),
                    ),
                    child: Column(
                      children: [
                        buildInfoRow(
                          'Title',
                          media.title,
                        ),
                        buildInfoRow(
                          'Type',
                          getMediaTypeName(),
                        ),
                        if (media.releaseYear !=
                            null)
                          buildInfoRow(
                            'Release Year',
                            media.releaseYear!
                                .toString(),
                          ),
                        if (media.rating != null)
                          buildInfoRow(
                            'Rating',
                            media.rating!
                                .toStringAsFixed(1),
                          ),
                        if (hasTrailer)
                          buildInfoRow(
                            'Trailer',
                            'YouTube',
                          ),
                        buildInfoRow(
                          'Library',
                          owned
                              ? 'Owned'
                              : 'Not owned',
                        ),
                      ],
                    ),
                  ),

                  if (owned) ...[
                    const SizedBox(height: 34),
                    buildPrimaryButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'WATCH NOW',
                      onPressed: () =>
                          playMedia(context),
                    ),
                    const SizedBox(height: 10),
                    buildGroupWatchButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrailerPlayerScreen extends StatefulWidget {
  final String title;
  final String videoId;

  const TrailerPlayerScreen({
    super.key,
    required this.title,
    required this.videoId,
  });

  @override
  State<TrailerPlayerScreen> createState() =>
      _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState
    extends State<TrailerPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.title} Trailer',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }
}