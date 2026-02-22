import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/search_service.dart';

class SearchRepository {
  final FileService _fileService;
  final SearchService _searchService;
  final RendererRepository _rendererRepository;
  bool _modelLoaded = false;

  SearchRepository({
    required FileService fileService,
    required SearchService searchService,
    required RendererRepository rendererRepository,
  }) : _fileService = fileService,
       _searchService = searchService,
       _rendererRepository = rendererRepository;

  Future<void> loadModel() async {
    if (_modelLoaded) {
      debugPrint('[SearchRepo] Model already loaded');
      return;
    }
    final indices = _rendererRepository.archivedIndices;
    final verses = _rendererRepository.verses;
    if (indices == null || verses == null) {
      debugPrint('[SearchRepo] Cannot load model: indices/verses not available');
      return;
    }

    debugPrint('[SearchRepo] Loading model files from disk...');
    final embeddings = await _fileService.readBytes('model/embeddings.npy');
    final model = await _fileService.readBytes('model/all-minilm-l6-v2.onnx');
    final tokenizer = await _fileService.readBytes('model/tokenizer/tokenizer.json');

    debugPrint('[SearchRepo] Initializing ML model...');
    _searchService.loadModel(indices, embeddings, verses, model, tokenizer);
    _modelLoaded = true;
    debugPrint('[SearchRepo] Model ready');
  }

  rust.Index getResult(String query) {
    return _searchService.getResult(query);
  }
}
