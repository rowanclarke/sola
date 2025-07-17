import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter/services.dart';
import 'package:rust/rust.dart' as rust;

import 'dart:ffi';

class RendererService {
  late Pointer<Void> renderer = rust.getRenderer();

  RendererService();

  Future<void> registerFontFamilies() async {
    final font = await rootBundle
        .load('assets/fonts/AveriaSerifLibre-Regular.ttf')
        .then((b) => b.buffer.asUint8List());
    rust.registerFontFamily(renderer, 'AveriaSerifLibre', font);
  }

  Future<void> registerStyles() async {
    rust.registerStyle(
      renderer,
      rust.Style.NORMAL,
      TextStyle(
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
      TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 24,
        height: 1,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    rust.registerStyle(
      renderer,
      rust.Style.VERSE,
      TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 10,
        height: 1,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
  }

  late Pointer<Void> _painter;

  Future<void> render(String usfm, double width, double height) async {
    final dimensions = rust.Dimensions(
      width,
      height,
      headerHeight: height / 5,
      dropCapPadding: 20,
    );
    _painter = rust.layout(renderer, usfm, dimensions);
  }

  Uint8List getPages() {
    return rust.serializePages(_painter);
  }

  Uint8List getIndices() {
    return rust.serializeIndices(_painter);
  }

  Uint8List getVerses() {
    return rust.serializeVerses(_painter);
  }

  Pointer<Void> getArchivedPages(Uint8List pages) {
    return rust.getArchivedPages(pages);
  }

  Pointer<Void> getArchivedIndices(Uint8List indices) {
    return rust.getArchivedIndices(indices);
  }

  int getNumPages(Pointer<Void> pages) {
    return rust.getNumPages(pages);
  }

  Future<List<rust.Text>> getPage(Pointer<Void> pages, int n) async {
    return rust.getPage(renderer, pages, n);
  }
}
