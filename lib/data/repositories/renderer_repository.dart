import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/render_isolate.dart';
import 'package:sola/domain/services/renderer_service.dart';

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

  Future<List<String>> renderAll({
    required String translationId,
    required double width,
    required double height,
  }) async {
    final books = await _bibleRepository.getSerializedBooks(
      translationId: translationId,
    );
    for (final book in books.entries) {
      await _renderBook(translationId, book.key, width, height, book.value);
    }
    return books.keys.toList();
  }

  void invalidateCache() {
    debugPrint('[RendererRepo] Cache invalidated');
    _pageCache.clear();
  }
}
