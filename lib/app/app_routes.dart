/// Navigation route definitions for the Sola application.
///
/// This file defines all named routes used throughout the application.
/// Routes are used for navigation between screens and can include parameters.
///
/// Route hierarchy:
/// - `/` (root) → LibraryScreen
/// - `/reader` → ReaderScreen (requires translation to be open)
/// - `/rendering_config` → RenderingConfigScreen
/// - `/search` → SearchScreen

import 'package:flutter/material.dart';

import '../presentation/screens/library_screen.dart';
import '../presentation/screens/reader_screen.dart';
import '../presentation/screens/rendering_config_screen.dart';
import '../presentation/screens/search_screen.dart';

/// Named route constants used throughout the application.
///
/// Use these constants instead of magic strings for route navigation:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.reader);
/// ```
abstract class AppRoutes {
  /// Root route - Translation library screen.
  ///
  /// Displays available translations, allows downloading and opening.
  /// This is the first screen shown after application launch.
  static const String library = '/';

  /// Reader screen - Display rendered pages.
  ///
  /// Shows current page with navigation. Requires a translation to be open.
  /// Can be pushed with optional parameters:
  /// ```dart
  /// Navigator.pushNamed(
  ///   context,
  ///   AppRoutes.reader,
  ///   arguments: {'book': 'Genesis', 'page': 5},
  /// );
  /// ```
  static const String reader = '/reader';

  /// Rendering configuration screen.
  ///
  /// Allows user to configure rendering options (font, size, margins, etc)
  /// and preview results.
  static const String renderingConfig = '/rendering_config';

  /// Search screen.
  ///
  /// Allows user to search verses and navigate to results.
  static const String search = '/search';
}

/// Route generator for the Sola application.
///
/// This class generates route handlers based on route names.
/// It's used by MaterialApp.onGenerateRoute to create screens dynamically.
///
/// Example:
/// ```dart
/// MaterialApp(
///   onGenerateRoute: AppRouteGenerator.generateRoute,
///   home: LibraryScreen(),
/// )
/// ```
abstract class AppRouteGenerator {
  /// Generates a route based on the route settings.
  ///
  /// Returns a [MaterialPageRoute] wrapping the appropriate screen.
  /// Unknown routes return null (causing a "route not found" error).
  ///
  /// Parameters:
  ///   - [settings.name]: The route name (e.g., '/reader')
  ///   - [settings.arguments]: Optional arguments passed with navigation
  ///
  /// Returns:
  ///   - [MaterialPageRoute<dynamic>] if route is recognized
  ///   - `null` if route is not found
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    throw UnimplementedError();
  }

  /// Creates a route to the library screen.
  ///
  /// The library screen shows available translations.
  static MaterialPageRoute<dynamic> _createLibraryRoute() {
    throw UnimplementedError();
  }

  /// Creates a route to the reader screen.
  ///
  /// Optional arguments:
  ///   - `book` (String): Book name to navigate to
  ///   - `page` (int): Page number to navigate to
  static MaterialPageRoute<dynamic> _createReaderRoute(Object? arguments) {
    throw UnimplementedError();
  }

  /// Creates a route to the rendering config screen.
  static MaterialPageRoute<dynamic> _createRenderingConfigRoute() {
    throw UnimplementedError();
  }

  /// Creates a route to the search screen.
  static MaterialPageRoute<dynamic> _createSearchRoute() {
    throw UnimplementedError();
  }
}

/// Navigation helper methods.
///
/// Provides convenient shortcuts for common navigation operations.
extension NavigationExtension on BuildContext {
  /// Navigate to the library screen.
  void goToLibrary() =>
      Navigator.pushNamedAndRemoveUntil(this, AppRoutes.library, (_) => false);

  /// Navigate to the reader screen.
  void goToReader({Map<String, dynamic>? arguments}) =>
      Navigator.pushNamed(this, AppRoutes.reader, arguments: arguments);

  /// Navigate to the rendering config screen.
  void goToRenderingConfig() =>
      Navigator.pushNamed(this, AppRoutes.renderingConfig);

  /// Navigate to the search screen.
  void goToSearch() => Navigator.pushNamed(this, AppRoutes.search);

  /// Go back to the previous screen.
  void goBack() => Navigator.pop(this);
}
