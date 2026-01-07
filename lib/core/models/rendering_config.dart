/// Represents rendering configuration options for formatting a Bible translation.
/// Contains formatting preferences that affect how pages are rendered.
class RenderingConfig {
  final bool enablePoetryFormatting;
  final bool enableParagraphSpacing;
  final String pageFormat; // e.g., "single", "double"

  const RenderingConfig({
    this.enablePoetryFormatting = true,
    this.enableParagraphSpacing = true,
    this.pageFormat = 'single',
  });

  /// Creates a copy of this rendering config with some fields replaced.
  RenderingConfig copyWith({
    bool? enablePoetryFormatting,
    bool? enableParagraphSpacing,
    String? pageFormat,
  }) {
    throw UnimplementedError();
  }
}

/// Represents rendering progress information during the rendering process.
class RenderingProgress {
  final int totalBooks;
  final int booksProcessed;
  final String currentBook;

  const RenderingProgress({
    required this.totalBooks,
    required this.booksProcessed,
    required this.currentBook,
  });

  /// Calculates the percentage progress (0.0 to 1.0).
  double get percentComplete {
    throw UnimplementedError();
  }
}
