import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Recent {
  String? imgurl;
  String? name;

  Recent({
    this.imgurl,
    this.name,
  });
}

/// Reusable recently-watched card.
class RecentlyWatchedCard extends StatefulWidget {
  final String? imgurl;
  final String? name;

  const RecentlyWatchedCard({
    super.key,
    this.imgurl,
    this.name,
  });

  @override
  State<RecentlyWatchedCard> createState() => _RecentlyWatchedCardState();
}

class _RecentlyWatchedCardState extends State<RecentlyWatchedCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imgurl?.trim() ?? '';
    final title = widget.name?.trim() ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        child: AnimatedScale(
          scale: _pressed
              ? 0.96
              : _hovering
                  ? 1.035
                  : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 150,
            height: 220,
            margin: const EdgeInsets.only(left: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hovering ? 0.65 : 0.35,
                  ),
                  blurRadius: _hovering ? 24 : 14,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPoster(imageUrl),

                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: _hovering ? 0.02 : 0.0,
                              ),
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: _hovering ? 0.88 : 0.82,
                              ),
                            ],
                            stops: const [
                              0.0,
                              0.42,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress indicator.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          width: _hovering ? 90 : 70,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Play button on hover.
                  Center(
                    child: AnimatedOpacity(
                      opacity: _hovering ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: AnimatedScale(
                        scale: _hovering ? 1.0 : 0.7,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Title.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: AnimatedSlide(
                      offset: _hovering
                          ? const Offset(0, -0.05)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Text(
                        title.isEmpty ? 'Untitled' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Subtle hover border.
                  if (_hovering)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                        ),
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

  Widget _buildPoster(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const _PosterPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 350),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) {
        return const _PosterLoading();
      },
      errorWidget: (context, url, error) {
        return const _PosterPlaceholder();
      },
    );
  }
}

class _PosterLoading extends StatelessWidget {
  const _PosterLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF202020),
            Color(0xFF0D0D0D),
          ],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF222222),
            Color(0xFF0B0B0B),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: const Icon(
            Icons.movie_rounded,
            color: Colors.white38,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// Compatibility name for your old series.dart.
class RecentlyWatched extends RecentlyWatchedCard {
  const RecentlyWatched({
    super.key,
    super.imgurl,
    super.name,
  });
}