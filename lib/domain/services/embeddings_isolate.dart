import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/embeddings_data.dart';

class _LoadModelMsg {
  final Uint8List model;
  final Uint8List tokenizer;
  final SendPort replyPort;

  _LoadModelMsg(this.model, this.tokenizer, this.replyPort);
}

class _ComputeMsg {
  final Uint8List bookBytes;
  final SendPort replyPort;

  _ComputeMsg(this.bookBytes, this.replyPort);
}

class _ErrorResult {
  final String message;

  _ErrorResult(this.message);
}

class EmbeddingsIsolate {
  final Isolate _isolate;
  final SendPort _commandPort;

  EmbeddingsIsolate._(this._isolate, this._commandPort);

  static Future<EmbeddingsIsolate> spawn({
    required Uint8List model,
    required Uint8List tokenizer,
  }) async {
    print('[EmbeddingsIsolate] Spawning...');
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(_entryPoint, initPort.sendPort);
    final commandPort = await initPort.first as SendPort;

    final replyPort = ReceivePort();
    commandPort.send(_LoadModelMsg(model, tokenizer, replyPort.sendPort));
    print('[EmbeddingsIsolate] Waiting for model load...');
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    print('[EmbeddingsIsolate] Model loaded');

    return EmbeddingsIsolate._(isolate, commandPort);
  }

  Future<EmbeddingsData> computeEmbeddings(Uint8List bookBytes) async {
    final replyPort = ReceivePort();
    _commandPort.send(_ComputeMsg(bookBytes, replyPort.sendPort));
    final result = await replyPort.first;
    if (result is _ErrorResult) throw Exception(result.message);
    return result as EmbeddingsData;
  }

  void dispose() {
    print('[EmbeddingsIsolate] Killing isolate');
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _entryPoint(SendPort mainPort) {
    final commandPort = ReceivePort();
    mainPort.send(commandPort.sendPort);

    Pointer<Void>? model;

    commandPort.listen((message) {
      if (message is _LoadModelMsg) {
        try {
          print('[EmbeddingsIsolate] Loading model...');
          model = rust.getModel(message.model, message.tokenizer);
          print('[EmbeddingsIsolate] Model loaded');
          message.replyPort.send(true);
        } catch (e) {
          print('[EmbeddingsIsolate] Load error: $e');
          message.replyPort.send(_ErrorResult(e.toString()));
        }
      } else if (message is _ComputeMsg) {
        try {
          print('[EmbeddingsIsolate] Computing embeddings...');
          final book = rust.getArchivedBook(message.bookBytes);
          final data = rust.getEmbeddings(model!, book);
          print(
            '[EmbeddingsIsolate] Computed: '
            '${data.embeddingsBytes.length}B embeddings, '
            '${data.versesBytes.length}B verses',
          );
          message.replyPort.send(data);
        } catch (e) {
          print('[EmbeddingsIsolate] Compute error: $e');
          message.replyPort.send(_ErrorResult(e.toString()));
        }
      }
    });
  }
}
