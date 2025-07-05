import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../domain/models/page_model.dart';
import '../services/page_service.dart';

class PageRepository {
  final PageService service;
  static const _fileName = "pages";

  PageRepository(this.service);

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  Future<List<PageModel>> getPages() async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      print("File exists");
    }

    await file.writeAsString("Dummy");
    final apiModels = await service.fetchPages();
    return apiModels.map((a) => a.toDomain()).toList();
  }
}
