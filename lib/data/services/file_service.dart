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

  Future<void> deleteDirectory(String path) async {
    final dir = Directory(localPath(path));
    await dir.delete(recursive: true);
  }

  Future<void> deleteFile(String path) async {
    final file = File(localPath(path));
    await file.delete(recursive: true);
  }

  File file(String path) {
    return File(localPath(path));
  }

  List<File> getFiles() {
    return local.listSync(recursive: true).whereType<File>().toList();
  }

  Future<bool> isInitialized() async {
    return await local.exists();
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
