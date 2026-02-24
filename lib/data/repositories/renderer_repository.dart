import 'dart:ffi';
import 'dart:typed_data';

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

  Pointer<Void>? archivedIndices;
  Uint8List? rawIndices;
  Uint8List? verses;
  int? numPages;

  RendererRepository({
    required FileService fileService,
    required RendererService rendererService,
    required BibleRepository bibleRepository,
  }) : _fileService = fileService,
       _rendererService = rendererService,
       _bibleRepository = bibleRepository;

  Future<List<PageModel>> renderAndLoadPages({
    required String translationId,
    required String bookId,
    required double width,
    required double height,
  }) async {
    final cacheKey = '$translationId/$bookId-$width-$height';

    if (_pageCache.containsKey(cacheKey)) {
      debugPrint('[RendererRepo] Memory cache hit: $cacheKey');
      return _pageCache[cacheKey]!;
    }

    final dir = 'rendered/$translationId/$bookId-$width-$height';
    final dirExists = await _fileService.openDirectory(dir);

    if (!dirExists) {
      debugPrint('[RendererRepo] Rendering $bookId at ${width.toInt()}x${height.toInt()}');
      // Gather inputs on main isolate
      final bookBytes = await _bibleRepository.getSerializedBook(
        translationId: translationId,
        bookId: bookId,
      );
      final fontData = await rootBundle.load('assets/fonts/AveriaSerifLibre-Regular.ttf');

      // Run heavy rendering on background isolate
      final output = await compute(renderInBackground, RenderInput(
        bookBytes: bookBytes,
        fontBytes: fontData.buffer.asUint8List(),
        width: width,
        height: height,
      ));

      // Write serialized results to disk on main isolate
      await _fileService.writeBytes('$dir/pages', output.pages);
      await _fileService.writeBytes('$dir/indices', output.indices);
      await _fileService.writeBytes('$dir/verses', output.verses);
      debugPrint('[RendererRepo] Render complete, saved to disk');
    } else {
      debugPrint('[RendererRepo] Disk cache hit: $dir');
    }

    // Read from disk (fast if just written, or from cache on re-open)
    final pagesBytes = await _fileService.readBytes('$dir/pages');
    final indicesBytes = await _fileService.readBytes('$dir/indices');
    final versesBytes = await _fileService.readBytes('$dir/verses');

    // Deserialize on main isolate (fast pointer operations)
    final archivedPages = _rendererService.getArchivedPages(pagesBytes);
    rawIndices = indicesBytes;
    archivedIndices = _rendererService.getArchivedIndices(indicesBytes);
    verses = versesBytes;
    numPages = _rendererService.getNumPages(archivedPages);

    final pages = List.generate(
      numPages!,
      (n) => PageModel(_rendererService.getPage(archivedPages, n)),
    );
    _pageCache[cacheKey] = pages;
    debugPrint('[RendererRepo] Deserialized $numPages pages');
    return pages;
  }

  void invalidateCache() {
    debugPrint('[RendererRepo] Cache invalidated');
    _pageCache.clear();
  }
}
