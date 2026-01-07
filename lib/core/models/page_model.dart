/// Represents a single rendered page of Bible content.
/// Contains the text content to be displayed on a page.
class PageModel {
  final String translationId;
  final String bookId;
  final int pageNumber;
  final String content; // The formatted text content of the page

  const PageModel({
    required this.translationId,
    required this.bookId,
    required this.pageNumber,
    required this.content,
  });
}
