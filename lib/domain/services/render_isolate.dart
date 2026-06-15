import 'dart:typed_data';

import 'package:rust/rust.dart' as rust;
import 'package:sola/domain/services/renderer_service.dart' show registerDefaultStyles;

class RenderInput {
  final Uint8List bookBytes;
  final Uint8List fontBytes;
  final double width;
  final double height;

  RenderInput({
    required this.bookBytes,
    required this.fontBytes,
    required this.width,
    required this.height,
  });
}

class RenderOutput {
  final Uint8List pages;
  final Uint8List indices;
  final Uint8List verses;
  final Uint8List verseRanges;

  RenderOutput({
    required this.pages,
    required this.indices,
    required this.verses,
    required this.verseRanges,
  });
}

RenderOutput renderInBackground(RenderInput input) {
  print('[Isolate] Rendering ${input.width.toInt()}x${input.height.toInt()}');
  final renderer = rust.getRenderer();
  rust.registerFontFamily(renderer, 'AveriaSerifLibre', input.fontBytes);
  registerDefaultStyles(renderer);

  final book = rust.getArchivedBook(input.bookBytes);
  print('[Isolate] Layout starting...');
  final painter = rust.layout(
    renderer,
    book,
    rust.Dimensions(
      input.width,
      input.height,
      headerHeight: input.height / 5,
      dropCapPadding: 20,
    ),
  );
  print('[Isolate] Serializing pages/indices/verses...');

  final output = RenderOutput(
    pages: rust.serializePages(painter),
    indices: rust.serializeIndices(painter),
    verses: rust.serializeVerses(painter),
    verseRanges: rust.serializeVerseRanges(painter),
  );
  print('[Isolate] Render complete');
  return output;
}

class SerializeInput {
  final Map<String, String> usfmFiles;

  SerializeInput({required this.usfmFiles});
}

class SerializeOutput {
  final Map<String, Uint8List> serializedBooks;

  SerializeOutput({required this.serializedBooks});
}

SerializeOutput serializeInBackground(SerializeInput input) {
  print('[Isolate] Serializing ${input.usfmFiles.length} USFM files...');
  final result = <String, Uint8List>{};
  for (final entry in input.usfmFiles.entries) {
    final bytes = rust.serializeUsfm(entry.value);
    final book = rust.getArchivedBook(bytes);
    final id = rust.getBookIdentifier(book);
    result[id] = bytes;
    print('[Isolate] Serialized: $id');
  }
  print('[Isolate] Serialization complete: ${result.length} books');
  return SerializeOutput(serializedBooks: result);
}
