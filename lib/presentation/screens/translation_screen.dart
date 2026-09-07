import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/translation.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../widgets/selectable_list_row.dart';
import '../widgets/searchable_list_view.dart';
import '../widgets/step_indicator.dart';
import '../widgets/translation_badge.dart';
import '../../app/app_routes.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<OnboardingViewModel>(
          builder: (context, vm, _) {
            return Column(
              children: [
                if (vm.isOnboarding)
                  const StepIndicator(currentStep: 2, totalSteps: 3)
                else
                  _buildBackBar(context),
                _buildHeader(vm),
                Expanded(
                  child: SearchableListView<Translation>(
                    searchHint: 'Search translations...',
                    searchController: _searchController,
                    onSearchChanged: (q) => vm.searchTranslations(q),
                    items: vm.filteredTranslations,
                    itemBuilder: (context, translation) {
                      final isSelected =
                          vm.selectedTranslation?.id == translation.id;
                      final downloadState =
                          vm.getDownloadState(translation.id);
                      return SelectableListRow(
                        leading: TranslationBadge(
                          translationId: translation.id,
                          isFilled: isSelected,
                        ),
                        title: translation.title,
                        subtitle: translation.description,
                        isSelected: isSelected,
                        onTap: () {
                          if (downloadState == DownloadState.ready) {
                            vm.selectTranslation(translation);
                          } else if (downloadState !=
                              DownloadState.downloading) {
                            vm.downloadTranslation(translation);
                          }
                        },
                        trailing: _buildTrailing(
                          vm,
                          translation,
                          isSelected,
                          downloadState,
                        ),
                      );
                    },
                  ),
                ),
                _buildContinueButton(context, vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(OnboardingViewModel vm) {
    final langInfo = vm.selectedLanguageInfo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a translation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          if (langInfo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.language, size: 12, color: _mid),
                const SizedBox(width: 6),
                Text(
                  '${langInfo.nativeName} \u00b7 ${langInfo.description}',
                  style: const TextStyle(fontSize: 12, color: _mid),
                ),
                const SizedBox(width: 6),
                Text('\u00b7', style: TextStyle(fontSize: 12, color: _line)),
                const SizedBox(width: 6),
                Text(
                  '${vm.filteredTranslations.length} available',
                  style: const TextStyle(fontSize: 12, color: _mid),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackBar(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20, color: _ink),
          onPressed: () => context.goBack(),
        ),
      ),
    );
  }

  // --------------- list item helpers ---------------

  Widget? _buildTrailing(
    OnboardingViewModel vm,
    Translation translation,
    bool isSelected,
    DownloadState state,
  ) {
    // Default trailing handles selected (check) and ready (empty circle).
    if (isSelected || state == DownloadState.ready) return null;

    const size = 22.0;

    switch (state) {
      case DownloadState.downloading:
        final progress = vm.getDownloadProgress(translation.id);
        return GestureDetector(
          onTap: () => vm.cancelTranslation(),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 1.5,
                    backgroundColor: _line,
                    valueColor: const AlwaysStoppedAnimation<Color>(_ink),
                  ),
                ),
                const Icon(Icons.close, size: 10, color: _ink),
              ],
            ),
          ),
        );
      case DownloadState.idle:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _line, width: 1.5),
          ),
          child: const Icon(Icons.download, size: 13, color: _mid),
        );
      default:
        return null;
    }
  }

  // --------------- footer ---------------

  Widget _buildContinueButton(BuildContext context, OnboardingViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _line, width: 0.5)),
        color: _bg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChangeLanguageButton(context, vm),
          const SizedBox(height: 10),
          _buildContinue(context, vm),
        ],
      ),
    );
  }

  /// The list only ever shows one language, so getting to another one needs its
  /// own way out.
  Widget _buildChangeLanguageButton(
    BuildContext context,
    OnboardingViewModel vm,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: () {
          vm.goBackToLanguageStep();
          context.goToLanguage();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Change language',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildContinue(BuildContext context, OnboardingViewModel vm) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: vm.selectedTranslation != null
            ? () async {
                await vm.goToCompleteStep();
                if (context.mounted) {
                  context.goToComplete();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _line,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
