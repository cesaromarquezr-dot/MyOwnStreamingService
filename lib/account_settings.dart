// FILE: `lib/account_settings.dart`.
// Purpose: Implements the account settings portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'localization.dart';

/// Implements the `AccountSettingsScreen` class for this feature or UI component.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

/// Implements the `_AccountSettingsScreenState` class for this feature or UI component.
class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool loading = true;
  int limit = 1000000000000, used = 0;
  bool pending = false;
  int requestedTb = 0;
  double requestFeeUsd = 0;
  String requestStatus = 'none';

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
          requestedTb = (d['requestedTerabytes'] as num?)?.toInt() ?? 0;
          requestFeeUsd = (d['requestFeeUsd'] as num?)?.toDouble() ?? 0;
          requestStatus = d['requestStatus']?.toString() ?? 'none';
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

  /// Lets the user choose additional physical storage and submits the paid request.
  Future<void> _request() async {
    var selectedTb = requestedTb > 0 ? requestedTb : 1;
    const options = [1, 2, 4, 8, 12];
    const pricePerTbUsd = 75.0;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const UniversalText('Request more storage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UniversalText('Additional storage is physical storage that will be purchased and installed on your account server after payment is received.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedTb,
                decoration: InputDecoration(labelText: tr('Additional storage')),
                items: [for (final tb in options) DropdownMenuItem(value: tb, child: UniversalText('+ $tb TB'))],
                onChanged: (value) => setDialogState(() => selectedTb = value ?? 1),
              ),
              const SizedBox(height: 12),
              UniversalText('Additional fee: ${_price(selectedTb * pricePerTbUsd)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const UniversalText('This is a request for physical hardware. The platform owner will review the request, receive payment, obtain the storage, install it, and then update your server capacity.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('CANCEL')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final controller = AppController.instance;
                  final d = await controller.backendApi.requestMoreStorage(additionalTerabytes: selectedTb);
                  if (controller.currentAccount != null) {
                    controller.currentAccount!.storageRequestPending = true;
                    controller.currentAccount!.storageRequestedTerabytes = selectedTb;
                    controller.currentAccount!.storageRequestFeeUsd = (d['feeUsd'] as num?)?.toDouble() ?? selectedTb * pricePerTbUsd;
                    controller.currentAccount!.storageRequestStatus = 'requested';
                    if (controller.backendApi.isAuthenticated && controller.isBackendAuthenticated) {
                      try { await controller.syncStorageStateToSupabase(); } catch (_) {}
                    }
                  }
                  if (!mounted) return;
                  setState(() {
                    pending = true;
                    requestedTb = selectedTb;
                    requestFeeUsd = (d['feeUsd'] as num?)?.toDouble() ?? selectedTb * pricePerTbUsd;
                    requestStatus = 'requested';
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Storage request sent. Please wait for the platform owner to contact you.')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const UniversalText('SEND REQUEST'),
            ),
          ],
        ),
      ),
    );
  }

  /// Performs `_deleteAccount` for this feature. Update this documentation when its contract changes.
  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const UniversalText('Delete account?'),
            content: const UniversalText('This permanently removes the account, profiles, sessions, '
              'remote workers and account data. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const UniversalText('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const UniversalText('DELETE ACCOUNT'),
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
        title: const UniversalText('Account Settings'),
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
                  const UniversalText('Subscription & currency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  UniversalText('Your base plan is \$10/month or \$100/year USD equivalent. '
                    'Your checkout display uses your device/account country: '
                    '${_currency()}. Current conversion is configurable by '
                    'the service and should be refreshed by the production '
                    'billing provider.',
                  ),
                  const SizedBox(height: 8),
                  UniversalText('Monthly: ${_price(10)}   •   Yearly: ${_price(100)}',
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
                      const UniversalText('Server storage',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      UniversalText('${(pct * 100).toStringAsFixed(0)}%'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                  ),

                  const SizedBox(height: 8),

                  UniversalText('${_size(used)} used of ${_size(limit)}',
                  ),

                  const SizedBox(height: 8),
                  if (pending)
                    UniversalText('Request: +$requestedTb TB • ${requestStatus.replaceAll('_', ' ')} • Fee: ${_price(requestFeeUsd)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
              title: UniversalText('Device roles'),
              subtitle: UniversalText('PC/desktop: remote disc importing. '
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
              title: const UniversalText('Delete account'),
              subtitle: const UniversalText('Permanently stop using the service and remove the account.',
              ),
              onTap: _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
