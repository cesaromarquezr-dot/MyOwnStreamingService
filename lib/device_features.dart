// FILE: `lib/device_features.dart`.
// Purpose: Implements the device features portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Device pairing and casting remain transport-agnostic. This UI stores only
// temporary/local presentation state; actual Chromecast/AirPlay/HDMI/USB
// integrations can be connected later without changing the user flow.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_core.dart';
import 'localization.dart';

/// Device, TV casting, account pairing and road-trip controls.
///
/// The UI is intentionally transport-agnostic: Chromecast/AirPlay/HDMI/USB
/// implementations can be connected later without changing the user flow.
class DeviceCenterScreen extends StatefulWidget {
  const DeviceCenterScreen({super.key});

  @override
  State<DeviceCenterScreen> createState() => _DeviceCenterScreenState();
}

class _DeviceCenterScreenState extends State<DeviceCenterScreen> {
  final List<CastDevice> devices = [
    CastDevice(
      'Living Room TV',
      'Smart TV',
      Icons.tv_rounded,
    ),
    CastDevice(
      'Bedroom TV',
      'Smart TV',
      Icons.tv_rounded,
    ),
  ];

  final Set<String> downloads = <String>{};

  bool scanning = false;
  bool carMode = false;
  bool audioOnly = false;
  bool tvPaired = false;

  @override
  Widget build(BuildContext context) {
    final profile = AppController.instance.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Devices & Road Trip'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _heroCard(context),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const UniversalText(
                'Show TV sign-in QR / code',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: UniversalText(
                tvPaired
                    ? 'TV pairing is active for this session.'
                    : 'Use this when signing the TV app into your account.',
              ),
              trailing: Icon(
                tvPaired
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TvPairingScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          _sectionTitle('Send to TV'),

          _deviceCard(
            context,
            'Scan & pair a TV',
            tvPaired
                ? 'TV pairing is active. You can pair another TV if needed.'
                : 'Use the TV code or QR code to begin the pairing flow.',
            Icons.qr_code_2_rounded,
            _pairDevice,
          ),

          ...devices.map(
            (device) => _deviceCard(
              context,
              device.name,
              '${device.type} • ${device.available ? 'Ready' : 'Unavailable'}',
              device.icon,
              () => _castTo(context, device),
            ),
          ),

          const SizedBox(height: 12),

          _sectionTitle('Road Trip Mode'),

          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: carMode,
                  title: const UniversalText(
                    'Road Trip Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const UniversalText(
                    'Prioritize downloaded movies and shows when you are offline.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      carMode = value;
                      if (!value) {
                        audioOnly = false;
                      }
                    });
                  },
                ),
                if (carMode) ...[
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: audioOnly,
                    title: const UniversalText('Audio-only fallback'),
                    subtitle: const UniversalText(
                      'If the car has no compatible screen, keep audio playing '
                      'while the phone shows the video.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        audioOnly = value;
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.usb_rounded),
                    title: const UniversalText('USB / car screen'),
                    subtitle: const UniversalText(
                      'Use a compatible USB media connection when the vehicle '
                      'supports video playback.',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bluetooth_rounded),
                    title: const UniversalText('Bluetooth audio'),
                    subtitle: const UniversalText(
                      'Connect your phone to the car for audio. Bluetooth '
                      'video support depends on the vehicle.',
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          _sectionTitle('Offline Downloads'),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.download_for_offline_rounded,
                  ),
                  title: const UniversalText(
                    'Download Center',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: UniversalText(
                    '${downloads.length} title'
                    '${downloads.length == 1 ? '' : 's'} '
                    'marked for your next trip.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () => _showDownloads(context),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: UniversalText('Download before leaving'),
                  subtitle: UniversalText(
                    'Offline playback requires a licensed downloadable video '
                    'source; trailers and metadata are not full movie downloads.',
                  ),
                ),
              ],
            ),
          ),

          if (profile != null) ...[
            const SizedBox(height: 12),
            UniversalText(
              'Signed in as ${profile.name}',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.devices_other_rounded,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UniversalText(
                    'Watch anywhere',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  UniversalText(
                    'Cast from your phone or tablet, pair a TV, and prepare '
                    'an offline road-trip library.',
                    style: TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
        left: 3,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _deviceCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _pairDevice() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UniversalText(
                'Pair a TV',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const UniversalText(
                'On the TV, open My Streaming Service and choose '
                'Sign in / Pair device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanQr();
                    },
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                    ),
                    label: const UniversalText('Scan QR code'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _enterTvCode();
                    },
                    icon: const Icon(
                      Icons.password_rounded,
                    ),
                    label: const UniversalText('Enter TV code'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const UniversalText(
                'Pairing is designed to avoid entering the account password '
                'directly on the TV.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enterTvCode() async {
    final controller = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const UniversalText('Enter TV code'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: tr('6-digit code'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().length != 6) {
                  return;
                }

                Navigator.pop(context);

                if (mounted) {
                  _setTvPaired();
                }
              },
              child: const UniversalText('Pair'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _scanQr() async {
    if (scanning) return;

    setState(() {
      scanning = true;
    });

    bool scanned = false;

    try {
      scanned = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const _QrScannerScreen(),
            ),
          ) ??
          false;
    } finally {
      if (mounted) {
        setState(() {
          scanning = false;
        });
      }
    }

    if (scanned && mounted) {
      _setTvPaired();
    }
  }

  void _setTvPaired() {
    setState(() {
      tvPaired = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: UniversalText(
          'TV pairing completed for this session.',
        ),
      ),
    );
  }

  void _castTo(
    BuildContext context,
    CastDevice device,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.cast_rounded,
              ),
              title: UniversalText(
                'Cast to ${device.name}',
              ),
              subtitle: const UniversalText(
                'Chromecast / AirPlay / compatible smart-TV transport',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: UniversalText(
                      'Cast target selected: ${device.name}. '
                      'Start a movie and choose Cast when transport support '
                      'is available.',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.link_rounded,
              ),
              title: const UniversalText(
                'Use as remote',
              ),
              subtitle: const UniversalText(
                'Control play, pause, seek, audio and subtitles.',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: UniversalText(
                      'Remote controls are ready for the paired-device flow.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloads(BuildContext context) {
    // Library belongs to AppController, not Profile.
    final media = AppController.instance.library;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UniversalText(
                  'Offline Download Center',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const UniversalText(
                  'Choose titles to prepare for a road trip. Actual offline '
                  'video storage must come from a licensed downloadable source.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                if (media.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: UniversalText(
                      'Your library is empty.',
                    ),
                  )
                else
                  ...media.take(12).map(
                        (item) => CheckboxListTile(
                          value: downloads.contains(item.id),
                          title: Text(item.title),
                          subtitle: Text(
                            _mediaTypeLabel(item),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                downloads.add(item.id);
                              } else {
                                downloads.remove(item.id);
                              }
                            });

                            setSheetState(() {});
                          },
                        ),
                      ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const UniversalText('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mediaTypeLabel(MediaItem item) {
    final type = item.type.toString().toLowerCase();

    if (type.contains('movie')) {
      return 'Movie';
    }

    if (type.contains('tv') ||
        type.contains('series') ||
        type.contains('show')) {
      return 'TV Show';
    }

    return 'Media';
  }
}

class CastDevice {
  final String name;
  final String type;
  final IconData icon;
  final bool available;

  const CastDevice(
    this.name,
    this.type,
    this.icon, {
    this.available = true,
  });
}

class TvPairingScreen extends StatelessWidget {
  const TvPairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final code = (100000 + Random().nextInt(900000)).toString();
    final payload = 'my-streaming-service://pair?code=$code';

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Sign in on TV'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.tv_rounded,
                size: 62,
              ),
              const SizedBox(height: 14),
              const UniversalText(
                'Scan this QR code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const UniversalText(
                'Or enter the code shown below on the TV.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: payload,
                size: 230,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 20),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 7,
                ),
              ),
              const SizedBox(height: 12),
              const UniversalText(
                'This code is temporary and should only be used on your TV.',
                style: TextStyle(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Scan TV QR code'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (handled || capture.barcodes.isEmpty) {
            return;
          }

          final rawValue = capture.barcodes.first.rawValue;

          if (rawValue == null || rawValue.trim().isEmpty) {
            return;
          }

          // The scanner only accepts the application's pairing URI format.
          if (!rawValue.startsWith('my-streaming-service://pair')) {
            return;
          }

          handled = true;

          Navigator.pop(
            context,
            true,
          );
        },
      ),
    );
  }
}