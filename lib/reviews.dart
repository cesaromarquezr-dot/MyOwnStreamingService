// TMDB-only public review browser for cinematic titles.
// The app's former local/profile/community review composer has been removed;
// the Reviews button now shows provider-sourced TMDB reviews only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'core/services/cinematic_title_metadata_service.dart';

class ReviewsHubScreen extends StatefulWidget {
  final MediaItem? media;
  final CinematicTitleMetadata? initialMetadata;

  const ReviewsHubScreen({super.key, this.media, this.initialMetadata});

  @override
  State<ReviewsHubScreen> createState() => _ReviewsHubScreenState();
}

class _ReviewsHubScreenState extends State<ReviewsHubScreen> {
  CinematicTitleMetadata? _metadata;
  final List<CinematicTitleReview> _reviews = <CinematicTitleReview>[];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  int _totalPages = 0;
  int _totalResults = 0;

  @override
  void initState() {
    super.initState();
    _metadata = widget.initialMetadata;
    if (widget.media != null) unawaited(_loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    final media = widget.media;
    if (media == null) return;
    if (!CinematicTitleMetadataService.isConfigured) {
      setState(() => _error = 'TMDB is not configured. Add the TMDB credential to Backend/.env and restart the backend.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _reviews.clear();
      _page = 0;
      _totalPages = 0;
      _totalResults = 0;
    });
    try {
      final metadata = _metadata ?? await CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: media.isSeries,
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (!mounted) return;
      _metadata = metadata;
      if (metadata == null) {
        setState(() => _error = 'No exact TMDB title match was found. No local title or metadata has been changed.');
        return;
      }
      await _loadPage(1, first: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPage(int page, {bool first = false}) async {
    final metadata = _metadata;
    if (metadata == null || page < 1 || _loadingMore) return;
    if (first) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await CinematicTitleMetadataService.lookupReviewsPage(
        providerId: metadata.providerId,
        isTv: metadata.isTv,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        final existing = _reviews.map((review) => review.id ?? '${review.author}|${review.createdAt}|${review.content.hashCode}').toSet();
        for (final review in result.reviews) {
          final key = review.id ?? '${review.author}|${review.createdAt}|${review.content.hashCode}';
          if (existing.add(key)) _reviews.add(review);
        }
        _page = result.page;
        _totalPages = result.totalPages;
        _totalResults = result.totalResults;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openReview(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final metadata = _metadata;
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090909),
        title: Text('${media?.title ?? 'TMDB'} Reviews', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Refresh TMDB reviews',
            onPressed: _loading ? null : _loadFirstPage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: media == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('Open Reviews from a movie or show details page to browse its TMDB reviews.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                Text(media.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('Public reviews provided by TMDB. MyOwnStreamingService does not collect, publish, or mix in its own reviews.', style: TextStyle(color: Colors.white54, height: 1.4)),
                if (metadata != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('TMDB user score', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            Text(metadata.voteAverage != null && metadata.voteAverage! > 0 ? '${metadata.voteAverage!.toStringAsFixed(1)}/10' : 'Not available', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ])),
                          if ((metadata.voteCount ?? 0) > 0) Text('${metadata.voteCount} votes', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_loading && _reviews.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
                  if (metadata == null) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _loadFirstPage, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))),
                ],
                if (!_loading && metadata != null && _reviews.isEmpty && _error == null)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No public reviews are currently listed by TMDB for this title.', style: TextStyle(color: Colors.white60))),
                if (_reviews.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(children: [const Expanded(child: Text('REVIEWS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2))), Text('$_totalResults available', style: const TextStyle(color: Colors.white54, fontSize: 12))]),
                  const SizedBox(height: 8),
                  for (final review in _reviews)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        title: Text(review.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(<String>[
                          if (review.rating != null) 'Rating ${review.rating!.toStringAsFixed(1)}/10',
                          if (review.createdAt != null) review.createdAt!.split('T').first,
                        ].join(' · ').isEmpty ? 'Public TMDB review' : <String>[
                          if (review.rating != null) 'Rating ${review.rating!.toStringAsFixed(1)}/10',
                          if (review.createdAt != null) review.createdAt!.split('T').first,
                        ].join(' · '), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        children: [
                          Align(alignment: Alignment.centerLeft, child: SelectableText(review.content, style: const TextStyle(color: Colors.white70, height: 1.5))),
                          if (review.url != null && review.url!.trim().isNotEmpty)
                            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _openReview(review.url!), icon: const Icon(Icons.open_in_new_rounded, size: 15), label: const Text('Open original review on TMDB'))),
                        ],
                      ),
                    ),
                  if (_page < _totalPages)
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: _loadingMore ? null : () => _loadPage(_page + 1),
                      icon: _loadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more_rounded),
                      label: Text(_loadingMore ? 'Loading…' : 'Load more TMDB reviews (${_reviews.length} of $_totalResults)'),
                    )),
                ],
              ],
            ),
    );
  }
}
