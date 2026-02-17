import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';

/// Application entry point.
///
/// Calls AppBootstrap to initialize all dependencies, then runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final rootWidget = await AppBootstrap.initialize();

  runApp(rootWidget);
}
