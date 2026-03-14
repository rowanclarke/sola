import 'package:flutter/foundation.dart';
import 'package:sola/core/models/embeddings_data.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/domain/services/embeddings_isolate.dart';
import 'package:sola/domain/services/embeddings_service.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/model_service.dart';

class EmbeddingsRepository {
  final FileService _fileService;
  final EmbeddingsService _embeddingsService;
  final ModelService _modelService;
  final BibleRepository _bibleRepository;

  final Map<String, EmbeddingsData> _cache = {};
  EmbeddingsIsolate? _isolate;
  String? _loadedModelId;

  EmbeddingsRepository({
    required FileService fileService,
    required EmbeddingsService embeddingsService,
    required ModelService modelService,
    required BibleRepository bibleRepository,
  }) : _fileService = fileService,
       _embeddingsService = embeddingsService,
       _modelService = modelService,
       _bibleRepository = bibleRepository;

  String _diskPath(String translationId, String bookId) =>
      'embeddings/$translationId/$bookId';

  Future<void> ensureIsolate(ModelInfo model) async {
    if (_loadedModelId == model.id && _isolate != null) return;

    _isolate?.dispose();

    debugPrint('[EmbeddingsRepo] Downloading model if needed...');
    await _modelService.ensureAvailable(model);

    final basePath = _modelService.getPath(model.id);
    debugPrint('[EmbeddingsRepo] Loading model files from $basePath...');

    final modelBytes = await _fileService.readBytes(
      '$basePath/all-minilm-l6-v2.onnx',
    );
    final tokenizerBytes = await _fileService.readBytes(
      '$basePath/tokenizer/tokenizer.json',
    );

    _isolate = await _embeddingsService.createEmbeddingsIsolate(
      model: modelBytes,
      tokenizer: tokenizerBytes,
    );
    _loadedModelId = model.id;
    debugPrint('[EmbeddingsRepo] Embeddings isolate ready');
  }

  Future<EmbeddingsData> getEmbeddings({
    required String translationId,
    required String bookId,
  }) async {
    final key = '$translationId/$bookId';

    // Memory cache
    if (_cache.containsKey(key)) {
      debugPrint('[EmbeddingsRepo] Memory cache hit: $key');
      return _cache[key]!;
    }

    // Disk cache
    final dir = _diskPath(translationId, bookId);
    final embExists = await _fileService.fileExists('$dir/embeddings');
    final versesExists = await _fileService.fileExists('$dir/verses');
    if (embExists && versesExists) {
      debugPrint('[EmbeddingsRepo] Disk cache hit: $dir');
      final data = EmbeddingsData(
        embeddingsBytes: await _fileService.readBytes('$dir/embeddings'),
        versesBytes: await _fileService.readBytes('$dir/verses'),
      );
      _cache[key] = data;
      return data;
    }

    // Compute
    if (_isolate == null) {
      throw StateError('Embeddings model not loaded');
    }

    debugPrint('[EmbeddingsRepo] Computing embeddings for $bookId...');
    final bookBytes = await _bibleRepository.getSerializedBook(
      translationId: translationId,
      bookId: bookId,
    );
    final data = await _isolate!.computeEmbeddings(bookBytes);

    // Persist to disk
    await _fileService.writeBytes('$dir/embeddings', data.embeddingsBytes);
    await _fileService.writeBytes('$dir/verses', data.versesBytes);
    debugPrint('[EmbeddingsRepo] Cached embeddings for $bookId to disk');

    // Memory cache
    _cache[key] = data;
    return data;
  }

  Future<void> ensureEmbeddings({
    required String translationId,
    required List<String> bookIds,
  }) async {
    for (final bookId in bookIds) {
      await getEmbeddings(translationId: translationId, bookId: bookId);
    }
  }

  void dispose() {
    _isolate?.dispose();
    _isolate = null;
    _cache.clear();
    _loadedModelId = null;
  }
}
