import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/translation.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../../app/app_routes.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _fill = Color(0xFFF4F4F5);
const _card = Colors.white;

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
                _buildStepIndicator(),
                _buildHeader(vm),
                _buildSearchField(vm),
                Expanded(child: _buildTranslationList(vm)),
                _buildContinueButton(context, vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'STEP 2 OF 3',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _mid,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              return Container(
                width: 18,
                height: 3,
                margin: EdgeInsets.only(left: i > 0 ? 5 : 0),
                decoration: BoxDecoration(
                  color: i < 2 ? _ink : _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
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
                  '${langInfo.nativeName} · ${langInfo.description}',
                  style: const TextStyle(fontSize: 12, color: _mid),
                ),
                const SizedBox(width: 6),
                Text('·', style: TextStyle(fontSize: 12, color: _line)),
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

  Widget _buildSearchField(OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (q) => vm.searchTranslations(q),
        decoration: InputDecoration(
          hintText: 'Search translations...',
          hintStyle: const TextStyle(color: _mid, fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 18, color: _mid),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: _mid),
                  onPressed: () {
                    _searchController.clear();
                    vm.searchTranslations('');
                  },
                )
              : null,
          filled: true,
          fillColor: _fill,
          contentPadding: const EdgeInsets.symmetric(
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
    );
  }

  Widget _buildTranslationList(OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        itemCount: vm.filteredTranslations.length,
        itemBuilder: (context, i) {
          final translation = vm.filteredTranslations[i];
          return _buildTranslationRow(vm, translation);
        },
      ),
    );
  }

  Widget _buildTranslationRow(OnboardingViewModel vm, Translation translation) {
    final isSelected = vm.selectedTranslation?.id == translation.id;
    final downloadState = vm.getDownloadState(translation.id);
    final isReady = downloadState == DownloadState.ready;
    final isDownloading = downloadState == DownloadState.downloading;

    return InkWell(
      onTap: () {
        if (isReady) {
          vm.selectTranslation(translation);
        } else if (!isDownloading) {
          vm.downloadTranslation(translation);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: 0.5)),
        ),
        child: Row(
          children: [
            // Abbreviation badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? _ink : _fill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? _ink : _line),
              ),
              alignment: Alignment.center,
              child: Text(
                translation.id.length > 6
                    ? translation.id.substring(0, 6)
                    : translation.id,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _ink,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translation.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    translation.description,
                    style: const TextStyle(fontSize: 11.5, color: _mid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download state icon
            _buildDownloadIcon(vm, translation, isSelected, downloadState),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadIcon(
    OnboardingViewModel vm,
    Translation translation,
    bool isSelected,
    DownloadState state,
  ) {
    const size = 26.0;

    if (isSelected) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 13),
      );
    }

    switch (state) {
      case DownloadState.ready:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _line, width: 1.5),
          ),
        );
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
        return GestureDetector(
          onTap: () => vm.downloadTranslation(translation),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _line, width: 1.5),
            ),
            child: const Icon(Icons.download, size: 13, color: _mid),
          ),
        );
    }
  }

  Widget _buildContinueButton(BuildContext context, OnboardingViewModel vm) {
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
      ),
    );
  }
}
