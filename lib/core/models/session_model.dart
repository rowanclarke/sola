class SessionModel {
  final String? currentLanguageCode;
  final String? currentTranslationId;
  final String? currentBookId;
  final int? currentPageNumber;

  const SessionModel({
    this.currentLanguageCode,
    this.currentTranslationId,
    this.currentBookId,
    this.currentPageNumber,
  });

  SessionModel copyWith({
    String? currentLanguageCode,
    String? currentTranslationId,
    String? currentBookId,
    int? currentPageNumber,
  }) {
    return SessionModel(
      currentLanguageCode: currentLanguageCode ?? this.currentLanguageCode,
      currentTranslationId: currentTranslationId ?? this.currentTranslationId,
      currentBookId: currentBookId ?? this.currentBookId,
      currentPageNumber: currentPageNumber ?? this.currentPageNumber,
    );
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      currentLanguageCode: json['currentLanguageCode'] as String?,
      currentTranslationId: json['currentTranslationId'] as String?,
      currentBookId: json['currentBookId'] as String?,
      currentPageNumber: json['currentPageNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLanguageCode': currentLanguageCode,
      'currentTranslationId': currentTranslationId,
      'currentBookId': currentBookId,
      'currentPageNumber': currentPageNumber,
    };
  }
}
