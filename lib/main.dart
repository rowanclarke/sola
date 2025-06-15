import 'package:asset_cache/asset_cache.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:asset_cache/asset_cache.dart';
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
      final contents = String.fromCharCodes(bytes);
      bible[book] = contents;
    }
    return bible;
  }
}

class MyApp extends StatelessWidget {
  final bibleCache = BibleCache();

  Future<String> text() async {
    final web = await bibleCache.load(
      'https://ebible.org/Scriptures/engwebpb_usfm.zip',
    );
    return web['02-GENengwebpb.usfm']!.substring(0, 100);
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
