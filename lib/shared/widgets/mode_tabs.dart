import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

enum ScanMode { ticket, face, touch, tally }

class ModeTabs extends StatelessWidget {
  const ModeTabs({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
    this.touchEnabled = false,
  });

  final ScanMode activeMode;
  final ValueChanged<ScanMode> onModeChanged;
  final bool touchEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.0,
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.darkDivider,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _ModeTab(
            icon: Icons.qr_code_scanner,
            label: 'TICKET',
            isActive: activeMode == ScanMode.ticket,
            onTap: () => onModeChanged(ScanMode.ticket),
          ),
          _ModeTab(
            icon: Icons.face_retouching_natural,
            label: 'FACE',
            isActive: activeMode == ScanMode.face,
            onTap: () => onModeChanged(ScanMode.face),
          ),
          _ModeTab(
            icon: Icons.fingerprint,
            label: 'TOUCH',
            isActive: activeMode == ScanMode.touch,
            enabled: touchEnabled,
            onTap: touchEnabled ? () => onModeChanged(ScanMode.touch) : null,
          ),
          _ModeTab(
            icon: Icons.tag,
            label: 'TALLY',
            isActive: activeMode == ScanMode.tally,
            onTap: () => onModeChanged(ScanMode.tally),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.isActive,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.blue : AppColors.textMuted;

    final Widget content = Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.0,
                color: color,
              ),
              const SizedBox(height: 4.0),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}
