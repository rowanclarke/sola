class EmbeddingsInfo {
  final String translationId;
  final String downloadUrl;

  const EmbeddingsInfo({
    required this.translationId,
    required this.downloadUrl,
  });

  static const defaultEmbeddings = EmbeddingsInfo(
    translationId: 'engwebpb',
    downloadUrl:
        'https://github.com/rowanclarke/sola/releases/download/asset-embeddings-v0.0.1/engwebpb.zip',
  );
}
