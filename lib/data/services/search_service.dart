import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

import 'dart:ffi';

class SearchService {
  late Pointer<Void> model;
  late Pointer<Void> indices;

  void loadModel(
    Pointer<Void> indices,
    Uint8List embeddings,
    Uint8List verses,
    Uint8List model,
    Uint8List tokenizer,
  ) {
    this.indices = indices;
    this.model = rust.loadModel(embeddings, verses, model, tokenizer);
  }

  Future<String> getResult(String s) async {
    final index = rust.getResult(model, s);
    final page = rust.getIndex(indices, index);
    return page.toString();
  }

  Uint8List getVerses(Pointer<Void> painter) {
    return rust.serializeVerses(painter);
  }

  Uint8List getIndices(Pointer<Void> painter) {
    return rust.serializeIndices(painter);
  }
}
