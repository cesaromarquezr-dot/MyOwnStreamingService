/// Shared visual design tokens for customizable pages. Domain-specific
/// storefronts and future profile/community pages can add their own content
/// layout while reusing this theme, palette, background, and control model.
class PagePresentation {
  String presetTheme;
  String brightnessMode;
  int primaryColor;
  int secondaryColor;
  int backgroundColor;
  int gradientEndColor;
  String backgroundType;
  String backgroundImageUrl;
  String fontFamily;
  double fontScale;
  double buttonRadius;
  double cardRadius;

  PagePresentation({
    this.presetTheme = 'Indigo',
    this.brightnessMode = 'system',
    this.primaryColor = 0xFF536DFE,
    this.secondaryColor = 0xFFFFB74D,
    this.backgroundColor = 0xFFF6F7FB,
    this.gradientEndColor = 0xFFE8EAF6,
    this.backgroundType = 'solid',
    this.backgroundImageUrl = '',
    this.fontFamily = 'Default',
    this.fontScale = 1,
    this.buttonRadius = 14,
    this.cardRadius = 18,
  });

  factory PagePresentation.fromJson(Map<String, dynamic> json) => PagePresentation(
    presetTheme: json['presetTheme']?.toString() ?? 'Indigo',
    brightnessMode: json['brightnessMode']?.toString() ?? 'system',
    primaryColor: _intValue(json['primaryColor'], 0xFF536DFE),
    secondaryColor: _intValue(json['secondaryColor'], 0xFFFFB74D),
    backgroundColor: _intValue(json['backgroundColor'], 0xFFF6F7FB),
    gradientEndColor: _intValue(json['gradientEndColor'], 0xFFE8EAF6),
    backgroundType: json['backgroundType']?.toString() ?? 'solid',
    backgroundImageUrl: json['backgroundImageUrl']?.toString() ?? '',
    fontFamily: json['fontFamily']?.toString() ?? 'Default',
    fontScale: _doubleValue(json['fontScale'], 1).clamp(0.8, 1.4).toDouble(),
    buttonRadius: _doubleValue(json['buttonRadius'], 14).clamp(0, 32).toDouble(),
    cardRadius: _doubleValue(json['cardRadius'], 18).clamp(0, 36).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'presetTheme': presetTheme,
    'brightnessMode': brightnessMode,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'backgroundColor': backgroundColor,
    'gradientEndColor': gradientEndColor,
    'backgroundType': backgroundType,
    'backgroundImageUrl': backgroundImageUrl,
    'fontFamily': fontFamily,
    'fontScale': fontScale,
    'buttonRadius': buttonRadius,
    'cardRadius': cardRadius,
  };
}

int _intValue(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;
double _doubleValue(dynamic value, double fallback) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;
