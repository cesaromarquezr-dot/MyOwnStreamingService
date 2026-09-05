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

  SubscriptionPlan selectedPlan =
      SubscriptionPlan.monthly;

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

    final username =
        usernameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    final confirmPassword =
        confirmController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage(
        'Please fill in every field.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      showMessage(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      creatingAccount = true;
    });

    try {
      /*
       * Signup now creates the account and payment session.
       *
       * It does NOT log the user in.
       *
       * The backend returns:
       *
       * - account
       * - inactive subscription
       * - payment session
       * - payment ID
       * - checkout token
       *
       * The payment information is passed to payment.dart.
       */
      final signupData =
          await AppController.instance
              .createAccountWithBackend(
        username: username,
        email: email,
        password: password,
        plan: selectedPlan,
        firstProfileName: username,
      );

      if (!mounted) return;

      final payment =
          signupData['payment'];

      if (payment is! Map) {
        throw Exception(
          'No payment session was returned by the server.',
        );
      }

      final paymentId =
          payment['id']?.toString();

      final checkoutToken =
          payment['checkoutToken']?.toString();

      final amountValue =
          payment['amount'];

      final currency =
          payment['currency']?.toString() ??
              'USD';

      if (paymentId == null ||
          paymentId.isEmpty) {
        throw Exception(
          'Payment session did not contain a payment ID.',
        );
      }

      if (checkoutToken == null ||
          checkoutToken.isEmpty) {
        throw Exception(
          'Payment session did not contain checkout authorization.',
        );
      }

      double amount;

      if (amountValue is num) {
        amount = amountValue.toDouble();
      } else {
        amount =
            double.tryParse(
                  amountValue?.toString() ?? '',
                ) ??
                0.0;
      }

      if (amount <= 0) {
        throw Exception(
          'Payment session returned an invalid amount.',
        );
      }

      /*
       * The account is intentionally NOT authenticated here.
       *
       * Payment must be completed first.
       */
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

      String message =
          'Unable to create account.';

      final errorText =
          error.toString();

      if (errorText.contains(
        'Username is already',
      )) {
        message =
            'That username is already in use.';
      } else if (errorText.contains(
        'Email is already',
      )) {
        message =
            'That email is already in use.';
      } else if (errorText.contains(
        'Password',
      )) {
        message = errorText
            .replaceFirst(
              'BackendApiException:',
              '',
            )
            .trim();
      } else if (errorText.isNotEmpty) {
        message = errorText
            .replaceFirst(
              'BackendApiException:',
              '',
            )
            .replaceFirst(
              'Exception:',
              '',
            )
            .trim();
      }

      if (message.isEmpty) {
        message =
            'Unable to create account.';
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

  void showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      appBar: AppBar(
        backgroundColor:
            Colors.black,
        title: const Text(
          'Create Account',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 550,
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                ),

                const SizedBox(
                  height: 30,
                ),

                TextField(
                  controller:
                      usernameController,
                  enabled:
                      !creatingAccount,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Username',
                    labelStyle:
                        TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),

                TextField(
                  controller:
                      emailController,
                  enabled:
                      !creatingAccount,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Email',
                    labelStyle:
                        TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),

                TextField(
                  controller:
                      passwordController,
                  enabled:
                      !creatingAccount,
                  obscureText:
                      obscurePassword,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',
                    labelStyle:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed:
                          creatingAccount
                              ? null
                              : () {
                                  setState(
                                    () {
                                      obscurePassword =
                                          !obscurePassword;
                                    },
                                  );
                                },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),

                TextField(
                  controller:
                      confirmController,
                  enabled:
                      !creatingAccount,
                  obscureText:
                      obscureConfirm,
                  style:
                      const TextStyle(
                    color: Colors.white,
                  ),
                  decoration:
                      InputDecoration(
                    labelText:
                        'Confirm Password',
                    labelStyle:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed:
                          creatingAccount
                              ? null
                              : () {
                                  setState(
                                    () {
                                      obscureConfirm =
                                          !obscureConfirm;
                                    },
                                  );
                                },
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Choose your subscription',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                RadioGroup<SubscriptionPlan>(
                  groupValue: selectedPlan,
                      onChanged: (value) {
  if (creatingAccount || value == null) {
    return;
  }

  setState(() {
    selectedPlan = value;
  });
},
                  child: Column(
                    children: [
                      RadioListTile<
                          SubscriptionPlan>(
                        value:
                            SubscriptionPlan
                                .monthly,
                        title: const Text(
                          '\$9.99 USD / month',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                          ),
                        ),
                        subtitle:
                            const Text(
                          'Billed every month',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ),

                      RadioListTile<
                          SubscriptionPlan>(
                        value:
                            SubscriptionPlan
                                .yearly,
                        title: const Text(
                          '\$99.99 USD / year',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                          ),
                        ),
                        subtitle:
                            const Text(
                          'Billed once per year',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Selected: $selectedPlanPrice',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                CheckboxListTile(
                  value:
                      rememberLogin,
                  onChanged:
                      creatingAccount
                          ? null
                          : (value) {
                              setState(
                                () {
                                  rememberLogin =
                                      value ??
                                          false;
                                },
                              );
                            },
                  title:
                      const Text(
                    'Remember my login',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                    ),
                  ),
                  controlAffinity:
                      ListTileControlAffinity
                          .leading,
                ),

                const SizedBox(
                  height: 20,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      ElevatedButton(
                    onPressed:
                        creatingAccount
                            ? null
                            : createAccount,
                    child:
                        creatingAccount
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Text(
                                'CONTINUE TO PAYMENT',
                                style:
                                    TextStyle(
                                  fontSize:
                                      18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextButton(
                  onPressed:
                      creatingAccount
                          ? null
                          : () =>
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) =>
                                    false,
                              ),
                  child:
                      const Text(
                    'Already have an account? Sign in',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Signup extends SignupScreen {
  const Signup({
    super.key,
  });
}