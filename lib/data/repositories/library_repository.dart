import 'package:sola/core/models/translation.dart';
import 'package:sola/domain/services/file_service.dart';

/// LibraryRepository manages metadata for available and downloaded translations.
/// Handles retrieval, storage, and synchronization of translation lists.
class LibraryRepository {
  final FileService _fileService;
  List<Translation>? _availableTranslationsCache;
  List<Translation>? _downloadedTranslationsCache;

  static const String _downloadedTranslationsPath =
      'downloaded_translations.json';
  static const String _availableTranslationsPath =
      'available_translations.json';

  LibraryRepository({required FileService fileService})
    : _fileService = fileService;

  /// Retrieves the list of translations available for download.
  /// Returns cached data if available; otherwise, loads from storage or remote.
  Future<List<Translation>> getAvailableTranslations() {
    throw UnimplementedError();
  }

  /// Retrieves the list of translations already downloaded locally.
  Future<List<Translation>> getDownloadedTranslations() {
    throw UnimplementedError();
  }

  /// Downloads a translation from a remote source and stores it locally.
  /// Updates the downloaded translations list upon successful completion.
  Future<void> downloadTranslation(String translationId, String downloadUrl) {
    throw UnimplementedError();
  }

  /// Adds a translation to the list of downloaded translations.
  /// Persists the updated list to storage.
  Future<void> addDownloadedTranslation(Translation translation) {
    throw UnimplementedError();
  }

  /// Clears the in-memory cache to force reloading from storage.
  void invalidateCache() {
    throw UnimplementedError();
  }
}
