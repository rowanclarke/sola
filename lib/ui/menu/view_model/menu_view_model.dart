import 'package:flutter/material.dart';
import 'package:sola/ui/translation_selection/widgets/translation_selection_screen.dart';

class MenuViewModel extends ChangeNotifier {
  void navigateToTranslationSelection(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TranslationSelectionScreen()),
    );
  }
}
