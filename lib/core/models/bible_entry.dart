/// Represents metadata for a single Bible translation.
/// This includes identifier, language, and potential download URL.
class BibleEntry {
  final String id;
  final String language;
  final String name;
  final String? downloadUrl; // Optional, for available translations

  const BibleEntry({
    required this.id,
    required this.language,
    required this.name,
    this.downloadUrl,
  });
}
