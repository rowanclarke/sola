import 'dart:convert';

import 'package:asset_cache/asset_cache.dart';
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
  final style = TextStyle(fontSize: 32, letterSpacing: 0);

  Future<String> text() async {
    final web = await bibleCache.load('http://0.0.0.0:8000/engwebpb_usfm.zip');
    final response = charsMap(web['02-GENengwebpb.usfm']!);
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

    return "Hi";
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FutureBuilder<String>(
            future: text(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return SelectableText('Error: ${snapshot.error}');
              } else {
                return Text(
                  snapshot.data ?? 'Done',
                  style: TextStyle(fontSize: 24),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
