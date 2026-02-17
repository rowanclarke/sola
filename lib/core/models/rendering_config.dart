/// Represents rendering configuration options for formatting a Bible translation.
/// Contains formatting preferences that affect how pages are rendered.
class RenderingConfig {
  final int fontSize;

  const RenderingConfig({
    required this.fontSize,
  });
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
