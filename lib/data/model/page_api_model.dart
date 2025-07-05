import '../../domain/models/page_model.dart';

class PageApiModel {
  final int id;
  final String content;

  PageApiModel({required this.id, required this.content});

  PageModel toDomain() => PageModel(id: id, text: content);
}
