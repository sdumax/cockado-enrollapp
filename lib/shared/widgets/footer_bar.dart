import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class FooterBar extends StatelessWidget {
  const FooterBar({
    super.key,
    required this.version,
    this.isAutoCapture = true,
  });

  final String version;
  final bool isAutoCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.0,
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.darkDivider,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isAutoCapture ? 'AUTO-CAPTURE: ON' : 'AUTO-CAPTURE: OFF',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: isAutoCapture
                  ? AppColors.textMuted
                  : AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
          Text(
            version.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
