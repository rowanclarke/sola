class ModelInfo {
  final String id;
  final String downloadUrl;

  const ModelInfo({required this.id, required this.downloadUrl});

  static const defaultModel = ModelInfo(
    id: 'all-minilm-l6-v2',
    downloadUrl:
        'https://github.com/rowanclarke/sola/releases/download/asset-model-v0.0.1/model.zip',
  );
}
