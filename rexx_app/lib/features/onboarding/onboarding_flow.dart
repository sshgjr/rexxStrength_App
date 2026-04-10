import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'models/onboarding_state.dart';
import 'steps/welcome_step.dart';
import 'steps/body_info_step.dart';
import 'steps/experience_step.dart';
import 'steps/lift_input_step.dart';
import 'steps/result_step.dart';

/// 5단계 온보딩 PageView.
/// Welcome → Body → Experience → Lifts → Result
class OnboardingFlow extends StatefulWidget {
  final String token;
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.token,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _input = OnboardingInput();
  bool _explicitSkip = false;
  OnboardingResult? _result;
  bool _submitting = false;

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit({required bool explicitSkip}) async {
    setState(() {
      _submitting = true;
      _explicitSkip = explicitSkip;
    });
    try {
      final json = await AuthService().submitOnboarding(
        token: widget.token,
        sex: _input.sex?.code,
        birthYear: _input.birthYear,
        trainingExperience: _input.experience?.code,
        squat1rm: _input.squatUnknown ? null : _input.squat1rm,
        bench1rm: _input.benchUnknown ? null : _input.bench1rm,
        deadlift1rm: _input.deadliftUnknown ? null : _input.deadlift1rm,
      );
      setState(() {
        _result = OnboardingResult.fromJson(json);
        _submitting = false;
      });
      _goToPage(4);
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('지금은 저장할 수 없어요. 나중에 설정에서 입력할 수 있어요. ($e)')),
        );
        widget.onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0C),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            WelcomeStep(
              onStart: () => _goToPage(1),
              onSkip: () => _submit(explicitSkip: true),
            ),
            BodyInfoStep(
              input: _input,
              onNext: () => _goToPage(2),
              onSkip: () => _goToPage(2),
            ),
            ExperienceStep(
              input: _input,
              onNext: () => _goToPage(3),
              onSkip: () => _goToPage(3),
            ),
            LiftInputStep(
              input: _input,
              submitting: _submitting,
              onComplete: () => _submit(explicitSkip: false),
            ),
            if (_result != null)
              ResultStep(
                result: _result!,
                explicitSkip: _explicitSkip,
                onConfirm: widget.onComplete,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
