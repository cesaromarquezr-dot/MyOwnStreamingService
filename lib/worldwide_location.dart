// FILE: lib/worldwide_location.dart
// Purpose: Reusable worldwide address selection for stores and checkout.
// Country/state/city data is supplied by Countrify's bundled global dataset.
// Postal/ZIP codes are entered explicitly because postal-code formats and
// coverage differ by country; the backend can optionally resolve city postal
// codes from a configured postal provider.

import 'package:countrify/countrify.dart';
import 'package:flutter/material.dart';

import 'app_core.dart';

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

  factory WorldwideAddress.fromJson(Map<String, dynamic> json) =>
      WorldwideAddress(
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
///
/// Countrify supplies the worldwide geographic dataset. The country picker
/// remains Countrify's picker, while states and cities are loaded directly
/// through GeoRepository and displayed with Flutter's native dropdowns.
///
/// This avoids relying on Countrify's searchable state/city overlay widgets,
/// while retaining the same bundled offline country/state/city data.
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
  Country? _country;
  CountryState? _state;
  City? _city;

  List<CountryState> _states = <CountryState>[];
  List<City> _cities = <City>[];

  bool _loadingStates = false;
  bool _loadingCities = false;

  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _postal;

  List<String> _postalResults = <String>[];
  bool _loadingPostalCodes = false;

  bool _initializationStarted = false;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialAddress;

    _line1 = TextEditingController(
      text: initial?.addressLine1 ?? '',
    );

    _line2 = TextEditingController(
      text: initial?.addressLine2 ?? '',
    );

    _postal = TextEditingController(
      text: initial?.postalCode ?? '',
    );

    _line1.addListener(_emit);
    _line2.addListener(_emit);
    _postal.addListener(_emit);

    if (initial != null &&
        initial.countryCode.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreInitialAddress(initial);
      });
    }
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _restoreInitialAddress(
    WorldwideAddress initial,
  ) async {
    if (!mounted || _initializationStarted) {
      return;
    }

    _initializationStarted = true;

    try {
      final countries = CountryUtils.getAllCountries();

      Country? matchingCountry;

      for (final country in countries) {
        if (country.alpha2Code.toUpperCase() ==
            initial.countryCode.trim().toUpperCase()) {
          matchingCountry = country;
          break;
        }
      }

      if (matchingCountry == null) {
        return;
      }

      await _loadStates(
        matchingCountry,
        desiredStateName: initial.state,
      );
    } catch (_) {
      // Initial address restoration is best-effort. The user can still
      // select the address manually if the bundled data cannot be loaded.
    }
  }

  Future<void> _loadStates(
    Country country, {
    String? desiredStateName,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _country = country;
      _state = null;
      _city = null;
      _states = <CountryState>[];
      _cities = <City>[];
      _postalResults = <String>[];
      _loadingStates = true;
      _loadingCities = false;
    });

    _emit();

    try {
      final states = await GeoRepository.instance.statesOf(
        country.alpha2Code,
      );

      if (!mounted) {
        return;
      }

      CountryState? restoredState;

      if (desiredStateName != null &&
          desiredStateName.trim().isNotEmpty) {
        final wanted = desiredStateName.trim().toLowerCase();

        for (final state in states) {
          if (state.name.trim().toLowerCase() == wanted) {
            restoredState = state;
            break;
          }
        }
      }

      setState(() {
        _states = states;
        _loadingStates = false;
        _state = restoredState;
      });

      if (restoredState != null) {
        await _loadCities(
          restoredState,
          desiredCityName: widget.initialAddress?.city,
        );
      } else {
        _emit();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _states = <CountryState>[];
        _loadingStates = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load states/provinces: '
            '${error.toString()}',
          ),
        ),
      );

      _emit();
    }
  }

  Future<void> _loadCities(
    CountryState state, {
    String? desiredCityName,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _state = state;
      _city = null;
      _cities = <City>[];
      _postalResults = <String>[];
      _loadingCities = true;
    });

    _emit();

    try {
      final cities = await GeoRepository.instance.citiesOf(
        state.id,
      );

      if (!mounted) {
        return;
      }

      City? restoredCity;

      if (desiredCityName != null &&
          desiredCityName.trim().isNotEmpty) {
        final wanted = desiredCityName.trim().toLowerCase();

        for (final city in cities) {
          if (city.name.trim().toLowerCase() == wanted) {
            restoredCity = city;
            break;
          }
        }
      }

      setState(() {
        _cities = cities;
        _loadingCities = false;
        _city = restoredCity;
      });

      _emit();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cities = <City>[];
        _loadingCities = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load cities: ${error.toString()}',
          ),
        ),
      );

      _emit();
    }
  }

  Future<void> _lookupPostalCodes() async {
    final country = _country;
    final city = _city;

    if (country == null || city == null) {
      return;
    }

    setState(() {
      _loadingPostalCodes = true;
    });

    try {
      final response =
          await AppController.instance.backendApi.getPostalCodes(
        country.alpha2Code,
        city.name,
      );
      final rawPostalCodes = response['postalCodes'];
      final results = rawPostalCodes is List
          ? rawPostalCodes.map((value) => value.toString()).toList()
          : <String>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _postalResults = results;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No postal codes were returned for this city. '
              'You can enter the postal code manually.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('BackendApiException: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingPostalCodes = false;
        });
      }
    }
  }

  void _emit() {
    final country = _country;

    if (country == null) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(
      WorldwideAddress(
        country: country.name,
        countryCode: country.alpha2Code,
        state: _state?.name,
        stateCode: _state?.iso2,
        city: _city?.name,
        postalCode: _postal.text.trim(),
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim(),
      ),
    );
  }

  void _handleCountryChanged(Country? country) {
    if (country == null) {
      setState(() {
        _country = null;
        _state = null;
        _city = null;
        _states = <CountryState>[];
        _cities = <City>[];
        _postalResults = <String>[];
      });

      _emit();
      return;
    }

    _loadStates(country);
  }

  void _handleStateChanged(CountryState? state) {
    if (state == null) {
      setState(() {
        _state = null;
        _city = null;
        _cities = <City>[];
        _postalResults = <String>[];
      });

      _emit();
      return;
    }

    _loadCities(state);
  }

  void _handleCityChanged(City? city) {
    setState(() {
      _city = city;
      _postalResults = <String>[];
    });

    _emit();
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      filled: widget.dark,
      fillColor: widget.dark
          ? Colors.white.withValues(alpha: .04)
          : null,
    );
  }

  CountrifyFieldStyle _countryStyle() {
    return widget.dark
        ? CountrifyFieldStyle.darkStyle()
        : CountrifyFieldStyle.defaultStyle();
  }

  Widget _loadingField({
    required String label,
    required bool loading,
    required bool enabled,
    required String hint,
  }) {
    return InputDecorator(
      decoration: _decoration(label).copyWith(
        enabled: enabled,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loading
                  ? 'Loading...'
                  : hint,
              style: TextStyle(
                color: enabled
                    ? null
                    : Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: .45),
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryStyle = _countryStyle();

    final stateEnabled =
        _country != null &&
        !_loadingStates &&
        _states.isNotEmpty;

    final cityEnabled =
        _state != null &&
        !_loadingCities &&
        _cities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -------------------------------------------------------------------
        // COUNTRY
        // -------------------------------------------------------------------
        CountryDropdownField(
          initialCountryCode: _country == null
              ? null
              : CountryCode.values.firstWhere(
                  (code) =>
                      code.name.toUpperCase() ==
                      _country!.alpha2Code.toUpperCase(),
                  orElse: () => CountryCode.us,
                ),
          showPhoneCode: false,
          showFlag: true,
          searchEnabled: true,
          pickerMode: CountryPickerMode.bottomSheet,
          style: countryStyle.copyWith(
            labelText: 'Country',
            hintText: 'Select country',
          ),
          onChanged: _handleCountryChanged,
        ),

        const SizedBox(height: 10),

        // -------------------------------------------------------------------
        // STATE / PROVINCE / REGION
        // -------------------------------------------------------------------
        if (_loadingStates)
          _loadingField(
            label: 'State / Province / Region',
            loading: true,
            enabled: true,
            hint: 'Loading states/provinces...',
          )
        else
          DropdownButtonFormField<CountryState>(
            key: ValueKey(
              'state-${_country?.alpha2Code ?? 'none'}',
            ),
            initialValue: _state,
            isExpanded: true,
            decoration: _decoration(
              'State / Province / Region',
            ).copyWith(
              enabled: stateEnabled,
            ),
            hint: Text(
              _country == null
                  ? 'Select a country first'
                  : _states.isEmpty
                      ? 'No states/provinces available'
                      : 'Select state, province or region',
            ),
            items: _states
                .map(
                  (state) => DropdownMenuItem<CountryState>(
                    value: state,
                    child: Text(
                      state.iso2 == null ||
                              state.iso2!.trim().isEmpty
                          ? state.name
                          : '${state.name} (${state.iso2})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged:
                stateEnabled ? _handleStateChanged : null,
          ),

        const SizedBox(height: 10),

        // -------------------------------------------------------------------
        // CITY
        // -------------------------------------------------------------------
        if (_loadingCities)
          _loadingField(
            label: 'City',
            loading: true,
            enabled: true,
            hint: 'Loading cities...',
          )
        else
          DropdownButtonFormField<City>(
            key: ValueKey(
              'city-${_state?.id ?? 'none'}',
            ),
            initialValue: _city,
            isExpanded: true,
            decoration: _decoration('City').copyWith(
              enabled: cityEnabled,
            ),
            hint: Text(
              _state == null
                  ? 'Select a state/province first'
                  : _cities.isEmpty
                      ? 'No cities available'
                      : 'Select city',
            ),
            items: _cities
                .map(
                  (city) => DropdownMenuItem<City>(
                    value: city,
                    child: Text(
                      city.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged:
                cityEnabled ? _handleCityChanged : null,
          ),

        const SizedBox(height: 10),

        // -------------------------------------------------------------------
        // POSTAL / ZIP
        // -------------------------------------------------------------------
        TextField(
          controller: _postal,
          textInputAction: TextInputAction.next,
          decoration: _decoration('Postal / ZIP code'),
        ),

        if (_country != null && _city != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  _loadingPostalCodes ? null : _lookupPostalCodes,
              icon: _loadingPostalCodes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: const Text(
                'Find postal / ZIP codes for this city',
              ),
            ),
          ),
          if (_postalResults.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue:
                  _postalResults.contains(_postal.text)
                      ? _postal.text
                      : null,
              decoration: _decoration(
                'Available postal / ZIP codes',
              ),
              items: _postalResults
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Text(code),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _postal.text = value;
                _emit();
              },
            ),
        ],

        const SizedBox(height: 10),

        // -------------------------------------------------------------------
        // STREET
        // -------------------------------------------------------------------
        TextField(
          controller: _line1,
          textInputAction: TextInputAction.next,
          decoration: _decoration(
            widget.requireStreet
                ? 'Address line 1 (required)'
                : 'Address line 1',
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: _line2,
          textInputAction: TextInputAction.done,
          decoration: _decoration(
            'Address line 2 (optional)',
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Worldwide location data: countries, states/provinces/regions '
          'and cities are available offline. Postal codes use the format '
          'appropriate to the selected country.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: widget.dark ? Colors.white60 : null,
              ),
        ),
      ],
    );
  }
}