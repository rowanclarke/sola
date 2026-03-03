import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/core/models/index.dart';

class IndexService {
  IndexResponse getIndex() {
    return IndexResponse();
  }
}

class IndexResponse {
  final Pointer<Void> index = rust.getSearch();

  void addBook(String bookId, Uint8List bytes) {
    final book = rust.getArchivedBook(bytes);
    rust.addBook(index, bookId, book);
  }

  List<Index> search(String query) {
    return rust
        .searchIndex(index, query)
        .map(
          (index) => BookIndex(
            index.book.cast<Utf8>().toDartString(length: index.book_len),
          ),
        )
        .toList();
  }
}
