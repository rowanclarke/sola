import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/domain/services/file_service.dart';

class LibraryRepository {
  static const _apiUrl = 'https://translations.sola-9ee.workers.dev/api/translations';
  static const _cacheFile = 'translations_cache.json';

  final FileService _fileService;
  List<Translation>? _availableTranslationsCache;
  List<Translation>? _downloadedTranslationsCache;

  LibraryRepository({required FileService fileService})
    : _fileService = fileService;

  Future<List<Translation>> getAvailableTranslations() async {
    if (_availableTranslationsCache != null) return _availableTranslationsCache!;

    List<dynamic>? data;

    // Try fetching from API
    try {
      debugPrint('[LibraryRepo] Fetching translations from API...');
      final dio = Dio();
      final response = await dio.get<List<dynamic>>(_apiUrl);
      data = response.data;
      if (data != null) {
        // Cache to disk
        await _fileService.writeFile(_cacheFile, json.encode(data));
        debugPrint('[LibraryRepo] Cached ${data.length} translations to disk');
      }
    } catch (e) {
      debugPrint('[LibraryRepo] API fetch failed: $e');
    }

    // Fall back to disk cache
    if (data == null) {
      try {
        debugPrint('[LibraryRepo] Loading translations from disk cache...');
        final cached = await _fileService.readFile(_cacheFile);
        data = json.decode(cached) as List<dynamic>;
        debugPrint('[LibraryRepo] Loaded ${data.length} translations from cache');
      } catch (e) {
        debugPrint('[LibraryRepo] No disk cache available: $e');
        data = [];
      }
    }

    final list = data
        .map((e) => Translation.fromJson(e as Map<String, dynamic>))
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
    String translationId, {
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    final url = Translation.downloadUrl(translationId);
    debugPrint('[LibraryRepo] Downloading $translationId from $url');
    await _fileService.extractRemote(
      url,
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
