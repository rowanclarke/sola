import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

import 'dart:ffi';

class SearchService {
  late Pointer<Void> package;

  void loadModel(
    Uint8List embeddings,
    String lines,
    Uint8List model,
    Uint8List tokenizer,
  ) {
    package = rust.loadModel(embeddings, lines, model, tokenizer);
  }

  Future<String> getResult(String s) async {
    return rust.getResult(package, s);
  }
}
