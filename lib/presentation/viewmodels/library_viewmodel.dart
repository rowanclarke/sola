import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// LibraryViewModel manages the state of available and downloaded translations.
/// Provides UI-facing functionality for browsing, downloading, and selecting translations.
class LibraryViewModel extends ChangeNotifier {
  final LibraryRepository _libraryRepository;
  final SessionRepository _sessionRepository;

  List<Translation> _availableTranslations = [];
  List<Translation> _downloadedTranslations = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _downloadingTranslationId;

  LibraryViewModel({
    required LibraryRepository libraryRepository,
    required SessionRepository sessionRepository,
  }) : _libraryRepository = libraryRepository,
       _sessionRepository = sessionRepository;

  /// Returns the list of available translations ready for download.
  List<Translation> get availableTranslations => _availableTranslations;

  /// Returns the list of already downloaded translations.
  List<Translation> get downloadedTranslations => _downloadedTranslations;

  /// Returns true if the view is loading translation lists.
  bool get isLoading => _isLoading;

  /// Returns true if a download is currently in progress.
  bool get isDownloading => _isDownloading;

  /// Returns the ID of the translation currently being downloaded, or null.
  String? get downloadingTranslationId => _downloadingTranslationId;

  /// Fetches and loads the lists of available and downloaded translations.
  /// Updates the state and notifies listeners when complete.
  Future<void> loadTranslations() {
    throw UnimplementedError();
  }

  /// Downloads a translation by its ID.
  /// Updates download progress state and notifies listeners.
  Future<void> downloadTranslation(Translation translation) {
    throw UnimplementedError();
  }

  /// Opens a translation, setting it as the current active translation.
  /// Updates the global session and navigates to the rendering screen.
  Future<void> openTranslation(Translation translation) {
    throw UnimplementedError();
  }

  /// Refreshes the translation lists, clearing any cached data.
  Future<void> refresh() {
    throw UnimplementedError();
  }
}
