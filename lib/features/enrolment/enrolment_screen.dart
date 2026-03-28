import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cockado_enrollapp/core/router/app_router.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/features/scan/scan_providers.dart';
import 'package:cockado_enrollapp/shared/widgets/app_status_bar.dart';

enum _EnrolmentType { face, fingerprint, both }

class EnrolmentScreen extends ConsumerStatefulWidget {
  const EnrolmentScreen({super.key});

  @override
  ConsumerState<EnrolmentScreen> createState() => _EnrolmentScreenState();
}

class _EnrolmentScreenState extends ConsumerState<EnrolmentScreen> {
  final _tallyController = TextEditingController();
  final _tallyFocus = FocusNode();
  _EnrolmentType _selectedType = _EnrolmentType.face;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(standbyInhibitedProvider.notifier).state = true;
        _tallyFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    ref.read(standbyInhibitedProvider.notifier).state = false;
    _tallyController.dispose();
    _tallyFocus.dispose();
    super.dispose();
  }

  void _startEnrolment() {
    final tally = _tallyController.text.trim();
    if (tally.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tally number is required.')),
      );
      return;
    }

    final encoded = Uri.encodeComponent(tally);
    switch (_selectedType) {
      case _EnrolmentType.face:
        context.push('${AppRoutes.enrolmentFace}?tally=$encoded');
      case _EnrolmentType.fingerprint:
        context.push('${AppRoutes.enrolmentFingerprint}?tally=$encoded');
      case _EnrolmentType.both:
        context.push(
          '${AppRoutes.enrolmentFace}?tally=$encoded&next=fingerprint',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          const AppStatusBar(),
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Instruction text
                const Text(
                  "Enter the member's tally number and select the biometric enrolment type to proceed.",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                _buildTallyField(),
                const SizedBox(height: 14),
                _buildTypeField(),
                const SizedBox(height: 14),
                _buildStartButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      color: AppColors.darkBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF152235),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'BIOMETRIC ENROLMENT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTallyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TALLY NUMBER',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0F2236),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _tallyController,
                  focusNode: _tallyFocus,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  cursorColor: AppColors.blue,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENROLMENT TYPE',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0F2236),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _TypeOption(
                label: 'FACE',
                fontSize: 11,
                letterSpacing: 1.0,
                isActive: _selectedType == _EnrolmentType.face,
                onTap: () =>
                    setState(() => _selectedType = _EnrolmentType.face),
              ),
              const SizedBox(width: 4),
              _TypeOption(
                label: 'FINGERPRINT',
                fontSize: 10,
                letterSpacing: 0.8,
                isActive: _selectedType == _EnrolmentType.fingerprint,
                onTap: () =>
                    setState(() => _selectedType = _EnrolmentType.fingerprint),
              ),
              const SizedBox(width: 4),
              _TypeOption(
                label: 'BOTH',
                fontSize: 11,
                letterSpacing: 1.0,
                isActive: _selectedType == _EnrolmentType.both,
                onTap: () =>
                    setState(() => _selectedType = _EnrolmentType.both),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _startEnrolment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'START ENROLMENT',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.fontSize,
    required this.letterSpacing,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final double letterSpacing;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1A3A5C) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: letterSpacing,
              color: isActive ? AppColors.blue : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
