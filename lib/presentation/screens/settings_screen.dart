import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../viewmodels/settings_viewmodel.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _card = Colors.white;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SettingsViewModel>();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: _line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _CacheRow(
                    title: 'Serialization cache',
                    subtitle: 'Parsed Bible book data',
                    onClear: () => _clearCache(
                      context,
                      'Serialization cache cleared',
                      vm.clearSerializationCache,
                    ),
                  ),
                  _CacheRow(
                    title: 'Rendering cache',
                    subtitle: 'Laid-out page images',
                    onClear: () => _clearCache(
                      context,
                      'Rendering cache cleared',
                      vm.clearRenderingCache,
                    ),
                  ),
                  _CacheRow(
                    title: 'Search cache',
                    subtitle: 'Search index and embeddings',
                    onClear: () => _clearCache(
                      context,
                      'Search cache cleared',
                      vm.clearSearchCache,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: _ink),
            onPressed: () => context.goBack(),
          ),
          const SizedBox(width: 4),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(
    BuildContext context,
    String message,
    Future<void> Function() clear,
  ) async {
    await clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _CacheRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClear;

  const _CacheRow({
    required this.title,
    required this.subtitle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _mid),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: _mid),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
