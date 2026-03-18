import 'dart:typed_data';

import 'package:sola/core/models/embeddings_data.dart';
import 'package:sola/core/models/embeddings_info.dart';
import 'package:sola/domain/services/file_service.dart';

class EmbeddingsService {
  final FileService _fileService;

  EmbeddingsService({required FileService fileService})
      : _fileService = fileService;

  Future<void> ensureAvailable(EmbeddingsInfo info) async {
    final path = 'embeddings/${info.translationId}';
    await _fileService.extractRemote(info.downloadUrl, path);
  }

  Future<EmbeddingsData> readEmbeddings({
    required String translationId,
    required String bookId,
  }) async {
    final dir = 'embeddings/$translationId';
    final embeddingsBytes = await _fileService.readBytes('$dir/$bookId.npy');
    final verseRefsBytes = await _fileService.readBytes('$dir/$bookId.idx');
    return EmbeddingsData(
      embeddingsBytes: embeddingsBytes,
      verseRefsBytes: verseRefsBytes,
    );
  }

  Future<Uint8List> readModelBytes(String modelBasePath) {
    return _fileService.readBytes('$modelBasePath/all-minilm-l6-v2.onnx');
  }

  Future<Uint8List> readTokenizerBytes(String modelBasePath) {
    return _fileService.readBytes('$modelBasePath/tokenizer/tokenizer.json');
  }
}
