import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'rust_bindings_generated.dart' as bind;
export 'rust_bindings_generated.dart' show Style;

class CharsMapResponse {
  final Pointer<Void> map;
  final Uint32List chars;

  CharsMapResponse(this.map, this.chars);
}

class Dimensions {
  final double width;
  final double height;
  final double lineHeight;
  final double headerHeight;
  final double headerPadding;

  Dimensions(
    this.width,
    this.height,
    this.lineHeight,
    this.headerHeight,
    this.headerPadding,
  );
}

CharsMapResponse charsMap(String usfm) {
  final out = malloc<Pointer<UnsignedInt>>();
  final outLen = malloc<Size>();

  final native = usfm.toNativeUtf8();

  final map = _bindings.chars_map(
    native.cast<UnsignedChar>(),
    native.length,
    out,
    outLen,
  );

  return CharsMapResponse(
    map,
    out.value.cast<Uint32>().asTypedList(outLen.value),
  );
}

void insert(Pointer<Void> map, int chr, bind.Style style, double width) =>
    _bindings.insert(map, chr, style, width);

Pointer<Void> layout(Pointer<Void> map, String usfm, Dimensions dim) {
  final native = usfm.toNativeUtf8();
  final cdim = calloc<bind.Dimensions>();
  cdim.ref.width = dim.width;
  cdim.ref.height = dim.height;
  cdim.ref.line_height = dim.lineHeight;
  cdim.ref.header_height = dim.headerHeight;
  cdim.ref.header_padding = dim.headerPadding;
  return _bindings.layout(
    map,
    native.cast<UnsignedChar>(),
    native.length,
    cdim,
  );
}

List<bind.Text> page(Pointer<Void> layout) {
  final out = malloc<Pointer<bind.Text>>();
  final outLen = malloc<Size>();

  _bindings.page(layout, out, outLen);

  return List.generate(outLen.value, (i) => (out.value + i).ref);
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
