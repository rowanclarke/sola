class Translation {
  final String id;
  final String title;
  final String language;
  final String url;
  final String description;
  final int nt;
  final int ot;
  final bool downloadable;
  final String textDirection;
  final String bcp47;
  final String bcp47Tag;

  const Translation({
    required this.id,
    required this.title,
    required this.language,
    required this.url,
    this.description = '',
    this.nt = 0,
    this.ot = 0,
    this.downloadable = false,
    this.textDirection = 'ltr',
    this.bcp47 = '',
    this.bcp47Tag = '',
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      id: json['id'] as String,
      title: json['title'] as String,
      language: json['lang_en'] as String,
      url: json['url'] as String,
      description: json['description'] as String? ?? '',
      nt: json['nt'] as int? ?? 0,
      ot: json['ot'] as int? ?? 0,
      downloadable: json['downloadable'] as bool? ?? false,
      textDirection: json['text_direction'] as String? ?? 'ltr',
      bcp47: json['bcp47'] as String? ?? '',
      bcp47Tag: json['bcp47_tag'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lang_en': language,
      'url': url,
      'description': description,
      'nt': nt,
      'ot': ot,
      'downloadable': downloadable,
      'text_direction': textDirection,
      'bcp47': bcp47,
      'bcp47_tag': bcp47Tag,
    };
  }
}
