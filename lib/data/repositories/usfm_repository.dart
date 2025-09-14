import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/usfm_service.dart';
import 'package:sola/domain/providers/book_provider.dart';

class UsfmRepository implements BookProvider {
  final FileService rawService;
  final UsfmService usfmService;
  final FileService fileService;

  UsfmRepository(this.rawService, this.usfmService, this.fileService);

  Future<void> loadBooks() async {
    // print(await fileService.isInitialized());
    if (!await fileService.isInitialized()) {
      // final usfm = await rawService.file("02-GENengwebpb.usfm").readAsString();
      // Uint8List bytes = await usfmService.serialize(usfm);
      // Pointer<Void> archived = await usfmService.getArchived(bytes);
      // String identifier = usfmService.getIdentifier(archived);
      for (File file in rawService.getFiles()) {
        print(file.uri);
        Uint8List bytes = await usfmService.serialize(
          await file.readAsString(),
        );
        Pointer<Void> archived = await usfmService.getArchived(bytes);
        String identifier = usfmService.getIdentifier(archived);
        await fileService.file(identifier).writeAsBytes(bytes);
      }
    }
  }

  @override
  Future<Pointer<Void>> getBook(String book) async {
    print("Getting book $book");
    Uint8List bytes = await fileService.readAsBytes(book);
    return await usfmService.getArchived(bytes);
  }
}
