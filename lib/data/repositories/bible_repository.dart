import 'dart:typed_data';

import 'package:sola/domain/services/bible_service.dart';
import 'package:sola/domain/services/file_service.dart';

class BibleRepository {
  final FileService _fileService;
  final BibleService _bibleService;
  final Map<String, Uint8List> _serializationCache = {};

  BibleRepository({
    required FileService fileService,
    required BibleService bibleService,
  }) : _fileService = fileService,
       _bibleService = bibleService;

  Future<Uint8List> getSerializedBook({
    required String translationId,
    required String bookId,
  }) async {
    final key = '$translationId/$bookId';
    if (_serializationCache.containsKey(key)) return _serializationCache[key]!;
    final bytes = await _fileService.readBytes(_getSerializedBookPath(translationId, bookId));
    _serializationCache[key] = bytes;
    return bytes;
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
    for (final file in usfmFiles) {
      final usfm = await _fileService.readFile('library/$translationId/$file');
      final bytes = _bibleService.serializeUsfm(usfm);
      final archived = _bibleService.getArchivedBook(bytes);
      final bookId = _bibleService.getBookIdentifier(archived);
      await saveSerializedBook(
        translationId: translationId,
        bookId: bookId,
        data: bytes,
      );
    }
  }

  void invalidateCache() {
    _serializationCache.clear();
  }

  String _getSerializedBookPath(String translationId, String bookId) {
    return 'serialized/$translationId/$bookId';
  }
}
