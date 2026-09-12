// FILE: `lib/account_settings.dart`.
// Purpose: Implements the account settings portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_core.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool loading = true;
  int limit = 1000000000000, used = 0;
  bool pending = false;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    _load();
  }

  /// Performs `_load` for this feature. Update this documentation when its contract changes.
  Future<void> _load() async {
    try {
      final d = await AppController.instance.backendApi.getStorage();

      if (mounted) {
        setState(() {
          limit = (d['limitBytes'] as num?)?.toInt() ?? limit;
          used = (d['usedBytes'] as num?)?.toInt() ?? 0;
          pending = d['requestPending'] == true;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  /// Performs `_size` for this feature. Update this documentation when its contract changes.
  String _size(int b) {
    final tb = b / 1000000000000;

    if (tb >= 1) {
      return '${tb.toStringAsFixed(tb % 1 == 0 ? 0 : 1)} TB';
    }

    final gb = b / 1000000000;
    return '${gb.toStringAsFixed(0)} GB';
  }

  /// Performs `_currency` for this feature. Update this documentation when its contract changes.
  String _currency() {
    final c =
        Localizations.localeOf(context).countryCode?.toUpperCase() ?? 'US';

    if (c == 'MX') return 'MXN';
    if (c == 'GB') return 'GBP';

    const euro = {
      'DE',
      'FR',
      'ES',
      'IT',
      'PT',
      'NL',
      'BE',
      'IE',
      'AT',
      'FI',
      'GR',
    };

    if (euro.contains(c)) return 'EUR';
    if (c == 'CA') return 'CAD';
    if (c == 'AU') return 'AUD';

    return 'USD';
  }

  /// Performs `_rate` for this feature. Update this documentation when its contract changes.
  double _rate(String c) {
    switch (c) {
      case 'MXN':
        return 18.5;
      case 'GBP':
        return .75;
      case 'EUR':
        return .85;
      case 'CAD':
        return 1.37;
      case 'AUD':
        return 1.53;
      default:
        return 1;
    }
  }

  /// Performs `_price` for this feature. Update this documentation when its contract changes.
  String _price(double usd) {
    final c = _currency();
    final v = usd * _rate(c);

    final symbol = {
          'USD': '\$',
          'MXN': 'MX\$',
          'GBP': '£',
          'EUR': '€',
          'CAD': 'CA\$',
          'AUD': 'A\$',
        }[c] ??
        c;

    return '$symbol${v.toStringAsFixed(2)}';
  }

  /// Performs `_request` for this feature. Update this documentation when its contract changes.
  Future<void> _request() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request more storage'),
        content: Text(
          pending
              ? 'A request is already pending.'
              : 'Your account currently has ${_size(limit)}. '
                  'Request additional server storage from the platform owner. '
                  'There is no automatic charge for a storage request; '
                  'the platform owner decides whether to grant it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          if (!pending)
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  await AppController.instance.backendApi.requestMoreStorage();

                  if (mounted) {
                    setState(() => pending = true);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Storage request sent to the platform owner.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );
                  }
                }
              },
              child: const Text('REQUEST'),
            ),
        ],
      ),
    );
  }

  /// Performs `_deleteAccount` for this feature. Update this documentation when its contract changes.
  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete account?'),
            content: const Text(
              'This permanently removes the account, profiles, sessions, '
              'remote workers and account data. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE ACCOUNT'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await AppController.instance.backendApi.deleteAccount();
      AppController.instance.reset();

      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    // FIXED:
    // Explicitly make pct a double so LinearProgressIndicator
    // receives the correct type.
    final double pct = limit == 0
        ? 0.0
        : math.min(1.0, used / limit).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription & currency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your base plan is \$10/month or \$100/year USD equivalent. '
                    'Your checkout display uses your device/account country: '
                    '${_currency()}. Current conversion is configurable by '
                    'the service and should be refreshed by the production '
                    'billing provider.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly: ${_price(10)}   •   Yearly: ${_price(100)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage_rounded),
                      const SizedBox(width: 8),
                      const Text(
                        'Server storage',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text('${(pct * 100).toStringAsFixed(0)}%'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${_size(used)} used of ${_size(limit)}',
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed: loading || pending ? null : _request,
                    icon: const Icon(Icons.add_to_drive),
                    label: Text(
                      pending
                          ? 'REQUEST PENDING'
                          : 'REQUEST MORE STORAGE',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Card(
            child: ListTile(
              leading: Icon(Icons.devices),
              title: Text('Device roles'),
              subtitle: Text(
                'PC/desktop: remote disc importing. '
                'Phone/tablet: downloads and casting. '
                'TV: best big-screen experience. '
                'HDMI from a computer is supported where the hardware '
                'supports it. Bluetooth is for audio, not generic video.',
              ),
            ),
          ),

          const SizedBox(height: 18),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: const Text('Delete account'),
              subtitle: const Text(
                'Permanently stop using the service and remove the account.',
              ),
              onTap: _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
