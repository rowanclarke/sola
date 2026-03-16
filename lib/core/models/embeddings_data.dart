import 'dart:typed_data';

class EmbeddingsData {
  final Uint8List embeddingsBytes;
  final Uint8List indicesBytes;

  EmbeddingsData({required this.embeddingsBytes, required this.indicesBytes});
}
