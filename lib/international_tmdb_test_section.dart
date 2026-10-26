import 'package:flutter/material.dart';

import 'core/services/cinematic_title_metadata_service.dart';

/// On-demand smoke test for TMDB lookups across a range of countries,
/// languages, and both movie and TV catalogs.
/// These are test fixtures only; they are never inserted into the user's library.
class InternationalTmdbTestSection extends StatefulWidget {
  const InternationalTmdbTestSection({super.key});

  @override
  State<InternationalTmdbTestSection> createState() =>
      _InternationalTmdbTestSectionState();
}

class _InternationalTmdbTestSectionState
    extends State<InternationalTmdbTestSection> {
  static const _samples = <_InternationalTitleSample>[
    _InternationalTitleSample('Una película de huevos', isTv: false, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('Candidato Honesto', isTv: false, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('La leyenda de la Nahuala', isTv: false, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('El Chavo del Ocho', isTv: true, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('Una familia de diez', isTv: true, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('La familia P. Luche', isTv: true, country: 'Mexico', language: 'Spanish'),
    _InternationalTitleSample('오징어 게임', isTv: true, country: 'South Korea', language: 'Korean'),
    _InternationalTitleSample('기생충', isTv: false, country: 'South Korea', language: 'Korean'),
    _InternationalTitleSample('Élite', isTv: true, country: 'Spain', language: 'Spanish'),
    _InternationalTitleSample('부산행', isTv: false, country: 'South Korea', language: 'Korean'),
    // India
    _InternationalTitleSample('Dangal', isTv: false, country: 'India', language: 'Hindi'),
    _InternationalTitleSample('3 Idiots', isTv: false, country: 'India', language: 'Hindi'),
    _InternationalTitleSample('RRR', isTv: false, country: 'India', language: 'Telugu'),
    _InternationalTitleSample('Baahubali: The Beginning', isTv: false, country: 'India', language: 'Telugu'),
    _InternationalTitleSample('The Family Man', isTv: true, country: 'India', language: 'Hindi'),
    // Japan
    _InternationalTitleSample('Your Name', isTv: false, country: 'Japan', language: 'Japanese'),
    _InternationalTitleSample('Spirited Away', isTv: false, country: 'Japan', language: 'Japanese'),
    _InternationalTitleSample('Attack on Titan', isTv: true, country: 'Japan', language: 'Japanese'),
    // Brazil
    _InternationalTitleSample('City of God', isTv: false, country: 'Brazil', language: 'Portuguese'),
    _InternationalTitleSample('Elite Squad', isTv: false, country: 'Brazil', language: 'Portuguese'),
    _InternationalTitleSample('3%', isTv: true, country: 'Brazil', language: 'Portuguese'),
    _InternationalTitleSample('A Dog’s Will', isTv: false, country: 'Brazil', language: 'Portuguese'),
    // Portugal
    _InternationalTitleSample('Glória', isTv: true, country: 'Portugal', language: 'Portuguese'),
    _InternationalTitleSample('The Gilded Cage', isTv: false, country: 'Portugal', language: 'Portuguese/French'),
    // Turkey
    _InternationalTitleSample('Miracle in Cell No. 7', isTv: false, country: 'Turkey', language: 'Turkish'),
    _InternationalTitleSample('The Protector', isTv: true, country: 'Turkey', language: 'Turkish'),
    _InternationalTitleSample('Ethos', isTv: true, country: 'Turkey', language: 'Turkish'),
    // France
    _InternationalTitleSample('Amélie', isTv: false, country: 'France', language: 'French'),
    _InternationalTitleSample('The Intouchables', isTv: false, country: 'France', language: 'French'),
    _InternationalTitleSample('Lupin', isTv: true, country: 'France', language: 'French'),
    // China
    _InternationalTitleSample('Wolf Warrior 2', isTv: false, country: 'China', language: 'Mandarin'),
    _InternationalTitleSample('The Wandering Earth', isTv: false, country: 'China', language: 'Mandarin'),
    _InternationalTitleSample('Hidden Blade', isTv: false, country: 'China', language: 'Mandarin'),
    // Additional regions
    _InternationalTitleSample('Dark', isTv: true, country: 'Germany', language: 'German'),
    _InternationalTitleSample('Good Bye, Lenin!', isTv: false, country: 'Germany', language: 'German'),
    _InternationalTitleSample('La casa de papel', isTv: true, country: 'Spain', language: 'Spanish'),
    _InternationalTitleSample('Relatos salvajes', isTv: false, country: 'Argentina', language: 'Spanish'),
    _InternationalTitleSample('Bad Genius', isTv: false, country: 'Thailand', language: 'Thai'),
    _InternationalTitleSample('Laskar Pelangi', isTv: false, country: 'Indonesia', language: 'Indonesian'),
    // More countries and regional industries
    _InternationalTitleSample('Coco', isTv: false, country: 'Mexico/United States', language: 'English/Spanish'),
    _InternationalTitleSample('The Secret in Their Eyes', isTv: false, country: 'Argentina', language: 'Spanish'),
    _InternationalTitleSample('Narcos', isTv: true, country: 'Colombia/United States', language: 'Spanish/English'),
    _InternationalTitleSample('The Platform', isTv: false, country: 'Spain', language: 'Spanish'),
    _InternationalTitleSample('Roma', isTv: false, country: 'Mexico', language: 'Spanish/Mixtec'),
    _InternationalTitleSample('The Raid', isTv: false, country: 'Indonesia', language: 'Indonesian'),
    _InternationalTitleSample('The Night Comes for Us', isTv: false, country: 'Indonesia', language: 'Indonesian'),
    _InternationalTitleSample('Hello, Love, Goodbye', isTv: false, country: 'Philippines', language: 'Filipino/English'),
    _InternationalTitleSample('Trese', isTv: true, country: 'Philippines', language: 'Filipino/English'),
    _InternationalTitleSample('A Separation', isTv: false, country: 'Iran', language: 'Persian'),
    _InternationalTitleSample('The Salesman', isTv: false, country: 'Iran', language: 'Persian'),
    _InternationalTitleSample('The Square', isTv: false, country: 'Egypt', language: 'Arabic'),
    _InternationalTitleSample('Finding Ola', isTv: true, country: 'Egypt', language: 'Arabic'),
    _InternationalTitleSample('Lionheart', isTv: false, country: 'Nigeria', language: 'English'),
    _InternationalTitleSample('Blood & Water', isTv: true, country: 'South Africa', language: 'English'),
    _InternationalTitleSample('The Boy Who Harnessed the Wind', isTv: false, country: 'Malawi/United Kingdom', language: 'English/Chichewa'),
    _InternationalTitleSample('아가씨', isTv: false, country: 'South Korea', language: 'Korean'),
    _InternationalTitleSample('킹덤', isTv: true, country: 'South Korea', language: 'Korean'),
    _InternationalTitleSample('In the Mood for Love', isTv: false, country: 'Hong Kong', language: 'Cantonese'),
    _InternationalTitleSample('Infernal Affairs', isTv: false, country: 'Hong Kong', language: 'Cantonese'),
    _InternationalTitleSample('Yi Yi', isTv: false, country: 'Taiwan', language: 'Mandarin'),
    _InternationalTitleSample('Someday or One Day', isTv: true, country: 'Taiwan', language: 'Mandarin'),
    _InternationalTitleSample('Cinema Paradiso', isTv: false, country: 'Italy', language: 'Italian'),
    _InternationalTitleSample('Gomorrah', isTv: true, country: 'Italy', language: 'Italian'),
    _InternationalTitleSample('The Lives of Others', isTv: false, country: 'Germany', language: 'German'),
    _InternationalTitleSample('The Hunt', isTv: false, country: 'Denmark', language: 'Danish'),
    _InternationalTitleSample('Borgen', isTv: true, country: 'Denmark', language: 'Danish'),
    _InternationalTitleSample('The Girl with the Dragon Tattoo', isTv: false, country: 'Sweden', language: 'Swedish'),
    _InternationalTitleSample('Ragnarok', isTv: true, country: 'Norway', language: 'Norwegian'),
    _InternationalTitleSample('The Bridge', isTv: true, country: 'Sweden/Denmark', language: 'Swedish/Danish'),
    _InternationalTitleSample('Cold War', isTv: false, country: 'Poland', language: 'Polish/French'),
    _InternationalTitleSample('The Mire', isTv: true, country: 'Poland', language: 'Polish'),
    _InternationalTitleSample('The Lunchbox', isTv: false, country: 'India', language: 'Hindi'),
    _InternationalTitleSample('Panchayat', isTv: true, country: 'India', language: 'Hindi'),
    _InternationalTitleSample('택시운전사', isTv: false, country: 'South Korea', language: 'Korean'),
    _InternationalTitleSample('Shoplifters', isTv: false, country: 'Japan', language: 'Japanese'),
    _InternationalTitleSample('Midnight Diner', isTv: true, country: 'Japan', language: 'Japanese'),
    _InternationalTitleSample('The Wandering Earth II', isTv: false, country: 'China', language: 'Mandarin'),
    _InternationalTitleSample('Reset', isTv: true, country: 'China', language: 'Mandarin'),
    _InternationalTitleSample('The Teacher’s Lounge', isTv: false, country: 'Germany', language: 'German'),
    _InternationalTitleSample('The Last King of Scotland', isTv: false, country: 'Uganda/United Kingdom', language: 'English'),
    _InternationalTitleSample('The Gods Must Be Crazy', isTv: false, country: 'Botswana/South Africa', language: 'English/Afrikaans'),
    _InternationalTitleSample('The Raid 2', isTv: false, country: 'Indonesia', language: 'Indonesian'),
    _InternationalTitleSample('The Chestnut Man', isTv: true, country: 'Denmark', language: 'Danish'),
  ];

  final Map<String, _InternationalTestResult> _results = {};
  bool _running = false;
  int _completed = 0;

  Future<void> _runTests() async {
    if (_running || !CinematicTitleMetadataService.isConfigured) return;
    setState(() {
      _running = true;
      _completed = 0;
      _results.clear();
    });
    // Sequential requests reduce the chance of hitting API rate limits.
    for (final sample in _samples) {
      try {
        final metadata = await CinematicTitleMetadataService.lookupTitle(
          title: sample.title,
          isTv: sample.isTv,
        );
        if (!mounted) return;
        setState(() {
          _results[sample.title] = _InternationalTestResult(metadata: metadata);
          _completed++;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _results[sample.title] = _InternationalTestResult(error: error.toString());
          _completed++;
        });
      }
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.values.where((r) => r.metadata != null).length;
    return Card(
      color: const Color(0xFF17171C),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.public, color: Color(0xFF9C8CF0)),
        title: const Text(
          'International TMDB test titles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _results.isEmpty
              ? 'Verify movies and shows from a worldwide mix of countries and languages'
              : 'Matched $passed of ${_results.length} checked titles',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          const Text(
            'Runs live title lookups using the configured TMDB API. These examples are only test fixtures and will not be added to your library.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _running ? null : _runTests,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore),
              label: Text(_running
                  ? 'Testing international titles ($_completed/${_samples.length})…'
                  : 'Run worldwide content test'),
            ),
          ),
          const SizedBox(height: 8),
          for (final sample in _samples) _buildResultRow(sample),
        ],
      ),
    );
  }

  Widget _buildResultRow(_InternationalTitleSample sample) {
    final result = _results[sample.title];
    final metadata = result?.metadata;
    final imageUrl = metadata?.posterUrl;
    final status = result == null
        ? 'Not tested'
        : metadata != null
            ? 'TMDB match found'
            : (result.error != null ? 'Request failed' : 'No exact title match');
    final color = result == null
        ? Colors.white38
        : metadata != null
            ? Colors.greenAccent
            : Colors.orangeAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 48,
              height: 70,
              child: imageUrl == null
                  ? Container(
                      color: Colors.white10,
                      child: const Icon(Icons.movie_outlined, color: Colors.white38),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sample.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Text('${sample.isTv ? 'TV show' : 'Movie'} • ${sample.country} • ${sample.language}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 3),
                Text(status, style: TextStyle(color: color, fontSize: 12)),
                if (metadata != null)
                  Text(
                    '${metadata.title} • ${metadata.originalLanguage ?? 'language unavailable'}'
                    '${metadata.voteAverage == null ? '' : ' • ${metadata.voteAverage!.toStringAsFixed(1)}/10'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                if (result?.error != null)
                  Text(result!.error!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
              ],
            ),
          ),
          Icon(
            result == null
                ? Icons.hourglass_empty
                : metadata != null
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _InternationalTitleSample {
  const _InternationalTitleSample(
    this.title, {
    required this.isTv,
    required this.country,
    required this.language,
  });

  final String title;
  final bool isTv;
  final String country;
  final String language;
}

class _InternationalTestResult {
  const _InternationalTestResult({this.metadata, this.error});

  final CinematicTitleMetadata? metadata;
  final String? error;
}
