/// Represents a Bible translation with metadata.
/// Contains identifier, language, name, and optional download information.
class Translation {
  final String id;
  final String title;
  final String language;
  final String url;

  const Translation({
    required this.id,
    required this.title,
    required this.language,
    required this.url,
  });
}
