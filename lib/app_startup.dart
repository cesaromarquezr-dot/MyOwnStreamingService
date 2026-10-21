// Centralized, ordered initialization for MyOwnStreamingService.
// Kept separate from runApp so startup order can be regression-tested.
import 'app_core.dart';
import 'app_customization.dart';
import 'innovation_features.dart';
import 'music.dart';
import 'navigation/page_appearance_store.dart';
import 'shop.dart';
import 'social_story_experience.dart';
import 'supabase/supabase_service.dart';

typedef AppStartupStep = Future<void> Function();

/// Ordered initialization steps. Tests can supply in-memory steps to verify
/// ordering and fail-fast behavior without connecting to real services.
class AppStartupTasks {
  const AppStartupTasks({
    required this.initializeSupabase,
    required this.initializeHomeCustomization,
    required this.initializePageAppearance,
    required this.initializePageContentCustomization,
    required this.initializeAppSectionCustomization,
    required this.initializeDetailsCustomization,
    required this.initializeMusicCustomization,
    required this.initializeBadges,
    required this.initializePlatformPreferences,
    required this.initializeShopCatalog,
    required this.initializeStoryPlacement,
  });

  final AppStartupStep initializeSupabase;
  final AppStartupStep initializeHomeCustomization;
  final AppStartupStep initializePageAppearance;
  final AppStartupStep initializePageContentCustomization;
  final AppStartupStep initializeAppSectionCustomization;
  final AppStartupStep initializeDetailsCustomization;
  final AppStartupStep initializeMusicCustomization;
  final AppStartupStep initializeBadges;
  final AppStartupStep initializePlatformPreferences;
  final AppStartupStep initializeShopCatalog;
  final AppStartupStep initializeStoryPlacement;

  Future<void> run() async {
    await initializeSupabase();
    await initializeHomeCustomization();
    await initializePageAppearance();
    await initializePageContentCustomization();
    await initializeAppSectionCustomization();
    await initializeDetailsCustomization();
    await initializeMusicCustomization();
    await initializeBadges();
    await initializePlatformPreferences();
    await initializeShopCatalog();
    await initializeStoryPlacement();
  }
}

/// Initializes app services in the same sequence used by the original main().
Future<void> initializeMyStreamingService({
  required AppStartupStep initializeHomeCustomization,
}) {
  return AppStartupTasks(
    initializeSupabase: () => SupabaseService.instance.initialize(),
    initializeHomeCustomization: initializeHomeCustomization,
    initializePageAppearance: PageAppearanceStore.initialize,
    initializePageContentCustomization: PageContentCustomizationStore.initialize,
    initializeAppSectionCustomization: AppSectionCustomizationStore.initialize,
    initializeDetailsCustomization: DetailsCustomizationStore.initialize,
    initializeMusicCustomization: MusicPageCustomizationStore.initialize,
    initializeBadges: () async => AppController.instance.initializeBadges(),
    initializePlatformPreferences: PlatformPreferenceStore.initialize,
    initializeShopCatalog: ShopCatalog.instance.initialize,
    initializeStoryPlacement: () async =>
        StoryPlacementStore.load(AppController.instance.currentProfile),
  ).run();
}
