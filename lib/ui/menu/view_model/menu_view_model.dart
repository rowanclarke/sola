import 'package:flutter/material.dart';
import 'package:sola/ui/translation_selection/widgets/translation_selection_screen.dart';

class MenuViewModel extends ChangeNotifier {
  void navigateToTranslationSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TranslationSelectionScreen()),
    );
  }

  void navigateToEmbeddingSelection(BuildContext context) {
    // TODO: Implement embedding selection screen navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Embedding model selection coming soon')),
    );
  }

  void navigateToVerseEmbedding(BuildContext context) {
    // TODO: Implement verse embedding screen navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verse embedding coming soon')),
    );
  }
}
