/// Represents a serializable format of session state for persistence.
/// Used when saving/loading session data to/from storage.
class SessionStateData {
  final String? currentTranslationId;
  final String? currentBookId;
  final int? currentPageNumber;

  const SessionStateData({
    this.currentTranslationId,
    this.currentBookId,
    this.currentPageNumber,
  });

  /// Converts this to a JSON-compatible map for serialization.
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  /// Creates an instance from a JSON-compatible map.
  factory SessionStateData.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }
}
