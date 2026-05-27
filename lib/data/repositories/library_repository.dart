import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/domain/services/file_service.dart';

class LibraryRepository {
  final FileService _fileService;
  List<Translation>? _availableTranslationsCache;
  List<Translation>? _downloadedTranslationsCache;

  LibraryRepository({required FileService fileService})
    : _fileService = fileService;

  Future<List<Translation>> getAvailableTranslations() async {
    if (_availableTranslationsCache != null) return _availableTranslationsCache!;
    debugPrint('[LibraryRepo] Loading available translations from asset...');
    final data = await _fileService.deserializeAsset('assets/translations.json');
    final list = (data as List)
        .map((e) => Translation.fromJson(e as Map<String, dynamic>))
        .where((t) => t.downloadable)
        .toList();
    _availableTranslationsCache = list;
    debugPrint('[LibraryRepo] Found ${list.length} available translations');
    return list;
  }

  Future<List<Translation>> getDownloadedTranslations() async {
    if (_downloadedTranslationsCache != null) return _downloadedTranslationsCache!;
    final available = await getAvailableTranslations();
    final dirs = await _fileService.listDirectory('library');
    final dirSet = dirs.toSet();
    final list = available.where((t) => dirSet.contains(t.id)).toList();
    _downloadedTranslationsCache = list;
    debugPrint('[LibraryRepo] Found ${list.length} downloaded translations');
    return list;
  }

  Future<void> downloadTranslation(
    String translationId,
    String downloadUrl, {
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[LibraryRepo] Downloading $translationId from $downloadUrl');
    await _fileService.extractRemote(
      downloadUrl,
      'library/$translationId',
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    _downloadedTranslationsCache = null;
    debugPrint('[LibraryRepo] Download complete: $translationId');
  }

  void invalidateCache() {
    debugPrint('[LibraryRepo] Cache invalidated');
    _availableTranslationsCache = null;
    _downloadedTranslationsCache = null;
  }
}
