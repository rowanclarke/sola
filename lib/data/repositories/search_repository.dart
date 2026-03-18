import 'package:flutter/foundation.dart';
import 'package:sola/core/models/embeddings_info.dart';
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/core/models/search_result.dart';
import 'package:sola/data/repositories/embeddings_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/search_isolate.dart';

class SearchRepository {
  final FileService _fileService;
  final EmbeddingsRepository _embeddingsRepository;

  final Map<String, SearchIsolate> _isolates = {};
  int? _modelAddress;

  SearchRepository({
    required FileService fileService,
    required EmbeddingsRepository embeddingsRepository,
  }) : _fileService = fileService,
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
        final pageMapBytes = await _fileService.readBytes('$dir/indices');
        final embeddingsData = await _embeddingsRepository.getEmbeddings(
          translationId: embeddingsInfo.translationId,
          bookId: bookId,
        );

        _isolates[bookId] = await SearchIsolate.spawn(
          bookId: bookId,
          pageMapBytes: pageMapBytes,
          embeddings: embeddingsData.embeddingsBytes,
          verseRefs: embeddingsData.verseRefsBytes,
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

    final searchFutures = _isolates.values.map((isolate) async {
      try {
        return await isolate.getResult(query);
      } catch (e) {
        debugPrint('[SearchRepo] getResult failed for ${isolate.bookId}: $e');
        return <SearchResult>[];
      }
    });

    final results = await Future.wait(searchFutures);
    final merged = results.expand((list) => list).toList();
    merged.sort((a, b) => a.distance.compareTo(b.distance));
    return merged;
  }

  Future<List<Index>> searchIndex(String query) async {
    if (_isolates.isEmpty) throw StateError('No search isolates loaded');

    final searchFutures = _isolates.values.map((isolate) async {
      try {
        return await isolate.searchIndex(query);
      } catch (e) {
        debugPrint('[SearchRepo] searchIndex failed for ${isolate.bookId}: $e');
        return <Index>[];
      }
    });

    final results = await Future.wait(searchFutures);
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
