import 'dart:convert';
import 'package:asset_cache/asset_cache.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

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

  Future<Widget> pages(double width, double height) async {
    final web = await bibleCache.load(
      'http://192.168.1.42:8000/engwebpb_usfm.zip',
    );
    final gen = web['02-GENengwebpb.usfm']!;

    final renderer = getRenderer();
    final font = await rootBundle
        .load('assets/fonts/AveriaSerifLibre-Regular.ttf')
        .then((b) => b.buffer.asUint8List());
    registerFontFamily(renderer, 'AveriaSerifLibre', font);
    registerStyle(
      renderer,
      Style.NORMAL,
      TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 16,
        height: 1,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    registerStyle(
      renderer,
      Style.HEADER,
      TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 24,
        height: 1,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    registerStyle(
      renderer,
      Style.VERSE,
      TextStyle(
        fontFamily: 'AveriaSerifLibre',
        fontSize: 8,
        height: 1,
        letterSpacing: 0,
        wordSpacing: 0,
      ),
    );
    final rendered = layout(
      renderer,
      gen,
      Dimensions(width, height, headerHeight: height / 5, headerPadding: 10),
    );
    final texts = page(rendered);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children:
            texts.map((text) {
              final rect = text.rect;
              final style = toTextStyle(text.style);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
