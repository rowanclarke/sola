// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedding_model_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmbeddingModelMetadata _$EmbeddingModelMetadataFromJson(
  Map<String, dynamic> json,
) => EmbeddingModelMetadata(
  id: json['id'] as String,
  name: json['name'] as String,
  language: json['language'] as String,
  downloadUrl: json['downloadUrl'] as String,
  fileSize: (json['fileSize'] as num).toInt(),
);

Map<String, dynamic> _$EmbeddingModelMetadataToJson(
  EmbeddingModelMetadata instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'language': instance.language,
  'downloadUrl': instance.downloadUrl,
  'fileSize': instance.fileSize,
};
