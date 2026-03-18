import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/index.dart';
import 'package:sola/core/models/search_result.dart';

class _InitMessage {
  final Uint8List pageMapBytes;
  final Uint8List embeddings;
  final Uint8List verseRefs;
  final int modelAddress;
  final SendPort replyPort;

  _InitMessage(
    this.pageMapBytes,
    this.embeddings,
    this.verseRefs,
    this.modelAddress,
    this.replyPort,
  );
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
  final String bookId;
  final Isolate _isolate;
  final SendPort _commandPort;

  SearchIsolate._(this.bookId, this._isolate, this._commandPort);

  /// Loads the ONNX model once in a background isolate.
  /// Returns the native pointer address (int) for sharing across isolates.
  static Future<int> loadModelOnce(
    Uint8List model,
    Uint8List tokenizer,
  ) async {
    print('[SearchIsolate] Loading model once...');
    final address = await Isolate.run(() {
      final ptr = rust.loadModel(model, tokenizer);
      return ptr.address;
    });
    print('[SearchIsolate] Model loaded, address: $address');
    return address;
  }

  static Future<SearchIsolate> spawn({
    required String bookId,
    required Uint8List pageMapBytes,
    required Uint8List embeddings,
    required Uint8List verseRefs,
    required int modelAddress,
  }) async {
    print('[SearchIsolate] Spawning isolate for $bookId...');
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(_entryPoint, initPort.sendPort);
    final commandPort = await initPort.first as SendPort;

    final replyPort = ReceivePort();
    commandPort.send(
      _InitMessage(
        pageMapBytes,
        embeddings,
        verseRefs,
        modelAddress,
        replyPort.sendPort,
      ),
    );
    print('[SearchIsolate] Waiting for data load ($bookId)...');
    final result = await replyPort.first;
    if (result is _IsolateError) throw Exception(result.message);
    print('[SearchIsolate] Ready for $bookId');

    return SearchIsolate._(bookId, isolate, commandPort);
  }

  Future<List<SearchResult>> getResult(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_SearchMessage(query, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _IsolateError) throw Exception(result.message);
    return (result as List).cast<SearchResult>();
  }

  Future<List<Index>> searchIndex(String query) async {
    final replyPort = ReceivePort();
    _commandPort.send(_TextSearchMessage(query, replyPort.sendPort));
    final results = await replyPort.first;
    if (results is _IsolateError) throw Exception(results.message);
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
    Pointer<Void>? pageMap;
    Pointer<Void>? embeddings;
    Pointer<Void>? verseRefs;

    commandPort.listen((message) {
      if (message is _InitMessage) {
        try {
          print('[SearchIsolate] Loading data...');
          pageMap = rust.getArchivedIndices(message.pageMapBytes);
          model = Pointer<Void>.fromAddress(message.modelAddress);
          print('[SearchIsolate] Model pointer: ${message.modelAddress}');
          (embeddings, verseRefs) = rust.loadEmbeddings(
            message.embeddings,
            message.verseRefs,
          );
          print('[SearchIsolate] Embeddings loaded');
          message.replyPort.send(true);
        } catch (e) {
          print('[SearchIsolate] Load error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      } else if (message is _SearchMessage) {
        try {
          print('[SearchIsolate] Query: "${message.query}"');
          final (:pointers, :distances) = rust.getResult(
            model!,
            embeddings!,
            verseRefs!,
            message.query,
          );
          final results = List.generate(pointers.length, (i) {
            final index = rust.getIndex(pageMap!, pointers[i]);
            return SearchResult(
              index: _toIndex(index),
              distance: distances[i],
            );
          });
          print('[SearchIsolate] ${results.length} results');
          message.replyPort.send(results);
        } catch (e) {
          print('[SearchIsolate] Query error: $e');
          message.replyPort.send(_IsolateError(e.toString()));
        }
      } else if (message is _TextSearchMessage) {
        try {
          print('[SearchIsolate] Index search: "${message.query}"');
          final results = rust.searchIndex(pageMap!, message.query);
          print('[SearchIsolate] Raw result: $results');
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
