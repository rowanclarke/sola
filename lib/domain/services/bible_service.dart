import 'dart:ffi';
import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;

class BibleService {
  Uint8List serializeUsfm(String usfm) {
    return rust.serializeUsfm(usfm);
  }

  Pointer<Void> getArchivedBook(Uint8List bytes) {
    return rust.getArchivedBook(bytes);
  }

  String getBookIdentifier(Pointer<Void> book) {
    return rust.getBookIdentifier(book);
  }
}
