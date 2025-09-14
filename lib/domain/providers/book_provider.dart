import 'dart:ffi';

abstract class BookProvider {
  Future<Pointer<Void>> getBook(String book);
}
