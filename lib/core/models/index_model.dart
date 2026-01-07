/// Represents the verse-to-page index for a rendered Bible book.
/// Maps verse references to their corresponding page numbers.
class IndexModel {
  final String translationId;
  final String bookId;
  final Map<String, int> verseToPageMap;

  const IndexModel({
    required this.translationId,
    required this.bookId,
    required this.verseToPageMap,
  });
}
