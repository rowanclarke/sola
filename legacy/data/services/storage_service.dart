import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sola/data/services/file_service.dart';

class StorageService {
  final Directory extern;

  StorageService(this.extern);

  String externPath(String path) {
    return '${extern.path}/$path';
  }

  Future<void> _extract(Directory local, Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filePath = '${local.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      } else {
        final dir = Directory(filePath);
        await dir.create(recursive: true);
      }
    }
  }

  Future<FileService> extractAsset(String path) async {
    final local = Directory(externPath(path));
    if (!await local.exists()) {
      final bytes = await rootBundle.load(path);
      await _extract(local, bytes.buffer.asUint8List());
    }
    return FileService(local);
  }

  Future<FileService> extractRemote(String url) async {
    Uri uri = Uri.parse(url);
    final path = uri.pathSegments.last;
    final local = Directory(externPath(path));
    if (!await local.exists()) {
      final response = await http.get(uri);
      await _extract(local, response.bodyBytes);
    }
    return FileService(local);
  }

  FileService local(String path) {
    return FileService(Directory(externPath(path)));
  }

  Future<void> deleteDirectory(String path) async {
    final dir = Directory(externPath(path));
    await dir.delete(recursive: true);
  }
}
