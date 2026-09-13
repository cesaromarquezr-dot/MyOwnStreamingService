// FILE: `Backend/config.dart`.
// Purpose: Implements the config portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:io';

/// Implements the `AppConfig` class for this feature or UI component.
class AppConfig {
  // ---------------------------------------------------------------------------
  // SERVER
  // ---------------------------------------------------------------------------

  /// Bind address for the home server. Use 0.0.0.0 so LAN clients can connect.
  static String get host => Platform.environment['SERVER_HOST']?.trim().isNotEmpty == true ? Platform.environment['SERVER_HOST']!.trim() : '0.0.0.0';

  static const int port = 8080;

  static const String apiVersion =
      'v1';

  static String get baseUrl {
    return Platform.environment['SERVER_PUBLIC_URL']?.trim().isNotEmpty == true
        ? Platform.environment['SERVER_PUBLIC_URL']!.trim()
        : 'http://127.0.0.1:$port';
  }

  static String get apiBaseUrl {
    return '$baseUrl/api/$apiVersion';
  }

  // ARM
  // Set ARM_SERVER_URL in the backend environment to the ARM web UI,
  // for example http://192.168.1.50:8080.
  static String get armServerUrl =>
      Platform.environment['ARM_SERVER_URL']?.trim().isNotEmpty == true
          ? Platform.environment['ARM_SERVER_URL']!.trim()
          : 'http://127.0.0.1:8081';

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  // Absolute lifetime of a normal login session.
  //
  // Later we can make this configurable per device/trust level.
  static const Duration sessionLifetime =
      Duration(days: 30);

  // Minimum password length for the first
  // authentication implementation.
  //
  // We will strengthen the password policy in
  // the next authentication pass.
  static const int minimumPasswordLength =
      6;

  /// Root directory containing server-managed media.
  static String get mediaRoot => Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true ? Platform.environment['MEDIA_ROOT']!.trim() : './media';
  /// Default Movies capacity: 1 TB. Override with MOVIES_CAPACITY_BYTES.
  static int get moviesCapacityBytes => int.tryParse(Platform.environment['MOVIES_CAPACITY_BYTES'] ?? '') ?? 1000000000000;
  /// Default Series capacity: 5 TB. Override with SERIES_CAPACITY_BYTES.
  static int get seriesCapacityBytes => int.tryParse(Platform.environment['SERIES_CAPACITY_BYTES'] ?? '') ?? 5000000000000;
  /// Default Music capacity: 32 GB. Override with MUSIC_CAPACITY_BYTES.
  static int get musicCapacityBytes => int.tryParse(Platform.environment['MUSIC_CAPACITY_BYTES'] ?? '') ?? 32000000000;
  /// Default free/available pool shown by the dashboard: 20 TB.
  static int get availableStorageBytes => int.tryParse(Platform.environment['AVAILABLE_STORAGE_BYTES'] ?? '') ?? 20000000000000;

  // ---------------------------------------------------------------------------
  // MANAGED SERVER PRICING
  // ---------------------------------------------------------------------------
  // These are deliberately configurable assumptions rather than hard-coded
  // facts. Operators can replace them with their real hardware, energy,
  // bandwidth, payment-processing and support costs through environment vars.
  static double get serverHardwareCostUsd => double.tryParse(Platform.environment['SERVER_HARDWARE_COST_USD'] ?? '') ?? 650.0;
  static double get serverStorageCostUsd => double.tryParse(Platform.environment['SERVER_STORAGE_COST_USD'] ?? '') ?? 180.0;
  static int get serverAmortizationMonths => int.tryParse(Platform.environment['SERVER_AMORTIZATION_MONTHS'] ?? '') ?? 36;
  static double get serverAverageWatts => double.tryParse(Platform.environment['SERVER_AVERAGE_WATTS'] ?? '') ?? 45.0;
  static double get electricityRateUsdPerKwh => double.tryParse(Platform.environment['ELECTRICITY_USD_PER_KWH'] ?? '') ?? 0.16;
  static double get monthlyBandwidthOpsCostUsd => double.tryParse(Platform.environment['MONTHLY_BANDWIDTH_OPS_USD'] ?? '') ?? 6.0;
  static double get monthlySupportReserveUsd => double.tryParse(Platform.environment['MONTHLY_SUPPORT_RESERVE_USD'] ?? '') ?? 4.0;
  static double get paymentProcessingRate => double.tryParse(Platform.environment['PAYMENT_PROCESSING_RATE'] ?? '') ?? 0.035;
  static double get paymentProcessingFixedUsd => double.tryParse(Platform.environment['PAYMENT_PROCESSING_FIXED_USD'] ?? '') ?? 0.30;
  static double get targetGrossMargin => double.tryParse(Platform.environment['TARGET_GROSS_MARGIN'] ?? '') ?? 0.25;
  /// Publicly configurable one-time price per additional TB of physical storage.
  static double get additionalStoragePricePerTbUsd => double.tryParse(Platform.environment['ADDITIONAL_STORAGE_PRICE_PER_TB_USD'] ?? '') ?? 75.0;

  /// Calculates the estimated monthly operating cost of one managed server.
  static double get estimatedMonthlyServerCostUsd {
    final hardware = (serverHardwareCostUsd + serverStorageCostUsd) / serverAmortizationMonths;
    final electricity = serverAverageWatts * 24 * 30 / 1000 * electricityRateUsdPerKwh;
    return hardware + electricity + monthlyBandwidthOpsCostUsd + monthlySupportReserveUsd;
  }

  /// Calculates a subscription price that covers estimated server cost and the
  /// configured target gross margin after a percentage-plus-fixed payment fee.
  static double get profitableMonthlyPriceUsd {
    final cost = estimatedMonthlyServerCostUsd + paymentProcessingFixedUsd;
    final denominator = 1 - paymentProcessingRate - targetGrossMargin;
    final raw = denominator <= 0 ? cost : cost / denominator;
    final calculated = (raw * 100).ceilToDouble() / 100;
    // Use a predictable retail price while never pricing below the calculated
    // break-even-plus-margin floor.
    return calculated < 54.99 ? 54.99 : calculated;
  }

  /// Returns the public price for one account with one managed home server.
  static double get monthlySubscriptionPriceUsd => profitableMonthlyPriceUsd;

  /// Annual billing receives a modest discount while retaining a positive
  /// contribution margin for the managed server service.
  static double get yearlySubscriptionPriceUsd {
    final monthly = monthlySubscriptionPriceUsd;
    final discounted = monthly * 12 * 0.91;
    final calculated = (discounted * 100).ceilToDouble() / 100;
    return calculated < 599.99 ? 599.99 : calculated;
  }
}
