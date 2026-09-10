import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  final WidgetBuilder loginBuilder;

  const HowItWorksScreen({
    super.key,
    required this.loginBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.red, size: 72),
            const SizedBox(height: 14),
            const Text('MY STREAMING SERVICE', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text('Your authorized media. Your private library. Your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 16, height: 1.35)),
            const SizedBox(height: 28),
            _Step(icon: Icons.disc_full_rounded, title: '1. Add your media',
              text: 'Use compatible import hardware or supported library tools for media you own or are legally authorized to use.'),
            _Step(icon: Icons.auto_awesome_rounded, title: '2. Organize it',
              text: 'Build a private library with titles, artwork, metadata, collections, profiles, audio, subtitles and viewing history.'),
            _Step(icon: Icons.cloud_done_rounded, title: '3. Keep it private',
              text: 'Your account has its own logically isolated library and storage. Access is protected by authentication and account-level authorization.'),
            _Step(icon: Icons.devices_rounded, title: '4. Watch on your devices',
              text: 'Use the apps and web experience to access your personal library from supported phones, tablets, computers and TV platforms.'),
            _Step(icon: Icons.lock_outline_rounded, title: '5. You stay responsible for your media',
              text: 'The service provides technology and infrastructure. It does not grant copyright rights, and copying, conversion and remote access can be subject to local law.'),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.verified_user_outlined), SizedBox(width: 10),
                    Expanded(child: Text('Built around responsible use', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))]),
                  const SizedBox(height: 12),
                  Text('We do not provide a public catalog of commercial movies or shows. Customers are expected to use only media they own or are legally authorized to use. The app does not authorize DRM circumvention or unauthorized redistribution.',
                    style: TextStyle(color: Colors.grey.shade300, height: 1.45)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalCenterScreen())),
              icon: const Icon(Icons.policy_outlined),
              label: const Text('VIEW TERMS, PRIVACY & COPYRIGHT POLICIES'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: loginBuilder,
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Step({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.redAccent, size: 30),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: Colors.grey.shade400, height: 1.35)),
        ])),
      ]))),
    );
  }
}

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal & Privacy Center')),
      body: ListView(padding: const EdgeInsets.all(20), children: const [
        _PolicyCard(title: 'Terms of Service', icon: Icons.description_outlined, text: 'Use of the service requires lawful use of your account and media. Do not upload, import, redistribute or share media without the rights or authorization required by applicable law. We may suspend accounts for abuse or repeated infringement.'),
        _PolicyCard(title: 'Privacy', icon: Icons.lock_outline, text: 'Libraries are private by default and separated by account authorization. We process the information needed to operate, secure, bill and support the service. Account deletion is designed to trigger removal of associated media and storage according to the service retention policy.'),
        _PolicyCard(title: 'Copyright', icon: Icons.copyright_outlined, text: 'The service does not provide a commercial movie or television catalog and does not grant copyright permissions. Customers are responsible for determining whether copying, importing, converting, storing or remotely accessing particular media is lawful where they live.'),
        _PolicyCard(title: 'Import & DRM', icon: Icons.disc_full_outlined, text: 'Import tools are intended for authorized personal media. The service does not authorize circumvention of technological protection measures or unauthorized distribution.'),
        _PolicyCard(title: 'Copyright notices', icon: Icons.report_outlined, text: 'The production service will maintain a documented copyright notice and response process, including abuse handling and repeat-infringer procedures where legally applicable.'),
        _PolicyCard(title: 'Important', icon: Icons.warning_amber_rounded, text: 'These in-app policies are product safeguards and plain-language disclosures, not legal advice or a substitute for jurisdiction-specific legal review before launch.'),
      ]),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;
  const _PolicyCard({required this.title, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: Colors.redAccent), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))]),
    const SizedBox(height: 10),
    Text(text, style: TextStyle(color: Colors.grey.shade300, height: 1.45)),
  ])));
}
