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
    if (_modelLoaded) return;
    final indices = _rendererRepository.archivedIndices;
    final verses = _rendererRepository.verses;
    if (indices == null || verses == null) return;

    final embeddings = await _fileService.readBytes('model/embeddings.npy');
    final model = await _fileService.readBytes('model/all-minilm-l6-v2.onnx');
    final tokenizer = await _fileService.readBytes('model/tokenizer/tokenizer.json');

    _searchService.loadModel(indices, embeddings, verses, model, tokenizer);
    _modelLoaded = true;
  }

  rust.Index getResult(String query) {
    return _searchService.getResult(query);
  }
}
