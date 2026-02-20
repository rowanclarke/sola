import 'dart:ffi';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

class SearchService {
  Pointer<Void>? _indices;
  Pointer<Void>? _model;

  void loadModel(
    Pointer<Void> indices,
    Uint8List embeddings,
    Uint8List verses,
    Uint8List model,
    Uint8List tokenizer,
  ) {
    _indices = indices;
    _model = rust.loadModel(embeddings, verses, model, tokenizer);
  }

  rust.Index getResult(String query) {
    final resultPtr = rust.getResult(_model!, query);
    return rust.getIndex(_indices!, resultPtr);
  }
}
