import 'dart:ffi';
import 'dart:typed_data';

import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/page_model.dart';

class RendererRepository {
  final RendererService rendererService;
  final FileService fileService;
  final String book;

  late Pointer<Void> pages;
  late int numPages;
  late Pointer<Void> indices;
  late Uint8List verses;

  RendererRepository(this.book, this.rendererService, this.fileService) {
    rendererService.registerStyles();
  }

  Future<void> init(
    Future<Pointer<Void>> Function() getArchived,
    double width,
    double height,
  ) async {
    RendererResponse? response;
    await fileService.deleteDirectory(book);
    if (!await fileService.openDirectory(book)) {
      rendererService.registerFontFamilies();
      response = await rendererService.render(
        await getArchived(),
        width,
        height,
      );
    }
    final pages = await fileService.readAsBytes("pages", response?.getPages);
    final indices = await fileService.readAsBytes(
      "indices",
      response?.getIndices,
    );
    verses = await fileService.readAsBytes("verses", response?.getVerses);
    this.pages = rendererService.getArchivedPages(pages);
    numPages = rendererService.getNumPages(this.pages);
    this.indices = rendererService.getArchivedIndices(indices);
  }

  Future<PageModel> getPage(int n) async {
    return PageModel(page: await rendererService.getPage(pages, n));
  }
}
