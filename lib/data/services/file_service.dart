import 'dart:io';

import 'package:flutter/services.dart';

class FileService {
  final Directory local;

  FileService(this.local);

  String localPath(String path) {
    return '${local.path}/$path';
  }

  Future<bool> openDirectory(String path) async {
    final dir = Directory(localPath(path));
    if (!await dir.exists()) {
      dir.create(recursive: true);
      return false;
    }
    return true;
  }

  Future<String> readAsString(String path, {String Function()? get}) async {
    final file = File(localPath(path));
    if (!await file.exists()) {
      final string = get!();
      await file.writeAsString(string);
      return string;
    }
    return await file.readAsString();
  }

  Future<Uint8List> readAsBytes(
    String path, {
    Uint8List Function()? get,
  }) async {
    final file = File(localPath(path));
    if (!await file.exists()) {
      final bytes = get!();
      await file.writeAsBytes(bytes);
      return bytes;
    }
    return await file.readAsBytes();
  }
}
