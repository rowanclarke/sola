import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart' show TextStyle;
import 'rust_bindings_generated.dart' as bind;
export 'rust_bindings_generated.dart' show Style;

// ignore: avoid_print
void _log(String msg) => print(msg);

class Dimensions {
  final double width;
  final double height;
  final double headerHeight;
  final double dropCapPadding;

  Dimensions(
    this.width,
    this.height, {
    required this.headerHeight,
    required this.dropCapPadding,
  });
}

class Text {
  final String text;
  final bind.Rectangle rect;
  final TextStyle style;

  Text(this.text, this.rect, this.style);
}

class Index {
  final int page;
  final String book;
  final String header;
  final int? chapter;
  final int? verse;

  Index(this.page, this.book, this.header, [this.chapter, this.verse]);
}

/// Allocates error output pointers for FFI calls.
({Pointer<Pointer<Char>> error, Pointer<Size> errorLen}) _allocError() {
  final error = malloc<Pointer<Char>>();
  final errorLen = malloc<Size>();
  return (error: error, errorLen: errorLen);
}

/// Checks whether the FFI call wrote an error. If so, reads the message,
/// frees the Rust-allocated string, and throws an [Exception].
void _checkError(Pointer<Pointer<Char>> outError, Pointer<Size> outErrorLen) {
  if (outErrorLen.value > 0) {
    final msg = outError.value.cast<Utf8>().toDartString(
      length: outErrorLen.value,
    );
    _bindings.free_error(outError.value, outErrorLen.value);
    _log('[FFI] Error from Rust: $msg');
    throw Exception('Rust error: $msg');
  }
}

Pointer<Void> getRenderer() {
  return _bindings.renderer();
}

void registerFontFamily(
  Pointer<Void> renderer,
  String family,
  Uint8List bytes,
) {
  final familyPtr = family.toNativeUtf8();
  final ptr = malloc<Uint8>(bytes.length);
  final bytePtr = ptr.asTypedList(bytes.length);
  bytePtr.setAll(0, bytes);
  final e = _allocError();
  _bindings.register_font_family(
    renderer,
    familyPtr.cast<Char>(),
    familyPtr.length,
    ptr.cast<Char>(),
    bytes.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
}

void registerStyle(
  Pointer<Void> renderer,
  bind.Style style,
  TextStyle textStyle,
) {
  final native = textStyle.fontFamily!.toNativeUtf8();
  final ctextStyle = calloc<bind.TextStyle>();
  ctextStyle.ref.font_family = native.cast<Char>();
  ctextStyle.ref.font_family_len = native.length;
  ctextStyle.ref.font_size = textStyle.fontSize!;
  ctextStyle.ref.height = textStyle.height!;
  ctextStyle.ref.letter_spacing = textStyle.letterSpacing!;
  ctextStyle.ref.word_spacing = textStyle.wordSpacing!;
  _bindings.register_style(renderer, style, ctextStyle);
}

TextStyle toTextStyle(bind.TextStyle textStyle) {
  final fontFamily = textStyle.font_family.cast<Utf8>().toDartString(
    length: textStyle.font_family_len,
  );
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: textStyle.font_size,
    height: textStyle.height,
    letterSpacing: textStyle.letter_spacing,
    wordSpacing: textStyle.word_spacing,
  );
}

Uint8List serializeUsfm(String usfm) {
  _log('[FFI] serializeUsfm: ${usfm.length} chars');
  final usfmPtr = usfm.toNativeUtf8();
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();

  _bindings.serialize_usfm(
    usfmPtr.cast<Char>(),
    usfmPtr.length,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> getArchivedBook(Uint8List book) {
  final bookPtr = _toNative(book);
  final e = _allocError();
  final result = _bindings.archived_book(
    bookPtr.cast<Char>(),
    book.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return result;
}

String getBookIdentifier(Pointer<Void> book) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  _bindings.book_identifier(
    book,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.cast<Utf8>().toDartString(length: outLen.value);
}

Pointer<Void> layout(
  Pointer<Void> renderer,
  Pointer<Void> book,
  Dimensions dim,
) {
  _log('[FFI] layout: ${dim.width.toInt()}x${dim.height.toInt()}');
  final cdim = calloc<bind.Dimensions>();
  cdim.ref.width = dim.width;
  cdim.ref.height = dim.height;
  cdim.ref.header_height = dim.headerHeight;
  cdim.ref.drop_cap_padding = dim.dropCapPadding;
  final e = _allocError();
  final result = _bindings.layout(renderer, book, cdim, e.error, e.errorLen);
  _checkError(e.error, e.errorLen);
  return result;
}

Uint8List serializePages(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();

  _bindings.serialize_pages(
    painter,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> getArchivedPages(Uint8List pages) {
  final ptr = malloc<Uint8>(pages.length);
  final bytePtr = ptr.asTypedList(pages.length);
  bytePtr.setAll(0, pages);
  final e = _allocError();
  final result = _bindings.archived_pages(
    ptr.cast<Char>(),
    pages.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return result;
}

int getNumPages(Pointer<Void> pages) {
  return _bindings.num_pages(pages);
}

List<Text> getPage(Pointer<Void> renderer, Pointer<Void> pages, int pageIndex) {
  final out = malloc<Pointer<bind.Text>>();
  final outLen = malloc<Size>();
  final e = _allocError();

  _bindings.page(renderer, pages, pageIndex, out, outLen, e.error, e.errorLen);
  _checkError(e.error, e.errorLen);

  return List.generate(outLen.value, (i) {
    final text = (out.value + i).ref;
    return Text(
      text.text.cast<Utf8>().toDartString(length: text.len),
      text.rect,
      toTextStyle(text.style),
    );
  });
}

Uint8List serializeIndices(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();

  _bindings.serialize_indices(
    painter,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> getArchivedIndices(Uint8List indices) {
  final indicesPtr = _toNative(indices);
  final e = _allocError();
  final result = _bindings.archived_indices(
    indicesPtr.cast<Char>(),
    indices.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return result;
}

Index getIndex(Pointer<Void> indices, Pointer<Void> index) {
  final page = malloc<Size>();
  final book = malloc<Pointer<Utf8>>();
  final bookLen = malloc<Size>();
  final header = malloc<Pointer<Utf8>>();
  final headerLen = malloc<Size>();
  final chapter = malloc<UnsignedShort>();
  final verse = malloc<UnsignedShort>();
  final e = _allocError();
  chapter.value = 0;
  verse.value = 0;
  _bindings.get_index(
    indices,
    index,
    page,
    book.cast<Pointer<Char>>(),
    bookLen,
    header.cast<Pointer<Char>>(),
    headerLen,
    chapter,
    verse,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return Index(
    page.value,
    book.value.toDartString(length: bookLen.value),
    header.value.toDartString(length: headerLen.value),
    chapter.value == 0 ? null : chapter.value,
    verse.value == 0 ? null : verse.value,
  );
}

Uint8List serializeVerses(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();

  _bindings.serialize_verses(
    painter,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.asTypedList(outLen.value);
}

Uint8List serializeVerseRanges(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();

  _bindings.serialize_verse_ranges(
    painter,
    out.cast<Pointer<Char>>(),
    outLen,
  );
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> loadSearchEngine(
  Uint8List model,
  Uint8List tokenizer,
  String hnswDir,
  String hnswBasename,
  Uint8List idx,
) {
  _log('[FFI] loadSearchEngine: model=${model.length}B tokenizer=${tokenizer.length}B idx=${idx.length}B');
  final modelPtr = _toNative(model);
  final tokenizerPtr = _toNative(tokenizer);
  final hnswDirPtr = hnswDir.toNativeUtf8();
  final hnswBasenamePtr = hnswBasename.toNativeUtf8();
  final idxPtr = _toNative(idx);
  final e = _allocError();
  final result = _bindings.load_search_engine(
    modelPtr.cast<Char>(),
    model.length,
    tokenizerPtr.cast<Char>(),
    tokenizer.length,
    hnswDirPtr.cast<Char>(),
    hnswDirPtr.length,
    hnswBasenamePtr.cast<Char>(),
    hnswBasenamePtr.length,
    idxPtr.cast<Char>(),
    idx.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return result;
}

({List<int> ids, List<double> distances}) search(
  Pointer<Void> engine,
  String query,
  int topK,
  int ef,
) {
  _log('[FFI] search: "$query" topK=$topK ef=$ef');
  final queryPtr = query.toNativeUtf8();
  final outIds = malloc<Pointer<Size>>();
  final outDistances = malloc<Pointer<Float>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  _bindings.search(
    engine,
    queryPtr.cast<Char>(),
    queryPtr.length,
    topK,
    ef,
    outIds,
    outDistances,
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  final count = outLen.value;
  return (
    ids: List.generate(count, (i) => outIds.value[i]),
    distances: List.generate(count, (i) => outDistances.value[i]),
  );
}

Index getSearchResult(
  Pointer<Void> engine,
  Pointer<Void> pageMap,
  int id,
) {
  final page = malloc<Size>();
  final book = malloc<Pointer<Utf8>>();
  final bookLen = malloc<Size>();
  final header = malloc<Pointer<Utf8>>();
  final headerLen = malloc<Size>();
  final chapter = malloc<UnsignedShort>();
  final verse = malloc<UnsignedShort>();
  final e = _allocError();
  chapter.value = 0;
  verse.value = 0;
  _bindings.get_search_result(
    engine,
    pageMap,
    id,
    page,
    book.cast<Pointer<Char>>(),
    bookLen,
    header.cast<Pointer<Char>>(),
    headerLen,
    chapter,
    verse,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return Index(
    page.value,
    book.value.toDartString(length: bookLen.value),
    header.value.toDartString(length: headerLen.value),
    chapter.value == 0 ? null : chapter.value,
    verse.value == 0 ? null : verse.value,
  );
}

List<Pointer<Void>> searchIndex(Pointer<Void> pageMap, String query) {
  _log('[FFI] searchIndex: "$query"');
  final queryPtr = query.toNativeUtf8();
  final out = malloc<Pointer<Pointer<Void>>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  _bindings.search_index(
    pageMap,
    queryPtr.cast<Char>(),
    queryPtr.length,
    out,
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return List.generate(outLen.value, (i) => out.value[i]);
}

Pointer<Void> pageMapBuilderNew() {
  return _bindings.page_map_builder_new();
}

void pageMapBuilderAdd(Pointer<Void> builder, Uint8List bytes) {
  final ptr = _toNative(bytes);
  final e = _allocError();
  _bindings.page_map_builder_add(
    builder,
    ptr.cast<Char>(),
    bytes.length,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
}

Uint8List pageMapBuilderFinish(Pointer<Void> builder) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  _bindings.page_map_builder_finish(
    builder,
    out.cast<Pointer<Char>>(),
    outLen,
    e.error,
    e.errorLen,
  );
  _checkError(e.error, e.errorLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Uint8> _toNative(Uint8List list) {
  final ptr = malloc<Uint8>(list.length);
  ptr.asTypedList(list.length).setAll(0, list);
  return ptr;
}

const String _libName = 'rust';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final bind.RustBindings _bindings = bind.RustBindings(_dylib);
