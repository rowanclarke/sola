import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/language_repository.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../widgets/selectable_list_row.dart';
import '../widgets/step_indicator.dart';
import '../../app/app_routes.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _fill = Color(0xFFF4F4F5);
const _card = Colors.white;

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 160;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingViewModel>().init();
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _measureHeader() {
    final box =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height != _headerHeight) {
      setState(() => _headerHeight = box.size.height);
    }
  }

  void _openPicker() {
    _searchController.clear();
    context.read<OnboardingViewModel>().searchLanguages('');
    _sheetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
  }

  void _closePicker() {
    _searchController.clear();
    context.read<OnboardingViewModel>().searchLanguages('');
    _sheetController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Consumer<OnboardingViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                const StepIndicator(currentStep: 1, totalSteps: 3),
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            _buildDetectedCard(vm),
                            _buildChooseDifferent(),
                          ],
                        ),
                      ),
                      _buildPickerSheet(vm),
                    ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Sola',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We detected your device language. You can change this anytime.',
            style: TextStyle(fontSize: 14, color: _mid, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedCard(OnboardingViewModel vm) {
    final info = vm.detectedLanguageInfo;
    if (info == null) return const SizedBox.shrink();

    final isSelected = vm.selectedLanguageCode == info.bcp47;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () => vm.selectLanguage(info.bcp47),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? _ink : _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detected',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _mid,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildLanguageBadge(info.bcp47),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.description,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${info.translationCount} translations available',
                          style: const TextStyle(fontSize: 11.5, color: _mid),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: _ink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  else
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _line, width: 1.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChooseDifferent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: InkWell(
        onTap: _openPicker,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.language, size: 15, color: _ink.withAlpha(180)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Choose a different language',
                  style: TextStyle(fontSize: 13, color: _ink),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: _mid),
            ],
          ),
        ),
      ),
    );
  }

  // --------------- picker sheet ---------------

  Widget _buildPickerSheet(OnboardingViewModel vm) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0,
      minChildSize: 0,
      maxChildSize: 1,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PickerHeaderDelegate(
                  height: _headerHeight,
                  child: Container(
                    key: _headerKey,
                    color: _bg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grab handle
                        Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(top: 10, bottom: 6),
                            child: Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _line,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // Header
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Choose your language',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You can change this later in Settings.',
                                style:
                                    TextStyle(fontSize: 14, color: _mid),
                              ),
                            ],
                          ),
                        ),
                        // Search
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (q) => vm.searchLanguages(q),
                            decoration: InputDecoration(
                              hintText: 'Search languages...',
                              hintStyle: const TextStyle(
                                color: _mid,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 18,
                                color: _mid,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: _mid,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        vm.searchLanguages('');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: _fill,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemBuilder: (context, i) {
                  final lang = vm.filteredLanguages[i];
                  final isSelected =
                      vm.selectedLanguageCode == lang.bcp47;
                  return SelectableListRow(
                    leading: _buildLanguageBadge(lang.bcp47),
                    title: lang.nativeName,
                    subtitle:
                        '${lang.description} \u00b7 ${lang.translationCount} translations',
                    isSelected: isSelected,
                    onTap: () => vm.selectLanguage(lang.bcp47),
                  );
                },
                itemCount: vm.filteredLanguages.length,
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------- shared helpers ---------------

  Widget _buildLanguageBadge(String bcp47) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        bcp47.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, OnboardingViewModel vm) {
    final info = vm.selectedLanguageInfo;
    final label = info != null ? 'Continue in ${info.description}' : 'Continue';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _line, width: 0.5)),
        color: _bg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: vm.selectedLanguageCode != null
              ? () async {
                  await vm.goToTranslationStep();
                  if (context.mounted) {
                    context.goToTranslation();
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
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _PickerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PickerHeaderDelegate({required this.height, required this.child});

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PickerHeaderDelegate oldDelegate) =>
      oldDelegate.height != height;
}
