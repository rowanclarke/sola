import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/model_info.dart';
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchRepository _searchRepository;
  final SessionRepository _sessionRepository;

  double dragOffset = 0.0;
  rust.Index? _lastResult;
  String? _error;
  bool _isModelLoading = false;
  bool _isModelReady = false;
  String? _loadedTranslationId;

  static const double startDescent = -50.0;
  static const double triggerThreshold = 125.0;
  static const double maxDescent = 150.0;

  SearchViewModel({
    required SearchRepository searchRepository,
    required SessionRepository sessionRepository,
  }) : _searchRepository = searchRepository,
       _sessionRepository = sessionRepository;

  rust.Index? get lastResult => _lastResult;
  String? get error => _error;
  bool get isModelLoading => _isModelLoading;
  bool get isModelReady => _isModelReady;

  void handleDragUpdate(double deltaY) {
    dragOffset = (dragOffset + deltaY).clamp(0, maxDescent);
    notifyListeners();
  }

  bool handleDragEnd() {
    final triggered = dragOffset >= triggerThreshold;
    dragOffset = 0;
    notifyListeners();
    return triggered;
  }

  Future<void> loadModel() async {
    if (_isModelLoading) return;

    final currentTranslationId =
        _sessionRepository.currentSession.currentTranslationId;

    // Skip if already loaded for this exact translation
    if (_isModelReady && _loadedTranslationId == currentTranslationId) {
      debugPrint('[SearchVM] Model already loaded for $currentTranslationId');
      return;
    }

    // Reset stale state from previous translation
    if (_isModelReady) {
      debugPrint('[SearchVM] Translation changed '
          '($_loadedTranslationId → $currentTranslationId), reloading model');
    }
    _isModelReady = false;
    _isModelLoading = true;
    _lastResult = null;
    _error = null;
    debugPrint('[SearchVM] Loading search model for $currentTranslationId...');
    notifyListeners();

    try {
      await _searchRepository.loadModel(ModelInfo.defaultModel);
      _isModelReady = true;
      _loadedTranslationId = currentTranslationId;
      debugPrint('[SearchVM] Model loaded for $currentTranslationId');
    } catch (e) {
      debugPrint('[SearchVM] Model load error: $e');
      _error = 'Failed to load search model: $e';
      _loadedTranslationId = null;
    } finally {
      _isModelLoading = false;
      notifyListeners();
    }
  }

  Future<rust.Index?> getResult(String query) async {
    if (query.isEmpty) return null;
    if (!_isModelReady) {
      debugPrint('[SearchVM] Search attempted but model not ready');
      _error = _isModelLoading
          ? 'Search model is still loading. Please try again shortly.'
          : 'Search model failed to load.';
      notifyListeners();
      return null;
    }
    debugPrint('[SearchVM] Searching: "$query"');
    _error = null;
    try {
      _lastResult = await _searchRepository.getResult(query);
      debugPrint('[SearchVM] Result: book=${_lastResult?.book} '
          'ch=${_lastResult?.chapter}:${_lastResult?.verse} page=${_lastResult?.page}');
    } catch (e) {
      debugPrint('[SearchVM] Search error: $e');
      _error = e.toString();
      _lastResult = null;
    }
    notifyListeners();
    return _lastResult;
  }

}
