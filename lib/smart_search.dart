// FILE: `lib/smart_search.dart`.
// Purpose: Implements the smart search portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class SmartSearch {
  static List<MediaItem> search(
    String query,
    List<MediaItem> library,
  ) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return [];
    }

    return library.where((media) {
      final title = media.title.toLowerCase();
      final description = (media.description ?? '').toLowerCase();
      final type = media.type.toLowerCase();
      final year = media.releaseYear.toString();
      final rating = media.rating.toString();

      final matchesTitle = title.contains(q);
      final matchesDescription = description.contains(q);
      final matchesType = type.contains(q);
      final matchesYear = year == q;
      final matchesRating = rating == q;

      bool matchesFriendlyType = false;

      if (q == 'movie' || q == 'movies') {
        matchesFriendlyType =
            type == 'movie' || type == 'movies';
      }

      if (q == 'tv' ||
          q == 'tv show' ||
          q == 'tv shows' ||
          q == 'series' ||
          q == 'show' ||
          q == 'shows') {
        matchesFriendlyType =
            type == 'tvshow' ||
            type == 'tv_show' ||
            type == 'tv show';
      }

      return matchesTitle ||
          matchesDescription ||
          matchesType ||
          matchesYear ||
          matchesRating ||
          matchesFriendlyType;
    }).toList();
  }
}

class SmartSearchScreen extends StatefulWidget {
  const SmartSearchScreen({super.key});

  @override
  State<SmartSearchScreen> createState() =>
      _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller =
      TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  List<MediaItem> results = [];

  late AnimationController animationController;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    searchFocusNode.addListener(_focusChanged);

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    animationController.forward();
  }

  /// Performs `_focusChanged` for this feature. Update this documentation when its contract changes.
  void _focusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    controller.dispose();
    searchFocusNode
      ..removeListener(_focusChanged)
      ..dispose();
    animationController.dispose();
    super.dispose();
  }

  /// Performs `performSearch` for this feature. Update this documentation when its contract changes.
  void performSearch([String? value]) {
    final query = value ?? controller.text;

    final library = AppController.instance.library;

    setState(() {
      results = SmartSearch.search(
        query,
        library,
      );
    });

    animationController
      ..reset()
      ..forward();
  }

  /// Performs `clearSearch` for this feature. Update this documentation when its contract changes.
  void clearSearch() {
    controller.clear();

    setState(() {
      results = [];
    });

    searchFocusNode.requestFocus();
  }

  /// Performs `useSuggestion` for this feature. Update this documentation when its contract changes.
  void useSuggestion(String suggestion) {
    controller.text = suggestion;

    controller.selection = TextSelection.fromPosition(
      TextPosition(
        offset: controller.text.length,
      ),
    );

    performSearch(suggestion);
  }

  /// Performs `_typeLabel` for this feature. Update this documentation when its contract changes.
  String _typeLabel(MediaItem media) {
    final type = media.type.toLowerCase();
    if (type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show') {
      return 'TV SHOW';
    }

    return 'MOVIE';
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          const _SearchBackground(),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= 900;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          isDesktop ? 1100 : 700,
                    ),
                    child: CustomScrollView(
                      physics:
                          const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildHeader(theme),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSearchBar(theme),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSuggestions(),
                        ),
                        SliverToBoxAdapter(
                          child: _buildResultsHeader(),
                        ),
                        _buildResultsList(isDesktop),
                        const SliverPadding(
                          padding:
                              EdgeInsets.only(bottom: 50),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_buildHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildHeader(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            24,
            22,
            18,
          ),
          child: Row(
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () =>
                    Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style:
                          theme.textTheme.headlineMedium
                              ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Find something to watch',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: 0.52),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_buildSearchBar` for this feature. Update this documentation when its contract changes.
  Widget _buildSearchBar(ThemeData theme) {
    final focused = searchFocusNode.hasFocus;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 22),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.075),
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: focused
                    ? Colors.white
                        .withValues(alpha: 0.28)
                    : Colors.white
                        .withValues(alpha: 0.11),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: searchFocusNode,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.white,
              textInputAction:
                  TextInputAction.search,
              onChanged: performSearch,
              onSubmitted: performSearch,
              decoration: InputDecoration(
                hintText:
                    'Search movies, shows, years...',
                hintStyle: TextStyle(
                  color: Colors.white
                      .withValues(alpha: 0.38),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white
                      .withValues(alpha: 0.65),
                  size: 25,
                ),
                suffixIcon:
                    controller.text.isNotEmpty
                        ? IconButton(
                            onPressed: clearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          )
                        : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 19,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Performs `_buildSuggestions` for this feature. Update this documentation when its contract changes.
  Widget _buildSuggestions() {
    if (controller.text.isNotEmpty) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        18,
        22,
        4,
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          _SuggestionChip(
            label: 'Movies',
            icon: Icons.movie_outlined,
            onTap: () =>
                useSuggestion('movies'),
          ),
          _SuggestionChip(
            label: 'TV Shows',
            icon: Icons.tv_outlined,
            onTap: () =>
                useSuggestion('tv shows'),
          ),
          _SuggestionChip(
            label: '2024',
            icon: Icons.calendar_today_outlined,
            onTap: () =>
                useSuggestion('2024'),
          ),
        ],
      ),
    );
  }

  /// Performs `_buildResultsHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildResultsHeader() {
    if (controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        12,
      ),
      child: Row(
        children: [
          Text(
            results.isEmpty
                ? 'No results'
                : '${results.length} ${results.length == 1 ? 'result' : 'results'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (results.isNotEmpty)
            Text(
              'YOUR LIBRARY',
              style: TextStyle(
                color: Colors.white
                    .withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  /// Performs `_buildResultsList` for this feature. Update this documentation when its contract changes.
  Widget _buildResultsList(bool isDesktop) {
    if (controller.text.trim().isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            80,
            22,
            40,
          ),
          child: const _EmptySearchState(
            icon: Icons.search_rounded,
            title: 'Search your library',
            message:
                'Look through your ripped movies and TV shows by title, type, year, or rating.',
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            55,
            22,
            40,
          ),
          child: const _EmptySearchState(
            icon: Icons.movie_filter_outlined,
            title: 'Nothing found',
            message:
                'Try another title, year, rating, movie, or TV show.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final media = results[index];

            return _SearchResultCard(
              key: ValueKey(
                '${media.title}_${media.releaseYear}_$index',
              ),
              media: media,
              typeLabel: _typeLabel(media),
              index: index,
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration:
                        const Duration(
                      milliseconds: 450,
                    ),
                    reverseTransitionDuration:
                        const Duration(
                      milliseconds: 300,
                    ),
                    pageBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                    ) =>
                        MediaDetailsScreen(
                      media: media,
                    ),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      final curved =
                          CurvedAnimation(
                        parent: animation,
                        curve:
                            Curves.easeOutCubic,
                      );

                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                            begin:
                                const Offset(
                              0.04,
                              0,
                            ),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
          childCount: results.length,
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final MediaItem media;
  final String typeLabel;
  final int index;
  final VoidCallback onTap;

  const _SearchResultCard({
    super.key,
    required this.media,
    required this.typeLabel,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SearchResultCard> createState() =>
      _SearchResultCardState();
}

class _SearchResultCardState
    extends State<_SearchResultCard> {
  bool hovering = false;

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final media = widget.media;

    return TweenAnimationBuilder<double>(
      duration: Duration(
        milliseconds:
            350 + (widget.index * 55),
      ),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (
        context,
        value,
        child,
      ) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding:
            const EdgeInsets.only(bottom: 13),
        child: MouseRegion(
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
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translateByDouble(
                  hovering ? 3.0 : 0.0,
                  hovering ? -1.0 : 0.0,
                  0.0,
                  1.0,
                ),
              decoration: BoxDecoration(
                color: hovering
                    ? Colors.white
                        .withValues(alpha: 0.10)
                    : Colors.white
                        .withValues(alpha: 0.055),
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: hovering
                      ? Colors.white
                          .withValues(alpha: 0.20)
                      : Colors.white
                          .withValues(alpha: 0.075),
                ),
                boxShadow: hovering
                    ? [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 22,
                          offset:
                              const Offset(0, 9),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(9),
                child: Row(
                  children: [
                    _Poster(
                      media: media,
                      width: 105,
                      height: 145,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 5,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                _MetaPill(
                                  label:
                                      widget.typeLabel,
                                ),
                                _MetaPill(
                                  label: media
                                      .releaseYear
                                      .toString(),
                                ),
                                _MetaPill(
                                  label:
                                      '★ ${media.rating}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              media.description ?? '',
                              maxLines: 3,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.52,
                                ),
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 200,
                      ),
                      width: 35,
                      height: 35,
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha:
                              hovering
                                  ? 0.13
                                  : 0.055,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white
                            .withValues(
                          alpha:
                              hovering
                                  ? 0.9
                                  : 0.45,
                        ),
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final MediaItem media;
  final double width;
  final double height;

  const _Poster({
    required this.media,
    required this.width,
    required this.height,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final imageUrl = media.imageUrl ?? '';

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF171717),
              child: const Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
            ),

            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    color:
                        const Color(0xFF171717),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor:
                              AlwaysStoppedAnimation<
                                  Color>(
                            Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color:
                        const Color(0xFF171717),
                    child: const Center(
                      child: Icon(
                        Icons
                            .broken_image_outlined,
                        color: Colors.white30,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 65,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end: Alignment
                          .bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black
                            .withValues(
                          alpha: 0.7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({
    required this.label,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.075),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white
              .withValues(alpha: 0.68),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(13),
        onTap: onTap,
        child: Ink(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: 0.055),
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: Colors.white54,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(15),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: 0.07),
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: 0.10),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptySearchState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration:
              BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white
                .withValues(alpha: 0.055),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white
                .withValues(alpha: 0.42),
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 420,
          ),
          child: Text(
            message,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBackground
    extends StatelessWidget {
  const _SearchBackground();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            right: -130,
            child: Container(
              width: 430,
              height: 430,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(
                  alpha: 0.025,
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -230,
            child: Container(
              width: 460,
              height: 460,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(
                  alpha: 0.018,
                ),
              ),
            ),
          ),
          CustomPaint(
            size: Size.infinite,
            painter:
                _GridPainter(),
          ),
        ],
      ),
    );
  }
}

class _GridPainter
    extends CustomPainter {
  @override
  /// Performs `paint` for this feature. Update this documentation when its contract changes.
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.018)
      ..strokeWidth = 0.5;

    const spacing = 45.0;

    for (
      double x = 0;
      x < size.width;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (
      double y = 0;
      y < size.height;
      y += spacing
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  /// Performs `shouldRepaint` for this feature. Update this documentation when its contract changes.
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
