import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter/services.dart';
import 'package:rust/rust.dart' as rust;

class RendererResponse {
  final Pointer<Void> _painter;

  RendererResponse(this._painter);

  Uint8List getPages() => rust.serializePages(_painter);
  Uint8List getIndices() => rust.serializeIndices(_painter);
  Uint8List getVerses() => rust.serializeVerses(_painter);
}

class RendererService {
  final Pointer<Void> renderer = rust.getRenderer();
  bool _fontsRegistered = false;

  Future<void> registerFontFamilies() async {
    if (_fontsRegistered) return;
    final fontData = await rootBundle.load(
      'assets/fonts/AveriaSerifLibre-Regular.ttf',
    );
    rust.registerFontFamily(
      renderer,
      'AveriaSerifLibre',
      fontData.buffer.asUint8List(),
    );
    _fontsRegistered = true;
  }

  void registerStyles() {
    rust.registerStyle(
      renderer,
      rust.Style.NORMAL,
      const TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    rust.registerStyle(
      renderer,
      rust.Style.HEADER,
      const TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 24,
        height: 1.0,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    rust.registerStyle(
      renderer,
      rust.Style.VERSE,
      const TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 10,
        height: 1.0,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    rust.registerStyle(
      renderer,
      rust.Style.CHAPTER,
      const TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 48,
        height: 1.0,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
  }

  RendererResponse layout(Pointer<Void> book, double width, double height) {
    print("Hi");
    final painter = rust.layout(
      renderer,
      book,
      rust.Dimensions(
        width,
        height,
        headerHeight: height / 5,
        dropCapPadding: 20,
      ),
    );
    print("Hello");
    return RendererResponse(painter);
  }

  Pointer<Void> getArchivedPages(Uint8List bytes) {
    return rust.getArchivedPages(bytes);
  }

  Pointer<Void> getArchivedIndices(Uint8List bytes) {
    return rust.getArchivedIndices(bytes);
  }

  int getNumPages(Pointer<Void> pages) {
    return rust.getNumPages(pages);
  }

  List<rust.Text> getPage(Pointer<Void> pages, int n) {
    return rust.getPage(renderer, pages, n);
  }
}
