import 'dart:typed_data';

import 'package:sola/domain/services/embeddings_isolate.dart';

class EmbeddingsService {
  Future<EmbeddingsIsolate> createEmbeddingsIsolate({
    required Uint8List model,
    required Uint8List tokenizer,
  }) {
    return EmbeddingsIsolate.spawn(model: model, tokenizer: tokenizer);
  }
}
