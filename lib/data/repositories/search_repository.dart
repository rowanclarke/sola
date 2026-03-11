import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/model_service.dart';
import 'package:sola/domain/services/search_isolate.dart';
import 'package:sola/domain/services/search_service.dart';

class SearchRepository {
  final FileService _fileService;
  final SearchService _searchService;
  final ModelService _modelService;

  final Map<String, SearchIsolate> _isolates = {};

  // Shared model files (same across all books in a translation)
  Uint8List? _modelBytes;
  Uint8List? _tokenizerBytes;
  Uint8List? _embeddingsBytes;
  String? _loadedModelId;

  SearchRepository({
    required FileService fileService,
    required SearchService searchService,
    required ModelService modelService,
  }) : _fileService = fileService,
       _searchService = searchService,
       _modelService = modelService;

  bool get isReady => _isolates.isNotEmpty;

  Future<void> _ensureModelFiles(ModelInfo model) async {
    if (_loadedModelId == model.id) return;

    debugPrint('[SearchRepo] Downloading model if needed...');
    await _modelService.ensureAvailable(model);

    final basePath = _modelService.getPath(model.id);
    debugPrint('[SearchRepo] Loading model files from $basePath...');

    _embeddingsBytes = await _fileService.readBytes(
      '$basePath/embeddings.npy',
    );
    _modelBytes = await _fileService.readBytes(
      '$basePath/all-minilm-l6-v2.onnx',
    );
    _tokenizerBytes = await _fileService.readBytes(
      '$basePath/tokenizer/tokenizer.json',
    );
    _loadedModelId = model.id;
  }

  Future<void> loadModel({
    required ModelInfo model,
    required String translationId,
    required List<String> bookIds,
    required double width,
    required double height,
  }) async {
    await _ensureModelFiles(model);

    for (final bookId in bookIds) {
      if (_isolates.containsKey(bookId)) continue;

      final dir = 'rendered/$translationId/$bookId-$width-$height';
      try {
        final indicesBytes = await _fileService.readBytes('$dir/indices');
        final verses = await _fileService.readBytes('$dir/verses');

        _isolates[bookId] = await _searchService.createSearchIsolate(
          bookId: bookId,
          indicesBytes: indicesBytes,
          embeddings: _embeddingsBytes!,
          verses: verses,
          model: _modelBytes!,
          tokenizer: _tokenizerBytes!,
        );
      } catch (e) {
        debugPrint('[SearchRepo] Failed to load search for $bookId: $e');
      }
    }
    debugPrint('[SearchRepo] ${_isolates.length} book isolates ready');
  }

  Future<List<Index>> getResult(String query) async {
    if (_isolates.isEmpty) throw StateError('No search isolates loaded');

    final futures = _isolates.values.map((iso) async {
      try {
        return <Index>[await iso.getResult(query)];
      } catch (e) {
        debugPrint('[SearchRepo] getResult failed for ${iso.bookId}: $e');
        return <Index>[];
      }
    });

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
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
    _modelBytes = null;
    _tokenizerBytes = null;
    _embeddingsBytes = null;
    _loadedModelId = null;
  }
}
