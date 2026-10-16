import 'package:flutter/material.dart';

/// Opens the page-specific customization screen registered by the app shell.
typedef PageCustomizationOpener = void Function(
  BuildContext context,
  String pageId,
);

class PageCustomizationController {
  PageCustomizationController._();

  static PageCustomizationOpener? _opener;

  static void configure(PageCustomizationOpener opener) {
    _opener = opener;
  }

  static void open(BuildContext context, String pageId) {
    _opener?.call(context, pageId);
  }
}

/// Compact app-bar action with a tooltip explicitly tied to the current page.
/// Each page passes its own stable page ID, so settings never target whichever
/// unrelated screen happened to be active previously.
class PageCustomizeButton extends StatelessWidget {
  final String pageId;

  const PageCustomizeButton({
    super.key,
    required this.pageId,
  });

  static const Map<String, String> _titles = <String, String>{
    'home': 'Home',
    'details': 'Details',
    'friends': 'Friends',
    'actors': 'Actors',
    'library': 'Library',
    'collections': 'Collections',
    'hey-marathon': 'Hey Marathon',
    'movies': 'Movies',
    'series': 'TV Shows',
    'my-tv': 'TV Channels',
    'food-delivery': 'Food Delivery',
    'shop': 'Store',
    'store-creation': 'Store Creation',
    'store-settings': 'Store Settings',
    'seller-dashboard': 'Seller Dashboard',
  };

  @override
  Widget build(BuildContext context) {
    final title = _titles[pageId] ?? pageId;
    return IconButton(
      tooltip: 'Customize $title',
      onPressed: () => PageCustomizationController.open(context, pageId),
      icon: const Icon(Icons.tune_rounded),
    );
  }
}
