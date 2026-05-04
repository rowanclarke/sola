import 'package:flutter/foundation.dart';
import 'package:sola/core/models/rendering_config.dart';

class RenderingViewModel extends ChangeNotifier {
  RenderingConfig _config = const RenderingConfig(fontSize: 16);

  RenderingConfig get config => _config;

  void setFormattingOption(RenderingConfig config) {
    _config = config;
    notifyListeners();
  }
}
