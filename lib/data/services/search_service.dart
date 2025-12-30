import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

import 'dart:ffi';

import '../../domain/models/index_model.dart';
import '../../domain/models/verse_data_model.dart';
import 'file_service.dart';

class SearchService {
  late Pointer<Void> model;
  late Pointer<Void> indices;
  final FileService fileService;

  SearchService(this.fileService);

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

  Future<void> loadModelFromPaths(Map<String, String> paths) async {
    // Load all model files from paths
    final embeddings = await fileService.readAsBytes(paths['embeddings'] ?? '');
    final verses = await fileService.readAsBytes(paths['verses'] ?? '');
    final modelData = await fileService.readAsBytes(paths['model'] ?? '');
    final tokenizer = await fileService.readAsBytes(paths['tokenizer'] ?? '');

    // Create a dummy indices pointer (would normally come from renderer)
    // For now, we assume indices are managed separately
    model = rust.loadModel(embeddings, verses, modelData, tokenizer);
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

  Future<List<IndexModel>> searchAcrossTranslation(
    String query,
    String translationId,
  ) async {
    // TODO: Implement cross-translation search
    // Should query embeddings stored for the translation and return all relevant verses
    return [];
  }

  Future<void> embedVerses(List<VerseData> verses) async {
    // TODO: Implement verse embedding
    // For each verse, generate embedding and store via SearchRepository
  }

  Uint8List getVerses(Pointer<Void> painter) {
    return rust.serializeVerses(painter);
  }

  Uint8List getIndices(Pointer<Void> painter) {
    return rust.serializeIndices(painter);
  }
}
