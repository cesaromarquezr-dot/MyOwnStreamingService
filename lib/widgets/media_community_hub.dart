import 'package:material_ui/material_ui.dart';

import '../community/media_community_service.dart';
import '../core/services/cinematic_title_metadata_service.dart';

/// User-written reviews and account-aware discussions for one media item.
/// Reviews are only enabled after the current profile has recorded playback.
class MediaCommunityHub extends StatefulWidget {
  const MediaCommunityHub({
    super.key,
    required this.mediaKey,
    required this.mediaTitle,
    required this.mediaType,
    this.hasConsumptionActivity = false,
    this.consumptionActivityFuture,
    this.activityProfileId,
    this.providerReviews = const <CinematicTitleReview>[],
    this.providerId,
    this.providerIsTv = false,
  });

  final String mediaKey;
  final String mediaTitle;
  final String mediaType;
  final bool hasConsumptionActivity;
  final Future<bool>? consumptionActivityFuture;
  final String? activityProfileId;
  final List<CinematicTitleReview> providerReviews;
  final int? providerId;
  final bool providerIsTv;

  @override
  State<MediaCommunityHub> createState() => _MediaCommunityHubState();
}

class _MediaCommunityHubState extends State<MediaCommunityHub> {
  bool _loading = true;
  bool _posting = false;
  bool _hasActivity = false;
  String? _error;
  List<Map<String, dynamic>> _reviews = const <Map<String, dynamic>>[];
  int _communityReviewPage = 1;
  bool _hasMoreCommunityReviews = false;
  bool _loadingMoreCommunityReviews = false;
  List<Map<String, dynamic>> _threads = const <Map<String, dynamic>>[];
  List<CinematicTitleReview> _providerReviews = const <CinematicTitleReview>[];
  int _providerReviewPage = 1;
  int _providerReviewTotalPages = 1;
  bool _loadingMoreProviderReviews = false;

  @override
  void initState() {
    super.initState();
    _hasActivity = widget.hasConsumptionActivity;
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MediaCommunityHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaKey != widget.mediaKey ||
        oldWidget.hasConsumptionActivity != widget.hasConsumptionActivity ||
        oldWidget.activityProfileId != widget.activityProfileId ||
        oldWidget.providerReviews.length != widget.providerReviews.length ||
        oldWidget.providerId != widget.providerId ||
        oldWidget.providerIsTv != widget.providerIsTv) {
      _hasActivity = widget.hasConsumptionActivity;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = MediaCommunityService.instance;
      if (widget.consumptionActivityFuture != null && !_hasActivity) {
        _hasActivity = await widget.consumptionActivityFuture!;
      }
      final providerFuture = widget.providerId != null
          ? CinematicTitleMetadataService.lookupReviewsPage(
              providerId: widget.providerId!,
              isTv: widget.providerIsTv,
              page: 1,
            )
              .then<CinematicTitleReviewPage?>((page) => page)
              .catchError((Object _) => null)
          : Future<CinematicTitleReviewPage?>.value(null);
      final reviewsFuture = service
          .loadReviews(widget.mediaKey, page: 1)
          .catchError((Object _) => <Map<String, dynamic>>[]);
      final threadsFuture = service
          .loadThreads(widget.mediaKey)
          .catchError((Object _) => <Map<String, dynamic>>[]);
      final results = await Future.wait([reviewsFuture, threadsFuture]);
      final providerPage = await providerFuture;
      if (!mounted) return;
      setState(() {
        _reviews = results[0];
        _communityReviewPage = 1;
        _hasMoreCommunityReviews = results[0].length == 100;
        _threads = results[1];
        _providerReviews = providerPage?.reviews ?? widget.providerReviews;
        _providerReviewPage = providerPage?.page ?? 1;
        _providerReviewTotalPages = providerPage?.totalPages ?? 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(
      0,
      (sum, row) => sum + ((row['rating'] as num?)?.toInt() ?? 0),
    );
    return total / _reviews.length;
  }

  Future<void> _loadMoreCommunityReviews() async {
    if (_loadingMoreCommunityReviews || !_hasMoreCommunityReviews) return;
    setState(() => _loadingMoreCommunityReviews = true);
    try {
      final nextPage = _communityReviewPage + 1;
      final rows = await MediaCommunityService.instance.loadReviews(
        widget.mediaKey,
        page: nextPage,
      );
      if (!mounted) return;
      final known = _reviews.map((row) => row['id']?.toString()).toSet();
      setState(() {
        _reviews = <Map<String, dynamic>>[
          ..._reviews,
          ...rows.where((row) => known.add(row['id']?.toString())),
        ];
        _communityReviewPage = nextPage;
        _hasMoreCommunityReviews = rows.length == 100;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load more community reviews: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreCommunityReviews = false);
    }
  }

  Future<void> _loadMoreProviderReviews() async {
    final providerId = widget.providerId;
    if (providerId == null ||
        _loadingMoreProviderReviews ||
        _providerReviewPage >= _providerReviewTotalPages) {
      return;
    }
    setState(() => _loadingMoreProviderReviews = true);
    try {
      final page = await CinematicTitleMetadataService.lookupReviewsPage(
        providerId: providerId,
        isTv: widget.providerIsTv,
        page: _providerReviewPage + 1,
      );
      if (!mounted) return;
      final known = _providerReviews
          .map((review) => review.id ?? '${review.author}|${review.createdAt}')
          .toSet();
      setState(() {
        _providerReviews = <CinematicTitleReview>[
          ..._providerReviews,
          ...page.reviews.where((review) => known.add(
                review.id ?? '${review.author}|${review.createdAt}',
              )),
        ];
        _providerReviewPage = page.page;
        _providerReviewTotalPages = page.totalPages;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load more provider reviews: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreProviderReviews = false);
    }
  }

  Future<void> _writeReview() async {
    if (!_hasActivity || _posting) return;
    final textController = TextEditingController();
    var rating = 5;
    var shareGlobally = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${widget.mediaTitle}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your rating'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value out of 5',
                      onPressed: () => setDialogState(() => rating = value),
                      icon: Icon(
                        value <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: textController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                    labelText: 'Your review',
                    hintText: 'What did you think?',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: shareGlobally,
                  onChanged: (value) =>
                      setDialogState(() => shareGlobally = value),
                  title: const Text('Share review publicly'),
                  subtitle: const Text(
                      'Otherwise only profiles in this account can see it.'),
                ),
                const Text(
                  'Only profiles with recorded playback can submit a review.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Post review'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) {
      textController.dispose();
      return;
    }
    setState(() => _posting = true);
    try {
      await MediaCommunityService.instance.saveReview(
        mediaKey: widget.mediaKey,
        mediaTitle: widget.mediaTitle,
        mediaType: widget.mediaType,
        rating: rating,
        reviewText: textController.text,
        hasPlayActivity: _hasActivity,
        visibility: shareGlobally ? 'global' : 'account',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post review: $error')),
        );
      }
    } finally {
      textController.dispose();
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _newDiscussion() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var spoiler = false;
    var shareGlobally = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start a discussion'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Discussion title',
                  hintText: 'What would you like to discuss?',
                ),
              ),
              TextField(
                controller: bodyController,
                minLines: 3,
                maxLines: 7,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: shareGlobally,
                onChanged: (value) =>
                    setDialogState(() => shareGlobally = value),
                title: const Text('Share discussion publicly'),
                subtitle: const Text(
                    'Otherwise only profiles in this account can see it.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: spoiler,
                onChanged: (value) =>
                    setDialogState(() => spoiler = value ?? false),
                title: const Text('Contains spoilers'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) {
      titleController.dispose();
      bodyController.dispose();
      return;
    }
    setState(() => _posting = true);
    try {
      await MediaCommunityService.instance.createThread(
        mediaKey: widget.mediaKey,
        mediaTitle: widget.mediaTitle,
        mediaType: widget.mediaType,
        title: titleController.text,
        body: bodyController.text,
        containsSpoilers: spoiler,
        visibility: shareGlobally ? 'global' : 'account',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish discussion: $error')),
        );
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = MediaCommunityService.instance;
    if (!service.isConfigured) {
      return _panel(
        title: 'Ratings, Reviews & Discussions',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProviderReviewsSection(),
            const Text(
              'Connect Supabase and apply the community migration to enable MyOwnStreamingService profile reviews and discussion boards.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return _panel(
      title: 'Ratings, Reviews & Discussions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!service.isAuthenticated)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Sign in to participate in reviews and discussion boards.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          if (!_loading) ...[
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 27),
                const SizedBox(width: 5),
                Text(
                  _reviews.isEmpty
                      ? 'No community ratings yet'
                      : '${_averageRating.toStringAsFixed(1)} / 5',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(width: 8),
                Text('(${_reviews.length} reviews)',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed:
                      _hasActivity && !_posting && service.isAuthenticated
                          ? _writeReview
                          : null,
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('Write a review'),
                ),
              ],
            ),
            if (!_hasActivity)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Watch or listen to this item on the current profile before submitting a review.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            _buildProviderReviewsSection(),
            if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Be the first to review this title.',
                    style: TextStyle(color: Colors.white60)),
              )
            else
              for (final review in _reviews)
                _ReviewTile(review: review, mediaType: widget.mediaType),
            if (_hasMoreCommunityReviews)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadingMoreCommunityReviews
                      ? null
                      : _loadMoreCommunityReviews,
                  icon: _loadingMoreCommunityReviews
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: const Text('Load more community reviews'),
                ),
              ),
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text('Discussion board',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
                OutlinedButton.icon(
                  onPressed: _posting || !service.isAuthenticated
                      ? null
                      : _newDiscussion,
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: const Text('Start discussion'),
                ),
              ],
            ),
            if (_threads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'No discussions yet. Start a conversation about this item.',
                    style: TextStyle(color: Colors.white60)),
              )
            else
              for (final thread in _threads)
                _DiscussionThreadCard(thread: thread),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderReviewsSection() {
    if (_providerReviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 14, bottom: 6),
          child: Text('Reviews from TMDB',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final review in _providerReviews)
          _ProviderReviewTile(review: review),
        if (_providerReviewPage < _providerReviewTotalPages)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  _loadingMoreProviderReviews ? null : _loadMoreProviderReviews,
              icon: _loadingMoreProviderReviews
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                'Load more TMDB reviews ($_providerReviewPage/$_providerReviewTotalPages pages)',
              ),
            ),
          ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _panel({required String title, required Widget child}) => Container(
        margin: const EdgeInsets.only(top: 22, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.mediaType});
  final Map<String, dynamic> review;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final name = review['profile_name']?.toString().trim();
    final date =
        DateTime.tryParse(review['created_at']?.toString() ?? '')?.toLocal();
    final hasActivity = review['has_play_activity'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name?.isNotEmpty == true ? name! : 'Profile',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  5,
                  (i) => Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: Colors.amber,
                      )),
            ),
          ]),
          if (hasActivity)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                mediaType.toLowerCase().contains('music') ||
                        mediaType.toLowerCase().contains('album') ||
                        mediaType.toLowerCase().contains('song') ||
                        mediaType.toLowerCase().contains('track')
                    ? 'Listening activity recorded on this profile'
                    : 'Viewing activity recorded on this profile',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(review['review_text']?.toString() ?? '',
                style: const TextStyle(color: Colors.white70, height: 1.4)),
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ),
          const Divider(height: 18),
        ],
      ),
    );
  }
}

class _ProviderReviewTile extends StatelessWidget {
  const _ProviderReviewTile({required this.review});
  final CinematicTitleReview review;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(review.createdAt ?? '')?.toLocal();
    final rating = review.rating;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(review.author,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (rating != null)
              Text('${rating.toStringAsFixed(1)}/10',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          Text(review.content,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, height: 1.4)),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · TMDB',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          const Divider(height: 18),
        ],
      ),
    );
  }
}

class _DiscussionThreadCard extends StatefulWidget {
  const _DiscussionThreadCard({required this.thread});
  final Map<String, dynamic> thread;

  @override
  State<_DiscussionThreadCard> createState() => _DiscussionThreadCardState();
}

class _DiscussionThreadCardState extends State<_DiscussionThreadCard> {
  bool _loading = false;
  bool _spoilersRevealed = false;
  List<Map<String, dynamic>> _replies = const <Map<String, dynamic>>[];

  Future<void> _loadReplies() async {
    setState(() => _loading = true);
    try {
      final rows = await MediaCommunityService.instance.loadReplies(
        widget.thread['id']?.toString() ?? '',
      );
      if (!mounted) return;
      setState(() => _replies = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load discussion replies.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply() async {
    final controller = TextEditingController();
    final posted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reply to discussion'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          maxLength: 3000,
          decoration: const InputDecoration(
            hintText: 'Write a reply…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reply')),
        ],
      ),
    );
    if (posted == true && mounted) {
      try {
        await MediaCommunityService.instance.addReply(
          threadId: widget.thread['id']?.toString() ?? '',
          body: controller.text,
        );
        await _loadReplies();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not post reply: $error')),
          );
        }
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.thread['profile_name']?.toString() ?? 'Profile';
    final title = widget.thread['title']?.toString() ?? 'Discussion';
    final body = widget.thread['body']?.toString() ?? '';
    final spoiler = widget.thread['contains_spoilers'] == true;
    return Card(
      color: Colors.white.withValues(alpha: .035),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          if (expanded && _replies.isEmpty) _loadReplies();
        },
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$author${spoiler ? ' · Spoilers' : ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (spoiler && !_spoilersRevealed) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('This post contains spoilers.',
                  style: TextStyle(color: Colors.orangeAccent)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _spoilersRevealed = true),
                child: const Text('Reveal spoiler'),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(body,
                  style: const TextStyle(color: Colors.white70, height: 1.4)),
            ),
          const Divider(),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_replies.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No replies yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            )
          else
            for (final reply in _replies)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(reply['profile_name']?.toString() ?? 'Profile',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
                subtitle: Text(reply['body']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white70)),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reply,
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: const Text('Reply'),
            ),
          ),
        ],
      ),
    );
  }
}
