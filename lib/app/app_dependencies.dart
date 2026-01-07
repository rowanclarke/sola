/// Dependency declarations and factory methods for the Sola application.
///
/// This file provides a centralized location for declaring all application dependencies,
/// organized by layer (domain services, data repositories, presentation viewmodels).
/// The actual instantiation is handled by [AppBootstrap].

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/session/session_state.dart';
import '../data/repositories/bible_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/renderer_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/services/bible_service.dart';
import '../domain/services/file_service.dart';
import '../domain/services/renderer_service.dart';
import '../domain/services/search_service.dart';
import '../presentation/viewmodels/library_viewmodel.dart';
import '../presentation/viewmodels/reader_viewmodel.dart';
import '../presentation/viewmodels/rendering_viewmodel.dart';
import '../presentation/viewmodels/search_viewmodel.dart';
import '../presentation/viewmodels/session_viewmodel.dart';

/// Dependency declarations for domain services.
///
/// Domain services contain business logic and are independent of Flutter/UI.
/// They are instantiated once per application lifetime.
abstract class DomainServiceDependencies {
  /// Low-level file I/O operations.
  static FileService createFileService() => throw UnimplementedError();

  /// USFM parsing and serialization.
  static BibleService createBibleService(FileService fileService) =>
      throw UnimplementedError();

  /// Page rendering and verse indexing.
  static RendererService createRendererService(FileService fileService) =>
      throw UnimplementedError();

  /// Embedding generation and semantic search.
  static SearchService createSearchService(FileService fileService) =>
      throw UnimplementedError();
}

/// Dependency declarations for data repositories.
///
/// Repositories handle data access with caching and persistence.
/// They depend on domain services and are instantiated once per application lifetime.
abstract class DataRepositoryDependencies {
  /// Single source of truth for cross-screen session state.
  /// Must be created first as other repositories may depend on it.
  static SessionRepository createSessionRepository(FileService fileService) =>
      throw UnimplementedError();

  /// Translation library metadata caching.
  static LibraryRepository createLibraryRepository(
    FileService fileService,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Serialized book data caching.
  static BibleRepository createBibleRepository(
    BibleService bibleService,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Rendered pages and verse indexes caching.
  static RendererRepository createRendererRepository(
    RendererService rendererService,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Embeddings and search results caching.
  static SearchRepository createSearchRepository(
    SearchService searchService,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();
}

/// Dependency declarations for presentation viewmodels.
///
/// ViewModels manage UI state and are instantiated once per application lifetime.
/// They depend on repositories and notify listeners of state changes.
abstract class PresentationViewModelDependencies {
  /// Observes global session state changes (translation, book, page, search).
  /// Automatically notifies UI when SessionRepository state changes.
  static SessionViewModel createSessionViewModel(
    SessionRepository sessionRepository,
    SessionState sessionState,
  ) => throw UnimplementedError();

  /// Manages translation library UI state (loaded translations, selected, loading).
  /// Responds to user actions like opening/downloading translations.
  static LibraryViewModel createLibraryViewModel(
    LibraryRepository libraryRepository,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Manages rendering configuration and progress state.
  /// Responds to user configuration changes and preview requests.
  static RenderingViewModel createRenderingViewModel(
    RendererRepository rendererRepository,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Manages reader UI state (current page, page count, navigation).
  /// Responds to page navigation and gesture events.
  static ReaderViewModel createReaderViewModel(
    RendererRepository rendererRepository,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();

  /// Manages search UI state (query, results, selected verse).
  /// Responds to search input and result selection.
  static SearchViewModel createSearchViewModel(
    SearchRepository searchRepository,
    SessionRepository sessionRepository,
  ) => throw UnimplementedError();
}

/// Builds a list of [ChangeNotifierProvider] for all application viewmodels.
///
/// This is used by the root [MultiProvider] to make all viewmodels available
/// to the widget tree via Provider.of<T>() or Consumer<T>().
///
/// **Important:** All repositories and services must be created before calling this,
/// as they are required to instantiate the viewmodels.
///
/// Example:
/// ```dart
/// final fileService = DomainServiceDependencies.createFileService();
/// final bibleService = DomainServiceDependencies.createBibleService(fileService);
/// // ... create all other services and repositories ...
///
/// final providers = PresentationViewModelDependencies.buildProviders(
///   sessionViewModel: sessionVM,
///   libraryViewModel: libraryVM,
///   renderingViewModel: renderingVM,
///   readerViewModel: readerVM,
///   searchViewModel: searchVM,
/// );
///
/// return MultiProvider(
///   providers: providers,
///   child: const SolaApp(),
/// );
/// ```
abstract class ProviderBuilder {
  static List<ChangeNotifierProvider> buildProviders({
    required SessionViewModel sessionViewModel,
    required LibraryViewModel libraryViewModel,
    required RenderingViewModel renderingViewModel,
    required ReaderViewModel readerViewModel,
    required SearchViewModel searchViewModel,
  }) => throw UnimplementedError();
}
