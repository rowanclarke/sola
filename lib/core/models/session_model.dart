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
    return SessionModel(
      currentTranslationId: currentTranslationId ?? this.currentTranslationId,
      currentBookId: currentBookId ?? this.currentBookId,
      currentPageNumber: currentPageNumber ?? this.currentPageNumber,
    );
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      currentTranslationId: json['currentTranslationId'] as String?,
      currentBookId: json['currentBookId'] as String?,
      currentPageNumber: json['currentPageNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTranslationId': currentTranslationId,
      'currentBookId': currentBookId,
      'currentPageNumber': currentPageNumber,
    };
  }
}
