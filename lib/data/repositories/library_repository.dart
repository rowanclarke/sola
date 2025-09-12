import 'dart:convert';

import 'package:sola/data/services/file_service.dart';
import 'package:path/path.dart' show basename;
import 'package:sola/domain/models/bible_entry_model.dart';

class LibraryRepository {
  final FileService downloadedFileService;
  final FileService availableFileService;

  LibraryRepository(this.downloadedFileService, this.availableFileService);

  Future<List<BibleEntryModel>> getDownloadedEntries() async {
    return await Future.wait((await _getDownloaded()).map(getEntry));
  }

  Future<List<BibleEntryModel>> getNonDownloadedEntries() async {
    final available = await _getAvailable();
    final downloaded = await _getDownloaded();
    available.removeWhere((id) => downloaded.contains(id));
    return await Future.wait(available.map(getEntry));
  }

  Future<BibleEntryModel> getEntry(String id) async {
    return BibleEntryModel.fromJson(
      json.decode(await availableFileService.readAsString(id)),
    );
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
}
