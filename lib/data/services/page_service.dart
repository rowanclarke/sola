import 'dart:async';
import '../model/page_api_model.dart';

class PageService {
  Future<List<PageApiModel>> fetchPages() async {
    await Future.delayed(Duration(seconds: 1)); // simulate fetch
    return List.generate(
      5,
      (i) => PageApiModel(id: i + 1, content: 'Page number ${i + 1}'),
    );
  }
}
