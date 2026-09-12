// FILE: `lib/movies.dart`.
// Purpose: Implements the movies portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageController;
  String _searchQuery = '';

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.forward();
      }
    });
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Performs `_openDetails` for this feature. Update this documentation when its contract changes.
  void _openDetails(BuildContext context, MediaItem movie) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return MediaDetailsScreen(
            media: movie,
          );
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.965,
                end: 1,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final library = AppController.instance.library;

    final movies = library
        .where(
          (media) => media.type.toLowerCase() == 'movie',
        )
        .toList();

    final filteredMovies = _searchQuery.trim().isEmpty
        ? movies
        : movies.where((movie) {
            return movie.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();

    final featuredMovie =
        filteredMovies.isNotEmpty ? filteredMovies.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          const _MoviesBackground(),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildTopBar(context, movies.length),
                ),

                if (_searchQuery.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSearchSummary(
                      filteredMovies.length,
                    ),
                  ),

                if (filteredMovies.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(
                      isSearching:
                          _searchQuery.trim().isNotEmpty,
                    ),
                  )
                else ...[
                  if (_searchQuery.trim().isEmpty &&
                      featuredMovie != null)
                    SliverToBoxAdapter(
                      child: _buildFeaturedMovie(
                        context,
                        featuredMovie,
                      ),
                    ),

                  if (_searchQuery.trim().isEmpty)
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(
                        title: 'Your Movies',
                        subtitle:
                            '${filteredMovies.length} titles',
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      42,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie =
                              filteredMovies[index];

                          return _MovieCard(
                            movie: movie,
                            index: index,
                            animation: _pageController,
                            onTap: () {
                              _openDetails(
                                context,
                                movie,
                              );
                            },
                          );
                        },
                        childCount: filteredMovies.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 235,
                        mainAxisExtent: 370,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  /// Performs `_buildTopBar` for this feature. Update this documentation when its contract changes.
  Widget _buildTopBar(
    BuildContext context,
    int movieCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12,
      ),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Movies',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.07,
                        ),
                        borderRadius:
                            BorderRadius.circular(7),
                      ),
                      child: Text(
                        '$movieCount',
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.65,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  movieCount == 0
                      ? 'Build your movie collection'
                      : 'Your cinematic collection',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.4,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          _GlassIconButton(
            icon: _searchQuery.isEmpty
                ? Icons.search_rounded
                : Icons.close_rounded,
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                setState(() {
                  _searchQuery = '';
                });
                return;
              }

              _showSearch(context);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  /// Performs `_showSearch` for this feature. Update this documentation when its contract changes.
  void _showSearch(BuildContext context) {
    final controller = TextEditingController(
      text: _searchQuery,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Search movies',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search your movie library...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.32,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(
                        alpha: 0.055,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SEARCH SUMMARY
  // ============================================================

  /// Performs `_buildSearchSummary` for this feature. Update this documentation when its contract changes.
  Widget _buildSearchSummary(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        10,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 15,
            color: Colors.white.withValues(
              alpha: 0.4,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count ${count == 1 ? 'result' : 'results'}',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.45,
              ),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FEATURED MOVIE
  // ============================================================

  /// Performs `_buildFeaturedMovie` for this feature. Update this documentation when its contract changes.
  Widget _buildFeaturedMovie(
    BuildContext context,
    MediaItem movie,
  ) {
    final imageUrl = (movie.imageUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        18,
      ),
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          final value = Curves.easeOutCubic.transform(
            _pageController.value,
          );

          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: () {
            _openDetails(context, movie);
          },
          child: Container(
            height: 285,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.38,
                  ),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const _FeaturedFallback();
                    },
                  )
                else
                  const _FeaturedFallback(),

                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [
                        0.0,
                        0.35,
                        0.72,
                        1.0,
                      ],
                      colors: [
                        Colors.black.withValues(
                          alpha: 0.18,
                        ),
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.7,
                        ),
                        Colors.black.withValues(
                          alpha: 0.96,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 19,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.11,
                              ),
                              borderRadius:
                                  BorderRadius.circular(7),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          if (movie.releaseYear != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${movie.releaseYear}',
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.65,
                                ),
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'View details',
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.72,
                              ),
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  /// Performs `_buildSectionHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        3,
        20,
        11,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.35,
                    ),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.movie_filter_outlined,
            size: 18,
            color: Colors.white.withValues(
              alpha: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  /// Performs `_buildEmptyState` for this feature. Update this documentation when its contract changes.
  Widget _buildEmptyState({
    required bool isSearching,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.045,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.movie_outlined,
                size: 44,
                color: Colors.white.withValues(
                  alpha: 0.48,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              isSearching
                  ? 'No movies found'
                  : 'Your movie library is empty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Try a different title or clear your search.'
                  : 'Use "Add Movie or Show" to import a movie '
                      'into your library.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.42,
                ),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MOVIE CARD
// ============================================================

class _MovieCard extends StatefulWidget {
  final MediaItem movie;
  final int index;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _MovieCard({
    required this.movie,
    required this.index,
    required this.animation,
    required this.onTap,
  });

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  bool hovering = false;
  bool pressed = false;

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final imageUrl = (movie.imageUrl ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final delayedStart =
            (widget.index * 0.045).clamp(0.0, 0.65);

        final raw = ((widget.animation.value -
                    delayedStart) /
                (1 - delayedStart))
            .clamp(0.0, 1.0);

        final entrance = Curves.easeOutCubic.transform(raw);

        return Opacity(
          opacity: entrance,
          child: Transform.translate(
            offset: Offset(
              0,
              22 * (1 - entrance),
            ),
            child: child,
          ),
        );
      },
      child: MouseRegion(
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
          onTapDown: (_) {
            setState(() {
              pressed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              pressed = false;
            });
          },
          onTap: () {
            setState(() {
              pressed = false;
            });

            widget.onTap();
          },
          child: AnimatedScale(
            scale: pressed
                ? 0.965
                : hovering
                    ? 1.025
                    : 1,
            duration: const Duration(
              milliseconds: 180,
            ),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 220,
              ),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: hovering
                      ? Colors.white.withValues(
                          alpha: 0.18,
                        )
                      : Colors.white.withValues(
                          alpha: 0.065,
                        ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: hovering ? 0.48 : 0.25,
                    ),
                    blurRadius:
                        hovering ? 28 : 12,
                    offset: Offset(
                      0,
                      hovering ? 14 : 7,
                    ),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality:
                                FilterQuality.medium,
                            errorBuilder:
                                (_, __, ___) {
                              return _ArtworkFallback(
                                title: movie.title,
                              );
                            },
                          )
                        else
                          _ArtworkFallback(
                            title: movie.title,
                          ),

                        // Artwork gradient.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 125,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration:
                                  BoxDecoration(
                                gradient:
                                    LinearGradient(
                                  begin: Alignment
                                      .topCenter,
                                  end: Alignment
                                      .bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black
                                        .withValues(
                                      alpha: 0.94,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Hover dim.
                        AnimatedOpacity(
                          opacity:
                              hovering ? 1 : 0,
                          duration:
                              const Duration(
                            milliseconds: 180,
                          ),
                          child: Container(
                            color: Colors.black
                                .withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),

                        // Play button.
                        Center(
                          child: AnimatedScale(
                            scale: hovering ? 1 : 0.72,
                            duration:
                                const Duration(
                              milliseconds: 240,
                            ),
                            curve:
                                Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity:
                                  hovering ? 1 : 0,
                              duration:
                                  const Duration(
                                milliseconds: 170,
                              ),
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration:
                                    BoxDecoration(
                                  color: Colors.white,
                                  shape:
                                      BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors
                                          .black
                                          .withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons
                                      .play_arrow_rounded,
                                  color:
                                      Colors.black,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Movie badge.
                        Positioned(
                          top: 11,
                          left: 11,
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors.black
                                  .withValues(
                                alpha: 0.58,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(7),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'MOVIE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        if (movie.releaseYear != null)
                          Positioned(
                            top: 11,
                            right: 11,
                            child: Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors.black
                                    .withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(7),
                              ),
                              child: Text(
                                '${movie.releaseYear}',
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Card information.
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      13,
                      11,
                      10,
                      13,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                movie.title,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              if (movie.releaseYear !=
                                  null) ...[
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  '${movie.releaseYear}',
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(
                                      alpha: 0.38,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds: 180,
                          ),
                          width: 35,
                          height: 35,
                          decoration:
                              BoxDecoration(
                            color: hovering
                                ? Colors.white
                                    .withValues(
                                    alpha: 0.12,
                                  )
                                : Colors.white
                                    .withValues(
                                    alpha: 0.055,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons
                                .play_arrow_rounded,
                            color: Colors.white
                                .withValues(
                              alpha:
                                  hovering ? 0.95 : 0.65,
                            ),
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ARTWORK FALLBACK
// ============================================================

class _ArtworkFallback extends StatelessWidget {
  final String title;

  const _ArtworkFallback({
    required this.title,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF292929),
            Color(0xFF0B0B0B),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.035,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_rounded,
                    size: 50,
                    color: Colors.white.withValues(
                      alpha: 0.18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white
                          .withValues(
                        alpha: 0.32,
                      ),
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEATURED FALLBACK
// ============================================================

class _FeaturedFallback extends StatelessWidget {
  const _FeaturedFallback();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF303030),
            Color(0xFF0B0B0B),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_rounded,
          size: 80,
          color: Colors.white.withValues(
            alpha: 0.12,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _MoviesBackground extends StatelessWidget {
  const _MoviesBackground();

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -210,
            left: -140,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.032,
                ),
              ),
            ),
          ),
          Positioned(
            top: 360,
            right: -260,
            child: Container(
              width: 560,
              height: 560,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.016,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -300,
            left: -230,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.012,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GLASS BUTTON
// ============================================================

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_GlassIconButton> createState() =>
      _GlassIconButtonState();
}

class _GlassIconButtonState
    extends State<_GlassIconButton> {
  bool hovering = false;
  bool pressed = false;

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
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
        onTapDown: (_) {
          setState(() {
            pressed = true;
          });
        },
        onTapCancel: () {
          setState(() {
            pressed = false;
          });
        },
        onTap: () {
          setState(() {
            pressed = false;
          });
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: pressed
              ? 0.92
              : hovering
                  ? 1.04
                  : 1,
          duration:
              const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hovering
                  ? Colors.white.withValues(
                      alpha: 0.09,
                    )
                  : Colors.white.withValues(
                      alpha: 0.055,
                    ),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: hovering
                    ? Colors.white.withValues(
                        alpha: 0.14,
                      )
                    : Colors.white.withValues(
                        alpha: 0.07,
                      ),
              ),
            ),
            child: Icon(
              widget.icon,
              color: Colors.white.withValues(
                alpha: hovering ? 0.95 : 0.78,
              ),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}
