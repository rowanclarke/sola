import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart' as rust;

class UsfmService {
  Future<Uint8List> serialize(String usfm) async {
    return rust.serializeUsfm(usfm);
  }

  Future<Pointer<Void>> getArchived(Uint8List book) async {
    return rust.getArchivedBook(book);
  }

  String getIdentifier(Pointer<Void> book) {
    return rust.getBookIdentifier(book);
  }
}
