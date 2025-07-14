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

  Future<Uint8List> render(String usfm, double width, double height) async {
    final dimensions = rust.Dimensions(
      width,
      height,
      headerHeight: height / 5,
      dropCapPadding: 20,
    );
    final rendered = rust.layout(renderer, usfm, dimensions);
    return rust.serializePages(rendered);
  }

  Pointer<Void>? _pages;
  int? _numPages;

  set rendered(Uint8List rendered) {
    _pages = rust.getArchivedPages(rendered);
    _numPages = rust.getNumPages(_pages!);
  }

  get numPages => _numPages;

  Future<List<rust.Text>> getPage(int n) async {
    return rust.getPage(renderer, _pages!, n);
  }
}
