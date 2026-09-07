import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// What the reader's switcher offers and what merely sits on disk.
///
/// Downloaded translations split in two: the ordered set the switcher lists,
/// held in the session, and everything else. Membership and order are the only
/// state here — the translations themselves come from [LibraryRepository].
class TranslationsViewModel extends ChangeNotifier {
  final LibraryRepository _libraryRepository;
  final SessionRepository _sessionRepository;

  List<Translation> _downloaded = [];
  bool _isLoading = false;

  TranslationsViewModel({
    required LibraryRepository libraryRepository,
    required SessionRepository sessionRepository,
  }) : _libraryRepository = libraryRepository,
       _sessionRepository = sessionRepository;

  bool get isLoading => _isLoading;

  String? get currentId =>
      _sessionRepository.currentSession.currentTranslationId;

  Translation? get current => _byId(currentId);

  /// The switcher's translations, in the order it lists them.
  List<Translation> get switcherTranslations => [
    for (final id in _sessionRepository.currentSession.switcherTranslationIds)
      if (_byId(id) case final translation?) translation,
  ];

  /// Downloaded but kept out of the switcher.
  List<Translation> get poolTranslations {
    final inSwitcher =
        _sessionRepository.currentSession.switcherTranslationIds.toSet();
    return [
      for (final t in _downloaded)
        if (!inSwitcher.contains(t.id)) t,
    ];
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _downloaded = await _libraryRepository.getDownloadedTranslations();
      await _reconcile();
    } catch (e) {
      debugPrint('[TranslationsVM] Failed to load translations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Republishes the session-derived getters after someone else changed the
  /// session — the reader switching translation, for instance.
  void refresh() => notifyListeners();

  /// Forgets the cached download list so the next [load] goes back to disk.
  void invalidate() {
    _libraryRepository.invalidateCache();
    _downloaded = [];
  }

  Future<void> addToSwitcher(String translationId) async {
    final ids = _ids();
    if (ids.contains(translationId)) return;
    ids.add(translationId);
    await _persist(ids);
  }

  /// Whether [translationId] can leave the switcher: the translation being read
  /// has to stay reachable, and the list cannot empty out.
  bool canRemoveFromSwitcher(String translationId) =>
      translationId != currentId && _ids().length > 1;

  Future<void> removeFromSwitcher(String translationId) async {
    if (!canRemoveFromSwitcher(translationId)) {
      debugPrint('[TranslationsVM] Refusing to remove $translationId');
      return;
    }
    final ids = _ids()..remove(translationId);
    await _persist(ids);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final ids = _ids();
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    // ReorderableListView reports the drop point in the list as it was before
    // the row was lifted out of it.
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    await _persist(ids);
  }

  /// Drops ids whose download has gone and makes sure the translation being
  /// read is listed. Only writes when something actually moved.
  Future<void> _reconcile() async {
    final downloadedIds = {for (final t in _downloaded) t.id};
    final ids = _ids()..removeWhere((id) => !downloadedIds.contains(id));

    final currentTranslationId = currentId;
    if (currentTranslationId != null &&
        downloadedIds.contains(currentTranslationId) &&
        !ids.contains(currentTranslationId)) {
      ids.insert(0, currentTranslationId);
    }

    if (!listEquals(ids, _sessionRepository.currentSession.switcherTranslationIds)) {
      await _sessionRepository.setSwitcherTranslations(ids);
    }
  }

  List<String> _ids() =>
      [..._sessionRepository.currentSession.switcherTranslationIds];

  Future<void> _persist(List<String> ids) async {
    await _sessionRepository.setSwitcherTranslations(ids);
    notifyListeners();
  }

  Translation? _byId(String? id) {
    if (id == null) return null;
    for (final t in _downloaded) {
      if (t.id == id) return t;
    }
    return null;
  }
}
