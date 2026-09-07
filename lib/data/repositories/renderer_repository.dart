import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sola/core/models/page_index.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/domain/services/book_pages.dart';
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

/// What the reader needs to know about every book up front: enough to size the
/// scrubber and label it, and nothing that requires touching a `pages` file.
typedef BookData = ({int pageCount, String title, List<String> verseRanges});

class RendererRepository {
  /// Version of the [_readManifest] payload; bump when its shape changes.
  static const _manifestVersion = 1;

  /// How many books stay open at once. The current book plus whatever was read
  /// just before it, so paging back to the previous book costs nothing; each
  /// one holds a file handle and its offset table.
  static const _maxOpenBooks = 2;

  final FileService _fileService;
  final RendererService _rendererService;
  final BibleRepository _bibleRepository;

  /// Number of equal-width body columns each page is laid out in. Part of the
  /// on-disk key: the same page size rendered at a different column count is a
  /// different layout, so it must not reuse the cached pages.
  final int columns;

  /// Horizontal space between adjacent columns.
  final double gutter;

  /// Open books, least recently used first.
  final LinkedHashMap<String, BookPages> _openBooks = LinkedHashMap();

  RendererRepository({
    required FileService fileService,
    required RendererService rendererService,
    required BibleRepository bibleRepository,
    this.columns = 1,
    this.gutter = 0,
  }) : _fileService = fileService,
       _rendererService = rendererService,
       _bibleRepository = bibleRepository;

  /// Layout key shared by every rendered path, so a change of page size *or*
  /// column count lands in its own directory.
  String _layoutKey(double width, double height) =>
      '${width.toInt()}-${height.toInt()}-$columns';

  String _bookDir(String translationId, String bookId, double width, double height) =>
      'rendered/$translationId/$bookId-${_layoutKey(width, height)}';

  String _manifestPath(String translationId, double width, double height) =>
      'rendered/$translationId/manifest-${_layoutKey(width, height)}.json';

  /// Lays a book out and writes it to disk, unless that has already been done.
  ///
  /// Presence of `page_offsets` is the marker: a directory left by an older
  /// build has no offset table, and its `pages` file is in a format this
  /// version cannot seek into, so it gets rendered again.
  Future<String> _renderBook(
    String translationId,
    String bookId,
    double width,
    double height, [
    Uint8List? bytes,
  ]) async {
    final dir = _bookDir(translationId, bookId, width, height);

    if (await _fileService.fileExists('$dir/page_offsets')) {
      debugPrint('[RendererRepo] Disk cache hit: $dir');
      return dir;
    }

    debugPrint(
      '[RendererRepo] Rendering $bookId at ${width.toInt()}x${height.toInt()} '
      'in $columns column(s)',
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
        columns: columns,
        gutter: gutter,
      ),
    );

    // Write serialized results to disk on main isolate. The offset table is
    // written last: it is what marks the directory as complete.
    await _fileService.writeBytes('$dir/pages', output.pages);
    await _fileService.writeBytes('$dir/indices', output.indices);
    await _fileService.writeBytes('$dir/verses', output.verses);
    await _fileService.writeBytes('$dir/verse_ranges', output.verseRanges);
    await _fileService.writeBytes('$dir/page_offsets', output.pageOffsets);
    debugPrint('[RendererRepo] Render complete of $bookId, saved to disk');

    return dir;
  }

  /// Opens one book's pages for reading a page at a time.
  ///
  /// Nothing but the offset table is read here: the pages themselves come off
  /// disk as the reader asks for them.
  Future<BookPages> openBook({
    required String translationId,
    required String bookId,
    required double width,
    required double height,
  }) async {
    final key = '$translationId/$bookId-${_layoutKey(width, height)}';

    final open = _openBooks.remove(key);
    if (open != null && !open.isClosed) {
      debugPrint('[RendererRepo] Already open: $key');
      _openBooks[key] = open;
      return open;
    }

    final dir = await _renderBook(translationId, bookId, width, height);
    final book = await BookPages.open(
      pagesPath: _fileService.resolve('$dir/pages'),
      offsets: await _fileService.readBytes('$dir/page_offsets'),
      renderer: _rendererService,
    );
    _openBooks[key] = book;

    // Evict the least recently used book; the one just opened is last, so it
    // is never the one that goes.
    while (_openBooks.length > _maxOpenBooks) {
      final evicted = _openBooks.remove(_openBooks.keys.first)!;
      debugPrint('[RendererRepo] Closing least recently used book');
      await evicted.close();
    }
    return book;
  }

  /// Every book a translation has been serialized into, in canonical order.
  ///
  /// Translations differ in what they contain — plenty are New Testament only —
  /// so this is what a caller consults before assuming a book exists.
  Future<List<String>> availableBooks(String translationId) async {
    return _inCanonicalOrder(
      await _fileService.listDirectory('serialized/$translationId'),
    );
  }

  /// Renders every book of a translation that is not on disk yet, and returns
  /// what the reader needs to know about all of them, in canonical order.
  ///
  /// The per-book totals are cached in one manifest so a warm start reads a
  /// single small file instead of reopening every book's output.
  Future<Map<String, BookData>> renderAll({
    required String translationId,
    required double width,
    required double height,
  }) async {
    final bookIds = await availableBooks(translationId);

    final cached = await _readManifest(translationId, width, height, bookIds);
    if (cached != null) {
      debugPrint('[RendererRepo] Manifest hit: ${cached.length} books');
      return cached;
    }

    // No manifest: make sure every book is rendered, then read back the totals.
    // Book bytes are fetched per book so a translation that is already rendered
    // never loads them at all.
    final result = <String, BookData>{};
    for (final bookId in bookIds) {
      final dir = await _renderBook(translationId, bookId, width, height);

      final offsets = await _fileService.readBytes('$dir/page_offsets');
      final pageCount = PageIndex.parse(offsets).pageCount;

      final indicesBytes = await _fileService.readBytes('$dir/indices');
      final title = _rendererService.getBookTitle(indicesBytes);

      List<String> verseRanges;
      if (await _fileService.fileExists('$dir/verse_ranges')) {
        final vrBytes = await _fileService.readBytes('$dir/verse_ranges');
        verseRanges = utf8.decode(vrBytes).split('\n');
      } else {
        verseRanges = List.filled(pageCount, '');
      }

      result[bookId] = (
        pageCount: pageCount,
        title: title,
        verseRanges: verseRanges,
      );
    }

    // The serialized USFM is only an input to rendering; nothing reads it once
    // the pages are on disk.
    _bibleRepository.invalidateCache();

    await _writeManifest(translationId, width, height, result);
    return result;
  }

  List<String> _inCanonicalOrder(List<String> bookIds) {
    final present = bookIds.toSet();
    return [
      for (final id in _canonicalBookOrder)
        if (present.contains(id)) id,
    ];
  }

  /// The cached per-book totals, or null when there is no usable manifest for
  /// exactly [bookIds] — in which case the caller rebuilds it.
  Future<Map<String, BookData>?> _readManifest(
    String translationId,
    double width,
    double height,
    List<String> bookIds,
  ) async {
    final path = _manifestPath(translationId, width, height);
    if (!await _fileService.fileExists(path)) return null;
    try {
      final decoded = json.decode(await _fileService.readFile(path));
      if (decoded is! Map || decoded['version'] != _manifestVersion) return null;

      final books = decoded['books'];
      if (books is! List) return null;

      final result = <String, BookData>{};
      for (final book in books) {
        result[book['id'] as String] = (
          pageCount: book['pageCount'] as int,
          title: book['title'] as String,
          verseRanges: (book['verseRanges'] as List).cast<String>(),
        );
      }
      // A manifest for a different set of books says nothing about this one.
      if (result.length != bookIds.length ||
          !bookIds.every(result.containsKey)) {
        return null;
      }
      return result;
    } catch (e) {
      debugPrint('[RendererRepo] Ignoring unreadable manifest: $e');
      return null;
    }
  }

  Future<void> _writeManifest(
    String translationId,
    double width,
    double height,
    Map<String, BookData> books,
  ) async {
    await _fileService.writeFile(
      _manifestPath(translationId, width, height),
      json.encode({
        'version': _manifestVersion,
        'books': [
          for (final entry in books.entries)
            {
              'id': entry.key,
              'title': entry.value.title,
              'pageCount': entry.value.pageCount,
              'verseRanges': entry.value.verseRanges,
            },
        ],
      }),
    );
    debugPrint('[RendererRepo] Manifest written for ${books.length} books');
  }

  Future<void> invalidateCache() async {
    debugPrint('[RendererRepo] Cache invalidated');
    final open = _openBooks.values.toList();
    _openBooks.clear();
    for (final book in open) {
      await book.close();
    }
  }
}
