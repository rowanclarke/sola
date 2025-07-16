import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

class FileService {
  final Directory local;

  FileService(this.local);

  String localPath(String path) {
    return '${local.path}/$path';
  }

  Future<String> readAsString(String path) async {
    final file = File(localPath(path));
    return await file.readAsString();
  }

  Future<Uint8List> readAsBytes(String path) async {
    final file = File(localPath(path));
    return await file.readAsBytes();
  }
}
