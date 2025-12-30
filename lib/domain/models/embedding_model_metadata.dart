import 'package:json_annotation/json_annotation.dart';

part 'embedding_model_metadata.g.dart';

@JsonSerializable()
class EmbeddingModelMetadata {
  final String id;
  final String name;
  final String language;
  final String downloadUrl;
  final int fileSize;

  EmbeddingModelMetadata({
    required this.id,
    required this.name,
    required this.language,
    required this.downloadUrl,
    required this.fileSize,
  });

  factory EmbeddingModelMetadata.fromJson(Map<String, dynamic> json) =>
      _$EmbeddingModelMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$EmbeddingModelMetadataToJson(this);
}
