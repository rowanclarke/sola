import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/render_isolate.dart';
import 'package:sola/domain/services/renderer_service.dart';

const _canonicalBookOrder = [
  'GEN','EXO','LEV','NUM','DEU','JOS','JDG','RUT',
  '1SA','2SA','1KI','2KI','1CH','2CH','EZR','NEH',
  'EST','JOB','PSA','PRO','ECC','SNG','ISA','JER',
  'LAM','EZK','DAN','HOS','JOL','AMO','OBA','JON',
  'MIC','NAM','HAB','ZEP','HAG','ZEC','MAL',
  'MAT','MRK','LUK','JHN','ACT','ROM','1CO','2CO',
  'GAL','EPH','PHP','COL','1TH','2TH','1TI','2TI',
  'TIT','PHM','HEB','JAS','1PE','2PE','1JN','2JN',
  '3JN','JUD','REV',
];

class RendererRepository {
  final FileService _fileService;
  final RendererService _rendererService;
  final BibleRepository _bibleRepository;
  final Map<String, List<PageModel>> _pageCache = {};

  RendererRepository({
    required FileService fileService,
    required RendererService rendererService,
    required BibleRepository bibleRepository,
  }) : _fileService = fileService,
       _rendererService = rendererService,
       _bibleRepository = bibleRepository;

  Future<String> _renderBook(
    String translationId,
    String bookId,
    double width,
    double height, [
    Uint8List? bytes,
  ]) async {
    final dir =
        'rendered/$translationId/$bookId-${width.toInt()}-${height.toInt()}';
    final dirExists = await _fileService.openDirectory(dir);

    if (!dirExists) {
      debugPrint(
        '[RendererRepo] Rendering $bookId at ${width.toInt()}x${height.toInt()}',
      );
      // Gather inputs on main isolate
      final bookBytes =
          bytes ??
          await _bibleRepository.getSerializedBook(
            translationId: translationId,
            bookId: bookId,
          );
      final fontData = await rootBundle.load(
        // TODO cache fonts
        'assets/fonts/AveriaSerifLibre-Regular.ttf',
      );

      // Run heavy rendering on background isolate
      final output = await compute(
        renderInBackground,
        RenderInput(
          bookBytes: bookBytes,
          fontBytes: fontData.buffer.asUint8List(),
          width: width,
          height: height,
        ),
      );

      // Write serialized results to disk on main isolate
      await _fileService.writeBytes('$dir/pages', output.pages);
      await _fileService.writeBytes('$dir/indices', output.indices);
      await _fileService.writeBytes('$dir/verses', output.verses);
      debugPrint('[RendererRepo] Render complete of $bookId, saved to disk');
    } else {
      debugPrint('[RendererRepo] Disk cache hit: $dir');
    }

    return dir;
  }

  Future<List<PageModel>> renderAndLoadPages({
    required String translationId,
    required String bookId,
    required double width,
    required double height,
  }) async {
    final cacheKey =
        '$translationId/$bookId-${width.toInt()}-${height.toInt()}';

    if (_pageCache.containsKey(cacheKey)) {
      debugPrint('[RendererRepo] Memory cache hit: $cacheKey');
      return _pageCache[cacheKey]!;
    }

    final dir = await _renderBook(translationId, bookId, width, height);

    // Read from disk (fast if just written, or from cache on re-open)
    final pagesBytes = await _fileService.readBytes('$dir/pages');

    // Deserialize on main isolate (fast pointer operations)
    final archivedPages = _rendererService.getArchivedPages(pagesBytes);
    final numPages = _rendererService.getNumPages(archivedPages);

    final pages = List.generate(
      numPages,
      (n) => PageModel(_rendererService.getPage(archivedPages, n)),
    );
    _pageCache[cacheKey] = pages;
    debugPrint('[RendererRepo] Deserialized $numPages pages');
    return pages;
  }

  Future<Map<String, ({int pageCount, String title})>> renderAll({
    required String translationId,
    required double width,
    required double height,
  }) async {
    final books = await _bibleRepository.getSerializedBooks(
      translationId: translationId,
    );
    // First pass: render all books
    final dirs = <String, String>{};
    for (final book in books.entries) {
      dirs[book.key] = await _renderBook(
        translationId, book.key, width, height, book.value,
      );
    }
    // Second pass: read page counts and titles
    final unsorted = <String, ({int pageCount, String title})>{};
    for (final entry in dirs.entries) {
      final pagesBytes = await _fileService.readBytes('${entry.value}/pages');
      final archivedPages = _rendererService.getArchivedPages(pagesBytes);
      final pageCount = _rendererService.getNumPages(archivedPages);

      final indicesBytes = await _fileService.readBytes('${entry.value}/indices');
      final title = _rendererService.getBookTitle(indicesBytes);

      unsorted[entry.key] = (pageCount: pageCount, title: title);
    }
    // Sort into canonical Bible order
    final result = <String, ({int pageCount, String title})>{};
    for (final id in _canonicalBookOrder) {
      if (unsorted.containsKey(id)) {
        result[id] = unsorted[id]!;
      }
    }
    return result;
  }

  void invalidateCache() {
    debugPrint('[RendererRepo] Cache invalidated');
    _pageCache.clear();
  }
}
