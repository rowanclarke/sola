class SessionStateData {
  final String? currentTranslationId;
  final String? currentBookId;
  final int? currentPageNumber;

  const SessionStateData({
    this.currentTranslationId,
    this.currentBookId,
    this.currentPageNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentTranslationId': currentTranslationId,
      'currentBookId': currentBookId,
      'currentPageNumber': currentPageNumber,
    };
  }

  factory SessionStateData.fromJson(Map<String, dynamic> json) {
    return SessionStateData(
      currentTranslationId: json['currentTranslationId'] as String?,
      currentBookId: json['currentBookId'] as String?,
      currentPageNumber: json['currentPageNumber'] as int?,
    );
  }
}
