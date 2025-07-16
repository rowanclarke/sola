import 'package:sola/data/services/file_service.dart';

import '../services/search_service.dart';

class SearchRepository {
  final FileService fileService;
  final SearchService searchService;

  SearchRepository(this.fileService, this.searchService);

  Future<void> loadModel() async {
    final embeddings = await fileService.readAsBytes("embeddings.npy");
    final lines = await fileService.readAsString("plain_GENwebbeb.txt");
    final model = await fileService.readAsBytes("all-minilm-l6-v2.onnx");
    final tokenizer = await fileService.readAsBytes("tokenizer/tokenizer.json");
    searchService.loadModel(embeddings, lines, model, tokenizer);
  }

  Future<String> getResult(String s) {
    return searchService.getResult(s);
  }
}
