import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'core/services/disc_ingestion_service.dart';

const _discAccent = Color(0xFF8B7CFF);

/// Desktop-first workflow for MakeMKV ripping, verification, and library intake.
/// Firmware flashing is intentionally outside the app's automation boundary.
class DiscIngestionCenterScreen extends StatefulWidget {
  const DiscIngestionCenterScreen({super.key});

  @override
  State<DiscIngestionCenterScreen> createState() => _DiscIngestionCenterScreenState();
}

class _DiscIngestionCenterScreenState extends State<DiscIngestionCenterScreen> {
  final _service = DiscIngestionService.instance;
  final _executableController = TextEditingController();
  final _destinationController = TextEditingController();
  final _folderController = TextEditingController();
  final _manualMkvController = TextEditingController();
  final _titleSelectorController = TextEditingController(text: 'all');

  List<MakeMkvDrive> _drives = const [];
  List<MakeMkvTitle> _discTitles = const [];
  final Set<int> _selectedTitleIndexes = <int>{};
  bool _scanningTitles = false;
  int? _selectedDrive;
  bool _loading = true;
  bool _scanning = false;
  bool _testingDestination = false;
  bool _rightsConfirmed = false;
  bool _showAdvanced = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChange);
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    if (!mounted) return;
    _executableController.text = _service.executablePath;
    _destinationController.text = _service.destinationRoot;
    _folderController.text = _defaultFolderName();
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    _executableController.dispose();
    _destinationController.dispose();
    _folderController.dispose();
    _manualMkvController.dispose();
    _titleSelectorController.dispose();
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  String _defaultFolderName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Disc_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _saveConfiguration() async {
    try {
      await _service.configure(
        executablePath: _executableController.text,
        destinationRoot: _destinationController.text,
      );
      _message('Configuration saved on this device.');
    } catch (error) {
      _message('Unable to save settings: $error', isError: true);
    }
  }

  Future<void> _detectDrives() async {
    setState(() {
      _scanning = true;
      _localError = null;
    });
    try {
      await _service.configure(executablePath: _executableController.text);
      final drives = await _service.discoverDrives(executablePath: _executableController.text);
      if (!mounted) return;
      setState(() {
        _drives = drives;
        if (_selectedDrive == null || !drives.any((drive) => drive.index == _selectedDrive)) {
          _selectedDrive = drives.isEmpty ? null : drives.first.index;
        }
      });
      _message(drives.isEmpty ? 'MakeMKV did not report any visible optical drives.' : 'Found ${drives.length} visible optical drive(s).');
    } catch (error) {
      if (mounted) setState(() => _localError = error.toString());
      _message('Drive detection failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _scanDiscTitles() async {
    if (_selectedDrive == null) { _message('Detect and select an optical drive first.', isError: true); return; }
    setState(() { _scanningTitles = true; _localError = null; });
    try {
      final titles = await _service.scanDiscTitles(driveIndex: _selectedDrive!, executablePath: _executableController.text);
      if (!mounted) return;
      setState(() { _discTitles = titles; _selectedTitleIndexes..clear()..addAll(titles.where((t) => _looksLikeFeature(t)).map((t) => t.index)); });
      _message('Scanned ${titles.length} title(s). Review durations and track details before ripping.');
    } catch (error) { if (mounted) setState(() => _localError = error.toString()); _message('Disc title scan failed: $error', isError: true); }
    finally { if (mounted) setState(() => _scanningTitles = false); }
  }

  bool _looksLikeFeature(MakeMkvTitle title) {
    final match = RegExp(r'^(\d+):([0-5]\d):([0-5]\d)$').firstMatch(title.duration);
    if (match == null) return false;
    final seconds = int.parse(match[1]!) * 3600 + int.parse(match[2]!) * 60 + int.parse(match[3]!);
    return seconds >= 40 * 60;
  }

  Future<void> _testDestination() async {
    setState(() => _testingDestination = true);
    try {
      await _service.testDestination(_destinationController.text);
      await _service.configure(destinationRoot: _destinationController.text);
      _message('Output folder is writable.');
    } catch (error) {
      _message('Output folder check failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _testingDestination = false);
    }
  }

  Future<void> _startRip() async {
    if (_selectedDrive == null) {
      _message('Detect drives and select an optical drive first.', isError: true);
      return;
    }
    if (!_rightsConfirmed) {
      _message('Confirm that you are authorized to make this copy.', isError: true);
      return;
    }
    final executable = _executableController.text.trim();
    final outputRoot = _destinationController.text.trim();
    final folder = _folderController.text.trim();
    final selector = _titleSelectorController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start MakeMKV job?'),
        content: Text('Read from ${_selectedDriveLabel()} and write files to the selected output folder:\n\n${_combinePath(outputRoot, folder)}\n\nThe "all" title selector can include extras and multiple titles. The app will not flash drive firmware.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start rip')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final drive = _drives.firstWhere((item) => item.index == _selectedDrive);
      final job = await _service.startRip(
        driveIndex: drive.index,
        driveName: drive.name,
        titleSelector: selector,
        outputRoot: outputRoot,
        folderName: folder,
        rightsConfirmed: _rightsConfirmed,
        executablePath: executable,
      );
      _message('Started job ${job.id}. You can leave this page open to monitor progress.');
      _folderController.text = _defaultFolderName();
    } catch (error) {
      _message('Unable to start rip: $error', isError: true);
    }
  }

  String _selectedDriveLabel() {
    for (final drive in _drives) {
      if (drive.index == _selectedDrive) return '${drive.name}${drive.discName.isEmpty ? '' : ' · ${drive.discName}'}';
    }
    return 'drive $_selectedDrive';
  }

  String _combinePath(String root, String child) {
    if (root.isEmpty) return child;
    if (root.endsWith('/') || root.endsWith('\\')) return '$root$child';
    return '$root${Platform.pathSeparator}$child';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = -1;
    do {
      size /= 1024;
      unit++;
    } while (size >= 1024 && unit < units.length - 1);
    return '${size.toStringAsFixed(size >= 100 ? 0 : size >= 10 ? 1 : 2)} ${units[unit]}';
  }

  Future<void> _showImportDialog(String filePath) async {
    final validation = await _service.validateMkv(filePath);
    if (!mounted) return;
    if (!validation.passed) {
      _message(validation.error ?? 'The file did not pass the MKV header check.', isError: true);
      return;
    }

    final titleController = TextEditingController(text: _service.suggestTitleFromPath(filePath));
    final yearController = TextEditingController(text: _yearFromPath(filePath));
    final artworkController = TextEditingController();
    final discTitleController = TextEditingController();
    String kind = 'movie';
    String contentCategory = 'Main Feature';
    String discType = _defaultDiscType();
    String? parentMediaId;
    final candidateParents = AppController.instance.library.where((item) {
      final type = item.type.toLowerCase().replaceAll(RegExp(r'[_\s]+'), '');
      return item.id.trim().isNotEmpty && !item.tags.any((tag) => tag.toLowerCase() == 'disc extra') &&
          (type == 'movie' || type == 'tvshow' || type == 'show' || type == 'series');
    }).toList(growable: false)..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    var submitting = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Review and import MKV'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(filePath, style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text('Container signature passed · ${_formatBytes(validation.sizeBytes)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    const SizedBox(height: 14),
                    TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Title *')),
                    const SizedBox(height: 8),
                    TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Release year (optional)')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Library type'),
                      items: const [
                        DropdownMenuItem(value: 'movie', child: Text('Movie')),
                        DropdownMenuItem(value: 'tv', child: Text('TV / episode')),
                        DropdownMenuItem(value: 'music', child: Text('Music')),
                      ],
                      onChanged: (value) { if (value != null) setDialogState(() => kind = value); },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: contentCategory,
                      decoration: const InputDecoration(labelText: 'Content category'),
                      items: const [
                        DropdownMenuItem(value: 'Main Feature', child: Text('Main feature / movie')),
                        DropdownMenuItem(value: 'Episode', child: Text('TV episode')),
                        DropdownMenuItem(value: 'Deleted Scene', child: Text('Deleted scene')),
                        DropdownMenuItem(value: 'Audio Commentary', child: Text('Audio commentary')),
                        DropdownMenuItem(value: 'Behind-the-Scenes Featurette', child: Text('Behind the scenes / featurette')),
                        DropdownMenuItem(value: 'Documentary', child: Text('Documentary')),
                        DropdownMenuItem(value: 'Trailer', child: Text('Trailer')),
                        DropdownMenuItem(value: 'Alternate Cut', child: Text('Alternate cut / extended scene')),
                        DropdownMenuItem(value: 'Other Bonus Clip', child: Text('Other bonus clip')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          contentCategory = value;
                          if (value == 'Main Feature' || value == 'Episode') {
                            parentMediaId = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: discType,
                      decoration: const InputDecoration(labelText: 'Physical source format'),
                      items: const [
                        DropdownMenuItem(value: '4K Ultra HD', child: Text('4K Ultra HD Blu-ray')),
                        DropdownMenuItem(value: 'Blu-ray', child: Text('Blu-ray')),
                        DropdownMenuItem(value: 'DVD', child: Text('DVD')),
                        DropdownMenuItem(value: 'Audio CD', child: Text('Audio CD')),
                      ],
                      onChanged: (value) { if (value != null) setDialogState(() => discType = value); },
                    ),
                    if (contentCategory != 'Main Feature' && contentCategory != 'Episode') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: parentMediaId ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Attach bonus content to movie/show (optional)'),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(value: '', child: Text('Standalone / not linked')),
                          ...candidateParents.map((parent) => DropdownMenuItem<String>(
                            value: parent.id,
                            child: Text('${parent.title}${parent.releaseYear == null ? '' : ' (${parent.releaseYear})'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (value) => setDialogState(() => parentMediaId = value == null || value.isEmpty ? null : value),
                      ),
                      const SizedBox(height: 6),
                      const Text('Linked bonus content appears under Details → Information → Extras & Special Features. DVD menus, IFO/BUP navigation and interactive mini-games are not ordinary MKV files; preserve the original disc or a lawful full-disc image for those elements.', style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.35)),
                    ],
                    const SizedBox(height: 8),
                    TextField(controller: discTitleController, decoration: const InputDecoration(labelText: 'Disc / edition label (optional)')),
                    const SizedBox(height: 8),
                    TextField(controller: artworkController, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Poster artwork URL (optional)', hintText: 'https://…')),
                    const SizedBox(height: 12),
                    const Text('This checks the Matroska/EBML header only. It does not prove the whole file is playable. A raw filesystem path will not be saved as a playback URL; connect the file through your media-server gateway for playback. Bonus categories are stored as tags so deleted scenes, commentaries, trailers and featurettes remain identifiable.', style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.35)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: submitting ? null : () async {
                  final title = titleController.text.trim();
                  final yearText = yearController.text.trim();
                  final year = yearText.isEmpty ? null : int.tryParse(yearText);
                  final artwork = artworkController.text.trim();
                  if (title.isEmpty) {
                    _dialogMessage(dialogContext, 'A title is required.');
                    return;
                  }
                  if (yearText.isNotEmpty && (year == null || year < 1888 || year > DateTime.now().year + 10)) {
                    _dialogMessage(dialogContext, 'Enter a valid release year.');
                    return;
                  }
                  if (artwork.isNotEmpty) {
                    final uri = Uri.tryParse(artwork);
                    if (uri == null || !uri.hasAuthority || uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
                      _dialogMessage(dialogContext, 'Artwork must be a stable HTTPS URL without credentials, query strings, or fragments.');
                      return;
                    }
                  }
                  setDialogState(() => submitting = true);
                  try {
                    final item = await _service.importMkvToLibrary(
                      filePath: filePath,
                      title: title,
                      mediaKind: kind,
                      discType: discType,
                      releaseYear: year,
                      artworkUrl: artwork,
                      discTitle: discTitleController.text,
                      contentCategory: contentCategory,
                      parentMediaId: parentMediaId,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (mounted) {
                      _message('Added "${item.title}" to the library catalog.');
                    }
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    setDialogState(() => submitting = false);
                    _dialogMessage(dialogContext, 'Import failed: $error');
                  }
                },
                icon: const Icon(Icons.library_add_check_rounded),
                label: Text(submitting ? 'Importing…' : 'Add to library'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      yearController.dispose();
      artworkController.dispose();
      discTitleController.dispose();
    }
  }

  void _dialogMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _defaultDiscType() {
    final selector = _drives.where((item) => item.index == _selectedDrive).map((item) => item.discName.toLowerCase()).join(' ');
    if (selector.contains('uhd') || selector.contains('4k')) return '4K Ultra HD';
    if (selector.contains('dvd')) return 'DVD';
    if (selector.contains('cd')) return 'Audio CD';
    return 'Blu-ray';
  }

  String _yearFromPath(String path) {
    final match = RegExp(r'\b(18\d{2}|19\d{2}|20\d{2}|21\d{2})\b').firstMatch(path);
    if (match == null) return '';
    final year = int.tryParse(match.group(0) ?? '');
    if (year == null || year < 1888 || year > DateTime.now().year + 10) return '';
    return year.toString();
  }

  Future<void> _importManualPath() async {
    final path = _manualMkvController.text.trim();
    if (path.isEmpty) {
      _message('Enter the full path to a completed MKV file.', isError: true);
      return;
    }
    await _showImportDialog(path);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _message('Could not open $url', isError: true);
    }
  }

  void _message(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final jobs = _service.jobs;
    final active = jobs.where((job) => job.status == DiscRipStatus.running).length;
    final completed = jobs.where((job) => job.status == DiscRipStatus.succeeded).length;
    final failed = jobs.where((job) => job.status == DiscRipStatus.failed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Disc Ingestion Center'), actions: [
        IconButton(
          tooltip: 'Import technical manifests',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiscImportManifestScreen())),
          icon: const Icon(Icons.fact_check_outlined),
        ),
        IconButton(tooltip: 'Open setup guide', onPressed: () => _showGuideDialog(context), icon: const Icon(Icons.menu_book_rounded)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2C2345), Color(0xFF15151E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.album_rounded, color: Color(0xFFFFD36E), size: 34),
                const SizedBox(height: 10),
                Text('Disc ingestion & ripping', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Monitor MakeMKV jobs, send output directly to a local or NAS folder, validate completed MKVs, and review metadata before adding it to the app catalog.', style: TextStyle(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _stat('Running', active, Icons.sync_rounded),
                  _stat('Completed', completed, Icons.check_circle_outline_rounded),
                  _stat('Failed', failed, Icons.error_outline_rounded),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader('1. Configure MakeMKV', 'Local desktop automation · nothing is bundled or installed by the app'),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            TextField(
              controller: _executableController,
              decoration: const InputDecoration(labelText: 'MakeMKV console executable', hintText: r'C:\Program Files (x86)\MakeMKV\makemkvcon64.exe', prefixIcon: Icon(Icons.terminal_rounded)),
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Output root (local disk or mounted NAS)', hintText: r'Y:\Movies', prefixIcon: Icon(Icons.folder_open_rounded)),
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _saveConfiguration, icon: const Icon(Icons.save_outlined), label: const Text('Save settings'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _testingDestination ? null : _testDestination, icon: _testingDestination ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.drive_folder_upload_outlined), label: const Text('Test output'))),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _showAdvanced = !_showAdvanced), icon: Icon(_showAdvanced ? Icons.expand_less : Icons.tune), label: Text(_showAdvanced ? 'Hide advanced options' : 'Advanced options'))),
            if (_showAdvanced) ...[
              TextField(controller: _titleSelectorController, decoration: const InputDecoration(labelText: 'MakeMKV title selector', helperText: 'Use all to read every title, one numeric title index, or comma-separated title indexes selected in Disc Review.'), autocorrect: false),
              const SizedBox(height: 8),
              TextField(controller: _folderController, decoration: const InputDecoration(labelText: 'Unique output subfolder', helperText: 'A separate folder prevents collisions with existing MKV files.'), autocorrect: false),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _rightsConfirmed,
              onChanged: (value) => setState(() => _rightsConfirmed = value ?? false),
              title: const Text('I am authorized to make this copy and will comply with applicable law.'),
              subtitle: const Text('Required before launching a rip. The app does not bypass drive security or flash firmware.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]))),
          const SizedBox(height: 12),
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Multi-Movie Disc Review', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Scan the selected disc before ripping. Long titles are only suggestions; verify names and durations because extras, alternate cuts, and duplicate encodes can look similar.'),
              const SizedBox(height: 8),
              const Text('Where are the extras? Deleted scenes, featurettes, trailers, alternate cuts and some audio-commentary versions can appear as separate MakeMKV titles. Select the title indexes here or use the “all” selector, then import each resulting MKV and choose its Content category. Menu graphics, DVD navigation (IFO/BUP/VOB structure) and interactive mini-games are not usually exported as ordinary playable MKVs; preserve the original disc or an authorized full-disc image when you need those interactive elements.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _scanningTitles ? null : _scanDiscTitles, icon: _scanningTitles ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.manage_search), label: Text(_scanningTitles ? 'Scanning disc…' : 'Scan titles for review')),
              if (_discTitles.isNotEmpty) ...[
                const Divider(height: 24),
                Text('${_discTitles.length} titles detected · ${_selectedTitleIndexes.length} selected'),
                const SizedBox(height: 8),
                ..._discTitles.map((title) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero, dense: true,
                  value: _selectedTitleIndexes.contains(title.index),
                  onChanged: (checked) => setState(() { if (checked == true) { _selectedTitleIndexes.add(title.index); } else { _selectedTitleIndexes.remove(title.index); } }),
                  title: Text('Title ${title.index + 1}: ${title.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${title.duration} · ${title.chapters == 0 ? 'Chapters unknown' : '${title.chapters} chapters'} · ${title.audioTracks.length} audio label(s) · ${title.subtitleTracks.length} subtitle label(s)${_looksLikeFeature(title) ? ' · feature-length candidate' : ' · short/extra candidate'}'),
                )),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _selectedTitleIndexes.isEmpty ? null : () { final indexes = _selectedTitleIndexes.toList()..sort(); _titleSelectorController.text = indexes.join(','); _message('Selected title indexes prepared. Verify the selector before starting a rip.'); }, icon: const Icon(Icons.playlist_add_check), label: const Text('Use selected titles in rip selector')),
                const SizedBox(height: 6),
                const Text('Review safeguard: duration is a hint, not proof of movie identity. Compare names and durations manually; this screen does not automatically merge titles or claim to identify alternate cuts.', style: TextStyle(fontSize: 12)),
              ],
            ])),
          ),
          const SizedBox(height: 12),
          _sectionHeader('2. Detect drive and start a job', 'Drive detection uses MakeMKV’s documented command-line interface'),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _scanning ? null : _detectDrives, icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded), label: Text(_scanning ? 'Detecting…' : 'Detect optical drives'))),
            ]),
            if (_drives.isNotEmpty) ...[
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Optical drive', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedDrive,
                    items: _drives.map((drive) => DropdownMenuItem<int>(value: drive.index, child: Text('Drive ${drive.index}: ${drive.name}${drive.discName.isEmpty ? '' : ' · ${drive.discName}'}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _selectedDrive = value),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('No drives detected yet. Connect the optical drive, open MakeMKV once if needed, then run detection.', style: TextStyle(color: Colors.white60)),
            ],
            if (_localError != null) ...[const SizedBox(height: 8), Text(_localError!, style: TextStyle(color: theme.colorScheme.error))],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _service.hasActiveRip ? null : _startRip, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start ripping job'))),
            const SizedBox(height: 8),
            const Text('The app launches one MakeMKV process at a time. Use the desktop app on the computer that the optical drive is physically connected to. For mapped network drives, confirm the share is mounted in the same Windows user session.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          ]))),
          const SizedBox(height: 12),
          _sectionHeader('3. Live job monitoring', 'Progress, console events, completion status, and generated MKV files'),
          if (jobs.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No rip jobs recorded on this device yet.', style: TextStyle(color: Colors.white60))))
          else
            for (final job in jobs) _jobCard(context, job),
          const SizedBox(height: 12),
          _sectionHeader('4. Import a completed MKV', 'Check the container header and review metadata before adding a library entry'),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            TextField(controller: _manualMkvController, decoration: const InputDecoration(labelText: 'Full path to existing MKV', hintText: r'Y:\Movies\Example\Example.mkv', prefixIcon: Icon(Icons.video_file_outlined)), autocorrect: false),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _importManualPath, icon: const Icon(Icons.fact_check_rounded), label: const Text('Validate and review import'))),
            const SizedBox(height: 8),
            const Text('Import creates a catalog record with title, year, disc format and optional poster URL. It does not copy the file or claim that playback is configured; connect your NAS path to the app’s authorized media-server gateway.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          ]))),
          const SizedBox(height: 12),
          _buildReferences(context),
          const SizedBox(height: 16),
          const Text('Safety: firmware changes are never automated from this screen. A drive’s model name alone does not prove firmware compatibility. Verify exact hardware revision and interface details with current vendor/community documentation before considering a firmware change.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon) => Chip(avatar: Icon(icon, size: 16), label: Text('$label · $value'));

  Widget _sectionHeader(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );

  Widget _jobCard(BuildContext context, DiscRipJob job) {
    final icon = switch (job.status) {
      DiscRipStatus.running => Icons.sync_rounded,
      DiscRipStatus.succeeded => Icons.check_circle_rounded,
      DiscRipStatus.failed => Icons.error_rounded,
      DiscRipStatus.cancelled => Icons.cancel_rounded,
    };
    final color = switch (job.status) {
      DiscRipStatus.running => Colors.lightBlueAccent,
      DiscRipStatus.succeeded => Colors.greenAccent,
      DiscRipStatus.failed => Colors.redAccent,
      DiscRipStatus.cancelled => Colors.orangeAccent,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text('${job.driveName} · ${job.status.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(job.phase, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: job.status == DiscRipStatus.succeeded ? 1 : (job.status == DiscRipStatus.failed || job.status == DiscRipStatus.cancelled ? null : job.progress), minHeight: 4),
          const SizedBox(height: 4),
          Text('${(job.progress * 100).round()}% · ${job.id}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Align(alignment: Alignment.centerLeft, child: SelectableText('Output: ${job.outputPath}', style: const TextStyle(color: Colors.white60, fontSize: 12))),
          if (job.error != null) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: Text(job.error!, style: const TextStyle(color: Colors.redAccent)))],
          const SizedBox(height: 8),
          Row(children: [
            if (job.status == DiscRipStatus.running) TextButton.icon(onPressed: () async { try { await _service.cancelRip(job.id); } catch (error) { _message('$error', isError: true); } }, icon: const Icon(Icons.stop_circle_outlined), label: const Text('Cancel job')),
            if (job.status != DiscRipStatus.running) TextButton.icon(onPressed: () async { try { await _service.refreshJobOutputs(job.id); _message('Output folder rescanned.'); } catch (error) { _message('$error', isError: true); } }, icon: const Icon(Icons.refresh), label: const Text('Rescan output')),
          ]),
          if (job.outputFiles.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('Output files', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final file in job.outputFiles)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.video_file_outlined),
                title: Text(file.split(RegExp(r'[/\\]')).last, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(job.importedFiles.contains(file) ? 'Imported to catalog' : 'Ready for review', style: TextStyle(color: job.importedFiles.contains(file) ? Colors.greenAccent : Colors.white60, fontSize: 12)),
                trailing: job.importedFiles.contains(file) ? const Icon(Icons.check, color: Colors.greenAccent) : IconButton(tooltip: 'Validate and import', onPressed: () => _showImportDialog(file), icon: const Icon(Icons.library_add_check_rounded, color: _discAccent)),
              ),
          ],
          const Align(alignment: Alignment.centerLeft, child: Text('Recent log events', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 230),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(child: SelectableText(job.events.reversed.take(24).join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35, color: Colors.white70))),
          ),
        ],
      ),
    );
  }

  Widget _buildReferences(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.menu_book_rounded, color: _discAccent),
          title: const Text('Setup guide & verified references', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Official downloads, CLI docs, drive specifications and compatibility discussion'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            _reference('MakeMKV official download', 'https://www.makemkv.com/download/', Icons.download_rounded),
            _reference('MakeMKV CLI automation documentation', 'https://www.makemkv.com/developers/', Icons.terminal_rounded),
            _reference('LG BU40N product specifications', 'https://www.lg.com/us/burners-drives/lg-bu40n-ultra-slim-blu-ray-external-dvd-drive', Icons.devices_other_rounded),
            _reference('MakeMKV UHD drive / firmware discussion', 'https://forum.makemkv.com/forum/viewtopic.php?f=16&t=19634', Icons.forum_outlined),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text('The BU40N product page confirms a slim internal SATA optical drive. USB adapters/enclosures vary in power and compatibility. MakeMKV’s developer page documents CLI automation; this app uses it for drive discovery and rip progress. No firmware images are bundled.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4))),
          ],
        ),
      );

  Widget _reference(String title, String url, IconData icon) => ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: () => _launch(url),
      );

  void _showGuideDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick setup guide'),
        content: const SingleChildScrollView(child: Text(
          '1. Install MakeMKV from the official download page and open it once.\n\n'
          '2. Connect a compatible optical drive. A slim internal SATA drive such as the LG BU40N needs a correctly powered SATA-to-USB adapter or enclosure when used externally.\n\n'
          '3. Set the MakeMKV console executable and output root (for example, a mounted NAS folder such as Y:\\Movies). Test that folder before ripping.\n\n'
          '4. Detect drives, insert the disc, and start a job. “all” can include extras and multiple titles; review results before importing.\n\n'
          '5. When the job completes, validate each MKV, review title/year/disc type/artwork, and add the metadata entry to the app library.\n\n'
          '6. To make the file playable, ensure your media server scans the same output folder and exposes an authorized stream URL. Never use a raw Windows/NAS path as a browser playback URL.\n\n'
          'Firmware caution: do not flash solely because the model number matches a video. Firmware compatibility depends on exact revision, platform, region/version and interface behavior. Use the current MakeMKV community drive guide, make backups where supported, and understand the possibility of damaging the drive. This app intentionally does not flash firmware.'
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}


/// Displays local metadata manifests created during disc imports. Full file
/// paths are intentionally excluded; a manifest is not a playable stream URL.
class DiscImportManifestScreen extends StatefulWidget {
  const DiscImportManifestScreen({super.key});

  @override
  State<DiscImportManifestScreen> createState() => _DiscImportManifestScreenState();
}

class _DiscImportManifestScreenState extends State<DiscImportManifestScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DiscIngestionService.instance.loadImportManifests();
  }

  String _formatBytes(dynamic raw) {
    final bytes = (raw as num?)?.toInt() ?? 0;
    if (bytes < 1024) return '$bytes B';
    const units = <String>['KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = -1;
    do {
      value /= 1024;
      unit++;
    } while (value >= 1024 && unit < units.length - 1);
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false)
      : <Map<String, dynamic>>[];

  String _streamDescription(Map<String, dynamic> stream) {
    final type = stream['codecType']?.toString() ?? 'stream';
    final codec = stream['codecName']?.toString() ?? 'unknown codec';
    final dimensions = (stream['width'] is num && stream['height'] is num)
        ? ' · ${stream['width']}×${stream['height']}'
        : '';
    final channels = stream['channels'] is num ? ' · ${stream['channels']} ch' : '';
    final language = (stream['language']?.toString() ?? '').trim();
    final title = (stream['title']?.toString() ?? '').trim();
    return '$type · $codec$dimensions$channels${language.isEmpty ? '' : ' · $language'}${title.isEmpty ? '' : ' · $title'}';
  }

  Widget _manifestCard(Map<String, dynamic> manifest) {
    final videos = _maps(manifest['videoStreams']);
    final audio = _maps(manifest['audioStreams']);
    final subtitles = _maps(manifest['subtitleStreams']);
    final extras = _maps(manifest['otherStreams']);
    final hasProbe = manifest['streamInspectionSucceeded'] == true;
    final importedAt = DateTime.tryParse(manifest['importedAt']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(hasProbe ? Icons.verified_outlined : Icons.info_outline_rounded),
        title: Text(manifest['title']?.toString() ?? 'Imported item', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${manifest['sourceFileName'] ?? 'MKV'} · ${_formatBytes(manifest['fileSizeBytes'])}\n${manifest['contentCategory'] ?? 'Main Feature'} · ${importedAt?.toLocal().toString().split('.').first ?? 'Import date unavailable'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(dense: true, title: const Text('Container signature'), subtitle: Text(manifest['containerSignatureCheck']?.toString() ?? 'Unknown')),
          ListTile(dense: true, title: const Text('Stream inspection'), subtitle: Text(manifest['inspectionMessage']?.toString() ?? 'Not inspected')),
          ListTile(dense: true, title: const Text('Format'), subtitle: Text(manifest['formatName']?.toString() ?? 'Unknown')),
          if (manifest['durationSeconds'] is num)
            ListTile(dense: true, title: const Text('Duration'), subtitle: Text('${((manifest['durationSeconds'] as num).toDouble() / 60).toStringAsFixed(1)} minutes')),
          if (videos.isNotEmpty) ...[
            const ListTile(dense: true, title: Text('Video streams', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final stream in videos) ListTile(dense: true, leading: const Icon(Icons.videocam_outlined), title: Text(_streamDescription(stream))),
          ],
          if (audio.isNotEmpty) ...[
            const ListTile(dense: true, title: Text('Audio streams', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final stream in audio) ListTile(dense: true, leading: const Icon(Icons.audiotrack_rounded), title: Text(_streamDescription(stream))),
          ],
          if (subtitles.isNotEmpty) ...[
            const ListTile(dense: true, title: Text('Subtitle streams', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final stream in subtitles) ListTile(dense: true, leading: const Icon(Icons.closed_caption_outlined), title: Text(_streamDescription(stream))),
          ],
          if (extras.isNotEmpty) ...[
            const ListTile(dense: true, title: Text('Other streams', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final stream in extras) ListTile(dense: true, title: Text(_streamDescription(stream))),
          ],
          ListTile(dense: true, leading: const Icon(Icons.info_outline_rounded), title: const Text('Integrity and playback limits'), subtitle: Text(
            'Checksum: ${manifest['checksumStatus'] ?? 'not computed'}. Full decode test: ${manifest['fullDecodeTested'] == true ? 'performed' : 'not performed'}. Playback URL created: ${manifest['playbackUrlCreated'] == true ? 'yes' : 'no'}. A container signature or stream probe is not a complete playback verification.')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Import Technical Manifests'),
      actions: [
        IconButton(
          tooltip: 'Refresh manifests',
          onPressed: () => setState(() => _future = DiscIngestionService.instance.loadImportManifests()),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final manifests = snapshot.data ?? const <Map<String, dynamic>>[];
        if (manifests.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No import manifests yet. Import an MKV from the Disc Ingestion Center. If ffprobe is installed, stream and codec details will be included automatically.', textAlign: TextAlign.center)));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Manifests are stored in application-support storage and omit full source paths. ffprobe inspection is optional; without it, only the container signature and file size are recorded.', style: TextStyle(color: Colors.white60, height: 1.45)),
          const SizedBox(height: 12),
          for (final manifest in manifests) _manifestCard(manifest),
        ]);
      },
    ),
  );
}
