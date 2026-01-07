/// Represents the persistent session state of the application.
/// Stores the currently active translation, book, and page.
class SessionModel {
  final String? currentTranslationId;
  final String? currentBookId;
  final int? currentPageNumber;

  const SessionModel({
    this.currentTranslationId,
    this.currentBookId,
    this.currentPageNumber,
  });

  SessionModel copyWith({
    String? currentTranslationId,
    String? currentBookId,
    int? currentPageNumber,
  }) {
    throw UnimplementedError();
  }
}
