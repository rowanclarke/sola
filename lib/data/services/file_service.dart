import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' show join;

class FileService {
  final Directory dir;

  FileService(this.dir);

  String relative(String path) {
    return join(dir.path, path);
  }

  Future<bool> exists() async {
    return await dir.exists();
  }

  Future<void> create() async {
    await dir.create(recursive: true);
  }

  Future<void> _extract(FileService local, Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile) {
        final outFile = local.file(file.name);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      } else {
        final dir = local.directory(file.name);
        await dir.create();
      }
    }
  }

  Future<void> _write(File file, String string) async {
    await file.create(recursive: true);
    await file.writeAsString(string);
  }

  Future<FileService> extractAsset(String path) async {
    final local = directory(path);
    if (!await local.exists()) {
      final bytes = await rootBundle.load(path);
      await _extract(local, bytes.buffer.asUint8List());
    }
    return local;
  }

  Future<FileService> extractRemote(String url) async {
    Uri uri = Uri.parse(url);
    final path = uri.pathSegments.last;
    final local = directory(path);
    if (!await local.exists()) {
      final response = await http.get(uri);
      await _extract(local, response.bodyBytes);
    }
    return local;
  }

  Future<FileService> deserializeAsset(String path, String name) async {
    final contents = await rootBundle.loadString(path);
    final local = directory(path);
    if (!await local.exists()) {
      for (final dynamic item in json.decode(contents)) {
        await _write(local.file(item[name]), json.encode(item));
      }
    }
    return local;
  }

  Future<File> asset(String path) async {
    final contents = await rootBundle.loadString(path);
    final file = File(relative(path));
    await _write(file, contents);
    return file;
  }

  FileService directory(String path) {
    return FileService(Directory(relative(path)));
  }

  File file(String path) {
    return File(relative(path));
  }

  Future<List<File>> getFiles(bool recursive) async {
    if (await exists()) {
      return dir.listSync(recursive: recursive).whereType<File>().toList();
    } else {
      return [];
    }
  }

  Future<List<Directory>> getDirectories(bool recursive) async {
    if (await exists()) {
      return dir.listSync(recursive: recursive).whereType<Directory>().toList();
    } else {
      return [];
    }
  }

  Future<bool> openDirectory(String path) async {
    final dir = Directory(relative(path));
    if (!await dir.exists()) {
      dir.create(recursive: true);
      return false;
    }
    return true;
  }

  Future<void> deleteDirectory(String path) async {
    final dir = Directory(relative(path));
    await dir.delete(recursive: true);
  }

  Future<void> deleteFile(String path) async {
    final file = File(relative(path));
    await file.delete(recursive: true);
  }

  Future<String> readAsString(String path, [String Function()? get]) async {
    final file = File(relative(path));
    if (!await file.exists()) {
      final string = get!();
      await file.writeAsString(string);
      return string;
    }
    return await file.readAsString();
  }

  Future<Uint8List> readAsBytes(
    String path, [
    Uint8List Function()? get,
  ]) async {
    final file = File(relative(path));
    if (!await file.exists()) {
      final bytes = get!();
      await file.writeAsBytes(bytes);
      return bytes;
    }
    return await file.readAsBytes();
  }
}
