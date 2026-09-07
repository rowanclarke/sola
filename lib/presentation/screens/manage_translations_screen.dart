import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/models/translation.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../viewmodels/translations_viewmodel.dart';
import '../widgets/selectable_list_row.dart';
import '../widgets/translation_badge.dart';
import 'settings_screen.dart' show SettingsHeader;

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _card = Colors.white;

/// Which downloaded translations the reader's switcher offers, and in what
/// order.
///
/// Two groups: the switcher's own ordered list, and everything else that is
/// downloaded. Rows move between them; nothing is deleted here.
class ManageTranslationsScreen extends StatefulWidget {
  const ManageTranslationsScreen({super.key});

  @override
  State<ManageTranslationsScreen> createState() =>
      _ManageTranslationsScreenState();
}

class _ManageTranslationsScreenState extends State<ManageTranslationsScreen> {
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
            const SettingsHeader(title: 'Manage translations'),
            const Divider(height: 1, color: _line),
            Expanded(
              child: Consumer<TranslationsViewModel>(
                builder: (context, vm, _) {
                  if (vm.isLoading && vm.switcherTranslations.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _buildSwitcherSection(vm),
                      _buildPoolSection(vm),
                    ],
                  );
                },
              ),
            ),
            _buildAddButton(context),
          ],
        ),
      ),
    );
  }

  // --------------- sections ---------------

  Widget _buildSwitcherSection(TranslationsViewModel vm) {
    final translations = vm.switcherTranslations;

    return _Section(
      label: 'In switcher',
      hint: 'Drag to set the order they appear in.',
      child: translations.isEmpty
          ? const _EmptyNote('No translations in the switcher.')
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: translations.length,
              onReorder: vm.reorder,
              itemBuilder: (context, i) {
                final translation = translations[i];
                final canRemove = vm.canRemoveFromSwitcher(translation.id);
                return _TranslationRow(
                  // Reordering rebuilds the list, so rows need stable identity.
                  key: ValueKey(translation.id),
                  translation: translation,
                  isCurrent: translation.id == vm.currentId,
                  grabber: ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: _line,
                      ),
                    ),
                  ),
                  action: _RowAction(
                    icon: Icons.remove_circle_outline,
                    tooltip: canRemove
                        ? 'Remove from switcher'
                        : 'The translation being read stays in the switcher',
                    onTap: canRemove
                        ? () => vm.removeFromSwitcher(translation.id)
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPoolSection(TranslationsViewModel vm) {
    final translations = vm.poolTranslations;

    return _Section(
      label: 'Downloaded',
      hint: 'On this device, kept out of the switcher.',
      child: translations.isEmpty
          ? const _EmptyNote('Every downloaded translation is in the switcher.')
          : Column(
              children: [
                for (final translation in translations)
                  _TranslationRow(
                    key: ValueKey(translation.id),
                    translation: translation,
                    isCurrent: false,
                    // Order is meaningless here, so there is nothing to grab.
                    grabber: const SizedBox(width: 24),
                    action: _RowAction(
                      icon: Icons.add_circle_outline,
                      tooltip: 'Add to switcher',
                      onTap: () => vm.addToSwitcher(translation.id),
                    ),
                  ),
              ],
            ),
    );
  }

  // --------------- add ---------------

  Widget _buildAddButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line, width: 0.5)),
        color: _bg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _addTranslation(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Add translation',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _addTranslation(BuildContext context) async {
    // Same picker onboarding uses, entered at the translation step in the
    // language the session already reads.
    await context.read<OnboardingViewModel>().startAddTranslation();
    if (context.mounted) context.goToTranslation();
  }
}

// --------------- pieces ---------------

class _Section extends StatelessWidget {
  final String label;
  final String hint;
  final Widget child;

  const _Section({
    required this.label,
    required this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              hint,
              style: const TextStyle(fontSize: 12, color: _mid),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TranslationRow extends StatelessWidget {
  final Translation translation;
  final bool isCurrent;
  final Widget grabber;
  final Widget action;

  const _TranslationRow({
    super.key,
    required this.translation,
    required this.isCurrent,
    required this.grabber,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: Row(
        children: [
          grabber,
          Expanded(
            child: SelectableRow(
              leading: TranslationBadge(
                translationId: translation.id,
                size: 40,
                fontSize: 10,
                isFilled: isCurrent,
              ),
              title: translation.title,
              subtitle: _subtitle(),
              trailing: action,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final origin = translation.domain.isEmpty
        ? translation.langEn
        : '${translation.langEn} · ${translation.domain}';
    return isCurrent ? '$origin · Reading now' : origin;
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RowAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22, color: onTap == null ? _line : _mid),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String message;

  const _EmptyNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: _mid),
      ),
    );
  }
}
