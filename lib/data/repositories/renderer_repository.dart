import 'dart:ffi';
import 'dart:typed_data';

import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/page_model.dart';

class RendererRepository {
  final RendererService rendererService;
  final FileService fileService;
  bool initialized = false;

  late Pointer<Void> pages;
  late int numPages;
  late Pointer<Void> indices;
  late Uint8List verses;

  RendererRepository(this.rendererService, this.fileService) {
    rendererService.registerStyles();
  }

  Future<void> render(
    String book,
    double width,
    double height,
    Future<String> Function() getUsfm,
  ) async {
    if (!await fileService.openDirectory(book)) {
      rendererService.registerFontFamilies();
      await rendererService.render(await getUsfm(), width, height);
    }
    final pages = await fileService.readAsBytes(
      "$book/pages",
      get: rendererService.getPages,
    );
    final indices = await fileService.readAsBytes(
      "$book/indices",
      get: rendererService.getIndices,
    );
    verses = await fileService.readAsBytes(
      "$book/verses",
      get: rendererService.getVerses,
    );
    this.pages = rendererService.getArchivedPages(pages);
    numPages = rendererService.getNumPages(this.pages);
    this.indices = rendererService.getArchivedIndices(indices);
    initialized = true;
  }

  Future<PageModel> getPage(int n) async {
    return PageModel(page: await rendererService.getPage(pages, n));
  }
}
