import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/core/models/search_info.dart';
import 'package:sola/core/models/search_result.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/model_service.dart';
import 'package:sola/domain/services/search_isolate.dart';

/// Two-tier search over a rendered translation.
///
/// [lookupReference] answers "Gen 12", "1 John 3:16" and every prefix of them
/// from a compact in-memory index — synchronously, on the calling isolate, so
/// it can run on every keystroke. [search] is the semantic fallback, which
/// loads an embedding model and runs off-isolate.
class SearchRepository {
  final FileService _fileService;
  final ModelService _modelService;

  SearchIsolate? _isolate;
  rust.ReferenceIndex? _references;

  SearchRepository({
    required FileService fileService,
    required ModelService modelService,
  }) : _fileService = fileService,
       _modelService = modelService;

  bool get isReady => _isolate != null;

  Future<void> init({
    required ModelInfo model,
    required SearchInfo searchInfo,
    required String translationId,
    required List<String> bookIds,
    required double width,
    required double height,
  }) async {
    debugPrint('[SearchRepo] Initializing search...');

    // Reference search comes straight out of the rendered output, so bring it
    // up first — it is ready while the model is still downloading.
    final indicesBytesList = <Uint8List>[];
    for (final bookId in bookIds) {
      final dir = 'rendered/$translationId/$bookId-${width.toInt()}-${height.toInt()}';
      try {
        indicesBytesList.add(await _fileService.readBytes('$dir/indices'));
      } catch (e) {
        debugPrint('[SearchRepo] Skipping indices for $bookId: $e');
      }
    }
    _references = rust.ReferenceIndex.build(indicesBytesList);
    debugPrint('[SearchRepo] Reference index ready (${indicesBytesList.length} books)');

    await _modelService.ensureAvailable(model);

    final searchDir = 'search/${searchInfo.translationId}';
    await _fileService.extractRemote(searchInfo.downloadUrl, searchDir);

    final modelPath = _modelService.getPath(model.id);
    final modelBytes = await _fileService.readBytes('$modelPath/all-minilm-l6-v2.onnx');
    final tokenizerBytes = await _fileService.readBytes('$modelPath/tokenizer/tokenizer.json');

    final idxBytes = await _fileService.readBytes('$searchDir/${searchInfo.translationId}.idx');

    final hnswDir = _fileService.resolve(searchDir);

    _isolate = await SearchIsolate.spawn(
      modelBytes: modelBytes,
      tokenizerBytes: tokenizerBytes,
      hnswDir: hnswDir,
      hnswBasename: searchInfo.translationId,
      idxBytes: idxBytes,
      indicesBytesList: indicesBytesList,
    );
    debugPrint('[SearchRepo] Search ready');
  }

  /// Reference matches for [query], best first, or empty when it names no book.
  List<Index> lookupReference(String query, {int limit = 5}) {
    final references = _references;
    if (references == null) return const [];
    return [
      for (final hit in references.lookup(query, limit: limit))
        Index(hit.page, hit.book, hit.header, hit.chapter, hit.verse),
    ];
  }

  Future<List<SearchResult>> search(String query) => _isolate!.search(query);

  void dispose() {
    _isolate?.dispose();
    _isolate = null;
    _references?.dispose();
    _references = null;
  }
}
