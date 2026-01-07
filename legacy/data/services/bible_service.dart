import 'dart:ffi';
import 'dart:typed_data';
import 'package:rust/rust.dart' as rust;

class BibleService {
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
