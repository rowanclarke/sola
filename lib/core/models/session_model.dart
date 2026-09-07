class SessionModel {
  final String? currentLanguageCode;
  final String? currentTranslationId;
  final String? currentBookId;
  final int? currentPageNumber;

  /// Translations offered by the reader's switcher, in the order they appear
  /// there. Anything downloaded but absent from this list stays on disk and out
  /// of the way.
  final List<String> switcherTranslationIds;

  const SessionModel({
    this.currentLanguageCode,
    this.currentTranslationId,
    this.currentBookId,
    this.currentPageNumber,
    this.switcherTranslationIds = const [],
  });

  SessionModel copyWith({
    String? currentLanguageCode,
    String? currentTranslationId,
    String? currentBookId,
    int? currentPageNumber,
    List<String>? switcherTranslationIds,
  }) {
    return SessionModel(
      currentLanguageCode: currentLanguageCode ?? this.currentLanguageCode,
      currentTranslationId: currentTranslationId ?? this.currentTranslationId,
      currentBookId: currentBookId ?? this.currentBookId,
      currentPageNumber: currentPageNumber ?? this.currentPageNumber,
      switcherTranslationIds:
          switcherTranslationIds ?? this.switcherTranslationIds,
    );
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      currentLanguageCode: json['currentLanguageCode'] as String?,
      currentTranslationId: json['currentTranslationId'] as String?,
      currentBookId: json['currentBookId'] as String?,
      currentPageNumber: json['currentPageNumber'] as int?,
      switcherTranslationIds:
          (json['switcherTranslationIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLanguageCode': currentLanguageCode,
      'currentTranslationId': currentTranslationId,
      'currentBookId': currentBookId,
      'currentPageNumber': currentPageNumber,
      'switcherTranslationIds': switcherTranslationIds,
    };
  }
}
