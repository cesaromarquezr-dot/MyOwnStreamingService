// FILE: `lib/signup.dart`.
// Purpose: Implements the signup portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'payment.dart';
import 'how_it_works.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final securityAnswerController = TextEditingController();
  final customQuestionController = TextEditingController();

  static const securityQuestions = [
    'What was the name of your first pet?',
    'What city were you born in?',
    'What was the name of your first school?',
    'What is your favorite movie?',
    'Create my own question',
  ];
  String selectedSecurityQuestion = securityQuestions.first;

  SubscriptionPlan selectedPlan = SubscriptionPlan.monthly;

  bool rememberLogin = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool creatingAccount = false;
  bool termsAccepted = false;
  bool privacyAccepted = false;
  bool acceptableUseAccepted = false;

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    securityAnswerController.dispose();
    customQuestionController.dispose();
    super.dispose();
  }

  /// Performs `createAccount` for this feature. Update this documentation when its contract changes.
  Future<void> createAccount() async {
  if (creatingAccount) return;

  final email = emailController.text.trim();
  final password = passwordController.text;
  final confirm = confirmController.text;
  final securityQuestion = selectedSecurityQuestion == 'Create my own question'
      ? customQuestionController.text.trim()
      : selectedSecurityQuestion;
  final securityAnswer = securityAnswerController.text.trim();

  if (email.isEmpty ||
      password.isEmpty ||
      confirm.isEmpty) {
    _showMessage('Please complete all fields.');
    return;
  }

  if (password.length < 6) {
    _showMessage('Password must be at least 6 characters.');
    return;
  }

  if (password != confirm) {
    _showMessage('Passwords do not match.');
    return;
  }

  if (!termsAccepted || !privacyAccepted || !acceptableUseAccepted) {
    _showMessage('Please review and accept the Terms of Service, Privacy Policy, and Copyright & Acceptable Use Policy.');
    return;
  }

  setState(() {
    creatingAccount = true;
  });

  try {
    final signupData =
        await AppController.instance.createAccountWithBackend(
      email: email,
      password: password,
      plan: selectedPlan,
      firstProfileName: '',
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );

    if (!mounted) return;

    final paymentData = signupData['payment'];

    if (paymentData is! Map) {
      throw Exception('Payment information was not returned.');
    }

    final paymentId =
    paymentData['id']?.toString() ??
    paymentData['paymentId']?.toString() ??
    '';

final checkoutToken =
    paymentData['checkoutToken']?.toString() ??
    '';

final amount = paymentData['amount'];

final currency =
    paymentData['currency']?.toString() ??
    '';

    if (paymentId.isEmpty) {
  throw Exception(
    'Payment session was created but no payment ID was returned.',
  );
}

if (checkoutToken.isEmpty) {
  throw Exception(
    'Payment session was created but no checkout authorization was returned.',
  );
}

if (amount == null) {
  throw Exception(
    'Payment session was created but no payment amount was returned.',
  );
}

if (currency.isEmpty) {
  throw Exception(
    'Payment session was created but no payment currency was returned.',
  );
}

    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => PaymentScreen(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
      plan: selectedPlan,
      amount: (amount as num).toDouble(),
      currency: currency,
      email: email,
      rememberLogin: rememberLogin,
    ),
  ),
);
  } catch (e) {
    if (!mounted) return;

    _showMessage(
      e.toString().replaceFirst('Exception: ', ''),
    );
  } finally {
    if (mounted) {
      setState(() {
        creatingAccount = false;
      });
    }
  }
}

  /// Performs `_showMessage` for this feature. Update this documentation when its contract changes.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Performs `_inputDecoration` for this feature. Update this documentation when its contract changes.
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.045),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.4,
        ),
      ),
    );
  }


  /// Performs `_buildSecurityQuestionSection` for this feature. Update this documentation when its contract changes.
  Widget _buildSecurityQuestionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('ACCOUNT SECURITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Colors.white54)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedSecurityQuestion,
          decoration: _inputDecoration(label: 'Security question', icon: Icons.security_rounded),
          items: securityQuestions.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
          onChanged: (value) { if (value != null) setState(() => selectedSecurityQuestion = value); },
        ),
        if (selectedSecurityQuestion == 'Create my own question') ...[
          const SizedBox(height: 12),
          TextField(controller: customQuestionController, decoration: _inputDecoration(label: 'Your custom question', icon: Icons.edit_rounded)),
        ],
        const SizedBox(height: 12),
        TextField(controller: securityAnswerController, obscureText: true, decoration: _inputDecoration(label: 'Answer', icon: Icons.key_rounded)),
        const SizedBox(height: 8),
        const Text('If a sign-in looks suspicious, this question will be asked before access is granted.', style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.35)),
      ],
    );
  }

  /// Performs `_buildLogo` for this feature. Update this documentation when its contract changes.
  Widget _buildLogo() {
    return Center(
      child: Hero(
        tag: 'app-logo',
        child: Container(
          width: 82,
          height: 82,
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
          child: const Icon(
            Icons.play_circle_fill,
            size: 80,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  /// Performs `_buildPlanCard` for this feature. Update this documentation when its contract changes.
  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String title,
    required String price,
    required String subtitle,
  }) {
    final selected = selectedPlan == plan;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            selectedPlan = plan;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? Colors.red : Colors.white54,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: Stack(
        children: [
          Positioned(
            top: -140,
            left: -100,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.10),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 80,
                  sigmaY: 80,
                ),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.055),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 90,
                  sigmaY: 90,
                ),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 20,
                        sigmaY: 20,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogo(),

                            const SizedBox(height: 24),

                            Text(
                              'Create your account',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Start building your personal streaming library.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 30),

                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Email address',
                                icon: Icons.email_outlined,
                              ),
                            ),

                            const SizedBox(height: 14),

                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  onPressed: () {
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
                            ),

                            const SizedBox(height: 14),

                            TextField(
                              controller: confirmController,
                              obscureText: obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => createAccount(),
                              decoration: _inputDecoration(
                                label: 'Confirm password',
                                icon: Icons.lock_reset_outlined,
                                suffixIcon: IconButton(
                                  onPressed: () {
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
                            ),

                            const SizedBox(height: 26),

                            const Text(
                              'Choose your plan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                _buildPlanCard(
                                  plan: SubscriptionPlan.monthly,
                                  title: 'Monthly',
                                  price: '\$10.00',
                                  subtitle: 'Billed every month',
                                ),
                                const SizedBox(width: 12),
                                _buildPlanCard(
                                  plan: SubscriptionPlan.yearly,
                                  title: 'Yearly',
                                  price: '\$100.00',
                                  subtitle: 'Best annual value',
                                ),
                              ],
                            ),

                            _buildSecurityQuestionSection(),

                            const SizedBox(height: 18),

                            CheckboxListTile(
                              value: rememberLogin,
                              onChanged: (value) {
                                setState(() {
                                  rememberLogin = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              title: const Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed:
                                    creatingAccount ? null : createAccount,
                                icon: creatingAccount
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_forward_rounded,
                                      ),
                                label: Text(
                                  creatingAccount
                                      ? 'Creating account...'
                                      : 'Continue to payment',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: creatingAccount
                                    ? null
                                    : () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => LegalCenterScreen(
                                              onContinue: () => Navigator.of(context).pop(),
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.policy_outlined, size: 17),
                                label: const Text('Review legal & privacy'),
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.035),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LEGAL AGREEMENTS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Please review and accept all three requirements before continuing to payment.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.58),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: termsAccepted,
                                    onChanged: creatingAccount
                                        ? null
                                        : (value) => setState(() => termsAccepted = value ?? false),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: const Text('I agree to the Terms of Service.'),
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: privacyAccepted,
                                    onChanged: creatingAccount
                                        ? null
                                        : (value) => setState(() => privacyAccepted = value ?? false),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: const Text('I acknowledge the Privacy Policy.'),
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: acceptableUseAccepted,
                                    onChanged: creatingAccount
                                        ? null
                                        : (value) => setState(() => acceptableUseAccepted = value ?? false),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: const Text('I agree to the Copyright & Acceptable Use Policy.'),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: 0.58,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'By continuing, you confirm that you have reviewed and accepted '
                              'the Terms of Service, Privacy Policy, and Copyright & '
                              'Acceptable Use Policy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.38),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
