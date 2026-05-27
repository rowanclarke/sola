import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/onboarding_viewmodel.dart';
import '../widgets/step_indicator.dart';
import '../../app/app_routes.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);
const _line = Color(0xFFE4E4E7);
const _fill = Color(0xFFF4F4F5);

class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<OnboardingViewModel>(
          builder: (context, vm, _) {
            return Column(
              children: [
                const StepIndicator(currentStep: 3, totalSteps: 3),
                Expanded(child: _buildContent(vm)),
                _buildButtons(context, vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(OnboardingViewModel vm) {
    final translation = vm.selectedTranslation;
    final langInfo = vm.selectedLanguageInfo;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _ink, width: 1.5),
              ),
              child: const Icon(Icons.check, size: 28, color: _ink),
            ),
            const SizedBox(height: 18),
            const Text(
              "You're all set",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your library is ready. You can change these anytime in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _mid,
                height: 1.4,
              ),
            ),
            if (translation != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        translation.id.length > 6
                            ? translation.id.substring(0, 6)
                            : translation.id,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translation.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            langInfo != null
                                ? '${langInfo.description} \u00b7 ${translation.language}'
                                : translation.language,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _mid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                context.goToReader();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start reading',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () {
                vm.goBackToLanguageStep();
                context.goToLanguage();
              },
              child: const Text(
                'Change language or translation',
                style: TextStyle(
                  fontSize: 13,
                  color: _mid,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
