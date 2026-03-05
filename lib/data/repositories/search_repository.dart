import 'package:flutter/foundation.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/model_service.dart';
import 'package:sola/domain/services/search_service.dart';

import '../../core/models/index.dart';

class SearchRepository {
  final FileService _fileService;
  final SearchService _searchService;
  final RendererRepository _rendererRepository;
  final ModelService _modelService;

  SearchRepository({
    required FileService fileService,
    required SearchService searchService,
    required RendererRepository rendererRepository,
    required ModelService modelService,
  }) : _fileService = fileService,
       _searchService = searchService,
       _rendererRepository = rendererRepository,
       _modelService = modelService;

  Future<void> loadModel(ModelInfo model) async {
    final indicesBytes = _rendererRepository.rawIndices;
    final verses = _rendererRepository.verses;
    if (indicesBytes == null || verses == null) {
      debugPrint(
        '[SearchRepo] Cannot load model: indices/verses not available',
      );
      return;
    }

    debugPrint('[SearchRepo] Downloading model if needed...');
    await _modelService.ensureAvailable(model);

    final basePath = _modelService.getPath(model.id);
    debugPrint('[SearchRepo] Loading model files from $basePath...');

    final embeddings = await _fileService.readBytes('$basePath/embeddings.npy');
    final onnxModel = await _fileService.readBytes(
      '$basePath/all-minilm-l6-v2.onnx',
    );
    final tokenizer = await _fileService.readBytes(
      '$basePath/tokenizer/tokenizer.json',
    );

    debugPrint('[SearchRepo] Initializing ML model...');
    await _searchService.loadModel(
      indicesBytes,
      embeddings,
      verses,
      onnxModel,
      tokenizer,
    );
    debugPrint('[SearchRepo] Model ready');
  }

  Future<Index> getResult(String query) async {
    return await _searchService.getResult(query);
  }

  Future<List<Index>> searchIndex(String query) async {
    return await _searchService.searchIndex(query);
  }
}
