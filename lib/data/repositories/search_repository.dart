import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/core/models/search_info.dart';
import 'package:sola/core/models/search_result.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/model_service.dart';
import 'package:sola/domain/services/search_isolate.dart';

class SearchRepository {
  final FileService _fileService;
  final ModelService _modelService;

  SearchIsolate? _isolate;

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

    await _modelService.ensureAvailable(model);

    final searchDir = 'search/${searchInfo.translationId}';
    await _fileService.extractRemote(searchInfo.downloadUrl, searchDir);

    final modelPath = _modelService.getPath(model.id);
    final modelBytes = await _fileService.readBytes('$modelPath/all-minilm-l6-v2.onnx');
    final tokenizerBytes = await _fileService.readBytes('$modelPath/tokenizer/tokenizer.json');

    final idxBytes = await _fileService.readBytes('$searchDir/${searchInfo.translationId}.idx');

    final pageMapBytesList = <Uint8List>[];
    for (final bookId in bookIds) {
      final dir = 'rendered/$translationId/$bookId-${width.toInt()}-${height.toInt()}';
      try {
        pageMapBytesList.add(await _fileService.readBytes('$dir/indices'));
      } catch (e) {
        debugPrint('[SearchRepo] Skipping page map for $bookId: $e');
      }
    }

    final hnswDir = _fileService.resolve(searchDir);

    _isolate = await SearchIsolate.spawn(
      modelBytes: modelBytes,
      tokenizerBytes: tokenizerBytes,
      hnswDir: hnswDir,
      hnswBasename: searchInfo.translationId,
      idxBytes: idxBytes,
      pageMapBytesList: pageMapBytesList,
    );
    debugPrint('[SearchRepo] Search ready');
  }

  Future<List<SearchResult>> search(String query) => _isolate!.search(query);

  Future<List<Index>> searchIndex(String query) => _isolate!.searchIndex(query);

  void dispose() {
    _isolate?.dispose();
    _isolate = null;
  }
}
