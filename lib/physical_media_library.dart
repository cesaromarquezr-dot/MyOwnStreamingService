import 'package:flutter/material.dart';
import 'app_core.dart';
import 'details.dart';

const _physicalAccent = Color(0xFF8B7CFF);

class PhysicalMediaLibraryScreen extends StatelessWidget {
  const PhysicalMediaLibraryScreen({super.key});

  static const formats = <DiscFormat>[
    DiscFormat('Blu-ray', 'Blu-ray', Icons.album_rounded, 'HD movies and TV imported from Blu-ray discs'),
    DiscFormat('DVD', 'DVD', Icons.album_outlined, 'Movies, TV, and extras imported from DVDs'),
    DiscFormat('4K Ultra HD', '4K Ultra HD', Icons.high_quality_rounded, '4K UHD editions and their available HDR/audio metadata'),
    DiscFormat('CD', 'Audio CD', Icons.music_note_rounded, 'Albums and tracks imported from audio CDs'),
  ];

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    int countFor(DiscFormat f) => library.where((m) => _matches(m.discType, f.sourceType)).length;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: const Text('Physical Media'), backgroundColor: const Color(0xFF11111A)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Your imported disc collection', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Browse imported media by the format recorded in its disc metadata.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 18),
          ...formats.map((format) {
            final count = countFor(format);
            return Card(
              color: const Color(0xFF171722),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(backgroundColor: _physicalAccent.withValues(alpha: .18), child: Icon(format.icon, color: _physicalAccent)),
                title: Text(format.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${format.description}\n$count ${count == 1 ? 'item' : 'items'}', style: const TextStyle(color: Colors.white60, height: 1.35))),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhysicalMediaFormatScreen(format: format))),
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text('Only items with matching disc-format metadata appear in these categories. A file’s resolution alone is not used to guess which disc it came from.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class PhysicalMediaFormatScreen extends StatefulWidget {
  final DiscFormat format;
  const PhysicalMediaFormatScreen({super.key, required this.format});
  @override
  State<PhysicalMediaFormatScreen> createState() => _PhysicalMediaFormatScreenState();
}

class _PhysicalMediaFormatScreenState extends State<PhysicalMediaFormatScreen> {
  final _searchController = TextEditingController();
  String _sort = 'Title A–Z';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.format;
    final query = _searchController.text.trim().toLowerCase();
    final items = AppController.instance.library.where((m) =>
      _matches(m.discType, format.sourceType) &&
      (query.isEmpty || m.title.toLowerCase().contains(query) ||
       (m.discTitle ?? '').toLowerCase().contains(query) ||
       m.type.toLowerCase().contains(query) ||
       (m.releaseYear?.toString() ?? '').contains(query))
    ).toList();
    items.sort((a, b) {
      if (_sort == 'Newest year') return (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
      if (_sort == 'Oldest year') return (a.releaseYear ?? 9999).compareTo(b.releaseYear ?? 9999);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: Text(format.label), backgroundColor: const Color(0xFF11111A)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search title, year, or disc name',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty ? null : IconButton(
              tooltip: 'Clear search', icon: const Icon(Icons.close_rounded),
              onPressed: () { _searchController.clear(); setState(() {}); },
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [
          Expanded(child: Text('${items.length} ${items.length == 1 ? 'item' : 'items'}', style: const TextStyle(color: Colors.white60))),
          const Text('Sort: ', style: TextStyle(color: Colors.white60)),
          DropdownButton<String>(value: _sort, dropdownColor: const Color(0xFF171722), underline: const SizedBox.shrink(),
            items: const [DropdownMenuItem(value: 'Title A–Z', child: Text('Title A–Z')), DropdownMenuItem(value: 'Newest year', child: Text('Newest year')), DropdownMenuItem(value: 'Oldest year', child: Text('Oldest year'))],
            onChanged: (v) { if (v != null) setState(() => _sort = v); }),
        ])),
        Expanded(child: items.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(format.icon, color: _physicalAccent, size: 54), const SizedBox(height: 14), Text('No ${format.label} imports yet', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)), const SizedBox(height: 8), const Text('When you import media and its disc format is recorded, it will appear here automatically.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60))])))
          : ListView.builder(
              padding: const EdgeInsets.all(12), itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final detail = [item.type, if (item.releaseYear != null) '${item.releaseYear}', if ((item.discTitle ?? '').trim().isNotEmpty) item.discTitle!.trim()].join(' · ');
                return Card(color: const Color(0xFF171722), child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: (item.imageUrl ?? '').trim().isNotEmpty
                        ? Image.network(
                            item.imageUrl!, width: 52, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 52, height: 72,
                              child: Icon(Icons.movie_outlined, color: _physicalAccent),
                            ),
                          )
                        : const SizedBox(
                            width: 52, height: 72,
                            child: Icon(Icons.movie_outlined, color: _physicalAccent),
                          ),
                  ),
                  title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(detail, style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item))),
                ));
              },
            ),
        ),
      ]),
    );
  }
}

bool _matches(String? value, String expected) => (value ?? '').trim().toLowerCase() == expected.toLowerCase();

class DiscFormat {
  final String label;
  final String sourceType;
  final IconData icon;
  final String description;
  const DiscFormat(this.label, this.sourceType, this.icon, this.description);
}
