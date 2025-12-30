import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/menu_view_model.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuViewModel>(
      builder: (context, menuVm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Menu')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Change Translation'),
                onTap: () => menuVm.navigateToTranslationSelection(context),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download Embedding Model'),
                onTap: () => menuVm.navigateToEmbeddingSelection(context),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Embed All Verses'),
                onTap: () => menuVm.navigateToVerseEmbedding(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
