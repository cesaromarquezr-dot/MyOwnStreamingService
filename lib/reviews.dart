// Media review UI: private profile reviews plus privacy-safe global reviews.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'localization.dart';

class MediaReviewEntry {
  final String username;
  final double score;
  final String label;
  final String text;

  const MediaReviewEntry({
    required this.username,
    required this.score,
    required this.label,
    required this.text,
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
    setState(() {
      local.add(MediaReviewEntry(
        username: profile?.name ?? 'Current Profile',
        score: score,
        label: label.text.trim().isEmpty ? 'Review' : label.text.trim(),
        text: text,
      ));
    });
    if (media != null && profile != null && AppController.instance.backendApi.isAuthenticated) {
      try {
        await AppController.instance.backendApi.submitReview(
          mediaId: media.id,
          profileId: profile.id,
          score: score,
          label: label.text.trim(),
          text: text,
          globalUsername: username.text.trim(),
        );
      } catch (_) {
        // The local review remains visible if the home server is temporarily offline.
      }
    }
    review.clear();
  }

  @override
  void dispose() {
    label.dispose();
    review.dispose();
    username.dispose();
    super.dispose();
  }
}
