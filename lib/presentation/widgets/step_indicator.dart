import 'package:flutter/material.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _line = Color(0xFFE4E4E7);

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'STEP $currentStep OF $totalSteps',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _mid,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: List.generate(totalSteps, (i) {
              return Container(
                width: 18,
                height: 3,
                margin: EdgeInsets.only(left: i > 0 ? 5 : 0),
                decoration: BoxDecoration(
                  color: i < currentStep ? _ink : _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
