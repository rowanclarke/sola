const _regionDemonyms = <String, String>{
  'US': 'American',
  'GB': 'British',
  'AU': 'Australian',
  'BR': 'Brazilian',
  'PT': 'European',
  'ES': 'Castilian',
  'MX': 'Mexican',
  '419': 'Latin American',
  'CA': 'Canadian',
  'NZ': 'New Zealand',
  'ZA': 'South African',
  'IN': 'Indian',
  'PH': 'Philippine',
  'BE': 'Belgian',
  'CH': 'Swiss',
};

class LanguageTag {
  final String language;
  final String? script;
  final String? region;

  const LanguageTag({
    required this.language,
    this.script,
    this.region,
  });

  /// Parses a BCP47 tag like "en", "aai-Latn", "en-Latn-GB", or "en-GB".
  factory LanguageTag.parse(String tag) {
    final parts = tag.split('-');
    final language = parts[0];
    String? script;
    String? region;

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.length == 4 && part[0] == part[0].toUpperCase() && part.substring(1) == part.substring(1).toLowerCase()) {
        script = part;
      } else if ((part.length == 2 && part == part.toUpperCase()) || (part.length == 3 && RegExp(r'^\d{3}$').hasMatch(part))) {
        region = part;
      }
    }

    return LanguageTag(language: language, script: script, region: region);
  }

  /// Returns true if [other] matches this tag's non-null fields.
  /// A null field in [this] is treated as a wildcard (matches anything).
  /// e.g. LanguageTag("en", region: "GB").matches("en-Latn-GB") → true
  bool matches(LanguageTag other) {
    if (language != other.language) return false;
    if (script != null && script != other.script) return false;
    if (region != null && region != other.region) return false;
    return true;
  }

  /// Returns a display name like "English" or "English · British English".
  String displayName(String languageName) {
    if (region == null) return languageName;
    final demonym = _regionDemonyms[region!];
    if (demonym == null) return languageName;
    return '$languageName \u00b7 $demonym $languageName';
  }
}
