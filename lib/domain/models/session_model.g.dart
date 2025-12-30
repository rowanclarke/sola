// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionModel _$SessionModelFromJson(Map<String, dynamic> json) => SessionModel(
  translationId: json['translationId'] as String,
  bookId: json['bookId'] as String,
  pageNumber: (json['pageNumber'] as num).toInt(),
  embeddingModelId: json['embeddingModelId'] as String?,
);

Map<String, dynamic> _$SessionModelToJson(SessionModel instance) =>
    <String, dynamic>{
      'translationId': instance.translationId,
      'bookId': instance.bookId,
      'pageNumber': instance.pageNumber,
      'embeddingModelId': instance.embeddingModelId,
    };
