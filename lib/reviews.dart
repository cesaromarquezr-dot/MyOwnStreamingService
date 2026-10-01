// Media review UI: private profile reviews plus privacy-safe global reviews.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'localization.dart';

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

  const ReviewsHubScreen({super.key, this.media});

  @override
  State<ReviewsHubScreen> createState() => _ReviewsHubScreenState();
}

class _ReviewsHubScreenState extends State<ReviewsHubScreen> {
  double score = 10;
  final TextEditingController label = TextEditingController(text: 'Excellent');
  final TextEditingController review = TextEditingController();
  final TextEditingController username = TextEditingController(text: 'SpideyFan0804');
  bool translation = true;
  bool spoiler = false;
  String reviewType = 'written';
  final Set<String> destinations = <String>{'profile'};
  final TextEditingController communityId = TextEditingController();
  final TextEditingController videoUrl = TextEditingController();

  final List<MediaReviewEntry> local = <MediaReviewEntry>[];
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

  /// Builds the review editor, account reviews and global privacy-safe feed.
  @override
  Widget build(BuildContext context) {
    final title = widget.media?.title ?? 'Reviews';
    return Scaffold(
      appBar: AppBar(title: UniversalText('$title Reviews')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (widget.media != null) _ratingSummary(widget.media!),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const UniversalText('Write your review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
                  TextField(
                    controller: username,
                    decoration: InputDecoration(
                      labelText: tr('Global review username'),
                      helperText: tr('Only this username is shown publicly; never your email.'),
                    ),
                  ),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('Written'), selected: reviewType == 'written', onSelected: (_) => setState(() => reviewType = 'written')),
                    ChoiceChip(label: const Text('Video link'), selected: reviewType == 'video', onSelected: (_) => setState(() => reviewType = 'video')),
                  ]),
                  if (reviewType == 'video') ...[
                    const SizedBox(height: 8),
                    TextField(controller: videoUrl, decoration: const InputDecoration(labelText: 'Video review URL')),
                  ],
                  const SizedBox(height: 8),
                  const UniversalText('Publish this review to', style: TextStyle(fontWeight: FontWeight.w800)),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final destination in const ['profile', 'story', 'community'])
                      FilterChip(label: Text(destination == 'profile' ? 'Profile' : destination == 'story' ? 'Story (24h)' : 'Community'), selected: destinations.contains(destination), onSelected: (value) => setState(() => value ? destinations.add(destination) : destinations.remove(destination))),
                  ]),
                  if (destinations.contains('community'))
                    Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: communityId, decoration: const InputDecoration(labelText: 'Community ID'))),
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: spoiler, onChanged: (value) => setState(() => spoiler = value), title: const UniversalText('Mark review as containing spoilers')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: translation,
                    onChanged: (value) => setState(() => translation = value),
                    title: const UniversalText('Translations on for global reviews'),
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
          const UniversalText('Reviews from profiles on this account',
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
                child: UniversalText('Global reviews',
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
        : local.map((entry) => entry.score).reduce((a, b) => a + b) / local.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const UniversalText('Official / critic rating', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(media.rating == null ? 'Not available' : '${media.rating}/10${media.ratingReason == null ? '' : ' • ${media.ratingReason}'}'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const UniversalText('Viewer rating', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(viewerRating == null ? 'No reviews' : '${viewerRating.toStringAsFixed(1)}/10'),
                ],
              ),
            ),
          ],
        ),
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
                Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w900)),
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
                child: UniversalText('Translation: enabled', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            if (entry.publicationIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  TextButton.icon(onPressed: () => _interact(entry, 'reaction'), icon: const Icon(Icons.favorite_border_rounded), label: const Text('React')),
                  TextButton.icon(onPressed: () => _interact(entry, 'comment'), icon: const Icon(Icons.comment_outlined), label: const Text('Comment')),
                  TextButton.icon(onPressed: () => _interact(entry, 'note'), icon: const Icon(Icons.sticky_note_2_outlined), label: const Text('Note')),
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
    String? reviewId;
    final publicationIds = <String, String>{};
    if (media != null && profile != null && AppController.instance.backendApi.isAuthenticated) {
      try {
        final saved = await AppController.instance.backendApi.submitReview(
          mediaId: media.id,
          profileId: profile.id,
          score: score,
          label: label.text.trim(),
          text: text,
          globalUsername: username.text.trim(),
          reviewType: reviewType,
          videoUrl: videoUrl.text.trim().isEmpty ? null : videoUrl.text.trim(),
          spoiler: spoiler,
        );
        reviewId = (saved['review'] as Map?)?['id']?.toString();
        if (reviewId != null) {
          for (final destination in destinations) {
            if (destination == 'community' && communityId.text.trim().isEmpty) continue;
            try {
              final published = await AppController.instance.backendApi.publishReview(
                reviewId: reviewId!,
                mediaId: media.id,
                profileId: profile.id,
                destination: destination,
                destinationId: destination == 'community' ? communityId.text.trim() : null,
                spoiler: spoiler,
              );
              final publication = (published['publication'] as Map?)?['id']?.toString();
              if (publication != null) publicationIds[destination] = publication;
            } catch (_) {}
          }
        }
      } catch (_) {
        // The local review remains visible if the home server is temporarily offline.
      }
    }
    setState(() {
      local.add(MediaReviewEntry(
        username: profile?.name ?? 'Current Profile',
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
    final publicationId = entry.publicationIds['profile'] ?? entry.publicationIds['story'] ?? entry.publicationIds['community'];
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(type == 'reaction' ? 'Reaction added.' : '${type[0].toUpperCase()}${type.substring(1)} added.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<String?> _promptInteraction(String type) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(type == 'comment' ? 'Comment on review' : 'Add private note'), content: TextField(controller: controller, autofocus: true, minLines: 2, maxLines: 5), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))]));
    controller.dispose();
    return value;
  }

  @override
  void dispose() {
    label.dispose();
    review.dispose();
    username.dispose();
    communityId.dispose();
    videoUrl.dispose();
    super.dispose();
  }
}
