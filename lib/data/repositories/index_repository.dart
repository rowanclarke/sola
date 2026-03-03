import 'package:flutter/foundation.dart';
import 'package:sola/core/models/index.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/index_service.dart';

class IndexRepository {
  final FileService _fileService;
  final IndexService _indexService;

  final Map<String, IndexResponse> _responseCache = {};

  IndexRepository({
    required FileService fileService,
    required IndexService indexService,
  }) : _fileService = fileService,
       _indexService = indexService;

  Future<void> indexBooks(
    String translationId,
    Map<String, Uint8List> books,
  ) async {
    final key = translationId;
    if (_responseCache.containsKey(key)) {
      debugPrint('[IndexRepo] Response cache hit: $key');
      return;
    }
    debugPrint('[IndexRepo] Fetching new index');
    final index = _indexService.getIndex();
    for (final bookId in books.keys) {
      index.addBook(bookId, books[bookId]!);
      debugPrint('[IndexRepo] Indexed $bookId');
    }
    _responseCache[key] = index;
  }

  List<Index> searchIndex(String translationId, String query) {
    debugPrint(
      '[IndexRepo] Cache status: ${_responseCache[translationId] != null}',
    );
    final index = _responseCache[translationId]!;
    return index.search(query);
  }
}
