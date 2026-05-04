import 'package:flutter/foundation.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/domain/services/file_service.dart';

class ModelService {
  final FileService _fileService;

  ModelService({required FileService fileService}) : _fileService = fileService;

  /// Downloads and extracts model files if not already cached.
  /// Idempotent: FileService.extractRemote skips if directory exists.
  Future<void> ensureAvailable(ModelInfo model) async {
    final path = 'models/${model.id}';
    debugPrint('[ModelSvc] Ensuring model "${model.id}" is available at $path');
    await _fileService.extractRemote(model.downloadUrl, path);
    debugPrint('[ModelSvc] Model "${model.id}" ready');
  }

  /// Returns the base directory path for a model's files.
  String getPath(String modelId) => 'models/$modelId';

  /// Checks whether model files exist on disk.
  Future<bool> isAvailable(String modelId) async {
    final contents = await _fileService.listDirectory('models/$modelId');
    return contents.isNotEmpty;
  }
}
