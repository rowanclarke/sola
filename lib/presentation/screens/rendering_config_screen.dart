import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/models/rendering_config.dart';
import '../viewmodels/rendering_viewmodel.dart';

class RenderingConfigScreen extends StatefulWidget {
  const RenderingConfigScreen({super.key});

  @override
  State<RenderingConfigScreen> createState() => _RenderingConfigScreenState();
}

class _RenderingConfigScreenState extends State<RenderingConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RenderingViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Reading Settings')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Font Size: ${vm.config.fontSize}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: vm.config.fontSize.toDouble(),
                  min: 10,
                  max: 30,
                  divisions: 20,
                  label: vm.config.fontSize.toString(),
                  onChanged: (value) {
                    vm.setFormattingOption(
                      RenderingConfig(fontSize: value.round()),
                    );
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => context.goToReader(),
                  child: const Text('Start Reading'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
