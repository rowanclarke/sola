import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/embeddings_data.dart';
import 'package:sola/core/models/embeddings_info.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/domain/services/embeddings_service.dart';
import 'package:sola/domain/services/model_service.dart';

class EmbeddingsRepository {
  final EmbeddingsService _embeddingsService;
  final ModelService _modelService;

  final Map<String, EmbeddingsData> _cache = {};

  Uint8List? _modelBytes;
  Uint8List? _tokenizerBytes;
  String? _loadedModelId;

  EmbeddingsRepository({
    required EmbeddingsService embeddingsService,
    required ModelService modelService,
  }) : _embeddingsService = embeddingsService,
       _modelService = modelService;

  Uint8List get modelBytes {
    if (_modelBytes == null) throw StateError('Model not loaded');
    return _modelBytes!;
  }

  Uint8List get tokenizerBytes {
    if (_tokenizerBytes == null) throw StateError('Model not loaded');
    return _tokenizerBytes!;
  }

  Future<void> ensureModel(ModelInfo model) async {
    if (_loadedModelId == model.id && _modelBytes != null) return;

    debugPrint('[EmbeddingsRepo] Ensuring model ${model.id}...');
    await _modelService.ensureAvailable(model);

    final basePath = _modelService.getPath(model.id);
    _modelBytes = await _embeddingsService.readModelBytes(basePath);
    _tokenizerBytes = await _embeddingsService.readTokenizerBytes(basePath);
    _loadedModelId = model.id;
    debugPrint('[EmbeddingsRepo] Model ${model.id} ready');
  }

  Future<void> ensureAvailable(EmbeddingsInfo info) async {
    debugPrint(
      '[EmbeddingsRepo] Ensuring embeddings for ${info.translationId}...',
    );
    await _embeddingsService.ensureAvailable(info);
    debugPrint('[EmbeddingsRepo] Embeddings for ${info.translationId} ready');
  }

  Future<EmbeddingsData> getEmbeddings({
    required String translationId,
    required String bookId,
  }) async {
    final key = '$translationId/$bookId';

    if (_cache.containsKey(key)) {
      debugPrint('[EmbeddingsRepo] Cache hit: $key');
      return _cache[key]!;
    }

    debugPrint('[EmbeddingsRepo] Reading embeddings for $bookId from disk...');
    final data = await _embeddingsService.readEmbeddings(
      translationId: translationId,
      bookId: bookId,
    );
    _cache[key] = data;
    return data;
  }

  Future<void> ensureEmbeddings({
    required String translationId,
    required List<String> bookIds,
  }) async {
    for (final bookId in bookIds) {
      try {
        await getEmbeddings(translationId: translationId, bookId: bookId);
      } catch (e) {
        debugPrint(
          '[EmbeddingsRepo] Failed to load embeddings for $bookId: $e',
        );
      }
    }
  }

  void dispose() {
    _cache.clear();
    _modelBytes = null;
    _tokenizerBytes = null;
    _loadedModelId = null;
  }
}
