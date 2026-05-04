class SearchInfo {
  final String translationId;
  final String downloadUrl;

  const SearchInfo({
    required this.translationId,
    required this.downloadUrl,
  });

  static const defaultSearch = SearchInfo(
    translationId: 'engwebpb',
    downloadUrl:
        'https://github.com/rowanclarke/sola/releases/download/asset-embeddings-v0.0.2/engwebpb.zip',
  );
}
