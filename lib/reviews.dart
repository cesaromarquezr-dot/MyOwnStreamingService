// Media review UI: provider reviews, external rating scores, profile reviews and community reviews.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_core.dart';
import 'localization.dart';
import 'backend_api.dart';
import 'core/services/cinematic_title_metadata_service.dart';

class MediaReviewEntry {
  final String username;
  final double score;
  final String label;
  final String text;
  final String? reviewId;
  final Map<String, String> publicationIds;

  const MediaReviewEntry({
    required this.username,
    required this.score,
    required this.label,
    required this.text,
    this.reviewId,
    this.publicationIds = const <String, String>{},
  });
}

/// Review hub used from a media details page or the More menu.
class ReviewsHubScreen extends StatefulWidget {
  final MediaItem? media;
  final CinematicTitleMetadata? initialMetadata;

  const ReviewsHubScreen({super.key, this.media, this.initialMetadata});

  @override
  State<ReviewsHubScreen> createState() => _ReviewsHubScreenState();
}

class _ReviewsHubScreenState extends State<ReviewsHubScreen> {
  double score = 10;
  final TextEditingController label = TextEditingController(text: 'Excellent');
  final TextEditingController review = TextEditingController();
  bool translation = true;
  bool spoiler = false;
  String reviewType = 'written';
  final Set<String> destinations = <String>{'profile'};
  final TextEditingController communityId = TextEditingController();
  final TextEditingController videoUrl = TextEditingController();

  final List<MediaReviewEntry> local = <MediaReviewEntry>[];
  CinematicTitleMetadata? _titleMetadata;
  Map<String, dynamic>? _externalRatings;
  bool _loadingProviderData = false;
  bool _loadingProviderReviews = false;
  bool _loadingMoreProviderReviews = false;
  String? _providerError;
  final List<CinematicTitleReview> _providerReviews = <CinematicTitleReview>[];
  int _providerReviewPage = 0;
  int _providerReviewTotalPages = 0;
  int _providerReviewTotalResults = 0;

  final List<MediaReviewEntry> global = <MediaReviewEntry>[
    const MediaReviewEntry(
      username: 'noobmaster69',
      score: 10,
      label: 'Best ever',
      text: 'This is the best film I have seen.',
    ),
    const MediaReviewEntry(
      username: 'SpideyFan0804',
      score: 5,
      label: 'Mediocre',
      text: 'Good ideas, but the pacing was uneven.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _titleMetadata = widget.initialMetadata;
    if (widget.media != null && CinematicTitleMetadataService.isConfigured) {
      unawaited(_loadProviderTitleData());
    }
  }

  Future<void> _loadProviderTitleData() async {
    final media = widget.media;
    if (media == null || !CinematicTitleMetadataService.isConfigured) return;
    setState(() {
      _loadingProviderData = true;
      _providerError = null;
    });
    try {
      final metadata = _titleMetadata ?? await CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: media.isSeries,
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (!mounted) return;
      setState(() => _titleMetadata = metadata);
      if (metadata == null) {
        setState(() => _providerError = 'No matching TMDB title was found for this item.');
        return;
      }
      await _loadProviderReviewPage(1);
      final imdbId = metadata.imdbId?.trim() ?? '';
      if (imdbId.isNotEmpty) {
        try {
          final ratings = await AppController.instance.backendApi.getExternalMediaRatings(imdbId);
          if (mounted) setState(() => _externalRatings = ratings);
        } catch (_) {
          // External ratings are optional; TMDB ratings and reviews remain available.
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _providerError = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingProviderData = false);
    }
  }

  Future<void> _loadProviderReviewPage(int page) async {
    final metadata = _titleMetadata;
    if (metadata == null || page < 1 || (page > 1 && _loadingMoreProviderReviews)) return;
    if (page == 1) {
      setState(() => _loadingProviderReviews = true);
    } else {
      setState(() => _loadingMoreProviderReviews = true);
    }
    try {
      final result = await CinematicTitleMetadataService.lookupReviewsPage(
        providerId: metadata.providerId,
        isTv: metadata.isTv,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        final existing = _providerReviews.map((review) => review.id ?? '${review.author}|${review.createdAt}|${review.content.hashCode}').toSet();
        for (final review in result.reviews) {
          final key = review.id ?? '${review.author}|${review.createdAt}|${review.content.hashCode}';
          if (existing.add(key)) _providerReviews.add(review);
        }
        _providerReviewPage = result.page;
        _providerReviewTotalPages = result.totalPages;
        _providerReviewTotalResults = result.totalResults;
      });
    } catch (error) {
      if (mounted) setState(() => _providerError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loadingProviderReviews = false;
          _loadingMoreProviderReviews = false;
        });
      }
    }
  }

  String _externalRating(String source) {
    final ratings = _externalRatings?['ratings'];
    if (ratings is List) {
      for (final entry in ratings.whereType<Map>()) {
        if ((entry['source']?.toString() ?? '').toLowerCase() == source.toLowerCase()) {
          final value = entry['value']?.toString().trim() ?? '';
          if (value.isNotEmpty && value != 'N/A') return value;
        }
      }
    }
    return 'Not available';
  }

  Future<void> _openRatingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  /// Builds the review editor, account reviews and global privacy-safe feed.
  @override
  Widget build(BuildContext context) {
    final title = widget.media?.title ?? 'Reviews';
    return Scaffold(
      appBar: AppBar(title: UniversalText('$title Reviews')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (widget.media != null) ...[
            _ratingSummary(widget.media!),
            _providerReviewsSection(),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const UniversalText('Write your review',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  UniversalText('Your rating: ${score.toStringAsFixed(0)}/10'),
                  Slider(
                    value: score,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: score.toStringAsFixed(0),
                    onChanged: (value) => setState(() => score = value),
                  ),
                  TextField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: tr('Short label (e.g. Mediocre, Excellent)'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: review,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: tr('Your review')),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: Text(
                      (AppController.instance.currentProfile?.username ?? '')
                              .trim()
                              .isEmpty
                          ? 'No profile username set'
                          : '@${AppController.instance.currentProfile!.username}',
                    ),
                    subtitle: const UniversalText(
                      'Public reviews use the username chosen for your active profile.',
                    ),
                  ),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const UniversalText('Written'),
                        selected: reviewType == 'written',
                        onSelected: (_) =>
                            setState(() => reviewType = 'written')),
                    ChoiceChip(
                        label: const UniversalText('Video link'),
                        selected: reviewType == 'video',
                        onSelected: (_) =>
                            setState(() => reviewType = 'video')),
                  ]),
                  if (reviewType == 'video') ...[
                    const SizedBox(height: 8),
                    TextField(
                        controller: videoUrl,
                        decoration: const InputDecoration(
                            labelText: 'Video review URL')),
                  ],
                  const SizedBox(height: 8),
                  const UniversalText('Publish this review to',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final destination in const [
                      'profile',
                      'story',
                      'community'
                    ])
                      FilterChip(
                          label: Text(destination == 'profile'
                              ? 'Profile'
                              : destination == 'story'
                                  ? 'Story (24h)'
                                  : 'Community'),
                          selected: destinations.contains(destination),
                          onSelected: (value) => setState(() => value
                              ? destinations.add(destination)
                              : destinations.remove(destination))),
                  ]),
                  if (destinations.contains('community'))
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                            controller: communityId,
                            decoration: const InputDecoration(
                                labelText: 'Community ID'))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: spoiler,
                      onChanged: (value) => setState(() => spoiler = value),
                      title: const UniversalText(
                          'Mark review as containing spoilers')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: translation,
                    onChanged: (value) => setState(() => translation = value),
                    title: const UniversalText(
                        'Translations on for global reviews'),
                  ),
                  FilledButton(
                    onPressed: _submit,
                    child: const UniversalText('Submit review'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const UniversalText(
            'Reviews from profiles on this account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          for (final entry in local) _reviewCard(entry, false),
          if (local.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: UniversalText('No profile reviews yet.'),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(
                child: UniversalText(
                  'Global reviews',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              FilterChip(
                label: const UniversalText('Translation ON'),
                selected: translation,
                onSelected: (value) => setState(() => translation = value),
              ),
            ],
          ),
          for (final entry in global) _reviewCard(entry, true),
        ],
      ),
    );
  }

  Widget _ratingSummary(MediaItem media) {
    final viewerRating = local.isEmpty
        ? null
        : local.map((entry) => entry.score).reduce((a, b) => a + b) /
            local.length;
    final metadata = _titleMetadata;
    final imdbId = metadata?.imdbId?.trim() ?? '';
    final imdbRating = (_externalRatings?['imdbRating']?.toString() ?? '').trim();
    final metascore = (_externalRatings?['metascore']?.toString() ?? '').trim();
    final scoreItems = <({String label, String value, VoidCallback? onTap})>[
      (
        label: 'TMDB',
        value: metadata?.voteAverage != null && metadata!.voteAverage! > 0
            ? '${metadata.voteAverage!.toStringAsFixed(1)}/10 (${metadata.voteCount ?? 0} votes)'
            : 'Not available',
        onTap: null,
      ),
      (
        label: 'IMDb',
        value: imdbRating.isNotEmpty && imdbRating != 'N/A'
            ? '$imdbRating/10${(_externalRatings?['imdbVotes']?.toString().trim().isNotEmpty ?? false) ? ' · ${_externalRatings!['imdbVotes']} votes' : ''}'
            : 'Not available',
        onTap: imdbId.isEmpty ? null : () => _openRatingUrl('https://www.imdb.com/title/$imdbId/'),
      ),
      (
        label: 'Rotten Tomatoes',
        value: _externalRating('Rotten Tomatoes'),
        onTap: () => _openRatingUrl('https://www.rottentomatoes.com/search?search=${Uri.encodeQueryComponent(media.title)}'),
      ),
      (
        label: 'Metascore',
        value: metascore.isNotEmpty && metascore != 'N/A' ? '$metascore/100' : 'Not available',
        onTap: null,
      ),
      (
        label: 'My profile reviews',
        value: viewerRating == null ? 'No reviews' : '${viewerRating.toStringAsFixed(1)}/10',
        onTap: null,
      ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scores & ratings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: scoreItems.map((item) => Container(
                constraints: const BoxConstraints(minWidth: 130, maxWidth: 210),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF202027),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: InkWell(
                  onTap: item.onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(item.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      if (item.onTap != null) const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Open source', style: TextStyle(fontSize: 10, color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
            if (metadata?.imdbId != null && metadata!.imdbId!.isNotEmpty &&
                _externalRatings?['configured'] == false) ...[
              const SizedBox(height: 10),
              const Text(
                'TMDB scores are available now. To show imported IMDb, Rotten Tomatoes, and Metascore ratings when available, add OMDB_API_KEY to Backend/.env and restart the backend.',
                style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
            ],
            if (_loadingProviderData) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _providerReviewsSection() {
    final metadata = _titleMetadata;
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Reviews for this title', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              if (_providerReviewTotalResults > 0)
                Text('$_providerReviewTotalResults', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Refresh title reviews',
                onPressed: _loadingProviderData ? null : _loadProviderTitleData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Public reviews supplied by TMDB. Load additional pages to browse the complete set returned by the provider.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
            if (_providerError != null) ...[
              const SizedBox(height: 8),
              Text(_providerError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ],
            if (_loadingProviderReviews && _providerReviews.isEmpty) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ] else if (metadata == null && !_loadingProviderData) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Provider reviews cannot be loaded until a TMDB title match is available.', style: TextStyle(color: Colors.white54)),
              ),
            ] else if (_providerReviews.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No public reviews are currently listed by TMDB for this title.', style: TextStyle(color: Colors.white54)),
              ),
            ] else ...[
              const SizedBox(height: 8),
              ..._providerReviews.map(_providerReviewCard),
              if (_providerReviewPage < _providerReviewTotalPages) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingMoreProviderReviews
                        ? null
                        : () => _loadProviderReviewPage(_providerReviewPage + 1),
                    icon: _loadingMoreProviderReviews
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMoreProviderReviews
                        ? 'Loading reviews…'
                        : 'Load more reviews (${_providerReviews.length} of $_providerReviewTotalResults)'),
                  ),
                ),
              ],
              if (_providerReviewTotalPages > 0 && _providerReviewPage >= _providerReviewTotalPages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('All ${_providerReviews.length} available TMDB reviews are loaded.', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _providerReviewCard(CinematicTitleReview review) {
    final meta = <String>[
      if (review.rating != null) 'Rating ${review.rating!.toStringAsFixed(1)}/10',
      if (review.createdAt != null) review.createdAt!.split('T').first,
    ].join(' · ');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(review.author, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          meta.isEmpty ? 'Public review' : meta,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(review.content, style: const TextStyle(color: Colors.white70, height: 1.45)),
          ),
          if (review.url != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openRatingUrl(review.url!),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('Open original review'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reviewCard(MediaReviewEntry entry, bool public) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(entry.username,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                UniversalText('${entry.score.toStringAsFixed(0)}/10'),
              ],
            ),
            const SizedBox(height: 4),
            Text(entry.label, style: const TextStyle(color: Colors.amber)),
            const SizedBox(height: 8),
            Text(entry.text, style: const TextStyle(color: Colors.white70)),
            if (public && translation)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: UniversalText('Translation: enabled',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            if (entry.publicationIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => _interact(entry, 'reaction'),
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const UniversalText('React')),
                  TextButton.icon(
                      onPressed: () => _interact(entry, 'comment'),
                      icon: const Icon(Icons.comment_outlined),
                      label: const UniversalText('Comment')),
                  TextButton.icon(
                      onPressed: () => _interact(entry, 'note'),
                      icon: const Icon(Icons.sticky_note_2_outlined),
                      label: const UniversalText('Note')),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  /// Saves the review locally and posts it to the authenticated backend when possible.
  Future<void> _submit() async {
    final text = review.text.trim();
    if (text.isEmpty) return;
    final media = widget.media;
    final profile = AppController.instance.currentProfile;
    final backend = AppController.instance.backendApi;
    if (media != null &&
        backend.isAuthenticated &&
        (profile == null || (profile.username).trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UniversalText(
              'Choose a profile username before publishing a public review.',
            ),
          ),
        );
      }
      return;
    }
    String? reviewId;
    final publicationIds = <String, String>{};
    if (media != null &&
        profile != null &&
        AppController.instance.backendApi.isAuthenticated) {
      try {
        final saved = await AppController.instance.backendApi.submitReview(
          mediaId: media.id,
          profileId: profile.id,
          score: score,
          label: label.text.trim(),
          text: text,
          reviewType: reviewType,
          videoUrl: videoUrl.text.trim().isEmpty ? null : videoUrl.text.trim(),
          spoiler: spoiler,
        );
        reviewId = (saved['review'] as Map?)?['id']?.toString();
        if (reviewId != null) {
          for (final destination in destinations) {
            if (destination == 'community' && communityId.text.trim().isEmpty) {
              continue;
            }
            try {
              final published =
                  await AppController.instance.backendApi.publishReview(
                reviewId: reviewId,
                mediaId: media.id,
                profileId: profile.id,
                destination: destination,
                destinationId:
                    destination == 'community' ? communityId.text.trim() : null,
                spoiler: spoiler,
              );
              final publication =
                  (published['publication'] as Map?)?['id']?.toString();
              if (publication != null) {
                publicationIds[destination] = publication;
              }
            } catch (_) {}
          }
        }
      } catch (_) {
        // The local review remains visible if the home server is temporarily offline.
      }
    }
    setState(() {
      local.add(MediaReviewEntry(
        username: profile?.username.trim().isNotEmpty == true
            ? '@${profile!.username}'
            : (profile?.name ?? 'Current Profile'),
        score: score,
        label: label.text.trim().isEmpty ? 'Review' : label.text.trim(),
        text: text,
        reviewId: reviewId,
        publicationIds: publicationIds,
      ));
    });
    review.clear();
  }

  Future<void> _interact(MediaReviewEntry entry, String type) async {
    final publicationId = entry.publicationIds['profile'] ??
        entry.publicationIds['story'] ??
        entry.publicationIds['community'];
    final profile = AppController.instance.currentProfile;
    if (publicationId == null || profile == null) return;
    String body = '';
    String? reaction;
    if (type == 'reaction') {
      reaction = 'like';
    } else {
      body = await _promptInteraction(type) ?? '';
      if (body.trim().isEmpty) return;
    }
    try {
      await AppController.instance.backendApi.addReviewInteraction(
        publicationId: publicationId,
        profileId: profile.id,
        type: type,
        body: body,
        reaction: reaction,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(type == 'reaction'
                ? 'Reaction added.'
                : '${type[0].toUpperCase()}${type.substring(1)} added.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<String?> _promptInteraction(String type) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(type == 'comment'
                    ? 'Comment on review'
                    : 'Add private note'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 5),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const UniversalText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const UniversalText('Save'))
                ]));
    controller.dispose();
    return value;
  }

  @override
  void dispose() {
    label.dispose();
    review.dispose();
    communityId.dispose();
    videoUrl.dispose();
    super.dispose();
  }
}
