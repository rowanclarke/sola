import 'package:flutter/material.dart';

import '../presentation/screens/complete_screen.dart';
import '../presentation/screens/language_screen.dart';
import '../presentation/screens/reader_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/translation_screen.dart';

abstract class AppRoutes {
  static const String language = '/language';
  static const String translation = '/translation';
  static const String complete = '/complete';
  static const String reader = '/reader';
  static const String settings = '/settings';
}

abstract class AppRouteGenerator {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.language:
        return MaterialPageRoute(builder: (_) => const LanguageScreen());
      case AppRoutes.translation:
        return MaterialPageRoute(builder: (_) => const TranslationScreen());
      case AppRoutes.complete:
        return MaterialPageRoute(builder: (_) => const CompleteScreen());
      case AppRoutes.reader:
        return MaterialPageRoute(builder: (_) => const ReaderScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return null;
    }
  }
}

extension NavigationExtension on BuildContext {
  void goToLanguage() =>
      Navigator.pushNamedAndRemoveUntil(this, AppRoutes.language, (_) => false);

  void goToTranslation() =>
      Navigator.pushNamed(this, AppRoutes.translation);

  void goToComplete() =>
      Navigator.pushNamed(this, AppRoutes.complete);

  void goToReader() =>
      Navigator.pushNamedAndRemoveUntil(this, AppRoutes.reader, (_) => false);

  void goToSettings() =>
      Navigator.pushNamed(this, AppRoutes.settings);

  void goBack() => Navigator.pop(this);
}
