import 'dart:ffi';
import 'dart:typed_data';

class BibleService {
  Future<Uint8List> serialize(String usfm) async {
    throw Error;
    // return rust.serializeUsfm(usfm);
  }

  Future<Pointer<Void>> getArchived(Uint8List book) async {
    throw Error;
    // return rust.getArchivedBook(book);
  }

  String getIdentifier(Pointer<Void> book) {
    throw Error;
    // return rust.getBookIdentifier(book);
  }
}
