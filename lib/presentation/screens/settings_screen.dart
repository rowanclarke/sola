import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/models/translation.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/translations_viewmodel.dart';
import '../widgets/translation_badge.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _card = Colors.white;
const _sepia = Color(0xFFF5E9D0);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Typography and theme are laid out but not wired to anything yet, so their
  // state lives here rather than in the session.
  double _textSize = 2;
  double _lineSpacing = 1;
  int _themeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TranslationsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsHeader(title: 'Settings'),
            const Divider(height: 1, color: _line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildTranslationCard(),
                  _buildTypographyCard(),
                  _buildThemeCard(),
                  _buildHelpCard(),
                  _buildDeveloperCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------- current translation ---------------

  Widget _buildTranslationCard() {
    return Consumer<TranslationsViewModel>(
      builder: (context, vm, _) {
        return SettingsCard(
          label: 'Current translation',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  _buildCurrentTranslation(vm.current),
                  const SizedBox(height: 14),
                  _OutlinedAction(
                    label: 'Manage translations',
                    onTap: () => context.goToManageTranslations(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentTranslation(Translation? translation) {
    if (translation == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No translation selected',
          style: TextStyle(fontSize: 15, color: _mid),
        ),
      );
    }

    return Row(
      children: [
        TranslationBadge(
          translationId: translation.id,
          size: 48,
          fontSize: 12,
          isFilled: true,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translation.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle(translation),
                style: const TextStyle(fontSize: 13, color: _mid),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _subtitle(Translation translation) {
    if (translation.domain.isEmpty) return translation.langEn;
    return '${translation.langEn} · ${translation.domain}';
  }

  // --------------- typography (visual only) ---------------

  Widget _buildTypographyCard() {
    return SettingsCard(
      label: 'Typography',
      children: [
        const SettingsRow(
          title: 'Fonts per script',
          subtitle: '5 scripts configured',
          showChevron: true,
        ),
        _buildSliderRow(
          title: 'Text size',
          marker: 'L',
          value: _textSize,
          onChanged: (v) => setState(() => _textSize = v),
        ),
        _buildSliderRow(
          title: 'Line spacing',
          marker: 'M',
          value: _lineSpacing,
          onChanged: (v) => setState(() => _lineSpacing = v),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String marker,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: _ink),
                ),
              ),
              Text(
                marker,
                style: const TextStyle(fontSize: 12, color: _mid),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: _ink,
              inactiveTrackColor: _line,
              thumbColor: _ink,
              activeTickMarkColor: _ink,
              inactiveTickMarkColor: _line,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // --------------- reading theme (visual only) ---------------

  Widget _buildThemeCard() {
    const options = [
      ('Light', Colors.white, _ink),
      ('Sepia', _sepia, _ink),
      ('Dark', _ink, Colors.white),
    ];

    return SettingsCard(
      label: 'Reading theme',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _ThemeChip(
                    label: options[i].$1,
                    background: options[i].$2,
                    foreground: options[i].$3,
                    isSelected: _themeIndex == i,
                    onTap: () => setState(() => _themeIndex = i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --------------- help (visual only) ---------------

  Widget _buildHelpCard() {
    return const SettingsCard(
      label: 'Help',
      children: [
        SettingsRow(title: 'Report a bug', showChevron: true),
        SettingsRow(title: 'Submit feedback', showChevron: true),
      ],
    );
  }

  // --------------- developer options ---------------

  Widget _buildDeveloperCard() {
    final vm = context.read<SettingsViewModel>();

    return SettingsCard(
      label: 'Developer options',
      children: [
        _buildCacheRow(
          'Serialization cache',
          'Parsed Bible book data',
          'Serialization cache cleared',
          vm.clearSerializationCache,
        ),
        _buildCacheRow(
          'Rendering cache',
          'Laid-out page images',
          'Rendering cache cleared',
          vm.clearRenderingCache,
        ),
        _buildCacheRow(
          'Search cache',
          'Search index and embeddings',
          'Search cache cleared',
          vm.clearSearchCache,
        ),
      ],
    );
  }

  Widget _buildCacheRow(
    String title,
    String subtitle,
    String message,
    Future<void> Function() clear,
  ) {
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20, color: _mid),
        onPressed: () => _clearCache(message, clear),
      ),
    );
  }

  Future<void> _clearCache(
    String message,
    Future<void> Function() clear,
  ) async {
    await clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// The back arrow and title every settings-side screen opens with.
class SettingsHeader extends StatelessWidget {
  final String title;

  const SettingsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: _ink),
            onPressed: () => context.goBack(),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
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
}

/// A labelled white card. Every settings section is one of these.
class SettingsCard extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const SettingsCard({
    super.key,
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _mid,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One line inside a [SettingsCard], divided from the line above it.
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _line, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, color: _ink),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: _mid),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron)
              const Icon(Icons.chevron_right, size: 18, color: _mid),
          ],
        ),
      ),
    );
  }
}

/// The stadium-outlined secondary action used under a card's content.
class _OutlinedAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _line),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _ink : _line,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: foreground.withAlpha(90)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
