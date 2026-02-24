import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class FileService {
  final Directory _baseDir;

  FileService(this._baseDir);

  String _resolve(String path) => p.join(_baseDir.path, path);

  Future<String> readFile(String filePath) {
    return File(_resolve(filePath)).readAsString();
  }

  Future<void> writeFile(String filePath, String data) async {
    final file = File(_resolve(filePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(data);
  }

  Future<Uint8List> readBytes(String filePath, [Future<Uint8List> Function()? generator]) async {
    final file = File(_resolve(filePath));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    if (generator != null) {
      final bytes = await generator();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return bytes;
    }
    throw FileSystemException('File not found', _resolve(filePath));
  }

  Future<void> writeBytes(String filePath, Uint8List data) async {
    final file = File(_resolve(filePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data);
  }

  Future<bool> fileExists(String filePath) {
    return File(_resolve(filePath)).exists();
  }

  Future<List<String>> listDirectory(String directoryPath) async {
    final dir = Directory(_resolve(directoryPath));
    if (!await dir.exists()) return [];
    return dir
        .list()
        .map((e) => p.basename(e.path))
        .toList();
  }

  Future<void> deleteFile(String filePath) {
    return File(_resolve(filePath)).delete();
  }

  Future<void> extractRemote(String url, String path) async {
    final dir = Directory(_resolve(path));
    if (await dir.exists()) {
      debugPrint('[FileService] Already extracted: $path');
      return;
    }
    debugPrint('[FileService] Downloading $url ...');
    final response = await http.get(Uri.parse(url));
    debugPrint('[FileService] Downloaded ${response.bodyBytes.length} bytes, extracting...');
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    for (final file in archive) {
      final filePath = p.join(dir.path, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
    debugPrint('[FileService] Extracted ${archive.length} entries to $path');
  }

  Future<dynamic> deserializeAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    return json.decode(jsonString);
  }

  Future<bool> openDirectory(String path) async {
    final dir = Directory(_resolve(path));
    if (await dir.exists()) return true;
    await dir.create(recursive: true);
    return false;
  }
}
