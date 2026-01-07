import 'dart:async';

import 'package:flutter/material.dart';

class AsyncSearchAnchor<T> extends StatefulWidget {
  final SearchController searchController;
  final Future<Iterable<T>> Function(String) searchFunction;
  final Widget Function(T result) builder;

  const AsyncSearchAnchor({
    required this.searchController,
    required this.searchFunction,
    required this.builder,
    super.key,
  });

  @override
  State<AsyncSearchAnchor> createState() => _AsyncSearchAnchorState<T>();
}

class _AsyncSearchAnchorState<T> extends State<AsyncSearchAnchor<T>> {
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  Future<Iterable<T>> _search(String query) async {
    if (query.isEmpty) {
      return <T>[];
    }

    try {
      return await widget.searchFunction(query);
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: widget.searchController,
      builder: (context, controller) => const SizedBox.shrink(),
      suggestionsBuilder:
          (BuildContext context, SearchController controller) async {
            final results = await _debouncedSearch(controller.text);
            if (results == null) {
              return <Widget>[];
            }
            return results.map<Widget>(widget.builder).toList();
          },
    );
  }
}

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  Duration debounceDuration = Duration(milliseconds: 500);

  _DebounceTimer() {
    _timer = Timer(debounceDuration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

// An exception indicating that the timer was canceled.
class _CancelException implements Exception {
  const _CancelException();
}
