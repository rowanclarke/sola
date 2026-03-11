import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/index.dart';

class _LoadMsg {
  final Uint8List indicesBytes;
  final Uint8List embeddings;
  final Uint8List verses;
  final Uint8List model;
  final Uint8List tokenizer;
  final SendPort replyPort;

  _LoadMsg(
    this.indicesBytes,
    this.embeddings,
    this.verses,
    this.model,
    this.tokenizer,
    this.replyPort,
  );
}

class _QueryMsg {
  final String query;
  final SendPort replyPort;

  _QueryMsg(this.query, this.replyPort);
}

class _IndexMsg {
  final String query;
  final SendPort replyPort;

  _IndexMsg(this.query, this.replyPort);
}

class _ErrorResult {
  final String message;

  _ErrorResult(this.message);
}

class SearchIsolate {
  final String bookId;
  final Isolate _isolate;
  final SendPort _commandPort;

  SearchIsolate._(this.bookId, this._isolate, this._commandPort);

  static Future<SearchIsolate> spawn({
    required String bookId,
    required Uint8List indicesBytes,
    required Uint8List embeddings,
    required Uint8List verses,
    required Uint8List model,
    required Uint8List tokenizer,
  }) async {
    print('[SearchIsolate] Spawning isolate for $bookId...');
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(_entryPoint, initPort.sendPort);
    final commandPort = await initPort.first as SendPort;

    final replyPort = ReceivePort();
    commandPort.send(
      _LoadMsg(
        indicesBytes,
        embeddings,
        verses,
        model,
        tokenizer,
        replyPort.sendPort,
      ),
    );
    print('[SearchIsolate] Waiting for model load ($bookId)...');
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    print('[SearchIsolate] Model loaded for $bookId');

    return SearchIsolate._(bookId, isolate, commandPort);
  }

  Future<Index> getResult(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_QueryMsg(query, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    return _toIndex(result);
  }

  Future<List<Index>> searchIndex(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_IndexMsg(query, replyPort.sendPort));
    final results = await replyPort.first;
    if (results is _ErrorResult) throw Exception(results.message);
    if (results is List<rust.Index>) return results.map(_toIndex).toList();
    return [];
  }

  void dispose() {
    print('[SearchIsolate] Killing isolate for $bookId');
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

    Pointer<Void>? model;
    Pointer<Void>? indices;

    commandPort.listen((message) {
      if (message is _LoadMsg) {
        try {
          print('[SearchIsolate] Loading model...');
          indices = rust.getArchivedIndices(message.indicesBytes);
          model = rust.loadModel(
            message.embeddings,
            message.verses,
            message.model,
            message.tokenizer,
          );
          print('[SearchIsolate] Model loaded');
          message.replyPort.send(true);
        } catch (e) {
          print('[SearchIsolate] Load error: $e');
          message.replyPort.send(_ErrorResult(e.toString()));
        }
      } else if (message is _QueryMsg) {
        try {
          print('[SearchIsolate] Query: "${message.query}"');
          final resultPtr = rust.getResult(model!, message.query);
          final index = rust.getIndex(indices!, resultPtr);
          print(
            '[SearchIsolate] Result: ${index.book} '
            '${index.chapter}:${index.verse}',
          );
          message.replyPort.send(index);
        } catch (e) {
          print('[SearchIsolate] Query error: $e');
          message.replyPort.send(_ErrorResult(e.toString()));
        }
      } else if (message is _IndexMsg) {
        try {
          print('[SearchIsolate] Index search: "${message.query}"');
          final results = rust.searchIndex(indices!, message.query);
          print('[SearchIsolate] Raw result: $results');
          final indexes = results
              .map((result) => rust.getIndex(indices!, result))
              .toList();
          message.replyPort.send(indexes);
        } catch (e) {
          print('[SearchIsolate] Index search error: $e');
          message.replyPort.send(_ErrorResult(e.toString()));
        }
      }
    });
  }
}
