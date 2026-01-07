import 'package:flutter/foundation.dart';
import 'package:sola/core/models/rendering_config.dart';
import 'package:sola/core/models/rendering_config.dart' show RenderingProgress;
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// RenderingViewModel orchestrates the rendering configuration and process.
/// Manages formatting options, rendering progress, and navigation to the reader screen.
class RenderingViewModel extends ChangeNotifier {
  final RendererRepository _rendererRepository;
  final SessionRepository _sessionRepository;

  RenderingConfig? _config;
  RenderingProgress? _progress;
  bool _isRendering = false;

  RenderingViewModel({
    required RendererRepository rendererRepository,
    required SessionRepository sessionRepository,
  }) : _rendererRepository = rendererRepository,
       _sessionRepository = sessionRepository;

  RenderingConfig? get config => _config;
  RenderingProgress? get progress => _progress;
  bool get isRendering => _isRendering;

  /// Sets rendering configuration options.
  void setFormattingOption(RenderingConfig config) {
    throw UnimplementedError();
  }

  /// Starts the rendering process for the current translation.
  /// Reports progress to listeners via the onProgress callback.
  Future<void> startRendering() {
    throw UnimplementedError();
  }

  /// Generates and returns a preview of the first rendered page.
  /// Useful for showing users a sample before full rendering.
  Future<String?> previewFirstPage() {
    throw UnimplementedError();
  }

  /// Handles rendering completion, updating the session and notifying listeners.
  void _onRenderingComplete() {
    throw UnimplementedError();
  }
}
