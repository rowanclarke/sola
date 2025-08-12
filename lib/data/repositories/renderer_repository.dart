import 'dart:ffi';
import 'dart:typed_data';

import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/page_model.dart';
import 'package:sola/domain/providers/book_provider.dart';

class RendererRepository {
  final BookProvider bookProvider;
  final RendererService rendererService;
  final FileService fileService;
  bool initialized = false;

  late Pointer<Void> pages;
  late int numPages;
  late Pointer<Void> indices;
  late Uint8List verses;

  RendererRepository(
    this.bookProvider,
    this.rendererService,
    this.fileService,
  ) {
    rendererService.registerStyles();
  }

  Future<void> render(String book, double width, double height) async {
    RendererResponse? response;
    await fileService.deleteDirectory(book);
    if (!await fileService.openDirectory(book)) {
      rendererService.registerFontFamilies();
      response = await rendererService.render(
        await bookProvider.getBook(book),
        width,
        height,
      );
    }
    final pages = await fileService.readAsBytes(
      "$book/pages",
      get: response?.getPages,
    );
    final indices = await fileService.readAsBytes(
      "$book/indices",
      get: response?.getIndices,
    );
    verses = await fileService.readAsBytes(
      "$book/verses",
      get: response?.getVerses,
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
