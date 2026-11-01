import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'streaming_experience.dart';

/// Evidence-based viewer guidance and provider-side efficiency practices.
/// Provider recommendations are informational: this client does not configure
/// the user's CDN, encoders, data-centre fleet, or electricity procurement.
class StreamingSustainabilityScreen extends StatelessWidget {
  const StreamingSustainabilityScreen({super.key});

  static const _ieaUrl =
      'https://www.iea.org/commentaries/the-carbon-footprint-of-streaming-video-fact-checking-the-headlines';
  static const _carbonTrustUrl =
      'https://www.carbontrust.com/our-work-and-impact/guides-reports-and-tools/carbon-impact-of-video-streaming';
  static const _traficomUrl =
      'https://traficom.fi/en/news/first-study-energy-consumption-communications-networks';
  static const _dvbUrl =
      'https://dvb.org/?standard=adaptive-media-streaming-over-ip-multicast';

  Future<void> _openSource(String value) async {
    try {
      await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Source links are optional reading; keep the screen usable if the
      // platform cannot open an external browser.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Sustainability')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.energy_savings_leaf_rounded,
                          color: colors.primary, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Stream thoughtfully. Measure honestly.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Streaming electricity use depends on the screen, playback equipment, network, data centre and electricity mix. The biggest opportunity varies by household and service, so the guidance below avoids promising a fixed saving for every viewer.',
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(
            title: 'A modelled energy breakdown',
            subtitle:
                'The IEA’s analysis of average Netflix viewing habits in 2019 estimated this split. It is a historical model, not a live measurement or a universal percentage.',
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BreakdownCard(
                  value: '72%',
                  label: 'Viewing devices',
                  detail: 'Screens and playback devices',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _BreakdownCard(
                  value: '23%',
                  label: 'Data transmission',
                  detail: 'Networks delivering video',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _BreakdownCard(
                  value: '5%',
                  label: 'Data centres',
                  detail: 'Hosting and delivery systems',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'These shares are specific to the IEA’s 2019 Netflix viewing model. Different devices, network mixes and viewing patterns can produce different results.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 22),
          const _SectionHeading(
            title: 'For viewers',
            subtitle:
                'Practical choices that can reduce electricity use or avoid unnecessary data and playback work.',
          ),
          const SizedBox(height: 10),
          const _AdviceCard(
            icon: Icons.devices_rounded,
            title: 'Choose an efficient screen',
            body:
                'A smaller laptop or phone often uses less electricity than a large television. In the Carbon Trust’s device-only comparison, a 50-inch TV had about 4.5 times the viewing-device footprint of a laptop. Actual results depend on the model, brightness and peripherals.',
          ),
          const _AdviceCard(
            icon: Icons.hd_outlined,
            title: 'Match video quality to the moment',
            body:
                'Use SD or 720p when 4K or 1080p detail is unnecessary. Lower quality can reduce bitrate and data use, but research found that the effect on total streaming emissions can be small because the screen often accounts for more energy. 720p is HD, not SD.',
          ),
          const _AdviceCard(
            icon: Icons.wifi_rounded,
            title: 'Prefer fixed broadband when practical',
            body:
                'Wi-Fi or Ethernet over a fixed broadband connection can be more energy-efficient per gigabyte than mobile networks in some regions. The difference is not universal, and a Wi-Fi router also uses electricity. Avoid assuming a fixed “five times” saving.',
          ),
          const _AdviceCard(
            icon: Icons.play_circle_outline_rounded,
            title: 'Avoid playback you do not need',
            body:
                'Turn off automatic hero video previews when you do not use them, disable autoplay where the service offers that control, stop playback when finished, and choose audio-only listening for music or podcasts when available.',
          ),
          const _AdviceCard(
            icon: Icons.devices_other_rounded,
            title: 'Keep devices in service longer',
            body:
                'Repair, maintain and keep working devices where practical. Refurbished equipment can avoid some of the manufacturing footprint associated with replacing a device early.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use the controls already built into the app',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Eco mode reduces nonessential previews, motion and background work. Data Saver requests a 480p cap where the authorized playback service supports it. Neither feature measures actual watts or guarantees a specific saving.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const StreamingExperienceSettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.high_quality_rounded),
                      label: const Text('Open streaming quality settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionHeading(
            title: 'For streaming providers',
            subtitle:
                'Infrastructure practices for service operators. These are recommendations and are not automatically configured by this Flutter app.',
          ),
          const SizedBox(height: 10),
          const _AdviceCard(
            icon: Icons.memory_rounded,
            title: 'Use efficient encoding and hardware acceleration',
            body:
                'Evaluate codecs such as HEVC and AV1 with compatible hardware encoders and decoders. Compare end-to-end energy, quality, bitrate, encoding time and device compatibility: a more efficient bitrate does not automatically mean lower processing energy.',
          ),
          const _AdviceCard(
            icon: Icons.hub_rounded,
            title: 'Cache content close to viewers',
            body:
                'Use appropriately placed CDN edge caches to serve popular content nearer to viewers and reduce repeated origin transfers. Measure cache effectiveness and the energy used by the additional edge infrastructure.',
          ),
          const _AdviceCard(
            icon: Icons.cell_tower_rounded,
            title: 'Consider multicast ABR for large live audiences',
            body:
                'DVB-MABR can reduce redundant delivery when many viewers watch the same linear stream at the same time. It requires compatible network and service infrastructure; it is not a general replacement for ordinary on-demand unicast streaming.',
          ),
          const _AdviceCard(
            icon: Icons.cloud_sync_rounded,
            title: 'Scale infrastructure with demand',
            body:
                'Consolidate workloads, scale capacity to real traffic, and use low-power states or power down idle resources where safe. Preserve redundancy, performance and recovery capacity rather than shutting down essential services.',
          ),
          const _AdviceCard(
            icon: Icons.solar_power_rounded,
            title: 'Procure low-carbon electricity',
            body:
                'Use credible renewable electricity procurement, such as solar and wind power, for data centres and network operations. This primarily reduces the carbon intensity of electricity; it does not by itself reduce the number of kilowatt-hours consumed.',
          ),
          const _AdviceCard(
            icon: Icons.monitor_heart_outlined,
            title: 'Measure the whole delivery chain',
            body:
                'Track facility electricity, server utilization, encoding, storage, CDN and network efficiency, and report the measurement boundary and time period. Separate electricity use (kWh) from greenhouse-gas emissions (CO₂e).',
          ),
          const SizedBox(height: 22),
          const _SectionHeading(
            title: 'Evidence and references',
            subtitle:
                'Open the original research and standards for methodology, context and limitations.',
          ),
          const SizedBox(height: 8),
          _SourceTile(
            title: 'International Energy Agency',
            subtitle: 'Streaming electricity model and 72 / 23 / 5 split',
            onTap: () => _openSource(_ieaUrl),
          ),
          _SourceTile(
            title: 'Carbon Trust',
            subtitle: 'Device comparisons and video-quality findings',
            onTap: () => _openSource(_carbonTrustUrl),
          ),
          _SourceTile(
            title: 'Traficom (Finland)',
            subtitle:
                'Measured fixed/mobile network energy per GB; regional study, not a global factor',
            onTap: () => _openSource(_traficomUrl),
          ),
          _SourceTile(
            title: 'DVB-MABR',
            subtitle: 'Standard for adaptive media streaming over IP multicast',
            onTap: () => _openSource(_dvbUrl),
          ),
          const SizedBox(height: 12),
          const Text(
            'Important: This screen is educational. It does not inspect your ISP, measure your display or router, configure your CDN, control data-centre servers, verify renewable-energy contracts, or calculate a verified carbon footprint.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12, height: 1.4)),
        ],
      );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.value,
    required this.label,
    required this.detail,
  });

  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(height: 3),
              Text(detail,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10, height: 1.25)),
            ],
          ),
        ),
      );
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(body,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 7),
        child: ListTile(
          leading: const Icon(Icons.open_in_new_rounded),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
