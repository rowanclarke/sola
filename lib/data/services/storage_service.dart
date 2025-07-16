import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:sola/data/services/file_service.dart';

class StorageService {
  final Directory extern;

  StorageService(this.extern);

  String externPath(String path) {
    return '${extern.path}/$path';
  }

  Future<FileService> extractAsset(String path) async {
    final local = Directory(externPath(path));
    if (!await local.exists()) {
      final bytes = await rootBundle.load(path);
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
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
    return FileService(local);
  }
}
