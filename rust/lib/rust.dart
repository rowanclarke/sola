import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'rust_bindings_generated.dart';

class CharsMapResponse {
  final Pointer<Void> map;
  final Uint32List chars;

  CharsMapResponse(this.map, this.chars);
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

void insert(Pointer<Void> map, int chr, double width, double height) =>
    _bindings.insert(map, chr, width, height);

Pointer<Void> layout(Pointer<Void> map, String usfm) {
  final native = usfm.toNativeUtf8();
  return _bindings.layout(map, native.cast<UnsignedChar>(), native.length);
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

final RustBindings _bindings = RustBindings(_dylib);
