import 'package:sola/core/models/language_tag.dart';

class Translation {
  final String id;
  final String title;
  final String lang;
  final String langEn;
  final String description;
  final String domain;
  final String copyright;
  final String contents;
  final String bcp47;
  final int size;
  final LanguageTag languageTag;

  const Translation({
    required this.id,
    required this.title,
    required this.lang,
    required this.langEn,
    this.description = '',
    this.domain = '',
    this.copyright = '',
    this.contents = '',
    this.bcp47 = '',
    this.size = 0,
    required this.languageTag,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    final bcp47 = json['bcp47'] as String? ?? '';
    return Translation(
      id: json['id'] as String,
      title: json['title'] as String,
      lang: json['lang'] as String? ?? '',
      langEn: json['lang_en'] as String? ?? '',
      description: json['description'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      copyright: json['copyright'] as String? ?? '',
      contents: json['contents'] as String? ?? '',
      bcp47: bcp47,
      size: json['size'] as int? ?? 0,
      languageTag: LanguageTag.parse(bcp47),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lang': lang,
      'lang_en': langEn,
      'description': description,
      'domain': domain,
      'copyright': copyright,
      'contents': contents,
      'bcp47': bcp47,
      'size': size,
    };
  }

  static String downloadUrl(String id) =>
      'https://translations.sola-9ee.workers.dev/download?id=$id';
}
