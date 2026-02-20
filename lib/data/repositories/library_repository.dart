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
    final data = await _fileService.deserializeAsset('assets/translations.json');
    final list = (data as List)
        .map((e) => Translation.fromJson(e as Map<String, dynamic>))
        .where((t) => t.downloadable)
        .toList();
    _availableTranslationsCache = list;
    return list;
  }

  Future<List<Translation>> getDownloadedTranslations() async {
    if (_downloadedTranslationsCache != null) return _downloadedTranslationsCache!;
    final available = await getAvailableTranslations();
    final dirs = await _fileService.listDirectory('library');
    final dirSet = dirs.toSet();
    final list = available.where((t) => dirSet.contains(t.id)).toList();
    _downloadedTranslationsCache = list;
    return list;
  }

  Future<void> downloadTranslation(String translationId, String downloadUrl) async {
    await _fileService.extractRemote(downloadUrl, 'library/$translationId');
    _downloadedTranslationsCache = null;
  }

  void invalidateCache() {
    _availableTranslationsCache = null;
    _downloadedTranslationsCache = null;
  }
}
