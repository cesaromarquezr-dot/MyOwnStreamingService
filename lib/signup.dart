import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'payment.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  SubscriptionPlan selectedPlan = SubscriptionPlan.monthly;

  bool rememberLogin = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool creatingAccount = false;

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    if (creatingAccount) return;

    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('Please fill in every field.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      creatingAccount = true;
    });

    try {
      final signupData =
          await AppController.instance.createAccountWithBackend(
        username: username,
        email: email,
        password: password,
        plan: selectedPlan,
        firstProfileName: username,
      );

      if (!mounted) return;

      final payment = signupData['payment'];

      if (payment is! Map) {
        throw Exception(
          'No payment session was returned by the server.',
        );
      }

      final paymentId = payment['id']?.toString();

      final checkoutToken =
          payment['checkoutToken']?.toString();

      final amountValue = payment['amount'];

      final currency =
          payment['currency']?.toString() ?? 'USD';

      if (paymentId == null || paymentId.isEmpty) {
        throw Exception(
          'Payment session did not contain a payment ID.',
        );
      }

      if (checkoutToken == null || checkoutToken.isEmpty) {
        throw Exception(
          'Payment session did not contain checkout authorization.',
        );
      }

      double amount;

      if (amountValue is num) {
        amount = amountValue.toDouble();
      } else {
        amount = double.tryParse(
              amountValue?.toString() ?? '',
            ) ??
            0.0;
      }

      if (amount <= 0) {
        throw Exception(
          'Payment session returned an invalid amount.',
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentId: paymentId,
            checkoutToken: checkoutToken,
            plan: selectedPlan,
            amount: amount,
            currency: currency,
            username: username,
            rememberLogin: rememberLogin,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      String message = 'Unable to create account.';

      final errorText = error.toString();

      if (errorText.contains('Username is already')) {
        message = 'That username is already in use.';
      } else if (errorText.contains('Email is already')) {
        message = 'That email is already in use.';
      } else if (errorText.contains('Password')) {
        message = errorText
            .replaceFirst('BackendApiException:', '')
            .replaceFirst('Exception:', '')
            .trim();
      } else if (errorText.isNotEmpty) {
        message = errorText
            .replaceFirst('BackendApiException:', '')
            .replaceFirst('Exception:', '')
            .trim();
      }

      if (message.isEmpty) {
        message = 'Unable to create account.';
      }

      showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          creatingAccount = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get selectedPlanPrice {
    switch (selectedPlan) {
      case SubscriptionPlan.monthly:
        return '\$9.99 USD / month';

      case SubscriptionPlan.yearly:
        return '\$99.99 USD / year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool compactLayout = size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background glow.
          Positioned(
            top: -180,
            left: -120,
            child: _backgroundGlow(
              size: compactLayout ? 380 : 520,
            ),
          ),

          Positioned(
            bottom: -220,
            right: -150,
            child: _backgroundGlow(
              size: compactLayout ? 420 : 600,
            ),
          ),

          // Subtle background grid / atmosphere.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BackgroundPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: compactLayout ? 18 : 32,
                  vertical: compactLayout ? 24 : 44,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 620,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: 1,
                    ),
                    duration: const Duration(
                      milliseconds: 750,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (
                      context,
                      animation,
                      child,
                    ) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          35 * (1 - animation),
                        ),
                        child: Opacity(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _buildSignupCard(
                      context,
                      compactLayout,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundGlow({
    required double size,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.075),
              Colors.white.withValues(alpha: 0.025),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupCard(
    BuildContext context,
    bool compactLayout,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        compactLayout ? 24 : 30,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 22,
          sigmaY: 22,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(
              compactLayout ? 24 : 30,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 50,
                spreadRadius: 4,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compactLayout ? 22 : 42,
              compactLayout ? 28 : 38,
              compactLayout ? 22 : 42,
              compactLayout ? 24 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),

                const SizedBox(height: 25),

                const Text(
                  'Create your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  'Start building your personal streaming experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 30),

                _buildSectionLabel('ACCOUNT'),

                const SizedBox(height: 12),

                _buildTextField(
                  controller: usernameController,
                  label: 'Username',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller: emailController,
                  label: 'Email address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: creatingAccount
                        ? null
                        : () {
                            setState(() {
                              obscurePassword =
                                  !obscurePassword;
                            });
                          },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _buildTextField(
                  controller: confirmController,
                  label: 'Confirm password',
                  icon: Icons.lock_reset_outlined,
                  obscureText: obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!creatingAccount) {
                      createAccount();
                    }
                  },
                  suffixIcon: IconButton(
                    tooltip: obscureConfirm
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: creatingAccount
                        ? null
                        : () {
                            setState(() {
                              obscureConfirm =
                                  !obscureConfirm;
                            });
                          },
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                _buildSectionLabel('CHOOSE YOUR PLAN'),

                const SizedBox(height: 12),

                _buildPlanCard(
                  plan: SubscriptionPlan.monthly,
                  title: '\$9.99 USD',
                  subtitle: 'per month',
                  description: 'Billed monthly',
                  badge: null,
                ),

                const SizedBox(height: 10),

                _buildPlanCard(
                  plan: SubscriptionPlan.yearly,
                  title: '\$99.99 USD',
                  subtitle: 'per year',
                  description: 'Billed once per year',
                  badge: 'BEST VALUE',
                ),

                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 250,
                  ),
                  transitionBuilder: (
                    child,
                    animation,
                  ) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey(selectedPlan),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.045,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.07,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 19,
                          color: Colors.white.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selected: $selectedPlanPrice',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: 0.82,
                              ),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor:
                        Colors.white.withValues(alpha: 0.45),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: rememberLogin,
                    onChanged: creatingAccount
                        ? null
                        : (value) {
                            setState(() {
                              rememberLogin =
                                  value ?? false;
                            });
                          },
                    title: Text(
                      'Remember my login',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 14,
                      ),
                    ),
                    controlAffinity:
                        ListTileControlAffinity.leading,
                    activeColor: Colors.white,
                    checkColor: Colors.black,
                  ),
                ),

                const SizedBox(height: 10),

                _buildContinueButton(),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: creatingAccount
                      ? null
                      : () {
                          Navigator
                              .pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Colors.white.withValues(alpha: 0.75),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Already have an account?  Sign in',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'By continuing, you agree to the terms of service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Hero(
        tag: 'app-logo',
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/symbol.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: !creatingAccount,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
        ),
        floatingLabelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.43),
          size: 21,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.055),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.075),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.32),
            width: 1.2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.045),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String title,
    required String subtitle,
    required String description,
    required String? badge,
  }) {
    final selected = selectedPlan == plan;

    return AnimatedScale(
      scale: selected ? 1.0 : 0.985,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: creatingAccount
            ? null
            : () {
                setState(() {
                  selectedPlan = plan;
                });
              },
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.105)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.075),
              width: selected ? 1.3 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(
                            alpha: 0.32,
                          ),
                    width: selected ? 6 : 2,
                  ),
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
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.45,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.48,
                        ),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.82,
                      ),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: creatingAccount
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.28,
                    ),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: creatingAccount
              ? null
              : createAccount,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor:
                Colors.white.withValues(alpha: 0.14),
            disabledForegroundColor:
                Colors.white.withValues(alpha: 0.55),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 220,
            ),
            transitionBuilder: (
              child,
              animation,
            ) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: creatingAccount
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : const Row(
                    key: ValueKey('continue'),
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        'CONTINUE TO PAYMENT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      SizedBox(width: 9),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;

    const spacing = 55.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

// Compatibility alias.
class Signup extends SignupScreen {
  const Signup({
    super.key,
  });
}