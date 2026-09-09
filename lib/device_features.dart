import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_core.dart';

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

  @override
  Widget build(BuildContext context) {
    final profile = AppController.instance.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Road Trip'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _heroCard(context),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text(
                'Show TV sign-in QR / code',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Use this when you are signing the TV app into your account.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
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
            'Use the TV code or QR code to sign in and control playback.',
            Icons.qr_code_2_rounded,
            _pairDevice,
          ),

          ...devices.map(
            (device) => _deviceCard(
              context,
              device.name,
              '${device.type} • Ready to cast',
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
                  title: const Text(
                    'Road Trip Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Prioritize downloaded movies and shows when you are offline.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      carMode = value;
                    });
                  },
                ),

                if (carMode) ...[
                  const Divider(height: 1),

                  SwitchListTile.adaptive(
                    value: audioOnly,
                    title: const Text('Audio-only fallback'),
                    subtitle: const Text(
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
                    title: const Text('USB / car screen'),
                    subtitle: const Text(
                      'Use a compatible USB media connection when the vehicle '
                      'supports video playback.',
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.bluetooth_rounded),
                    title: const Text('Bluetooth audio'),
                    subtitle: const Text(
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
                  title: const Text(
                    'Download Center',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
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
                  title: Text('Download before leaving'),
                  subtitle: Text(
                    'Offline playback requires a licensed downloadable video '
                    'source; trailers and metadata are not full movie downloads.',
                  ),
                ),
              ],
            ),
          ),

          if (profile != null) ...[
            const SizedBox(height: 12),
            Text(
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
                  Text(
                    'Watch anywhere',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
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

  void _pairDevice() async {
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
              const Text(
                'Pair a TV',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'On the TV, open My Streaming Service and choose '
                'Sign in / Pair device.',
              ),

              const SizedBox(height: 20),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scanQr();
                    },
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                    ),
                    label: const Text('Scan QR code'),
                  ),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _enterTvCode();
                    },
                    icon: const Icon(
                      Icons.password_rounded,
                    ),
                    label: const Text('Enter TV code'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                'Pairing signs you in without typing your account password '
                'on the TV.',
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

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter TV code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: '6-digit code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          FilledButton(
            onPressed: () {
              if (controller.text.trim().length == 6) {
                Navigator.pop(context);
                _showPaired();
              }
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _scanQr() async {
    setState(() {
      scanning = true;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _QrScannerScreen(),
      ),
    );

    if (mounted) {
      setState(() {
        scanning = false;
      });

      _showPaired();
    }
  }

  void _showPaired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TV paired. You can now send playback to it.',
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
              title: Text(
                'Cast to ${device.name}',
              ),
              subtitle: const Text(
                'Chromecast / AirPlay / compatible smart-TV transport',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ready to cast to ${device.name}. '
                      'Start a movie and choose Cast.',
                    ),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.link_rounded,
              ),
              title: const Text(
                'Use as remote',
              ),
              subtitle: const Text(
                'Control play, pause, seek, audio and subtitles.',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
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
    // FIXED:
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
                const Text(
                  'Offline Download Center',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Choose titles to prepare for a road trip. Actual offline '
                  'video storage must come from a licensed downloadable source.',
                ),

                const SizedBox(height: 14),

                if (media.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Your library is empty.',
                    ),
                  )
                else
                  ...media.take(12).map(
                    (item) => CheckboxListTile(
                      value: downloads.contains(item.id),
                      title: Text(item.title),

                      // FIXED:
                      // MediaType does not expose .name in this project.
                      subtitle: Text(
                        _mediaTypeLabel(item),
                      ),

                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
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
                  label: const Text(
                    'Done',
                  ),
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

  CastDevice(
    this.name,
    this.type,
    this.icon,
  );
}

class TvPairingScreen extends StatelessWidget {
  const TvPairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final code = (100000 + Random().nextInt(900000)).toString();
    final payload = 'my-streaming-service://pair?code=$code';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in on TV'),
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

              const Text(
                'Scan this QR code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Or enter the code shown below on the TV.',
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

              const Text(
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

class _QrScannerScreen extends StatelessWidget {
  const _QrScannerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan TV QR code'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (capture.barcodes.isNotEmpty) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}