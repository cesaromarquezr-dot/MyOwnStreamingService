import 'dart:async';

import 'package:flutter/material.dart';

import 'app_accessibility.dart';
import 'app_core.dart';
import 'energy_saver.dart';
import 'streaming_experience.dart';

/// Settings and transparent, session-level activity diagnostics. Energy values
/// are estimates based on user-entered wattage/rate, not meter readings.
class PowerPerformanceScreen extends StatefulWidget {
  const PowerPerformanceScreen({super.key});

  @override
  State<PowerPerformanceScreen> createState() => _PowerPerformanceScreenState();
}

class _PowerPerformanceScreenState extends State<PowerPerformanceScreen> {
  final EnergySaverController _energy = EnergySaverController.instance;
  late final TextEditingController _wattsController;
  late final TextEditingController _hoursController;
  late final TextEditingController _rateController;
  bool _savingEstimate = false;
  bool _lowBandwidthPlayback = false;

  String? get _profileId => AppController.instance.currentProfile?.id;

  @override
  void initState() {
    super.initState();
    _wattsController = TextEditingController();
    _hoursController = TextEditingController();
    _rateController = TextEditingController();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _energy.ensureLoaded(profileId: _profileId);
    final playback =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    if (!mounted) return;
    setState(() => _lowBandwidthPlayback = playback.dataSaver);
    _updateEstimateFields();
  }

  void _updateEstimateFields() {
    if (!mounted || _savingEstimate) return;
    _wattsController.text = _energy.estimatedDeviceWatts.toStringAsFixed(0);
    _hoursController.text = _energy.hoursPerDay.toStringAsFixed(1);
    _rateController.text = _energy.electricityRate.toStringAsFixed(3);
    setState(() {});
  }

  @override
  void dispose() {
    _wattsController.dispose();
    _hoursController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _saveEstimate() async {
    setState(() => _savingEstimate = true);
    double parse(TextEditingController c, double fallback) =>
        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;
    await _energy.setPowerEstimate(
      watts: parse(_wattsController, _energy.estimatedDeviceWatts),
      hoursPerDay: parse(_hoursController, _energy.hoursPerDay),
      rate: parse(_rateController, _energy.electricityRate),
    );
    if (mounted) setState(() => _savingEstimate = false);
  }

  Future<void> _setMode(EnergySaverMode mode) async {
    await _energy.setMode(mode);
    await _syncMotionPreference(_energy.reduceAnimations);
  }

  Future<void> _syncMotionPreference(bool reduceMotion) async {
    final playback =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    playback.reduceMotion = reduceMotion;
    await playback.save(profileId: _profileId);
    await AppAccessibilitySettings.instance.reload(profileId: _profileId);
  }

  Future<void> _setReduceMotion(bool value) async {
    await _energy.setOptions(reduceAnimations: value);
    await _syncMotionPreference(value);
  }

  Future<void> _openStreamingSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StreamingExperienceSettingsScreen(),
      ),
    );
    final playback =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    if (!mounted) return;
    setState(() => _lowBandwidthPlayback = playback.dataSaver);
  }

  Future<void> _setLowBandwidthPlayback(bool enabled) async {
    final playback =
        await StreamingExperiencePreferences.load(profileId: _profileId);
    if (enabled) {
      playback.enableDataSaver();
    } else {
      playback.disableDataSaver();
    }
    await playback.save(profileId: _profileId);
    if (!mounted) return;
    setState(() => _lowBandwidthPlayback = enabled);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enabled
          ? 'Data Saver enabled; 480p maximum requested where the playback service supports it.'
          : 'Data Saver disabled; your previous resolution preference was restored where available.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _energy,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final metrics = _energy.sessionMetrics;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Power & Performance'),
            actions: [
              IconButton(
                tooltip: 'Reset session activity counters',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: () {
                  _energy.resetSessionMetrics();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Session activity counters reset.'),
                  ));
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              _sectionTitle('Energy profile', 'Eco is the low-energy default. Choose another profile only when you want more previews or faster background updates.'),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;
                final modes = <(EnergySaverMode, IconData, String, String)>[
                  (EnergySaverMode.eco, Icons.eco_outlined, 'Eco', 'Recommended default: no automatic or hover videos, reduced motion, throttled artwork and longer playback/background update intervals.'),
                  (EnergySaverMode.balanced, Icons.balance_rounded, 'Balanced', 'Hover previews enabled; background updates run less often than Cinema.'),
                  (EnergySaverMode.cinema, Icons.local_movies_outlined, 'Cinema', 'Automatic hero previews and richer motion while active.'),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: modes.map((entry) {
                    final selected = _energy.mode == entry.$1;
                    return SizedBox(
                      width: wide ? (constraints.maxWidth - 20) / 3 : constraints.maxWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => unawaited(_setMode(entry.$1)),
                        child: AnimatedContainer(
                          duration: _energy.reduceAnimations ? Duration.zero : const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: selected ? colorScheme.primary.withValues(alpha: .18) : Colors.white.withValues(alpha: .035),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? colorScheme.primary : Colors.white12, width: selected ? 1.5 : 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(entry.$2, size: 26, color: selected ? colorScheme.primary : Colors.white70),
                              const SizedBox(height: 8),
                              Text(entry.$3, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 5),
                              Text(entry.$4, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35)),
                              if (selected) ...[
                                const SizedBox(height: 8),
                                const Row(children: [Icon(Icons.check_circle, size: 16), SizedBox(width: 5), Text('Selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 24),
              _sectionTitle('Playback and network savings', 'These controls reduce the app’s avoidable rendering, network traffic and playback quality when you choose them. Resolution caps only affect streams whose authorized playback service honors them.'),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Low-bandwidth playback',
                subtitle: 'Enable Data Saver and request a 480p maximum. Your previous resolution preference is remembered and restored when you turn this off.',
                value: _lowBandwidthPlayback,
                icon: Icons.data_saver_on_outlined,
                onChanged: _setLowBandwidthPlayback,
              ),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Eco also batches playback session updates, saves local watch progress less often, reduces player UI redraws, skips nonessential background heartbeats while the app is hidden, disables automatic video previews, and throttles artwork lookups. Pause, seek, completion, and final progress updates remain immediate.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Display power', 'OLED-black mode uses black shared surfaces throughout the app. It can reduce display power on OLED/AMOLED panels; LCD screens usually see little or no benefit because their backlight remains on.'),
              const SizedBox(height: 8),
              _switchTile(
                title: 'OLED-black theme',
                subtitle: 'Use pure-black app, card, dialog and navigation surfaces. Your choice is saved for this profile on this device.',
                value: _energy.oledBlackTheme,
                icon: Icons.brightness_2_outlined,
                onChanged: (value) => _energy.setOptions(oledBlackTheme: value),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined),
                          SizedBox(width: 8),
                          Text('More ways to save energy', style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('''• Lower your device screen brightness and enable adaptive brightness.
• Turn on Battery Saver / Low Power Mode in your device settings.
• Keep Eco selected to avoid autoplay previews, reduce motion and defer nonessential refreshes.
• Lower streaming resolution to reduce bandwidth when your playback service supports the selected cap.'''),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openStreamingSettings,
                          icon: const Icon(Icons.high_quality_rounded),
                          label: const Text('Open streaming quality settings'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('The app cannot directly change your operating system’s brightness or native battery-saver switch. Dark-theme energy savings depend on the screen: OLED/AMOLED pixels can turn off for black, while LCD backlights remain on. Actual savings vary by device and brightness.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Fine-tune behavior', 'Your choices are saved for this profile.'),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Autoplay hero video previews',
                subtitle: 'When off, the hero uses artwork until you hover or explicitly start a preview.',
                value: _energy.autoPlayHeroPreviews,
                icon: Icons.movie_filter_outlined,
                onChanged: (value) => _energy.setOptions(autoPlayHeroPreviews: value),
              ),
              _switchTile(
                title: 'Play video previews on hover',
                subtitle: 'Eco disables hover video by default; Balanced waits before starting it.',
                value: _energy.hoverVideoPreviews,
                icon: Icons.ads_click_rounded,
                onChanged: (value) => _energy.setOptions(hoverVideoPreviews: value),
              ),
              _switchTile(
                title: 'Pause work when app is in background',
                subtitle: 'Pause decorative previews and defer nonessential refreshes when minimized or hidden.',
                value: _energy.pauseWhenAppHidden,
                icon: Icons.pause_circle_outline_rounded,
                onChanged: (value) => _energy.setOptions(pauseWhenAppHidden: value),
              ),
              _switchTile(
                title: 'Pause refreshes for inactive pages',
                subtitle: 'Avoid metadata and artwork refreshes for pages that are no longer selected.',
                value: _energy.pauseInactivePageWork,
                icon: Icons.tab_unselected_rounded,
                onChanged: (value) => _energy.setOptions(pauseInactivePageWork: value),
              ),
              _switchTile(
                title: 'Low-power artwork loading',
                subtitle: 'Load visible/nearby artwork first and throttle provider lookups; keep existing cache.',
                value: _energy.lowPowerArtworkLoading,
                icon: Icons.image_search_outlined,
                onChanged: (value) => _energy.setOptions(lowPowerArtworkLoading: value),
              ),
              _switchTile(
                title: 'Reduce interface motion',
                subtitle: 'Reduce nonessential animations and transitions.',
                value: _energy.reduceAnimations,
                icon: Icons.motion_photos_off_outlined,
                onChanged: _setReduceMotion,
              ),
              _switchTile(
                title: 'Prefer direct play when supported',
                subtitle: 'A playback hint for compatible server/device integrations; this setting cannot force direct play if the source requires transcoding.',
                value: _energy.preferDirectPlay,
                icon: Icons.play_circle_outline_rounded,
                onChanged: (value) => _energy.setOptions(preferDirectPlay: value),
              ),
              _switchTile(
                title: 'Reuse in-memory artwork lookup results',
                subtitle: 'Reuse matching results during this app session; resolved poster/backdrop URLs remain cached locally either way.',
                value: _energy.cacheArtwork,
                icon: Icons.cached_rounded,
                onChanged: (value) => _energy.setOptions(cacheArtwork: value),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Estimated device electricity cost', 'Use your own measured average wattage and electricity rate for a better estimate.'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final fieldWidth = constraints.maxWidth >= 700
                          ? (constraints.maxWidth - 20) / 3
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldWidth, child: _numberField(_wattsController, 'Average watts', '100')),
                          SizedBox(width: fieldWidth, child: _numberField(_hoursController, 'Hours per day', '6')),
                          SizedBox(width: fieldWidth, child: _numberField(_rateController, 'Rate per kWh (your currency)', '0.15')),
                        ],
                      );
                    }),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _savingEstimate ? null : _saveEstimate,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Update estimate'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('${_energy.estimatedMonthlyKwh.toStringAsFixed(1)} kWh / month', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('${_energy.estimatedMonthlyCost.toStringAsFixed(2)} per month in your entered currency', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    const Text('This is a calculator, not a live power measurement or a guaranteed saving. App optimizations reduce avoidable work; your electricity meter or a wall power meter is needed to confirm real usage.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Session activity', 'Useful for seeing whether the app is doing less unnecessary work. These are counters, not watts.'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _metricRow('Current profile', _energy.modeLabel),
                    _metricRow('Active page', _energy.activePage),
                    _metricRow('App state', _energy.appIsForeground ? 'Foreground' : 'Background'),
                    const Divider(height: 22),
                    ...metrics.entries.map((entry) => _metricRow(entry.key, '${entry.value}')),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Practical note: for a large household bill, check heating/cooling, water heating, refrigeration, and the computer/media server’s actual power draw as well. This screen cannot control or measure unrelated household appliances.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35)),
        ],
      );

  Widget _switchTile({required String title, required String subtitle, required bool value, required IconData icon, required Future<void> Function(bool) onChanged}) => Card(
        child: SwitchListTile.adaptive(
          secondary: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          value: value,
          onChanged: (next) => unawaited(onChanged(next)),
        ),
      );

  Widget _numberField(TextEditingController controller, String label, String hint) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder()),
      );

  Widget _metricRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white60))), const SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800)))]),
      );
}
