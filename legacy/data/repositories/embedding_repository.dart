import 'package:sola/data/services/file_service.dart';
import 'package:sola/domain/models/embedding_model_metadata.dart';

class EmbeddingRepository {
  final FileService fileService;

  EmbeddingRepository(this.fileService);

  Future<List<EmbeddingModelMetadata>> getAvailableModels() async {
    // TODO: Implement fetching available models from asset or remote API
    // For now, return empty list
    return [];
  }

  Future<Map<String, String>> downloadModel(String modelId) async {
    // TODO: Implement model downloading and extraction
    // Returns map of file paths: {'embeddings': '...', 'model': '...', 'tokenizer': '...'}
    return {};
  }

  Future<List<EmbeddingModelMetadata>> getDownloadedModels() async {
    // TODO: Implement fetching list of downloaded models
    return [];
  }

  Future<void> saveModelPath(String modelId, String path) async {
    // TODO: Persist downloaded model path to storage
  }

  Future<String?> getModelPath(String modelId) async {
    // TODO: Retrieve path of downloaded model
    return null;
  }
}
