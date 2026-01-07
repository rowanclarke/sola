/// Represents a Bible translation with metadata.
/// Contains identifier, language, name, and optional download information.
class Translation {
  final String id;
  final String name;
  final String language;
  final String? downloadUrl;
  final bool isDownloaded;

  const Translation({
    required this.id,
    required this.name,
    required this.language,
    this.downloadUrl,
    this.isDownloaded = false,
  });

  /// Creates a copy of this translation with some fields replaced.
  Translation copyWith({
    String? id,
    String? name,
    String? language,
    String? downloadUrl,
    bool? isDownloaded,
  }) {
    throw UnimplementedError();
  }
}
