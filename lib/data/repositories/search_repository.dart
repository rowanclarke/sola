import 'package:flutter/foundation.dart';
import 'package:sola/core/models/embeddings_info.dart';
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/core/models/search_result.dart';
import 'package:sola/data/repositories/embeddings_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/search_isolate.dart';
import 'package:sola/domain/services/search_service.dart';

class SearchRepository {
  final FileService _fileService;
  final SearchService _searchService;
  final EmbeddingsRepository _embeddingsRepository;

  final Map<String, SearchIsolate> _isolates = {};
  int? _modelAddress;

  SearchRepository({
    required FileService fileService,
    required SearchService searchService,
    required EmbeddingsRepository embeddingsRepository,
  }) : _fileService = fileService,
       _searchService = searchService,
       _embeddingsRepository = embeddingsRepository;

  bool get isReady => _isolates.isNotEmpty;

  Future<void> loadModel({
    required ModelInfo model,
    required EmbeddingsInfo embeddingsInfo,
    required String translationId,
    required List<String> bookIds,
    required double width,
    required double height,
  }) async {
    await _embeddingsRepository.ensureModel(model);
    await _embeddingsRepository.ensureAvailable(embeddingsInfo);
    await _embeddingsRepository.ensureEmbeddings(
      translationId: embeddingsInfo.translationId,
      bookIds: bookIds,
    );

    if (_modelAddress == null) {
      _modelAddress = await SearchIsolate.loadModelOnce(
        _embeddingsRepository.modelBytes,
        _embeddingsRepository.tokenizerBytes,
      );
    }

    for (final bookId in bookIds) {
      if (_isolates.containsKey(bookId)) continue;

      final dir = 'rendered/$translationId/$bookId-$width-$height';
      try {
        final indicesBytes = await _fileService.readBytes('$dir/indices');
        final embeddingsData = await _embeddingsRepository.getEmbeddings(
          translationId: embeddingsInfo.translationId,
          bookId: bookId,
        );

        _isolates[bookId] = await _searchService.createSearchIsolate(
          bookId: bookId,
          indicesBytes: indicesBytes,
          embeddings: embeddingsData.embeddingsBytes,
          verses: embeddingsData.indicesBytes,
          modelAddress: _modelAddress!,
        );
      } catch (e) {
        debugPrint('[SearchRepo] Failed to load search for $bookId: $e');
      }
    }
    debugPrint('[SearchRepo] ${_isolates.length} book isolates ready');
  }

  Future<List<SearchResult>> getResult(String query) async {
    if (_isolates.isEmpty) throw StateError('No search isolates loaded');

    final futures = _isolates.values.map((iso) async {
      try {
        return await iso.getResult(query);
      } catch (e) {
        debugPrint('[SearchRepo] getResult failed for ${iso.bookId}: $e');
        return <SearchResult>[];
      }
    });

    final results = await Future.wait(futures);
    final merged = results.expand((list) => list).toList();
    merged.sort((a, b) => a.distance.compareTo(b.distance));
    return merged;
  }

  Future<List<Index>> searchIndex(String query) async {
    if (_isolates.isEmpty) throw StateError('No search isolates loaded');

    final futures = _isolates.values.map((iso) async {
      try {
        return await iso.searchIndex(query);
      } catch (e) {
        debugPrint('[SearchRepo] searchIndex failed for ${iso.bookId}: $e');
        return <Index>[];
      }
    });

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  void disposeBook(String bookId) {
    _isolates.remove(bookId)?.dispose();
  }

  void dispose() {
    for (final isolate in _isolates.values) {
      isolate.dispose();
    }
    _isolates.clear();
    _modelAddress = null;
  }
}
