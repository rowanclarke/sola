import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

import 'dart:ffi';

import '../../domain/models/index_model.dart';

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

  Future<IndexModel> getResult(String s) async {
    final result = rust.getResult(model, s);
    final index = rust.getIndex(indices, result);
    return IndexModel(
      page: index.page,
      book: index.book,
      chapter: index.chapter,
      verse: index.verse,
    );
  }

  Uint8List getVerses(Pointer<Void> painter) {
    return rust.serializeVerses(painter);
  }

  Uint8List getIndices(Pointer<Void> painter) {
    return rust.serializeIndices(painter);
  }
}
