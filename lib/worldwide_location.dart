// FILE: lib/worldwide_location.dart
// Purpose: Reusable worldwide address selection for stores and checkout.
// Country/state/city data is supplied by Countrify's bundled global dataset.
// Postal/ZIP codes are entered explicitly because postal-code formats and
// coverage differ by country; the backend can optionally resolve city postal
// codes from a configured postal provider.

import 'package:countrify/countrify.dart';

import 'app_core.dart';
import 'package:flutter/material.dart';

/// A normalized address used by store and checkout flows.
class WorldwideAddress {
  final String country;
  final String countryCode;
  final String? state;
  final String? stateCode;
  final String? city;
  final String postalCode;
  final String addressLine1;
  final String addressLine2;

  const WorldwideAddress({
    required this.country,
    required this.countryCode,
    required this.postalCode,
    this.state,
    this.stateCode,
    this.city,
    this.addressLine1 = '',
    this.addressLine2 = '',
  });

  bool get isComplete =>
      country.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty &&
      (city?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
        'country': country,
        'countryCode': countryCode,
        'state': state,
        'stateCode': stateCode,
        'city': city,
        'postalCode': postalCode,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
      };

  factory WorldwideAddress.fromJson(Map<String, dynamic> json) => WorldwideAddress(
        country: json['country']?.toString() ?? '',
        countryCode: json['countryCode']?.toString() ?? '',
        state: json['state']?.toString(),
        stateCode: json['stateCode']?.toString(),
        city: json['city']?.toString(),
        postalCode: json['postalCode']?.toString() ?? '',
        addressLine1: json['addressLine1']?.toString() ?? '',
        addressLine2: json['addressLine2']?.toString() ?? '',
      );

  String get summary => [
        if (addressLine1.trim().isNotEmpty) addressLine1.trim(),
        if (addressLine2.trim().isNotEmpty) addressLine2.trim(),
        if (city?.trim().isNotEmpty ?? false) city!.trim(),
        if (state?.trim().isNotEmpty ?? false) state!.trim(),
        postalCode.trim(),
        country.trim(),
      ].join(', ');
}

/// Country → state/province → city → postal/ZIP address editor.
class WorldwideAddressForm extends StatefulWidget {
  final WorldwideAddress? initialAddress;
  final ValueChanged<WorldwideAddress?> onChanged;
  final bool requireStreet;
  final bool dark;

  const WorldwideAddressForm({
    super.key,
    this.initialAddress,
    required this.onChanged,
    this.requireStreet = false,
    this.dark = false,
  });

  @override
  State<WorldwideAddressForm> createState() => _WorldwideAddressFormState();
}

class _WorldwideAddressFormState extends State<WorldwideAddressForm> {
  CountryStateCitySelection? _selection;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _postal;
  List<String> _postalResults = <String>[];
  bool _loadingPostalCodes = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress;
    _line1 = TextEditingController(text: initial?.addressLine1 ?? '');
    _line2 = TextEditingController(text: initial?.addressLine2 ?? '');
    _postal = TextEditingController(text: initial?.postalCode ?? '');
    _line1.addListener(_emit);
    _line2.addListener(_emit);
    _postal.addListener(_emit);
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _lookupPostalCodes() async {
    final country = _selection?.country;
    final city = _selection?.city;
    if (country == null || city == null) return;
    setState(() => _loadingPostalCodes = true);
    try {
      final results = await AppController.instance.backendApi.getPostalCodes(
        countryCode: country.alpha2Code,
        city: city.name,
      );
      if (!mounted) return;
      setState(() => _postalResults = results);
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No postal codes were returned for this city. You can enter the postal code manually.')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('BackendApiException: ', ''))));
    } finally {
      if (mounted) setState(() => _loadingPostalCodes = false);
    }
  }

  void _emit() {
    final country = _selection?.country;
    final state = _selection?.state;
    final city = _selection?.city;
    if (country == null) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(
      WorldwideAddress(
        country: country.name,
        countryCode: country.alpha2Code,
        state: state?.name,
        stateCode: state?.iso2,
        city: city?.name,
        postalCode: _postal.text.trim(),
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim(),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: widget.dark,
        fillColor: widget.dark ? Colors.white.withValues(alpha: .04) : null,
      );

  @override
  Widget build(BuildContext context) {
    final style = widget.dark
        ? CountrifyFieldStyle.darkStyle()
        : CountrifyFieldStyle.defaultStyle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CountryStateCityField(
          spacing: 10,
          fieldStyle: style,
          onChanged: (selection) {
            setState(() => _selection = selection);
            _emit();
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _postal,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Postal / ZIP code'),
        ),
        if (_selection?.country != null && _selection?.city != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loadingPostalCodes ? null : _lookupPostalCodes,
              icon: _loadingPostalCodes
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('Find postal / ZIP codes for this city'),
            ),
          ),
          if (_postalResults.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _postalResults.contains(_postal.text) ? _postal.text : null,
              decoration: _decoration('Available postal / ZIP codes'),
              items: _postalResults
                  .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _postal.text = value;
                _emit();
              },
            ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _line1,
          textInputAction: TextInputAction.next,
          decoration: _decoration(
            widget.requireStreet ? 'Address line 1 (required)' : 'Address line 1',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _line2,
          textInputAction: TextInputAction.done,
          decoration: _decoration('Address line 2 (optional)'),
        ),
        const SizedBox(height: 8),
        Text(
          'Worldwide location data: countries, states/provinces/regions and cities are available offline. Postal codes use the format appropriate to the selected country.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: widget.dark ? Colors.white60 : null,
              ),
        ),
      ],
    );
  }
}
