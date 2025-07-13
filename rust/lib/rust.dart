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

Pointer<Void> layout(Pointer<Void> map, String usfm, Dimensions dim) {
  final native = usfm.toNativeUtf8();
  final cdim = calloc<bind.Dimensions>();
  cdim.ref.width = dim.width;
  cdim.ref.height = dim.height;
  cdim.ref.header_height = dim.headerHeight;
  cdim.ref.drop_cap_padding = dim.dropCapPadding;
  return _bindings.layout(map, native.cast<Char>(), native.length, cdim);
}

Uint8List serializePages(Pointer<Void> layout) {
  final out = malloc<Pointer<Uint8>>();
  final outLen = malloc<Size>();

  _bindings.serialize_pages(layout, out.cast<Pointer<Char>>(), outLen);
  return out.value.asTypedList(outLen.value);
}

List<Text> page(Pointer<Void> renderer, Uint8List pages, int n) {
  final ptr = malloc<Uint8>(pages.length);
  final bytePtr = ptr.asTypedList(pages.length);
  bytePtr.setAll(0, pages);
  final out = malloc<Pointer<bind.Text>>();
  final outLen = malloc<Size>();

  _bindings.page(renderer, ptr.cast<Char>(), pages.length, n, out, outLen);

  return List.generate(outLen.value, (i) {
    final text = (out.value + i).ref;
    return Text(
      text.text.cast<Utf8>().toDartString(length: text.len),
      text.rect,
      toTextStyle(text.style),
    );
  });
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
