import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/search_result.dart';

class _InitMessage {
  final Uint8List modelBytes;
  final Uint8List tokenizerBytes;
  final String hnswDir;
  final String hnswBasename;
  final Uint8List idxBytes;
  final List<Uint8List> pageMapBytesList;
  final SendPort replyPort;

  _InitMessage({
    required this.modelBytes,
    required this.tokenizerBytes,
    required this.hnswDir,
    required this.hnswBasename,
    required this.idxBytes,
    required this.pageMapBytesList,
    required this.replyPort,
  });
}

class _SearchMessage {
  final String query;
  final SendPort replyPort;

  _SearchMessage(this.query, this.replyPort);
}

class _TextSearchMessage {
  final String query;
  final SendPort replyPort;

  _TextSearchMessage(this.query, this.replyPort);
}

class _IsolateError {
  final String message;

  _IsolateError(this.message);
}

class SearchIsolate {
  final Isolate _isolate;
  final SendPort _commandPort;

  SearchIsolate._(this._isolate, this._commandPort);

  static Future<SearchIsolate> spawn({
    required Uint8List modelBytes,
    required Uint8List tokenizerBytes,
    required String hnswDir,
    required String hnswBasename,
    required Uint8List idxBytes,
    required List<Uint8List> pageMapBytesList,
  }) async {
    print('[SearchIsolate] Spawning isolate...');
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(_entryPoint, initPort.sendPort);
    final commandPort = await initPort.first as SendPort;

    final replyPort = ReceivePort();
    commandPort.send(
      _InitMessage(
        modelBytes: modelBytes,
        tokenizerBytes: tokenizerBytes,
        hnswDir: hnswDir,
        hnswBasename: hnswBasename,
        idxBytes: idxBytes,
        pageMapBytesList: pageMapBytesList,
        replyPort: replyPort.sendPort,
      ),
    );
    print('[SearchIsolate] Waiting for engine load...');
    final result = await replyPort.first;
    if (result is _IsolateError) throw Exception(result.message);
    print('[SearchIsolate] Ready');

    return SearchIsolate._(isolate, commandPort);
  }

  Future<List<SearchResult>> search(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_SearchMessage(query, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _IsolateError) throw Exception(result.message);
    return (result as List).cast<SearchResult>();
  }

  Future<List<Index>> searchIndex(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_TextSearchMessage(query, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _IsolateError) throw Exception(result.message);
    if (result is List<rust.Index>) return result.map(_toIndex).toList();
    return [];
  }

  void dispose() {
    print('[SearchIsolate] Killing isolate');
    _isolate.kill(priority: Isolate.immediate);
  }

  static Index _toIndex(rust.Index index) {
    return Index(
      index.page,
      index.book,
      index.header,
      index.chapter,
      index.verse,
    );
  }

  static void _entryPoint(SendPort mainPort) {
    final commandPort = ReceivePort();
    mainPort.send(commandPort.sendPort);

    Pointer<Void>? engine;
    Pointer<Void>? pageMap;

    commandPort.listen((message) {
      if (message is _InitMessage) {
        try {
          print('[SearchIsolate] Loading search engine...');
          engine = rust.loadSearchEngine(
            message.modelBytes,
            message.tokenizerBytes,
            message.hnswDir,
            message.hnswBasename,
            message.idxBytes,
          );
          print('[SearchIsolate] Engine loaded');

          print('[SearchIsolate] Building merged page map from ${message.pageMapBytesList.length} books...');
          final builder = rust.pageMapBuilderNew();
          for (final bytes in message.pageMapBytesList) {
            rust.pageMapBuilderAdd(builder, bytes);
          }
          final mergedBytes = rust.pageMapBuilderFinish(builder);
          pageMap = rust.getArchivedIndices(mergedBytes);
          print('[SearchIsolate] Page map built');

          message.replyPort.send(true);
        } catch (e) {
          print('[SearchIsolate] Init error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      } else if (message is _SearchMessage) {
        try {
          print('[SearchIsolate] Query: "${message.query}"');

          // Try text search first
          final textResults = rust.searchIndex(pageMap!, message.query);
          if (textResults.isNotEmpty) {
            print('[SearchIsolate] ${textResults.length} text results');
            final results = textResults.map((ptr) {
              final index = rust.getIndex(pageMap!, ptr);
              return SearchResult(index: _toIndex(index), distance: 0.0);
            }).toList();
            message.replyPort.send(results);
            return;
          }

          // Fall back to HNSW semantic search
          final (:ids, :distances) = rust.search(engine!, message.query, 10, 50);
          print('[SearchIsolate] ${ids.length} HNSW results');
          final results = List.generate(ids.length, (i) {
            final index = rust.getSearchResult(engine!, pageMap!, ids[i]);
            return SearchResult(index: _toIndex(index), distance: distances[i]);
          });
          message.replyPort.send(results);
        } catch (e) {
          print('[SearchIsolate] Query error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      } else if (message is _TextSearchMessage) {
        try {
          print('[SearchIsolate] Index search: "${message.query}"');
          final results = rust.searchIndex(pageMap!, message.query);
          final indexes = results
              .map((result) => rust.getIndex(pageMap!, result))
              .toList();
          message.replyPort.send(indexes);
        } catch (e) {
          print('[SearchIsolate] Index search error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      }
    });
  }
}
