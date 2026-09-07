import 'package:flutter/material.dart';

import 'app_core.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with TickerProviderStateMixin {
  final AppController controller = AppController.instance;
  final TextEditingController _messageController = TextEditingController();

  final Set<String> _votingIds = <String>{};

  late final AnimationController _headerAnimationController;

  bool _loadingRecommendations = true;
  bool _loadingWishlist = true;
  bool _sendingMessage = false;
  bool _startingGroupWatch = false;

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _loadData();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loadingRecommendations = true;
        _loadingWishlist = true;
      });
    }

    try {
      await Future.wait<void>([
        controller.loadGroupRecommendations(),
        controller.loadGroupWishlist(),
      ]);
    } catch (_) {
      // The controller exposes its own error state.
    }

    if (!mounted) return;

    setState(() {
      _loadingRecommendations = false;
      _loadingWishlist = false;
    });
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  String get _profileName {
    return controller.currentProfile?.name ??
        controller.currentAccount?.username ??
        'You';
  }

  List<Profile> get _profiles {
    return controller.currentAccount?.profiles ?? <Profile>[];
  }

  // ============================================================
  // GROUP WATCH
  // ============================================================

  Future<void> _openGroupWatchPicker() async {
    if (_startingGroupWatch) {
      return;
    }

    final library = List<MediaItem>.from(controller.library);

    if (library.isEmpty) {
      _showMessage(
        'Your library is empty. Add a movie or show before starting Group Watch.',
      );
      return;
    }

    final media = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GroupWatchMediaSheet(
          media: library,
        );
      },
    );

    if (media == null || !mounted) {
      return;
    }

    await _openGroupWatchInvites(media);
  }

  Future<void> _openGroupWatchInvites(MediaItem media) async {
    final profiles = List<Profile>.from(_profiles);

    if (profiles.isEmpty) {
      _showMessage(
        'Create at least one profile before starting Group Watch.',
      );
      return;
    }

    final result = await showModalBottomSheet<_GroupWatchInviteDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GroupWatchInviteSheet(
          media: media,
          profiles: profiles,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _createGroupWatch(
      media,
      result.invitedProfileIds,
      invitationDurationHours: result.invitationDurationHours,
    );
  }

  Future<void> _createGroupWatch(
    MediaItem media,
    List<String> invitedProfileIds, {
    int invitationDurationHours = 24,
  }) async {
    final profileId = controller.currentProfile?.id;

    if (profileId == null || profileId.isEmpty) {
      _showMessage(
        'Select a profile before starting Group Watch.',
      );
      return;
    }

    if (_startingGroupWatch) {
      return;
    }

    setState(() {
      _startingGroupWatch = true;
    });

    try {
      final session = await controller.createBackendGroupWatchSession(
        media,
        profileId: profileId,
        invitedProfileIds: invitedProfileIds.toSet(),
        invitationDurationHours: invitationDurationHours,
      );

      if (!mounted) return;

      _showMessage(
        invitedProfileIds.isEmpty
            ? 'Group Watch lobby created for ${media.title}.'
            : 'Invitations sent for ${media.title}.',
      );

      /*
       * group_watch.dart will be connected here next.
       *
       * Once that file exists, this is the navigation point:
       *
       * Navigator.of(context).push(
       *   MaterialPageRoute(
       *     builder: (_) => GroupWatchScreen(
       *       sessionId: session.id,
       *       media: media,
       *     ),
       *   ),
       * );
       *
       * The backend session is already created above, so the lobby
       * will have a real session ID and participant state.
       */

      // Keep the variable referenced until GroupWatchScreen is connected.
      debugPrint('Created Group Watch session: ${session.id}');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (!mounted) {
        setState(() {
          return;
        });
      }
      setState(() {
        _startingGroupWatch = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sendingMessage) {
      return;
    }

    setState(() {
      _sendingMessage = true;
    });

    try {
      controller.sendGroupMessage(message: text);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        _showMessage(
          _cleanError(error),
          isError: true,
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _sendingMessage = false;
    });
  }

  Future<void> _vote(
    Map<String, dynamic> recommendation,
    bool yes,
  ) async {
    final id = _stringValue(recommendation['id']);

    if (id.isEmpty || _votingIds.contains(id)) {
      return;
    }

    final profileId = controller.currentProfile?.id;

    if (profileId == null || profileId.isEmpty) {
      _showMessage('Select a profile before voting.');
      return;
    }

    setState(() {
      _votingIds.add(id);
    });

    try {
      await controller.voteOnGroupRecommendation(
        recommendationId: id,
        profileId: profileId,
        vote: yes ? 'yes' : 'no',
      );

      if (mounted) {
        _showMessage(
          yes ? 'You voted YES.' : 'You voted NO.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          _cleanError(error),
          isError: true,
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _votingIds.remove(id);
    });
  }

  Future<void> _createRecommendation() async {
    final result = await showModalBottomSheet<_RecommendationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _RecommendationSheet();
      },
    );

    if (result == null) {
      return;
    }

    final profileId = controller.currentProfile?.id;

    if (profileId == null || profileId.isEmpty) {
      _showMessage('Select a profile before creating a recommendation.');
      return;
    }

    try {
      await controller.createGroupRecommendation(
        title: result.title,
        type: result.type,
        profileId: profileId,
        activeParticipants: result.participantIds.toSet(),
      );

      if (!mounted) return;

      await controller.loadGroupRecommendations();

      if (!mounted) return;

      _showMessage('Recommendation added to the group.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  Future<void> _removeWishlistItem(WishlistItem item) async {
    try {
      await controller.removeFromGroupWishlist(item.id);

      if (!mounted) return;

      _showMessage('${item.title} removed from the group wishlist.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  Future<void> _acquireWishlistItem(WishlistItem item) async {
    final profileId = controller.currentProfile?.id;

    if (profileId == null || profileId.isEmpty) {
      _showMessage('Select a profile first.');
      return;
    }

    try {
      await controller.acquireGroupWishlistItem(
        mediaId: item.id,
        profileId: profileId,
      );

      if (!mounted) return;

      _showMessage('${item.title} was added to your library.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? const Color(0xFF7F1D1D) : const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF050505),
          body: Stack(
            children: [
              const _BackgroundGlow(),

              SafeArea(
                child: RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: const Color(0xFF18181B),
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildMembers(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildQuickActions(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildRecommendations(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildWishlist(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildChatHeader(),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          110,
                        ),
                        sliver: _buildMessages(),
                      ),
                    ],
                  ),
                ),
              ),

              _buildComposer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROUP ROOM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Movie Night',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
              _CircleButton(
                icon: Icons.refresh_rounded,
                onTap: _refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembers() {
    final profiles = _profiles;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 42,
              child: Stack(
                children: [
                  for (int i = 0; i < profiles.take(4).length; i++)
                    Positioned(
                      left: i * 22,
                      child: _Avatar(
                        profile: profiles[i],
                        size: 42,
                        showBorder: true,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profiles.isEmpty
                        ? 'Private movie room'
                        : '${profiles.length} ${profiles.length == 1 ? 'member' : 'members'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Recommend something everyone will love.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: _GroupWatchAction(
              loading: _startingGroupWatch,
              onTap: _openGroupWatchPicker,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_rounded,
                  title: 'Recommend',
                  subtitle: 'Suggest a movie',
                  onTap: _createRecommendation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.how_to_vote_rounded,
                  title: 'Voting',
                  subtitle: 'Pick the winner',
                  onTap: _scrollToRecommendations,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToRecommendations() {
    // Recommendations are intentionally near the top of the feed.
  }

  Widget _buildRecommendations() {
    final recommendations = controller.groupRecommendations;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'GROUP PICKS',
            subtitle: recommendations.isEmpty
                ? 'Start the movie debate.'
                : 'Everyone gets a vote.',
            trailing: TextButton.icon(
              onPressed: _createRecommendation,
              icon: const Icon(
                Icons.add_rounded,
                size: 17,
              ),
              label: const Text('Recommend'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingRecommendations)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (recommendations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyRecommendations(),
            )
          else
            SizedBox(
              height: 286,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recommendations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];

                  return _RecommendationCard(
                    recommendation: recommendation,
                    isVoting: _votingIds.contains(
                      _stringValue(recommendation['id']),
                    ),
                    onYes: () => _vote(
                      recommendation,
                      true,
                    ),
                    onNo: () => _vote(
                      recommendation,
                      false,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWishlist() {
    final wishlist = controller.wishlist;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'GROUP WISHLIST',
            subtitle: 'Movies the room agreed on.',
          ),
          const SizedBox(height: 12),
          if (_loadingWishlist)
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (wishlist.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Approved recommendations will appear here.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: wishlist
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WishlistCard(
                          item: item,
                          onGet: () => _acquireWishlistItem(item),
                          onRemove: () => _removeWishlistItem(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROUP CHAT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Talk about what to watch next.',
                  style: TextStyle(
                    color: Color(0xFF77777F),
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

  Widget _buildMessages() {
    final messages = List<ChatMessage>.from(
      controller.groupMessages,
    );

    if (messages.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.only(top: 5),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              const Text(
                'Start the conversation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Recommend a movie or tell everyone what you want to watch.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        final isMine = message.sender == _profileName ||
            message.sender ==
                (controller.currentAccount?.username ?? '');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ChatBubble(
            message: message,
            isMine: isMine,
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF070707).withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Message the group...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: _sendingMessage ? null : _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _sendingMessage
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _sendingMessage
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.black,
                          size: 21,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GROUP WATCH ACTION
// ============================================================

class _GroupWatchAction extends StatefulWidget {
  final VoidCallback onTap;
  final bool loading;

  const _GroupWatchAction({
    required this.onTap,
    this.loading = false,
  });

  @override
  State<_GroupWatchAction> createState() => _GroupWatchActionState();
}

class _GroupWatchActionState extends State<_GroupWatchAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading
          ? null
          : (_) {
              setState(() {
                _pressed = true;
              });
            },
      onTapCancel: widget.loading
          ? null
          : () {
              setState(() {
                _pressed = false;
              });
            },
      onTap: widget.loading
          ? null
          : () {
              setState(() {
                _pressed = false;
              });

              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: widget.loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(
                        Icons.groups_rounded,
                        color: Colors.black,
                        size: 25,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.loading
                          ? 'CREATING WATCH PARTY'
                          : 'GROUP WATCH',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.loading
                          ? 'Setting up your private movie night...'
                          : 'Watch together with synchronized playback',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF929298),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 34,
                        height: 34,
                      )
                    : Container(
                        key: const ValueKey('arrow'),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GROUP WATCH MEDIA PICKER
// ============================================================

class _GroupWatchMediaSheet extends StatefulWidget {
  final List<MediaItem> media;

  const _GroupWatchMediaSheet({
    required this.media,
  });

  @override
  State<_GroupWatchMediaSheet> createState() => _GroupWatchMediaSheetState();
}

class _GroupWatchMediaSheetState extends State<_GroupWatchMediaSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MediaItem> get _filteredMedia {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.media;
    }

    return widget.media.where((media) {
      return media.title.toLowerCase().contains(query) ||
          media.type.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = _filteredMedia;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF101012),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Group Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose something for everyone to watch.',
                          style: TextStyle(
                            color: Color(0xFF77777F),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.055),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _search = value;
                    });
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search your library...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                              });
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: media.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 25, 20, 35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.movie_filter_outlined,
                            size: 42,
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          const SizedBox(height: 13),
                          const Text(
                            'Nothing found',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Try another title.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        25,
                      ),
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: media.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final item = media[index];

                        return _GroupWatchMediaTile(
                          media: item,
                          onTap: () {
                            Navigator.of(context).pop(item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GROUP WATCH INVITE SHEET
// ============================================================

class _GroupWatchInviteSheet extends StatefulWidget {
  final MediaItem media;
  final List<Profile> profiles;

  const _GroupWatchInviteSheet({
    required this.media,
    required this.profiles,
  });

  @override
  State<_GroupWatchInviteSheet> createState() => _GroupWatchInviteSheetState();
}

class _GroupWatchInviteSheetState extends State<_GroupWatchInviteSheet> {
  late final Set<String> _selectedProfileIds;

  int _invitationDurationHours = 24;

  @override
  void initState() {
    super.initState();

    final currentProfileId = AppController.instance.currentProfile?.id;

    _selectedProfileIds = <String>{
      for (final profile in widget.profiles)
        if (profile.id != currentProfileId) profile.id,
    };
  }

  void _toggleProfile(String profileId) {
    setState(() {
      if (_selectedProfileIds.contains(profileId)) {
        _selectedProfileIds.remove(profileId);
      } else {
        _selectedProfileIds.add(profileId);
      }
    });
  }

  void _selectEveryone() {
    final currentProfileId = AppController.instance.currentProfile?.id;

    setState(() {
      _selectedProfileIds
        ..clear()
        ..addAll(
          widget.profiles
              .where((profile) => profile.id != currentProfileId)
              .map((profile) => profile.id),
        );
    });
  }

  void _clearEveryone() {
    setState(() {
      _selectedProfileIds.clear();
    });
  }

  void _continue() {
    Navigator.of(context).pop(
      _GroupWatchInviteDraft(
        invitedProfileIds: _selectedProfileIds.toList(),
        invitationDurationHours: _invitationDurationHours,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProfileId = AppController.instance.currentProfile?.id;

    final inviteableProfiles = widget.profiles
        .where((profile) => profile.id != currentProfileId)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF101012),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Row(
                children: [
                  _MediaPoster(
                    media: widget.media,
                    width: 64,
                    height: 88,
                    borderRadius: 13,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite to watch',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.media.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose who gets an invitation.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'INVITE PEOPLE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedProfileIds.length ==
                            inviteableProfiles.length
                        ? _clearEveryone
                        : _selectEveryone,
                    child: Text(
                      _selectedProfileIds.length ==
                              inviteableProfiles.length
                          ? 'Clear'
                          : 'Everyone',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: inviteableProfiles.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_add_disabled_rounded,
                              size: 34,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No one else to invite',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can still create a private Group Watch lobby.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        10,
                      ),
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: inviteableProfiles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final profile = inviteableProfiles[index];
                        final selected =
                            _selectedProfileIds.contains(profile.id);

                        return _GroupWatchProfileTile(
                          profile: profile,
                          selected: selected,
                          onTap: () => _toggleProfile(profile.id),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVITATION EXPIRATION',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _InvitationDurationButton(
                        label: '1 HOUR',
                        selected: _invitationDurationHours == 1,
                        onTap: () {
                          setState(() {
                            _invitationDurationHours = 1;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _InvitationDurationButton(
                        label: '6 HOURS',
                        selected: _invitationDurationHours == 6,
                        onTap: () {
                          setState(() {
                            _invitationDurationHours = 6;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _InvitationDurationButton(
                        label: '24 HOURS',
                        selected: _invitationDurationHours == 24,
                        onTap: () {
                          setState(() {
                            _invitationDurationHours = 24;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedProfileIds.isEmpty
                                ? 'CREATE PRIVATE LOBBY'
                                : 'SEND ${_selectedProfileIds.length} INVITATION${_selectedProfileIds.length == 1 ? '' : 'S'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupWatchInviteDraft {
  final List<String> invitedProfileIds;
  final int invitationDurationHours;

  const _GroupWatchInviteDraft({
    required this.invitedProfileIds,
    required this.invitationDurationHours,
  });
}

class _GroupWatchProfileTile extends StatefulWidget {
  final Profile profile;
  final bool selected;
  final VoidCallback onTap;

  const _GroupWatchProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_GroupWatchProfileTile> createState() => _GroupWatchProfileTileState();
}

class _GroupWatchProfileTileState extends State<_GroupWatchProfileTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.055),
            ),
          ),
          child: Row(
            children: [
              _Avatar(
                profile: widget.profile,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.selected
                          ? 'Will receive an invitation'
                          : 'Not invited',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? Colors.white
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: widget.selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationDurationButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InvitationDurationButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.11)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: selected ? 0.9 : 0.45,
                ),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GROUP WATCH MEDIA TILE
// ============================================================

class _GroupWatchMediaTile extends StatefulWidget {
  final MediaItem media;
  final VoidCallback onTap;

  const _GroupWatchMediaTile({
    required this.media,
    required this.onTap,
  });

  @override
  State<_GroupWatchMediaTile> createState() => _GroupWatchMediaTileState();
}

class _GroupWatchMediaTileState extends State<_GroupWatchMediaTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final media = widget.media;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.055),
            ),
          ),
          child: Row(
            children: [
              _MediaPoster(
                media: media,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _capitalize(media.type),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Invite the group',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.075),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MEDIA POSTER
// ============================================================

class _MediaPoster extends StatelessWidget {
  final MediaItem media;
  final double width;
  final double height;
  final double borderRadius;

  const _MediaPoster({
    required this.media,
    this.width = 58,
    this.height = 78,
    this.borderRadius = 11,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (media.imageUrl ?? '').trim();

    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          media.type.toLowerCase().contains('series') ||
                  media.type.toLowerCase().contains('tv')
              ? Icons.tv_rounded
              : Icons.movie_rounded,
          color: Colors.white.withValues(alpha: 0.45),
          size: 22,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: width,
            height: height,
            color: Colors.white.withValues(alpha: 0.07),
            child: Icon(
              Icons.movie_rounded,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// RECOMMENDATION SHEET
// ============================================================

class _RecommendationSheet extends StatefulWidget {
  const _RecommendationSheet();

  @override
  State<_RecommendationSheet> createState() => _RecommendationSheetState();
}

class _RecommendationSheetState extends State<_RecommendationSheet> {
  final TextEditingController _titleController = TextEditingController();

  String _type = 'movie';

  final Set<String> _selectedParticipants = <String>{};

  @override
  void initState() {
    super.initState();

    final profiles =
        AppController.instance.currentAccount?.profiles ?? <Profile>[];

    for (final profile in profiles) {
      _selectedParticipants.add(profile.id);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a movie or show title.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _RecommendationDraft(
        title: title,
        type: _type,
        participantIds: _selectedParticipants.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles =
        AppController.instance.currentAccount?.profiles ?? <Profile>[];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111113),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recommend something',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Put a movie or show up for the group vote.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.055),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'TYPE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Movie',
                    icon: Icons.movie_outlined,
                    selected: _type == 'movie',
                    onTap: () {
                      setState(() {
                        _type = 'movie';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeButton(
                    label: 'Series',
                    icon: Icons.tv_outlined,
                    selected: _type == 'series',
                    onTap: () {
                      setState(() {
                        _type = 'series';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (profiles.isNotEmpty) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'WHO CAN VOTE?',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedParticipants.length ==
                            profiles.length) {
                          _selectedParticipants.clear();
                        } else {
                          _selectedParticipants
                            ..clear()
                            ..addAll(
                              profiles.map(
                                (profile) => profile.id,
                              ),
                            );
                        }
                      });
                    },
                    child: Text(
                      _selectedParticipants.length == profiles.length
                          ? 'Clear'
                          : 'Everyone',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ...profiles.map(
                (profile) {
                  final selected =
                      _selectedParticipants.contains(profile.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedParticipants.remove(profile.id);
                          } else {
                            _selectedParticipants.add(profile.id);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.09)
                              : Colors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            _Avatar(
                              profile: profile,
                              size: 38,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 23,
                              height: 23,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.black,
                                      size: 15,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text(
                  'START GROUP VOTE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
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

class _RecommendationDraft {
  final String title;
  final String type;
  final List<String> participantIds;

  const _RecommendationDraft({
    required this.title,
    required this.type,
    required this.participantIds,
  });
}

// ============================================================
// RECOMMENDATION CARD
// ============================================================

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final bool isVoting;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _RecommendationCard({
    required this.recommendation,
    required this.isVoting,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(recommendation['title']);
    final type = _stringValue(recommendation['type']);

    final statusValue = _stringValue(
      recommendation['status'],
    );

    final status = statusValue.isEmpty ? 'pending' : statusValue;

    final yesVotes = _numberValue(
      recommendation['yesVotes'] ??
          recommendation['yes_votes'] ??
          recommendation['upVotes'] ??
          recommendation['up_votes'],
    );

    final noVotes = _numberValue(
      recommendation['noVotes'] ??
          recommendation['no_votes'] ??
          recommendation['downVotes'] ??
          recommendation['down_votes'],
    );

    final providedYesPercentage = _numberValue(
      recommendation['yesPercentage'] ??
          recommendation['yes_percentage'],
    );

    final providedNoPercentage = _numberValue(
      recommendation['noPercentage'] ??
          recommendation['no_percentage'],
    );

    final totalVotes = yesVotes + noVotes;

    final hasProvidedPercentages =
        providedYesPercentage > 0 || providedNoPercentage > 0;

    final yesPercentage = hasProvidedPercentages
        ? providedYesPercentage
        : totalVotes == 0
            ? 0
            : (yesVotes / totalVotes) * 100;

    final noPercentage = hasProvidedPercentages
        ? providedNoPercentage
        : totalVotes == 0
            ? 0
            : (noVotes / totalVotes) * 100;

    final normalizedStatus = status.toLowerCase();

    final isClosed = normalizedStatus != 'pending' &&
        normalizedStatus != 'open' &&
        normalizedStatus != 'voting';

    final approved = normalizedStatus == 'approved';

    return Container(
      width: 292,
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: approved
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type.toLowerCase().contains('series') ||
                            type.toLowerCase().contains('tv')
                        ? Icons.tv_rounded
                        : Icons.movie_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const Spacer(),
                _StatusBadge(
                  status: status,
                ),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              title.isEmpty ? 'Untitled recommendation' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              type.isEmpty ? 'Movie' : _capitalize(type),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '${yesVotes.round()} YES',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${noVotes.round()} NO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 7,
                child: Row(
                  children: [
                    Expanded(
                      flex: yesPercentage <= 0
                          ? 1
                          : yesPercentage.round().clamp(1, 100),
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      flex: noPercentage <= 0
                          ? 1
                          : noPercentage.round().clamp(1, 100),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_up_alt_rounded,
                    label: 'YES',
                    selected: false,
                    enabled: !isVoting && !isClosed,
                    onTap: onYes,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_down_alt_rounded,
                    label: 'NO',
                    selected: false,
                    enabled: !isVoting && !isClosed,
                    onTap: onNo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WISHLIST
// ============================================================

class _WishlistCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onGet;
  final VoidCallback onRemove;

  const _WishlistCard({
    required this.item,
    required this.onGet,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              item.type.toLowerCase().contains('series') ||
                      item.type.toLowerCase().contains('tv')
                  ? Icons.tv_rounded
                  : Icons.movie_rounded,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _capitalize(item.type),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to library',
            onPressed: onGet,
            icon: const Icon(
              Icons.add_to_queue_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.45),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHAT
// ============================================================

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 330,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            14,
            11,
            14,
            10,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(isMine ? 17 : 5),
              bottomRight: Radius.circular(isMine ? 5 : 17),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.sender,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Text(
                message.message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADING
// ============================================================

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============================================================
// QUICK ACTION
// ============================================================

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTap: () {
        setState(() {
          _pressed = false;
        });
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.065),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 10,
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
}

// ============================================================
// VOTE BUTTON
// ============================================================

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(
                  alpha: enabled ? 0.07 : 0.035,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: enabled ? 0.08 : 0.03,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? Colors.black
                  : Colors.white.withValues(
                      alpha: enabled ? 0.75 : 0.25,
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.black
                    : Colors.white.withValues(
                        alpha: enabled ? 0.7 : 0.25,
                      ),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TYPE BUTTON
// ============================================================

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.11)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: Colors.white.withValues(
                alpha: selected ? 0.95 : 0.45,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: selected ? 0.95 : 0.5,
                ),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final String label;
    final IconData icon;

    switch (normalized) {
      case 'approved':
      case 'accepted':
        label = 'APPROVED';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        label = 'REJECTED';
        icon = Icons.cancel_rounded;
        break;
      case 'closed':
        label = 'CLOSED';
        icon = Icons.lock_rounded;
        break;
      default:
        label = 'VOTING';
        icon = Icons.how_to_vote_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AVATAR
// ============================================================

class _Avatar extends StatelessWidget {
  final Profile profile;
  final double size;
  final bool showBorder;

  const _Avatar({
    required this.profile,
    required this.size,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl?.trim() ?? '';

    final child = avatarUrl.isNotEmpty
        ? ClipOval(
            child: Image.network(
              avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return _initials();
              },
            ),
          )
        : _initials();

    return Container(
      width: size,
      height: size,
      padding: showBorder
          ? const EdgeInsets.all(2)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF222225),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: const Color(0xFF050505),
                width: 2,
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _initials() {
    final name = profile.name.trim();

    String initials = '?';

    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));

      if (parts.length >= 2) {
        initials =
            '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        initials = name.substring(0, 1).toUpperCase();
      }
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================
// CIRCLE BUTTON
// ============================================================

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY RECOMMENDATIONS
// ============================================================

class _EmptyRecommendations extends StatelessWidget {
  const _EmptyRecommendations();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 38,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 13),
          const Text(
            'Nothing to vote on yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Be the first person to recommend a movie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            right: -130,
            child: Container(
              width: 390,
              height: 390,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.055),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 420,
            left: -180,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
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
// HELPERS
// ============================================================

String _stringValue(dynamic value) {
  if (value == null) {
    return '';
  }

  return value.toString().trim();
}

double _numberValue(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1);
}

String _formatTime(DateTime time) {
  final local = time.toLocal();

  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;

  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $suffix';
}