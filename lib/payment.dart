import 'package:flutter/material.dart';

import 'app_core.dart';

// ============================================================
// PAYMENT SCREEN
// ============================================================

class PaymentScreen extends StatefulWidget {
  final String paymentId;
  final String checkoutToken;
  final SubscriptionPlan plan;
  final double amount;
  final String currency;
  final String username;
  final bool rememberLogin;

  const PaymentScreen({
    super.key,
    required this.paymentId,
    required this.checkoutToken,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.username,
    required this.rememberLogin,
  });

  @override
  State<PaymentScreen> createState() =>
      _PaymentScreenState();
}

// ============================================================
// PAYMENT STATE
// ============================================================

class _PaymentScreenState
    extends State<PaymentScreen> {
  final TextEditingController
      transactionController =
      TextEditingController();

  bool processing = false;
  bool paymentSucceeded = false;

  String? errorMessage;

  @override
  void dispose() {
    transactionController.dispose();
    super.dispose();
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  Future<void> completePayment() async {
    if (processing) {
      return;
    }

    final processorTransactionId =
        transactionController.text.trim();

    if (processorTransactionId.isEmpty) {
      setState(() {
        errorMessage =
            'Enter your payment transaction ID.';
      });

      return;
    }

    if (processorTransactionId.length < 6) {
      setState(() {
        errorMessage =
            'The payment transaction ID is too short.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      processing = true;
      errorMessage = null;
    });

    try {
      final result =
          await AppController
              .instance
              .backendApi
              .verifyCheckoutPayment(
        paymentId: widget.paymentId,
        checkoutToken:
            widget.checkoutToken,
        processorTransactionId:
            processorTransactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        processing = false;
        paymentSucceeded = true;
      });

      await Future<void>.delayed(
        const Duration(
          milliseconds: 900,
        ),
      );

      if (!mounted) {
        return;
      }

      // Payment verification intentionally does NOT
      // authenticate the user. The user must log in
      // normally after payment succeeds.
      //
      // We return to the previous screen rather than
      // assuming where the application's login route
      // lives. main.dart can decide the final routing.
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        processing = false;
        paymentSucceeded = false;
        errorMessage =
            _cleanErrorMessage(e);
      });
    }
  }

  // ==========================================================
  // ERROR MESSAGE
  // ==========================================================

  String _cleanErrorMessage(
    Object error,
  ) {
    final message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ==========================================================
  // PLAN DISPLAY
  // ==========================================================

  String get planName {
    switch (widget.plan) {
      case SubscriptionPlan.monthly:
        return 'Monthly';
      case SubscriptionPlan.yearly:
        return 'Yearly';
    }
  }

  String get billingDescription {
    switch (widget.plan) {
      case SubscriptionPlan.monthly:
        return 'Billed every month';
      case SubscriptionPlan.yearly:
        return 'Billed every year';
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Complete Payment',
        ),
        centerTitle: true,
        automaticallyImplyLeading:
            !processing &&
            !paymentSucceeded,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),
              child:
                  paymentSucceeded
                      ? _buildSuccessState(
                          theme,
                        )
                      : _buildPaymentForm(
                          theme,
                        ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PAYMENT FORM
  // ==========================================================

  Widget _buildPaymentForm(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.lock_outline,
          size: 52,
        ),

        const SizedBox(
          height: 20,
        ),

        Text(
          'Activate your subscription',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.headlineSmall
                  ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Text(
          'Complete your payment to activate your account.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium,
        ),

        const SizedBox(
          height: 28,
        ),

        // ====================================================
        // PLAN CARD
        // ====================================================

        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons
                          .subscriptions_outlined,
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            '$planName Plan',
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            billingDescription,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                    ),

                    Text(
                      '\$${widget.amount.toStringAsFixed(2)}',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                const Divider(),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    const Text(
                      'Total',
                    ),
                    Text(
                      '\$${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        // ====================================================
        // TRANSACTION ID
        // ====================================================

        TextField(
          controller:
              transactionController,
          enabled: !processing,
          textInputAction:
              TextInputAction.done,
          onSubmitted: (_) =>
              completePayment(),
          decoration:
              const InputDecoration(
            labelText:
                'Payment Transaction ID',
            hintText:
                'Enter the transaction ID',
            border:
                OutlineInputBorder(),
            prefixIcon: Icon(
              Icons.receipt_long_outlined,
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Text(
          'Your card or bank details are not sent to this app backend. The payment processor should provide the transaction ID.',
          style:
              theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),

        // ====================================================
        // ERROR
        // ====================================================

        if (errorMessage != null) ...[
          const SizedBox(
            height: 16,
          ),

          Container(
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              color: theme
                  .colorScheme
                  .errorContainer,
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: theme
                    .colorScheme
                    .onErrorContainer,
              ),
            ),
          ),
        ],

        const SizedBox(
          height: 24,
        ),

        // ====================================================
        // PAY BUTTON
        // ====================================================

        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed:
                processing
                    ? null
                    : completePayment,
            child:
                processing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'COMPLETE PAYMENT',
                      ),
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          'Payment ID: ${widget.paymentId}',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

  Widget _buildSuccessState(
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 80,
        ),

        const SizedBox(
          height: 24,
        ),

        Text(
          'Payment successful',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.headlineSmall
                  ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Text(
          'Your subscription has been activated.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyLarge,
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          'Please log in to continue.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium,
        ),

        const SizedBox(
          height: 28,
        ),

        const Center(
          child:
              CircularProgressIndicator(),
        ),
      ],
    );
  }
}