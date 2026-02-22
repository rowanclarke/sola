import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/models/translation.dart';
import '../viewmodels/library_viewmodel.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadTranslations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sola Bible'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Downloaded'),
              Tab(text: 'Available'),
            ],
          ),
        ),
        body: Consumer<LibraryViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(vm.error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return TabBarView(
              children: [
                _buildDownloadedList(context, vm),
                _buildAvailableList(context, vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDownloadedList(BuildContext context, LibraryViewModel vm) {
    if (vm.downloadedTranslations.isEmpty) {
      return const Center(child: Text('No downloaded translations'));
    }
    return ListView.builder(
      itemCount: vm.downloadedTranslations.length,
      itemBuilder: (context, i) {
        final t = vm.downloadedTranslations[i];
        return _buildTranslationTile(context, t, true, () async {
          await vm.openTranslation(t);
          if (context.mounted) context.goToRenderingConfig();
        });
      },
    );
  }

  Widget _buildAvailableList(BuildContext context, LibraryViewModel vm) {
    if (vm.availableTranslations.isEmpty) {
      return const Center(child: Text('No translations available'));
    }
    return ListView.builder(
      itemCount: vm.availableTranslations.length,
      itemBuilder: (context, i) {
        final t = vm.availableTranslations[i];
        final isDownloading = vm.isDownloadingId(t.id);
        return _buildTranslationTile(context, t, false, () {
          vm.downloadTranslation(t);
        }, isDownloading: isDownloading);
      },
    );
  }

  Widget _buildTranslationTile(
    BuildContext context,
    Translation translation,
    bool isDownloaded,
    VoidCallback onAction, {
    bool isDownloading = false,
  }) {
    return ListTile(
      title: Text(translation.title),
      subtitle: Text('${translation.language} - ${translation.description}'),
      trailing: isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onAction,
              child: Text(isDownloaded ? 'Open' : 'Download'),
            ),
    );
  }
}
