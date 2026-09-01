import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/page_index.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/domain/services/renderer_service.dart';

/// One book's rendered pages, read one page at a time.
///
/// Holds the open `pages` file and its offset table — a few KB — and
/// materializes a page only when something asks for it. A page is a few KB of
/// its own, so reading it is done synchronously: that costs less than the frame
/// a placeholder would take, and it keeps one file position in play.
///
/// Pages a live widget is showing are pinned by [retain]; [release] hands them
/// back when Flutter disposes that widget, and they then sit in a small LRU so
/// swiping back is instant. Anything past [idleCapacity] is dropped, which is
/// what keeps a long book from ending up resident in full.
class BookPages {
  /// How many unpinned pages stay materialized. PageView keeps roughly three
  /// children alive, so this is a few swipes of history either way.
  static const int idleCapacity = 8;

  final RandomAccessFile _file;
  final PageIndex _index;
  final RendererService _renderer;

  final Map<int, PageModel> _resident = {};
  final Map<int, int> _pinned = {};
  final Queue<int> _idle = Queue<int>();
  bool _closed = false;

  BookPages._(this._file, this._index, this._renderer);

  /// Opens the `pages` file at [pagesPath] against its already-read offset
  /// table. Only the table is held in memory.
  static Future<BookPages> open({
    required String pagesPath,
    required Uint8List offsets,
    required RendererService renderer,
  }) async {
    final index = PageIndex.parse(offsets);
    final file = await File(pagesPath).open();
    debugPrint('[BookPages] Opened $pagesPath (${index.pageCount} pages)');
    return BookPages._(file, index, renderer);
  }

  int get pageCount => _index.pageCount;

  bool get isClosed => _closed;

  /// The page at [index], read from disk if it is not resident.
  PageModel page(int index) {
    if (_closed) throw StateError('BookPages used after close');
    RangeError.checkValidIndex(index, this, 'index', pageCount);
    final resident = _resident[index];
    if (resident != null) return resident;

    _file.setPositionSync(_index.offsetOf(index));
    final bytes = _file.readSync(_index.lengthOf(index));
    final page = PageModel(_renderer.pageFromBytes(bytes));
    debugPrint(
      '[BookPages] Read page $index (${bytes.length} bytes, '
      '${page.page.length} fragments)',
    );

    _resident[index] = page;
    if (!_pinned.containsKey(index)) _markIdle(index);
    return page;
  }

  /// Pins [index] for as long as a widget is showing it.
  void retain(int index) {
    if (_closed) return;
    _pinned.update(index, (count) => count + 1, ifAbsent: () => 1);
    _idle.remove(index);
  }

  /// Releases the pin a matching [retain] took. The page is not dropped
  /// immediately — it moves to the idle LRU and is dropped once it falls off
  /// the end of it.
  void release(int index) {
    if (_closed) return;
    final count = _pinned[index];
    if (count == null) return;
    if (count > 1) {
      _pinned[index] = count - 1;
      return;
    }
    _pinned.remove(index);
    if (_resident.containsKey(index)) _markIdle(index);
  }

  /// Reads [center] and its neighbours now. Used when opening a book or
  /// jumping to a search result, so the first frame has nothing left to do.
  void warm(int center, {int radius = 1}) {
    final window = _window(center, radius).toList();
    debugPrint('[BookPages] Warming pages $window of $pageCount');
    for (final index in window) {
      page(index);
    }
  }

  /// Same window as [warm], but off the current frame — for the pages a swipe
  /// is about to reach.
  void prefetchAround(int center, {int radius = 1}) {
    for (final index in _window(center, radius)) {
      if (_resident.containsKey(index)) continue;
      Future(() {
        if (_closed || _resident.containsKey(index)) return;
        debugPrint('[BookPages] Prefetching page $index');
        page(index);
      });
    }
  }

  Iterable<int> _window(int center, int radius) sync* {
    if (pageCount == 0) return;
    final first = (center - radius).clamp(0, pageCount - 1);
    final last = (center + radius).clamp(0, pageCount - 1);
    for (var index = first; index <= last; index++) {
      yield index;
    }
  }

  void _markIdle(int index) {
    _idle.remove(index);
    _idle.addLast(index);
    while (_idle.length > idleCapacity) {
      final dropped = _idle.removeFirst();
      _resident.remove(dropped);
      debugPrint('[BookPages] Dropped page $dropped');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _resident.clear();
    _pinned.clear();
    _idle.clear();
    await _file.close();
  }
}
