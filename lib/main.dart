import 'dart:convert';
import 'dart:ffi';

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
  final style = TextStyle(fontSize: 32, letterSpacing: 0, wordSpacing: 0);

  Future<Widget> text() async {
    final web = await bibleCache.load('http://0.0.0.0:8000/engwebpb_usfm.zip');
    final gen = web['02-GENengwebpb.usfm']!;
    final response = charsMap(gen);
    final map = response.map;
    final chars = response.chars;
    final text = String.fromCharCodes(chars);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
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
      insert(map, chars[i], width, 0);
    }

    final l = layout(map, gen);
    final texts = page(l);

    return SizedBox(
      width: 500,
      height: 800,
      child: Stack(
        children:
            texts.map((text) {
              final s = text.text.cast<Utf8>().toDartString(length: text.len);
              final rect = text.rect;
              final spacing = text.style.word_spacing;
              print(spacing);

              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width + 50,
                height: rect.height,
                child: Text(
                  s,
                  style: style.copyWith(wordSpacing: spacing, letterSpacing: 0),
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
      home: Scaffold(
        body: Center(
          child: FutureBuilder<Widget>(
            future: text(),
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
          ),
        ),
      ),
    );
  }
}
