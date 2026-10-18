import 'package:flutter/material.dart';
import 'food_delivery.dart';
import 'shop.dart';

/// A lightweight bridge between watching something and the existing commerce
/// destinations. It does not imply that food delivery or merchant checkout is
/// available in every region; those flows remain owned by their respective screens.
class WatchAndEnjoyScreen extends StatelessWidget {
  const WatchAndEnjoyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch & Enjoy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF241A3C), Color(0xFF142B3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.movie_filter_rounded, size: 34, color: Colors.white),
                    SizedBox(height: 14),
                    Text('Make it a movie night', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('Find something to eat, discover entertainment-related products, and get back to your stream without losing the plot.', style: TextStyle(color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: wide ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: wide ? 1.65 : 2.3,
                children: [
                  _ActionCard(
                    icon: Icons.delivery_dining_rounded,
                    title: 'Food delivery & pickup',
                    subtitle: 'Browse restaurants and menus, then continue into the existing ordering flow.',
                    actionLabel: 'Explore food',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FoodOrderingScreen())),
                  ),
                  _ActionCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Shop & merchandise',
                    subtitle: 'Discover products and entertainment merchandise using your existing Shop, wishlist and shopping bag.',
                    actionLabel: 'Open shop',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShopScreen(onHome: () => Navigator.of(context).maybePop()))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Commerce is optional. Availability, delivery areas, prices, taxes, checkout and fulfillment depend on the connected restaurant or seller services. Shopping and food ordering stay separate from playback controls.', style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 28),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Expanded(child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall)),
          Row(children: [Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 6), const Icon(Icons.arrow_forward_rounded, size: 17)]),
        ]),
      ),
    ),
  );
}
