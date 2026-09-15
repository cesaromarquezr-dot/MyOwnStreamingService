// FILE: lib/localization.dart
// Purpose: Universal, defensive application localization helpers.
// Every translated widget rebuilds when LanguageController changes. Missing
// translations ALWAYS fall back to the original English text, so localization
// can never introduce a null lookup/red-screen failure.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents one supported application language.
class AppLanguage {
  final String code;
  final String flag;

  /// Name shown in the language's own language/script.
  final String nativeName;

  final String englishName;

  const AppLanguage(
    this.code,
    this.flag,
    this.nativeName,
    this.englishName,
  );
}

/// Global profile-aware language state used by every screen.
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final instance = LanguageController._();

  AppLanguage current = languages.first;

  static const languages = <AppLanguage>[
    AppLanguage('en', '🇬🇧', 'English', 'English'),
    AppLanguage('es', '🇪🇸', 'Español', 'Spanish'),
    AppLanguage('fr', '🇫🇷', 'Français', 'French'),
    AppLanguage('de', '🇩🇪', 'Deutsch', 'German'),
    AppLanguage('pt', '🇵🇹', 'Português', 'Portuguese'),
    AppLanguage('it', '🇮🇹', 'Italiano', 'Italian'),
    AppLanguage('nl', '🇳🇱', 'Nederlands', 'Dutch'),
    AppLanguage('pl', '🇵🇱', 'Polski', 'Polish'),
    AppLanguage('tr', '🇹🇷', 'Türkçe', 'Turkish'),
    AppLanguage('ru', '🇷🇺', 'Русский', 'Russian'),
    AppLanguage('uk', '🇺🇦', 'Українська', 'Ukrainian'),
    AppLanguage('ar', '🇸🇦', 'العربية', 'Arabic'),
    AppLanguage('hi', '🇮🇳', 'हिन्दी', 'Hindi'),
    AppLanguage('zh', '🇨🇳', '中文', 'Chinese'),
    AppLanguage('ja', '🇯🇵', '日本語', 'Japanese'),
    AppLanguage('ko', '🇰🇷', '한국어', 'Korean'),
  ];

  /// Changes the active language and persists it for the current profile.
  Future<void> set(AppLanguage value) async {
    current = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final profileId = AppController.instance.currentProfile?.id;

    await prefs.setString(
      profileId == null
          ? 'app_language'
          : 'profile_language_$profileId',
      value.code,
    );
  }

  Future<void> loadForCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = AppController.instance.currentProfile?.id;

    final code = prefs.getString(
      profileId == null
          ? 'app_language'
          : 'profile_language_$profileId',
    );

    if (code == null) return;

    final match = languages.where((item) => item.code == code);

    if (match.isEmpty) return;

    current = match.first;
    notifyListeners();
  }
}

/// Reusable language picker intended to be placed in any app bar or menu.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) {
        final language = LanguageController.instance.current;

        return PopupMenuButton<AppLanguage>(
          tooltip: universalTranslate('Language'),
          onSelected: LanguageController.instance.set,
          itemBuilder: (_) {
            return [
              for (final item in LanguageController.languages)
                PopupMenuItem<AppLanguage>(
                  value: item,
                  child: Row(
                    children: [
                      Text(item.flag),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.nativeName),
                      ),
                    ],
                  ),
                ),
            ];
          },
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${language.flag} ${language.nativeName}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Translation lookup for user-facing strings.
class AppText {
  static String get(String key) {
    final language = LanguageController.instance.current.code;

    const data = <String, Map<String, String>>{
      'language': {
        'en': 'Language',
        'es': 'Idioma',
        'fr': 'Langue',
        'de': 'Sprache',
        'pt': 'Idioma',
        'it': 'Lingua',
        'ru': 'Язык',
        'ar': 'اللغة',
        'zh': '语言',
        'ja': '言語',
        'ko': '언어',
        'hi': 'भाषा',
      },
      'home': {
        'en': 'Home',
        'es': 'Inicio',
        'fr': 'Accueil',
        'de': 'Startseite',
        'pt': 'Início',
        'it': 'Home',
        'ru': 'Главная',
        'ar': 'الرئيسية',
        'zh': '首页',
        'ja': 'ホーム',
        'ko': '홈',
        'hi': 'होम',
      },
      'movies': {
        'en': 'Movies',
        'es': 'Películas',
        'fr': 'Films',
        'de': 'Filme',
        'pt': 'Filmes',
        'it': 'Film',
        'ru': 'Фильмы',
        'ar': 'الأفلام',
        'zh': '电影',
        'ja': '映画',
        'ko': '영화',
        'hi': 'फ़िल्में',
      },
      'tvShows': {
        'en': 'TV Shows',
        'es': 'Series',
        'fr': 'Séries',
        'de': 'Serien',
        'pt': 'Séries',
        'it': 'Serie TV',
        'ru': 'Сериалы',
        'ar': 'المسلسلات',
        'zh': '电视剧',
        'ja': 'テレビ番組',
        'ko': 'TV 프로그램',
        'hi': 'टीवी शो',
      },
      'music': {
        'en': 'Music',
        'es': 'Música',
        'fr': 'Musique',
        'de': 'Musik',
        'pt': 'Música',
        'it': 'Musica',
        'ru': 'Музыка',
        'ar': 'الموسيقى',
        'zh': '音乐',
        'ja': '音楽',
        'ko': '음악',
        'hi': 'संगीत',
      },
      'search': {
        'en': 'Search',
        'es': 'Buscar',
        'fr': 'Rechercher',
        'de': 'Suchen',
        'pt': 'Pesquisar',
        'it': 'Cerca',
        'ru': 'Поиск',
        'ar': 'بحث',
        'zh': '搜索',
        'ja': '検索',
        'ko': '검색',
        'hi': 'खोज',
      },
      'settings': {
        'en': 'Settings',
        'es': 'Configuración',
        'fr': 'Paramètres',
        'de': 'Einstellungen',
        'pt': 'Configurações',
        'it': 'Impostazioni',
        'ru': 'Настройки',
        'ar': 'الإعدادات',
        'zh': '设置',
        'ja': '設定',
        'ko': '설정',
        'hi': 'सेटिनги',
      },
      'recommendations': {
        'en': 'Recommendations',
        'es': 'Recomendaciones',
        'fr': 'Recommandations',
        'de': 'Empfehlungen',
        'pt': 'Recomendações',
        'it': 'Consigliati',
        'ru': 'Рекомендации',
        'ar': 'التوصيات',
        'zh': '推荐',
        'ja': 'おすすめ',
        'ko': '추천',
        'hi': 'अनुशंसाएँ',
      },
      'collections': {
        'en': 'Collections',
        'es': 'Colecciones',
        'fr': 'Collections',
        'de': 'Sammlungen',
        'pt': 'Coleções',
        'it': 'Raccolte',
        'ru': 'Коллекции',
        'ar': 'المجموعات',
        'zh': '收藏集',
        'ja': 'コレクション',
        'ko': '컬렉션',
        'hi': 'संग्रह',
      },
      'monthly': {
        'en': 'Monthly Wrapped',
        'es': 'Resumen mensual',
        'fr': 'Bilan mensuel',
        'de': 'Monatsrückblick',
        'pt': 'Resumo mensal',
        'it': 'Riepilogo mensile',
        'ru': 'Месячный обзор',
        'ar': 'الملخص الشهري',
        'zh': '月度回顾',
        'ja': '月間まとめ',
        'ko': '월간 요약',
        'hi': 'मासिक सारांश',
      },
      'yearly': {
        'en': 'Year-End Wrapped',
        'es': 'Resumen anual',
        'fr': 'Bilan annuel',
        'de': 'Jahresrückblick',
        'pt': 'Resumo anual',
        'it': 'Riepilogo annuale',
        'ru': 'Итоги года',
        'ar': 'ملخص العام',
        'zh': '年度回顾',
        'ja': '年間まとめ',
        'ko': '연말 요약',
        'hi': 'वार्षिक सारांश',
      },
      'achievements': {
        'en': 'Achievements',
        'es': 'Logros',
        'fr': 'Succès',
        'de': 'Erfolge',
        'pt': 'Conquistas',
        'it': 'Obiettivi',
        'ru': 'Достижения',
        'ar': 'الإنجازات',
        'zh': '成就',
        'ja': '実績',
        'ko': '업적',
        'hi': 'उपलब्धियाँ',
      },
      'connectedSports': {
        'en': 'Connected Sports',
        'es': 'Deportes conectados',
        'fr': 'Sports connectés',
        'de': 'Verbundene Sportdienste',
        'pt': 'Desporto conectado',
        'it': 'Sport collegati',
        'ru': 'Подключённый спорт',
        'ar': 'الرياضات المتصلة',
        'zh': '已连接体育',
        'ja': '接続スポーツ',
        'ko': '연결된 스포츠',
        'hi': 'कनेक्टेड स्पोर्ट्स',
      },
    };

    return data[key]?[language] ?? data[key]?['en'] ?? key;
  }

  /// Safely translates a user-facing English literal. Missing translations
  /// always fall back to English, so localization can never introduce a null
  /// value or a widget-building exception.
  static String literal(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return value;

    // Existing keyed translations are also available by their English value.
    const aliases = <String, String>{
      'Home': 'home',
      'Movies': 'movies',
      'TV Shows': 'tvShows',
      'Music': 'music',
      'Search': 'search',
      'Settings': 'settings',
      'Recommendations': 'recommendations',
      'Collections': 'collections',
      'Monthly Wrapped': 'monthly',
      'Year-End Wrapped': 'yearly',
      'Achievements': 'achievements',
      'Connected Sports': 'connectedSports',
      'Language': 'language',
    };
    final key = aliases[normalized];
    if (key != null) {
      final translated = get(key);
      if (translated != normalized) return translated;
    }
    final code = LanguageController.instance.current.code;
    return universalCommonTranslations[normalized]?[code] ?? value;
  }
}

/// A selectable text widget that automatically rebuilds when language changes.
class UniversalSelectableText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final String? semanticsLabel;

  const UniversalSelectableText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) => SelectableText(
        universalTranslate(value),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null
            ? null
            : universalTranslate(semanticsLabel!),
      ),
    );
  }
}

/// A Text widget that automatically rebuilds when language changes.
class LocalizedText extends StatelessWidget {
  final String keyName;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LocalizedText(
    this.keyName, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) {
        return Text(
          AppText.get(keyName),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}

/// Displays a literal user-facing string through the universal language layer.
/// The original English text is retained as the final fallback, guaranteeing
/// that a missing translation can never cause a null/red-screen failure.
class UniversalLocalizedText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  const UniversalLocalizedText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) => Text(
        AppText.literal(value),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}


/// Centralized localized Text widget. It intentionally mirrors the commonly
/// used Flutter Text parameters so existing UI styling can be retained.
class UniversalText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const UniversalText(
    this.value, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) => Text(
        universalTranslate(value),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null
            ? null
            : universalTranslate(semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ),
    );
  }
}

/// Convenience API for code that needs a translated string rather than a
/// widget. The existing AppText table remains the first source of truth.
String tr(String value) => universalTranslate(value);

/// Common translations used across the application. Less-common text safely
/// falls back to English until its key is added here or to AppText's keyed map.
/// This map is deliberately data-only: it cannot throw on a missing key.
const Map<String, Map<String, String>> universalCommonTranslations = {
  'Cancel': {'es':'Cancelar','fr':'Annuler','de':'Abbrechen','pt':'Cancelar','it':'Annulla','nl':'Annuleren','pl':'Anuluj','tr':'İptal','ru':'Отмена','uk':'Скасувати','ar':'إلغاء','hi':'रद्द करें','zh':'取消','ja':'キャンセル','ko':'취소'},
  'CANCEL': {'es':'CANCELAR','fr':'ANNULER','de':'ABBRECHEN','pt':'CANCELAR','it':'ANNULLA','nl':'ANNULEREN','pl':'ANULUJ','tr':'İPTAL','ru':'ОТМЕНА','uk':'СКАСУВАТИ','ar':'إلغاء','hi':'रद्द करें','zh':'取消','ja':'キャンセル','ko':'취소'},
  'Close': {'es':'Cerrar','fr':'Fermer','de':'Schließen','pt':'Fechar','it':'Chiudi','nl':'Sluiten','pl':'Zamknij','tr':'Kapat','ru':'Закрыть','uk':'Закрити','ar':'إغلاق','hi':'बंद करें','zh':'关闭','ja':'閉じる','ko':'닫기'},
  'CLOSE': {'es':'CERRAR','fr':'FERMER','de':'SCHLIESSEN','pt':'FECHAR','it':'CHIUDI','nl':'SLUITEN','pl':'ZAMKNIJ','tr':'KAPAT','ru':'ЗАКРЫТЬ','uk':'ЗАКРИТИ','ar':'إغلاق','hi':'बंद करें','zh':'关闭','ja':'閉じる','ko':'닫기'},
  'Save': {'es':'Guardar','fr':'Enregistrer','de':'Speichern','pt':'Guardar','it':'Salva','nl':'Opslaan','pl':'Zapisz','tr':'Kaydet','ru':'Сохранить','uk':'Зберегти','ar':'حفظ','hi':'सहेजें','zh':'保存','ja':'保存','ko':'저장'},
  'SAVE': {'es':'GUARDAR','fr':'ENREGISTRER','de':'SPEICHERN','pt':'GUARDAR','it':'SALVA','nl':'OPSLAAN','pl':'ZAPISZ','tr':'KAYDET','ru':'СОХРАНИТЬ','uk':'ЗБЕРЕГТИ','ar':'حفظ','hi':'सहेजें','zh':'保存','ja':'保存','ko':'저장'},
  'Create': {'es':'Crear','fr':'Créer','de':'Erstellen','pt':'Criar','it':'Crea','nl':'Maken','pl':'Utwórz','tr':'Oluştur','ru':'Создать','uk':'Створити','ar':'إنشاء','hi':'बनाएँ','zh':'创建','ja':'作成','ko':'만들기'},
  'CREATE': {'es':'CREAR','fr':'CRÉER','de':'ERSTELLEN','pt':'CRIAR','it':'CREA','nl':'MAKEN','pl':'UTWÓRZ','tr':'OLUŞTUR','ru':'СОЗДАТЬ','uk':'СТВОРИТИ','ar':'إنشاء','hi':'बनाएँ','zh':'创建','ja':'作成','ko':'만들기'},
  'Done': {'es':'Listo','fr':'Terminé','de':'Fertig','pt':'Concluído','it':'Fatto','nl':'Klaar','pl':'Gotowe','tr':'Bitti','ru':'Готово','uk':'Готово','ar':'تم','hi':'हो गया','zh':'完成','ja':'完了','ko':'완료'},
  'DONE': {'es':'LISTO','fr':'TERMINÉ','de':'FERTIG','pt':'CONCLUÍDO','it':'FATTO','nl':'KLAAR','pl':'GOTOWE','tr':'BİTTİ','ru':'ГОТОВО','uk':'ГОТОВО','ar':'تم','hi':'हो गया','zh':'完成','ja':'完了','ko':'완료'},
  'Home': {'es':'Inicio','fr':'Accueil','de':'Startseite','pt':'Início','it':'Home','nl':'Home','pl':'Strona główna','tr':'Ana Sayfa','ru':'Главная','uk':'Головна','ar':'الرئيسية','hi':'होम','zh':'首页','ja':'ホーム','ko':'홈'},
  'Movies': {'es':'Películas','fr':'Films','de':'Filme','pt':'Filmes','it':'Film','nl':'Films','pl':'Filmy','tr':'Filmler','ru':'Фильмы','uk':'Фільми','ar':'الأفلام','hi':'फ़िल्में','zh':'电影','ja':'映画','ko':'영화'},
  'TV Shows': {'es':'Series','fr':'Séries','de':'Serien','pt':'Séries','it':'Serie TV','nl':'Series','pl':'Seriale','tr':'Diziler','ru':'Сериалы','uk':'Серіали','ar':'المسلسلات','hi':'टीवी शो','zh':'电视剧','ja':'テレビ番組','ko':'TV 프로그램'},
  'Music': {'es':'Música','fr':'Musique','de':'Musik','pt':'Música','it':'Musica','nl':'Muziek','pl':'Muzyka','tr':'Müzik','ru':'Музыка','uk':'Музика','ar':'الموسيقى','hi':'संगीत','zh':'音乐','ja':'音楽','ko':'음악'},
  'Search': {'es':'Buscar','fr':'Rechercher','de':'Suchen','pt':'Pesquisar','it':'Cerca','nl':'Zoeken','pl':'Szukaj','tr':'Ara','ru':'Поиск','uk':'Пошук','ar':'بحث','hi':'खोजें','zh':'搜索','ja':'検索','ko':'검색'},
  'Settings': {'es':'Configuración','fr':'Paramètres','de':'Einstellungen','pt':'Configurações','it':'Impostazioni','nl':'Instellingen','pl':'Ustawienia','tr':'Ayarlar','ru':'Настройки','uk':'Налаштування','ar':'الإعدادات','hi':'सेटिंग्स','zh':'设置','ja':'設定','ko':'설정'},
  'Recommendations': {'es':'Recomendaciones','fr':'Recommandations','de':'Recommandations','pt':'Recomendações','it':'Consigliati','nl':'Aanbevelingen','pl':'Polecane','tr':'Öneriler','ru':'Рекомендации','uk':'Рекомендації','ar':'التوصيات','hi':'सिफारिशें','zh':'推荐','ja':'おすすめ','ko':'추천'},
  'Collections': {'es':'Colecciones','fr':'Collections','de':'Sammlungen','pt':'Coleções','it':'Raccolte','nl':'Collecties','pl':'Kolekcje','tr':'Koleksiyonlar','ru':'Коллекции','uk':'Колекції','ar':'المجموعات','hi':'संग्रह','zh':'收藏','ja':'コレクション','ko':'컬렉션'},
  'Actors': {'es':'Actores','fr':'Acteurs','de':'Schauspieler','pt':'Atores','it':'Attori','nl':'Acteurs','pl':'Aktorzy','tr':'Oyuncular','ru':'Актёры','uk':'Актори','ar':'الممثلون','hi':'अभिनेता','zh':'演员','ja':'俳優','ko':'배우'},
  'Movie': {'es':'Película','fr':'Film','de':'Film','pt':'Filme','it':'Film','nl':'Film','pl':'Film','tr':'Film','ru':'Фильм','uk':'Фільм','ar':'فيلم','hi':'फ़िल्म','zh':'电影','ja':'映画','ko':'영화'},
  'TV Show': {'es':'Serie','fr':'Série','de':'Série','pt':'Série','it':'Serie TV','nl':'Serie','pl':'Serial','tr':'Dizi','ru':'Сериал','uk':'Серіал','ar':'مسلسل','hi':'टीवी शो','zh':'电视剧','ja':'テレビ番組','ko':'TV 프로그램'},
  'Play': {'es':'Reproducir','fr':'Lire','de':'Abspielen','pt':'Reproduzir','it':'Riproduci','nl':'Afspelen','pl':'Odtwórz','tr':'Oynat','ru':'Воспроизвести','uk':'Відтворити','ar':'تشغيل','hi':'चलाएँ','zh':'播放','ja':'再生','ko':'재생'},
  'Pause': {'es':'Pausar','fr':'Pause','de':'Pausieren','pt':'Pausar','it':'Pausa','nl':'Pauzeren','pl':'Pauza','tr':'Duraklat','ru':'Пауза','uk':'Пауза','ar':'إيقاف مؤقت','hi':'रोकें','zh':'暂停','ja':'一時停止','ko':'일시정지'},
  'Information': {'es':'Información','fr':'Informations','de':'Informationen','pt':'Informações','it':'Informazioni','nl':'Informatie','pl':'Informacje','tr':'Bilgi','ru':'Информация','uk':'Інформація','ar':'معلومات','hi':'जानकारी','zh':'信息','ja':'情報','ko':'정보'},
  'Storage': {'es':'Almacenamiento','fr':'Stockage','de':'Speicher','pt':'Armazenamento','it':'Archiviazione','nl':'Opslag','pl':'Pamięć','tr':'Depolama','ru':'Хранилище','uk':'Сховище','ar':'التخزين','hi':'स्टोरेज','zh':'存储','ja':'ストレージ','ko':'저장 공간'},
  'Language': {'es':'Idioma','fr':'Langue','de':'Sprache','pt':'Idioma','it':'Lingua','nl':'Taal','pl':'Język','tr':'Dil','ru':'Язык','uk':'Мова','ar':'اللغة','hi':'भाषा','zh':'语言','ja':'言語','ko':'언어'},
  'Continue': {'es':'Continuar','fr':'Continuer','de':'Weiter','pt':'Continuar','it':'Continua','nl':'Doorgaan','pl':'Kontynuuj','tr':'Devam','ru':'Продолжить','uk':'Продовжити','ar':'متابعة','hi':'जारी रखें','zh':'继续','ja':'続行','ko':'계속'},
  'Back': {'es':'Atrás','fr':'Retour','de':'Zurück','pt':'Voltar','it':'Indietro','nl':'Terug','pl':'Wstecz','tr':'Geri','ru':'Назад','uk':'Назад','ar':'رجوع','hi':'वापस','zh':'返回','ja':'戻る','ko':'뒤로'},
  'Customize Home': {'es':'Personalizar inicio','fr':'Personnaliser l’accueil','de':'Startseite anpassen','pt':'Personalizar início','it':'Personalizza Home','nl':'Home aanpassen','pl':'Dostosuj stronę główną','tr':'Ana Sayfayı Özelleştir','ru':'Настроить главную','uk':'Налаштувати головну','ar':'تخصيص الرئيسية','hi':'होम अनुकूलित करें','zh':'自定义首页','ja':'ホームをカスタマイズ','ko':'홈 사용자 지정'},
  'Customize Details': {'es':'Personalizar detalles','fr':'Personnaliser les détails','de':'Details anpassen','pt':'Personalizar detalhes','it':'Personalizza dettagli','nl':'Details aanpassen','pl':'Dostosuj szczegóły','tr':'Ayrıntıları Özelleştir','ru':'Настроить детали','uk':'Налаштувати деталі','ar':'تخصيص التفاصيل','hi':'विवरण अनुकूलित करें','zh':'自定义详情','ja':'詳細をカスタマイズ','ko':'상세 정보 사용자 지정'},
  'Customize Music': {'es':'Personalizar música','fr':'Personnaliser la musique','de':'Musik anpassen','pt':'Personalizar música','it':'Personalizza musica','nl':'Muziek aanpassen','pl':'Dostosuj muzykę','tr':'Müziği Özelleştir','ru':'Настроить музыку','uk':'Налаштувати музику','ar':'تخصيص الموسيقى','hi':'संगीत अनुकूलित करें','zh':'自定义音乐','ja':'音楽をカスタマイズ','ko':'음악 사용자 지정'},
  'Customize App': {'es':'Personalizar aplicación','fr':'Personnaliser l’application','de':'App anpassen','pt':'Personalizar aplicativo','it':'Personalizza app','nl':'App aanpassen','pl':'Dostosuj aplikację','tr':'Uygulamayı Özelleştir','ru':'Настроить приложение','uk':'Налаштувати застосунок','ar':'تخصيص التطبيق','hi':'ऐप अनुकूलित करें','zh':'自定义应用','ja':'アプリをカスタマイズ','ko':'앱 사용자 지정'},
  'SAVE CHANGES': {'es':'GUARDAR CAMBIOS','fr':'ENREGISTRER LES MODIFICATIONS','de':'ÄNDERUNGEN SPEICHERN','pt':'SALVAR ALTERAÇÕES','it':'SALVA MODIFICHE','nl':'WIJZIGINGEN OPSLAAN','pl':'ZAPISZ ZMIANY','tr':'DEĞİŞİKLİKLERİ KAYDET','ru':'СОХРАНИТЬ ИЗМЕНЕНИЯ','uk':'ЗБЕРЕГТИ ЗМІНИ','ar':'حفظ التغييرات','hi':'परिवर्तन सहेजें','zh':'保存更改','ja':'変更を保存','ko':'변경 사항 저장'},
  'CONTINUE TO DETAILS': {'es':'CONTINUAR A DETALLES','fr':'CONTINUER VERS LES DÉTAILS','de':'WEITER ZU DETAILS','pt':'CONTINUAR PARA DETALHES','it':'CONTINUA AI DETTAGLI','nl':'DOORGAAN NAAR DETAILS','pl':'PRZEJDŹ DO SZCZEGÓŁÓW','tr':'AYRINTILARA DEVAM ET','ru':'ПРОДОЛЖИТЬ К ДЕТАЛЯМ','uk':'ПРОДОВЖИТИ ДО ДЕТАЛЕЙ','ar':'المتابعة إلى التفاصيل','hi':'विवरण पर जारी रखें','zh':'继续到详情','ja':'詳細へ進む','ko':'상세 정보로 계속'},
  'CONTINUE TO MUSIC': {'es':'CONTINUAR A MÚSICA','fr':'CONTINUER VERS LA MUSIQUE','de':'WEITER ZU MUSIK','pt':'CONTINUAR PARA MÚSICA','it':'CONTINUA ALLA MUSICA','nl':'DOORGAAN NAAR MUZIEK','pl':'PRZEJDŹ DO MUZYKI','tr':'MÜZİĞE DEVAM ET','ru':'ПРОДОЛЖИТЬ К МУЗЫКЕ','uk':'ПРОДОВЖИТИ ДО МУЗИКИ','ar':'المتابعة إلى الموسيقى','hi':'संगीत पर जारी रखें','zh':'继续到音乐','ja':'音楽へ進む','ko':'음악으로 계속'},
  'CONTINUE TO ACCOUNT INVITE': {'es':'CONTINUAR A INVITACIÓN DE CUENTA','fr':'CONTINUER VERS L’INVITATION DU COMPTE','de':'WEITER ZUR KONTOEINLADUNG','pt':'CONTINUAR PARA CONVITE DA CONTA','it':'CONTINUA ALL’INVITO DELL’ACCOUNT','nl':'DOORGAAN NAAR ACCOUNTUITNODIGING','pl':'PRZEJDŹ DO ZAPROSZENIA DO KONTA','tr':'HESAP DAVETİNE DEVAM ET','ru':'ПРОДОЛЖИТЬ К ПРИГЛАШЕНИЮ В АККАУНТ','uk':'ПРОДОВЖИТИ ДО ЗАПРОШЕННЯ В ОБЛІКОВИЙ ЗАПИС','ar':'المتابعة إلى دعوة الحساب','hi':'खाता आमंत्रण पर जारी रखें','zh':'继续到账户邀请','ja':'アカウント招待へ進む','ko':'계정 초대로 계속'},
  'Your authorized media. Your private library. Your devices.': {'es':'Tu contenido autorizado. Tu biblioteca privada. Tus dispositivos.', 'fr':'Vos médias autorisés. Votre bibliothèque privée. Vos appareils.', 'de':'Ihre autorisierten Medien. Ihre private Bibliothek. Ihre Geräte.', 'pt':'Sua mídia autorizada. Sua biblioteca privada. Seus dispositivos.', 'it':'I tuoi contenuti autorizzati. La tua biblioteca privata. I tuoi dispositivi.', 'nl':'Je geautoriseerde media. Je privébibliotheek. Je apparaten.', 'pl':'Twoje autoryzowane multimedia. Twoja prywatna biblioteka. Twoje urządzenia.', 'tr':'Yetkili medyanız. Özel kitaplığınız. Cihazlarınız.', 'ru':'Ваші авторизовані медіа. Ваша приватна бібліотека. Ваші пристрої.', 'uk':'Ваши авторизованные медиа. Ваша личная библиотека. Ваши устройства.', 'ar':'وسائطك المصرح بها. مكتبتك الخاصة. أجهزتك.', 'hi':'मीडिया जिसकी आपको अनुमति है। आपकी निजी लाइब्रेरी। आपके डिवाइस।', 'zh':'您的授权媒体。您的私人媒体库。您的设备。', 'ja':'あなたが利用を許可されたメディア。あなたのプライベートライブラリ。あなたのデバイス。', 'ko':'승인된 미디어. 비공개 라이브러리. 내 기기.'},
  '1. Add your media': {'es':'1. Añade tus medios', 'fr':'1. Ajoutez vos médias', 'de':'1. Medien hinzufügen', 'pt':'1. Adicione sua mídia', 'it':'1. Aggiungi i tuoi contenuti', 'nl':'1. Voeg je media toe', 'pl':'1. Dodaj swoje multimedia', 'tr':'1. Medyanızı ekleyin', 'ru':'1. Додайте медіа', 'uk':'1. Добавьте медиа', 'ar':'1. أضف وسائطك', 'hi':'1. 미디어 추가', 'zh':'1. 添加您的媒体', 'ja':'1. メディアを追加', 'ko':'1. 미디어 추가'},
  '2. Organize it': {'es':'2. Organízalos', 'fr':'2. Organisez-les', 'de':'2. Organisieren', 'pt':'2. Organize', 'it':'2. Organizza', 'nl':'2. Organiseer ze', 'pl':'2. Uporządkuj je', 'tr':'2. Düzenleyin', 'ru':'2. Упорядкуйте', 'uk':'2. Организуйте', 'ar':'2. نظّمها', 'hi':'2. व्यवस्थित करें', 'zh':'2. 整理媒体', 'ja':'2. 整理する', 'ko':'2. 정리하기'},
  '3. Keep it private': {'es':'3. Mantenlo privado', 'fr':'3. Gardez-les privés', 'de':'3. Privat halten', 'pt':'3. Mantenha privado', 'it':'3. Mantieni privato', 'nl':'3. Houd het privé', 'pl':'3. Zachowaj prywatność', 'tr':'3. Gizli tutun', 'ru':'3. Зберігайте приватність', 'uk':'3. Сохраняйте конфиденциальность', 'ar':'3. حافظ على الخصوصية', 'hi':'3. निजी रखें', 'zh':'3. 保持私密', 'ja':'3. 非公開にする', 'ko':'3. 비공개로 유지'},
  '4. Watch on your devices': {'es':'4. Mira en tus dispositivos', 'fr':'4. Regardez sur vos appareils', 'de':'4. Auf Ihren Geräten ansehen', 'pt':'4. Assista em seus dispositivos', 'it':'4. Guarda sui tuoi dispositivi', 'nl':'4. Kijk op je apparaten', 'pl':'4. Oglądaj na swoich urządzeniach', 'tr':'4. Cihazlarınızda izleyin', 'ru':'4. Переглядайте на своїх пристроях', 'uk':'4. Смотрите на своих устройствах', 'ar':'4. شاهد على أجهزتك', 'hi':'4. अपने डिवाइस पर देखें', 'zh':'4. 在您的设备上观看', 'ja':'4. デバイスで視聴する', 'ko':'4. 기기에서 시청'},
  '5. You stay responsible for your media': {'es':'5. Tú eres responsable de tus medios', 'fr':'5. Vous restez responsable de vos médias', 'de':'5. Sie bleiben für Ihre Medien verantwortlich', 'pt':'5. Você continua responsável por sua mídia', 'it':'5. Resti responsabile dei tuoi contenuti', 'nl':'5. Jij blijft verantwoordelijk voor je media', 'pl':'5. Nadal odpowiadasz za swoje multimedia', 'tr':'5. Medyanızdan siz sorumlusunuz', 'ru':'5. Ви відповідаєте за свої медіа', 'uk':'5. Вы несете ответственность за свои медиа', 'ar':'5. أنت مسؤول عن وسائطك', 'hi':'5. आप अपने मीडिया के लिए जिम्मेदार हैं', 'zh':'5. 您仍需对您的媒体负责', 'ja':'5. メディアについては利用者が責任を負います', 'ko':'5. 미디어에 대한 책임은 사용자에게 있습니다'},
  'Built around responsible use': {'es':'Basado en un uso responsable', 'fr':'Conçu pour un usage responsable', 'de':'Für verantwortungsvolle Nutzung entwickelt', 'pt':'Baseado no uso responsável', 'it':'Progettato per un uso responsabile', 'nl':'Gebouwd voor verantwoord gebruik', 'pl':'Zaprojektowane z myślą o odpowiedzialnym użytkowaniu', 'tr':'Sorumlu kullanıma dayalı', 'ru':'Створено для відповідального використання', 'uk':'Создано для ответственного использования', 'ar':'مصمم للاستخدام المسؤول', 'hi':'जिम्मेदार उपयोग पर आधारित', 'zh':'以负责任的使用为核心', 'ja':'責任ある利用を中心に設計', 'ko':'책임 있는 사용을 중심으로 설계'},
  'Use compatible import hardware or supported library tools for media you own or are legally authorized to use.': {'es':'Usa hardware de importación compatible o herramientas de biblioteca compatibles para contenido que poseas o cuyo uso esté legalmente autorizado.', 'fr':'Utilisez du matériel d’importation compatible ou des outils de bibliothèque pris en charge pour les médias que vous possédez ou êtes légalement autorisé à utiliser.', 'de':'Verwenden Sie kompatible Importhardware oder unterstützte Bibliothekswerkzeuge für Medien, die Ihnen gehören oder deren Nutzung Sie rechtlich gestattet ist.', 'pt':'Use hardware de importação compatível ou ferramentas de biblioteca compatíveis para mídias que você possui ou está legalmente autorizado a usar.', 'it':'Usa hardware di importazione compatibile o strumenti di libreria supportati per i contenuti che possiedi o che sei legalmente autorizzato a usare.', 'nl':'Gebruik compatibele importhardware of ondersteunde bibliotheektools voor media die je bezit of waarvoor je wettelijk toestemming hebt.', 'pl':'Używaj zgodnego sprzętu importującego lub obsługiwanych narzędzi bibliotecznych dla multimediów, które posiadasz lub których używanie jest prawnie dozwolone.', 'tr':'Sahip olduğunuz veya yasal olarak kullanma yetkiniz bulunan medya için uyumlu içe aktarma donanımı ya da desteklenen kitaplık araçlarını kullanın.', 'ru':'Використовуйте сумісне обладнання для імпорту або підтримувані інструменти бібліотеки для медіа, якими ви володієте або які маєте законний дозвіл використовувати.', 'uk':'Используйте совместимое оборудование для импорта или поддерживаемые инструменты библиотеки для медиа, которыми вы владеете или которые вам разрешено использовать по закону.', 'ar':'استخدم أجهزة الاستيراد المتوافقة أو أدوات المكتبة المدعومة للوسائط التي تملكها أو المصرح لك قانونًا باستخدامها.', 'hi':'अपने स्वामित्व वाले या कानूनी रूप से उपयोग की अनुमति वाले मीडिया के लिए संगत इंपोर्ट हार्डवेयर या समर्थित लाइब्रेरी टूल का उपयोग करें।', 'zh':'对于您拥有或依法获准使用的媒体，请使用兼容的导入硬件或受支持的媒体库工具。', 'ja':'所有または合法的な利用許可を持つメディアには、対応する取り込みハードウェアまたはサポート対象のライブラリツールを使用してください。', 'ko':'소유하거나 합법적으로 사용할 권한이 있는 미디어에는 호환되는 가져오기 하드웨어 또는 지원되는 라이브러리 도구를 사용하세요。'},
  'Build a private library with titles, artwork, metadata, collections, profiles, audio, subtitles and viewing history.': {'es':'Crea una biblioteca privada con títulos, carátulas, metadatos, colecciones, perfiles, audio, subtítulos e historial de visualización.', 'fr':'Créez une bibliothèque privée avec titres, illustrations, métadonnées, collections, profils, audio, sous-titres et historique de visionnage.', 'de':'Erstellen Sie eine private Bibliothek mit Titeln, Grafiken, Metadaten, Sammlungen, Profilen, Audio, Untertiteln und Wiedergabeverlauf.', 'pt':'Crie uma biblioteca privada com títulos, capas, metadados, coleções, perfis, áudio, legendas e histórico de exibição.', 'it':'Crea una libreria privata con titoli, copertine, metadati, raccolte, profili, audio, sottotitoli e cronologia di visione.', 'nl':'Bouw een privébibliotheek met titels, artwork, metadata, collecties, profielen, audio, ondertitels en kijkgeschiedenis.', 'pl':'Zbuduj prywatną bibliotekę z tytułami, grafikami, metadanymi, kolekcjami, profilami, dźwiękiem, napisami i historią oglądania.', 'tr':'Başlıklar, görseller, meta veriler, koleksiyonlar, profiller, ses, altyazılar ve izleme geçmişi içeren özel bir kitaplık oluşturun.', 'ru':'Створіть приватну бібліотеку з назвами, обкладинками, метаданими, колекціями, профілями, аудіо, субтитрами та історією перегляду.', 'uk':'Создайте личную библиотеку с названиями, обложками, метаданными, коллекциями, профилями, аудио, субтитрами и историей просмотра.', 'ar':'أنشئ مكتبة خاصة بالعناوين والأعمال الفنية والبيانات الوصفية والمجموعات والملفات الشخصية والصوت والترجمات وسجل المشاهدة.', 'hi':'शीर्षकों, आर्टवर्क, मेटाडेटा, संग्रह, प्रोफाइल, ऑडियो, सबटाइटल और देखने के इतिहास के साथ निजी लाइब्रेरी बनाएं।', 'zh':'创建包含标题、封面、元数据、收藏集、个人资料、音频、字幕和观看记录的私人媒体库。', 'ja':'タイトル、アートワーク、メタデータ、コレクション、プロフィール、音声、字幕、視聴履歴を備えたプライベートライブラリを作成します。', 'ko':'제목, 아트워크, 메타데이터, 컬렉션, 프로필, 오디오, 자막 및 시청 기록이 있는 비공개 라이브러리를 만드세요。'},
  'Your account has its own logically isolated library and storage. Access is protected by authentication and account-level authorization.': {'es':'Tu cuenta tiene su propia biblioteca y almacenamiento aislados lógicamente. El acceso está protegido por autenticación y autorización a nivel de cuenta.', 'fr':'Votre compte dispose de sa propre bibliothèque et de son propre stockage logiquement isolés. L’accès est protégé par authentification et autorisation au niveau du compte.', 'de':'Ihr Konto verfügt über eine logisch isolierte Bibliothek und einen eigenen Speicher. Der Zugriff wird durch Authentifizierung und kontobasierte Autorisierung geschützt.', 'pt':'Sua conta tem sua própria biblioteca e armazenamento logicamente isolados. O acesso é protegido por autenticação e autorização em nível de conta.', 'it':'Il tuo account dispone di una libreria e di uno spazio di archiviazione logicamente isolati. L’accesso è protetto da autenticazione e autorizzazione a livello di account.', 'nl':'Je account heeft een eigen logisch geïsoleerde bibliotheek en opslag. Toegang wordt beschermd door authenticatie en autorisatie op accountniveau.', 'pl':'Twoje konto ma własną logicznie odizolowaną bibliotekę i pamięć masową. Dostęp jest chroniony uwierzytelnianiem i autoryzacją na poziomie konta.', 'tr':'Hesabınızın kendine ait, mantıksal olarak yalıtılmış bir kitaplığı ve depolama alanı vardır. Erişim, kimlik doğrulama ve hesap düzeyinde yetkilendirme ile korunur.', 'ru':'Ваш обліковий запис має власну логічно ізольовану бібліотеку та сховище. Доступ захищено автентифікацією та авторизацією на рівні облікового запису.', 'uk':'У вашей учетной записи есть собственная логически изолированная библиотека и хранилище. Доступ защищен аутентификацией и авторизацией на уровне учетной записи.', 'ar':'يحتوي حسابك على مكتبة ومساحة تخزين معزولتين منطقيًا. الوصول محمي بالمصادقة والتفويض على مستوى الحساب.', 'hi':'आपके खाते की अपनी तार्किक रूप से अलग लाइब्रेरी और स्टोरेज है। एक्सेस प्रमाणीकरण और खाता-स्तरीय प्राधिकरण से सुरक्षित है।', 'zh':'您的账户拥有独立隔离的媒体库和存储空间。访问受身份验证和账户级授权保护。', 'ja':'アカウントには論理的に分離された専用ライブラリとストレージがあります。アクセスは認証とアカウント単位の認可で保護されます。', 'ko':'계정에는 논리적으로 격리된 전용 라이브러리와 저장 공간이 있습니다. 액세스는 인증과 계정 수준 권한 부여로 보호됩니다。'},
  'Use the apps and web experience to access your personal library from supported phones, tablets, computers and TV platforms.': {'es':'Usa las aplicaciones y la experiencia web para acceder a tu biblioteca personal desde teléfonos, tabletas, computadoras y plataformas de TV compatibles.', 'fr':'Utilisez les applications et le web pour accéder à votre bibliothèque personnelle depuis les téléphones, tablettes, ordinateurs et plateformes TV pris en charge.', 'de':'Nutzen Sie Apps und Weboberfläche, um von unterstützten Smartphones, Tablets, Computern und TV-Plattformen auf Ihre persönliche Bibliothek zuzugreifen.', 'pt':'Use os aplicativos e a experiência web para acessar sua biblioteca pessoal em telefones, tablets, computadores e plataformas de TV compatíveis.', 'it':'Usa le app e l’esperienza web per accedere alla tua libreria personale da telefoni, tablet, computer e piattaforme TV supportati.', 'nl':'Gebruik de apps en webervaring om je persoonlijke bibliotheek te openen vanaf ondersteunde telefoons, tablets, computers en tv-platforms.', 'pl':'Korzystaj z aplikacji i wersji internetowej, aby uzyskać dostęp do prywatnej biblioteki z obsługiwanych telefonów, tabletów, komputerów i platform TV.', 'tr':'Desteklenen telefon, tablet, bilgisayar ve TV platformlarından kişisel kitaplığınıza erişmek için uygulamaları ve web deneyimini kullanın.', 'ru':'Використовуйте застосунки та вебверсію для доступу до особистої бібліотеки з підтримуваних телефонів, планшетів, комп’ютерів і ТВ-платформ.', 'uk':'Используйте приложения и веб-версию для доступа к личной библиотеке с поддерживаемых телефонов, планшетов, компьютеров и ТВ-платформ.', 'ar':'استخدم التطبيقات وتجربة الويب للوصول إلى مكتبتك الشخصية من الهواتف والأجهزة اللوحية وأجهزة الكمبيوتر ومنصات التلفزيون المدعومة.', 'hi':'समर्थित फोन, टैबलेट, कंप्यूटर और टीवी प्लेटफ़ॉर्म से अपनी निजी लाइब्रेरी तक पहुँचने के लिए ऐप्स और वेब अनुभव का उपयोग करें।', 'zh':'通过应用和网页体验，从受支持的手机、平板电脑、电脑和电视平台访问您的个人媒体库。', 'ja':'対応するスマートフォン、タブレット、コンピューター、TVプラットフォームからアプリやWeb版で個人ライブラリにアクセスできます。', 'ko':'지원되는 휴대폰, 태블릿, 컴퓨터 및 TV 플랫폼에서 앱과 웹 환경을 통해 개인 라이브러리에 액세스하세요。'},
  'CONTINUE': {'es':'CONTINUAR', 'fr':'CONTINUER', 'de':'WEITER', 'pt':'CONTINUAR', 'it':'CONTINUA', 'nl':'DOORGAAN', 'pl':'KONTYNUUJ', 'tr':'DEVAM', 'ru':'ПРОДОВЖИТИ', 'uk':'ПРОДОЛЖИТЬ', 'ar':'متابعة', 'hi':'जारी रखें', 'zh':'继续', 'ja':'続行', 'ko':'계속'},

  'Create your account': {'es':'Crea tu cuenta','fr':'Créez votre compte','de':'Erstellen Sie Ihr Konto','pt':'Crie sua conta','it':'Crea il tuo account','nl':'Maak je account','pl':'Utwórz konto','tr':'Hesabınızı oluşturun','ru':'Создайте учетную запись','uk':'Створіть обліковий запис','ar':'أنشئ حسابك','hi':'अपना खाता बनाएँ','zh':'创建您的账户','ja':'アカウントを作成','ko':'계정을 만드세요'},
  'Start building your personal streaming library.': {'es':'Empieza a crear tu biblioteca personal de streaming.','fr':'Commencez à créer votre bibliothèque de streaming personnelle.','de':'Beginnen Sie mit dem Aufbau Ihrer persönlichen Streaming-Bibliothek.','pt':'Comece a criar sua biblioteca pessoal de streaming.','it':'Inizia a creare la tua libreria streaming personale.','nl':'Begin met het opbouwen van je persoonlijke streamingbibliotheek.','pl':'Zacznij tworzyć swoją prywatną bibliotekę streamingową.','tr':'Kişisel yayın kitaplığınızı oluşturmaya başlayın.','ru':'Начните создавать свою личную потоковую библиотеку.','uk':'Почніть створювати свою особисту потокову бібліотеку.','ar':'ابدأ بإنشاء مكتبة البث الشخصية الخاصة بك.','hi':'अपनी निजी स्ट्रीमिंग लाइब्रेरी बनाना शुरू करें।','zh':'开始创建您的个人流媒体库。','ja':'個人ストリーミングライブラリの作成を始めましょう。','ko':'개인 스트리밍 라이브러리 만들기를 시작하세요.'},
  'Email address': {'es':'Dirección de correo electrónico','fr':'Adresse e-mail','de':'E-Mail-Adresse','pt':'Endereço de e-mail','it':'Indirizzo email','nl':'E-mailadres','pl':'Adres e-mail','tr':'E-posta adresi','ru':'Адрес электронной почты','uk':'Адреса електронної пошти','ar':'عنوان البريد الإلكتروني','hi':'ईमेल पता','zh':'电子邮件地址','ja':'メールアドレス','ko':'이메일 주소'},
  'Password': {'es':'Contraseña','fr':'Mot de passe','de':'Passwort','pt':'Senha','it':'Password','nl':'Wachtwoord','pl':'Hasło','tr':'Şifre','ru':'Пароль','uk':'Пароль','ar':'كلمة المرور','hi':'पासवर्ड','zh':'密码','ja':'パスワード','ko':'비밀번호'},
  'Confirm password': {'es':'Confirmar contraseña','fr':'Confirmer le mot de passe','de':'Passwort bestätigen','pt':'Confirmar senha','it':'Conferma password','nl':'Wachtwoord bevestigen','pl':'Potwierdź hasło','tr':'Şifreyi onayla','ru':'Подтвердите пароль','uk':'Підтвердьте пароль','ar':'تأكيد كلمة المرور','hi':'पासवर्ड की पुष्टि करें','zh':'确认密码','ja':'パスワードを確認','ko':'비밀번호 확인'},
  'Choose your plan': {'es':'Elige tu plan','fr':'Choisissez votre forfait','de':'Wählen Sie Ihren Tarif','pt':'Escolha seu plano','it':'Scegli il tuo piano','nl':'Kies je abonnement','pl':'Wybierz plan','tr':'Planınızı seçin','ru':'Выберите тариф','uk':'Виберіть план','ar':'اختر خطتك','hi':'अपना प्लान चुनें','zh':'选择您的方案','ja':'プランを選択','ko':'요금제를 선택하세요'},
  'Monthly': {'es':'Mensual','fr':'Mensuel','de':'Monatlich','pt':'Mensal','it':'Mensile','nl':'Maandelijks','pl':'Miesięczny','tr':'Aylık','ru':'Ежемесячный','uk':'Щомісячний','ar':'شهري','hi':'मासिक','zh':'每月','ja':'月額','ko':'월간'},
  'Yearly': {'es':'Anual','fr':'Annuel','de':'Jährlich','pt':'Anual','it':'Annuale','nl':'Jaarlijks','pl':'Roczny','tr':'Yıllık','ru':'Ежегодный','uk':'Щорічний','ar':'سنوي','hi':'वार्षिक','zh':'每年','ja':'年額','ko':'연간'},
  'Billed every month': {'es':'Facturado cada mes','fr':'Facturé chaque mois','de':'Monatliche Abrechnung','pt':'Cobrado todos os meses','it':'Fatturato ogni mese','nl':'Elke maand gefactureerd','pl':'Rozliczane co miesiąc','tr':'Her ay faturalandırılır','ru':'Оплата ежемесячно','uk':'Оплата щомісяця','ar':'تتم الفوترة شهريًا','hi':'हर महीने बिल किया जाएगा','zh':'每月结算','ja':'毎月請求','ko':'매월 청구'},
  'Best annual value': {'es':'Mejor valor anual','fr':'Meilleur rapport annuel','de':'Bester Jahreswert','pt':'Melhor valor anual','it':'Miglior valore annuale','nl':'Beste jaarwaarde','pl':'Najlepsza wartość roczna','tr':'En iyi yıllık değer','ru':'Выгодный годовой тариф','uk':'Найкраща річна ціна','ar':'أفضل قيمة سنوية','hi':'सबसे अच्छा वार्षिक मूल्य','zh':'年度最优惠','ja':'年間でお得','ko':'연간 최고의 혜택'},
  'ACCOUNT SECURITY': {'es':'SEGURIDAD DE LA CUENTA','fr':'SÉCURITÉ DU COMPTE','de':'KONTOSICHERHEIT','pt':'SEGURANÇA DA CONTA','it':'SICUREZZA DELL’ACCOUNT','nl':'ACCOUNTBEVEILIGING','pl':'BEZPIECZEŃSTWO KONTA','tr':'HESAP GÜVENLİĞİ','ru':'БЕЗОПАСНОСТЬ УЧЕТНОЙ ЗАПИСИ','uk':'БЕЗПЕКА ОБЛІКОВОГО ЗАПИСУ','ar':'أمان الحساب','hi':'खाता सुरक्षा','zh':'账户安全','ja':'アカウントセキュリティ','ko':'계정 보안'},
  'Security question': {'es':'Pregunta de seguridad','fr':'Question de sécurité','de':'Sicherheitsfrage','pt':'Pergunta de segurança','it':'Domanda di sicurezza','nl':'Beveiligingsvraag','pl':'Pytanie zabezpieczające','tr':'Güvenlik sorusu','ru':'Контрольный вопрос','uk':'Контрольне запитання','ar':'سؤال الأمان','hi':'सुरक्षा प्रश्न','zh':'安全问题','ja':'セキュリティ質問','ko':'보안 질문'},
  'What was the name of your first pet?': {'es':'¿Cómo se llamaba tu primera mascota?','fr':'Comment s’appelait votre premier animal de compagnie ?','de':'Wie hieß Ihr erstes Haustier?','pt':'Qual era o nome do seu primeiro animal de estimação?','it':'Come si chiamava il tuo primo animale domestico?','nl':'Hoe heette je eerste huisdier?','pl':'Jak nazywało się Twoje pierwsze zwierzę?','tr':'İlk evcil hayvanınızın adı neydi?','ru':'Как звали вашего первого питомца?','uk':'Як звали вашого першого домашнього улюбленця?','ar':'ما اسم أول حيوان أليف لك؟','hi':'आपके पहले पालतू जानवर का नाम क्या था?','zh':'您的第一只宠物叫什么名字？','ja':'最初のペットの名前は何でしたか？','ko':'첫 번째 반려동물의 이름은 무엇이었나요?'},
  'What city were you born in?': {'es':'¿En qué ciudad naciste?','fr':'Dans quelle ville êtes-vous né(e) ?','de':'In welcher Stadt wurden Sie geboren?','pt':'Em que cidade você nasceu?','it':'In quale città sei nato?','nl':'In welke stad ben je geboren?','pl':'W jakim mieście się urodziłeś?','tr':'Hangi şehirde doğdunuz?','ru':'В каком городе вы родились?','uk':'У якому місті ви народилися?','ar':'في أي مدينة وُلدت؟','hi':'आपका जन्म किस शहर में हुआ था?','zh':'您出生在哪个城市？','ja':'どの都市で生まれましたか？','ko':'어느 도시에서 태어났나요?'},
  'What was the name of your first school?': {'es':'¿Cómo se llamaba tu primera escuela?','fr':'Comment s’appelait votre première école ?','de':'Wie hieß Ihre erste Schule?','pt':'Qual era o nome da sua primeira escola?','it':'Come si chiamava la tua prima scuola?','nl':'Hoe heette je eerste school?','pl':'Jak nazywała się Twoja pierwsza szkoła?','tr':'İlk okulunuzun adı neydi?','ru':'Как называлась ваша первая школа?','uk':'Як називалася ваша перша школа?','ar':'ما اسم مدرستك الأولى؟','hi':'आपके पहले स्कूल का नाम क्या था?','zh':'您的第一所学校叫什么名字？','ja':'最初の学校の名前は何でしたか？','ko':'첫 번째 학교의 이름은 무엇이었나요?'},
  'What is your favorite movie?': {'es':'¿Cuál es tu película favorita?','fr':'Quel est votre film préféré ?','de':'Was ist Ihr Lieblingsfilm?','pt':'Qual é seu filme favorito?','it':'Qual è il tuo film preferito?','nl':'Wat is je favoriete film?','pl':'Jaki jest Twój ulubiony film?','tr':'En sevdiğiniz film nedir?','ru':'Какой ваш любимый фильм?','uk':'Який ваш улюблений фільм?','ar':'ما هو فيلمك المفضل؟','hi':'आपकी पसंदीदा फ़िल्म कौन सी है?','zh':'您最喜欢的电影是什么？','ja':'お気に入りの映画は何ですか？','ko':'가장 좋아하는 영화는 무엇인가요?'},
  'Create my own question': {'es':'Crear mi propia pregunta','fr':'Créer ma propre question','de':'Meine eigene Frage erstellen','pt':'Criar minha própria pergunta','it':'Crea la mia domanda','nl':'Mijn eigen vraag maken','pl':'Utwórz własne pytanie','tr':'Kendi sorumu oluştur','ru':'Создать свой вопрос','uk':'Створити власне запитання','ar':'إنشاء سؤالي الخاص','hi':'अपना प्रश्न बनाएँ','zh':'创建我自己的问题','ja':'自分の質問を作成','ko':'내 질문 만들기'},
  'Your custom question': {'es':'Tu pregunta personalizada','fr':'Votre question personnalisée','de':'Ihre eigene Frage','pt':'Sua pergunta personalizada','it':'La tua domanda personalizzata','nl':'Je eigen vraag','pl':'Twoje własne pytanie','tr':'Özel sorunuz','ru':'Ваш собственный вопрос','uk':'Ваше власне запитання','ar':'سؤالك المخصص','hi':'आपका कस्टम प्रश्न','zh':'您的自定义问题','ja':'カスタム質問','ko':'사용자 지정 질문'},
  'Answer': {'es':'Respuesta','fr':'Réponse','de':'Antwort','pt':'Resposta','it':'Risposta','nl':'Antwoord','pl':'Odpowiedź','tr':'Cevap','ru':'Ответ','uk':'Відповідь','ar':'الإجابة','hi':'उत्तर','zh':'答案','ja':'回答','ko':'답변'},
  'If a sign-in looks suspicious, this question will be asked before access is granted.': {'es':'Si un inicio de sesión parece sospechoso, se hará esta pregunta antes de conceder acceso.','fr':'Si une connexion semble suspecte, cette question sera posée avant d’accorder l’accès.','de':'Wenn eine Anmeldung verdächtig erscheint, wird diese Frage vor der Zugriffsfreigabe gestellt.','pt':'Se um login parecer suspeito, esta pergunta será feita antes que o acesso seja concedido.','it':'Se un accesso sembra sospetto, questa domanda verrà posta prima di concedere l’accesso.','nl':'Als een aanmelding verdacht lijkt, wordt deze vraag gesteld voordat toegang wordt verleend.','pl':'Jeśli logowanie wygląda podejrzanie, to pytanie zostanie zadane przed przyznaniem dostępu.','tr':'Bir oturum açma şüpheli görünürse, erişim verilmeden önce bu soru sorulur.','ru':'Если вход выглядит подозрительно, этот вопрос будет задан до предоставления доступа.','uk':'Якщо вхід виглядає підозріло, це запитання буде поставлено перед наданням доступу.','ar':'إذا بدا تسجيل الدخول مريبًا، فسيتم طرح هذا السؤال قبل منح الوصول.','hi':'यदि साइन-इन संदिग्ध लगता है, तो एक्सेस देने से पहले यह प्रश्न पूछा जाएगा।','zh':'如果登录看起来可疑，在授予访问权限前会询问此问题。','ja':'サインインが不審に見える場合、アクセスを許可する前にこの質問が表示されます。','ko':'로그인이 의심스러워 보이면 액세스가 허용되기 전에 이 질문을 묻습니다.'},
  'Remember me': {'es':'Recordarme','fr':'Se souvenir de moi','de':'Angemeldet bleiben','pt':'Lembrar de mim','it':'Ricordami','nl':'Onthoud mij','pl':'Zapamiętaj mnie','tr':'Beni hatırla','ru':'Запомнить меня','uk':'Запам’ятати мене','ar':'تذكرني','hi':'मुझे याद रखें','zh':'记住我','ja':'ログイン情報を記憶','ko':'로그인 정보 기억'},
  'Creating account...': {'es':'Creando cuenta...','fr':'Création du compte...','de':'Konto wird erstellt...','pt':'Criando conta...','it':'Creazione account...','nl':'Account maken...','pl':'Tworzenie konta...','tr':'Hesap oluşturuluyor...','ru':'Создание учетной записи...','uk':'Створення облікового запису...','ar':'جارٍ إنشاء الحساب...','hi':'खाता बनाया जा रहा है...','zh':'正在创建账户...','ja':'アカウントを作成中...','ko':'계정 생성 중...'},
  'Continue to payment': {'es':'Continuar al pago','fr':'Continuer vers le paiement','de':'Weiter zur Zahlung','pt':'Continuar para pagamento','it':'Continua al pagamento','nl':'Doorgaan naar betaling','pl':'Przejdź do płatności','tr':'Ödemeye devam et','ru':'Перейти к оплате','uk':'Перейти до оплати','ar':'المتابعة إلى الدفع','hi':'भुगतान पर जाएँ','zh':'继续付款','ja':'支払いに進む','ko':'결제로 계속'},
  'Review legal & privacy': {'es':'Revisar aspectos legales y privacidad','fr':'Consulter les mentions légales et la confidentialité','de':'Rechtliches & Datenschutz prüfen','pt':'Revisar aspectos legais e privacidade','it':'Rivedi aspetti legali e privacy','nl':'Juridische zaken & privacy bekijken','pl':'Sprawdź kwestie prawne i prywatność','tr':'Hukuk ve gizliliği incele','ru':'Проверить юридические условия и конфиденциальность','uk':'Переглянути юридичні умови та конфіденційність','ar':'مراجعة الشروط القانونية والخصوصية','hi':'कानूनी और गोपनीयता की समीक्षा करें','zh':'查看法律与隐私','ja':'法的事項とプライバシーを確認','ko':'법률 및 개인정보 보호 검토'},
  'LEGAL AGREEMENTS': {'es':'ACUERDOS LEGALES','fr':'ACCORDS JURIDIQUES','de':'RECHTLICHE VEREINBARUNGEN','pt':'ACORDOS LEGAIS','it':'ACCORDI LEGALI','nl':'JURIDISCHE OVEREENKOMSTEN','pl':'UMOWY PRAWNE','tr':'YASAL SÖZLEŞMELER','ru':'ЮРИДИЧЕСКИЕ СОГЛАШЕНИЯ','uk':'ЮРИДИЧНІ УГОДИ','ar':'الاتفاقيات القانونية','hi':'कानूनी समझौते','zh':'法律协议','ja':'法的同意事項','ko':'법적 동의'},
  'Please review and accept all three requirements before continuing to payment.': {'es':'Revisa y acepta los tres requisitos antes de continuar al pago.','fr':'Veuillez examiner et accepter les trois exigences avant de poursuivre vers le paiement.','de':'Bitte prüfen und akzeptieren Sie alle drei Anforderungen, bevor Sie mit der Zahlung fortfahren.','pt':'Revise e aceite os três requisitos antes de continuar para o pagamento.','it':'Rivedi e accetta tutti e tre i requisiti prima di procedere al pagamento.','nl':'Bekijk en accepteer alle drie de vereisten voordat je doorgaat naar de betaling.','pl':'Przejrzyj i zaakceptuj wszystkie trzy wymagania przed przejściem do płatności.','tr':'Ödemeye devam etmeden önce üç gereksinimi de inceleyip kabul edin.','ru':'Проверьте и примите все три требования перед переходом к оплате.','uk':'Перегляньте та прийміть усі три вимоги перед переходом до оплати.','ar':'يرجى مراجعة المتطلبات الثلاثة وقبولها قبل المتابعة إلى الدفع.','hi':'भुगतान जारी रखने से पहले तीनों आवश्यकताओं की समीक्षा करें और स्वीकार करें।','zh':'继续付款前，请查看并接受全部三项要求。','ja':'支払いに進む前に、3つの要件をすべて確認して同意してください。','ko':'결제로 계속하기 전에 세 가지 요구 사항을 모두 검토하고 동의하세요.'},
  'I agree to the Terms of Service.': {'es':'Acepto los Términos del Servicio.','fr':'J’accepte les Conditions d’utilisation.','de':'Ich akzeptiere die Nutzungsbedingungen.','pt':'Concordo com os Termos de Serviço.','it':'Accetto i Termini di servizio.','nl':'Ik ga akkoord met de Servicevoorwaarden.','pl':'Akceptuję Warunki korzystania z usługi.','tr':'Hizmet Şartlarını kabul ediyorum.','ru':'Я принимаю Условия использования.','uk':'Я погоджуюся з Умовами використання.','ar':'أوافق على شروط الخدمة.','hi':'मैं सेवा की शर्तों से सहमत हूँ।','zh':'我同意服务条款。','ja':'利用規約に同意します。','ko':'서비스 약관에 동의합니다.'},
  'I acknowledge the Privacy Policy.': {'es':'Reconozco la Política de Privacidad.','fr':'Je reconnais la Politique de confidentialité.','de':'Ich bestätige die Datenschutzerklärung.','pt':'Reconheço a Política de Privacidade.','it':'Riconosco l’Informativa sulla privacy.','nl':'Ik erken het Privacybeleid.','pl':'Potwierdzam zapoznanie się z Polityką prywatności.','tr':'Gizlilik Politikasını kabul ediyorum.','ru':'Я подтверждаю ознакомление с Политикой конфиденциальности.','uk':'Я підтверджую ознайомлення з Політикою конфіденційності.','ar':'أقر بسياسة الخصوصية.','hi':'मैं गोपनीयता नीति को स्वीकार करता हूँ।','zh':'我确认已阅读隐私政策。','ja':'プライバシーポリシーを確認しました。','ko':'개인정보 처리방침을 확인했습니다.'},
  'I agree to the Copyright & Acceptable Use Policy.': {'es':'Acepto la Política de Derechos de Autor y Uso Aceptable.','fr':'J’accepte la Politique relative aux droits d’auteur et à l’utilisation acceptable.','de':'Ich akzeptiere die Urheberrechts- und Richtlinie zur zulässigen Nutzung.','pt':'Concordo com a Política de Direitos Autorais e Uso Aceitável.','it':'Accetto la Politica sul copyright e sull’uso accettabile.','nl':'Ik ga akkoord met het beleid inzake auteursrecht en aanvaardbaar gebruik.','pl':'Akceptuję Politykę praw autorskich i dopuszczalnego użytkowania.','tr':'Telif Hakkı ve Kabul Edilebilir Kullanım Politikasını kabul ediyorum.','ru':'Я принимаю Политику авторских прав и допустимого использования.','uk':'Я погоджуюся з Політикою авторських прав і прийнятного використання.','ar':'أوافق على سياسة حقوق الطبع والنشر والاستخدام المقبول.','hi':'मैं कॉपीराइट और स्वीकार्य उपयोग नीति से सहमत हूँ।','zh':'我同意版权与可接受使用政策。','ja':'著作権および適正利用ポリシーに同意します。','ko':'저작권 및 허용 가능한 사용 정책에 동의합니다.'},
  'Already have an account?': {'es':'¿Ya tienes una cuenta?','fr':'Vous avez déjà un compte ?','de':'Sie haben bereits ein Konto?','pt':'Já tem uma conta?','it':'Hai già un account?','nl':'Heb je al een account?','pl':'Masz już konto?','tr':'Zaten bir hesabınız var mı?','ru':'Уже есть учетная запись?','uk':'Вже маєте обліковий запис?','ar':'هل لديك حساب بالفعل؟','hi':'क्या आपके पास पहले से खाता है?','zh':'已有账户？','ja':'すでにアカウントをお持ちですか？','ko':'이미 계정이 있으신가요?'},
  'Sign in': {'es':'Iniciar sesión','fr':'Se connecter','de':'Anmelden','pt':'Entrar','it':'Accedi','nl':'Inloggen','pl':'Zaloguj się','tr':'Giriş yap','ru':'Войти','uk':'Увійти','ar':'تسجيل الدخول','hi':'साइन इन करें','zh':'登录','ja':'サインイン','ko':'로그인'},
  'By continuing, you confirm that you have reviewed and accepted the Terms of Service, Privacy Policy, and Copyright & Acceptable Use Policy.': {'es':'Al continuar, confirmas que has revisado y aceptado los Términos del Servicio, la Política de Privacidad y la Política de Derechos de Autor y Uso Aceptable.','fr':'En continuant, vous confirmez avoir consulté et accepté les Conditions d’utilisation, la Politique de confidentialité et la Politique relative aux droits d’auteur et à l’utilisation acceptable.','de':'Durch Fortfahren bestätigen Sie, dass Sie die Nutzungsbedingungen, Datenschutzerklärung sowie Urheberrechts- und Richtlinie zur zulässigen Nutzung geprüft und akzeptiert haben.','pt':'Ao continuar, você confirma que revisou e aceitou os Termos de Serviço, a Política de Privacidade e a Política de Direitos Autorais e Uso Aceitável.','it':'Continuando, confermi di aver esaminato e accettato i Termini di servizio, l’Informativa sulla privacy e la Politica sul copyright e sull’uso accettabile.','nl':'Door verder te gaan bevestig je dat je de Servicevoorwaarden, het Privacybeleid en het beleid inzake auteursrecht en aanvaardbaar gebruik hebt bekeken en geaccepteerd.','pl':'Kontynuując, potwierdzasz, że zapoznałeś(-aś) się i akceptujesz Warunki korzystania z usługi, Politykę prywatności oraz Politykę praw autorskich i dopuszczalnego użytkowania.','tr':'Devam ederek Hizmet Şartlarını, Gizlilik Politikasını ve Telif Hakkı ve Kabul Edilebilir Kullanım Politikasını incelediğinizi ve kabul ettiğinizi onaylarsınız.','ru':'Продолжая, вы подтверждаете, что ознакомились и приняли Условия использования, Политику конфиденциальности и Политику авторских прав и допустимого использования.','uk':'Продовжуючи, ви підтверджуєте, що переглянули та прийняли Умови використання, Політику конфіденційності та Політику авторських прав і прийнятного використання.','ar':'بالمتابعة، تؤكد أنك راجعت ووافقت على شروط الخدمة وسياسة الخصوصية وسياسة حقوق الطبع والنشر والاستخدام المقبول.','hi':'जारी रखकर, आप पुष्टि करते हैं कि आपने सेवा की शर्तों, गोपनीयता नीति और कॉपीराइट एवं स्वीकार्य उपयोग नीति की समीक्षा की है और उन्हें स्वीकार किया है।','zh':'继续操作即表示您确认已查看并接受服务条款、隐私政策以及版权与可接受使用政策。','ja':'続行することで、利用規約、プライバシーポリシー、著作権および適正利用ポリシーを確認し同意したことを確認します。','ko':'계속 진행하면 서비스 약관, 개인정보 처리방침 및 저작권 및 허용 가능한 사용 정책을 검토하고 동의했음을 확인하는 것입니다.'},
  'Please complete all fields.': {'es':'Completa todos los campos.','fr':'Veuillez remplir tous les champs.','de':'Bitte füllen Sie alle Felder aus.','pt':'Preencha todos os campos.','it':'Compila tutti i campi.','nl':'Vul alle velden in.','pl':'Wypełnij wszystkie pola.','tr':'Lütfen tüm alanları doldurun.','ru':'Заполните все поля.','uk':'Заповніть усі поля.','ar':'يرجى إكمال جميع الحقول.','hi':'कृपया सभी फ़ील्ड भरें।','zh':'请填写所有字段。','ja':'すべての項目を入力してください。','ko':'모든 필드를 입력하세요.'},
  'Password must be at least 6 characters.': {'es':'La contraseña debe tener al menos 6 caracteres.','fr':'Le mot de passe doit comporter au moins 6 caractères.','de':'Das Passwort muss mindestens 6 Zeichen lang sein.','pt':'A senha deve ter pelo menos 6 caracteres.','it':'La password deve contenere almeno 6 caratteri.','nl':'Het wachtwoord moet minimaal 6 tekens bevatten.','pl':'Hasło musi mieć co najmniej 6 znaków.','tr':'Şifre en az 6 karakter olmalıdır.','ru':'Пароль должен содержать не менее 6 символов.','uk':'Пароль має містити щонайменше 6 символів.','ar':'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.','hi':'पासवर्ड कम से कम 6 वर्णों का होना चाहिए।','zh':'密码至少需要 6 个字符。','ja':'パスワードは6文字以上にしてください。','ko':'비밀번호는 6자 이상이어야 합니다.'},
  'Passwords do not match.': {'es':'Las contraseñas no coinciden.','fr':'Les mots de passe ne correspondent pas.','de':'Die Passwörter stimmen nicht überein.','pt':'As senhas não coincidem.','it':'Le password non corrispondono.','nl':'De wachtwoorden komen niet overeen.','pl':'Hasła nie są zgodne.','tr':'Şifreler eşleşmiyor.','ru':'Пароли не совпадают.','uk':'Паролі не збігаються.','ar':'كلمتا المرور غير متطابقتين.','hi':'पासवर्ड मेल नहीं खाते।','zh':'密码不匹配。','ja':'パスワードが一致しません。','ko':'비밀번호가 일치하지 않습니다.'},
  'Please review and accept the Terms of Service, Privacy Policy, and Copyright & Acceptable Use Policy.': {'es':'Revisa y acepta los Términos del Servicio, la Política de Privacidad y la Política de Derechos de Autor y Uso Aceptable.','fr':'Veuillez consulter et accepter les Conditions d’utilisation, la Politique de confidentialité et la Politique relative aux droits d’auteur et à l’utilisation acceptable.','de':'Bitte prüfen und akzeptieren Sie die Nutzungsbedingungen, Datenschutzerklärung sowie die Urheberrechts- und Richtlinie zur zulässigen Nutzung.','pt':'Revise e aceite os Termos de Serviço, a Política de Privacidade e a Política de Direitos Autorais e Uso Aceitável.','it':'Rivedi e accetta i Termini di servizio, l’Informativa sulla privacy e la Politica sul copyright e sull’uso accettabile.','nl':'Bekijk en accepteer de Servicevoorwaarden, het Privacybeleid en het beleid inzake auteursrecht en aanvaardbaar gebruik.','pl':'Przejrzyj i zaakceptuj Warunki korzystania z usługi, Politykę prywatności oraz Politykę praw autorskich i dopuszczalnego użytkowania.','tr':'Hizmet Şartlarını, Gizlilik Politikasını ve Telif Hakkı ve Kabul Edilebilir Kullanım Politikasını inceleyip kabul edin.','ru':'Проверьте и примите Условия использования, Политику конфиденциальности и Политику авторских прав и допустимого использования.','uk':'Перегляньте та прийміть Умови використання, Політику конфіденційності та Політику авторських прав і прийнятного використання.','ar':'يرجى مراجعة شروط الخدمة وسياسة الخصوصية وسياسة حقوق الطبع والنشر والاستخدام المقبول والموافقة عليها.','hi':'सेवा की शर्तों, गोपनीयता नीति और कॉपीराइट एवं स्वीकार्य उपयोग नीति की समीक्षा करें और स्वीकार करें।','zh':'请查看并接受服务条款、隐私政策以及版权与可接受使用政策。','ja':'利用規約、プライバシーポリシー、著作権および適正利用ポリシーを確認して同意してください。','ko':'서비스 약관, 개인정보 처리방침 및 저작권 및 허용 가능한 사용 정책을 검토하고 동의하세요.'},
  'Payment information was not returned.': {'es':'No se devolvió la información de pago.','fr':'Les informations de paiement n’ont pas été retournées.','de':'Zahlungsinformationen wurden nicht zurückgegeben.','pt':'As informações de pagamento não foram retornadas.','it':'Le informazioni di pagamento non sono state restituite.','nl':'Betalingsinformatie is niet teruggestuurd.','pl':'Nie zwrócono informacji o płatności.','tr':'Ödeme bilgileri döndürülmedi.','ru':'Платежная информация не была возвращена.','uk':'Платіжну інформацію не повернуто.','ar':'لم يتم إرجاع معلومات الدفع.','hi':'भुगतान की जानकारी वापस नहीं मिली।','zh':'未返回付款信息。','ja':'支払い情報が返されませんでした。','ko':'결제 정보가 반환되지 않았습니다.'},
  'Payment session was created but no payment ID was returned.': {'es':'Se creó la sesión de pago, pero no se devolvió ningún ID de pago.','fr':'La session de paiement a été créée, mais aucun identifiant de paiement n’a été retourné.','de':'Die Zahlungssitzung wurde erstellt, aber es wurde keine Zahlungs-ID zurückgegeben.','pt':'A sessão de pagamento foi criada, mas nenhum ID de pagamento foi retornado.','it':'La sessione di pagamento è stata creata, ma non è stato restituito alcun ID di pagamento.','nl':'De betalingssessie is aangemaakt, maar er is geen betalings-ID teruggestuurd.','pl':'Sesja płatności została utworzona, ale nie zwrócono identyfikatora płatności.','tr':'Ödeme oturumu oluşturuldu ancak ödeme kimliği döndürülmedi.','ru':'Платежная сессия создана, но идентификатор платежа не возвращен.','uk':'Платіжну сесію створено, але ідентифікатор платежу не повернуто.','ar':'تم إنشاء جلسة الدفع ولكن لم يتم إرجاع معرّف الدفع.','hi':'भुगतान सत्र बनाया गया, लेकिन कोई भुगतान ID वापस नहीं मिला।','zh':'付款会话已创建，但未返回付款 ID。','ja':'支払いセッションは作成されましたが、支払いIDが返されませんでした。','ko':'결제 세션이 생성되었지만 결제 ID가 반환되지 않았습니다.'},
  'Payment session was created but no checkout authorization was returned.': {'es':'Se creó la sesión de pago, pero no se devolvió ninguna autorización de pago.','fr':'La session de paiement a été créée, mais aucune autorisation de paiement n’a été retournée.','de':'Die Zahlungssitzung wurde erstellt, aber es wurde keine Checkout-Autorisierung zurückgegeben.','pt':'A sessão de pagamento foi criada, mas nenhuma autorização de checkout foi retornada.','it':'La sessione di pagamento è stata creata, ma non è stata restituita alcuna autorizzazione al checkout.','nl':'De betalingssessie is aangemaakt, maar er is geen checkout-autorisatie teruggestuurd.','pl':'Sesja płatności została utworzona, ale nie zwrócono autoryzacji płatności.','tr':'Ödeme oturumu oluşturuldu ancak ödeme yetkilendirmesi döndürülmedi.','ru':'Платежная сессия создана, но авторизация оплаты не возвращена.','uk':'Платіжну сесію створено, але авторизацію оплати не повернуто.','ar':'تم إنشاء جلسة الدفع ولكن لم يتم إرجاع تفويض الدفع.','hi':'भुगतान सत्र बनाया गया, लेकिन चेकआउट प्राधिकरण वापस नहीं मिला।','zh':'付款会话已创建，但未返回结账授权。','ja':'支払いセッションは作成されましたが、決済認証が返されませんでした。','ko':'결제 세션이 생성되었지만 결제 승인이 반환되지 않았습니다.'},
  'Payment session was created but no payment amount was returned.': {'es':'Se creó la sesión de pago, pero no se devolvió el importe.','fr':'La session de paiement a été créée, mais aucun montant n’a été retourné.','de':'Die Zahlungssitzung wurde erstellt, aber kein Zahlungsbetrag wurde zurückgegeben.','pt':'A sessão de pagamento foi criada, mas nenhum valor de pagamento foi retornado.','it':'La sessione di pagamento è stata creata, ma non è stato restituito alcun importo.','nl':'De betalingssessie is aangemaakt, maar er is geen betalingsbedrag teruggestuurd.','pl':'Sesja płatności została utworzona, ale nie zwrócono kwoty płatności.','tr':'Ödeme oturumu oluşturuldu ancak ödeme tutarı döndürülmedi.','ru':'Платежная сессия создана, но сумма платежа не возвращена.','uk':'Платіжну сесію створено, але суму платежу не повернуто.','ar':'تم إنشاء جلسة الدفع ولكن لم يتم إرجاع مبلغ الدفع.','hi':'भुगतान सत्र बनाया गया, लेकिन भुगतान राशि वापस नहीं मिली।','zh':'付款会话已创建，但未返回付款金额。','ja':'支払いセッションは作成されましたが、支払額が返されませんでした。','ko':'결제 세션이 생성되었지만 결제 금액이 반환되지 않았습니다.'},
  'Payment session was created but no payment currency was returned.': {'es':'Se creó la sesión de pago, pero no se devolvió la moneda.','fr':'La session de paiement a été créée, mais aucune devise de paiement n’a été retournée.','de':'Die Zahlungssitzung wurde erstellt, aber keine Zahlungswährung wurde zurückgegeben.','pt':'A sessão de pagamento foi criada, mas nenhuma moeda de pagamento foi retornada.','it':'La sessione di pagamento è stata creata, ma non è stata restituita alcuna valuta.','nl':'De betalingssessie is aangemaakt, maar er is geen betalingsvaluta teruggestuurd.','pl':'Sesja płatności została utworzona, ale nie zwrócono waluty płatności.','tr':'Ödeme oturumu oluşturuldu ancak ödeme para birimi döndürülmedi.','ru':'Платежная сессия создана, но валюта платежа не возвращена.','uk':'Платіжну сесію створено, але валюту платежу не повернуто.','ar':'تم إنشاء جلسة الدفع ولكن لم يتم إرجاع عملة الدفع.','hi':'भुगतान सत्र बनाया गया, लेकिन भुगतान मुद्रा वापस नहीं मिली।','zh':'付款会话已创建，但未返回付款货币。','ja':'支払いセッションは作成されましたが、支払い通貨が返されませんでした。','ko':'결제 세션이 생성되었지만 결제 통화가 반환되지 않았습니다.'},
  'More': {'es':'Más','fr':'Plus','de':'Mehr','pt':'Mais','it':'Altro','nl':'Meer','pl':'Więcej','tr':'Daha Fazla','ru':'Ещё','uk':'Більше','ar':'المزيد','hi':'अधिक','zh':'更多','ja':'その他','ko':'더보기'},
  'Clear': {'es':'Borrar','fr':'Effacer','de':'Löschen','pt':'Limpar','it':'Cancella','nl':'Wissen','pl':'Wyczyść','tr':'Temizle','ru':'Очистить','uk':'Очистити','ar':'مسح','hi':'साफ़ करें','zh':'清除','ja':'クリア','ko':'지우기'},
  'Refresh': {'es':'Actualizar','fr':'Actualiser','de':'Aktualisieren','pt':'Atualizar','it':'Aggiorna','nl':'Vernieuwen','pl':'Odśwież','tr':'Yenile','ru':'Обновить','uk':'Оновити','ar':'تحديث','hi':'रिफ्रेश','zh':'刷新','ja':'更新','ko':'새로고침'},
  'Role': {'es':'Rol','fr':'Rôle','de':'Rolle','pt':'Função','it':'Ruolo','nl':'Rol','pl':'Rola','tr':'Rol','ru':'Роль','uk':'Роль','ar':'الدور','hi':'भूमिका','zh':'角色','ja':'役割','ko':'역할'},
  'Type': {'es':'Tipo','fr':'Type','de':'Typ','pt':'Tipo','it':'Tipo','nl':'Type','pl':'Typ','tr':'Tür','ru':'Тип','uk':'Тип','ar':'النوع','hi':'प्रकार','zh':'类型','ja':'種類','ko':'유형'},
  'Year': {'es':'Año','fr':'Année','de':'Jahr','pt':'Ano','it':'Anno','nl':'Jaar','pl':'Rok','tr':'Yıl','ru':'Год','uk':'Рік','ar':'السنة','hi':'वर्ष','zh':'年份','ja':'年','ko':'연도'},
  'About': {'es':'Acerca de','fr':'À propos','de':'Über','pt':'Sobre','it':'Informazioni','nl':'Over','pl':'Informacje','tr':'Hakkında','ru':'О приложении','uk':'Про застосунок','ar':'حول','hi':'के बारे में','zh':'关于','ja':'情報','ko':'정보'},
  'Audio': {'es':'Audio','fr':'Audio','de':'Audio','pt':'Áudio','it':'Audio','nl':'Audio','pl':'Audio','tr':'Ses','ru':'Аудио','uk':'Аудіо','ar':'الصوت','hi':'ऑडियो','zh':'音频','ja':'音声','ko':'오디오'},
  'Mute': {'es':'Silenciar','fr':'Muet','de':'Stumm','pt':'Silenciar','it':'Silenzia','nl':'Dempen','pl':'Wycisz','tr':'Sessize al','ru':'Без звука','uk':'Без звуку','ar':'كتم الصوت','hi':'म्यूट','zh':'静音','ja':'ミュート','ko':'음소거'},
  'Film': {'es':'Película','fr':'Film','de':'Film','pt':'Filme','it':'Film','nl':'Film','pl':'Film','tr':'Film','ru':'Фильм','uk':'Фільм','ar':'فيلم','hi':'फ़िल्म','zh':'电影','ja':'映画','ko':'영화'},
  'Shows': {'es':'Series','fr':'Séries','de':'Serien','pt':'Séries','it':'Serie','nl':'Series','pl':'Seriale','tr':'Diziler','ru':'Сериалы','uk':'Серіали','ar':'المسلسلات','hi':'शो','zh':'节目','ja':'番組','ko':'쇼'},
  'Title': {'es':'Título','fr':'Titre','de':'Titel','pt':'Título','it':'Titolo','nl':'Titel','pl':'Tytuł','tr':'Başlık','ru':'Название','uk':'Назва','ar':'العنوان','hi':'शीर्षक','zh':'标题','ja':'タイトル','ko':'제목'},
  'Albums': {'es':'Álbumes','fr':'Albums','de':'Alben','pt':'Álbuns','it':'Album','nl':'Albums','pl':'Albumy','tr':'Albümler','ru':'Альбомы','uk':'Альбоми','ar':'الألبومات','hi':'एल्बम','zh':'专辑','ja':'アルバム','ko':'앨범'},
  'Amount': {'es':'Cantidad','fr':'Montant','de':'Betrag','pt':'Valor','it':'Importo','nl':'Bedrag','pl':'Kwota','tr':'Miktar','ru':'Сумма','uk':'Сума','ar':'المبلغ','hi':'राशि','zh':'金额','ja':'金額','ko':'금액'},
  'Extras': {'es':'Extras','fr':'Bonus','de':'Extras','pt':'Extras','it':'Extra','nl':'Extra’s','pl':'Dodatki','tr':'Ekstralar','ru':'Дополнительно','uk':'Додатково','ar':'إضافات','hi':'अतिरिक्त','zh':'额外内容','ja':'特典','ko':'부가 콘텐츠'},
  'Genres': {'es':'Géneros','fr':'Genres','de':'Genres','pt':'Gêneros','it':'Generi','nl':'Genres','pl':'Gatunki','tr':'Türler','ru':'Жанры','uk':'Жанри','ar':'الأنواع','hi':'शैलियाँ','zh':'类型','ja':'ジャンル','ko':'장르'},
  'Region': {'es':'Región','fr':'Région','de':'Region','pt':'Região','it':'Regione','nl':'Regio','pl':'Region','tr':'Bölge','ru':'Регион','uk':'Регіон','ar':'المنطقة','hi':'क्षेत्र','zh':'地区','ja':'地域','ko':'지역'},
  'Remove': {'es':'Eliminar','fr':'Supprimer','de':'Entfernen','pt':'Remover','it':'Rimuovi','nl':'Verwijderen','pl':'Usuń','tr':'Kaldır','ru':'Удалить','uk':'Видалити','ar':'إزالة','hi':'हटाएँ','zh':'移除','ja':'削除','ko':'제거'},
  'Season': {'es':'Temporada','fr':'Saison','de':'Staffel','pt':'Temporada','it':'Stagione','nl':'Seizoen','pl':'Sezon','tr':'Sezon','ru':'Сезон','uk':'Сезон','ar':'الموسم','hi':'सीज़न','zh':'季','ja':'シーズン','ko':'시즌'},
  'Writer': {'es':'Guionista','fr':'Scénariste','de':'Drehbuchautor','pt':'Roteirista','it':'Sceneggiatore','nl':'Scenarioschrijver','pl':'Scenarzysta','tr':'Senarist','ru':'Сценарист','uk':'Сценарист','ar':'كاتب السيناريو','hi':'लेखक','zh':'编剧','ja':'脚本家','ko':'각본가'},
  'Privacy': {'es':'Privacidad','fr':'Confidentialité','de':'Datenschutz','pt':'Privacidade','it':'Privacy','nl':'Privacy','pl':'Prywatność','tr':'Gizlilik','ru':'Конфиденциальность','uk':'Конфіденційність','ar':'الخصوصية','hi':'गोपनीयता','zh':'隐私','ja':'プライバシー','ko':'개인정보 보호'},
  'Director': {'es':'Director','fr':'Réalisateur','de':'Regisseur','pt':'Diretor','it':'Regista','nl':'Regisseur','pl':'Reżyser','tr':'Yönetmen','ru':'Режиссёр','uk':'Режисер','ar':'المخرج','hi':'निर्देशक','zh':'导演','ja':'監督','ko':'감독'},
  'Biography': {'es':'Biografía','fr':'Biographie','de':'Biografie','pt':'Biografia','it':'Biografia','nl':'Biografie','pl':'Biografia','tr':'Biyografi','ru':'Биография','uk':'Біографія','ar':'السيرة الذاتية','hi':'जीवनी','zh':'传记','ja':'プロフィール','ko':'약력'},
  'Subtitles': {'es':'Subtítulos','fr':'Sous-titres','de':'Untertitel','pt':'Legendas','it':'Sottotitoli','nl':'Ondertitels','pl':'Napisy','tr':'Altyazılar','ru':'Субтитры','uk':'Субтитри','ar':'الترجمات','hi':'उपशीर्षक','zh':'字幕','ja':'字幕','ko':'자막'},
  'Description': {'es':'Descripción','fr':'Description','de':'Beschreibung','pt':'Descrição','it':'Descrizione','nl':'Beschrijving','pl':'Opis','tr':'Açıklama','ru':'Описание','uk':'Опис','ar':'الوصف','hi':'विवरण','zh':'描述','ja':'説明','ko':'설명'},
  'Group Chat': {'es':'Chat grupal','fr':'Discussion de groupe','de':'Gruppenchat','pt':'Chat em grupo','it':'Chat di gruppo','nl':'Groepschat','pl':'Czat grupowy','tr':'Grup Sohbeti','ru':'Групповой чат','uk':'Груповий чат','ar':'دردشة جماعية','hi':'ग्रुप चैट','zh':'群聊','ja':'グループチャット','ko':'그룹 채팅'},
  'Group Watch': {'es':'Ver en grupo','fr':'Visionnage en groupe','de':'Gruppen-Watch','pt':'Assistir em grupo','it':'Visione di gruppo','nl':'Samen kijken','pl':'Wspólne oglądanie','tr':'Grup İzleme','ru':'Групповой просмотр','uk':'Груповий перегляд','ar':'المشاهدة الجماعية','hi':'ग्रुप वॉच','zh':'一起观看','ja':'グループ視聴','ko':'그룹 시청'},
  'Participants': {'es':'Participantes','fr':'Participants','de':'Teilnehmer','pt':'Participantes','it':'Partecipanti','nl':'Deelnemers','pl':'Uczestnicy','tr':'Katılımcılar','ru':'Участники','uk':'Учасники','ar':'المشاركون','hi':'प्रतिभागी','zh':'参与者','ja':'参加者','ko':'참가자'},
  'Profile name': {'es':'Nombre del perfil','fr':'Nom du profil','de':'Profilname','pt':'Nome do perfil','it':'Nome profilo','nl':'Profielnaam','pl':'Nazwa profilu','tr':'Profil adı','ru':'Имя профиля','uk':'Ім’я профілю','ar':'اسم الملف الشخصي','hi':'प्रोफ़ाइल नाम','zh':'个人资料名称','ja':'プロフィール名','ko':'프로필 이름'},
  'Notifications': {'es':'Notificaciones','fr':'Notifications','de':'Benachrichtigungen','pt':'Notificações','it':'Notifiche','nl':'Meldingen','pl':'Powiadomienia','tr':'Bildirimler','ru':'Уведомления','uk':'Сповіщення','ar':'الإشعارات','hi':'सूचनाएँ','zh':'通知','ja':'通知','ko':'알림'},
  'Add to library': {'es':'Añadir a la biblioteca','fr':'Ajouter à la bibliothèque','de':'Zur Bibliothek hinzufügen','pt':'Adicionar à biblioteca','it':'Aggiungi alla libreria','nl':'Aan bibliotheek toevoegen','pl':'Dodaj do biblioteki','tr':'Kitaplığa ekle','ru':'Добавить в библиотеку','uk':'Додати до бібліотеки','ar':'إضافة إلى المكتبة','hi':'लाइब्रेरी में जोड़ें','zh':'添加到媒体库','ja':'ライブラリに追加','ko':'라이브러리에 추가'},
  'Account Settings': {'es':'Configuración de la cuenta','fr':'Paramètres du compte','de':'Kontoeinstellungen','pt':'Configurações da conta','it':'Impostazioni account','nl':'Accountinstellingen','pl':'Ustawienia konta','tr':'Hesap Ayarları','ru':'Настройки аккаунта','uk':'Налаштування облікового запису','ar':'إعدادات الحساب','hi':'खाता सेटिंग्स','zh':'账户设置','ja':'アカウント設定','ko':'계정 설정'},
};

/// Defensive universal lookup. Existing keyed translations win, then common
/// phrase translations, and finally the original value.
String universalTranslate(String value) {
  final current = LanguageController.instance.current.code;
  if (current == 'en') return value;

  final keyed = AppText.literal(value);
  if (keyed != value) return keyed;

  final direct = universalCommonTranslations[value]?[current];
  if (direct != null) return direct;

  // Handle common uppercase labels without throwing or altering dynamic data.
  final upper = value.toUpperCase();
  final upperDirect = universalCommonTranslations[upper]?[current];
  if (upperDirect != null) return upperDirect;

  return value;
}
