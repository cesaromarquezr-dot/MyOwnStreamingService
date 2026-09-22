// FILE: Backend/services/mock_payment_processor.dart.
//
// Purpose:
// Provides a development-only payment processor verifier for local checkout
// testing. It is intentionally simple and MUST NOT be used in production.
//
// Security contract:
// - This verifier is only wired when ARM_MOCK=true.
// - It never accepts card numbers, CVVs, bank credentials, or passwords.
// - A numeric transaction ID is only a test fixture identifier.
// - The application PaymentService still verifies amount, currency, status,
//   ownership, expiration, and transaction-ID matching.

import '../models/payment_session.dart';
import 'payment_service.dart';

/// Creates a development-only payment processor verifier.
///
/// Local test transaction IDs may be any 6-32 digit value. IDs beginning with
/// `FAIL` intentionally simulate a processor-declined transaction so the
/// failure path can be tested.
PaymentProcessorVerifier createMockPaymentProcessorVerifier() {
  return (
    PaymentSession payment,
    String processorTransactionId,
  ) async {
    final transactionId = processorTransactionId.trim();

    // Keep the mock asynchronous so the production integration contract is
    // exercised in the same way as a real network-backed provider.
    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (transactionId.toUpperCase().startsWith('FAIL')) {
      return PaymentVerificationResult(
        succeeded: false,
        transactionId: transactionId,
        amount: payment.amount,
        currency: payment.currency,
      );
    }

    final isNumericTestId =
        RegExp(r'^\d{6,32}$').hasMatch(transactionId);

    final isPrefixedTestId =
        RegExp(r'^MOCK-[A-Z0-9_-]{3,64}$')
            .hasMatch(transactionId.toUpperCase());

    if (!isNumericTestId && !isPrefixedTestId) {
      return PaymentVerificationResult(
        succeeded: false,
        transactionId: transactionId,
        amount: payment.amount,
        currency: payment.currency,
      );
    }

    return PaymentVerificationResult(
      succeeded: true,
      transactionId: transactionId,
      amount: payment.amount,
      currency: payment.currency,
    );
  };
}
