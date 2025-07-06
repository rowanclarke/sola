import 'dart:io';

import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:sola/data/services/renderer_service.dart';
import '../../domain/models/page_model.dart';
import '../services/bible_service.dart';

class PageRepository {
  final BibleService service;
  final RendererService renderer;
  final Directory documents;

  final String url;
  late String bible;
  final String book;

  PageRepository(
    this.service,
    this.renderer,
    this.documents,
    this.url,
    this.book,
  ) {
    bible = Uri.parse(url).pathSegments.last;
    bible = bible.substring(0, bible.lastIndexOf('.'));

    renderer.registerStyles();
  }

  Future<String> _getFilePath() async {
    return '${documents.path}/pages_$book';
  }

  Future<String> _getBiblePath() async {
    return '${documents.path}/bibles_$bible';
  }

  Future<List<PageModel>> getPages(double width, double height) async {
    final filePath = await _getFilePath();
    final file = File(filePath);

    if (!await file.exists()) {
      renderer.registerFontFamilies();
      final bible = await getBible();
      final render = await renderer.render(bible[book]!, width, height);
      await file.writeAsBytes(render);
    }

    renderer.rendered = await file.readAsBytes();
    return [
      PageModel(page: await renderer.getPage(0)),
      PageModel(page: await renderer.getPage(1)),
    ];
  }

  Future<Map<String, String>> getBible() async {
    final filePath = await _getBiblePath();
    final file = File(filePath);

    if (!await file.exists()) {
      final bible = await service.fetchBible(url);
      await file.writeAsBytes(serialize(bible));
      return bible;
    } else {
      final decoded = deserialize(await file.readAsBytes());
      return Map<String, String>.from(decoded);
    }
  }
}
