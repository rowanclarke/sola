import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sola/data/services/renderer_service.dart';
import '../../domain/models/page_model.dart';
import '../services/bible_service.dart';

class PageRepository {
  final BibleService service;
  final RendererService renderer;

  final String url;
  final String book;

  PageRepository(this.service, this.renderer, this.url, this.book) {
    renderer.registerStyles();
  }

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/a1';
  }

  Future<List<PageModel>> getPages(double width, double height) async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    if (!await file.exists()) {
      renderer.registerFontFamilies();
      final bible = await service.fetchBible(url);
      final render = await renderer.render(bible[book]!, width, height);
      await file.writeAsBytes(render);
    }

    renderer.rendered = await file.readAsBytes();
    return [
      PageModel(page: await renderer.getPage(0, width, height)),
      PageModel(page: await renderer.getPage(1, width, height)),
    ];
  }
}
