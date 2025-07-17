import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart' show TextStyle;
import 'rust_bindings_generated.dart' as bind;
export 'rust_bindings_generated.dart' show Style;

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

Pointer<Void> getRenderer() {
  return _bindings.renderer();
}

void registerFontFamily(
  Pointer<Void> renderer,
  String family,
  Uint8List bytes,
) {
  final native = family.toNativeUtf8();
  final ptr = malloc<Uint8>(bytes.length);
  final bytePtr = ptr.asTypedList(bytes.length);
  bytePtr.setAll(0, bytes);
  return _bindings.register_font_family(
    renderer,
    native.cast<Char>(),
    native.length,
    ptr.cast<Char>(),
    bytes.length,
  );
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

Pointer<Void> layout(Pointer<Void> renderer, String usfm, Dimensions dim) {
  final native = usfm.toNativeUtf8();
  final cdim = calloc<bind.Dimensions>();
  cdim.ref.width = dim.width;
  cdim.ref.height = dim.height;
  cdim.ref.header_height = dim.headerHeight;
  cdim.ref.drop_cap_padding = dim.dropCapPadding;
  return _bindings.layout(renderer, native.cast<Char>(), native.length, cdim);
}

Uint8List serializePages(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();

  _bindings.serialize_pages(painter, out.cast<Pointer<Char>>(), outLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> getArchivedPages(Uint8List pages) {
  final ptr = malloc<Uint8>(pages.length);
  final bytePtr = ptr.asTypedList(pages.length);
  bytePtr.setAll(0, pages);
  return _bindings.archived_pages(ptr.cast<Char>(), pages.length);
}

int getNumPages(Pointer<Void> pages) {
  return _bindings.num_pages(pages);
}

List<Text> getPage(Pointer<Void> renderer, Pointer<Void> pages, int n) {
  final out = malloc<Pointer<bind.Text>>();
  final outLen = malloc<Size>();

  _bindings.page(renderer, pages, n, out, outLen);

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

  _bindings.serialize_indices(painter, out.cast<Pointer<Char>>(), outLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> getArchivedIndices(Uint8List indices) {
  final bIndices = Bytes(indices);
  return _bindings.archived_indices(bIndices.bytes, bIndices.length);
}

int getIndex(Pointer<Void> indices, Pointer<Void> index) {
  return _bindings.get_index(indices, index);
}

Uint8List serializeVerses(Pointer<Void> painter) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();

  _bindings.serialize_verses(painter, out.cast<Pointer<Char>>(), outLen);
  return out.value.asTypedList(outLen.value);
}

Pointer<Void> loadModel(
  Uint8List embeddings,
  Uint8List verses,
  Uint8List model,
  Uint8List tokenizer,
) {
  final bEmbeddings = Bytes(embeddings);
  final bLines = Bytes(verses);
  final bModel = Bytes(model);
  final bTokenizer = Bytes(tokenizer);
  return _bindings.load_model(
    bEmbeddings.bytes,
    bEmbeddings.length,
    bLines.bytes,
    bLines.length,
    bModel.bytes,
    bModel.length,
    bTokenizer.bytes,
    bTokenizer.length,
  );
}

Pointer<Void> getResult(Pointer<Void> model, String query) {
  final native = query.toNativeUtf8();
  return _bindings.get_result(model, native.cast<Char>(), native.length);
}

class Bytes {
  late Pointer<Uint8> _bytes;
  late int length;

  Bytes(Uint8List list) {
    length = list.length;
    _bytes = malloc<Uint8>(length);
    final bytePtr = _bytes.asTypedList(length);
    bytePtr.setAll(0, list);
  }

  get bytes => _bytes.cast<Char>();
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
