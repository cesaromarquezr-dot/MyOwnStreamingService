import 'package:flutter/material.dart';

/// Actor/Actress discovered from media imported into the user's library.
class Actor {
  final String id;
  final String name;

  String photoUrl;
  String biography;
  String placeOfBirth;
  DateTime? dateOfBirth;
  String knownFor;
  String relationshipStatus;
  String partnerName;

  Actor({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.biography = '',
    this.placeOfBirth = '',
    this.dateOfBirth,
    this.knownFor = '',
    this.relationshipStatus = '',
    this.partnerName = '',
  });

  int? get currentAge {
    if (dateOfBirth == null) return null;

    final now = DateTime.now();

    int age = now.year - dateOfBirth!.year;

    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month &&
            now.day < dateOfBirth!.day)) {
      age--;
    }

    return age;
  }
}

/// Cast member belonging to a movie or TV episode.
class CastMember {
  final String actorId;
  final String actorName;
  final String characterName;
  final String? photoUrl;

  CastMember({
    required this.actorId,
    required this.actorName,
    required this.characterName,
    this.photoUrl,
  });
}

/// Legacy model retained so older code can still reference it.
class TopHollywood {
  String? imgurl;
  String? name;

  TopHollywood({
    this.imgurl,
    this.name,
  });
}

/// Actor list screen.
class ActorsScreen extends StatefulWidget {
  const ActorsScreen({super.key});

  @override
  State<ActorsScreen> createState() => _ActorsScreenState();
}

class _ActorsScreenState extends State<ActorsScreen> {
  String searchQuery = '';

  final List<Actor> actors = [];

  @override
  Widget build(BuildContext context) {
    final filteredActors = actors.where((actor) {
      if (searchQuery.trim().isEmpty) {
        return true;
      }

      return actor.name
          .toLowerCase()
          .contains(searchQuery.trim().toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: const Color(0xFF070707),
            elevation: 0,
            title: const Text(
              'Actors',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF171717),
                          Color(0xFF0D0D0D),
                          Color(0xFF070707),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -80,
                    top: -90,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Stars',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.8,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Actors and actresses discovered from your library.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                8,
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search actors...',
                  prefixIcon:
                      const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF151515),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .55),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (filteredActors.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyActorsState(
                hasSearch: searchQuery.isNotEmpty,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                30,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final actor =
                        filteredActors[index];

                    return _ActorCard(
                      actor: actor,
                      index: index,
                    );
                  },
                  childCount: filteredActors.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  mainAxisExtent: 285,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cinematic actor card.
class _ActorCard extends StatefulWidget {
  final Actor actor;
  final int index;

  const _ActorCard({
    required this.actor,
    required this.index,
  });

  @override
  State<_ActorCard> createState() => _ActorCardState();
}

class _ActorCardState extends State<_ActorCard> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 350 + (widget.index * 45),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              18 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            hovered = false;
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
          onTapUp: (_) {
            setState(() {
              pressed = false;
            });
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ActorDetailsScreen(actor: actor),
              ),
            );
          },
          child: AnimatedScale(
            scale: pressed
                ? .97
                : hovered
                    ? 1.035
                    : 1,
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(18),
                boxShadow: hovered
                    ? [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: .5),
                          blurRadius: 25,
                          offset:
                              const Offset(0, 12),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ActorImage(
                      actor: actor,
                    ),

                    // Bottom gradient.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            begin:
                                Alignment.topCenter,
                            end:
                                Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: .12,
                              ),
                              Colors.black.withValues(
                                alpha: .9,
                              ),
                            ],
                            stops: const [
                              0,
                              .48,
                              1,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            actor.name,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          if (actor.knownFor.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              actor.knownFor,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    AnimatedOpacity(
                      opacity: hovered ? 1 : 0,
                      duration:
                          const Duration(milliseconds: 180),
                      child: Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(
                              alpha: .18,
                            ),
                          ),
                          child: const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(12),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
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
      ),
    );
  }
}

/// Actor image with a polished fallback.
class _ActorImage extends StatelessWidget {
  final Actor actor;

  const _ActorImage({
    required this.actor,
  });

  @override
  Widget build(BuildContext context) {
    if (actor.photoUrl.isEmpty) {
      return Container(
        color: const Color(0xFF171717),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: 70,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    return Image.network(
      actor.photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFF171717),
          child: Center(
            child: Icon(
              Icons.person_rounded,
              size: 70,
              color: Colors.grey.shade700,
            ),
          ),
        );
      },
      loadingBuilder:
          (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          color: const Color(0xFF171717),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}

/// Empty state.
class _EmptyActorsState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyActorsState({
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(alpha: .05),
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 42,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? 'No actors found'
                  : 'No actors yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try searching for a different name.'
                  : 'Actors discovered from your imported library will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actor details screen.
class ActorDetailsScreen extends StatelessWidget {
  final Actor actor;

  const ActorDetailsScreen({
    super.key,
    required this.actor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 430,
            pinned: true,
            backgroundColor:
                const Color(0xFF070707),
            elevation: 0,
            title: Text(
              actor.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (actor.photoUrl.isNotEmpty)
                    Image.network(
                      actor.photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) {
                        return Container(
                          color:
                              const Color(0xFF171717),
                        );
                      },
                    )
                  else
                    Container(
                      color:
                          const Color(0xFF171717),
                      child: Icon(
                        Icons.person_rounded,
                        size: 110,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),

                  // Cinematic overlay.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:
                            Alignment.topCenter,
                        end:
                            Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(
                            alpha: .15,
                          ),
                          Colors.black.withValues(
                            alpha: .35,
                          ),
                          const Color(0xFF070707),
                        ],
                        stops: const [
                          0,
                          .45,
                          1,
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          actor.name,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                        ),
                        if (actor.knownFor.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            actor.knownFor,
                            style: TextStyle(
                              color:
                                  Colors.grey.shade300,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              40,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  if (actor.biography.isNotEmpty)
                    _InfoSection(
                      title: 'Biography',
                      icon:
                          Icons.auto_stories_outlined,
                      child: Text(
                        actor.biography,
                        style: TextStyle(
                          color:
                              Colors.grey.shade300,
                          height: 1.55,
                          fontSize: 15,
                        ),
                      ),
                    ),

                  if (actor.placeOfBirth.isNotEmpty ||
                      actor.dateOfBirth != null ||
                      actor.relationshipStatus
                          .isNotEmpty ||
                      actor.partnerName.isNotEmpty)
                    _InfoSection(
                      title: 'About',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        children: [
                          if (actor.dateOfBirth != null)
                            _ActorInfoRow(
                              icon:
                                  Icons.cake_outlined,
                              label: 'Born',
                              value:
                                  _formatDate(
                                actor.dateOfBirth!,
                              ),
                            ),
                          if (actor.currentAge != null)
                            _ActorInfoRow(
                              icon:
                                  Icons.person_outline,
                              label: 'Age',
                              value:
                                  actor.currentAge!
                                      .toString(),
                            ),
                          if (actor.placeOfBirth
                              .isNotEmpty)
                            _ActorInfoRow(
                              icon:
                                  Icons.location_on_outlined,
                              label:
                                  'Place of birth',
                              value:
                                  actor.placeOfBirth,
                            ),
                          if (actor.relationshipStatus
                              .isNotEmpty)
                            _ActorInfoRow(
                              icon:
                                  Icons.favorite_border,
                              label:
                                  'Relationship',
                              value:
                                  actor.relationshipStatus,
                            ),
                          if (actor.partnerName
                              .isNotEmpty)
                            _ActorInfoRow(
                              icon:
                                  Icons.people_outline,
                              label: 'Partner',
                              value:
                                  actor.partnerName,
                            ),
                        ],
                      ),
                    ),

                  if (actor.biography.isEmpty &&
                      actor.placeOfBirth.isEmpty &&
                      actor.dateOfBirth == null &&
                      actor.knownFor.isEmpty &&
                      actor.relationshipStatus.isEmpty &&
                      actor.partnerName.isEmpty)
                    const _NoActorDetails(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _ActorInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ActorInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActorDetails extends StatelessWidget {
  const _NoActorDetails();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 42,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          const Text(
            'No additional information yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'More actor information will appear when metadata is available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compatibility name for older code.
class Actors extends ActorsScreen {
  const Actors({super.key});
}