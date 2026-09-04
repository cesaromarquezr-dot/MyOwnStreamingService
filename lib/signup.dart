import 'package:flutter/material.dart';
import 'app_core.dart';

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

    if (username.isEmpty || email.isEmpty || password.isEmpty ||
        confirmController.text.isEmpty) {
      showMessage('Please fill in every field.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    if (password != confirmController.text) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() => creatingAccount = true);

    try {
      await AppController.instance.createAccountWithBackend(
  username: username,
  email: email,
  password: password,
  plan: selectedPlan,
  firstProfileName: username,
);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    } catch (error) {
      if (!mounted) return;
      String message = 'Unable to create account.';
      final errorText = error.toString();

      if (errorText.contains('Username is already')) {
        message = 'That username is already in use.';
      } else if (errorText.contains('Email is already')) {
        message = 'That email is already in use.';
      } else if (errorText.contains('Password')) {
        message = errorText;
      } else if (errorText.isNotEmpty) {
        message = errorText.replaceFirst('BackendApiException:', '').trim();
      }
      showMessage(message);
    } finally {
      if (mounted) setState(() => creatingAccount = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Create Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 80),
                const SizedBox(height: 30),
                TextField(
                  controller: usernameController,
                  enabled: !creatingAccount,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: emailController,
                  enabled: !creatingAccount,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: passwordController,
                  enabled: !creatingAccount,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    suffixIcon: IconButton(
                      onPressed: creatingAccount
                          ? null
                          : () => setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: confirmController,
                  enabled: !creatingAccount,
                  obscureText: obscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    suffixIcon: IconButton(
                      onPressed: creatingAccount
                          ? null
                          : () => setState(() => obscureConfirm = !obscureConfirm),
                      icon: Icon(
                        obscureConfirm ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose your subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                RadioListTile<SubscriptionPlan>(
                  value: SubscriptionPlan.monthly,
                  groupValue: selectedPlan,
                  onChanged: creatingAccount ? null : (value) {
                    if (value != null) setState(() => selectedPlan = value);
                  },
                  title: const Text(
                    '\$8 USD / month',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Billed every month',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                RadioListTile<SubscriptionPlan>(
                  value: SubscriptionPlan.yearly,
                  groupValue: selectedPlan,
                  onChanged: creatingAccount ? null : (value) {
                    if (value != null) setState(() => selectedPlan = value);
                  },
                  title: const Text(
                    '\$50 USD / year',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Save \$46 compared with monthly billing',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
                  value: rememberLogin,
                  onChanged: creatingAccount ? null : (value) =>
                      setState(() => rememberLogin = value ?? false),
                  title: const Text(
                    'Remember my login',
                    style: TextStyle(color: Colors.white),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: creatingAccount ? null : createAccount,
                    child: creatingAccount
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: creatingAccount
                      ? null
                      : () => Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (route) => false),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class signup extends SignupScreen {
  const signup({super.key});
}