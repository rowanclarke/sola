import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:ui' show Color;
import 'package:flutter/painting.dart' show TextDecoration, TextStyle, FontWeight, TextBaseline;
import 'rust_bindings_generated.dart' as bind;
export 'rust_bindings_generated.dart' show Style;

// ignore: avoid_print
void _log(String msg) => print(msg);

class Dimensions {
  final double width;
  final double height;
  final double headerHeight;
  final double dropCapPadding;

  /// Number of equal-width body columns per page. Footnotes still pool into a
  /// single page-wide block at the foot, whichever column raised them.
  final int columns;

  /// Horizontal space between adjacent columns. Ignored when [columns] is 1.
  final double gutter;

  Dimensions(
    this.width,
    this.height, {
    required this.headerHeight,
    required this.dropCapPadding,
    this.columns = 1,
    this.gutter = 0,
  });
}

/// A fragment's box, copied out of native memory.
///
/// [Text] has to be free of pointers into the archive it came from: the page
/// buffer is released as soon as a page is materialized.
class TextRect {
  final double top;
  final double left;
  final double width;
  final double height;

  const TextRect(this.top, this.left, this.width, this.height);
}

class Text {
  final String text;
  final TextRect rect;
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

void _freeError(({Pointer<Pointer<Char>> error, Pointer<Size> errorLen}) e) {
  malloc.free(e.error);
  malloc.free(e.errorLen);
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

/// Copies a buffer Rust handed over and releases the Rust-side allocation.
///
/// Every `serialize_*` export allocates with `write_bytes_out`, so the bytes
/// have to come back to Dart before the caller drops them on the floor.
Uint8List _takeBytes(Pointer<Pointer<Uint8>> out, Pointer<Size> outLen) {
  final len = outLen.value;
  if (len == 0 || out.value == nullptr) return Uint8List(0);
  final bytes = Uint8List.fromList(out.value.asTypedList(len));
  _bindings.bytes_free(out.value.cast<Char>(), len);
  return bytes;
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
  ctextStyle.ref.underline = (textStyle.decoration == TextDecoration.underline) ? 1 : 0;
  _bindings.register_style(renderer, style, ctextStyle);
}

TextStyle toTextStyle(bind.TextStyle textStyle) {
  final fontFamily = textStyle.font_family.cast<Utf8>().toDartString(
    length: textStyle.font_family_len,
  );
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: textStyle.font_size,
    fontWeight: FontWeight.w700,
    height: textStyle.height,
    letterSpacing: textStyle.letter_spacing,
    wordSpacing: textStyle.word_spacing,
    textBaseline: TextBaseline.alphabetic,
    decoration: textStyle.underline != 0 ? TextDecoration.underline : null,
    decorationColor: textStyle.underline != 0 ? const Color(0xFF71717A) : null,
  );
}

Uint8List serializeUsfm(String usfm) {
  _log('[FFI] serializeUsfm: ${usfm.length} chars');
  final usfmPtr = usfm.toNativeUtf8();
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  try {
    _bindings.serialize_usfm(
      usfmPtr.cast<Char>(),
      usfmPtr.length,
      out.cast<Pointer<Char>>(),
      outLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    return _takeBytes(out, outLen);
  } finally {
    malloc.free(usfmPtr);
    malloc.free(out);
    malloc.free(outLen);
    _freeError(e);
  }
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
  _log(
    '[FFI] layout: ${dim.width.toInt()}x${dim.height.toInt()} '
    'in ${dim.columns} column(s)',
  );
  final cdim = calloc<bind.Dimensions>();
  cdim.ref.width = dim.width;
  cdim.ref.height = dim.height;
  cdim.ref.header_height = dim.headerHeight;
  cdim.ref.drop_cap_padding = dim.dropCapPadding;
  cdim.ref.columns = dim.columns;
  cdim.ref.gutter = dim.gutter;
  final e = _allocError();
  final result = _bindings.layout(renderer, book, cdim, e.error, e.errorLen);
  _checkError(e.error, e.errorLen);
  return result;
}

/// The rendered pages of one book: every page archived on its own, back to
/// back, plus the offset table that says where each one starts.
///
/// Written to disk as `pages` and `page_offsets` so a reader can seek to a
/// single page instead of loading the book.
({Uint8List pages, Uint8List offsets}) serializePages(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final outIndex = malloc<Pointer<Uint8>>();
  final outIndexLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  outIndexLen.value = 0;
  try {
    _bindings.serialize_pages(
      painter,
      out.cast<Pointer<Char>>(),
      outLen,
      outIndex.cast<Pointer<Char>>(),
      outIndexLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    return (pages: _takeBytes(out, outLen), offsets: _takeBytes(outIndex, outIndexLen));
  } finally {
    malloc.free(out);
    malloc.free(outLen);
    malloc.free(outIndex);
    malloc.free(outIndexLen);
    _freeError(e);
  }
}

/// Materializes one page from its own slice of the `pages` blob.
///
/// [page] must be exactly the bytes the offset table delimits for that page:
/// each segment is a self-contained archive. Everything the returned fragments
/// hold is copied into Dart, so both the native page list and the scratch
/// buffer are released before this returns.
List<Text> pageFromBytes(Pointer<Void> renderer, Uint8List page) {
  final pagePtr = _toNative(page);
  final out = malloc<Pointer<bind.Text>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  try {
    _bindings.page_from_bytes(
      renderer,
      pagePtr.cast<Char>(),
      page.length,
      out,
      outLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    final fragments = out.value;
    final count = outLen.value;
    try {
      return List.generate(count, (i) {
        final text = (fragments + i).ref;
        final rect = text.rect;
        return Text(
          text.text.cast<Utf8>().toDartString(length: text.len),
          TextRect(rect.top, rect.left, rect.width, rect.height),
          toTextStyle(text.style),
        );
      });
    } finally {
      _bindings.page_free(fragments, count);
    }
  } finally {
    malloc.free(pagePtr);
    malloc.free(out);
    malloc.free(outLen);
    _freeError(e);
  }
}

Uint8List serializeIndices(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  try {
    _bindings.serialize_indices(
      painter,
      out.cast<Pointer<Char>>(),
      outLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    return _takeBytes(out, outLen);
  } finally {
    malloc.free(out);
    malloc.free(outLen);
    _freeError(e);
  }
}

Uint8List serializeVerses(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  try {
    _bindings.serialize_verses(
      painter,
      out.cast<Pointer<Char>>(),
      outLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    return _takeBytes(out, outLen);
  } finally {
    malloc.free(out);
    malloc.free(outLen);
    _freeError(e);
  }
}

Uint8List serializeVerseRanges(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();
  outLen.value = 0;
  try {
    _bindings.serialize_verse_ranges(
      painter,
      out.cast<Pointer<Char>>(),
      outLen,
    );
    return _takeBytes(out, outLen);
  } finally {
    malloc.free(out);
    malloc.free(outLen);
  }
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
  Pointer<Void> refIndex,
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
  try {
    _bindings.get_search_result(
      engine,
      refIndex,
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
  } finally {
    malloc.free(page);
    malloc.free(book);
    malloc.free(bookLen);
    malloc.free(header);
    malloc.free(headerLen);
    malloc.free(chapter);
    malloc.free(verse);
    _freeError(e);
  }
}

/// Fuzzy book → chapter → verse lookup over one translation's rendered pages.
///
/// Built from the per-book `indices` files the renderer already writes, so it
/// costs no extra assets and stays in step with what was actually rendered.
/// Owns native memory: call [dispose] when the translation is unloaded.
class ReferenceIndex {
  final Pointer<Void> _index;

  // Query scratch, allocated once and reused, so a lookup per keystroke does
  // not allocate.
  final Pointer<Pointer<bind.RefHit>> _out = malloc<Pointer<bind.RefHit>>();
  final Pointer<Size> _outLen = malloc<Size>();
  final _error = _allocError();

  bool _disposed = false;

  ReferenceIndex._(this._index);

  /// Builds an index from each book's serialized `indices` map, in the order
  /// the books should be listed.
  static ReferenceIndex build(List<Uint8List> perBookIndices) {
    _log('[FFI] ReferenceIndex.build: ${perBookIndices.length} books');
    final builder = _bindings.ref_index_builder_new();
    final e = _allocError();
    Object? failure;
    try {
      for (final bytes in perBookIndices) {
        final ptr = _toNative(bytes);
        try {
          _bindings.ref_index_builder_add(
            builder,
            ptr.cast<Char>(),
            bytes.length,
            e.error,
            e.errorLen,
          );
          _checkError(e.error, e.errorLen);
        } finally {
          malloc.free(ptr);
        }
      }
    } catch (error) {
      failure = error;
    }
    // finish() consumes the builder either way, so always call it.
    final index = _bindings.ref_index_builder_finish(builder, e.error, e.errorLen);
    try {
      if (failure != null) {
        _bindings.ref_index_free(index);
        throw failure;
      }
      _checkError(e.error, e.errorLen);
      return ReferenceIndex._(index);
    } finally {
      _freeError(e);
    }
  }

  /// The raw handle, for FFI calls that resolve references themselves
  /// (see [getSearchResult]).
  Pointer<Void> get handle => _index;

  /// Best [limit] matches for [query], or an empty list when it names no book —
  /// the caller should then fall back to semantic search.
  List<Index> lookup(String query, {int limit = 5}) {
    if (_disposed) throw StateError('ReferenceIndex used after dispose');
    final queryPtr = query.toNativeUtf8();
    try {
      _bindings.ref_index_lookup(
        _index,
        queryPtr.cast<Char>(),
        queryPtr.length,
        limit,
        _out,
        _outLen,
        _error.error,
        _error.errorLen,
      );
      _checkError(_error.error, _error.errorLen);
      final hits = _out.value;
      final count = _outLen.value;
      try {
        return List.generate(count, (i) {
          final hit = (hits + i).ref;
          return Index(
            hit.page,
            hit.book.cast<Utf8>().toDartString(length: hit.book_len),
            hit.header.cast<Utf8>().toDartString(length: hit.header_len),
            hit.chapter == 0 ? null : hit.chapter,
            hit.verse == 0 ? null : hit.verse,
          );
        });
      } finally {
        _bindings.ref_hits_free(hits, count);
      }
    } finally {
      malloc.free(queryPtr);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bindings.ref_index_free(_index);
    malloc.free(_out);
    malloc.free(_outLen);
    _freeError(_error);
  }
}

/// Reads a book's display title straight out of its serialized `indices` map.
String indicesBookTitle(Uint8List indices) {
  final ptr = _toNative(indices);
  final out = malloc<Pointer<Utf8>>();
  final outLen = malloc<Size>();
  final e = _allocError();
  outLen.value = 0;
  try {
    _bindings.indices_book_title(
      ptr.cast<Char>(),
      indices.length,
      out.cast<Pointer<Char>>(),
      outLen,
      e.error,
      e.errorLen,
    );
    _checkError(e.error, e.errorLen);
    // Borrowed from `ptr`, so it must be copied before the buffer is freed.
    return outLen.value == 0
        ? ''
        : out.value.toDartString(length: outLen.value);
  } finally {
    malloc.free(ptr);
    malloc.free(out);
    malloc.free(outLen);
    _freeError(e);
  }
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
