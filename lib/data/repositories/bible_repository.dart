import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sola/domain/services/file_service.dart';
import 'package:sola/domain/services/render_isolate.dart';

class BibleRepository {
  final FileService _fileService;
  final Map<String, Uint8List> _serializationCache = {};

  BibleRepository({
    required FileService fileService,
  }) : _fileService = fileService;

  Future<Uint8List> getSerializedBook({
    required String translationId,
    required String bookId,
  }) async {
    final key = '$translationId/$bookId';
    if (_serializationCache.containsKey(key)) {
      debugPrint('[BibleRepo] Serialization cache hit: $key');
      return _serializationCache[key]!;
    }
    debugPrint('[BibleRepo] Reading serialized book from disk: $key');
    final bytes = await _fileService.readBytes(_getSerializedBookPath(translationId, bookId));
    _serializationCache[key] = bytes;
    return bytes;
  }

  Future<Map<String, Uint8List>> getSerializedBooks({
    required String translationId,
  }) async {
    final books = <String, Uint8List>{};
    for (final bookId in await _fileService.listDirectory(
      'serialized/$translationId',
    )) {
      books[bookId] = await getSerializedBook(
        translationId: translationId,
        bookId: bookId,
      );
    }
    return books;
  }

  Future<void> saveSerializedBook({
    required String translationId,
    required String bookId,
    required Uint8List data,
  }) async {
    final key = '$translationId/$bookId';
    _serializationCache[key] = data;
    await _fileService.writeBytes(_getSerializedBookPath(translationId, bookId), data);
  }

  Future<void> serializeTranslation(String translationId) async {
    final files = await _fileService.listDirectory('library/$translationId');
    final usfmFiles = files.where((f) => f.endsWith('.usfm')).toList();

    // Check if already serialized (all books cached or on disk)
    if (usfmFiles.isEmpty) return;

    debugPrint('[BibleRepo] Serializing ${usfmFiles.length} USFM files for $translationId');

    // Read all USFM files on main isolate (async I/O)
    final usfmContents = <String, String>{};
    for (final file in usfmFiles) {
      final content = await _fileService.readFile('library/$translationId/$file');
      usfmContents[file] = content;
    }

    // Run Rust serialization on background isolate
    final output = await compute(serializeInBackground, SerializeInput(
      usfmFiles: usfmContents,
    ));

    // Save results on main isolate (async I/O)
    for (final entry in output.serializedBooks.entries) {
      await saveSerializedBook(
        translationId: translationId,
        bookId: entry.key,
        data: entry.value,
      );
    }
    debugPrint('[BibleRepo] Serialization complete: ${output.serializedBooks.length} books');
  }

  void invalidateCache() {
    debugPrint('[BibleRepo] Cache invalidated');
    _serializationCache.clear();
  }

  String _getSerializedBookPath(String translationId, String bookId) {
    return 'serialized/$translationId/$bookId';
  }
}
