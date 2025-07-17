import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';

import '../services/search_service.dart';

class SearchRepository {
  final RendererRepository rendererRepository;
  final FileService fileService;
  final SearchService searchService;

  SearchRepository(
    this.rendererRepository,
    this.fileService,
    this.searchService,
  );

  Future<void> loadModel() async {
    final verses = rendererRepository.verses;
    final indices = rendererRepository.indices;
    final embeddings = await fileService.readAsBytes("embeddings.npy");
    final model = await fileService.readAsBytes("all-minilm-l6-v2.onnx");
    final tokenizer = await fileService.readAsBytes("tokenizer/tokenizer.json");
    searchService.loadModel(indices, embeddings, verses, model, tokenizer);
  }

  Future<String> getResult(String s) {
    return searchService.getResult(s);
  }
}
