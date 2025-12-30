import 'package:json_annotation/json_annotation.dart';

part 'session_model.g.dart';

@JsonSerializable()
class SessionModel {
  final String translationId;
  final String bookId;
  final int pageNumber;
  final String? embeddingModelId;

  SessionModel({
    required this.translationId,
    required this.bookId,
    required this.pageNumber,
    this.embeddingModelId,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);
  Map<String, dynamic> toJson() => _$SessionModelToJson(this);
}
