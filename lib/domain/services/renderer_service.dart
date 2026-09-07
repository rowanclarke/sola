import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextDecoration, TextStyle;
import 'package:flutter/services.dart';
import 'package:rust/rust.dart' as rust;

const _defaultStyles = [
  (rust.Style.NORMAL, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 16, height: 1.5, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.HEADER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 24, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.VERSE, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 10, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.CHAPTER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 48, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.WORD, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 16, height: 1.5, letterSpacing: 0, wordSpacing: 0, decoration: TextDecoration.underline)),
  (rust.Style.CALLER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 10, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.FOOTNOTE, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 12, height: 1.5, letterSpacing: 0, wordSpacing: 0)),
  (rust.Style.CROSSREF, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 12, height: 1.5, letterSpacing: 0, wordSpacing: 0)),
];

void registerDefaultStyles(Pointer<Void> renderer) {
  for (final (style, textStyle) in _defaultStyles) {
    rust.registerStyle(renderer, style, textStyle);
  }
}

class RendererService {
  final Pointer<Void> renderer = rust.getRenderer();
  bool _fontsRegistered = false;

  Future<void> registerFontFamilies() async {
    if (_fontsRegistered) return;
    debugPrint('[RendererSvc] Registering font families...');
    final fontData = await rootBundle.load(
      'assets/fonts/AveriaSerifLibre-Regular.ttf',
    );
    rust.registerFontFamily(
      renderer,
      'AveriaSerifLibre',
      fontData.buffer.asUint8List(),
    );
    _fontsRegistered = true;
    debugPrint('[RendererSvc] Fonts registered');
  }

  void registerStyles() {
    debugPrint('[RendererSvc] Registering text styles...');
    registerDefaultStyles(renderer);
    debugPrint('[RendererSvc] Styles registered');
  }

  Pointer<Void> layout(
    Pointer<Void> book,
    double width,
    double height, {
    int columns = 1,
    double gutter = 0,
  }) {
    debugPrint(
      '[RendererSvc] Layout: ${width.toInt()}x${height.toInt()} '
      'in $columns column(s)',
    );
    final painter = rust.layout(
      renderer,
      book,
      rust.Dimensions(
        width,
        height,
        headerHeight: height / 5,
        dropCapPadding: 20,
        columns: columns,
        gutter: gutter,
      ),
    );
    debugPrint('[RendererSvc] Layout complete');
    return painter;
  }

  /// Materializes one page from its own segment of a book's `pages` file.
  List<rust.Text> pageFromBytes(Uint8List bytes) {
    return rust.pageFromBytes(renderer, bytes);
  }

  String getBookTitle(Uint8List indicesBytes) {
    return rust.indicesBookTitle(indicesBytes);
  }
}
