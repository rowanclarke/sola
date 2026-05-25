import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/onboarding_viewmodel.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _bg = Color(0xFFFAFAFA);

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<OnboardingViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final langInfo = vm.selectedLanguageInfo;
            final translation = vm.selectedTranslation;

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 48, color: _mid),
                  const SizedBox(height: 24),
                  Text(
                    langInfo?.description ?? 'Unknown language',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translation?.title ?? 'No translation selected',
                    style: const TextStyle(
                      fontSize: 16,
                      color: _mid,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  if (translation != null)
                    Text(
                      translation.id,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _mid,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
