/// Use case for opening (switching to) a translation.
///
/// Orchestrates the process of:
/// 1. Checking if translation exists locally (download if not)
/// 2. Setting it as the current translation in SessionRepository
/// 3. Navigating to the appropriate screen
///
/// This is called from LibraryViewModel when user selects a translation.

import '../../core/models/bible_entry.dart';
import '../../core/models/session_model.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/session_repository.dart';

/// Use case for opening a translation.
///
/// Responsibilities:
/// - Verify translation is downloaded (or download it)
/// - Set current translation in SessionRepository
/// - Trigger navigation to reader/rendering config
///
/// Example:
/// ```dart
/// final useCase = OpenTranslation(
///   libraryRepository: libraryRepository,
///   sessionRepository: sessionRepository,
/// );
///
/// await useCase.execute(translationEntry);
/// ```
class OpenTranslation {
  /// Translation library repository.
  final LibraryRepository libraryRepository;

  /// Session state repository.
  final SessionRepository sessionRepository;

  /// Creates the use case.
  OpenTranslation({
    required this.libraryRepository,
    required this.sessionRepository,
  });

  /// Executes the use case.
  ///
  /// Steps:
  /// 1. Verify translation is available locally (download if needed)
  /// 2. Get the first book from the translation
  /// 3. Update SessionRepository with new translation and book
  /// 4. Caller is responsible for navigation
  ///
  /// Throws:
  /// - Exception if translation download fails
  /// - Exception if unable to load first book
  Future<void> execute(BibleEntry translation) async {
    throw UnimplementedError();
  }

  /// Downloads translation if not already downloaded.
  ///
  /// Returns true if download was successful or already downloaded.
  Future<bool> _downloadIfNeeded(BibleEntry translation) async {
    throw UnimplementedError();
  }

  /// Gets the first book of the translation.
  ///
  /// Used to initialize the reader with a sensible default.
  Future<String> _getFirstBook(BibleEntry translation) async {
    throw UnimplementedError();
  }
}
