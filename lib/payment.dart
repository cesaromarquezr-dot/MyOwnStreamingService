// FILE: `lib/payment.dart`.
// Purpose: Implements the payment portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

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
  final String email;
  final bool rememberLogin;

  const PaymentScreen({
    super.key,
    required this.paymentId,
    required this.checkoutToken,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.email,
    required this.rememberLogin,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

// ============================================================
// PAYMENT STATE
// ============================================================

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController transactionController =
      TextEditingController();

  bool processing = false;
  bool paymentSucceeded = false;

  String? errorMessage;

  late final AnimationController _animationController;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    transactionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  /// Performs `completePayment` for this feature. Update this documentation when its contract changes.
  Future<void> completePayment() async {
    if (processing) {
      return;
    }

    final processorTransactionId =
        transactionController.text.trim();

    if (processorTransactionId.isEmpty) {
      setState(() {
        errorMessage = 'Enter your payment transaction ID.';
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
      final result = await AppController.instance.backendApi
          .verifyCheckoutPayment(
        paymentId: widget.paymentId,
        checkoutToken: widget.checkoutToken,
        processorTransactionId: processorTransactionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        processing = false;
        paymentSucceeded = true;
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 900),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        processing = false;
        paymentSucceeded = false;
        errorMessage = _cleanErrorMessage(e);
      });
    }
  }

  // ==========================================================
  // ERROR MESSAGE
  // ==========================================================

  /// Performs `_cleanErrorMessage` for this feature. Update this documentation when its contract changes.
  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
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

  String get billingShortLabel {
    switch (widget.plan) {
      case SubscriptionPlan.monthly:
        return 'MONTHLY';
      case SubscriptionPlan.yearly:
        return 'YEARLY';
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          _buildBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isWide),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: paymentSucceeded
                        ? _buildSuccessState(isWide)
                        : _buildPaymentContent(isWide),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BACKGROUND
  // ==========================================================

  /// Performs `_buildBackground` for this feature. Update this documentation when its contract changes.
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final glow = 0.05 +
            (_animationController.value * 0.025);

        return Stack(
          children: [
            Positioned(
              top: -180,
              left: -140,
              child: Container(
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: glow,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -180,
              bottom: -200,
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: glow * 0.7,
                  ),
                ),
              ),
            ),
            child ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }

  // ==========================================================
  // TOP BAR
  // ==========================================================

  /// Performs `_buildTopBar` for this feature. Update this documentation when its contract changes.
  Widget _buildTopBar(bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 32 : 18,
        vertical: 14,
      ),
      child: Row(
        children: [
          if (!processing && !paymentSucceeded)
            _buildGlassIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 44),

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURE CHECKOUT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),

          const Spacer(),

          const SizedBox(width: 44),
        ],
      ),
    );
  }

  /// Performs `_buildGlassIconButton` for this feature. Update this documentation when its contract changes.
  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PAYMENT CONTENT
  // ==========================================================

  /// Performs `_buildPaymentContent` for this feature. Update this documentation when its contract changes.
  Widget _buildPaymentContent(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 20,
          18,
          isWide ? 32 : 20,
          40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(height: 28),

              _buildPaymentCard(),

              const SizedBox(height: 18),

              _buildSecurityNotice(),

              const SizedBox(height: 18),

              Text(
                'Payment ID: ${widget.paymentId}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  /// Performs `_buildHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildHeader() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final scale =
                1 + (_animationController.value * 0.025);

            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Complete your subscription',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Activate your account and start watching.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PAYMENT CARD
  // ==========================================================

  /// Performs `_buildPaymentCard` for this feature. Update this documentation when its contract changes.
  Widget _buildPaymentCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 35,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlanSection(),

            const SizedBox(height: 26),

            _buildTransactionField(),

            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildError(),
            ],

            const SizedBox(height: 22),

            _buildPayButton(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PLAN SECTION
  // ==========================================================

  /// Performs `_buildPlanSection` for this feature. Update this documentation when its contract changes.
  Widget _buildPlanSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$planName Plan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Text(
                            billingShortLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      billingDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.45,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

          ),

          const SizedBox(height: 18),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),

          const SizedBox(height: 17),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.currency,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TRANSACTION FIELD
  // ==========================================================

  /// Performs `_buildTransactionField` for this feature. Update this documentation when its contract changes.
  Widget _buildTransactionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 3),
          child: Text(
            'PAYMENT TRANSACTION ID',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: transactionController,
          enabled: !processing,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => completePayment(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Enter your transaction ID',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.receipt_long_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 21,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.045),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SECURITY NOTICE
  // ==========================================================

  /// Performs `_buildSecurityNotice` for this feature. Update this documentation when its contract changes.
  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 19,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Your card or bank details are not sent to this app backend. The payment processor should provide the transaction ID.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  /// Performs `_buildError` for this feature. Update this documentation when its contract changes.
  Widget _buildError() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PAY BUTTON
  // ==========================================================

  /// Performs `_buildPayButton` for this feature. Update this documentation when its contract changes.
  Widget _buildPayButton() {
    return SizedBox(
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: processing
              ? null
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: processing ? null : completePayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor:
                Colors.white.withValues(alpha: 0.12),
            disabledForegroundColor:
                Colors.white.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: processing
                ? const Row(
                    key: ValueKey('processing'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 11),
                      Text(
                        'VERIFYING PAYMENT...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    key: ValueKey('pay'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 17,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'COMPLETE PAYMENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

  /// Performs `_buildSuccessState` for this feature. Update this documentation when its contract changes.
  Widget _buildSuccessState(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 22,
          vertical: 30,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ),
          child: Column(
            children: [
              _buildSuccessIcon(),

              const SizedBox(height: 28),

              const Text(
                'Payment successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Your subscription has been activated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Please log in to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 30),

              _buildSuccessSummary(),

              const SizedBox(height: 28),

              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 13),

              Text(
                'Returning you to the app...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_buildSuccessIcon` for this feature. Update this documentation when its contract changes.
  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scale =
            1 + (_animationController.value * 0.035);

        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 105,
        height: 105,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.greenAccent.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.08),
              blurRadius: 45,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.greenAccent,
          size: 54,
        ),
      ),
    );
  }

  /// Performs `_buildSuccessSummary` for this feature. Update this documentation when its contract changes.
  Widget _buildSuccessSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '$planName Plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscription activated',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '\$${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
