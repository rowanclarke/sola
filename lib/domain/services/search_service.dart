import 'dart:typed_data';

import 'package:sola/domain/services/search_isolate.dart';

class SearchService {
  Future<SearchIsolate> createSearchIsolate({
    required String bookId,
    required Uint8List indicesBytes,
    required Uint8List embeddings,
    required Uint8List verses,
    required Uint8List model,
    required Uint8List tokenizer,
  }) {
    return SearchIsolate.spawn(
      bookId: bookId,
      indicesBytes: indicesBytes,
      embeddings: embeddings,
      verses: verses,
      model: model,
      tokenizer: tokenizer,
    );
  }
}
