import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
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
    print("Register fonts");
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
    print("Registered styles");
  }

  Future<Uint8List> render(String usfm, double width, double height) async {
    final dimensions = rust.Dimensions(
      width,
      height,
      headerHeight: height / 5,
      headerPadding: 20,
    );
    final rendered = rust.layout(renderer, usfm, dimensions);
    print("Serialised pages");
    return rust.serializePages(rendered);
  }

  Uint8List? _rendered;
  set rendered(Uint8List rendered) {
    print("Set rendered");
    _rendered = rendered;
  }

  Future<Widget> getPage(int n, double width, double height) async {
    print("Getting page");
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: rust.page(renderer, _rendered!, n).map((text) {
          final rect = text.rect;
          final style = rust.toTextStyle(text.style);
          return Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: Text(
              text.text.cast<Utf8>().toDartString(length: text.len),
              style: style,
              softWrap: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
