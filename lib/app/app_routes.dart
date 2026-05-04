import 'package:flutter/material.dart';

import '../presentation/screens/library_screen.dart';
import '../presentation/screens/reader_screen.dart';
import '../presentation/screens/rendering_config_screen.dart';

abstract class AppRoutes {
  static const String library = '/';
  static const String reader = '/reader';
  static const String renderingConfig = '/rendering_config';
  static const String search = '/search';
}

abstract class AppRouteGenerator {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.library:
        return MaterialPageRoute(builder: (_) => const LibraryScreen());
      case AppRoutes.reader:
        return MaterialPageRoute(builder: (_) => const ReaderScreen());
      case AppRoutes.renderingConfig:
        return MaterialPageRoute(builder: (_) => const RenderingConfigScreen());
      default:
        return null;
    }
  }
}

extension NavigationExtension on BuildContext {
  void goToLibrary() =>
      Navigator.pushNamedAndRemoveUntil(this, AppRoutes.library, (_) => false);

  void goToReader() => Navigator.pushNamed(this, AppRoutes.reader);

  void goToRenderingConfig() =>
      Navigator.pushNamed(this, AppRoutes.renderingConfig);

  void goBack() => Navigator.pop(this);
}
