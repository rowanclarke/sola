import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/menu_view_model.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Menu')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Change Translation'),
                onTap: () => vm.navigateToTranslationSelection(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
