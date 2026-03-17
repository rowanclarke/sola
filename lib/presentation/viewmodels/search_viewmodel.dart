import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/embeddings_info.dart';
import 'package:sola/core/models/search_result.dart';
import 'package:sola/core/models/model_info.dart';
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchRepository _searchRepository;
  final SessionRepository _sessionRepository;

  double dragOffset = 0.0;
  List<SearchResult> _results = [];
  String? _error;
  bool _isModelLoading = false;
  bool _isModelReady = false;
  String? _loadedTranslationId;

  // Debounced search state
  Timer? _debounceTimer;
  bool _isSearching = false;
  int _queryVersion = 0;

  static const double startDescent = -50.0;
  static const double triggerThreshold = 125.0;
  static const double maxDescent = 150.0;
  static const _debounceDuration = Duration(milliseconds: 400);

  SearchViewModel({
    required SearchRepository searchRepository,
    required SessionRepository sessionRepository,
  }) : _searchRepository = searchRepository,
       _sessionRepository = sessionRepository;

  List<SearchResult> get results => _results;
  String? get error => _error;
  bool get isModelLoading => _isModelLoading;
  bool get isModelReady => _isModelReady;
  bool get isSearching => _isSearching;

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

  Future<void> loadModel({
    required List<String> bookIds,
    required double width,
    required double height,
  }) async {
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
      debugPrint(
        '[SearchVM] Translation changed '
        '($_loadedTranslationId → $currentTranslationId), reloading model',
      );
      _searchRepository.dispose();
    }
    _isModelReady = false;
    _isModelLoading = true;
    _results = [];
    _error = null;
    debugPrint('[SearchVM] Loading search model for $currentTranslationId...');
    notifyListeners();

    try {
      await _searchRepository.loadModel(
        model: ModelInfo.defaultModel,
        embeddingsInfo: EmbeddingsInfo.defaultEmbeddings,
        translationId: currentTranslationId!,
        bookIds: bookIds,
        width: width,
        height: height,
      );
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

  void clearSearch() {
    _queryVersion++;
    _results = [];
    _error = null;
    _isSearching = false;
    notifyListeners();
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      clearSearch();
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!_isModelReady) {
      debugPrint('[SearchVM] Search attempted but model not ready');
      _error = _isModelLoading
          ? 'Search model is still loading. Please try again shortly.'
          : 'Search model failed to load.';
      notifyListeners();
      return;
    }

    _results = [];
    final version = ++_queryVersion;
    _isSearching = true;
    _error = null;
    notifyListeners();

    debugPrint('[SearchVM] Searching: "$query"');
    try {
      final indexResults = await _searchRepository.searchIndex(query);
      if (indexResults.isNotEmpty) {
        _results.addAll(
          indexResults.map(
            (idx) => SearchResult(index: idx, distance: 0.0),
          ),
        );
      } else {
        final semanticResults = await _searchRepository.getResult(query);
        if (version != _queryVersion) {
          debugPrint('[SearchVM] Stale result for "$query", ignoring');
          return;
        }
        _results.addAll(semanticResults);
      }
      if (_results.isNotEmpty) {
        final first = _results[0].index;
        debugPrint(
          '[SearchVM] ${_results.length} results, first: book=${first.book} '
          'ch=${first.chapter}:${first.verse} page=${first.page}',
        );
      }
    } catch (e) {
      if (version != _queryVersion) return;
      debugPrint('[SearchVM] Search error: $e');
      _error = e.toString();
      _results = [];
    } finally {
      if (version == _queryVersion) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
