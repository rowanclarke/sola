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

class _ErrorResult {
  final String message;

  _ErrorResult(this.message);
}

class SearchService {
  Isolate? _isolate;
  SendPort? _commandPort;

  Future<void> loadModel(
    Uint8List indicesBytes,
    Uint8List embeddings,
    Uint8List verses,
    Uint8List model,
    Uint8List tokenizer,
  ) async {
    dispose();

    print('[SearchSvc] Spawning search isolate...');
    final initPort = ReceivePort();
    _isolate = await Isolate.spawn(_entryPoint, initPort.sendPort);
    _commandPort = await initPort.first as SendPort;

    final replyPort = ReceivePort();
    _commandPort!.send(
      _LoadMsg(
        indicesBytes,
        embeddings,
        verses,
        model,
        tokenizer,
        replyPort.sendPort,
      ),
    );
    print('[SearchSvc] Waiting for model load...');
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    print('[SearchSvc] Model loaded on isolate');
  }

  Future<Index> getResult(String query) async {
    if (_commandPort == null) throw StateError('Model not loaded');
    final replyPort = ReceivePort();
    _commandPort!.send(_QueryMsg(query, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    return Index(
      result.page,
      result.book,
      result.header,
      result.chapter,
      result.verse,
    );
  }

  void dispose() {
    if (_isolate != null) {
      print('[SearchSvc] Killing search isolate');
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
      _commandPort = null;
    }
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
      }
    });
  }
}
