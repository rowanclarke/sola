/// Main entry point for the Sola Bible application.
///
/// This file initializes the Flutter app, sets up dependency injection,
/// and configures navigation and theming.

import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/app_routes.dart';

/// Application entry point.
///
/// Calls AppBootstrap to initialize all dependencies, then runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all dependencies (services, repositories, viewmodels, providers)
  final rootWidget = await AppBootstrap.initialize();

  runApp(rootWidget);
}

/// Root widget for the Sola application.
///
/// Wraps the entire app in MultiProvider (which provides all viewmodels
/// to the widget tree) and configures Material Design theme and routing.
class SolaApp extends StatelessWidget {
  /// Creates the root widget.
  ///
  /// This widget expects to be wrapped by AppBootstrap's MultiProvider tree,
  /// which makes all viewmodels available to the entire widget tree.
  const SolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }

  /// Builds the Material Design theme for the application.
  ///
  /// Configures:
  /// - Color scheme (primary, secondary, error)
  /// - Typography (font family, text styles)
  /// - Component themes (app bar, buttons, cards, etc.)
  static ThemeData get _themeData => throw UnimplementedError();

  /// Builds the dark theme variant.
  ///
  /// Optional dark mode support. If not implemented, uses default dark theme.
  static ThemeData get _darkThemeData => throw UnimplementedError();
}
