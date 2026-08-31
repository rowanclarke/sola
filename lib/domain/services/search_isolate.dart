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
  final List<Uint8List> indicesBytesList;
  final SendPort replyPort;

  _InitMessage({
    required this.modelBytes,
    required this.tokenizerBytes,
    required this.hnswDir,
    required this.hnswBasename,
    required this.idxBytes,
    required this.indicesBytesList,
    required this.replyPort,
  });
}

class _SearchMessage {
  final String query;
  final SendPort replyPort;

  _SearchMessage(this.query, this.replyPort);
}

class _IsolateError {
  final String message;

  _IsolateError(this.message);
}

/// Runs semantic (embedding) search off the UI isolate.
///
/// Reference lookups deliberately do not go through here — they are fast enough
/// to run inline, and routing them through this isolate would queue them behind
/// a model inference that can take hundreds of milliseconds.
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
    required List<Uint8List> indicesBytesList,
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
        indicesBytesList: indicesBytesList,
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
    rust.ReferenceIndex? references;

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

          // Its own copy, rather than a pointer shared with the main isolate:
          // ~200 KB and a few ms to keep the two isolates from touching the
          // same native memory.
          print(
            '[SearchIsolate] Building reference index from '
            '${message.indicesBytesList.length} books...',
          );
          references = rust.ReferenceIndex.build(message.indicesBytesList);
          print('[SearchIsolate] Reference index built');

          message.replyPort.send(true);
        } catch (e) {
          print('[SearchIsolate] Init error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      } else if (message is _SearchMessage) {
        try {
          print('[SearchIsolate] Query: "${message.query}"');
          final (:ids, :distances) = rust.search(engine!, message.query, 10, 50);
          print('[SearchIsolate] ${ids.length} results');
          final results = List.generate(ids.length, (i) {
            final index = rust.getSearchResult(
              engine!,
              references!.handle,
              ids[i],
            );
            return SearchResult(index: _toIndex(index), distance: distances[i]);
          });
          message.replyPort.send(results);
        } catch (e) {
          print('[SearchIsolate] Query error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      }
    });
  }
}
