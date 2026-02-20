class RenderingConfig {
  final int fontSize;

  const RenderingConfig({
    required this.fontSize,
  });
}

class RenderingProgress {
  final int totalBooks;
  final int booksProcessed;
  final String currentBook;

  const RenderingProgress({
    required this.totalBooks,
    required this.booksProcessed,
    required this.currentBook,
  });

  double get percentComplete =>
      totalBooks == 0 ? 0.0 : booksProcessed / totalBooks;
}
