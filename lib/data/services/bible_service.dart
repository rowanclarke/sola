import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

class BibleService {
  Future<Map<String, String>> fetchBible(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download ZIP file');
    }
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);

    final bible = <String, String>{};

    for (final file in archive) {
      final name = file.name;
      final bytes = file.content as List<int>;
      final content = utf8.decode(bytes);
      bible[name] = content;
    }

    return bible;
  }
}
