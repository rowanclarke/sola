import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:path/path.dart' show basename;
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/bible_entry_model.dart';

class LibraryRepository {
  final FileService downloadedFileService;
  final FileService availableFileService;
  final FileService usfmFileService;
  final FileService rendererFileService;

  LibraryRepository(
    this.downloadedFileService,
    this.availableFileService,
    this.usfmFileService,
    this.rendererFileService,
  );

  Future<List<BibleEntryModel>> getDownloadedEntries() async {
    return await Future.wait((await _getDownloaded()).map(getEntry));
  }

  Future<List<BibleEntryModel>> getNonDownloadedEntries() async {
    final available = await _getAvailable();
    final downloaded = await _getDownloaded();
    available.removeWhere((id) => downloaded.contains(id));
    final a = await Future.wait(
      available.map((id) {
        return getEntry(id).timeout(const Duration(seconds: 2)).catchError((e) {
          print("Error on id=$id: $e");
          return null; // or some default value
        });
      }),
      eagerError: false, // let others finish
    );
    print("a");
    return a;
  }

  Future<BibleEntryModel> getEntry(String id) async {
    final r = await availableFileService.readAsString(id);
    return BibleEntryModel.fromJson(json.decode(r));
  }

  Future<List<String>> _getAvailable() async {
    return (await availableFileService.getFiles(
      false,
    )).map((f) => basename(f.path)).toList();
  }

  Future<List<String>> _getDownloaded() async {
    return (await downloadedFileService.getDirectories(
      false,
    )).map((d) => basename(d.path)).toList();
  }

  Future<BibleRepository> getBible(
    RendererService rendererService,
    BibleEntryModel bible,
  ) async {
    final bibleRepository = BibleRepository(
      await downloadedFileService.extractRemote(bible.url, path: bible.id),
      usfmFileService.directory(bible.id),
      rendererFileService.directory(bible.id),
      rendererService,
    );
    await bibleRepository.init();
    return bibleRepository;
    // return await bibleRepository.getBook("GEN", width, height);
    // final rendererRepository = RendererRepository(
    //   rendererService,
    // );
    // return (bibleRepository, rendererRepository);
  }
}
