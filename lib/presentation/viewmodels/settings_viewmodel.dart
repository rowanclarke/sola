import 'package:flutter/foundation.dart';

import '../../data/repositories/bible_repository.dart';
import '../../data/repositories/renderer_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../domain/services/file_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final FileService _fileService;
  final BibleRepository _bibleRepository;
  final RendererRepository _rendererRepository;
  final SearchRepository _searchRepository;

  SettingsViewModel({
    required FileService fileService,
    required BibleRepository bibleRepository,
    required RendererRepository rendererRepository,
    required SearchRepository searchRepository,
  })  : _fileService = fileService,
        _bibleRepository = bibleRepository,
        _rendererRepository = rendererRepository,
        _searchRepository = searchRepository;

  Future<void> clearSerializationCache() async {
    _bibleRepository.invalidateCache();
    await _fileService.deleteDirectory('serialized');
    debugPrint('[Settings] Serialization cache cleared');
  }

  Future<void> clearRenderingCache() async {
    _rendererRepository.invalidateCache();
    await _fileService.deleteDirectory('rendered');
    debugPrint('[Settings] Rendering cache cleared');
  }

  Future<void> clearSearchCache() async {
    _searchRepository.dispose();
    await _fileService.deleteDirectory('search');
    debugPrint('[Settings] Search cache cleared');
  }
}
