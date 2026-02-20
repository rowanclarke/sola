import 'dart:ffi';
import 'dart:typed_data';

import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/domain/services/bible_service.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/renderer_service.dart';

class RendererRepository {
  final FileService _fileService;
  final RendererService _rendererService;
  final BibleRepository _bibleRepository;
  final BibleService _bibleService;
  final Map<String, List<PageModel>> _pageCache = {};

  Pointer<Void>? archivedIndices;
  Uint8List? verses;
  int? numPages;

  RendererRepository({
    required FileService fileService,
    required RendererService rendererService,
    required BibleRepository bibleRepository,
    required BibleService bibleService,
  }) : _fileService = fileService,
       _rendererService = rendererService,
       _bibleRepository = bibleRepository,
       _bibleService = bibleService;

  Future<List<PageModel>> renderAndLoadPages({
    required String translationId,
    required String bookId,
    required double width,
    required double height,
  }) async {
    final cacheKey = '$bookId-$width-$height';

    if (_pageCache.containsKey(cacheKey)) return _pageCache[cacheKey]!;

    final dir = 'rendered/$translationId/$cacheKey';
    final dirExists = await _fileService.openDirectory(dir);

    RendererResponse? response;
    if (!dirExists) {
      print("Hii");
      await _rendererService.registerFontFamilies();
      final bookBytes = await _bibleRepository.getSerializedBook(
        translationId: translationId,
        bookId: bookId,
      );
      final archivedBook = _bibleService.getArchivedBook(bookBytes);
      response = _rendererService.layout(archivedBook, width, height);
    }

    final pagesBytes = await _fileService.readBytes(
      '$dir/pages',
      response != null ? () async => response!.getPages() : null,
    );
    final indicesBytes = await _fileService.readBytes(
      '$dir/indices',
      response != null ? () async => response!.getIndices() : null,
    );
    final versesBytes = await _fileService.readBytes(
      '$dir/verses',
      response != null ? () async => response!.getVerses() : null,
    );

    final archivedPages = _rendererService.getArchivedPages(pagesBytes);
    archivedIndices = _rendererService.getArchivedIndices(indicesBytes);
    verses = versesBytes;
    numPages = _rendererService.getNumPages(archivedPages);

    final pages = List.generate(
      numPages!,
      (n) => PageModel(_rendererService.getPage(archivedPages, n)),
    );
    _pageCache[cacheKey] = pages;
    return pages;
  }

  void invalidateCache() {
    _pageCache.clear();
  }
}
