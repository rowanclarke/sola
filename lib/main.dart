import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:asset_cache/asset_cache.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class BibleCache extends GenericCache<Map<String, String>> {
  BibleCache();

  @override
  Future<Map<String, String>> loadAsset(String key) async {
    final response = await http.get(Uri.parse(key));

    if (response.statusCode != 200) {
      throw Exception('Failed to download ZIP file');
    }
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final bible = <String, String>{};
    for (final file in archive) {
      final book = file.name;
      final bytes = file.content as List<int>;
      final contents = utf8.decode(bytes);
      bible[book] = contents;
    }
    return bible;
  }
}

class MyApp extends StatelessWidget {
  final bibleCache = BibleCache();
  final lineHeight = 26.0;
  final headerHeight = 32.0;
  final fontSize = 16.0;
  final fontSizeSuperscript = 10.0;
  final fontSizeHeader = 32.0;
  final fontSizeChapter = 64.0;
  final headerPadding = 10.0;

  late final defaultStyle = TextStyle(
    fontFamily: 'AveriaSerifLibre',
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    wordSpacing: 0,
    height: lineHeight / fontSize,
  );

  TextStyle styled(Style style) {
    switch (style) {
      case Style.VERSE:
        return defaultStyle.copyWith(fontSize: fontSizeSuperscript, height: 1);
      case Style.NORMAL:
        return defaultStyle.copyWith(fontSize: fontSize);
      case Style.HEADER:
        return defaultStyle.copyWith(fontSize: fontSizeHeader, height: 1);
      case Style.CHAPTER:
        return defaultStyle.copyWith(
          fontSize: fontSizeChapter,
          height: 2 * lineHeight / fontSizeChapter,
        );
    }
  }

  void measure(Pointer<Void> map, Uint32List chars, Style style) {
    final text = String.fromCharCodes(chars);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: styled(style)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    for (int i = 0; i < text.length; i++) {
      final caretStart = textPainter.getOffsetForCaret(
        TextPosition(offset: i),
        Rect.zero,
      );
      final caretEnd = textPainter.getOffsetForCaret(
        TextPosition(offset: i + 1),
        Rect.zero,
      );
      final width = caretEnd.dx - caretStart.dx;
      insert(map, chars[i], style, width);
    }
  }

  Future<Widget> pages(double width, double height) async {
    final web = await bibleCache.load(
      'http://192.168.1.42:8000/engwebpb_usfm.zip',
    );
    final gen = web['02-GENengwebpb.usfm']!;
    final response = charsMap(gen);
    final map = response.map;
    for (final style in Style.values) {
      measure(map, response.chars, style);
    }
    final rendered = layout(
      map,
      gen,
      Dimensions(width, height, lineHeight, headerHeight, headerPadding),
    );
    final texts = page(rendered);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children:
            texts.map((text) {
              final rect = text.rect;
              final spacing = text.style.word_spacing;
              final style = styled(Style.fromValue(text.style.style));
              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: Text(
                  text.text.cast<Utf8>().toDartString(length: text.len),
                  style: style.copyWith(wordSpacing: spacing),
                  softWrap: false,
                ),
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'AveriaSerifLibre'),
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (width < 10 || height < 10) {
              return Container();
            }
            return FutureBuilder<Widget>(
              future: pages(width, height),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return SelectableText('Error: ${snapshot.error}');
                } else {
                  return snapshot.data ??
                      Text('Done', style: TextStyle(fontSize: 24));
                }
              },
            );
          },
        ),
      ),
    );
  }
}
